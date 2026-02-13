# BLDC Haptic Lever Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add support for BLDC motor-based haptic levers with configurable detent profiles that load/unload on train activation/deactivation.

**Architecture:** Extend existing Notch schema with optional BLDC haptic fields, add protocol messages for profile management, create BLDCProfileBuilder to generate firmware messages, integrate with LeverController for lifecycle management.

**Tech Stack:** Elixir, Phoenix, Ecto, PostgreSQL, binary protocol encoding

**Design Document:** `docs/plans/2026-02-13-bldc-lever-design.md`

---

## Task 1: Database Schema Updates

**Files:**
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_add_bldc_support.exs`
- Modify: `lib/trenino/train/lever_config.ex`
- Modify: `lib/trenino/train/notch.ex`

**Step 1: Create migration file**

```bash
mix ecto.gen.migration add_bldc_support
```

**Step 2: Write migration**

```elixir
defmodule Trenino.Repo.Migrations.AddBldcSupport do
  use Ecto.Migration

  def change do
    # Add :bldc to lever_type enum
    execute(
      "ALTER TYPE lever_type ADD VALUE IF NOT EXISTS 'bldc'",
      "ALTER TYPE lever_type DROP VALUE 'bldc'"
    )

    # Add BLDC fields to notches
    alter table(:train_lever_notches) do
      add :bldc_engagement, :integer
      add :bldc_hold, :integer
      add :bldc_exit, :integer
      add :bldc_spring_back, :integer
      add :bldc_damping, :integer
    end

    # Add constraints for valid ranges (0-255)
    create constraint(:train_lever_notches, :bldc_engagement_range,
      check: "bldc_engagement IS NULL OR (bldc_engagement >= 0 AND bldc_engagement <= 255)")

    create constraint(:train_lever_notches, :bldc_hold_range,
      check: "bldc_hold IS NULL OR (bldc_hold >= 0 AND bldc_hold <= 255)")

    create constraint(:train_lever_notches, :bldc_exit_range,
      check: "bldc_exit IS NULL OR (bldc_exit >= 0 AND bldc_exit <= 255)")

    create constraint(:train_lever_notches, :bldc_damping_range,
      check: "bldc_damping IS NULL OR (bldc_damping >= 0 AND bldc_damping <= 255)")
  end
end
```

**Step 3: Update LeverConfig schema**

In `lib/trenino/train/lever_config.ex`, update the lever_type enum:

```elixir
# Line ~43
field :lever_type, Ecto.Enum, values: [:discrete, :continuous, :hybrid, :bldc]
```

**Step 4: Update Notch schema**

In `lib/trenino/train/notch.ex`, add BLDC fields to schema and type:

```elixir
# Add to @type t (around line 47)
bldc_engagement: integer() | nil,
bldc_hold: integer() | nil,
bldc_exit: integer() | nil,
bldc_spring_back: integer() | nil,
bldc_damping: integer() | nil,

# Add to schema block (around line 65)
# BLDC haptic parameters (0-255)
field :bldc_engagement, :integer
field :bldc_hold, :integer
field :bldc_exit, :integer
field :bldc_spring_back, :integer
field :bldc_damping, :integer
```

**Step 5: Add BLDC validation to Notch changeset**

In `lib/trenino/train/notch.ex`, add to changeset function (around line 84):

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
def changeset(%__MODULE__{} = notch, attrs) do
  notch
  |> cast(attrs, [
    :index,
    :type,
    :value,
    :min_value,
    :max_value,
    :input_min,
    :input_max,
    :sim_input_min,
    :sim_input_max,
    :description,
    :lever_config_id,
    # BLDC fields
    :bldc_engagement,
    :bldc_hold,
    :bldc_exit,
    :bldc_spring_back,
    :bldc_damping
  ])
  |> round_float_fields([
    :value,
    :min_value,
    :max_value,
    :input_min,
    :input_max,
    :sim_input_min,
    :sim_input_max
  ])
  |> validate_required([:index, :type])
  |> validate_notch_values()
  |> validate_input_range()
  |> validate_sim_input_range()
  |> validate_bldc_fields()  # Add this
  |> foreign_key_constraint(:lever_config_id)
  |> unique_constraint([:lever_config_id, :index])
end

# Add validation function at the end of the module
defp validate_bldc_fields(changeset) do
  bldc_fields = [
    :bldc_engagement,
    :bldc_hold,
    :bldc_exit,
    :bldc_damping
  ]

  Enum.reduce(bldc_fields, changeset, fn field, cs ->
    case get_change(cs, field) do
      nil ->
        cs

      value when is_integer(value) ->
        validate_number(cs, field, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)

      _ ->
        cs
    end
  end)
end
```

**Step 6: Run migration**

```bash
mix ecto.migrate
```

Expected: Migration runs successfully

**Step 7: Commit**

```bash
git add priv/repo/migrations/ lib/trenino/train/lever_config.ex lib/trenino/train/notch.ex
git commit -m "feat(bldc): add database schema for BLDC lever support

- Add :bldc to lever_type enum
- Add BLDC haptic fields to notches (engagement, hold, exit, spring_back, damping)
- Add validation for BLDC field ranges (0-255)
- Update Notch changeset to handle BLDC fields"
```

---

## Task 2: Protocol Messages - Data Structures

**Files:**
- Create: `lib/trenino/serial/protocol/load_bldc_profile.ex`
- Create: `lib/trenino/serial/protocol/deactivate_bldc_profile.ex`
- Create: `lib/trenino/serial/protocol/retry_calibration.ex`
- Create: `test/trenino/serial/protocol/load_bldc_profile_test.exs`
- Create: `test/trenino/serial/protocol/deactivate_bldc_profile_test.exs`
- Create: `test/trenino/serial/protocol/retry_calibration_test.exs`

**Step 1: Write LoadBLDCProfile test**

Create `test/trenino/serial/protocol/load_bldc_profile_test.exs`:

```elixir
defmodule Trenino.Serial.Protocol.LoadBLDCProfileTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.LoadBLDCProfile

  describe "encode/1" do
    test "encodes message with single detent and no ranges" do
      msg = %LoadBLDCProfile{
        pin: 0,
        detents: [
          %{position: 50, engagement: 180, hold: 200, exit: 150, spring_back: 0}
        ],
        linear_ranges: []
      }

      assert {:ok, binary} = LoadBLDCProfile.encode(msg)

      # Message format: [type: 11] [pin: 0] [num_detents: 1] [num_ranges: 0]
      #                 [detent: position(50), engagement(180), hold(200), exit(150), spring_back(0)]
      assert binary == <<11, 0, 1, 0, 50, 180, 200, 150, 0>>
    end

    test "encodes message with multiple detents" do
      msg = %LoadBLDCProfile{
        pin: 0,
        detents: [
          %{position: 0, engagement: 180, hold: 200, exit: 150, spring_back: 0},
          %{position: 100, engagement: 180, hold: 200, exit: 150, spring_back: 1}
        ],
        linear_ranges: []
      }

      assert {:ok, binary} = LoadBLDCProfile.encode(msg)

      assert binary ==
               <<11, 0, 2, 0,
                 0, 180, 200, 150, 0,
                 100, 180, 200, 150, 1>>
    end

    test "encodes message with linear ranges" do
      msg = %LoadBLDCProfile{
        pin: 0,
        detents: [
          %{position: 0, engagement: 180, hold: 200, exit: 150, spring_back: 0},
          %{position: 100, engagement: 180, hold: 200, exit: 150, spring_back: 1}
        ],
        linear_ranges: [
          %{start_detent: 0, end_detent: 1, damping: 100}
        ]
      }

      assert {:ok, binary} = LoadBLDCProfile.encode(msg)

      assert binary ==
               <<11, 0, 2, 1,
                 0, 180, 200, 150, 0,
                 100, 180, 200, 150, 1,
                 0, 1, 100>>
    end

    test "returns error for invalid position (> 100)" do
      msg = %LoadBLDCProfile{
        pin: 0,
        detents: [
          %{position: 101, engagement: 180, hold: 200, exit: 150, spring_back: 0}
        ],
        linear_ranges: []
      }

      assert {:error, :invalid_position} = LoadBLDCProfile.encode(msg)
    end

    test "returns error for invalid strength value (> 255)" do
      msg = %LoadBLDCProfile{
        pin: 0,
        detents: [
          %{position: 50, engagement: 256, hold: 200, exit: 150, spring_back: 0}
        ],
        linear_ranges: []
      }

      assert {:error, :invalid_strength_value} = LoadBLDCProfile.encode(msg)
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/trenino/serial/protocol/load_bldc_profile_test.exs
```

Expected: FAIL with "module LoadBLDCProfile is not available"

**Step 3: Implement LoadBLDCProfile**

Create `lib/trenino/serial/protocol/load_bldc_profile.ex`:

```elixir
defmodule Trenino.Serial.Protocol.LoadBLDCProfile do
  @moduledoc """
  LoadBLDCProfile message (type 11).

  Loads a BLDC detent profile into the firmware. This configures the haptic
  feedback for a BLDC lever.

  ## Message Format

  ```
  [type: u8 = 11] [pin: u8] [num_detents: u8] [num_linear_ranges: u8]
  [detent_data: 5 bytes × num_detents]
  [range_data: 3 bytes × num_linear_ranges]
  ```

  Detent data (5 bytes each):
  ```
  [position: u8] [engagement: u8] [hold: u8] [exit: u8] [spring_back: u8]
  ```

  Range data (3 bytes each):
  ```
  [start_detent: u8] [end_detent: u8] [damping: u8]
  ```
  """

  @type detent :: %{
          position: non_neg_integer(),
          engagement: non_neg_integer(),
          hold: non_neg_integer(),
          exit: non_neg_integer(),
          spring_back: non_neg_integer()
        }

  @type linear_range :: %{
          start_detent: non_neg_integer(),
          end_detent: non_neg_integer(),
          damping: non_neg_integer()
        }

  @type t :: %__MODULE__{
          pin: non_neg_integer(),
          detents: [detent()],
          linear_ranges: [linear_range()]
        }

  defstruct [:pin, :detents, :linear_ranges]

  @message_type 11

  @spec encode(t()) :: {:ok, binary()} | {:error, atom()}
  def encode(%__MODULE__{pin: pin, detents: detents, linear_ranges: ranges}) do
    with :ok <- validate_detents(detents),
         :ok <- validate_ranges(ranges) do
      num_detents = length(detents)
      num_ranges = length(ranges)

      detent_data = Enum.map_join(detents, &encode_detent/1)
      range_data = Enum.map_join(ranges, &encode_range/1)

      binary = <<@message_type, pin, num_detents, num_ranges>> <> detent_data <> range_data

      {:ok, binary}
    end
  end

  defp validate_detents(detents) do
    Enum.reduce_while(detents, :ok, fn detent, _acc ->
      cond do
        detent.position > 100 ->
          {:halt, {:error, :invalid_position}}

        detent.engagement > 255 or detent.hold > 255 or detent.exit > 255 ->
          {:halt, {:error, :invalid_strength_value}}

        detent.spring_back > 255 ->
          {:halt, {:error, :invalid_spring_back}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_ranges(ranges) do
    Enum.reduce_while(ranges, :ok, fn range, _acc ->
      cond do
        range.start_detent > 255 or range.end_detent > 255 ->
          {:halt, {:error, :invalid_detent_index}}

        range.damping > 255 ->
          {:halt, {:error, :invalid_damping}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp encode_detent(detent) do
    <<detent.position, detent.engagement, detent.hold, detent.exit, detent.spring_back>>
  end

  defp encode_range(range) do
    <<range.start_detent, range.end_detent, range.damping>>
  end
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/trenino/serial/protocol/load_bldc_profile_test.exs
```

Expected: PASS (5 tests)

**Step 5: Write DeactivateBLDCProfile test**

Create `test/trenino/serial/protocol/deactivate_bldc_profile_test.exs`:

```elixir
defmodule Trenino.Serial.Protocol.DeactivateBLDCProfileTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.DeactivateBLDCProfile

  describe "encode/1" do
    test "encodes message with pin 0" do
      msg = %DeactivateBLDCProfile{pin: 0}

      assert {:ok, binary} = DeactivateBLDCProfile.encode(msg)
      assert binary == <<12, 0>>
    end

    test "encodes message with pin 5" do
      msg = %DeactivateBLDCProfile{pin: 5}

      assert {:ok, binary} = DeactivateBLDCProfile.encode(msg)
      assert binary == <<12, 5>>
    end
  end
end
```

**Step 6: Run test to verify it fails**

```bash
mix test test/trenino/serial/protocol/deactivate_bldc_profile_test.exs
```

Expected: FAIL with "module DeactivateBLDCProfile is not available"

**Step 7: Implement DeactivateBLDCProfile**

Create `lib/trenino/serial/protocol/deactivate_bldc_profile.ex`:

```elixir
defmodule Trenino.Serial.Protocol.DeactivateBLDCProfile do
  @moduledoc """
  DeactivateBLDCProfile message (type 12).

  Deactivates the BLDC detent profile, putting the motor into freewheel mode.

  ## Message Format

  ```
  [type: u8 = 12] [pin: u8]
  ```
  """

  @type t :: %__MODULE__{
          pin: non_neg_integer()
        }

  defstruct [:pin]

  @message_type 12

  @spec encode(t()) :: {:ok, binary()}
  def encode(%__MODULE__{pin: pin}) do
    {:ok, <<@message_type, pin>>}
  end
end
```

**Step 8: Run test to verify it passes**

```bash
mix test test/trenino/serial/protocol/deactivate_bldc_profile_test.exs
```

Expected: PASS (2 tests)

**Step 9: Write RetryCalibration test**

Create `test/trenino/serial/protocol/retry_calibration_test.exs`:

```elixir
defmodule Trenino.Serial.Protocol.RetryCalibrationTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.RetryCalibration

  describe "encode/1" do
    test "encodes message with pin 0" do
      msg = %RetryCalibration{pin: 0}

      assert {:ok, binary} = RetryCalibration.encode(msg)
      assert binary == <<8, 0>>
    end

    test "encodes message with pin 5" do
      msg = %RetryCalibration{pin: 5}

      assert {:ok, binary} = RetryCalibration.encode(msg)
      assert binary == <<8, 5>>
    end
  end
end
```

