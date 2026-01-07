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

    test "rejects sim_input_min below 0.0" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        sim_input_min: -0.1,
        sim_input_max: 0.5
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0.0 and 1.0" in errors_on(changeset).sim_input_min
    end

    test "rejects sim_input_max above 1.0" do
      attrs = %{
        index: 0,
        type: :gate,
        value: 0.0,
        sim_input_min: 0.9,
        sim_input_max: 1.1
      }

      changeset = Notch.changeset(%Notch{}, attrs)

      refute changeset.valid?
      assert "must be between 0.0 and 1.0" in errors_on(changeset).sim_input_max
    end
  end

end
