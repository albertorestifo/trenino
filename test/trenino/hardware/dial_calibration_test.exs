defmodule Trenino.Hardware.DialCalibrationTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, StepperAxis}
  alias Trenino.Train

  @points [%{value: 0, position: 0}, %{value: 100, position: 720}]

  defp changeset(points, axis \\ %StepperAxis{id: 1}),
    do:
      DialCalibration.changeset(
        %DialCalibration{stepper_axis_id: 1, points: []},
        %{points: points},
        axis
      )

  defp setup_axis do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)
    axis
  end

  test "points require sorted distinct values and monotonic positions inside limits" do
    for points <- [
          [],
          [%{value: 0, position: 0}],
          [%{value: 0, position: 0}, %{value: 0.001, position: 100}],
          [%{value: 0, position: 0}, %{value: 10, position: 800}]
        ],
        do: refute(changeset(points).valid?)

    assert changeset([%{value: 0, position: 720}, %{value: 100, position: 0}]).valid?
    assert changeset(@points).valid?
  end

  test "saving replaces the calibration and review is explicit" do
    axis = setup_axis()
    assert {:ok, cal} = Hardware.save_dial_calibration(axis, %{points: @points})
    refute cal.reviewed

    assert {:ok, cal} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    assert cal.reviewed and cal.valid

    assert {:ok, cal} =
             Hardware.save_dial_calibration(axis, %{
               points: [%{value: 0, position: 0}, %{value: 50, position: 300}]
             })

    refute cal.reviewed
    assert [_] = Repo.all(DialCalibration)
    assert {:error, %Ecto.Changeset{}} = Hardware.save_dial_calibration(axis, %{points: []})
  end

  test "an explicit reviewed: false clears the review even when nothing else changed" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})

    assert {:ok, cal} =
             Hardware.save_dial_calibration(axis, %{reviewed: false})

    refute cal.reviewed
    assert {:ok, %{reviewed: false}} = Hardware.get_dial_calibration(axis.id)

    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    assert {:ok, cal} = Hardware.save_dial_calibration(axis, %{reviewed: "false"})
    refute cal.reviewed
  end

  test "an explicit reviewed: false disables the bindings of the axis" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, train} = Train.create_train(%{name: "T", identifiers: [%{identifier: "T1"}]})

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "S",
        endpoint: "S",
        stepper_axis_id: axis.id,
        enabled: true
      })

    assert binding.enabled
    {:ok, _} = Hardware.save_dial_calibration(axis, %{reviewed: false})
    assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
  end

  test "axis limits are enforced for the calibration" do
    axis = setup_axis()
    wide = [%{value: 0, position: 0}, %{value: 100, position: axis.max_position + 1}]
    assert {:error, cs} = Hardware.save_dial_calibration(axis, %{points: wide})
    assert %{points: [_ | _]} = errors_on(cs)
  end

  test "an unreviewed save disables every binding on the axis, a reviewed one keeps them" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, train} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "S",
        endpoint: "S",
        stepper_axis_id: axis.id,
        enabled: true
      })

    assert binding.enabled
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    assert {:ok, %{enabled: true}} = Train.get_gauge_binding(binding.id)
    {:ok, _} = Hardware.save_dial_calibration(axis, %{output_unit: :mph, points: @points})
    assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
  end

  describe "fields that change what a stored position means" do
    for {field, value} <- [reverse: true, home_position: 10, motor_port: 2, home_direction: 1] do
      test "changing #{field} invalidates the dial and disables bindings" do
        axis = setup_axis()
        {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
        {:ok, train} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})

        {:ok, binding} =
          Train.create_gauge_binding(train.id, %{
            name: "S",
            endpoint: "S",
            stepper_axis_id: axis.id,
            enabled: true
          })

        {:ok, _} = Hardware.update_stepper_axis(axis, %{unquote(field) => unquote(value)})

        assert {:ok, %{valid: false, reviewed: false}} = Hardware.get_dial_calibration(axis.id)
        assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
      end
    end

    test "tuning homing backoff or speed keeps the reviewed dial" do
      axis = setup_axis()
      {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
      {:ok, _} = Hardware.update_stepper_axis(axis, %{home_backoff: 20, home_speed: 80})
      assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
    end
  end

  test "changing mode or soft limits invalidates the dial and disables all bindings" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, a} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})
    {:ok, b} = Train.create_train(%{name: "B", identifiers: [%{identifier: "B"}]})

    for train <- [a, b] do
      {:ok, _} =
        Train.create_gauge_binding(train.id, %{
          name: "S",
          endpoint: "S",
          stepper_axis_id: axis.id,
          enabled: true
        })
    end

    {:ok, _} = Hardware.update_stepper_axis(axis, %{max_position: 800})

    assert {:ok, %{valid: false, reviewed: false, points: [_, _]}} =
             Hardware.get_dial_calibration(axis.id)

    assert Enum.all?(
             [a, b],
             &Enum.all?(Train.list_gauge_bindings(&1.id), fn x -> not x.enabled end)
           )

    {:ok, cal} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    assert cal.valid and cal.reviewed
  end

  test "unrelated axis edits leave the dial alone" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, _} = Hardware.update_stepper_axis(axis, %{name: "Renamed"})
    assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
  end
end
