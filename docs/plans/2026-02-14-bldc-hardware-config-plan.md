# BLDC Lever Hardware Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add BLDC lever as a configurable input type so the host can send hardware parameters (motor pins, encoder, voltage, etc.) to the firmware via the standard Configure protocol message.

**Architecture:** Extend the existing `Configure` protocol message with a `:bldc_lever` input_type (0x03) and 10-byte payload. Add `:bldc_lever` to the `Input` schema with dedicated columns. Wire it through `ConfigurationManager` and expose it in the Device Settings UI. One BLDC lever per device enforced at DB level.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, binary protocol

---

### Task 1: Protocol — Add BLDC lever to Configure message

**Files:**
- Modify: `lib/trenino/serial/protocol/configure.ex`
- Modify: `test/trenino/serial/protocol/protocol_test.exs`

**Step 1: Write the failing tests**

Add to `test/trenino/serial/protocol/protocol_test.exs`, after the "Configure - Matrix type" describe block (after line 262):

```elixir
describe "Configure - BLDC Lever type" do
  test "encode encodes BLDC lever configuration correctly" do
    configure = %Configure{
      config_id: 0x12345678,
      total_parts: 0x02,
      part_number: 0x01,
      input_type: :bldc_lever,
      motor_pin_a: 5,
      motor_pin_b: 6,
      motor_pin_c: 9,
      motor_enable_a: 7,
      motor_enable_b: 8,
      encoder_cs: 10,
      pole_pairs: 11,
      voltage: 120,
      current_limit: 0,
      encoder_bits: 14
    }

    {:ok, encoded} = Configure.encode(configure)

    # Header (8 bytes) + 10 payload bytes = 18
    assert byte_size(encoded) == 18

    assert encoded ==
             <<0x02, 0x78, 0x56, 0x34, 0x12, 0x02, 0x01, 0x03, 5, 6, 9, 7, 8, 10, 11, 120,
               0, 14>>
  end

  test "decode_body decodes BLDC lever configuration" do
    body =
      <<0x78, 0x56, 0x34, 0x12, 0x02, 0x01, 0x03, 5, 6, 9, 7, 8, 10, 11, 120, 15, 14>>

    {:ok, decoded} = Configure.decode_body(body)

    assert decoded == %Configure{
             config_id: 0x12345678,
             total_parts: 0x02,
             part_number: 0x01,
             input_type: :bldc_lever,
             motor_pin_a: 5,
             motor_pin_b: 6,
             motor_pin_c: 9,
             motor_enable_a: 7,
             motor_enable_b: 8,
             encoder_cs: 10,
             pole_pairs: 11,
             voltage: 120,
             current_limit: 15,
             encoder_bits: 14
           }
  end

  test "decode_body returns error for BLDC lever with insufficient data" do
    # Header says BLDC (0x03) but only 3 payload bytes instead of 10
    body = <<0x78, 0x56, 0x34, 0x12, 0x01, 0x00, 0x03, 5, 6, 9>>
    assert Configure.decode_body(body) == {:error, :invalid_message}
  end

  test "roundtrip encode/decode BLDC lever" do
    original = %Configure{
      config_id: 0xDEADBEEF,
      total_parts: 0x03,
      part_number: 0x02,
      input_type: :bldc_lever,
      motor_pin_a: 3,
      motor_pin_b: 5,
      motor_pin_c: 6,
      motor_enable_a: 7,
      motor_enable_b: 8,
      encoder_cs: 15,
      pole_pairs: 7,
      voltage: 240,
      current_limit: 30,
      encoder_bits: 12
    }

    {:ok, encoded} = Configure.encode(original)
    {:ok, decoded} = Message.decode(encoded)

    assert decoded == original
  end
end
```

Also add to the "roundtrip through Message.decode for all message types" test (in the `messages` list around line 617):

```elixir
%Configure{
  config_id: 0x12345678,
  total_parts: 0x02,
  part_number: 0x01,
  input_type: :bldc_lever,
  motor_pin_a: 5,
  motor_pin_b: 6,
  motor_pin_c: 9,
  motor_enable_a: 7,
  motor_enable_b: 8,
  encoder_cs: 10,
  pole_pairs: 11,
  voltage: 120,
  current_limit: 0,
  encoder_bits: 14
},
```

And add to the `Message.decode/1` describe block (after line 570):