**Step 10: Run test to verify it fails**

```bash
mix test test/trenino/serial/protocol/retry_calibration_test.exs
```

Expected: FAIL with "module RetryCalibration is not available"

**Step 11: Implement RetryCalibration**

Create `lib/trenino/serial/protocol/retry_calibration.ex`:

```elixir
defmodule Trenino.Serial.Protocol.RetryCalibration do
  @moduledoc """
  RetryCalibration message (type 8).

  Requests the firmware to retry BLDC calibration after a failure.

  ## Message Format

  ```
  [type: u8 = 8] [pin: u8]
  ```
  """

  @type t :: %__MODULE__{
          pin: non_neg_integer()
        }

  defstruct [:pin]

  @message_type 8

  @spec encode(t()) :: {:ok, binary()}
  def encode(%__MODULE__{pin: pin}) do
    {:ok, <<@message_type, pin>>}
  end
end
```

**Step 12: Run test to verify it passes**

```bash
mix test test/trenino/serial/protocol/retry_calibration_test.exs
```

Expected: PASS (2 tests)

**Step 13: Commit**

```bash
git add lib/trenino/serial/protocol/ test/trenino/serial/protocol/
git commit -m "feat(bldc): add protocol messages for BLDC profile management

- Add LoadBLDCProfile message (type 11) with detent and range encoding
- Add DeactivateBLDCProfile message (type 12)
- Add RetryCalibration message (type 8)
- Add comprehensive tests for message encoding and validation"
```

---

## Task 3: BLDCProfileBuilder Module

**Files:**
- Create: `lib/trenino/hardware/bldc_profile_builder.ex`
- Create: `test/trenino/hardware/bldc_profile_builder_test.exs`

**Step 1: Write failing test**

Create `test/trenino/hardware/bldc_profile_builder_test.exs`:

```elixir
defmodule Trenino.Hardware.BLDCProfileBuilderTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.BLDCProfileBuilder
  alias Trenino.Serial.Protocol.LoadBLDCProfile
  alias Trenino.Train.{LeverConfig, Notch}

  describe "build_profile/1" do
    test "builds profile from lever config with gate notches" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.3,
            bldc_engagement: 180,
            bldc_hold: 200,
            bldc_exit: 150,
            bldc_spring_back: 0,
            bldc_damping: 0
          },
          %Notch{
            index: 1,
            type: :gate,
            input_min: 0.7,
            input_max: 1.0,
            bldc_engagement: 180,
            bldc_hold: 200,
            bldc_exit: 150,
            bldc_spring_back: 1,
            bldc_damping: 0
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} =
               BLDCProfileBuilder.build_profile(lever_config)

      assert profile.pin == 0
      assert length(profile.detents) == 2
      assert length(profile.linear_ranges) == 0

      [detent0, detent1] = profile.detents

      assert detent0.position == 0
      assert detent0.engagement == 180
      assert detent0.hold == 200
      assert detent0.exit == 150
      assert detent0.spring_back == 0

      assert detent1.position == 70
      assert detent1.engagement == 180
      assert detent1.hold == 200
      assert detent1.exit == 150
      assert detent1.spring_back == 1
    end

    test "builds profile with linear ranges" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.2,
            bldc_engagement: 180,
            bldc_hold: 200,
            bldc_exit: 150,
            bldc_spring_back: 0,
            bldc_damping: 0
          },
          %Notch{
            index: 1,
            type: :linear,
            input_min: 0.2,
            input_max: 0.8,
            bldc_engagement: 50,
            bldc_hold: 30,
            bldc_exit: 50,
            bldc_spring_back: 1,
            bldc_damping: 100
          },
          %Notch{
            index: 2,
            type: :gate,
            input_min: 0.8,
            input_max: 1.0,
            bldc_engagement: 180,
            bldc_hold: 200,
            bldc_exit: 150,
            bldc_spring_back: 2,
            bldc_damping: 0
          }
        ]
      }

      assert {:ok, %LoadBLDCProfile{} = profile} =
               BLDCProfileBuilder.build_profile(lever_config)

      assert length(profile.detents) == 3
      assert length(profile.linear_ranges) == 1

      [range] = profile.linear_ranges

      assert range.start_detent == 0
      assert range.end_detent == 1
      assert range.damping == 100
    end

    test "returns error for non-BLDC lever" do
      lever_config = %LeverConfig{
        lever_type: :discrete,
        notches: []
      }

      assert {:error, :not_bldc_lever} =
               BLDCProfileBuilder.build_profile(lever_config)
    end

    test "returns error for missing BLDC fields" do
      lever_config = %LeverConfig{
        lever_type: :bldc,
        notches: [
          %Notch{
            index: 0,
            type: :gate,
            input_min: 0.0,
            input_max: 0.5,
            bldc_engagement: nil,
            bldc_hold: 200,
            bldc_exit: 150,
            bldc_spring_back: 0,
            bldc_damping: 0
          }
        ]
      }

      assert {:error, :missing_bldc_parameters} =
               BLDCProfileBuilder.build_profile(lever_config)
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/trenino/hardware/bldc_profile_builder_test.exs
```

Expected: FAIL with "module BLDCProfileBuilder is not available"

**Step 3: Implement BLDCProfileBuilder**

Create `lib/trenino/hardware/bldc_profile_builder.ex`:

```elixir
defmodule Trenino.Hardware.BLDCProfileBuilder do
  @moduledoc """
  Builds LoadBLDCProfile messages from LeverConfig data.

  Converts notches with BLDC haptic parameters into firmware protocol messages.
  """

  alias Trenino.Serial.Protocol.LoadBLDCProfile
  alias Trenino.Train.{LeverConfig, Notch}

  @doc """
  Builds a LoadBLDCProfile message from a lever configuration.

  Returns `{:ok, LoadBLDCProfile.t()}` on success, or `{:error, reason}` if:
  - Lever is not BLDC type
  - BLDC parameters are missing
  - Parameters are out of valid range
  """
  @spec build_profile(LeverConfig.t()) ::
          {:ok, LoadBLDCProfile.t()} | {:error, atom()}
  def build_profile(%LeverConfig{lever_type: :bldc, notches: notches}) do
    with :ok <- validate_bldc_parameters(notches),
         detents <- build_detents(notches),
         ranges <- build_linear_ranges(notches) do
      {:ok,
       %LoadBLDCProfile{
         pin: 0,
         detents: detents,
         linear_ranges: ranges
       }}
    end
  end

  def build_profile(%LeverConfig{}), do: {:error, :not_bldc_lever}

  defp validate_bldc_parameters(notches) do
    missing =
      Enum.any?(notches, fn notch ->
        is_nil(notch.bldc_engagement) or
          is_nil(notch.bldc_hold) or
          is_nil(notch.bldc_exit) or
          is_nil(notch.bldc_spring_back) or
          is_nil(notch.bldc_damping)
      end)

    if missing do
      {:error, :missing_bldc_parameters}
    else
      :ok
    end
  end

  defp build_detents(notches) do
    notches
    |> Enum.sort_by(& &1.index)
    |> Enum.map(fn notch ->
      %{
        position: calculate_position(notch),
        engagement: notch.bldc_engagement,
        hold: notch.bldc_hold,
        exit: notch.bldc_exit,
        spring_back: notch.bldc_spring_back
      }
    end)
  end

  defp calculate_position(%Notch{input_min: input_min}) do
    # Convert input_min (0.0-1.0) to firmware position (0-100)
    round(input_min * 100)
  end

  defp build_linear_ranges(notches) do
    notches
    |> Enum.sort_by(& &1.index)
    |> Enum.filter(&(&1.type == :linear))
    |> Enum.map(fn notch ->
      %{
        start_detent: max(0, notch.index - 1),
        end_detent: notch.index,
        damping: notch.bldc_damping
      }
    end)
  end
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/trenino/hardware/bldc_profile_builder_test.exs
```

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/trenino/hardware/bldc_profile_builder.ex test/trenino/hardware/bldc_profile_builder_test.exs
git commit -m "feat(bldc): add BLDCProfileBuilder to generate firmware messages

