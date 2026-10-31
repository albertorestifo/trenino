defmodule Trenino.Repo.Migrations.MoveGaugeCalibrationToStepperAxes do
  @moduledoc """
  Moves the dial calibration (points, dial unit, validity, review) from each train's
  gauge binding to the stepper axis it drives.

  Up: every axis that has bindings gets one calibration. If all of its bindings carry
  the same points and unit, that calibration is kept, and stays reviewed only when
  every binding was reviewed and valid. If they disagree, the most recently updated
  binding wins, the calibration is marked unreviewed, the axis's bindings are disabled
  (they cannot run on an unreviewed dial) and a warning is logged.

  Down: copies each axis calibration back onto every binding of that axis, so a
  rollback of migrated data is lossless. Bindings of an axis with no calibration get
  empty points (unusable, disabled). Reviewed state and `enabled` are preserved.
  """
  use Ecto.Migration
  require Logger

  def up do
    create table(:hardware_stepper_dial_calibrations) do
      add :stepper_axis_id, references(:hardware_stepper_axes, on_delete: :delete_all),
        null: false

      add :output_unit, :string, null: false, default: "raw"
      add :valid, :boolean, null: false, default: true
      add :reviewed, :boolean, null: false, default: false
      add :points, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:hardware_stepper_dial_calibrations, [:stepper_axis_id])
    flush()

    rows =
      repo().query!("""
      SELECT id, stepper_axis_id, points, output_unit, calibration_valid,
             calibration_reviewed, updated_at
      FROM train_gauge_bindings
      ORDER BY stepper_axis_id, updated_at DESC, id DESC
      """).rows

    rows
    |> Enum.group_by(&Enum.at(&1, 1))
    |> Enum.each(fn {axis_id, bindings} -> migrate_axis(axis_id, bindings) end)

    alter table(:train_gauge_bindings) do
      remove :points
      remove :output_unit
      remove :calibration_valid
      remove :calibration_reviewed
    end
  end

  def down do
    alter table(:train_gauge_bindings) do
      add :points, :map, null: false, default: "[]"
      add :output_unit, :string, null: false, default: "raw"
      add :calibration_valid, :boolean, null: false, default: true
      add :calibration_reviewed, :boolean, null: false, default: false
    end

    flush()

    repo().query!("""
    UPDATE train_gauge_bindings SET
      points = (SELECT c.points FROM hardware_stepper_dial_calibrations c
                WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id),
      output_unit = (SELECT c.output_unit FROM hardware_stepper_dial_calibrations c
                     WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id),
      calibration_valid = (SELECT c.valid FROM hardware_stepper_dial_calibrations c
                           WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id),
      calibration_reviewed = (SELECT c.reviewed FROM hardware_stepper_dial_calibrations c
                              WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id)
    WHERE EXISTS (SELECT 1 FROM hardware_stepper_dial_calibrations c
                  WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id)
    """)

    repo().query!("""
    UPDATE train_gauge_bindings SET enabled = 0, output_unit = input_unit
    WHERE NOT EXISTS (SELECT 1 FROM hardware_stepper_dial_calibrations c
                      WHERE c.stepper_axis_id = train_gauge_bindings.stepper_axis_id)
    """)

    drop table(:hardware_stepper_dial_calibrations)
  end

  # Rows are newest first, so the head is the winner when the bindings disagree.
  defp migrate_axis(axis_id, [[_, _, points, unit, valid, _, _] = newest | _] = bindings) do
    decoded = decode(points)
    distinct = bindings |> Enum.map(&{normalize(Enum.at(&1, 2)), Enum.at(&1, 3)}) |> Enum.uniq()
    agree? = length(distinct) == 1

    {valid?, reviewed?} =
      if agree?,
        do: {Enum.all?(bindings, &truthy?(Enum.at(&1, 4))), Enum.all?(bindings, &truthy?(Enum.at(&1, 5)))},
        else: {truthy?(valid), false}

    unless agree? do
      Logger.warning(
        "Gauge calibration migration: stepper axis #{axis_id} had #{length(distinct)} " <>
          "different calibrations across its #{length(bindings)} bindings. Kept the one from " <>
          "binding #{hd(newest)} (most recently updated), marked it UNREVIEWED and disabled " <>
          "the axis's bindings. Review the dial calibration on the axis before enabling."
      )

      repo().query!("UPDATE train_gauge_bindings SET enabled = 0 WHERE stepper_axis_id = ?", [
        axis_id
      ])
    end

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    repo().query!(
      """
      INSERT INTO hardware_stepper_dial_calibrations
        (stepper_axis_id, output_unit, valid, reviewed, points, inserted_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      """,
      [axis_id, unit, bool(valid?), bool(reviewed?), Jason.encode!(decoded), now, now]
    )
  end

  defp normalize(json),
    do: json |> decode() |> Enum.map(&{&1["value"] * 1.0, &1["position"]})

  defp decode(json) when is_binary(json), do: Jason.decode!(json)
  defp decode(other), do: other
  defp truthy?(value), do: value in [1, true]
  defp bool(true), do: 1
  defp bool(false), do: 0
end
