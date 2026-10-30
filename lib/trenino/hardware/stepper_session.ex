defmodule Trenino.Hardware.StepperSession do
  @moduledoc "Per-UART bounded asynchronous motion session. Never owns or discovers UART."
  use GenServer
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Hardware.StepperSession.{AxisState, State}
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Protocol.{StepperCommand, StepperStatus}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  def command(pid, axis_id, operation, params, owner),
    do: GenServer.call(pid, {:command, axis_id, operation, params, owner})

  def set_target(pid, axis_id, target, owner),
    do: GenServer.call(pid, {:target, axis_id, target, owner})

  def begin_deployment(pid), do: GenServer.call(pid, :begin_deployment, 5000)

  def finish_deployment(pid, token, result),
    do: GenServer.call(pid, {:finish_deployment, token, result})

  def pause(pid, id, value), do: GenServer.call(pid, {:pause, id, value})
  def release_for_delete(pid, id), do: GenServer.call(pid, {:release_for_delete, id}, 3000)
  def reload_axes(pid, axes, token), do: GenServer.call(pid, {:reload_axes, axes, token})
  def forget_driver(pid, token), do: GenServer.call(pid, {:forget_driver, token}, 3000)

  @impl true
  def init(opts) do
    paused = Keyword.get(opts, :paused_axes, MapSet.new())

    axes =
      Map.new(
        Keyword.fetch!(opts, :axes),
        &{&1.id, %AxisState{config: &1, paused: MapSet.member?(paused, &1.id)}}
      )

    interval =
      axes |> Map.values() |> Enum.map(& &1.config.watchdog_ms) |> Enum.min(fn -> 1000 end)

    s = %State{
      port: Keyword.fetch!(opts, :port),
      generation: Keyword.fetch!(opts, :generation),
      device_id: Keyword.fetch!(opts, :device_id),
      axes: axes,
      send_fun: Keyword.get(opts, :send_fun, &Connection.send_message/2),
      ack_timeout: Keyword.get(opts, :ack_timeout, 250),
      idle_poll: Keyword.get(opts, :idle_poll, 1000),
      watchdog_interval: max(20, div(interval, 4)),
      timer_epoch: make_ref()
    }

    Connection.subscribe_messages(s.port)
    {:ok, s, {:continue, :probe}}
  end

  @impl true
  def handle_continue(:probe, s) do
    {s, _} = issue(s, nil, :get_status, %{})
    schedule(s, :poll, s.idle_poll)
    {:noreply, publish(s)}
  end

  @impl true
  def handle_call(:snapshot, _from, s), do: {:reply, s, s}

  def handle_call(
        {:reload_axes, axes, token},
        _,
        %State{lifecycle: :deploying, deployment_token: token} = s
      )
      when not is_nil(token) do
    axes = Map.new(axes, &{&1.id, %AxisState{config: &1}})

    interval =
      axes |> Map.values() |> Enum.map(& &1.config.watchdog_ms) |> Enum.min(fn -> 1000 end)

    {:reply, :ok, %{s | axes: axes, watchdog_interval: max(20, div(interval, 4))}}
  end

  def handle_call({:reload_axes, _, _}, _, s),
    do: {:reply, {:error, :invalid_deployment_token}, s}

  def handle_call(
        {:forget_driver, token},
        from,
        %State{lifecycle: :deploying, deployment_token: token} = s
      )
      when not is_nil(token) do
    {s, result} = issue(%{s | deployment_waiter: from}, nil, :forget_driver, %{})

    case result do
      {:ok, _} -> {:noreply, s}
      error -> {:reply, error, %{s | deployment_waiter: nil}}
    end
  end

  def handle_call({:forget_driver, _}, _, s), do: {:reply, {:error, :invalid_deployment_token}, s}

  def handle_call({:release_for_delete, id}, from, s) do
    case admit(s, id, :release, %{}) do
      :ok ->
        s = cancel_axis(s, id)
        {s, result} = issue(s, id, :release, %{})

        if match?({:ok, _}, result),
          do: {:noreply, put_axis(s, id, %{s.axes[id] | release_waiter: from})},
          else: {:reply, result, s}

      error ->
        {:reply, error, s}
    end
  end

  def handle_call({:pause, id, value}, _from, s) do
    case Map.fetch(s.axes, id) do
      {:ok, a} ->
        {:reply, :ok, publish(put_axis(s, id, %{a | paused: value, desired_target: nil}))}

      :error ->
        {:reply, {:error, :not_found}, s}
    end
  end

  def handle_call({:command, id, op, params, _owner}, _from, s) do
    case admit(s, id, op, params) do
      :ok ->
        s = if op in [:stop, :release], do: cancel_axis(s, id), else: s
        {s, result} = issue(s, id, op, params)
        {:reply, result, publish(s)}

      error ->
        {:reply, error, s}
    end
  end

  def handle_call({:target, id, target, _owner}, _from, s) do
    case admit_target(s, id, target) do
      :ok ->
        accept_target(s, id, target)

      error ->
        {:reply, error, s}
    end
  end

  def handle_call(:begin_deployment, from, %State{deployment_token: nil} = s) do
    token = make_ref()
    s = invalidate(s, :deploying)
    {s, result} = issue(%{s | deployment_token: token, deployment_waiter: from}, nil, :reset, %{})

    case result do
      {:ok, _} -> {:noreply, publish(s)}
      error -> {:reply, error, %{s | deployment_waiter: nil}}
    end
  end

  def handle_call(:begin_deployment, _, s), do: {:reply, {:error, :busy}, s}

  def handle_call({:finish_deployment, token, result}, _, %State{deployment_token: token} = s)
      when not is_nil(token) do
    s = %{s | deployment_token: nil, deployment_waiter: nil}
    s = if result == :ok, do: probe(s), else: fault(s, {:deployment_failed, result})
    {:reply, :ok, publish(s)}
  end

  def handle_call({:finish_deployment, _, _}, _, s), do: {:reply, {:error, :stale_token}, s}

  @impl true
  def handle_info({:serial_message, port, %StepperStatus{} = status}, %State{port: port} = s) do
    {:noreply, publish(receive_status(s, status))}
  end

  def handle_info({:retry, epoch, id, request}, %State{timer_epoch: epoch} = s) do
    {:noreply, publish(retry(s, id, request))}
  end

  def handle_info({:tick, epoch, :watchdog}, %State{timer_epoch: epoch} = s) do
    if s.lifecycle not in [:fault, :deploying, :disconnected, :unsupported] do
      case transmit(s, %StepperCommand{operation: :keep_alive, axis: 255, request_id: 0}) do
        :ok -> schedule(s, :watchdog, s.watchdog_interval)
        _ -> send(self(), {:transport_failed, s.timer_epoch})
      end
    end

    {:noreply, s}
  end

  def handle_info({:tick, epoch, :poll}, %State{timer_epoch: epoch} = s) do
    s = poll_axes(s)
    moving = Enum.any?(s.axes, fn {_, a} -> a.status && a.status.state in [:moving, :homing] end)
    schedule(s, :poll, if(moving, do: s.moving_poll, else: s.idle_poll))
    {:noreply, s}
  end

  def handle_info({:transport_failed, epoch}, %State{timer_epoch: epoch} = s),
    do: {:noreply, publish(fault(s, :send_failed))}

  def handle_info(_, s), do: {:noreply, s}

  defp admit(%State{lifecycle: lifecycle}, _, _, _)
       when lifecycle in [:deploying, :probing, :resetting, :configuring, :fault, :unsupported],
       do: {:error, lifecycle}

  defp admit(s, id, op, params), do: admit_axis(Map.get(s.axes, id), op, params)
  defp admit_axis(nil, _, _), do: {:error, :not_found}
  defp admit_axis(_, op, _) when op in [:stop, :release], do: :ok
  defp admit_axis(%AxisState{pending: p}, _, _) when not is_nil(p), do: {:error, :busy}
  defp admit_axis(%AxisState{ready: false}, :move_to, _), do: {:error, :needs_reference}
  defp admit_axis(a, :move_to, params), do: position_valid(a, Map.get(params, :position))

  defp admit_axis(
         %AxisState{config: %{reference_strategy: :host_reference}} = a,
         :reference,
         params
       ),
       do: position_valid(a, Map.get(params, :position))

  defp admit_axis(%AxisState{config: %{reference_strategy: :internal_stop}}, :home, _), do: :ok

  defp admit_axis(_, op, _) when op in [:reference, :home],
    do: {:error, :wrong_reference_strategy}

  defp admit_axis(_, op, _) when op in [:enable, :get_status], do: :ok
  defp admit_axis(_, _, _), do: {:error, :invalid_operation}

  defp admit_target(s, id, target) do
    case Map.get(s.axes, id) do
      nil -> {:error, :not_found}
      %AxisState{paused: true} -> {:error, :manual_pause}
      %AxisState{ready: false} -> {:error, :needs_reference}
      a -> position_valid(a, target)
    end
  end

  defp accept_target(s, id, target) do
    a = s.axes[id]

    cond do
      a.last_target == target ->
        {:reply, :ok, s}

      a.pending != nil ->
        {:reply, :ok, put_axis(s, id, %{a | desired_target: target})}

      true ->
        {s, result} = issue(s, id, :move_to, %{position: target})
        {:reply, if(match?({:ok, _}, result), do: :ok, else: result), publish(s)}
    end
  end

  defp position_valid(a, p) when is_integer(p) do
    if p >= a.config.min_position and p <= a.config.max_position,
      do: :ok,
      else: {:error, :outside_limits}
  end

  defp position_valid(_, _), do: {:error, :invalid_position}

  defp issue(%State{next_id: id} = s, _axis_id, _op, _params) when id >= 65_535 do
    {rollover(s), {:error, :reference_epoch_changed}}
  end

  defp issue(s, id, op, params) do
    axis = if id, do: s.axes[id].config.axis_index, else: if(op == :get_status, do: 0, else: 255)

    cmd =
      struct(
        StepperCommand,
        Map.merge(params, %{operation: op, axis: axis, request_id: s.next_id})
      )

    with {:ok, _} <- StepperCommand.encode(cmd), :ok <- transmit(s, cmd) do
      pending = %{command: cmd, retries: 0}
      s = %{s | next_id: s.next_id + 1}

      s =
        if id,
          do: put_axis(s, id, %{s.axes[id] | pending: pending}),
          else: %{s | global_pending: pending}

      Process.send_after(self(), {:retry, s.timer_epoch, id, cmd.request_id}, s.ack_timeout)
      {s, {:ok, cmd.request_id}}
    else
      error -> {fault(s, {:send_failed, error}), {:error, :send_failed}}
    end
  end

  defp transmit(s, cmd) do
    s.send_fun.(s.port, cmd)
  catch
    :exit, reason -> {:error, reason}
  end

  defp retry(s, id, request) do
    pending = if id, do: s.axes[id].pending, else: s.global_pending

    case pending do
      %{command: %{request_id: ^request} = cmd, retries: n} when n < 2 ->
        retry_command(s, id, cmd, n)

      %{command: %{request_id: ^request}} ->
        timeout(s, id)

      _ ->
        s
    end
  end

  defp retry_command(s, id, cmd, n) do
    case transmit(s, cmd) do
      :ok ->
        Process.send_after(self(), {:retry, s.timer_epoch, id, cmd.request_id}, s.ack_timeout)
        put_pending(s, id, %{command: cmd, retries: n + 1})

      _ ->
        fault(s, :send_failed)
    end
  end

  defp put_pending(s, nil, pending), do: %{s | global_pending: pending}
  defp put_pending(s, id, pending), do: put_axis(s, id, %{s.axes[id] | pending: pending})

  defp timeout(s, nil) do
    if s.deployment_waiter, do: GenServer.reply(s.deployment_waiter, {:error, :outcome_unknown})
    fault(%{s | deployment_waiter: nil}, :outcome_unknown)
  end

  defp timeout(s, id) do
    a = s.axes[id]
    if a.release_waiter, do: GenServer.reply(a.release_waiter, {:error, :outcome_unknown})

    s =
      put_axis(s, id, %{
        a
        | pending: nil,
          ready: false,
          reference_accepted: false,
          desired_target: nil,
          release_waiter: nil,
          error: :outcome_unknown
      })

    poll_axis(s, id)
  end

  defp receive_status(%State{lifecycle: :probing, global_pending: %{command: cmd}} = s, status) do
    if matches?(cmd, status) do
      capability_response(s, status)
    else
      s
    end
  end

  defp receive_status(%State{global_pending: %{command: %{operation: :reset} = cmd}} = s, status) do
    if matches?(cmd, status), do: reset_ack(s, status), else: s
  end

  defp receive_status(
         %State{global_pending: %{command: %{operation: :forget_driver} = cmd}} = s,
         status
       ) do
    if matches?(cmd, status) do
      reply_driver_waiter(s.deployment_waiter, status.result)

      %{s | global_pending: nil, deployment_waiter: nil}
    else
      s
    end
  end

  defp receive_status(s, status) do
    case Enum.find(s.axes, fn {_, a} -> a.config.axis_index == status.axis end) do
      nil -> s
      {id, a} -> axis_status(s, id, a, status)
    end
  end

  defp reply_driver_waiter(nil, _), do: :ok
  defp reply_driver_waiter(waiter, :ok), do: GenServer.reply(waiter, :ok)
  defp reply_driver_waiter(waiter, result), do: GenServer.reply(waiter, {:error, result})

  defp capability_response(s, status) do
    if Enum.all?(s.axes, fn {_, a} ->
         StepperStatus.supports?(status, StepperAxis.to_protocol_config(a.config))
       end) do
      {s, _} =
        issue(
          %{s | capabilities: status, global_pending: nil, lifecycle: :resetting},
          nil,
          :reset,
          %{}
        )

      s
    else
      %{s | lifecycle: :unsupported, global_pending: nil, error: :unsupported_capabilities}
    end
  end

  defp reset_ack(s, %StepperStatus{result: :ok}) do
    s = %{s | global_pending: nil}

    if s.deployment_waiter do
      GenServer.reply(s.deployment_waiter, {:ok, s.deployment_token})
      %{s | deployment_waiter: nil}
    else
      configure_next(%{s | queue: Map.keys(s.axes), lifecycle: :configuring})
    end
  end

  defp reset_ack(s, status), do: fault(s, {:reset_failed, status.result})

  defp configure_next(%State{queue: []} = s) do
    %{s | lifecycle: :awaiting_reference}
  end

  defp configure_next(%State{queue: [id | rest]} = s) do
    s = start_watchdog(s)

    {s, _} =
      issue(%{s | queue: rest}, id, :configure, %{
        configuration: StepperAxis.to_protocol_config(s.axes[id].config)
      })

    s
  end

  defp axis_status(s, id, a, status) do
    cond do
      status.fault != :none ->
        fault(s, status.fault)

      a.pending && matches?(a.pending.command, status) ->
        mutation_ack(s, id, a, status)

      a.reference_poll == status.request_id and status.request_id != 0 and
          status.operation == :get_status ->
        complete_reference(s, id, a, status)

      status.request_id == 0 ->
        async_status(s, id, a, status)

      true ->
        s
    end
  end

  defp mutation_ack(s, id, a, status) do
    cmd = a.pending.command
    a = %{a | pending: nil, status: status, updated_at: now()}

    if a.release_waiter,
      do:
        GenServer.reply(
          a.release_waiter,
          if(status.result == :ok and not status.energized,
            do: :ok,
            else: {:error, :release_unconfirmed}
          )
        )

    a = %{a | release_waiter: nil}

    case {status.result, cmd.operation} do
      {:ok, operation} -> accepted(s, id, a, cmd, operation)
      {error, :configure} -> fault(s, {:configure_failed, error})
      {error, _} -> put_axis(s, id, %{a | ready: false, reference_accepted: false, error: error})
    end
  end

  defp accepted(s, id, a, _, :configure), do: configure_next(put_axis(s, id, a))

  defp accepted(s, id, a, _, op) when op in [:home, :reference],
    do: poll_axis(put_axis(s, id, %{a | ready: false, reference_accepted: true}), id)

  defp accepted(s, id, a, _, :release),
    do: put_axis(s, id, %{a | ready: false, reference_accepted: false, last_target: nil})

  defp accepted(s, id, a, _, :stop),
    do:
      put_axis(s, id, %{
        a
        | ready: a.ready and a.status.known and a.status.state == :idle,
          reference_accepted: a.reference_accepted and a.status.known and a.status.state == :idle,
          desired_target: nil
      })

  defp accepted(s, id, a, cmd, :move_to),
    do: dispatch_desired(put_axis(s, id, %{a | last_target: cmd.position}), id)

  defp accepted(s, id, a, _, _), do: put_axis(s, id, a)

  defp complete_reference(s, id, a, status) do
    ready =
      a.reference_accepted and status.result == :ok and status.configured and status.known and
        (status.state == :idle or (a.ready and status.state == :moving)) and
        a.config.idle_behavior == :hold

    a = %{a | status: status, updated_at: now(), reference_poll: nil, ready: ready}
    s = put_axis(s, id, a)

    %{
      s
      | lifecycle:
          if(Enum.any?(s.axes, fn {_, axis} -> axis.ready end),
            do: :ready,
            else: :awaiting_reference
          )
    }
  end

  defp async_status(s, id, a, status) do
    cond do
      not status.configured ->
        fault(s, :unexpected_reset)

      status.state == :homing and a.reference_accepted ->
        put_axis(s, id, %{a | status: status, updated_at: now(), ready: false})

      not status.known ->
        put_axis(s, id, %{
          a
          | status: status,
            ready: false,
            reference_accepted: false,
            last_target: nil,
            updated_at: now()
        })

      true ->
        put_axis(s, id, %{a | status: status, updated_at: now()})
    end
  end

  defp poll_axes(%State{lifecycle: lifecycle} = s)
       when lifecycle in [:ready, :awaiting_reference] do
    Enum.reduce(Map.keys(s.axes), s, &poll_axis(&2, &1))
  end

  defp poll_axes(s), do: s

  defp poll_axis(s, id) do
    cmd = %StepperCommand{
      operation: :get_status,
      axis: s.axes[id].config.axis_index,
      request_id: s.next_id
    }

    cond do
      s.next_id >= 65_535 ->
        rollover(s)

      transmit(s, cmd) == :ok ->
        put_axis(%{s | next_id: s.next_id + 1}, id, %{s.axes[id] | reference_poll: cmd.request_id})

      true ->
        fault(s, :status_poll_failed)
    end
  end

  defp rollover(s) do
    s = invalidate(s, :resetting)
    {s, _} = issue(%{s | next_id: 1}, nil, :reset, %{})
    schedule(s, :poll, s.idle_poll)
    s
  end

  defp dispatch_desired(s, id) do
    a = s.axes[id]

    if a.desired_target && a.ready do
      {s, _} =
        issue(put_axis(s, id, %{a | desired_target: nil}), id, :move_to, %{
          position: a.desired_target
        })

      s
    else
      s
    end
  end

  defp cancel_axis(s, id) do
    put_axis(s, id, %{
      s.axes[id]
      | pending: nil,
        desired_target: nil,
        reference_poll: nil
    })
  end

  defp matches?(cmd, status),
    do:
      cmd.request_id != 0 and cmd.request_id == status.request_id and cmd.axis == status.axis and
        cmd.operation == status.operation

  defp put_axis(s, id, a), do: %{s | axes: Map.put(s.axes, id, a)}

  defp invalidate(s, lifecycle) do
    axes = Map.new(s.axes, fn {id, a} -> {id, %AxisState{config: a.config, paused: a.paused}} end)

    %{
      s
      | axes: axes,
        lifecycle: lifecycle,
        global_pending: nil,
        timer_epoch: make_ref(),
        watchdog_started: false
    }
  end

  defp fault(s, error) do
    reply_fault_waiter(s.deployment_waiter, error)
    Enum.each(s.axes, fn {_, axis} -> reply_fault_waiter(axis.release_waiter, error) end)
    %{invalidate(%{s | deployment_waiter: nil}, :fault) | error: error}
  end

  defp reply_fault_waiter(nil, _), do: :ok
  defp reply_fault_waiter(waiter, error), do: GenServer.reply(waiter, {:error, error})

  defp probe(s) do
    s = invalidate(s, :probing)
    {s, _} = issue(s, nil, :get_status, %{})
    schedule(s, :poll, s.idle_poll)
    s
  end

  defp schedule(s, kind, delay),
    do: Process.send_after(self(), {:tick, s.timer_epoch, kind}, delay)

  defp start_watchdog(%State{watchdog_started: true} = s), do: s

  defp start_watchdog(s) do
    schedule(s, :watchdog, s.watchdog_interval)
    %{s | watchdog_started: true}
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp publish(s) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "hardware:steppers:#{s.device_id}",
      {:stepper_updated, s.device_id, s}
    )

    s
  end
end