- Convert LeverConfig notches to LoadBLDCProfile messages
- Calculate detent positions from input_min (0.0-1.0 to 0-100)
- Build linear ranges from consecutive notches
- Validate BLDC parameters are present"
```

---

## Task 4: LeverAnalyzer BLDC Parameter Generation

**Files:**
- Modify: `lib/trenino/simulator/lever_analyzer.ex`
- Modify: `test/trenino/simulator/lever_analyzer_test.exs`

**Step 1: Write test for BLDC parameter generation**

Add to `test/trenino/simulator/lever_analyzer_test.exs`:

```elixir
describe "analyze_samples/2 with BLDC parameters" do
  test "generates BLDC parameters for gate zones" do
    samples = [
      %Sample{set_input: 0.0, actual_input: 0.0, output: -1.0, notch_index: 0, snapped: true},
      %Sample{set_input: 0.5, actual_input: 0.5, output: 0.0, notch_index: 1, snapped: true},
      %Sample{set_input: 1.0, actual_input: 1.0, output: 1.0, notch_index: 2, snapped: true}
    ]

    {:ok, result} = LeverAnalyzer.analyze_samples(samples, lever_type: :bldc)

    assert result.lever_type == :bldc
    assert length(result.suggested_notches) == 3

    # Check BLDC parameters for gates
    Enum.each(result.suggested_notches, fn notch ->
      assert notch.type == :gate
      assert notch.bldc_engagement == 180
      assert notch.bldc_hold == 200
      assert notch.bldc_exit == 150
      assert notch.bldc_spring_back == notch.index
      assert notch.bldc_damping == 0
    end)
  end

  test "generates BLDC parameters for linear zones" do
    samples = [
      %Sample{set_input: 0.0, actual_input: 0.0, output: 0.0, notch_index: 0, snapped: false},
      %Sample{set_input: 0.5, actual_input: 0.5, output: 0.5, notch_index: 0, snapped: false},
      %Sample{set_input: 1.0, actual_input: 1.0, output: 1.0, notch_index: 0, snapped: false}
    ]

    {:ok, result} = LeverAnalyzer.analyze_samples(samples, lever_type: :bldc)

    assert result.lever_type == :bldc
    assert length(result.suggested_notches) == 1

    [notch] = result.suggested_notches

    assert notch.type == :linear
    assert notch.bldc_engagement == 50
    assert notch.bldc_hold == 30
    assert notch.bldc_exit == 50
    assert notch.bldc_spring_back == 0
    assert notch.bldc_damping == 100
  end

  test "does not add BLDC parameters when lever_type not specified" do
    samples = [
      %Sample{set_input: 0.0, actual_input: 0.0, output: -1.0, notch_index: 0, snapped: true}
    ]

    {:ok, result} = LeverAnalyzer.analyze_samples(samples)

    [notch] = result.suggested_notches

    refute Map.has_key?(notch, :bldc_engagement)
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/trenino/simulator/lever_analyzer_test.exs -t describe:"analyze_samples/2 with BLDC parameters"
```

Expected: FAIL with missing :bldc_engagement fields

**Step 3: Modify LeverAnalyzer to accept opts**

In `lib/trenino/simulator/lever_analyzer.ex`, update `analyze_samples/1` to accept options:

```elixir
# Around line 355
@doc """
Analyzes pre-collected samples to determine lever type and zones.

## Options

- `:lever_type` - Force a specific lever type (e.g., :bldc). When set to :bldc,
  includes BLDC haptic parameters in suggested notches.

## Examples

    {:ok, result} = LeverAnalyzer.analyze_samples(samples)
    {:ok, result} = LeverAnalyzer.analyze_samples(samples, lever_type: :bldc)
"""
@spec analyze_samples([Sample.t()], keyword()) :: {:ok, AnalysisResult.t()}
def analyze_samples(samples, opts \\ []) when is_list(samples) do
  lever_type_override = Keyword.get(opts, :lever_type)

  outputs = Enum.map(samples, & &1.output)
  unique_outputs = Enum.uniq(outputs) |> Enum.sort()

  all_integers = Enum.all?(unique_outputs, &integer_value?/1)
  unique_count = length(unique_outputs)

  min_output = Enum.min(outputs)
  max_output = Enum.max(outputs)

  notch_groups = group_by_notch_index(samples)

  Logger.debug("[LeverAnalyzer] API reports #{map_size(notch_groups)} notch groups")

  zones = merge_continuous_notches(notch_groups)

  Logger.debug("[LeverAnalyzer] After merging: #{length(zones)} zones")

  lever_type = lever_type_override || classify_lever_type(unique_count, all_integers, zones)

  suggested_notches = build_notches_from_zones(zones, opts)

  {:ok,
   %AnalysisResult{
     lever_type: lever_type,
     samples: samples,
     zones: zones,
     suggested_notches: suggested_notches,
     min_output: min_output,
     max_output: max_output,
     unique_output_count: unique_count,
     all_outputs_integers: all_integers
   }}
end
```

**Step 4: Update build_notches_from_zones to add BLDC params**

In `lib/trenino/simulator/lever_analyzer.ex`, update around line 544:

```elixir
# Build notch suggestions from the detected zones
defp build_notches_from_zones(zones, opts) do
  lever_type = Keyword.get(opts, :lever_type)

  zones
  |> Enum.sort_by(& &1.set_input_min)
  |> Enum.with_index()
  |> Enum.map(fn {zone, idx} ->
    base_notch = build_base_notch(zone, idx)

    if lever_type == :bldc do
      Map.merge(base_notch, default_bldc_params(zone.type, idx))
    else
      base_notch
    end
  end)
end