```elixir
test "decodes Configure with BLDC lever type" do
  binary =
    <<0x02, 0x78, 0x56, 0x34, 0x12, 0x02, 0x01, 0x03, 5, 6, 9, 7, 8, 10, 11, 120, 0, 14>>

  {:ok, decoded} = Message.decode(binary)

  assert decoded == %Configure{
           config_id: 0x12345678,
           total_parts: 0x02,
           part_number: 0x01,
           input_type: :bldc_lever,
           motor_pin_a: 5,
           motor_pin_b: 6,
           motor_pin_c: 9,
           motor_enable_a: 7,
           motor_enable_b: 8,
           encoder_cs: 10,
           pole_pairs: 11,
           voltage: 120,
           current_limit: 0,
           encoder_bits: 14
         }
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/trenino/serial/protocol/protocol_test.exs --max-failures 1`
Expected: Compilation error — `motor_pin_a` not a valid key for `Configure`

**Step 3: Update Configure struct and type**

In `lib/trenino/serial/protocol/configure.ex`:

1. Update the `@type input_type` (line 16):

```elixir
@type input_type :: :analog | :button | :matrix | :bldc_lever
```

2. Add BLDC fields to `@type t()` (after line 29):

```elixir
# BLDC Lever fields
motor_pin_a: integer() | nil,
motor_pin_b: integer() | nil,
motor_pin_c: integer() | nil,
motor_enable_a: integer() | nil,
motor_enable_b: integer() | nil,
encoder_cs: integer() | nil,
pole_pairs: integer() | nil,
voltage: integer() | nil,
current_limit: integer() | nil,
encoder_bits: integer() | nil
```

3. Add BLDC fields to `defstruct` (after line 41):

```elixir
:motor_pin_a,
:motor_pin_b,
:motor_pin_c,
:motor_enable_a,
:motor_enable_b,
:encoder_cs,
:pole_pairs,
:voltage,
:current_limit,
:encoder_bits
```

4. Add encode clause for `:bldc_lever` (after the matrix encode, before `decode_body`):

```elixir
# Encode - BLDC Lever (input_type = 0x03)
def encode(%__MODULE__{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :bldc_lever,
      motor_pin_a: motor_pin_a,
      motor_pin_b: motor_pin_b,
      motor_pin_c: motor_pin_c,
      motor_enable_a: motor_enable_a,
      motor_enable_b: motor_enable_b,
      encoder_cs: encoder_cs,
      pole_pairs: pole_pairs,
      voltage: voltage,
      current_limit: current_limit,
      encoder_bits: encoder_bits
    }) do
  {:ok,
   <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
     0x03::8-unsigned, motor_pin_a::8-unsigned, motor_pin_b::8-unsigned,
     motor_pin_c::8-unsigned, motor_enable_a::8-unsigned, motor_enable_b::8-unsigned,
     encoder_cs::8-unsigned, pole_pairs::8-unsigned, voltage::8-unsigned,
     current_limit::8-unsigned, encoder_bits::8-unsigned>>}
end
```

5. Add decode_body clause for BLDC lever (before the catch-all `decode_body(_)`):

```elixir
# Decode body - BLDC Lever (input_type = 0x03)
def decode_body(
      <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x03,
        motor_pin_a::8-unsigned, motor_pin_b::8-unsigned, motor_pin_c::8-unsigned,
        motor_enable_a::8-unsigned, motor_enable_b::8-unsigned, encoder_cs::8-unsigned,
        pole_pairs::8-unsigned, voltage::8-unsigned, current_limit::8-unsigned,
        encoder_bits::8-unsigned>>
    ) do
  {:ok,
   %__MODULE__{
     config_id: config_id,
     total_parts: total_parts,
     part_number: part_number,
     input_type: :bldc_lever,
     motor_pin_a: motor_pin_a,
     motor_pin_b: motor_pin_b,
     motor_pin_c: motor_pin_c,
     motor_enable_a: motor_enable_a,
     motor_enable_b: motor_enable_b,
     encoder_cs: encoder_cs,
     pole_pairs: pole_pairs,
     voltage: voltage,
     current_limit: current_limit,
     encoder_bits: encoder_bits
   }}
end
```

6. Update the `@moduledoc` (line 3-10) to include the BLDC lever payload:

