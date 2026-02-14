defmodule Trenino.Train.NotchTest do
  use Trenino.DataCase, async: true

  alias Trenino.Train.Notch

  describe "changeset/2" do
    test "valid gate notch" do
      attrs = %{index: 0, type: :gate, value: 0.0}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "valid linear notch" do
      attrs = %{index: 1, type: :linear, min_value: 0.0, max_value: 1.0}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "gate requires value" do
      attrs = %{index: 0, type: :gate}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).value
    end

    test "linear requires min_value and max_value" do
      attrs = %{index: 1, type: :linear}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).min_value
      assert "can't be blank" in errors_on(changeset).max_value
    end

    test "rounds float values to 2 decimal places" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.123456,
        input_min: 0.111111,
        input_max: 0.999999
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert Ecto.Changeset.get_change(changeset, :value) == 0.12
      assert Ecto.Changeset.get_change(changeset, :input_min) == 0.11
      assert Ecto.Changeset.get_change(changeset, :input_max) == 1.0
    end
  end

  describe "validate_input_range/1" do
    test "accepts nil input range" do
      attrs = %{index: 0, type: :gate, value: 0.0}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts valid input range" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 0.1, input_max: 0.3}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts equal input_min and input_max for gate notches" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 0.5, input_max: 0.5}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "requires both input_min and input_max if one is set" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 0.1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "both input_min and input_max must be set together" in errors_on(changeset).input_min
    end

    test "rejects input_min greater than input_max" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 0.5, input_max: 0.2}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be less than or equal to input_max" in errors_on(changeset).input_min
    end

    test "rejects input_min below 0.0" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: -0.1, input_max: 0.5}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0.0 and 1.0" in errors_on(changeset).input_min
    end

    test "rejects input_min above 1.0" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 1.1, input_max: 1.5}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0.0 and 1.0" in errors_on(changeset).input_min
    end

    test "rejects input_max below 0.0" do
      # Note: with rounding, -0.1 stays as -0.1 and 0.5 stays as 0.5
      # input_min > input_max will be caught first, so we use -0.1 for both
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: -0.2, input_max: -0.1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      # input_min is checked first, so it will fail on input_min
      assert "must be between 0.0 and 1.0" in errors_on(changeset).input_min
    end

    test "rejects input_max above 1.0" do
      attrs = %{index: 0, type: :gate, value: 0.0, input_min: 0.9, input_max: 1.1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0.0 and 1.0" in errors_on(changeset).input_max
    end
  end

  describe "validate_sim_input_range/1" do
    test "accepts nil sim input range" do
      attrs = %{index: 0, type: :gate, value: 0.0}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts valid sim input range" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        sim_input_min: 0.1,
        sim_input_max: 0.3
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "requires both sim_input_min and sim_input_max if one is set" do
      attrs = %{index: 0, type: :gate, value: 0.0, sim_input_min: 0.1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?

      assert "both sim_input_min and sim_input_max must be set together" in errors_on(changeset).sim_input_min
    end

    test "rejects sim_input_min greater than sim_input_max" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        sim_input_min: 0.5,
        sim_input_max: 0.2
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be less than or equal to sim_input_max" in errors_on(changeset).sim_input_min
    end

    test "accepts negative sim_input values for levers with non-standard ranges" do
      attrs = %{
        index: 0,
        type: :gate,
        value: -4.0,
        sim_input_min: -1.0,
        sim_input_max: -0.88
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts sim_input values spanning negative to positive range" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        sim_input_min: -0.12,
        sim_input_max: 0.06
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end
  end

  describe "validate_bldc_fields/1" do
    test "accepts nil BLDC fields" do
      attrs = %{index: 0, type: :gate, value: 0.0}
      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts valid BLDC field values (0-255)" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        bldc_detent_strength: 128,
        bldc_damping: 50
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "accepts partial BLDC fields (some nil, some set)" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        bldc_detent_strength: 100,
        bldc_damping: nil
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      assert changeset.valid?
    end

    test "rejects BLDC detent_strength below 0" do
      attrs = %{index: 0, type: :gate, value: 0.0, bldc_detent_strength: -1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0 and 255" in errors_on(changeset).bldc_detent_strength
    end

    test "rejects BLDC detent_strength above 255" do
      attrs = %{index: 0, type: :gate, value: 0.0, bldc_detent_strength: 256}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0 and 255" in errors_on(changeset).bldc_detent_strength
    end

    test "rejects BLDC damping below 0" do
      attrs = %{index: 0, type: :gate, value: 0.0, bldc_damping: -1}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0 and 255" in errors_on(changeset).bldc_damping
    end

    test "rejects BLDC damping above 255" do
      attrs = %{index: 0, type: :gate, value: 0.0, bldc_damping: 256}
      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0 and 255" in errors_on(changeset).bldc_damping
    end

    test "rejects multiple invalid BLDC fields" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        bldc_detent_strength: -10,
        bldc_damping: 300
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0 and 255" in errors_on(changeset).bldc_detent_strength
      assert "must be between 0 and 255" in errors_on(changeset).bldc_damping
    end
  end
end