defp build_base_notch(zone, idx) do
  case zone.type do
    :gate ->
      %{
        type: :gate,
        index: idx,
        value: zone.value,
        input_min: zone.set_input_min,
        input_max: zone.set_input_max,
        actual_input_min: zone.actual_input_min,
        actual_input_max: zone.actual_input_max,
        description: "Gate at output #{zone.value}"
      }

    :linear ->
      %{
        type: :linear,
        index: idx,
        min_value: zone.output_min,
        max_value: zone.output_max,
        input_min: zone.set_input_min,
        input_max: zone.set_input_max,
        actual_input_min: zone.actual_input_min,
        actual_input_max: zone.actual_input_max,
        description: "Linear #{zone.output_min} to #{zone.output_max}"
      }
  end
end

defp default_bldc_params(:gate, idx) do
  %{
    bldc_engagement: 180,
    bldc_hold: 200,
    bldc_exit: 150,
    bldc_spring_back: idx,
    bldc_damping: 0
  }
end

defp default_bldc_params(:linear, idx) do
  %{
    bldc_engagement: 50,
    bldc_hold: 30,
    bldc_exit: 50,
    bldc_spring_back: idx,
    bldc_damping: 100
  }
end
```

**Step 5: Run test to verify it passes**

```bash
mix test test/trenino/simulator/lever_analyzer_test.exs
```

Expected: PASS (all tests including new BLDC tests)

**Step 6: Commit**

```bash
git add lib/trenino/simulator/lever_analyzer.ex test/trenino/simulator/lever_analyzer_test.exs
git commit -m "feat(bldc): generate BLDC haptic parameters in LeverAnalyzer

- Add lever_type option to analyze_samples/2
- Generate default BLDC parameters based on zone type
  - Gates: strong engagement (180), firm hold (200), moderate exit (150)
  - Linear: light engagement (50), light hold (30), smooth damping (100)
- Spring back defaults to same detent (no spring-back)
- Only add BLDC params when lever_type: :bldc specified"
```

---

## Task 5: LeverController BLDC Profile Management

**Files:**
- Modify: `lib/trenino/train/lever_controller.ex`
- Create: `test/trenino/train/lever_controller_bldc_test.exs`

**Step 1: Write test for profile loading on train activation**

Create `test/trenino/train/lever_controller_bldc_test.exs`:

```elixir
defmodule Trenino.Train.LeverControllerBldcTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train.LeverController
  alias Trenino.Serial.Connection, as: SerialConnection

  import Trenino.{HardwareFixtures, TrainFixtures}

  setup do
    # Start required processes
    start_supervised!(Trenino.Serial.Connection)
    start_supervised!(Trenino.Hardware.ConfigurationManager)
    start_supervised!(Trenino.Simulator.Connection)
    start_supervised!(Trenino.Train)
    start_supervised!(LeverController)

    :ok
  end

  describe "BLDC profile loading" do
    test "loads BLDC profile when train activates with BLDC lever" do
      # Setup: Create device with BLDC hardware config
      device = device_fixture()

      # Create train with BLDC lever
      train = train_fixture()
      element = element_fixture(train_id: train.id, name: "Throttle")

      lever_config =
        lever_config_fixture(
          element_id: element.id,
          lever_type: :bldc,
          min_endpoint: "Actor/Control.Min",
          max_endpoint: "Actor/Control.Max",
          value_endpoint: "Actor/Control.InputValue"
        )

      # Create notches with BLDC parameters
      notch_fixture(%{
        lever_config_id: lever_config.id,
        index: 0,
        type: :gate,
        value: 0.0,
        input_min: 0.0,
        input_max: 0.3,
        bldc_engagement: 180,
        bldc_hold: 200,
        bldc_exit: 150,
        bldc_spring_back: 0,
        bldc_damping: 0
      })

      notch_fixture(%{
        lever_config_id: lever_config.id,
        index: 1,
        type: :gate,
        value: 1.0,
        input_min: 0.7,
        input_max: 1.0,
        bldc_engagement: 180,
        bldc_hold: 200,
        bldc_exit: 150,
        bldc_spring_back: 1,
        bldc_damping: 0
      })

      # Mock serial connection
      port = "/dev/ttyUSB0"
      SerialConnection.register_mock_device(port, device.config_id)

      # Activate train
      Trenino.Train.activate_train(train.id)

      # Give controller time to process
      Process.sleep(100)

      # Verify LoadBLDCProfile message was sent
      messages = SerialConnection.get_sent_messages(port)

      assert Enum.any?(messages, fn msg ->
               match?(%Trenino.Serial.Protocol.LoadBLDCProfile{}, msg)
             end)
    end

    test "deactivates BLDC profile when train deactivates" do
      # Setup similar to above
      device = device_fixture()
      train = train_fixture()
      element = element_fixture(train_id: train.id)

      lever_config =
        lever_config_fixture(
          element_id: element.id,
          lever_type: :bldc
        )

      notch_fixture(%{
        lever_config_id: lever_config.id,
        index: 0,
        type: :gate,
        value: 0.0,
        input_min: 0.0,
        input_max: 1.0,
        bldc_engagement: 180,
        bldc_hold: 200,
        bldc_exit: 150,
        bldc_spring_back: 0,
        bldc_damping: 0
      })

      port = "/dev/ttyUSB0"
      SerialConnection.register_mock_device(port, device.config_id)

      # Activate then deactivate
      Trenino.Train.activate_train(train.id)
      Process.sleep(50)
      SerialConnection.clear_sent_messages(port)
      Trenino.Train.deactivate_train()
      Process.sleep(50)

      # Verify DeactivateBLDCProfile message was sent
      messages = SerialConnection.get_sent_messages(port)

      assert Enum.any?(messages, fn msg ->
               match?(%Trenino.Serial.Protocol.DeactivateBLDCProfile{}, msg)
             end)
    end

    test "skips profile loading for non-BLDC levers" do
      device = device_fixture()
      train = train_fixture()
      element = element_fixture(train_id: train.id)

      # Create discrete lever (not BLDC)
      lever_config =
        lever_config_fixture(
          element_id: element.id,
          lever_type: :discrete
        )

      port = "/dev/ttyUSB0"
      SerialConnection.register_mock_device(port, device.config_id)

      # Activate train
      Trenino.Train.activate_train(train.id)
      Process.sleep(50)

      # Verify no BLDC messages sent
      messages = SerialConnection.get_sent_messages(port)

      refute Enum.any?(messages, fn msg ->
               match?(%Trenino.Serial.Protocol.LoadBLDCProfile{}, msg)
             end)
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/trenino/train/lever_controller_bldc_test.exs
```

Expected: FAIL - BLDC profile not loaded

**Step 3: Add BLDC profile loading to LeverController**

In `lib/trenino/train/lever_controller.ex`, add after `load_bindings_for_train` (around line 223):

```elixir
defp load_bindings_for_train(%State{} = state, train) do
  bindings = Train.list_bindings_for_train(train.id)

  binding_lookup =
    bindings
    |> Enum.filter(& &1.enabled)
    |> Enum.map(fn binding ->
      {binding.input_id, %{lever_config: binding.lever_config, binding: binding}}
    end)
    |> Map.new()

  Logger.info(
    "[LeverController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
  )

  # Load BLDC profiles for this train
  load_bldc_profiles_for_train(train)

  %{state | active_train: train, binding_lookup: binding_lookup, last_sent_values: %{}}
end