```elixir
@moduledoc """
Configuration message sent to device to configure an input.

Protocol v2.0.0 - Discriminated union format:
- Common header: [type=0x02][config_id:u32][total_parts:u8][part_number:u8][input_type:u8]
- Analog payload: [pin:u8][sensitivity:u8]
- Button payload: [pin:u8][debounce:u8]
- Matrix payload: [num_row_pins:u8][num_col_pins:u8][row_pins...][col_pins...]
- BLDC Lever payload: [motor_pin_a:u8][motor_pin_b:u8][motor_pin_c:u8][motor_enable_a:u8][motor_enable_b:u8][encoder_cs:u8][pole_pairs:u8][voltage:u8][current_limit:u8][encoder_bits:u8]
"""
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/trenino/serial/protocol/protocol_test.exs`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/trenino/serial/protocol/configure.ex test/trenino/serial/protocol/protocol_test.exs
git commit -m "feat: add BLDC lever input type to Configure protocol message"
```

---

### Task 2: Message decoder — Wire missing message types

**Files:**
- Modify: `lib/trenino/serial/protocol/message.ex`
- Modify: `test/trenino/serial/protocol/protocol_test.exs`

**Step 1: Write the failing tests**

Add to `test/trenino/serial/protocol/protocol_test.exs` in the `Message.decode/1` describe block:

```elixir
test "decodes RetryCalibration" do
  binary = <<0x08, 0x0A>>
  {:ok, decoded} = Message.decode(binary)

  alias Trenino.Serial.Protocol.RetryCalibration
  assert decoded == %RetryCalibration{pin: 0x0A}
end

test "decodes LoadBLDCProfile" do
  # Minimal: pin=10, 1 detent, 0 ranges
  binary =
    <<0x0B, 10, 1, 0, 50, 100, 150, 100, 255>>

  {:ok, decoded} = Message.decode(binary)

  alias Trenino.Serial.Protocol.LoadBLDCProfile

  assert %LoadBLDCProfile{pin: 10, detents: [detent], ranges: []} = decoded
  assert detent.position == 50
end

test "decodes DeactivateBLDCProfile" do
  binary = <<0x0C, 0x0A>>
  {:ok, decoded} = Message.decode(binary)

  alias Trenino.Serial.Protocol.DeactivateBLDCProfile
  assert decoded == %DeactivateBLDCProfile{pin: 0x0A}
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/trenino/serial/protocol/protocol_test.exs --max-failures 1`
Expected: FAIL — `{:error, :unknown_message_type}` for type 0x08

**Step 3: Update Message.decode/1**

In `lib/trenino/serial/protocol/message.ex`:

1. Add aliases (line 6-15, add to the existing alias block):

```elixir
alias Trenino.Serial.Protocol.{
  ConfigurationError,
  ConfigurationStored,
  Configure,
  DeactivateBLDCProfile,
  Heartbeat,
  IdentityRequest,
  IdentityResponse,
  InputValue,
  LoadBLDCProfile,
  RetryCalibration,
  SetOutput
}
```

2. Add decode clauses after line 44 (before the catch-all):

```elixir
def decode(<<0x08, rest::binary>>), do: RetryCalibration.decode_body(rest)
def decode(<<0x0B, rest::binary>>), do: LoadBLDCProfile.decode_body(rest)
def decode(<<0x0C, rest::binary>>), do: DeactivateBLDCProfile.decode_body(rest)
```

Note: We skip 0x09 (CalibrationError) and 0x0A (EncoderError) since those protocol modules don't exist yet and aren't needed for this feature. They can be added when calibration error handling is implemented.

**Step 4: Run tests to verify they pass**

Run: `mix test test/trenino/serial/protocol/protocol_test.exs`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/trenino/serial/protocol/message.ex test/trenino/serial/protocol/protocol_test.exs
git commit -m "feat: wire RetryCalibration, LoadBLDCProfile, DeactivateBLDCProfile into Message decoder"
```

---

### Task 3: Database — Add BLDC lever columns to device_inputs

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_bldc_lever_input_type.exs`

**Step 1: Create migration**

Run: `mix ecto.gen.migration add_bldc_lever_input_type`

Then write the migration:

```elixir
defmodule Trenino.Repo.Migrations.AddBldcLeverInputType do
  use Ecto.Migration

  def change do
    # Add BLDC hardware parameter columns
    alter table(:device_inputs) do
      add :motor_pin_a, :integer
      add :motor_pin_b, :integer
      add :motor_pin_c, :integer
      add :motor_enable_a, :integer
      add :motor_enable_b, :integer
      add :encoder_cs, :integer
      add :pole_pairs, :integer
      add :voltage, :integer
      add :current_limit, :integer
      add :encoder_bits, :integer
    end

    # Enforce one BLDC lever per device
    create unique_index(:device_inputs, [:device_id],
      where: "input_type = 'bldc_lever'",
      name: :device_inputs_one_bldc_per_device
    )
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds

**Step 3: Commit**

```bash
git add priv/repo/migrations/*_add_bldc_lever_input_type.exs
git commit -m "feat: add BLDC lever columns and unique constraint to device_inputs"
```

---

### Task 4: Schema — Add BLDC lever to Input

**Files:**
- Modify: `lib/trenino/hardware/input.ex`

**Step 1: Write the failing test**

Create `test/trenino/hardware/input_test.exs`:

```elixir
defmodule Trenino.Hardware.InputTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.Input

  describe "changeset/2 - BLDC lever" do
    setup do
      device = insert_device()
      %{device: device}
    end

    test "valid BLDC lever changeset", %{device: device} do
      attrs = %{
        input_type: :bldc_lever,
        pin: 10,
        name: "BLDC Lever",
        motor_pin_a: 5,
        motor_pin_b: 6,
        motor_pin_c: 9,
        motor_enable_a: 7,
        motor_enable_b: 8,
        encoder_cs: 10,
        pole_pairs: 11,
        voltage: 120,
        current_limit: 0,
        encoder_bits: 14
      }

      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "BLDC lever requires all hardware fields", %{device: device} do
      attrs = %{
        input_type: :bldc_lever,
        pin: 10,
        motor_pin_a: 5
        # missing other fields
      }

      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).motor_pin_b
    end

    test "BLDC lever validates pole_pairs > 0", %{device: device} do
      attrs = bldc_attrs(device, pole_pairs: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).pole_pairs
    end

    test "BLDC lever validates voltage > 0", %{device: device} do
      attrs = bldc_attrs(device, voltage: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).voltage
    end

    test "BLDC lever validates encoder_bits > 0", %{device: device} do
      attrs = bldc_attrs(device, encoder_bits: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).encoder_bits
    end

    test "BLDC lever validates values are 0-255", %{device: device} do
      attrs = bldc_attrs(device, motor_pin_a: 256)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).motor_pin_a
    end

    test "analog changeset still works", %{device: device} do
      attrs = %{input_type: :analog, pin: 0, sensitivity: 5}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end
  end

  # Helper to build valid BLDC attrs with overrides
  defp bldc_attrs(_device, overrides \\ []) do
    Map.merge(
      %{
        input_type: :bldc_lever,
        pin: 10,
        motor_pin_a: 5,
        motor_pin_b: 6,
        motor_pin_c: 9,
        motor_enable_a: 7,
        motor_enable_b: 8,
        encoder_cs: 10,
        pole_pairs: 11,
        voltage: 120,
        current_limit: 0,
        encoder_bits: 14
      },
      Map.new(overrides)
    )
  end

  # Helper to insert a device
  defp insert_device do
    {:ok, device} =
      Trenino.Hardware.create_device(%{
        name: "Test Device",
        config_id: :rand.uniform(999_999)
      })

    device
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/trenino/hardware/input_test.exs --max-failures 1`
Expected: Compilation or runtime error — `:bldc_lever` not a valid enum value

**Step 3: Update Input schema**

In `lib/trenino/hardware/input.ex`:

1. Update `@type t` (line 30-44) — add BLDC fields:

```elixir
@type t :: %__MODULE__{
        id: integer() | nil,
        pin: integer(),
        input_type: :analog | :button | :bldc_lever,
        sensitivity: integer() | nil,
        debounce: integer() | nil,
        name: String.t() | nil,
        motor_pin_a: integer() | nil,
        motor_pin_b: integer() | nil,
        motor_pin_c: integer() | nil,
        motor_enable_a: integer() | nil,
        motor_enable_b: integer() | nil,
        encoder_cs: integer() | nil,
        pole_pairs: integer() | nil,
        voltage: integer() | nil,
        current_limit: integer() | nil,
        encoder_bits: integer() | nil,
        device_id: integer() | nil,
        matrix_id: integer() | nil,
        device: Device.t() | Ecto.Association.NotLoaded.t(),
        matrix: Matrix.t() | Ecto.Association.NotLoaded.t() | nil,
        calibration: Calibration.t() | Ecto.Association.NotLoaded.t() | nil,
        lever_bindings: [LeverInputBinding.t()] | Ecto.Association.NotLoaded.t(),
        inserted_at: DateTime.t() | nil,
        updated_at: DateTime.t() | nil
      }
```

