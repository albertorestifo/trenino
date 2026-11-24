defmodule Trenino.Hardware.Calibration.SessionTest do
  # Not async: the session saves through the shared sandbox connection.
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session
  alias Trenino.Hardware.Input.Calibration

  @port "/dev/test_angle"

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Angle Device"})

    {:ok, input} =
      Hardware.create_input(device.id, %{
        input_type: :analog,
        sensor: :mt6701,
        i2c_address: 0x06,
        sensitivity: 5
      })

    {:ok, pid} = Hardware.start_calibration_session(input, @port)
    Session.subscribe(input.id)
    on_exit(fn -> if Process.alive?(pid), do: Session.cancel(pid) end)

    %{input: input, pid: pid}
  end

  defp reading(pid, pin, value) do
    send(pid, {:input_value_updated, @port, pin, value})
    # A call after the send: the reading has been handled when it returns.
    Session.get_public_state(pid)
  end

  test "an angle sensor session is circular and waits for a first reading", %{
    input: input,
    pid: pid
  } do
    state = Session.get_public_state(pid)
    assert state.circular
    assert state.current_value == nil
    refute state.can_advance
    assert {:error, :no_reading} = Session.advance_step(pid)

    state = reading(pid, input.pin, 8192)
    assert state.current_value == 8192
    assert state.can_advance
  end

  test "one fresh reading completes a hold step", %{input: input, pid: pid} do
    reading(pid, input.pin, 100)
    :ok = Session.advance_step(pid)

    # The reading before Start doesn't count for the min end.
    refute Session.get_public_state(pid).can_advance
    assert reading(pid, input.pin, 100).can_advance
  end

  test "calibrates a lever whose travel crosses the sensor's 0", %{input: input, pid: pid} do
    pin = input.pin
    reading(pid, pin, 15_000)
    :ok = Session.advance_step(pid)

    # Min held at 15000 with a glitch.
    for v <- [15_000, 15_001, 14_999, 3000, 15_000], do: reading(pid, pin, v)
    :ok = Session.advance_step(pid)

    # Sweep there and back, across 16383 -> 0, then forward again.
    for v <- [15_500, 16_000, 16_300, 100, 600, 100, 16_300, 16_200, 16_380, 200, 900, 1500, 2000],
        do: reading(pid, pin, v)

    :ok = Session.advance_step(pid)
    for v <- [2000, 2001, 1999], do: reading(pid, pin, v)
    :ok = Session.advance_step(pid)

    assert_receive {:calibration_result, {:ok, %Calibration{} = cal}}, 1_000

    assert cal.circular
    assert cal.min_value == 15_000
    assert cal.max_value == 2000
    refute cal.is_inverted
    assert cal.has_rollover
    assert cal.max_hardware_value == 16_383
    assert Hardware.total_travel(cal) == 3384
  end

  test "reports a travel under 5 degrees", %{input: input, pid: pid} do
    pin = input.pin
    reading(pid, pin, 4000)
    :ok = Session.advance_step(pid)
    reading(pid, pin, 4000)
    :ok = Session.advance_step(pid)
    for v <- 4000..4100//10, do: reading(pid, pin, v)
    :ok = Session.advance_step(pid)
    reading(pid, pin, 4100)
    :ok = Session.advance_step(pid)

    assert_receive {:calibration_result, {:error, :range_too_small}}, 1_000
  end
end
