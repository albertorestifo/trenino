defmodule Trenino.Hardware.StepperAxisTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware.StepperAxis

  test "valid defaults and wire-only conversion" do
    cs = StepperAxis.changeset(%StepperAxis{device_id: 1}, %{name: "Speed", axis_index: 0})
    assert cs.valid?
    axis = Ecto.Changeset.apply_changes(cs)
    assert axis.startup_reference == :manual
    refute axis.commissioned

    assert %Trenino.Serial.Protocol.StepperConfiguration{motor_port: 1} =
             StepperAxis.to_protocol_config(axis)
  end

  test "range and home timing policy" do
    for {field, value} <- [
          axis_index: 2,
          motor_port: 3,
          shield_address: 95,
          max_speed: 201,
          acceleration: 10_001,
          watchdog_ms: 99,
          home_steps: 0,
          home_direction: 0,
          min_position: 721,
          home_backoff: 1080
        ] do
      refute StepperAxis.changeset(
               %StepperAxis{device_id: 1},
               Map.new([{:name, "Speed"}, {field, value}])
             ).valid?
    end

    refute StepperAxis.changeset(%StepperAxis{device_id: 1}, %{
             name: "Speed",
             reference_strategy: :internal_stop,
             home_timeout_ms: 9000
           }).valid?
  end

  test "range errors identify the editable field" do
    for {field, value} <- [
          watchdog_ms: 99,
          home_backoff: 1080,
          shield_address: 95,
          motor_port: 3,
          home_direction: 0
        ] do
      cs = StepperAxis.changeset(%StepperAxis{device_id: 1}, %{field => value, :name => "Speed"})
      assert Keyword.has_key?(cs.errors, field)
    end
  end

  test "motion edits clear commissioning; name edits preserve it" do
    axis = %StepperAxis{name: "Old", device_id: 1, commissioned: true}
    assert Ecto.Changeset.get_field(StepperAxis.changeset(axis, %{name: "New"}), :commissioned)
    refute Ecto.Changeset.get_field(StepperAxis.changeset(axis, %{reverse: true}), :commissioned)
    refute StepperAxis.auto_home?(%{axis | startup_reference: :home_on_connect})
  end
end
