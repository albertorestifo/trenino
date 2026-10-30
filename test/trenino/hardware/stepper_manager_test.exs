defmodule Trenino.Hardware.StepperManagerTest do
  use Trenino.DataCase, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperManager
  alias Trenino.Hardware.StepperSupervisor
  alias Trenino.Repo
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Protocol.{StepperCommand, StepperStatus}

  setup do
    owner = self()
    {:ok, device} = Hardware.create_device(%{name: "Stepper"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, pid} =
      StepperManager.start_link(
        devices: [],
        send_fun: fn _, msg ->
          send(owner, {:sent, msg})
          :ok
        end
      )

    Sandbox.allow(Repo, self(), pid)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    conn = %DeviceConnection{
      port: "mock-manager",
      status: :connected,
      pid: self(),
      device_config_id: device.config_id,
      device_version: "3.1.0"
    }

    %{pid: pid, device: device, axis: axis, conn: conn}
  end

  test "duplicate device updates preserve session generation; disconnect invalidates", %{
    pid: pid,
    device: device,
    conn: conn
  } do
    send(pid, {:devices_updated, [conn]})
    assert_receive {:sent, %StepperCommand{operation: :get_status}}
    initial = StepperManager.snapshot(device.id)
    send(pid, {:devices_updated, [conn]})
    assert StepperManager.snapshot(device.id).generation == initial.generation
    send(pid, {:devices_updated, [%{conn | status: :uploading}]})
    assert StepperManager.snapshot(device.id).lifecycle == :disconnected
    GenServer.stop(StepperManager)
  end

  test "no-axis deployment still reserves port", %{pid: _pid} do
    assert {:ok, token} = StepperManager.begin_deployment("empty")
    assert {:error, :busy} = StepperManager.begin_deployment("empty")
    assert :ok = StepperManager.finish_deployment("empty", token, :ok)
    GenServer.stop(StepperManager)
  end

  test "session crash recovers without authorizing automatic home", %{
    pid: pid,
    conn: conn,
    device: device
  } do
    send(pid, {:devices_updated, [conn]})
    assert_receive {:sent, %StepperCommand{operation: :get_status}}
    session = :sys.get_state(pid).sessions[conn.port]
    Process.exit(session.pid, :kill)
    assert_receive {:sent, %StepperCommand{operation: :get_status}}, 200
    assert StepperManager.snapshot(device.id).lifecycle == :probing
    refute :sys.get_state(pid).sessions[conn.port].auto_home
    GenServer.stop(StepperManager)
  end

  test "duplicate connected identity refuses attachment and removes existing session", %{
    pid: pid,
    conn: conn,
    device: device
  } do
    send(pid, {:devices_updated, [conn]})
    assert_receive {:sent, %StepperCommand{operation: :get_status}}
    send(pid, {:devices_updated, [conn, %{conn | port: "duplicate"}]})
    assert StepperManager.snapshot(device.id).lifecycle == :disconnected
    GenServer.stop(StepperManager)
  end

  test "unknown and forged manual ownership rejected", %{axis: axis} do
    assert {:error, :disconnected} = StepperManager.claim_manual(axis.id, self())
    assert {:error, _} = StepperManager.command(axis.id, :home, %{}, "forged")
    GenServer.stop(StepperManager)
  end

  test "MCP lease survives caller and deduplicates identical operation tokens", %{
    pid: pid,
    conn: conn,
    axis: axis
  } do
    send(pid, {:devices_updated, [conn]})

    for operation <- [:get_status, :reset, :configure] do
      assert_receive {:sent, %StepperCommand{operation: ^operation} = cmd}

      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "serial:messages:#{conn.port}",
        {:serial_message, conn.port, status(cmd)}
      )

      Process.sleep(5)
    end

    assert {:ok, %{token: token}} = StepperManager.claim_mcp_manual(axis.id)
    assert_receive {:sent, %StepperCommand{operation: :stop} = stop}

    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "serial:messages:#{conn.port}",
      {:serial_message, conn.port, status(stop)}
    )

    Process.sleep(5)

    assert {:ok, request} =
             StepperManager.command_once(
               axis.id,
               :reference,
               %{position: 0},
               token,
               "operation-1"
             )

    assert_receive {:sent, %StepperCommand{operation: :reference} = reference}
    assert reference.request_id == request

    assert {:ok, ^request} =
             StepperManager.command_once(
               axis.id,
               :reference,
               %{position: 0},
               token,
               "operation-1"
             )

    assert {:error, :operation_token_reused} =
             StepperManager.command_once(
               axis.id,
               :reference,
               %{position: 1},
               token,
               "operation-1"
             )

    assert {:ok, _} = StepperManager.renew_mcp_manual(axis.id, token)
    GenServer.stop(StepperManager)
  end

  test "MCP expiry stops and preserves manual pause; operation records cannot be evicted", ctx do
    prepare(ctx)
    assert {:ok, %{token: token}} = StepperManager.claim_mcp_manual(ctx.axis.id)
    assert_receive {:sent, %StepperCommand{operation: :stop}}

    :sys.replace_state(ctx.pid, fn s ->
      lease = s.leases[ctx.axis.id]
      records = Map.new(1..100, &{to_string(&1), %{content: {:enable, %{}}, result: {:ok, &1}}})
      put_in(s.leases[ctx.axis.id], %{lease | operations: records})
    end)

    assert {:error, :lease_operation_limit} =
             StepperManager.command_once(ctx.axis.id, :enable, %{}, token, "new")

    :sys.replace_state(ctx.pid, fn s ->
      put_in(s.leases[ctx.axis.id].expires, System.monotonic_time(:millisecond) - 1)
    end)

    send(ctx.pid, {:mcp_expire, ctx.axis.id, token})
    StepperManager.snapshot(ctx.device.id)

    assert {:error, :invalid_or_expired_lease} =
             StepperManager.renew_mcp_manual(ctx.axis.id, token)

    assert {:error, :manual_pause} = StepperManager.set_target(ctx.axis.id, 20, 1)
    assert_receive {:sent, %StepperCommand{operation: :stop}}
    GenServer.stop(StepperManager)
  end

  test "session death revokes a held lease before reconstructed session accepts commands", ctx do
    prepare(ctx)
    assert {:ok, token} = StepperManager.claim_manual(ctx.axis.id, self())
    old = :sys.get_state(ctx.pid).sessions[ctx.conn.port].pid
    Process.exit(old, :kill)
    assert_receive {:sent, %StepperCommand{operation: :get_status}}, 300

    assert {:error, :invalid_lease} =
             StepperManager.command(ctx.axis.id, :reference, %{position: 0}, token)

    assert Process.alive?(ctx.pid)
    assert :sys.get_state(ctx.pid).leases == %{}
    GenServer.stop(StepperManager)
  end

  test "unapplied edits cannot be commissioned against a previous firmware configuration", ctx do
    prepare(ctx)
    assert {:ok, token} = StepperManager.claim_manual(ctx.axis.id, self())
    assert_receive {:sent, %StepperCommand{operation: :stop} = stop}
    publish(ctx, status(stop))
    Process.sleep(5)
    assert {:ok, _} = StepperManager.command(ctx.axis.id, :reference, %{position: 0}, token)
    assert_receive {:sent, %StepperCommand{operation: :reference} = reference}
    publish(ctx, %{status(reference) | known: true, energized: true})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    publish(ctx, %{status(poll) | configured: true, known: true, energized: true})
    Process.sleep(5)
    assert {:ok, _} = StepperManager.complete_commissioning(ctx.axis.id, token)
    {:ok, current} = Hardware.get_stepper_axis(ctx.axis.id)
    assert {:ok, edited} = Hardware.update_stepper_axis(current, %{reverse: true})
    refute edited.commissioned
    assert {:error, _} = StepperManager.complete_commissioning(ctx.axis.id, token)

    assert {:error, :needs_apply} =
             StepperManager.command(ctx.axis.id, :move_to, %{position: 10}, token)

    assert {:ok, _} = StepperManager.command(ctx.axis.id, :stop, %{}, token)
    assert {:ok, _} = StepperManager.command(ctx.axis.id, :release, %{}, token)
    GenServer.stop(StepperManager)
  end

  test "manager hard restart removes orphan supervised sessions before reconstructing", ctx do
    start_supervised!(StepperSupervisor)
    prepare(ctx)
    old_session = :sys.get_state(ctx.pid).sessions[ctx.conn.port].pid
    Process.unlink(ctx.pid)
    monitor = Process.monitor(ctx.pid)
    Process.exit(ctx.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}
    owner = self()

    {:ok, replacement} =
      StepperManager.start_link(
        devices: [ctx.conn],
        send_fun: fn _, msg ->
          send(owner, {:replacement, msg})
          :ok
        end
      )

    on_exit(fn -> if Process.alive?(replacement), do: GenServer.stop(replacement) end)
    assert_receive {:replacement, %StepperCommand{operation: :get_status}}
    refute Process.alive?(old_session)
    assert DynamicSupervisor.count_children(StepperSupervisor).active == 1
    refute :sys.get_state(replacement).sessions[ctx.conn.port].auto_home
    GenServer.stop(replacement)
  end

  defp prepare(ctx) do
    send(ctx.pid, {:devices_updated, [ctx.conn]})

    for operation <- [:get_status, :reset, :configure] do
      assert_receive {:sent, %StepperCommand{operation: ^operation} = cmd}
      publish(ctx, status(cmd))
      Process.sleep(5)
    end
  end

  defp publish(ctx, status),
    do:
      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "serial:messages:#{ctx.conn.port}",
        {:serial_message, ctx.conn.port, status}
      )

  defp status(cmd) do
    %StepperStatus{
      operation: cmd.operation,
      axis: cmd.axis,
      request_id: cmd.request_id,
      result: :ok,
      state: :idle,
      configured: cmd.operation not in [:reset, :get_status],
      known: false,
      energized: false,
      reference_kind: :unknown,
      fault: :none,
      position: 0,
      target: 0,
      phase: 0,
      max_axes: 2,
      drivers: 1,
      modes: 7,
      homing: 1
    }
  end
end