2. Update schema (line 47-60) — add `:bldc_lever` to enum and add fields:

```elixir
schema "device_inputs" do
  field :pin, :integer
  field :input_type, Ecto.Enum, values: [:analog, :button, :bldc_lever]
  field :sensitivity, :integer
  field :debounce, :integer
  field :name, :string

  # BLDC lever hardware parameters
  field :motor_pin_a, :integer
  field :motor_pin_b, :integer
  field :motor_pin_c, :integer
  field :motor_enable_a, :integer
  field :motor_enable_b, :integer
  field :encoder_cs, :integer
  field :pole_pairs, :integer
  field :voltage, :integer
  field :current_limit, :integer
  field :encoder_bits, :integer

  belongs_to :device, Device
  belongs_to :matrix, Matrix
  has_one :calibration, Calibration
  has_many :lever_bindings, LeverInputBinding

  timestamps(type: :utc_datetime)
end
```

3. Update `changeset/2` (line 64-73) — add BLDC fields to cast:

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
def changeset(%__MODULE__{} = input, attrs) do
  input
  |> cast(attrs, [
    :pin,
    :input_type,
    :sensitivity,
    :debounce,
    :name,
    :device_id,
    :matrix_id,
    :motor_pin_a,
    :motor_pin_b,
    :motor_pin_c,
    :motor_enable_a,
    :motor_enable_b,
    :encoder_cs,
    :pole_pairs,
    :voltage,
    :current_limit,
    :encoder_bits
  ])
  |> validate_required([:input_type, :device_id, :pin])
  |> validate_by_input_type()
  |> validate_pin_range()
  |> foreign_key_constraint(:device_id)
  |> foreign_key_constraint(:matrix_id)
  |> unique_constraint([:device_id, :pin])
  |> unique_constraint(:device_id,
    name: :device_inputs_one_bldc_per_device,
    message: "already has a BLDC lever configured"
  )
end
```

4. Add `:bldc_lever` clause to `validate_by_input_type/1` (line 75-90):

```elixir
defp validate_by_input_type(changeset) do
  case get_field(changeset, :input_type) do
    :analog ->
      changeset
      |> validate_required([:sensitivity])
      |> validate_number(:sensitivity, greater_than: 0, less_than_or_equal_to: 10)

    :button ->
      changeset
      |> validate_required([:debounce])
      |> validate_number(:debounce, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)

    :bldc_lever ->
      bldc_fields = [
        :motor_pin_a,
        :motor_pin_b,
        :motor_pin_c,
        :motor_enable_a,
        :motor_enable_b,
        :encoder_cs,
        :pole_pairs,
        :voltage,
        :current_limit,
        :encoder_bits
      ]

      changeset
      |> validate_required(bldc_fields)
      |> validate_bldc_ranges()

    _ ->
      changeset
  end
end

@bldc_pin_fields [
  :motor_pin_a,
  :motor_pin_b,
  :motor_pin_c,
  :motor_enable_a,
  :motor_enable_b,
  :encoder_cs
]

