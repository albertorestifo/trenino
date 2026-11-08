defmodule Trenino.Hardware.DialCalibrationTest do
  use Trenino.DataCase, async: true
  alias Trenino.GaugeFixtures
  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train
  alias Trenino.Train.GaugeMapper

  @points [%{value: 0, position: 0}, %{value: 100, position: 720}]

  defp changeset(points, gauge \\ %Gauge{id: 1, travel: 720}),
    do:
      DialCalibration.changeset(
        %DialCalibration{gauge_id: 1, points: []},
        %{points: points},
        gauge
      )

  defp setup_axis do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    GaugeFixtures.gauge_fixture(device.id, %{travel: 720})
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
        gauge_id: axis.id,
        enabled: true
      })

    assert binding.enabled
    {:ok, _} = Hardware.save_dial_calibration(axis, %{reviewed: false})
    assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
  end

  test "positions must lie within the gauge travel" do
    axis = setup_axis()
    wide = [%{value: 0, position: 0}, %{value: 100, position: axis.travel + 1}]
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
        gauge_id: axis.id,
        enabled: true
      })

    assert binding.enabled
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    assert {:ok, %{enabled: true}} = Train.get_gauge_binding(binding.id)
    {:ok, _} = Hardware.save_dial_calibration(axis, %{output_unit: :mph, points: @points})
    assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
  end

  describe "fields that change what a stored position means" do
    for {field, value} <- [
          reverse: true,
          pins: [9, 10, 6, 255],
          driver: :direct
        ] do
      test "changing #{field} deletes the dial and disables bindings" do
        axis = setup_axis()
        {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
        {:ok, train} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})

        {:ok, binding} =
          Train.create_gauge_binding(train.id, %{
            name: "S",
            endpoint: "S",
            gauge_id: axis.id,
            enabled: true
          })

        attrs =
          if unquote(field) == :driver,
            do: %{driver: :direct, pins: [9, 10, 14, 15], max_speed: 1800},
            else: %{unquote(field) => unquote(Macro.escape(value))}

        {:ok, _} = Hardware.update_gauge(axis, attrs)

        assert {:error, :not_found} = Hardware.get_dial_calibration(axis.id)
        assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
      end
    end

    test "speed and acceleration keep the reviewed dial" do
      axis = setup_axis()
      {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
      {:ok, _} = Hardware.update_gauge(axis, %{max_speed: 3000, acceleration: 20_000})
      assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
    end
  end

  test "shrinking travel past a saved point deletes the dial and disables all bindings" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, a} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})
    {:ok, b} = Train.create_train(%{name: "B", identifiers: [%{identifier: "B"}]})

    for train <- [a, b] do
      {:ok, _} =
        Train.create_gauge_binding(train.id, %{
          name: "S",
          endpoint: "S",
          gauge_id: axis.id,
          enabled: true
        })
    end

    {:ok, _} = Hardware.update_gauge(axis, %{travel: 700})

    assert {:error, :not_found} = Hardware.get_dial_calibration(axis.id)

    assert Enum.all?(
             [a, b],
             &Enum.all?(Train.list_gauge_bindings(&1.id), fn x -> not x.enabled end)
           )
  end

  test "allowing more travel keeps the reviewed dial and its bindings" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, train} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "S",
        endpoint: "S",
        gauge_id: axis.id,
        enabled: true
      })

    {:ok, _} = Hardware.update_gauge(axis, %{travel: 3780})
    assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
    assert {:ok, %{enabled: true}} = Train.get_gauge_binding(binding.id)
  end

  test "unrelated gauge edits leave the dial alone" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, _} = Hardware.update_gauge(axis, %{name: "Renamed"})
    assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
  end

  test "a gauge whose dial is not valid maps nothing" do
    axis = setup_axis()
    {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @points, reviewed: true})
    {:ok, train} = Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{name: "S", endpoint: "S", gauge_id: axis.id})

    {:ok, gauge} = Hardware.get_gauge(axis.id)
    invalid = %{gauge | dial_calibration: %{gauge.dial_calibration | valid: false}}
    assert {:error, :invalid_calibration_or_limits} = GaugeMapper.map(binding, 50, invalid)
  end
end
