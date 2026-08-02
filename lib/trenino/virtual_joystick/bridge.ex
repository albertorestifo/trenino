defmodule Trenino.VirtualJoystick.Bridge do
  @moduledoc false
  use GenServer

  alias Trenino.VirtualJoystick.Bridge.PortAdapter

  @protocol 1
  @device 1
  @max_line_bytes 16 * 1024

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def set_axis(server, axis, value),
    do:
      safe_call(
        server,
        {:update, {:axis, axis}, %{command: "set_axis", axis: to_string(axis), value: value}}
      )

  def set_button(server, button, pressed),
    do:
      safe_call(
        server,
        {:update, {:button, button}, %{command: "set_button", button: button, pressed: pressed}}
      )

  def reset(server), do: safe_call(server, {:command, %{command: "reset"}})
  def shutdown(server), do: safe_call(server, :shutdown)
  def status(server), do: safe_call(server, :status)

  def binary_name,
    do:
      if(match?({:win32, _}, :os.type()),
        do: "trenino-virtual-joystick.exe",
        else: "trenino-virtual-joystick"
      )

  def executable_path do
    candidates =
      [
        app_path(),
        Path.join([:code.priv_dir(:trenino) |> to_string(), "bin", binary_name()]),
        Path.expand(Path.join(["tauri", "virtual_joystick", "target", "release", binary_name()])),
        Path.expand(Path.join(["tauri", "virtual_joystick", "target", "debug", binary_name()]))
      ]
      |> Enum.reject(&is_nil/1)

    case Enum.find(candidates, &File.regular?/1) do
      nil -> {:error, :executable_not_found}
      path -> {:ok, path}
    end
  end

  @impl true
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    adapter = Keyword.get(opts, :adapter, PortAdapter)

    timeout =
      Keyword.get(
        opts,
        :timeout,
        Application.get_env(:trenino, :virtual_joystick_bridge_timeout_ms, 5_000)
      )

    with {:ok, executable} <- executable(opts),
         {:ok, handle} <- adapter.open(self(), executable, stderr: :separate) do
      state = %{
        owner: owner,
        adapter: adapter,
        handle: handle,
        timeout: timeout,
        state: :starting,
        protocol: nil,
        device: @device,
        buffer: "",
        next_id: 1,
        outstanding: %{},
        in_flight: %{},
        pending: %{}
      }

      :ok = adapter.send_line(handle, Jason.encode!(%{command: "hello", protocol: @protocol}))
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:state, :protocol, :device]), state}
  end

  def handle_call(:shutdown, _from, state) do
    :ok = state.adapter.send_line(state.handle, Jason.encode!(%{command: "shutdown"}))
    {:reply, :ok, %{state | state: :stopping}}
  end

  def handle_call({:command, command}, from, state) do
    if state.state == :ready do
      {:noreply, send_request(state, nil, command, from)}
    else
      {:reply, unavailable(state), state}
    end
  end

  def handle_call({:update, key, command}, from, state) do
    cond do
      state.state != :ready -> {:reply, unavailable(state), state}
      Map.has_key?(state.in_flight, key) -> {:noreply, queue_latest(state, key, command, from)}
      true -> {:noreply, send_request(state, key, command, from)}
    end
  end

  @impl true
  def handle_info(
        {:virtual_joystick_adapter, handle, {:stdout, data}},
        %{handle: handle} = state
      ),
      do: consume(data, state)

  def handle_info(
        {:virtual_joystick_adapter, handle, {:stderr, _data}},
        %{handle: handle} = state
      ),
      do: {:noreply, state}

  def handle_info({:virtual_joystick_adapter, handle, {:exit, status}}, %{handle: handle} = state) do
    state = fail_all(state, {:process_exit, status})
    send(state.owner, {:virtual_joystick_bridge, {:exit, status}})
    {:noreply, %{state | state: :failed}}
  end

  def handle_info({handle, {:data, data}}, %{handle: handle} = state) when is_port(handle),
    do: consume(data, state)

  def handle_info({handle, {:exit_status, status}}, %{handle: handle} = state)
      when is_port(handle) do
    state = fail_all(state, {:process_exit, status})
    send(state.owner, {:virtual_joystick_bridge, {:exit, status}})
    {:noreply, %{state | state: :failed}}
  end

  def handle_info({:request_timeout, id}, state) do
    case Map.pop(state.outstanding, id) do
      {nil, _} ->
        {:noreply, state}

      {%{from: from, key: key}, outstanding} ->
        GenServer.reply(from, {:error, :timeout})
        state = %{state | outstanding: outstanding, in_flight: remove_key(state.in_flight, key)}
        {:noreply, dispatch_pending(state, key)}
    end
  end

  def handle_info(:stop_after_reply, state), do: {:stop, :normal, state}

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    state.adapter.close(state.handle)
    :ok
  end

  defp consume(data, state) do
    buffer = state.buffer <> data

    if byte_size(buffer) > @max_line_bytes and not String.contains?(buffer, "\n") do
      notify(state, {:protocol_error, :line_too_long})
      {:noreply, %{state | buffer: ""}}
    else
      parts = String.split(buffer, "\n")
      rest = List.last(parts)
      state = Enum.reduce(Enum.drop(parts, -1), %{state | buffer: rest}, &handle_line/2)
      {:noreply, state}
    end
  end

  defp handle_line("", state), do: state

  defp handle_line(line, state) when byte_size(line) > @max_line_bytes do
    notify(state, {:protocol_error, :line_too_long})
    state
  end

  defp handle_line(line, state) do
    case Jason.decode(line) do
      {:ok, response} ->
        handle_response(response, state)

      _ ->
        notify(state, {:protocol_error, :malformed_json})
        state
    end
  end

  defp handle_response(%{"event" => "ready", "protocol" => @protocol} = response, state) do
    ready = %{
      device: response["device"],
      axis_min: response["axis_min"],
      axis_max: response["axis_max"]
    }

    notify(state, {:ready, ready})
    %{state | state: :ready, protocol: @protocol, device: response["device"]}
  end

  defp handle_response(%{"event" => "ready", "protocol" => protocol}, state) do
    reason = {:protocol_mismatch, protocol}
    notify(state, {:error, reason})
    %{state | state: {:error, reason}, protocol: protocol}
  end

  defp handle_response(%{"event" => "applied", "request_id" => id}, state),
    do: acknowledge(state, id, :ok)

  defp handle_response(%{"event" => "device_removed"} = response, state) do
    notify(state, {:device_removed, response["device"]})
    state
  end

  defp handle_response(%{"event" => "stopped"}, state) do
    Process.send_after(self(), :stop_after_reply, 0)
    %{state | state: :stopped}
  end

  defp handle_response(%{"request_id" => id} = response, state),
    do: acknowledge(state, id, {:error, response["code"] || :feeder_error})

  defp handle_response(_response, state), do: state

  defp acknowledge(state, id, reply) do
    case Map.pop(state.outstanding, id) do
      {nil, _} ->
        state

      {%{from: from, key: key, timer: timer}, outstanding} ->
        Process.cancel_timer(timer)
        GenServer.reply(from, reply)
        state = %{state | outstanding: outstanding, in_flight: remove_key(state.in_flight, key)}
        dispatch_pending(state, key)
    end
  end

  defp send_request(state, key, command, from) do
    id = state.next_id
    payload = command |> Map.put(:request_id, id) |> Map.put(:device, state.device)
    :ok = state.adapter.send_line(state.handle, Jason.encode!(payload))
    timer = Process.send_after(self(), {:request_timeout, id}, state.timeout)
    entry = %{from: from, key: key, timer: timer}

    %{
      state
      | next_id: id + 1,
        outstanding: Map.put(state.outstanding, id, entry),
        in_flight: put_key(state.in_flight, key, id)
    }
  end

  defp queue_latest(state, key, command, from) do
    case state.pending[key] do
      %{from: old_from} -> GenServer.reply(old_from, {:error, :superseded})
      nil -> :ok
    end

    %{state | pending: Map.put(state.pending, key, %{command: command, from: from})}
  end

  defp dispatch_pending(state, nil), do: state

  defp dispatch_pending(state, key) do
    case Map.pop(state.pending, key) do
      {nil, _} ->
        state

      {%{command: command, from: from}, pending} ->
        send_request(%{state | pending: pending}, key, command, from)
    end
  end

  defp fail_all(state, reason) do
    Enum.each(state.outstanding, fn {_id, %{from: from, timer: timer}} ->
      Process.cancel_timer(timer)
      GenServer.reply(from, {:error, reason})
    end)

    Enum.each(state.pending, fn {_key, %{from: from}} ->
      GenServer.reply(from, {:error, reason})
    end)

    %{state | outstanding: %{}, pending: %{}, in_flight: %{}}
  end

  defp notify(state, event), do: send(state.owner, {:virtual_joystick_bridge, event})
  defp unavailable(%{state: {:error, reason}}), do: {:error, reason}
  defp unavailable(_state), do: {:error, :not_ready}
  defp put_key(map, nil, _id), do: map
  defp put_key(map, key, id), do: Map.put(map, key, id)
  defp remove_key(map, nil), do: map
  defp remove_key(map, key), do: Map.delete(map, key)

  defp executable(opts) do
    case Keyword.fetch(opts, :executable) do
      {:ok, path} -> {:ok, path}
      :error -> executable_path()
    end
  end

  defp app_path do
    case System.get_env("APP_PATH") do
      nil -> nil
      path -> Path.join(path, binary_name())
    end
  end

  defp safe_call(server, message) do
    GenServer.call(
      server,
      message,
      Application.get_env(:trenino, :virtual_joystick_bridge_timeout_ms, 5_000) + 1_000
    )
  catch
    :exit, reason -> {:error, {:bridge_exit, reason}}
  end
end
