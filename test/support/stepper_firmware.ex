defmodule Trenino.Test.StepperFirmware do
  @moduledoc "In-memory firmware contract fixture. Never opens a UART."
  alias Trenino.Serial.Protocol.{ConfigurationStored, Configure, StepperCommand, StepperStatus}

  def start_link(opts),
    do:
      Agent.start_link(fn ->
        %{
          owner: opts[:owner],
          connection: opts[:connection],
          axes: %{},
          hold_move_ack: false,
          hold_legacy_ack: false
        }
      end)

  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}

  def connections(pid),
    do:
      Agent.get(pid, fn s ->
        if s.connection.status == :connected, do: [s.connection], else: []
      end)

  def set_flag(pid, key, value), do: Agent.update(pid, &Map.put(&1, key, value))

  def connection(pid), do: Agent.get(pid, & &1.connection)
  def connect(pid, connection), do: Agent.update(pid, &%{&1 | connection: connection})

  def identity(pid, config_id),
    do:
      Agent.update(pid, fn s ->
        %{s | connection: %{s.connection | device_config_id: config_id}}
      end)

  def send_message(pid, port, %Configure{} = message) do
    owner = Agent.get(pid, & &1.owner)
    send(owner, {:wire, message})

    if not Agent.get(pid, & &1.hold_legacy_ack) and
         (message.total_parts == 0 or message.part_number + 1 == message.total_parts),
       do:
         send(self(), {:serial_message, port, %ConfigurationStored{config_id: message.config_id}})

    :ok
  end

  def send_message(pid, port, %StepperCommand{} = message) do
    {owner, status} =
      Agent.get_and_update(pid, fn s ->
        axes = apply_command(s.axes, message)
        {{s.owner, status(message, Map.get(axes, message.axis))}, %{s | axes: axes}}
      end)

    send(owner, {:wire, message})

    unless message.operation == :keep_alive or
             (message.operation == :move_to and Agent.get(pid, & &1.hold_move_ack)),
           do: send(self(), {:serial_message, port, status})

    if message.operation == :home, do: complete_home(pid, port, message, self())
    :ok
  end

  defp complete_home(pid, port, command, session) do
    Task.start(fn ->
      Process.sleep(20)

      status =
        Agent.get_and_update(pid, fn s ->
          a =
            Map.merge(s.axes[command.axis], %{
              known: true,
              state: :idle,
              energized: true,
              reference_kind: :assumed_stop
            })

          async = %{command | operation: :get_status, request_id: 0}
          {status(async, a), put_in(s.axes[command.axis], a)}
        end)

      send(session, {:serial_message, port, status})
    end)
  end

  defp apply_command(_, %StepperCommand{operation: :reset}), do: %{}

  defp apply_command(axes, %StepperCommand{operation: :configure, axis: axis}) do
    Map.put(axes, axis, %{
      configured: true,
      known: false,
      energized: false,
      state: :disabled,
      position: 0,
      target: 0,
      reference_kind: :unknown
    })
  end

  defp apply_command(axes, %StepperCommand{operation: op, axis: axis, position: position})
       when op in [:reference, :move_to] do
    Map.update!(
      axes,
      axis,
      &Map.merge(&1, %{
        known: true,
        energized: true,
        state: :idle,
        position: position,
        target: position,
        reference_kind: :host_assigned
      })
    )
  end

  defp apply_command(axes, %StepperCommand{operation: :home, axis: axis}),
    do: Map.update!(axes, axis, &Map.merge(&1, %{state: :homing, known: false, energized: true}))

  defp apply_command(axes, %StepperCommand{operation: :release, axis: axis}),
    do:
      Map.update!(
        axes,
        axis,
        &Map.merge(&1, %{
          known: false,
          energized: false,
          state: :disabled,
          reference_kind: :unknown
        })
      )

  defp apply_command(axes, _), do: axes

  defp status(cmd, axis) do
    defaults = %{
      configured: false,
      known: false,
      energized: false,
      state: :disabled,
      position: 0,
      target: 0,
      reference_kind: :unknown
    }

    struct(
      StepperStatus,
      Map.merge(defaults, axis || %{})
      |> Map.merge(%{
        operation: cmd.operation,
        axis: cmd.axis,
        request_id: cmd.request_id,
        result: :ok,
        fault: :none,
        phase: 0,
        max_axes: 2,
        drivers: 1,
        modes: 7,
        homing: 1
      })
    )
  end
end
