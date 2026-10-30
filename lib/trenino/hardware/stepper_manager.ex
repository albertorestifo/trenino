defmodule Trenino.Hardware.StepperManager do
  @moduledoc "Connection-generation, ownership and deployment authority for physical gauges."
  use GenServer
  alias Trenino.Hardware
  alias Trenino.Hardware.{StepperAxis, StepperSession, StepperSupervisor}
  alias Trenino.Serial.Connection

  @type state :: %{
          sessions: map(),
          connections: map(),
          barriers: map(),
          leases: map(),
          send_fun: function()
        }

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def subscribe(id), do: Phoenix.PubSub.subscribe(Trenino.PubSub, "hardware:steppers:#{id}")
  def snapshot(id), do: call({:snapshot, id}, %{lifecycle: :disconnected, axes: %{}})
  def claim_manual(id, owner), do: call({:claim, id, owner})
  def release_manual(id, token), do: call({:release_manual, id, token})
  def resume(id), do: call({:resume, id})
  def command(id, op, params, token), do: call({:command, id, op, params, token})
  def set_target(id, target, train_id), do: call({:target, id, target, train_id})
  def inactive(id, behavior), do: call({:inactive, id, behavior})
  def begin_deployment(port), do: call({:begin_deployment, port}, {:ok, :no_manager})

  def finish_deployment(port, token, result),
    do: call({:finish_deployment, port, token, result}, :ok)

  def reconcile_device(id), do: call({:reconcile, id}, :ok)
  def prepare_delete(id), do: call({:prepare_delete, id}, :ok)
  def recover(id), do: call({:recover, id})
  def complete_commissioning(id, token), do: call({:complete_commissioning, id, token})

  def recommission_address(id, address, acknowledged?),
    do: call({:recommission_address, id, address, acknowledged?})

  def claim_mcp_manual(id), do: call({:claim_mcp, id})
  def renew_mcp_manual(id, token), do: call({:renew_mcp, id, token})

  def command_once(id, op, params, lease_token, operation_token),
    do: call({:command_once, id, op, params, lease_token, operation_token})

  defp call(message, fallback \\ {:error, :disconnected}) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, message, 6000), else: fallback
  end

  @impl true
  def init(opts) do
    cleanup_orphan_sessions()
    Connection.subscribe()

    s = %{
      sessions: %{},
      connections: %{},
      barriers: %{},
      leases: %{},
      paused_axes: MapSet.new(),
      send_fun: Keyword.get(opts, :send_fun, &Connection.send_message/2)
    }

    {:ok, s, {:continue, {:initial, Keyword.get(opts, :devices, Connection.connected_devices())}}}
  end

  @impl true
  def handle_continue({:initial, devices}, s), do: {:noreply, reconcile(s, devices, false)}
  @impl true
  def handle_call({:snapshot, id}, _, s), do: {:reply, get_snapshot(s, id), s}

  def handle_call({:recommission_address, id, address, true}, _, s)
      when is_integer(address) and address in 96..119 do
    case find_session(s, id) do
      nil ->
        {:reply, {:error, :disconnected}, s}

      session ->
        result = recommission_session(session.pid, id, address)

        {:reply, result, revoke_port(s, session.port)}
    end
  end

  def handle_call({:recommission_address, _, _, _}, _, s),
    do: {:reply, {:error, :registration_acknowledgement_required}, s}

  def handle_call({:complete_commissioning, id, token}, _, s) do
    result =
      with %{token: ^token} = lease <- Map.get(s.leases, id),
           true <- live_lease?(lease),
           {:ok, pid} <- axis_session(s, id),
           :ok <- applied_configuration(s, id, pid),
           axis_state <- StepperSession.snapshot(pid).axes[id],
           true <- stationary_fresh?(axis_state),
           {:ok, axis} <- Hardware.get_stepper_axis(id),
           do: Hardware.update_stepper_axis(axis, %{commissioned: true})

    result =
      if match?({:ok, _}, result),
        do: result,
        else: {:error, :requires_fresh_reference_and_manual_lease}

    {:reply, result, s}
  end

  def handle_call({:claim_mcp, id}, _, s) do
    with {:ok, pid} <- axis_session(s, id), false <- Map.has_key?(s.leases, id) do
      token = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
      expires = System.monotonic_time(:millisecond) + 60_000
      StepperSession.pause(pid, id, true)
      StepperSession.command(pid, id, :stop, %{}, :manual)

      lease = %{
        token: token,
        monitor: nil,
        owner: :mcp,
        expires: expires,
        operations: %{},
        epoch: StepperSession.snapshot(pid).timer_epoch
      }

      Process.send_after(self(), {:mcp_expire, id, token}, 60_000)

      {:reply, {:ok, %{token: token, expires_in_ms: 60_000}},
       %{s | leases: Map.put(s.leases, id, lease), paused_axes: MapSet.put(s.paused_axes, id)}}
    else
      true -> {:reply, {:error, :owned}, s}
      error -> {:reply, error, s}
    end
  end

  def handle_call({:renew_mcp, id, token}, _, s) do
    case mcp_lease(s, id, token) do
      {:ok, lease} ->
        lease = %{lease | expires: System.monotonic_time(:millisecond) + 60_000}
        Process.send_after(self(), {:mcp_expire, id, token}, 60_000)

        {:reply, {:ok, %{token: token, expires_in_ms: 60_000}},
         %{s | leases: Map.put(s.leases, id, lease)}}

      error ->
        {:reply, error, s}
    end
  end

  def handle_call({:command_once, id, op, params, token, operation_token}, _, s) do
    with {:ok, lease} <- mcp_lease(s, id, token),
         true <- is_binary(operation_token) and byte_size(operation_token) in 1..200,
         {:ok, pid} <- axis_session(s, id) do
      {result, lease} =
        once(lease, operation_token, {op, params}, fn -> execute_once(s, pid, id, op, params) end)

      {:reply, result, %{s | leases: Map.put(s.leases, id, lease)}}
    else
      false -> {:reply, {:error, :operation_token_required}, s}
      error -> {:reply, error, s}
    end
  end

  def handle_call({:claim, id, owner}, _, s) do
    with {:ok, pid} <- axis_session(s, id), false <- Map.has_key?(s.leases, id) do
      token = make_ref()
      monitor = Process.monitor(owner)
      StepperSession.pause(pid, id, true)
      StepperSession.command(pid, id, :stop, %{}, :manual)

      lease = %{
        token: token,
        monitor: monitor,
        owner: owner,
        epoch: StepperSession.snapshot(pid).timer_epoch
      }

      {:reply, {:ok, token},
       %{s | leases: Map.put(s.leases, id, lease), paused_axes: MapSet.put(s.paused_axes, id)}}
    else
      true -> {:reply, {:error, :owned}, s}
      error -> {:reply, error, s}
    end
  end

  def handle_call({:release_manual, id, token}, _, s) do
    case Map.get(s.leases, id) do
      %{token: ^token, monitor: monitor} ->
        demonitor(monitor)
        stop_axis(s, id)
        {:reply, :ok, %{s | leases: Map.delete(s.leases, id)}}

      _ ->
        {:reply, {:error, :invalid_lease}, s}
    end
  end

  def handle_call({:resume, id}, _, s) do
    with false <- Map.has_key?(s.leases, id), {:ok, pid} <- axis_session(s, id) do
      {:reply, StepperSession.pause(pid, id, false),
       %{s | paused_axes: MapSet.delete(s.paused_axes, id)}}
    else
      true -> {:reply, {:error, :owned}, s}
      error -> {:reply, error, s}
    end
  end

  def handle_call({:command, id, op, params, token}, _, s) when op in [:stop, :release] do
    result =
      with %{token: ^token} <- Map.get(s.leases, id),
           {:ok, pid} <- axis_session(s, id),
           do: manual_command(pid, id, op, params)

    {:reply, normalize_lease_result(result), s}
  end

  def handle_call({:command, id, op, params, token}, _, s) do
    result =
      with %{token: ^token} <- Map.get(s.leases, id),
           {:ok, pid} <- axis_session(s, id),
           :ok <- applied_configuration(s, id, pid),
           do: manual_command(pid, id, op, params)

    {:reply, normalize_lease_result(result), s}
  end

  def handle_call({:target, id, target, _train_id}, _, s) do
    result =
      with false <- Map.has_key?(s.leases, id),
           false <- MapSet.member?(s.paused_axes, id),
           {:ok, axis} <- Hardware.get_stepper_axis(id),
           true <- axis.commissioned and axis.idle_behavior == :hold,
           {:ok, pid} <- axis_session(s, id),
           :ok <- applied_configuration(s, id, pid),
           do: StepperSession.set_target(pid, id, target, :train)

    {:reply, normalize_target_result(result), s}
  end

  def handle_call({:inactive, id, behavior}, _, s) do
    result =
      with false <- Map.has_key?(s.leases, id),
           {:ok, pid} <- axis_session(s, id),
           do:
             StepperSession.command(
               pid,
               id,
               if(behavior == :release, do: :release, else: :stop),
               %{},
               :train
             )

    {:reply, normalize_target_result(result), s}
  end

  def handle_call({:begin_deployment, port}, _, s) do
    if Map.has_key?(s.barriers, port) do
      {:reply, {:error, :busy}, s}
    else
      token = make_ref()

      result =
        case Map.get(s.sessions, port) do
          nil -> {:ok, token}
          %{pid: pid} -> StepperSession.begin_deployment(pid)
        end

      case result do
        {:ok, session_token} ->
          barrier = %{token: token, session_token: session_token}

          {:reply, {:ok, token},
           revoke_port(%{s | barriers: Map.put(s.barriers, port, barrier)}, port)}

        error ->
          {:reply, error, s}
      end
    end
  end

  def handle_call({:finish_deployment, port, token, result}, _, s) do
    case Map.get(s.barriers, port) do
      %{token: ^token, session_token: session_token} ->
        finish_session_deployment(s.sessions[port], session_token, result)

        s = %{s | barriers: Map.delete(s.barriers, port)}
        {:reply, :ok, reconcile(s, Connection.connected_devices(), false)}

      _ ->
        {:reply, {:error, :stale_token}, s}
    end
  end

  def handle_call({:prepare_delete, id}, _, s) do
    case axis_session(s, id) do
      {:error, :disconnected} -> {:reply, :ok, s}
      {:ok, pid} -> {:reply, StepperSession.release_for_delete(pid, id), s}
    end
  end

  def handle_call({:recover, id}, _, s) do
    case Enum.find(s.sessions, fn {_, session} -> session.device_id == id end) do
      nil ->
        {:reply, {:error, :disconnected}, s}

      {port, session} ->
        s = drop_session(s, port, session)
        {:reply, :ok, reconcile(s, Map.values(s.connections), false)}
    end
  end

  def handle_call({:reconcile, id}, from, s), do: handle_call({:recover, id}, from, s)

  @impl true
  def handle_info({:devices_updated, devices}, s), do: {:noreply, reconcile(s, devices, true)}

  def handle_info({:mcp_expire, id, token}, s) do
    now = System.monotonic_time(:millisecond)

    case Map.get(s.leases, id) do
      %{token: ^token, expires: expiry} when expiry <= now ->
        stop_axis(s, id)
        {:noreply, %{s | leases: Map.delete(s.leases, id)}}

      _ ->
        {:noreply, s}
    end
  end

  def handle_info({:DOWN, monitor, :process, pid, _}, s) do
    ids =
      s.leases
      |> Enum.filter(fn {_, lease} -> lease.monitor == monitor end)
      |> Enum.map(&elem(&1, 0))

    Enum.each(ids, &stop_axis(s, &1))

    dead_ports =
      s.sessions
      |> Enum.filter(fn {_, session} -> session.pid == pid end)
      |> Enum.map(&elem(&1, 0))

    s = Enum.reduce(dead_ports, s, &revoke_port(&2, &1))
    sessions = Map.reject(s.sessions, fn {_, session} -> session.pid == pid end)
    s = %{s | leases: Map.drop(s.leases, ids), sessions: sessions}
    {:noreply, reconcile(s, Map.values(s.connections), false)}
  end

  def handle_info({:stepper_updated, id, _snapshot}, s) do
    snapshot = get_snapshot(s, id)
    s = revoke_stale_leases(s, id, snapshot)

    session =
      Enum.find_value(s.sessions, fn {_, entry} -> if entry.device_id == id, do: entry end)

    if session && session.auto_home && snapshot.lifecycle == :awaiting_reference do
      axes = Hardware.list_stepper_axes(id) |> Enum.filter(&StepperAxis.auto_home?/1)
      s = update_in(s.sessions[session.port].auto_home, fn _ -> false end)
      Enum.each(axes, &StepperSession.command(session.pid, &1.id, :home, %{}, :startup))
      {:noreply, s}
    else
      {:noreply, s}
    end
  end

  def handle_info(_, s), do: {:noreply, s}

  @impl true
  def terminate(_, s) do
    Enum.each(s.sessions, fn {_, session} ->
      if Process.alive?(session.pid), do: GenServer.stop(session.pid)
    end)
  end

  defp reconcile(s, devices, fresh?) do
    connected = Enum.filter(devices, &(&1.status == :connected))
    counts = Enum.frequencies_by(connected, & &1.device_config_id)

    s =
      Enum.reduce(s.sessions, s, fn {port, session}, acc ->
        conn = Enum.find(connected, &(&1.port == port))

        if conn && generation(conn) == session.generation && counts[conn.device_config_id] == 1,
          do: acc,
          else: drop_session(acc, port, session)
      end)

    previous = s.connections
    s = %{s | connections: Map.new(connected, &{&1.port, &1})}

    Enum.reduce(connected, s, fn conn, acc ->
      new_generation? =
        fresh? and
          (not Map.has_key?(previous, conn.port) or
             previous[conn.port].pid != conn.pid)

      if counts[conn.device_config_id] == 1 and not Map.has_key?(acc.sessions, conn.port) and
           not Map.has_key?(acc.barriers, conn.port),
         do: start_session(acc, conn, new_generation?),
         else: acc
    end)
  end

  defp start_session(s, conn, auto_home) do
    with {:ok, version} <- Version.parse(conn.device_version || ""),
         true <- Version.compare(version, "3.1.0") != :lt and version.pre == [],
         {:ok, device} <- Hardware.get_device_by_config_id(conn.device_config_id),
         [_ | _] = axes <- Hardware.list_stepper_axes(device.id) do
      opts = [
        port: conn.port,
        generation: generation(conn),
        device_id: device.id,
        axes: axes,
        paused_axes: s.paused_axes,
        send_fun: s.send_fun
      ]

      {:ok, pid} = start_session_process(opts)
      Process.monitor(pid)
      subscribe(device.id)

      session = %{
        pid: pid,
        port: conn.port,
        generation: generation(conn),
        device_id: device.id,
        auto_home: auto_home
      }

      %{s | sessions: Map.put(s.sessions, conn.port, session)}
    else
      _ -> s
    end
  end

  defp drop_session(s, port, session) do
    if Process.alive?(session.pid), do: GenServer.stop(session.pid)
    s = revoke_port(s, port)

    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "hardware:steppers:#{session.device_id}",
      {:stepper_updated, session.device_id, %{lifecycle: :disconnected, axes: %{}}}
    )

    %{s | sessions: Map.delete(s.sessions, port)}
  end

  defp revoke_port(s, port) do
    case s.sessions[port] do
      nil ->
        s

      session ->
        ids = Hardware.list_stepper_axes(session.device_id) |> Enum.map(& &1.id)

        Enum.each(Map.take(s.leases, ids), fn {_, lease} ->
          demonitor(lease.monitor)
        end)

        %{s | leases: Map.drop(s.leases, ids)}
    end
  end

  defp axis_session(s, id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         session when not is_nil(session) <-
           find_session(s, axis.device_id),
         true <- Process.alive?(session.pid) do
      {:ok, session.pid}
    else
      _ -> {:error, :disconnected}
    end
  end

  defp get_snapshot(s, id) do
    case find_session(s, id) do
      nil -> %{lifecycle: :disconnected, axes: %{}}
      session -> safe_snapshot(session.pid)
    end
  end

  defp safe_snapshot(pid) do
    StepperSession.snapshot(pid)
  catch
    :exit, _ -> %{lifecycle: :disconnected, axes: %{}}
  end

  defp revoke_stale_leases(s, id, snapshot) do
    ids = Hardware.list_stepper_axes(id) |> Enum.map(& &1.id)

    stale =
      Enum.filter(Map.take(s.leases, ids), fn {_, lease} ->
        Map.get(lease, :epoch) != Map.get(snapshot, :timer_epoch)
      end)

    Enum.each(stale, fn {_, lease} -> demonitor(lease.monitor) end)
    %{s | leases: Map.drop(s.leases, Enum.map(stale, &elem(&1, 0)))}
  end

  defp find_session(s, id) do
    s.sessions |> Map.values() |> Enum.find(&(&1.device_id == id))
  end

  defp manual_command(pid, id, :jog, %{delta: delta}) when is_integer(delta) do
    a = StepperSession.snapshot(pid).axes[id]

    if a.status && a.status.known && a.status.state == :idle &&
         System.monotonic_time(:millisecond) - a.updated_at < 1500,
       do:
         StepperSession.command(
           pid,
           id,
           :move_to,
           %{position: a.status.position + delta},
           :manual
         ),
       else: {:error, :needs_fresh_stationary_position}
  end

  defp manual_command(pid, id, op, params),
    do: StepperSession.command(pid, id, op, params, :manual)

  defp normalize_lease_result(nil), do: {:error, :invalid_lease}
  defp normalize_lease_result({:ok, _} = result), do: result
  defp normalize_lease_result({:error, _} = result), do: result
  defp normalize_lease_result(_), do: {:error, :invalid_lease}
  defp normalize_target_result(false), do: {:error, :not_commissioned}
  defp normalize_target_result(true), do: {:error, :manual_pause}
  defp normalize_target_result(result), do: result

  defp stop_axis(s, id) do
    with {:ok, pid} <- axis_session(s, id),
         do: StepperSession.command(pid, id, :stop, %{}, :manual)
  end

  defp generation(conn), do: {conn.pid, conn.device_config_id, conn.device_version}

  defp cleanup_orphan_sessions do
    if Process.whereis(StepperSupervisor) do
      Enum.each(DynamicSupervisor.which_children(StepperSupervisor), &terminate_orphan/1)
    end
  end

  defp terminate_orphan({_, pid, _, _}) when is_pid(pid),
    do: DynamicSupervisor.terminate_child(StepperSupervisor, pid)

  defp terminate_orphan(_), do: :ok

  defp finish_session_deployment(nil, _, _), do: :ok

  defp finish_session_deployment(session, token, result) do
    if result == :ok,
      do:
        StepperSession.reload_axes(
          session.pid,
          Hardware.list_stepper_axes(session.device_id),
          token
        )

    StepperSession.finish_deployment(session.pid, token, result)
  end

  defp recommission_session(pid, device_id, address) do
    with {:ok, token} <- StepperSession.begin_deployment(pid) do
      result =
        with :ok <- StepperSession.forget_driver(pid, token),
             {:ok, axes} <- Hardware.update_stepper_shield_address(device_id, address),
             do: StepperSession.reload_axes(pid, axes, token)

      StepperSession.finish_deployment(pid, token, result)
      result
    end
  end

  defp applied_configuration(_s, id, pid) do
    with {:ok, persisted} <- Hardware.get_stepper_axis(id),
         configured when not is_nil(configured) <- StepperSession.snapshot(pid).axes[id],
         true <-
           persisted.axis_index == configured.config.axis_index and
             StepperAxis.to_protocol_config(persisted) ==
               StepperAxis.to_protocol_config(configured.config),
         do: :ok,
         else: (_ -> {:error, :needs_apply})
  end

  defp start_session_process(opts) do
    if Process.whereis(Trenino.Hardware.StepperSupervisor) do
      spec = Supervisor.child_spec({StepperSession, opts}, restart: :temporary)
      DynamicSupervisor.start_child(Trenino.Hardware.StepperSupervisor, spec)
    else
      case StepperSession.start_link(opts) do
        {:ok, pid} ->
          Process.unlink(pid)
          {:ok, pid}

        error ->
          error
      end
    end
  end

  defp live_lease?(%{owner: :mcp, expires: expires}),
    do: expires > System.monotonic_time(:millisecond)

  defp live_lease?(_), do: true

  defp stationary_fresh?(%{
         ready: true,
         status: %{known: true, state: :idle},
         updated_at: timestamp
       })
       when is_integer(timestamp),
       do: System.monotonic_time(:millisecond) - timestamp < 1500

  defp stationary_fresh?(_), do: false
  defp demonitor(nil), do: :ok
  defp demonitor(ref), do: Process.demonitor(ref, [:flush])

  defp mcp_lease(s, id, token) do
    now = System.monotonic_time(:millisecond)

    case Map.get(s.leases, id) do
      %{token: ^token, owner: :mcp, expires: expiry} = lease when expiry > now -> {:ok, lease}
      _ -> {:error, :invalid_or_expired_lease}
    end
  end

  defp once(lease, token, content, execute) do
    case Map.get(lease.operations, token) do
      %{content: ^content, result: result} ->
        {result, lease}

      entry when not is_nil(entry) ->
        {{:error, :operation_token_reused}, lease}

      nil when map_size(lease.operations) >= 100 ->
        {{:error, :lease_operation_limit}, lease}

      nil ->
        result = execute.()

        {result,
         %{
           lease
           | operations: Map.put(lease.operations, token, %{content: content, result: result})
         }}
    end
  end

  defp execute_once(_s, pid, id, :recover, _) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         {:ok, token} <- StepperSession.begin_deployment(pid),
         :ok <- StepperSession.reload_axes(pid, Hardware.list_stepper_axes(axis.device_id), token),
         :ok <- StepperSession.finish_deployment(pid, token, :ok),
         do: {:ok, :recovering}
  end

  defp execute_once(_s, pid, id, :recommission_address, %{address: address, acknowledged: true})
       when is_integer(address) and address in 96..119 do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         :ok <- recommission_session(pid, axis.device_id, address),
         do: {:ok, :recommissioning}
  end

  defp execute_once(_, _, _, :recommission_address, _),
    do: {:error, :registration_acknowledgement_required}

  defp execute_once(s, pid, id, :complete_commissioning, _) do
    with :ok <- applied_configuration(s, id, pid),
         true <- stationary_fresh?(StepperSession.snapshot(pid).axes[id]),
         {:ok, axis} <- Hardware.get_stepper_axis(id),
         {:ok, _} <- Hardware.update_stepper_axis(axis, %{commissioned: true}),
         do: {:ok, :commissioned},
         else: (_ -> {:error, :requires_fresh_reference_and_manual_lease})
  end

  defp execute_once(_, pid, id, op, params) when op in [:stop, :release],
    do: manual_command(pid, id, op, params)

  defp execute_once(s, pid, id, op, params) do
    with :ok <- applied_configuration(s, id, pid), do: manual_command(pid, id, op, params)
  end
end