defp load_bldc_profiles_for_train(train) do
  alias Trenino.Hardware.BLDCProfileBuilder
  alias Trenino.Serial.Protocol.LoadBLDCProfile

  train
  |> Train.list_lever_configs()
  |> Enum.filter(&(&1.lever_type == :bldc))
  |> Enum.each(fn lever_config ->
    case BLDCProfileBuilder.build_profile(lever_config) do
      {:ok, %LoadBLDCProfile{} = profile} ->
        case find_device_port_for_lever(lever_config) do
          {:ok, port} ->
            case SerialConnection.send_message(port, profile) do
              {:ok, _} ->
                Logger.info(
                  "[LeverController] Loaded BLDC profile for #{lever_config.element.name}"
                )

              {:error, reason} ->
                Logger.error(
                  "[LeverController] Failed to send BLDC profile: #{inspect(reason)}"
                )
            end

          {:error, reason} ->
            Logger.error("[LeverController] Could not find device port: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.error("[LeverController] Failed to build BLDC profile: #{inspect(reason)}")
    end
  end)
end

defp find_device_port_for_lever(lever_config) do
  # For now, use the first connected device
  # Future: link lever configs to specific devices
  case SerialConnection.connected_devices() do
    [device | _] -> {:ok, device.port}
    [] -> {:error, :no_device_connected}
  end
end
```

**Step 4: Add BLDC profile deactivation**

Update the `handle_info({:train_changed, nil}, state)` callback around line 136:

```elixir
def handle_info({:train_changed, nil}, %State{} = state) do
  Logger.info("[LeverController] Train deactivated, clearing bindings")

  # Deactivate BLDC profiles
  if state.active_train do
    deactivate_bldc_profiles_for_train(state.active_train)
  end

  {:noreply, %{state | active_train: nil, binding_lookup: %{}, last_sent_values: %{}}}
end

# Add at end of module
defp deactivate_bldc_profiles_for_train(train) do
  alias Trenino.Serial.Protocol.DeactivateBLDCProfile

  train
  |> Train.list_lever_configs()
  |> Enum.filter(&(&1.lever_type == :bldc))
  |> Enum.each(fn lever_config ->
    msg = %DeactivateBLDCProfile{pin: 0}

    case find_device_port_for_lever(lever_config) do
      {:ok, port} ->
        SerialConnection.send_message(port, msg)
        Logger.info("[LeverController] Deactivated BLDC profile for #{lever_config.element.name}")

      {:error, reason} ->
        Logger.error("[LeverController] Could not find device port: #{inspect(reason)}")
    end
  end)
end
```

**Step 5: Run test to verify it passes**

```bash
mix test test/trenino/train/lever_controller_bldc_test.exs
```

Expected: PASS (3 tests)

**Step 6: Commit**

```bash
git add lib/trenino/train/lever_controller.ex test/trenino/train/lever_controller_bldc_test.exs
git commit -m "feat(bldc): load/unload BLDC profiles on train activation

- Load BLDC profiles when train activates
- Deactivate BLDC profiles when train deactivates
- Use BLDCProfileBuilder to generate messages
- Send to first connected device (future: device-lever linking)
- Add comprehensive tests for profile lifecycle"
```

---

## Task 6: UI - Add BLDC Lever Type Option

**Files:**
- Modify: `lib/trenino_web/live/components/lever_setup_wizard.ex`
- Modify: `test/trenino_web/live/components/lever_setup_wizard_test.exs`

**Step 1: Add test for BLDC option in wizard**

Add to `test/trenino_web/live/components/lever_setup_wizard_test.exs`:

```elixir
describe "BLDC lever type selection" do
  test "shows BLDC option in lever type selection", %{conn: conn} do
    train = train_fixture()

    {:ok, view, _html} = live(conn, ~p"/trains/#{train}/edit")

    # Open wizard
    view |> element("button", "Add Lever") |> render_click()

    # Check BLDC option exists
    assert render(view) =~ "BLDC Haptic Lever"
    assert render(view) =~ "SimpleFOCShield v2"
  end

  test "selecting BLDC skips pin selection step", %{conn: conn} do
    train = train_fixture()

    {:ok, view, _html} = live(conn, ~p"/trains/#{train}/edit")

    view |> element("button", "Add Lever") |> render_click()

    # Select BLDC
    view
    |> form("#lever-wizard-form", %{lever_type: "bldc"})
    |> render_submit()

    # Should go directly to endpoint selection, skipping pin selection
    assert render(view) =~ "Select Simulator Endpoint"
    refute render(view) =~ "Select Hardware Pin"
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/trenino_web/live/components/lever_setup_wizard_test.exs -t describe:"BLDC lever type selection"
```

Expected: FAIL - BLDC option not found

**Step 3: Add BLDC option to wizard template**

In `lib/trenino_web/live/components/lever_setup_wizard.ex`, find the lever type selection section and add:

```heex
<!-- Around the lever type selection form -->
<.form for={@form} phx-submit="select_lever_type" phx-target={@myself}>
  <div class="space-y-3">
    <.radio_card
      field={@form[:lever_type]}
      value="discrete"
      label="Discrete Lever"
      description="Lever with fixed notch positions (e.g., reverser, gear selector)"
    />
    <.radio_card
      field={@form[:lever_type]}
      value="continuous"
      label="Continuous Lever"
      description="Smooth lever with no detents (e.g., throttle, brake)"
    />
    <.radio_card
      field={@form[:lever_type]}
      value="hybrid"
      label="Hybrid Lever"
      description="Lever with snap zones but continuous output (e.g., BR430 MasterController)"
    />
    <.radio_card
      field={@form[:lever_type]}
      value="bldc"
      label="BLDC Haptic Lever"
      description="Motor-driven lever with programmable force feedback"
      note="Requires SimpleFOCShield v2 on Arduino Mega 2560"
    />
  </div>

  <.button type="submit" class="mt-4">Next</.button>
</.form>
```

**Step 4: Update wizard step flow to skip pin selection for BLDC**

In `lib/trenino_web/live/components/lever_setup_wizard.ex`, update the `handle_event("select_lever_type", ...)` function:

```elixir
def handle_event("select_lever_type", %{"lever_type" => lever_type}, socket) do
  lever_type_atom = String.to_existing_atom(lever_type)

  socket =
    socket
    |> assign(:lever_type, lever_type_atom)
    |> assign(:step, next_step_after_type_selection(lever_type_atom))

  {:noreply, socket}
end

defp next_step_after_type_selection(:bldc) do
  # BLDC skips pin selection, goes to endpoint selection
  :select_endpoint
end

defp next_step_after_type_selection(_) do
  # Regular levers need pin selection
  :select_pin
end
```

**Step 5: Run test to verify it passes**

```bash
mix test test/trenino_web/live/components/lever_setup_wizard_test.exs
```

Expected: PASS

**Step 6: Commit**

```bash
git add lib/trenino_web/live/components/lever_setup_wizard.ex test/trenino_web/live/components/lever_setup_wizard_test.exs
git commit -m "feat(bldc): add BLDC lever type option to configuration wizard

- Add BLDC Haptic Lever option in type selection
- Show hardware requirements (SimpleFOCShield v2)
- Skip pin selection step for BLDC levers
- Go directly to endpoint selection"
```

---

## Task 7: Integration Test - Full BLDC Flow

**Files:**
- Create: `test/trenino/integration/bldc_lever_flow_test.exs`

**Step 1: Write comprehensive integration test**

Create `test/trenino/integration/bldc_lever_flow_test.exs`:

```elixir
defmodule Trenino.Integration.BldcLeverFlowTest do
  use Trenino.DataCase, async: false

  alias Trenino.{Hardware, Train}
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Connection, as: SimulatorConnection

  import Trenino.{HardwareFixtures, TrainFixtures}

  setup do
    # Start all required processes
    start_supervised!(SerialConnection)
    start_supervised!(Trenino.Hardware.ConfigurationManager)
    start_supervised!(SimulatorConnection)
    start_supervised!(Train)
    start_supervised!(Trenino.Train.LeverController)

    :ok
  end

  @tag :integration
  test "complete BLDC lever configuration and activation flow" do
    # Step 1: Create train with BLDC lever
    train = train_fixture(name: "Test Train")
    element = element_fixture(train_id: train.id, name: "Throttle")

    lever_config =
      lever_config_fixture(
        element_id: element.id,
        lever_type: :bldc,
        min_endpoint: "CurrentDrivableActor/Throttle.Min",
        max_endpoint: "CurrentDrivableActor/Throttle.Max",
        value_endpoint: "CurrentDrivableActor/Throttle.InputValue"
      )

    # Step 2: Create BLDC notches with haptic parameters
    {:ok, notch1} =
      Train.create_notch(%{
        lever_config_id: lever_config.id,
        index: 0,
        type: :gate,
        value: 0.0,
        input_min: 0.0,
        input_max: 0.2,
        sim_input_min: 0.0,
        sim_input_max: 0.0,
        bldc_engagement: 180,
        bldc_hold: 200,
        bldc_exit: 150,
        bldc_spring_back: 0,
        bldc_damping: 0,
        description: "Idle"
      })

    {:ok, notch2} =
      Train.create_notch(%{
        lever_config_id: lever_config.id,
        index: 1,
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        input_min: 0.2,
        input_max: 0.8,
        sim_input_min: 0.0,
        sim_input_max: 1.0,
        bldc_engagement: 50,
        bldc_hold: 30,
        bldc_exit: 50,
        bldc_spring_back: 1,
        bldc_damping: 100,
        description: "Power range"
      })

    {:ok, notch3} =
      Train.create_notch(%{
        lever_config_id: lever_config.id,
        index: 2,
        type: :gate,
        value: 1.0,
        input_min: 0.8,
        input_max: 1.0,
        sim_input_min: 1.0,
        sim_input_max: 1.0,
        bldc_engagement: 180,
        bldc_hold: 200,
        bldc_exit: 150,
        bldc_spring_back: 2,
        bldc_damping: 0,
        description: "Full throttle"
      })

    # Step 3: Setup mock device
    device = device_fixture()
    port = "/dev/ttyUSB0"
    SerialConnection.register_mock_device(port, device.config_id)

    # Step 4: Activate train
    {:ok, _} = Train.activate_train(train.id)

    # Give system time to process
    Process.sleep(100)

    # Step 5: Verify LoadBLDCProfile sent
    messages = SerialConnection.get_sent_messages(port)
    load_profile_msg = Enum.find(messages, &match?({:load_bldc_profile, _}, &1))

    assert load_profile_msg != nil, "LoadBLDCProfile message not sent"

    {:load_bldc_profile, profile} = load_profile_msg

    # Verify profile structure
    assert length(profile.detents) == 3
    assert length(profile.linear_ranges) == 1

    # Verify detent 0 (gate)
    [d0, d1, d2] = profile.detents
    assert d0.position == 0
    assert d0.engagement == 180
    assert d0.hold == 200

    # Verify detent 1 (linear)
    assert d1.position == 20
    assert d1.engagement == 50
    assert d1.hold == 30

    # Verify linear range
    [range] = profile.linear_ranges
    assert range.start_detent == 0
    assert range.end_detent == 1
    assert range.damping == 100

    # Step 6: Deactivate train
    SerialConnection.clear_sent_messages(port)
    :ok = Train.deactivate_train()
    Process.sleep(50)

    # Step 7: Verify DeactivateBLDCProfile sent
    messages = SerialConnection.get_sent_messages(port)

    assert Enum.any?(messages, fn
             {:deactivate_bldc_profile, _} -> true
             _ -> false
           end)
  end

  @tag :integration
  test "switches between trains with different BLDC profiles" do
    # Create two trains with different BLDC configurations
    train1 = train_fixture(name: "Train 1")
    element1 = element_fixture(train_id: train1.id, name: "Throttle")

    lever1 =
      lever_config_fixture(
        element_id: element1.id,
        lever_type: :bldc
      )

    # Train 1: Single gate
    Train.create_notch(%{
      lever_config_id: lever1.id,
      index: 0,
      type: :gate,
      value: 0.0,
      input_min: 0.0,
      input_max: 1.0,
      bldc_engagement: 200,
      bldc_hold: 220,
      bldc_exit: 180,
      bldc_spring_back: 0,
      bldc_damping: 0
    })

    train2 = train_fixture(name: "Train 2")
    element2 = element_fixture(train_id: train2.id, name: "Throttle")

    lever2 =
      lever_config_fixture(
        element_id: element2.id,
        lever_type: :bldc
      )

    # Train 2: Two gates
    Train.create_notch(%{
      lever_config_id: lever2.id,
      index: 0,
      type: :gate,
      value: 0.0,
      input_min: 0.0,
      input_max: 0.5,
      bldc_engagement: 150,
      bldc_hold: 170,
      bldc_exit: 130,
      bldc_spring_back: 0,
      bldc_damping: 0
    })

    Train.create_notch(%{
      lever_config_id: lever2.id,
      index: 1,
      type: :gate,
      value: 1.0,
      input_min: 0.5,
      input_max: 1.0,
      bldc_engagement: 150,
      bldc_hold: 170,
      bldc_exit: 130,
      bldc_spring_back: 1,
      bldc_damping: 0
    })

    device = device_fixture()
    port = "/dev/ttyUSB0"
    SerialConnection.register_mock_device(port, device.config_id)

    # Activate train 1
    Train.activate_train(train1.id)
    Process.sleep(50)

    messages1 = SerialConnection.get_sent_messages(port)
    {:load_bldc_profile, profile1} = Enum.find(messages1, &match?({:load_bldc_profile, _}, &1))
    assert length(profile1.detents) == 1

    # Switch to train 2
    SerialConnection.clear_sent_messages(port)
    Train.activate_train(train2.id)
    Process.sleep(50)

    messages2 = SerialConnection.get_sent_messages(port)

    # Should deactivate old profile and load new one
    assert Enum.any?(messages2, &match?({:deactivate_bldc_profile, _}, &1))
    {:load_bldc_profile, profile2} = Enum.find(messages2, &match?({:load_bldc_profile, _}, &1))
    assert length(profile2.detents) == 2
  end
end
```

**Step 2: Run test to verify it passes**

```bash
mix test test/trenino/integration/bldc_lever_flow_test.exs
```

Expected: PASS (2 integration tests)

**Step 3: Commit**

```bash
git add test/trenino/integration/bldc_lever_flow_test.exs
git commit -m "test(bldc): add end-to-end integration tests

- Test complete BLDC configuration and activation flow
- Verify profile loading with correct detents and ranges
- Test profile deactivation on train deactivation
- Test switching between trains with different profiles
- Validate message structure sent to firmware"
```

---

## Task 8: Documentation and Final Polish

**Files:**
- Create: `docs/features/bldc-levers.md`
- Modify: `README.md`

**Step 1: Create feature documentation**

Create `docs/features/bldc-levers.md`:

```markdown
# BLDC Haptic Levers

BLDC (Brushless DC) motor-based haptic levers provide programmable force feedback with virtual detents, enabling realistic haptic simulation of train controls.

## Features

- **Configurable Detents**: Define gate positions and linear ranges with precise positioning
- **Haptic Parameters**: Control engagement, hold, and exit forces for each detent
- **Spring-Back Behavior**: Configure detents to return to specific positions (e.g., deadman's switch)
- **Smooth Linear Ranges**: Add damping between detents for realistic throttle feel
- **Profile Switching**: Automatically load different haptic profiles when switching trains

## Hardware Requirements

- Arduino Mega 2560
- SimpleFOCShield v2
- BLDC motor (7 pole pairs typical)
- AS5047D 14-bit magnetic encoder (SPI mode)

## Configuration Flow

### 1. Add BLDC Lever to Train

In the train configuration UI:

1. Click "Add Lever"
2. Select "BLDC Haptic Lever"
3. System configures hardware and runs calibration
4. Select simulator endpoint (e.g., "CurrentDrivableActor/Throttle")
5. Run auto-detect to find notches
6. Review and save

### 2. Auto-Generated Haptic Parameters

The system automatically generates haptic parameters based on detected notch types:

**Gate Notches** (discrete positions):
- Engagement: 180 (strong snap into position)
- Hold: 200 (firm hold in position)
- Exit: 150 (moderate force to exit)
- Damping: 0 (no damping)

**Linear Ranges** (smooth zones):
- Engagement: 50 (light engagement)
- Hold: 30 (light hold)
- Exit: 50 (easy to exit)
- Damping: 100 (medium damping for smooth feel)

### 3. Profile Loading

Profiles are loaded automatically:

- **Train Activated**: BLDC profile loads, haptic feedback activates
- **Train Deactivated**: Profile unloads, motor enters freewheel mode
- **Train Switched**: Old profile unloads, new profile loads

## Technical Details

### Two-Level Configuration

**Level 1: Hardware Configuration** (EEPROM-persisted)
- Board profile selection
- Automatic calibration to find endstops
- Stored permanently in firmware

**Level 2: Detent Profile** (Runtime, volatile)
- Detent positions and strengths
- Spring-back targets
- Linear ranges with damping
- Loaded when train activates

### Position Calculation

Detent positions are calculated from the lever's `input_min` value (0.0-1.0 range) and converted to firmware position (0-100):

```elixir
position = round(input_min * 100)
```

### Linear Ranges

Linear ranges are automatically generated for `:linear` type notches. The range connects the previous detent to the current detent with the specified damping.

## Error Handling

### Calibration Errors

If calibration fails during initial setup:
- Error message displayed with cause (timeout, range too small, encoder error)
- "Retry Calibration" button available
- Check hardware connections and retry

### Runtime Encoder Errors

If encoder fails during operation:
- Firmware enters safe freewheel mode
- Error notification displayed
- Other controls continue working
- Fix hardware issue and recalibrate

## Future Enhancements

- Manual haptic parameter tuning UI
- Spring-back strength detection
- Multiple board profile support
- Profile templates and sharing
- Advanced haptics (vibration patterns, dynamic strength)

## See Also

- [Design Document](../plans/2026-02-13-bldc-lever-design.md)
- [Firmware BLDC Documentation](https://github.com/arestifo/trenino_firmware/blob/main/docs/BLDC_LEVER.md)
- [Protocol Specification](https://github.com/arestifo/trenino_firmware/blob/main/docs/PROTOCOL.md)
```

**Step 2: Update README with BLDC mention**

In `README.md`, update the features section to mention BLDC support:

```markdown
## Features

- **Train Configuration**: Configure multiple trains with different control layouts
- **Simulator Integration**: Connect to Train Simulator World via WebSocket API
- **Hardware Support**:
  - Analog inputs (potentiometers, levers)
  - Digital buttons (physical and matrix)
  - **BLDC haptic levers** with programmable force feedback
  - Output pins for lights and indicators
- **Auto-Detection**: Automatically detect simulator controls and map to hardware
- **Real-Time Control**: Low-latency hardware-to-simulator communication
- **MCP Server**: Control trains via Claude Desktop integration

## Hardware

Trenino supports various Arduino-compatible boards:
- Arduino Uno/Nano for basic setups
- Arduino Mega 2560 for BLDC haptic levers

**BLDC Lever Requirements**:
- Arduino Mega 2560
- SimpleFOCShield v2
- BLDC motor with AS5047D encoder

See [Hardware Setup Guide](docs/hardware-setup.md) for details.
```

**Step 3: Commit documentation**

```bash
git add docs/features/bldc-levers.md README.md
git commit -m "docs(bldc): add comprehensive BLDC lever documentation

- Create feature documentation with configuration flow
- Document hardware requirements and technical details
- Explain two-level configuration system
- Add error handling guide
- Update README with BLDC support mention"
```

---

## Final Steps

**Step 1: Run full test suite**

```bash
mix test
```

Expected: All tests pass

**Step 2: Run type checking**

```bash
mix dialyzer
```

Expected: No errors

**Step 3: Format code**

```bash
mix format
```

**Step 4: Create final commit**

```bash
git add .
git commit -m "feat(bldc): complete BLDC haptic lever support

Complete implementation of BLDC motor-based haptic levers:

- Database schema with BLDC haptic fields
- Protocol messages (LoadBLDCProfile, DeactivateBLDCProfile, RetryCalibration)
- BLDCProfileBuilder for generating firmware messages
- LeverAnalyzer enhancement with BLDC parameter generation
- LeverController integration for profile lifecycle
- UI updates with BLDC lever type option
- Comprehensive integration tests
- Feature documentation

Closes #[issue-number]"
```

---

## Summary

This implementation adds complete BLDC haptic lever support to Trenino:

1. ✅ **Database Schema** - Extended with BLDC fields and validations
2. ✅ **Protocol Messages** - LoadBLDCProfile, DeactivateBLDCProfile, RetryCalibration
3. ✅ **Profile Builder** - Converts notches to firmware messages
4. ✅ **Auto-Detection** - Generates sensible BLDC defaults
5. ✅ **Lifecycle Management** - Load/unload on train activation
6. ✅ **UI Integration** - BLDC option in configuration wizard
7. ✅ **Testing** - Unit tests and integration tests
8. ✅ **Documentation** - Feature docs and README updates

The system is ready for testing with real BLDC hardware.
