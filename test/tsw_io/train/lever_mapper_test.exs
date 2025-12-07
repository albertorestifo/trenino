defmodule TswIo.Train.LeverMapperTest do
  use TswIo.DataCase, async: true

  alias TswIo.Train.{LeverConfig, LeverMapper, Notch}

  describe "map_input/2 with positive simulator values" do
    setup do
      # Create a simple throttle with one linear notch spanning 0.0-1.0
      lever_config = %LeverConfig{
        id: 1,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps minimum input to minimum simulator value", %{lever_config: config} do
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.0)
    end

    test "maps maximum input to maximum simulator value", %{lever_config: config} do
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end

    test "interpolates mid-range values", %{lever_config: config} do
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      assert {:ok, 0.25} = LeverMapper.map_input(config, 0.25)
      assert {:ok, 0.75} = LeverMapper.map_input(config, 0.75)
    end
  end

  describe "map_input/2 with negative simulator values (reverser)" do
    setup do
      # Reverser: physical lever at 0.0 = -1.0, at 1.0 = +1.0
      lever_config = %LeverConfig{
        id: 2,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: -1.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps minimum input to negative simulator value", %{lever_config: config} do
      assert {:ok, -1.0} = LeverMapper.map_input(config, 0.0)
    end

    test "maps maximum input to positive simulator value", %{lever_config: config} do
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end

    test "maps middle input to neutral (0.0)", %{lever_config: config} do
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.5)
    end

    test "interpolates between negative and positive", %{lever_config: config} do
      # 25% of travel: -1.0 + (0.25 * 2.0) = -0.5
      assert {:ok, -0.5} = LeverMapper.map_input(config, 0.25)

      # 75% of travel: -1.0 + (0.75 * 2.0) = 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.75)
    end
  end

  describe "map_input/2 with all-negative simulator values (dynamic brake)" do
    setup do
      # Dynamic brake: -0.45 (full) to 0.0 (off)
      lever_config = %LeverConfig{
        id: 3,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: -0.45,
            max_value: 0.0,
            input_min: 0.0,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps minimum input to most negative value", %{lever_config: config} do
      assert {:ok, -0.45} = LeverMapper.map_input(config, 0.0)
    end

    test "maps maximum input to zero", %{lever_config: config} do
      assert {:ok, 0.0} = LeverMapper.map_input(config, 1.0)
    end

    test "interpolates in negative range", %{lever_config: config} do
      # 50% of travel: -0.45 + (0.5 * 0.45) = -0.225 -> rounds to -0.23
      assert {:ok, -0.23} = LeverMapper.map_input(config, 0.5)
    end
  end

  describe "map_input/2 with multiple notches" do
    setup do
      # Throttle with idle notch (0.0-0.25) and power notch (0.25-1.0)
      lever_config = %LeverConfig{
        id: 4,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 0.3,
            input_min: 0.0,
            input_max: 0.25
          },
          %Notch{
            index: 1,
            type: :linear,
            min_value: 0.3,
            max_value: 1.0,
            input_min: 0.25,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps values in first notch range", %{lever_config: config} do
      # At input 0.0, should be at min of first notch
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.0)

      # At input 0.125 (halfway through first notch), should be 0.15
      # Position within notch: (0.125 - 0.0) / (0.25 - 0.0) = 0.5
      # Value: 0.0 + (0.5 * 0.3) = 0.15
      assert {:ok, 0.15} = LeverMapper.map_input(config, 0.125)
    end

    test "maps values in second notch range", %{lever_config: config} do
      # At input 0.25, should be at min of second notch
      # Note: Boundary value goes to second notch since first is [0.0, 0.25)
      assert {:ok, 0.3} = LeverMapper.map_input(config, 0.25)

      # At input 0.625 (halfway through second notch)
      # Position: (0.625 - 0.25) / (1.0 - 0.25) = 0.5
      # Value: 0.3 + (0.5 * 0.7) = 0.65
      assert {:ok, 0.65} = LeverMapper.map_input(config, 0.625)
    end

    test "maps maximum value to final notch max", %{lever_config: config} do
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 with gate notches" do
    setup do
      # Reverser with three gate positions
      lever_config = %LeverConfig{
        id: 5,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: -1.0,
            input_min: 0.0,
            input_max: 0.33
          },
          %Notch{
            index: 1,
            type: :gate,
            value: 0.0,
            input_min: 0.33,
            input_max: 0.67
          },
          %Notch{
            index: 2,
            type: :gate,
            value: 1.0,
            input_min: 0.67,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns fixed value for gate notches", %{lever_config: config} do
      # First notch range
      assert {:ok, -1.0} = LeverMapper.map_input(config, 0.0)
      assert {:ok, -1.0} = LeverMapper.map_input(config, 0.16)
      assert {:ok, -1.0} = LeverMapper.map_input(config, 0.32)

      # Second notch range
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.33)
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.5)
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.66)

      # Third notch range
      assert {:ok, 1.0} = LeverMapper.map_input(config, 0.67)
      assert {:ok, 1.0} = LeverMapper.map_input(config, 0.84)
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 with partial notch coverage" do
    setup do
      # Lever where only middle portion is mapped (dead zones at ends)
      lever_config = %LeverConfig{
        id: 6,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.2,
            input_max: 0.8
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns error for input before first notch", %{lever_config: config} do
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.0)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.19)
    end

    test "maps values within notch range", %{lever_config: config} do
      assert {:ok, 0.0} = LeverMapper.map_input(config, 0.2)
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      # At 0.79 (near max), should be almost 1.0
      # Position: (0.79 - 0.2) / (0.8 - 0.2) = 0.59 / 0.6 = 0.983...
      {:ok, value} = LeverMapper.map_input(config, 0.79)
      assert value > 0.9
    end

    test "returns error for input at or after notch max", %{lever_config: config} do
      # Notch range is [0.2, 0.8) - exclusive on upper bound unless it's 1.0
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.8)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.81)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 with unmapped notches" do
    setup do
      # Notch exists but input range not yet calibrated
      lever_config = %LeverConfig{
        id: 7,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: nil,
            input_max: nil
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns error when no notches have input mapping", %{lever_config: config} do
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.0)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.5)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 edge cases" do
    setup do
      lever_config = %LeverConfig{
        id: 8,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "clamps out-of-range input values", %{lever_config: config} do
      # Values outside 0.0-1.0 get clamped but return :no_notch
      # This is expected behavior - hardware should never send these
      assert {:error, :no_notch} = LeverMapper.map_input(config, -0.5)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 1.5)
    end

    test "handles very small differences in input values", %{lever_config: config} do
      # Precision testing
      assert {:ok, 0.01} = LeverMapper.map_input(config, 0.01)
      assert {:ok, 0.99} = LeverMapper.map_input(config, 0.99)
    end
  end

  describe "find_notch/2" do
    test "finds notch containing input value" do
      notches = [
        %Notch{input_min: 0.0, input_max: 0.5},
        %Notch{input_min: 0.5, input_max: 1.0}
      ]

      assert %Notch{input_min: 0.0} = LeverMapper.find_notch(notches, 0.25)
      assert %Notch{input_min: 0.5} = LeverMapper.find_notch(notches, 0.75)
    end

    test "handles boundary value at 1.0" do
      notches = [
        %Notch{input_min: 0.0, input_max: 1.0}
      ]

      # Exact 1.0 should match
      assert %Notch{} = LeverMapper.find_notch(notches, 1.0)
    end

    test "returns nil when no notch matches" do
      notches = [
        %Notch{input_min: 0.2, input_max: 0.8}
      ]

      assert nil == LeverMapper.find_notch(notches, 0.1)
      assert nil == LeverMapper.find_notch(notches, 0.9)
    end

    test "ignores notches with nil input ranges" do
      notches = [
        %Notch{input_min: nil, input_max: nil},
        %Notch{input_min: 0.0, input_max: 1.0}
      ]

      assert %Notch{input_min: 0.0} = LeverMapper.find_notch(notches, 0.5)
    end
  end

  describe "calculate_value/2" do
    test "returns fixed value for gate notch" do
      notch = %Notch{type: :gate, value: 0.5}

      assert {:ok, 0.5} = LeverMapper.calculate_value(notch, 0.0)
      assert {:ok, 0.5} = LeverMapper.calculate_value(notch, 1.0)
    end

    test "interpolates value for linear notch" do
      notch = %Notch{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: 0.0,
        input_max: 1.0
      }

      assert {:ok, 0.0} = LeverMapper.calculate_value(notch, 0.0)
      assert {:ok, 0.5} = LeverMapper.calculate_value(notch, 0.5)
      assert {:ok, 1.0} = LeverMapper.calculate_value(notch, 1.0)
    end

    test "interpolates with negative values" do
      notch = %Notch{
        type: :linear,
        min_value: -1.0,
        max_value: 1.0,
        input_min: 0.0,
        input_max: 1.0
      }

      assert {:ok, -1.0} = LeverMapper.calculate_value(notch, 0.0)
      assert {:ok, 0.0} = LeverMapper.calculate_value(notch, 0.5)
      assert {:ok, 1.0} = LeverMapper.calculate_value(notch, 1.0)
    end

    test "returns error when notch lacks required fields" do
      # Gate notch without value
      notch = %Notch{type: :gate, value: nil}
      assert {:error, :unmapped_notch} = LeverMapper.calculate_value(notch, 0.5)

      # Linear notch without min_value
      notch = %Notch{
        type: :linear,
        min_value: nil,
        max_value: 1.0,
        input_min: 0.0,
        input_max: 1.0
      }

      assert {:error, :unmapped_notch} = LeverMapper.calculate_value(notch, 0.5)
    end
  end
end
