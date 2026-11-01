defmodule Trenino.Repo.MoveGaugeCalibrationMigrationTest do
  # Runs the real migration down and up inside the sandbox transaction (SQLite DDL is
  # transactional), so the old column layout is seeded with raw SQL.
  use Trenino.DataCase, async: false
  import ExUnit.CaptureLog
  alias Trenino.{Hardware, Repo, Train}

  @version 20_261_101_090_000
  @path "priv/repo/migrations/20261101090000_move_gauge_calibration_to_stepper_axes.exs"
  @real_points [
    %{"value" => 0, "position" => 0},
    %{"value" => 20, "position" => 140},
    %{"value" => 40, "position" => 280},
    %{"value" => 60, "position" => 424},
    %{"value" => 80, "position" => 563},
    %{"value" => 100, "position" => 714}
  ]

  setup_all do
    [{module, _}] = Code.compile_file(@path)
    %{migration: module}
  end

  setup %{migration: module} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, one} = Train.create_train(%{name: "One", identifiers: [%{identifier: "One"}]})
    {:ok, two} = Train.create_train(%{name: "Two", identifiers: [%{identifier: "Two"}]})
    migrate(module, :down)
    %{axis: axis, one: one, two: two, migration: module}
  end

  defp migrate(module, direction),
    do: Ecto.Migrator.run(Repo, [{@version, module}], direction, all: true, log: false)

  # Old layout row; `updated` orders "most recently updated".
  defp old_binding(train, axis, points, opts) do
    Repo.query!(
      """
      INSERT INTO train_gauge_bindings
        (train_id, stepper_axis_id, name, endpoint, input_unit, output_unit, out_of_range,
         inactive_behavior, points, enabled, calibration_valid, calibration_reviewed,
         inserted_at, updated_at)
      VALUES (?, ?, 'Speed', 'Speed', 'mps', ?, 'clamp', 'hold', ?, ?, 1, ?, ?, ?)
      """,
      [
        train.id,
        axis.id,
        Keyword.get(opts, :unit, "mph"),
        Jason.encode!(points),
        bool(Keyword.get(opts, :enabled, true)),
        bool(Keyword.get(opts, :reviewed, true)),
        Keyword.fetch!(opts, :updated),
        Keyword.fetch!(opts, :updated)
      ]
    )
  end

  defp bool(true), do: 1
  defp bool(false), do: 0

  defp calibrations(axis) do
    %{rows: rows} =
      Repo.query!(
        "SELECT points, output_unit, valid, reviewed FROM hardware_stepper_dial_calibrations WHERE stepper_axis_id = ?",
        [axis.id]
      )

    rows
  end

  defp enabled_flags(axis) do
    %{rows: rows} =
      Repo.query!("SELECT enabled FROM train_gauge_bindings WHERE stepper_axis_id = ?", [axis.id])

    Enum.map(rows, &hd/1)
  end

  test "identical reviewed tables become one reviewed axis calibration", ctx do
    float_points = Enum.map(@real_points, &Map.update!(&1, "value", fn v -> v * 1.0 end))
    old_binding(ctx.one, ctx.axis, @real_points, updated: "2026-10-30 10:00:00")
    old_binding(ctx.two, ctx.axis, float_points, updated: "2026-10-31 10:00:00")

    log = capture_log(fn -> migrate(ctx.migration, :up) end)

    assert [[points, "mph", valid, reviewed]] = calibrations(ctx.axis)

    assert Jason.decode!(points) |> Enum.map(&{&1["value"], &1["position"]}) ==
             [{0, 0}, {20, 140}, {40, 280}, {60, 424}, {80, 563}, {100, 714}]

    assert valid in [1, true] and reviewed in [1, true]
    assert enabled_flags(ctx.axis) == [1, 1]
    refute log =~ "different calibrations"

    assert {:ok, cal} = Hardware.get_dial_calibration(ctx.axis.id)
    assert cal.reviewed and cal.valid
    assert [%{value: 100.0, position: 714}] = Enum.take(cal.points, -1)
    assert cal.output_unit == :mph
  end

  test "disagreeing tables keep the newest, unreviewed, disable bindings and log a note", ctx do
    newer = [%{"value" => 0, "position" => 0}, %{"value" => 120, "position" => 700}]
    old_binding(ctx.one, ctx.axis, @real_points, updated: "2026-10-30 10:00:00")
    old_binding(ctx.two, ctx.axis, newer, updated: "2026-10-31 10:00:00")

    log = capture_log(fn -> migrate(ctx.migration, :up) end)

    assert [[points, "mph", _valid, reviewed]] = calibrations(ctx.axis)
    assert Jason.decode!(points) |> Enum.map(& &1["position"]) == [0, 700]
    assert reviewed in [0, false]
    assert enabled_flags(ctx.axis) == [0, 0]
    assert log =~ "axis #{ctx.axis.id}"
    assert log =~ "UNREVIEWED"
  end

  test "identical tables where one binding was unreviewed stay unreviewed", ctx do
    old_binding(ctx.one, ctx.axis, @real_points, updated: "2026-10-30 10:00:00")
    old_binding(ctx.two, ctx.axis, @real_points, updated: "2026-10-31 10:00:00", reviewed: false)
    migrate(ctx.migration, :up)
    assert [[_, "mph", _, reviewed]] = calibrations(ctx.axis)
    assert reviewed in [0, false]
  end

  test "an axis without bindings gets no calibration", ctx do
    migrate(ctx.migration, :up)
    assert calibrations(ctx.axis) == []
  end

  test "rollback copies the axis dial back onto every binding losslessly", ctx do
    old_binding(ctx.one, ctx.axis, @real_points, updated: "2026-10-30 10:00:00")
    old_binding(ctx.two, ctx.axis, @real_points, updated: "2026-10-31 10:00:00")
    migrate(ctx.migration, :up)
    migrate(ctx.migration, :down)

    %{rows: rows} =
      Repo.query!(
        "SELECT points, output_unit, calibration_valid, calibration_reviewed, enabled FROM train_gauge_bindings"
      )

    assert length(rows) == 2

    for [points, "mph", valid, reviewed, enabled] <- rows do
      assert length(Jason.decode!(points)) == 6
      assert valid in [1, true] and reviewed in [1, true] and enabled in [1, true]
    end

    migrate(ctx.migration, :up)
    assert [[_, "mph", _, reviewed]] = calibrations(ctx.axis)
    assert reviewed in [1, true]
  end
end
