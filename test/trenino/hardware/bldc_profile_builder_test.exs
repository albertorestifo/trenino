defmodule Trenino.Hardware.BLDCProfileBuilderTest do
  @moduledoc false

  use Trenino.DataCase, async: true

  alias Trenino.Hardware.BLDCProfileBuilder
  alias Trenino.Serial.Protocol.LoadBLDCProfile
  alias Trenino.Train.LeverConfig
  alias Trenino.Train.Notch

  describe "build_profile/1" do
    test "builds profile from lever config with gate notches" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: 80,
            bldc_spring_back: 120,
            bldc_damping: 30
          },
          %Notch{
            index: 1,
            type: :gate,
            input_min: 0.5,
            input_max: 0.5,
            bldc_engagement: 120,
            bldc_hold: 180,
            bldc_exit: 90,
            bldc_spring_back: 140,
            bldc_damping: 40
          },
          %Notch{
            index: 2,
            type: :gate,
            input_min: 1.0,
            input_max: 1.0,
            bldc_engagement: 140,
            bldc_hold: 200,
            bldc_exit: 100,
            bldc_spring_back: 160,
            bldc_damping: 50
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} = BLDCProfileBuilder.build_profile(lever_config)

      # Pin should always be 0
      assert profile.pin == 0

      # Should have 3 detents
      assert length(profile.detents) == 3

      # Check first detent
      first_detent = Enum.at(profile.detents, 0)
      assert first_detent.position == 0
      assert first_detent.engagement == 100
      assert first_detent.hold == 150
      assert first_detent.exit == 80
      assert first_detent.spring_back == 120

      # Check middle detent position calculation (0.5 → 50)
      middle_detent = Enum.at(profile.detents, 1)
      assert middle_detent.position == 50

      # Check last detent position calculation (1.0 → 100)
      last_detent = Enum.at(profile.detents, 2)
      assert last_detent.position == 100

      # No linear ranges for gate-only notches
      assert profile.ranges == []
    end

    test "builds profile with linear ranges" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: 80,
            bldc_spring_back: 120,
            bldc_damping: 30
          },
          %Notch{
            index: 1,
            type: :linear,
            input_min: 0.2,
            input_max: 0.7,
            bldc_engagement: 0,
            bldc_hold: 0,
            bldc_exit: 0,
            bldc_spring_back: 0,
            bldc_damping: 25
          },
          %Notch{
            index: 2,
            type: :gate,
            input_min: 1.0,
            input_max: 1.0,
            bldc_engagement: 140,
            bldc_hold: 200,
            bldc_exit: 100,
            bldc_spring_back: 160,
            bldc_damping: 50
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} = BLDCProfileBuilder.build_profile(lever_config)

      # Should have detents for gate notches only
      assert length(profile.detents) == 2

      # Should have one linear range
      assert length(profile.ranges) == 1

      range = Enum.at(profile.ranges, 0)
      # Range connects first detent (index 0) to second detent (index 1)
      assert range.start_detent == 0
      assert range.end_detent == 1
      assert range.damping == 25
    end

    test "returns error for non-BLDC lever" do
      lever_config = %LeverConfig{
        lever_type: :discrete,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0
          }
        ]
      }

      assert {:error, :not_bldc_lever} = BLDCProfileBuilder.build_profile(lever_config)
    end

    test "returns error for missing BLDC fields in gate notches" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: nil,
            bldc_spring_back: 120,
            bldc_damping: 30
          }
        ]
      }

      assert {:error, :missing_bldc_parameters} =
               BLDCProfileBuilder.build_profile(lever_config)
    end

    test "handles position calculation with decimal values" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.17,
            input_max: 0.17,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: 80,
            bldc_spring_back: 120,
            bldc_damping: 30
          },
          %Notch{
            index: 1,
            type: :gate,
            input_min: 0.73,
            input_max: 0.73,
            bldc_engagement: 120,
            bldc_hold: 180,
            bldc_exit: 90,
            bldc_spring_back: 140,
            bldc_damping: 40
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} = BLDCProfileBuilder.build_profile(lever_config)

      # 0.17 → 17, 0.73 → 73
      positions = Enum.map(profile.detents, & &1.position)
      assert positions == [17, 73]
    end

    test "handles multiple linear ranges" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: 80,
            bldc_spring_back: 120,
            bldc_damping: 30
          },
          %Notch{
            index: 1,
            type: :linear,
            input_min: 0.1,
            input_max: 0.4,
            bldc_engagement: 0,
            bldc_hold: 0,
            bldc_exit: 0,
            bldc_spring_back: 0,
            bldc_damping: 20
          },
          %Notch{
            index: 2,
            type: :gate,
            input_min: 0.5,
            input_max: 0.5,
            bldc_engagement: 120,
            bldc_hold: 180,
            bldc_exit: 90,
            bldc_spring_back: 140,
            bldc_damping: 40
          },
          %Notch{
            index: 3,
            type: :linear,
            input_min: 0.6,
            input_max: 0.9,
            bldc_engagement: 0,
            bldc_hold: 0,
            bldc_exit: 0,
            bldc_spring_back: 0,
            bldc_damping: 35
          },
          %Notch{
            index: 4,
            type: :gate,
            input_min: 1.0,
            input_max: 1.0,
            bldc_engagement: 140,
            bldc_hold: 200,
            bldc_exit: 100,
            bldc_spring_back: 160,
            bldc_damping: 50
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} = BLDCProfileBuilder.build_profile(lever_config)

      # Should have 3 gate detents
      assert length(profile.detents) == 3

      # Should have 2 linear ranges
      assert length(profile.ranges) == 2

      # First range connects detent 0 to detent 1
      first_range = Enum.at(profile.ranges, 0)
      assert first_range.start_detent == 0
      assert first_range.end_detent == 1
      assert first_range.damping == 20

      # Second range connects detent 1 to detent 2
      second_range = Enum.at(profile.ranges, 1)
      assert second_range.start_detent == 1
      assert second_range.end_detent == 2
      assert second_range.damping == 35
    end

    test "returns error when linear notch missing damping" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.0,
            bldc_engagement: 100,
            bldc_hold: 150,
            bldc_exit: 80,
            bldc_spring_back: 120,
            bldc_damping: 30
          },
          %Notch{
            index: 1,
            type: :linear,
            input_min: 0.2,
            input_max: 0.7,
            bldc_engagement: 0,
            bldc_hold: 0,
            bldc_exit: 0,
            bldc_spring_back: 0,
            bldc_damping: nil
          },
          %Notch{
            index: 2,
            type: :gate,
            input_min: 1.0,
            input_max: 1.0,
            bldc_engagement: 140,
            bldc_hold: 200,
            bldc_exit: 100,
            bldc_spring_back: 160,
            bldc_damping: 50
          }
        ]
      }

      assert {:error, :missing_bldc_parameters} =
               BLDCProfileBuilder.build_profile(lever_config)
    end
  end
end