defp validate_bldc_ranges(changeset) do
  changeset =
    Enum.reduce(@bldc_pin_fields, changeset, fn field, cs ->
      validate_number(cs, field, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    end)

  changeset
  |> validate_number(:pole_pairs, greater_than: 0, less_than_or_equal_to: 255)
  |> validate_number(:voltage, greater_than: 0, less_than_or_equal_to: 255)
  |> validate_number(:current_limit, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
  |> validate_number(:encoder_bits, greater_than: 0, less_than_or_equal_to: 255)
end
```

5. Update `@moduledoc` to mention `:bldc_lever`:

```elixir
@moduledoc """
Schema for device inputs (analog, button, or BLDC lever).

## Input Types

- `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
- `:button` - Button input. Can be physical (pin 0-127) or virtual (pin 128-255).
- `:bldc_lever` - BLDC motor haptic lever. Requires motor pins, encoder, and electrical params.

## Virtual Buttons

Virtual buttons are created automatically when a Matrix is configured.
They have:
- `matrix_id` set to the parent matrix
- `pin` in the range 128-255 (virtual pin)
- `name` describing their position (e.g., "R0C1")

Virtual buttons behave exactly like physical buttons but are hidden from
the regular input configuration UI.
"""
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/trenino/hardware/input_test.exs`
Expected: All tests PASS

**Step 5: Run existing tests for regressions**

Run: `mix test test/trenino/hardware/ test/trenino/serial/protocol/`
Expected: All PASS

**Step 6: Commit**

```bash
git add lib/trenino/hardware/input.ex test/trenino/hardware/input_test.exs
git commit -m "feat: add :bldc_lever input type to Input schema with validation"
```

---

### Task 5: ConfigurationManager — Build BLDC lever Configure messages

**Files:**
- Modify: `lib/trenino/hardware/configuration_manager.ex:309-366`

**Step 1: Add the BLDC lever clause**

In `lib/trenino/hardware/configuration_manager.ex`, add a new `build_configure_message/4` clause after the button clause (after line 339):

```elixir
defp build_configure_message(
       config_id,
       total_parts,
       part_number,
       {:input, %Input{input_type: :bldc_lever} = input}
     ) do
  %Configure{
    config_id: config_id,
    total_parts: total_parts,
    part_number: part_number,
    input_type: :bldc_lever,
    motor_pin_a: input.motor_pin_a,
    motor_pin_b: input.motor_pin_b,
    motor_pin_c: input.motor_pin_c,
    motor_enable_a: input.motor_enable_a,
    motor_enable_b: input.motor_enable_b,
    encoder_cs: input.encoder_cs,
    pole_pairs: input.pole_pairs,
    voltage: input.voltage,
    current_limit: input.current_limit,
    encoder_bits: input.encoder_bits
  }
end
```

**Step 2: Run existing ConfigurationManager tests**

Run: `mix test test/trenino/hardware/configuration_manager_test.exs`
Expected: All existing tests still PASS

**Step 3: Run full test suite**

Run: `mix test`
Expected: All PASS

**Step 4: Commit**

```bash
git add lib/trenino/hardware/configuration_manager.ex
git commit -m "feat: wire BLDC lever input type through ConfigurationManager"
```

---

### Task 6: Device Settings UI — Add BLDC lever input form

**Files:**
- Modify: `lib/trenino_web/live/configuration_edit_live.ex`

**Step 1: Update the "Add Input" modal**

In `lib/trenino_web/live/configuration_edit_live.ex`, update the `add_input_modal/1` function:

1. Add "BLDC Lever" to the input type dropdown (line 1369):

```elixir
<.input
  field={@form[:input_type]}
  type="select"
  options={[{"Analog", :analog}, {"Button", :button}, {"BLDC Lever", :bldc_lever}]}
  class="select select-bordered w-full"
/>
```

2. Hide the Pin Number field for BLDC (pin is auto-set to encoder_cs). Wrap the existing pin field (lines 1374-1386) with a `:if`:

```elixir
<div :if={@form[:input_type].value not in [:bldc_lever, "bldc_lever"]}>
  <label class="label">
    <span class="label-text">Pin Number</span>
  </label>
  <.input
    field={@form[:pin]}
    type="number"
    placeholder="Enter pin number (0-254)"
    min="0"
    max="254"
    class="input input-bordered w-full"
  />
</div>
```

3. Add BLDC-specific fields (after the debounce field block, before the buttons):

```elixir
<div :if={@form[:input_type].value in [:bldc_lever, "bldc_lever"]} class="space-y-4">
  <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1">
    Motor Pins
  </div>
  <div class="grid grid-cols-3 gap-3">
    <div>
      <label class="label"><span class="label-text text-xs">Phase A</span></label>
      <.input field={@form[:motor_pin_a]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Phase B</span></label>
      <.input field={@form[:motor_pin_b]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Phase C</span></label>
      <.input field={@form[:motor_pin_c]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
  </div>

  <div class="grid grid-cols-2 gap-3">
    <div>
      <label class="label"><span class="label-text text-xs">Enable A</span></label>
      <.input field={@form[:motor_enable_a]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Enable B</span></label>
      <.input field={@form[:motor_enable_b]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
  </div>

  <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1 mt-2">
    Encoder
  </div>
  <div class="grid grid-cols-2 gap-3">
    <div>
      <label class="label"><span class="label-text text-xs">SPI CS Pin</span></label>
      <.input field={@form[:encoder_cs]} type="number" min="0" max="255" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Resolution (bits)</span></label>
      <.input field={@form[:encoder_bits]} type="number" min="1" max="255" placeholder="14" class="input input-bordered input-sm w-full" />
    </div>
  </div>

  <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1 mt-2">
    Motor Parameters
  </div>
  <div class="grid grid-cols-3 gap-3">
    <div>
      <label class="label"><span class="label-text text-xs">Pole Pairs</span></label>
      <.input field={@form[:pole_pairs]} type="number" min="1" max="255" placeholder="11" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Voltage (0.1V)</span></label>
      <.input field={@form[:voltage]} type="number" min="1" max="255" placeholder="120" class="input input-bordered input-sm w-full" />
    </div>
    <div>
      <label class="label"><span class="label-text text-xs">Current Limit (0.1A)</span></label>
      <.input field={@form[:current_limit]} type="number" min="0" max="255" placeholder="0" class="input input-bordered input-sm w-full" />
    </div>
  </div>
</div>
```

**Step 2: Handle BLDC pin auto-assignment**

In the `add_regular_input/2` function (around line 562), add pin assignment for BLDC before calling `Hardware.create_input`:

```elixir
defp add_regular_input(socket, params) do
  # For BLDC lever, auto-set pin to encoder_cs value
  params =
    if params["input_type"] in ["bldc_lever", :bldc_lever] do
      Map.put(params, "pin", params["encoder_cs"])
    else
      params
    end

  case Hardware.create_input(socket.assigns.device.id, params) do
    # ... existing code unchanged
  end
end
```

**Step 3: Update the inputs table display**

In the `inputs_table/1` function (around line 1050-1056), add BLDC badge color:

```elixir
<span class={[
  "badge badge-sm capitalize",
  input.input_type == :analog && "badge-info",
  input.input_type == :button && "badge-warning",
  input.input_type == :bldc_lever && "badge-accent"
]}>
  {if input.input_type == :bldc_lever, do: "BLDC", else: input.input_type}
</span>
```

**Step 4: Run precommit checks**

Run: `mix precommit`
Expected: All pass (compile, format, credo, tests)

**Step 5: Commit**

```bash
git add lib/trenino_web/live/configuration_edit_live.ex
git commit -m "feat: add BLDC lever input form to Device Settings UI"
```

---

### Task 7: Setup Wizard — Filter inputs by lever type

**Files:**
- Modify: `lib/trenino_web/live/components/lever_setup_wizard.ex:96-100,506-509`

**Step 1: Update input filtering in initialize_wizard**

In `lib/trenino_web/live/components/lever_setup_wizard.ex`, replace lines 97-100:

```elixir
# Get all calibrated inputs (filtered by type later based on lever selection)
available_inputs =
  Hardware.list_all_inputs()
  |> Enum.filter(&(&1.input_type in [:analog, :bldc_lever]))
```

**Step 2: Update step flow for BLDC**

Replace `next_step_after_type_selection/1` (line 508-509) — BLDC should go through select_input now:

```elixir
defp next_step_after_type_selection(_), do: :select_input
```

**Step 3: Filter inputs by selected lever type in the select_input step**

Update the `step_select_input/1` function to filter inputs based on the selected lever type. The `step_content` dispatcher for `:select_input` (around line 880) needs the lever type. Update it to pass:

```elixir
defp step_content(%{current_step: :select_input} = assigns) do
  ~H"""
  <.step_select_input
    available_inputs={filter_inputs_for_type(@socket_assigns.available_inputs, @socket_assigns.selected_lever_type)}
    selected_input_id={@socket_assigns.selected_input_id}
    can_proceed={can_proceed_from?(:select_input, @socket_assigns)}
    myself={@myself}
  />
  """
end
```

Add the helper function:

```elixir
defp filter_inputs_for_type(inputs, :bldc), do: Enum.filter(inputs, &(&1.input_type == :bldc_lever))
defp filter_inputs_for_type(inputs, _), do: Enum.filter(inputs, &(&1.input_type == :analog))
```

**Step 4: Run precommit**

Run: `mix precommit`
Expected: All pass

**Step 5: Commit**

```bash
git add lib/trenino_web/live/components/lever_setup_wizard.ex
git commit -m "feat: setup wizard shows BLDC lever inputs when BLDC type selected"
```

---

### Task 8: Final verification

**Step 1: Run full test suite**

Run: `mix test`
Expected: All tests PASS

**Step 2: Run precommit**

Run: `mix precommit`
Expected: Clean (format, credo, tests, compile warnings)

**Step 3: Verify no compiler warnings**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation
