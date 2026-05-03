defmodule Trenino.Train.LeverMapperTest do
  use Trenino.DataCase, async: true

  alias Trenino.Train.{LeverConfig, LeverMapper, Notch}

  describe "map_input/2 with full range linear notch" do
    setup do
      # Simple throttle: hardware 0-1 maps to simulator InputValue 0-1
      lever_config = %LeverConfig{
        id: 1,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps minimum input to minimum simulator InputValue", %{lever_config: config} do
      assert {:ok, +0.0} = LeverMapper.map_input(config, 0.0)
    end

    test "maps maximum input to maximum simulator InputValue", %{lever_config: config} do
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end

    test "interpolates mid-range values", %{lever_config: config} do
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      assert {:ok, 0.25} = LeverMapper.map_input(config, 0.25)
      assert {:ok, 0.75} = LeverMapper.map_input(config, 0.75)
    end
  end

  describe "map_input/2 with scaled simulator input range" do
    setup do
      # Hardware 0-1 maps to simulator InputValue 0.2-0.8
      lever_config = %LeverConfig{
        id: 2,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.2,
            sim_input_max: 0.8
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps minimum input to sim_input_min", %{lever_config: config} do
      assert {:ok, 0.2} = LeverMapper.map_input(config, 0.0)
    end

    test "maps maximum input to sim_input_max", %{lever_config: config} do
      assert {:ok, 0.8} = LeverMapper.map_input(config, 1.0)
    end

    test "interpolates within simulator input range", %{lever_config: config} do
      # 50% of hardware = 0.2 + 0.5 * (0.8 - 0.2) = 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      # 25% of hardware = 0.2 + 0.25 * 0.6 = 0.35
      assert {:ok, 0.35} = LeverMapper.map_input(config, 0.25)
    end
  end

  describe "map_input/2 with MasterController-like notches" do
    setup do
      # Simulating MasterController: Gate - Linear - Gate - Linear
      lever_config = %LeverConfig{
        id: 3,
        notches: [
          # Emergency brake gate at position 0-5%
          %Notch{
            index: 0,
            type: :gate,
            value: -11.0,
            input_min: 0.0,
            input_max: 0.05,
            sim_input_min: 0.0,
            sim_input_max: 0.04
          },
          # Braking linear zone 5%-45%
          %Notch{
            index: 1,
            type: :linear,
            min_value: -10.0,
            max_value: -0.91,
            input_min: 0.05,
            input_max: 0.45,
            sim_input_min: 0.05,
            sim_input_max: 0.44
          },
          # Neutral gate at 45%-55%
          %Notch{
            index: 2,
            type: :gate,
            value: 0.0,
            input_min: 0.45,
            input_max: 0.55,
            sim_input_min: 0.49,
            sim_input_max: 0.51
          },
          # Power linear zone 55%-100%
          %Notch{
            index: 3,
            type: :linear,
            min_value: 1.0,
            max_value: 10.0,
            input_min: 0.55,
            input_max: 1.0,
            sim_input_min: 0.56,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "maps emergency gate to center of sim_input range", %{lever_config: config} do
      # Center of 0.0-0.04 = 0.02
      assert {:ok, 0.02} = LeverMapper.map_input(config, 0.0)
      assert {:ok, 0.02} = LeverMapper.map_input(config, 0.02)
    end

    test "maps braking zone with interpolation", %{lever_config: config} do
      # At input 0.05 (start of braking), should be at sim_input_min 0.05
      assert {:ok, 0.05} = LeverMapper.map_input(config, 0.05)

      # At input 0.25 (halfway through braking)
      # Position: (0.25 - 0.05) / (0.45 - 0.05) = 0.5
      # Sim: 0.05 + 0.5 * (0.44 - 0.05) = 0.05 + 0.195 = 0.245
      {:ok, value} = LeverMapper.map_input(config, 0.25)
      assert_in_delta value, 0.25, 0.02
    end

    test "maps neutral gate to center of sim_input range", %{lever_config: config} do
      # Center of 0.49-0.51 = 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
    end

    test "maps power zone with interpolation", %{lever_config: config} do
      # At input 0.55 (start of power), should be at sim_input_min 0.56
      assert {:ok, 0.56} = LeverMapper.map_input(config, 0.55)

      # At input 1.0 (max power), should be at sim_input_max 1.0
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 with gate notches" do
    setup do
      # Discrete reverser with three gate positions
      lever_config = %LeverConfig{
        id: 5,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: -1.0,
            input_min: 0.0,
            input_max: 0.33,
            sim_input_min: 0.0,
            sim_input_max: 0.1
          },
          %Notch{
            index: 1,
            type: :gate,
            value: 0.0,
            input_min: 0.33,
            input_max: 0.67,
            sim_input_min: 0.45,
            sim_input_max: 0.55
          },
          %Notch{
            index: 2,
            type: :gate,
            value: 1.0,
            input_min: 0.67,
            input_max: 1.0,
            sim_input_min: 0.9,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns center of sim_input range for gate notches", %{lever_config: config} do
      # First gate: center of 0.0-0.1 = 0.05
      assert {:ok, 0.05} = LeverMapper.map_input(config, 0.0)
      assert {:ok, 0.05} = LeverMapper.map_input(config, 0.16)
      assert {:ok, 0.05} = LeverMapper.map_input(config, 0.32)

      # Second gate: center of 0.45-0.55 = 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.33)
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)

      # Third gate: center of 0.9-1.0 = 0.95
      assert {:ok, 0.95} = LeverMapper.map_input(config, 0.67)
      assert {:ok, 0.95} = LeverMapper.map_input(config, 1.0)
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
            input_max: 0.8,
            sim_input_min: 0.0,
            sim_input_max: 1.0
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
      assert {:ok, +0.0} = LeverMapper.map_input(config, 0.2)
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      # At 0.79: position = (0.79-0.2)/(0.8-0.2) = 0.983, sim = 0.98
      {:ok, value} = LeverMapper.map_input(config, 0.79)
      assert value > 0.9
    end

    test "returns error for input at or after notch max", %{lever_config: config} do
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.8)
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
            input_max: nil,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns error when no notches have hardware input mapping", %{lever_config: config} do
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.0)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 0.5)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 1.0)
    end
  end

  describe "map_input/2 with no sim_input_range" do
    setup do
      # Notch has hardware input range but no sim_input range
      lever_config = %LeverConfig{
        id: 8,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: nil,
            sim_input_max: nil
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "returns error when no sim_input_range", %{lever_config: config} do
      assert {:error, :no_sim_input_range} = LeverMapper.map_input(config, 0.5)
    end
  end

  describe "map_input/2 edge cases" do
    setup do
      lever_config = %LeverConfig{
        id: 9,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "clamps out-of-range input values", %{lever_config: config} do
      assert {:error, :no_notch} = LeverMapper.map_input(config, -0.5)
      assert {:error, :no_notch} = LeverMapper.map_input(config, 1.5)
    end

    test "handles very small differences in input values", %{lever_config: config} do
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

      notch1 = LeverMapper.find_notch(notches, 0.25)
      assert notch1.input_min == 0.0
      notch2 = LeverMapper.find_notch(notches, 0.75)
      assert notch2.input_min == 0.5
    end

    test "handles boundary value at 1.0" do
      notches = [
        %Notch{input_min: 0.0, input_max: 1.0}
      ]

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

      notch = LeverMapper.find_notch(notches, 0.5)
      assert notch.input_min == 0.0
    end
  end

  describe "calculate_sim_input/2" do
    test "returns center of sim_input range for gate notch" do
      notch = %Notch{type: :gate, value: 0.5, sim_input_min: 0.4, sim_input_max: 0.6}

      # Center of 0.4-0.6 = 0.5
      assert {:ok, 0.5} = LeverMapper.calculate_sim_input(notch, 0.0)
      assert {:ok, 0.5} = LeverMapper.calculate_sim_input(notch, 1.0)
    end

    test "interpolates sim_input for linear notch" do
      notch = %Notch{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: 0.0,
        input_max: 1.0,
        sim_input_min: 0.2,
        sim_input_max: 0.8
      }

      assert {:ok, 0.2} = LeverMapper.calculate_sim_input(notch, 0.0)
      assert {:ok, 0.5} = LeverMapper.calculate_sim_input(notch, 0.5)
      assert {:ok, 0.8} = LeverMapper.calculate_sim_input(notch, 1.0)
    end

    test "returns error when notch lacks sim_input fields" do
      # Gate notch without sim_input_min
      notch = %Notch{type: :gate, value: 0.5, sim_input_min: nil, sim_input_max: 0.6}
      assert {:error, :no_sim_input_range} = LeverMapper.calculate_sim_input(notch, 0.5)

      # Linear notch without sim_input_max
      notch = %Notch{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: 0.0,
        input_max: 1.0,
        sim_input_min: 0.0,
        sim_input_max: nil
      }

      assert {:error, :no_sim_input_range} = LeverMapper.calculate_sim_input(notch, 0.5)
    end

    test "returns error when notch lacks input_min/max fields" do
      notch = %Notch{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: nil,
        input_max: 1.0,
        sim_input_min: 0.0,
        sim_input_max: 1.0
      }

      assert {:error, :unmapped_notch} = LeverMapper.calculate_sim_input(notch, 0.5)
    end
  end

  describe "map_input/2 with inverted lever" do
    setup do
      # Lever covers full range with inversion enabled
      # Hardware 0.0 should map like hardware 1.0 would normally
      lever_config = %LeverConfig{
        id: 10,
        inverted: true,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: 0.0,
            max_value: 1.0,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "inverts hardware input before mapping", %{lever_config: config} do
      # Hardware 0.0 -> inverted to 1.0 -> maps to sim 1.0
      assert {:ok, 1.0} = LeverMapper.map_input(config, 0.0)
      # Hardware 1.0 -> inverted to 0.0 -> maps to sim 0.0
      assert {:ok, +0.0} = LeverMapper.map_input(config, 1.0)
    end

    test "inverts mid-range values correctly", %{lever_config: config} do
      # Hardware 0.25 -> inverted to 0.75 -> maps to sim 0.75
      assert {:ok, 0.75} = LeverMapper.map_input(config, 0.25)
      # Hardware 0.5 -> inverted to 0.5 -> maps to sim 0.5 (midpoint unchanged)
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
      # Hardware 0.75 -> inverted to 0.25 -> maps to sim 0.25
      assert {:ok, 0.25} = LeverMapper.map_input(config, 0.75)
    end
  end

  describe "map_input/2 with inverted false (default)" do
    test "does not invert when inverted is false" do
      config = %LeverConfig{
        id: 11,
        inverted: false,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      # Hardware 0.0 -> maps to sim 0.0 (no inversion)
      assert {:ok, +0.0} = LeverMapper.map_input(config, 0.0)
      # Hardware 1.0 -> maps to sim 1.0 (no inversion)
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end

    test "does not invert when inverted is nil" do
      config = %LeverConfig{
        id: 12,
        inverted: nil,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            input_min: 0.0,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 1.0
          }
        ]
      }

      # Hardware 0.0 -> maps to sim 0.0 (no inversion)
      assert {:ok, +0.0} = LeverMapper.map_input(config, 0.0)
    end
  end

  describe "map_input/2 with inverted forward-layout multi-notch lever" do
    setup do
      # Forward layout: low input = low sim, high input = high sim
      # Braking (0.0-0.45), Neutral gate (0.45-0.55), Power (0.55-1.0)
      lever_config = %LeverConfig{
        id: 13,
        inverted: true,
        notches: [
          %Notch{
            index: 0,
            type: :linear,
            min_value: -10.0,
            max_value: 0.0,
            input_min: 0.0,
            input_max: 0.45,
            sim_input_min: 0.0,
            sim_input_max: 0.45
          },
          %Notch{
            index: 1,
            type: :gate,
            value: 0.0,
            input_min: 0.45,
            input_max: 0.55,
            sim_input_min: 0.45,
            sim_input_max: 0.55
          },
          %Notch{
            index: 2,
            type: :linear,
            min_value: 0.0,
            max_value: 10.0,
            input_min: 0.55,
            input_max: 1.0,
            sim_input_min: 0.55,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "forward layout is not reversed", %{lever_config: config} do
      refute LeverMapper.reversed_layout?(config.notches)
    end

    test "hardware 0.0 maps to full power (sim 1.0) when inverted", %{lever_config: config} do
      # Hardware 0.0 -> effective 1.0 -> power notch -> sim 1.0
      assert {:ok, 1.0} = LeverMapper.map_input(config, 0.0)
    end

    test "hardware 1.0 maps to start of braking (sim 0.0) when inverted", %{lever_config: config} do
      # Hardware 1.0 -> effective 0.0 -> braking notch -> sim 0.0
      assert {:ok, +0.0} = LeverMapper.map_input(config, 1.0)
    end

    test "hardware at neutral position maps correctly when inverted", %{lever_config: config} do
      # Hardware 0.5 -> effective 0.5 -> neutral gate -> sim 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
    end

    test "interpolates correctly within braking notch when inverted", %{lever_config: config} do
      # Hardware 0.78 -> effective 0.22 -> braking notch
      # Position in braking: (0.22 - 0.0) / 0.45 = 0.489
      # Sim: 0.0 + 0.489 * 0.45 = 0.22
      {:ok, value} = LeverMapper.map_input(config, 0.78)
      assert_in_delta value, 0.22, 0.01
    end

    test "interpolates correctly within power notch when inverted", %{lever_config: config} do
      # Hardware 0.22 -> effective 0.78 -> power notch
      # Position in power: (0.78 - 0.55) / 0.45 = 0.511
      # Sim: 0.55 + 0.511 * 0.45 = 0.78
      {:ok, value} = LeverMapper.map_input(config, 0.22)
      assert_in_delta value, 0.78, 0.01
    end

    test "start of power notch maps correctly when inverted", %{lever_config: config} do
      # Hardware 0.45 -> effective 0.55 -> power notch start -> sim 0.55
      assert {:ok, 0.55} = LeverMapper.map_input(config, 0.45)
    end

    test "end of braking notch maps correctly when inverted", %{lever_config: config} do
      # Hardware 0.55 -> effective 0.45 -> neutral gate -> sim 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.55)
    end
  end

  describe "map_input/2 with inverted reversed-layout multi-notch lever (M9-A style)" do
    setup do
      # Reversed layout: high input = low sim (Emergency), low input = high sim (Power)
      # This is like the M9-A MasterController
      lever_config = %LeverConfig{
        id: 14,
        inverted: true,
        notches: [
          # Emergency at high input (0.99-1.0) -> low sim (0.0-0.04)
          %Notch{
            index: 0,
            type: :gate,
            value: -2,
            input_min: 0.99,
            input_max: 1.0,
            sim_input_min: 0.0,
            sim_input_max: 0.04
          },
          # Braking linear (0.56-0.96) -> sim (0.06-0.44)
          %Notch{
            index: 1,
            type: :linear,
            min_value: -1,
            max_value: -0.25,
            input_min: 0.56,
            input_max: 0.96,
            sim_input_min: 0.06,
            sim_input_max: 0.44
          },
          # Cut-out gate (0.5-0.51) -> sim (0.46-0.54)
          %Notch{
            index: 2,
            type: :gate,
            value: 0,
            input_min: 0.5,
            input_max: 0.51,
            sim_input_min: 0.46,
            sim_input_max: 0.54
          },
          # Power at low input (0.0-0.45) -> high sim (0.56-1.0)
          %Notch{
            index: 3,
            type: :linear,
            min_value: 0.25,
            max_value: 1,
            input_min: 0.0,
            input_max: 0.45,
            sim_input_min: 0.56,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "reversed layout is detected correctly", %{lever_config: config} do
      assert LeverMapper.reversed_layout?(config.notches)
    end

    test "hardware 0.0 (physical Emergency) maps to Emergency gate", %{lever_config: config} do
      # Hardware 0.0 -> effective 1.0 -> Emergency gate (0.99-1.0) -> sim ~0.02
      assert {:ok, 0.02} = LeverMapper.map_input(config, 0.0)
    end

    test "hardware 0.5 (physical Cut-out) maps to Cut-out gate", %{lever_config: config} do
      # Hardware 0.5 -> effective 0.5 -> Cut-out gate -> sim 0.5
      assert {:ok, 0.5} = LeverMapper.map_input(config, 0.5)
    end

    test "hardware 1.0 (physical Max Power) maps to max power", %{lever_config: config} do
      # Hardware 1.0 -> effective 0.0 -> Power notch, with position inversion -> sim 1.0
      assert {:ok, 1.0} = LeverMapper.map_input(config, 1.0)
    end

    test "power increases as user moves from Cut-out toward Max Power", %{lever_config: config} do
      # User moves physical lever from Cut-out (hw 0.5) toward Max Power (hw 1.0)
      # Power should steadily increase from ~0.56 to 1.0
      {:ok, sim_at_cutout} = LeverMapper.map_input(config, 0.5)
      {:ok, sim_mid_power} = LeverMapper.map_input(config, 0.75)
      {:ok, sim_max_power} = LeverMapper.map_input(config, 1.0)

      assert sim_at_cutout == 0.5
      assert sim_mid_power > sim_at_cutout
      assert sim_max_power > sim_mid_power
      assert sim_max_power == 1.0
    end

    test "braking increases as user moves from Cut-out toward Emergency", %{lever_config: config} do
      # User moves physical lever from Cut-out (hw 0.5) toward Emergency (hw 0.0)
      # Braking should increase (sim should decrease toward 0)
      {:ok, sim_at_cutout} = LeverMapper.map_input(config, 0.5)
      {:ok, sim_mid_braking} = LeverMapper.map_input(config, 0.25)
      {:ok, sim_emergency} = LeverMapper.map_input(config, 0.0)

      assert sim_at_cutout == 0.5
      assert sim_mid_braking < sim_at_cutout
      assert sim_emergency < sim_mid_braking
      assert sim_emergency == 0.02
    end
  end

  describe "map_detent/2 with mixed gate and linear notches" do
    setup do
      # MasterController-style: Gate - Linear - Gate - Linear
      # Only gates should be considered for detent mapping
      lever_config = %LeverConfig{
        id: 20,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: -11.0,
            input_min: 0.0,
            input_max: 0.05,
            sim_input_min: 0.0,
            sim_input_max: 0.04
          },
          %Notch{
            index: 1,
            type: :linear,
            min_value: -10.0,
            max_value: -0.91,
            input_min: 0.05,
            input_max: 0.45,
            sim_input_min: 0.05,
            sim_input_max: 0.44
          },
          %Notch{
            index: 2,
            type: :gate,
            value: 0.0,
            input_min: 0.45,
            input_max: 0.55,
            sim_input_min: 0.49,
            sim_input_max: 0.51
          },
          %Notch{
            index: 3,
            type: :linear,
            min_value: 1.0,
            max_value: 10.0,
            input_min: 0.55,
            input_max: 1.0,
            sim_input_min: 0.56,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "detent 0 maps to first gate center, skipping linear notches", %{lever_config: config} do
      # First gate (index 0): center of 0.0-0.04 = 0.02
      assert {:ok, 0.02} = LeverMapper.map_detent(config, 0)
    end

    test "detent 1 maps to second gate center, skipping linear notches", %{lever_config: config} do
      # Second gate (index 2): center of 0.49-0.51 = 0.5
      assert {:ok, 0.5} = LeverMapper.map_detent(config, 1)
    end

    test "out-of-range detent index returns error", %{lever_config: config} do
      # Only 2 gates exist (detent 0 and 1)
      assert {:error, :no_gate_at_index} = LeverMapper.map_detent(config, 2)
      assert {:error, :no_gate_at_index} = LeverMapper.map_detent(config, 10)
    end
  end

  describe "map_detent/2 with all-gate notches" do
    setup do
      lever_config = %LeverConfig{
        id: 21,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: -1.0,
            sim_input_min: 0.0,
            sim_input_max: 0.1
          },
          %Notch{
            index: 1,
            type: :gate,
            value: 0.0,
            sim_input_min: 0.45,
            sim_input_max: 0.55
          },
          %Notch{
            index: 2,
            type: :gate,
            value: 1.0,
            sim_input_min: 0.9,
            sim_input_max: 1.0
          }
        ]
      }

      %{lever_config: lever_config}
    end

    test "each detent maps to the correct gate center", %{lever_config: config} do
      assert {:ok, 0.05} = LeverMapper.map_detent(config, 0)
      assert {:ok, 0.5} = LeverMapper.map_detent(config, 1)
      assert {:ok, 0.95} = LeverMapper.map_detent(config, 2)
    end

    test "out-of-range detent index returns error", %{lever_config: config} do
      assert {:error, :no_gate_at_index} = LeverMapper.map_detent(config, 3)
    end
  end

  describe "map_detent/2 edge cases" do
    test "empty notches returns error" do
      config = %LeverConfig{id: 22, notches: []}
      assert {:error, :no_gate_at_index} = LeverMapper.map_detent(config, 0)
    end

    test "missing sim_input range returns error" do
      config = %LeverConfig{
        id: 23,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: 0.0,
            sim_input_min: nil,
            sim_input_max: nil
          }
        ]
      }

      assert {:error, :no_sim_input_range} = LeverMapper.map_detent(config, 0)
    end

    test "rounds float values to 2 decimal places" do
      config = %LeverConfig{
        id: 24,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            value: 0.0,
            sim_input_min: 0.0,
            sim_input_max: 0.07
          }
        ]
      }

      # Center of 0.0-0.07 = 0.035, rounded to 0.04
      assert {:ok, 0.04} = LeverMapper.map_detent(config, 0)
    end
  end

  describe "calculate_sim_input/2 with integer values from SQLite" do
    test "handles integer sim_input values for gate notch" do
      # SQLite may return 0 instead of 0.0
      notch = %Notch{type: :gate, value: 0.5, sim_input_min: 0, sim_input_max: 1}

      assert {:ok, 0.5} = LeverMapper.calculate_sim_input(notch, 0.5)
    end

    test "handles integer input values for linear notch" do
      notch = %Notch{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: 0,
        input_max: 1,
        sim_input_min: 0,
        sim_input_max: 1
      }

      assert {:ok, 0.5} = LeverMapper.calculate_sim_input(notch, 0.5)
    end
  end
end
