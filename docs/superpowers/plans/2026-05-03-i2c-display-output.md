# I2C Display Output Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add HT16K33 14-segment display support as a new output type, driveable via simple bindings or Lua scripts.

**Architecture:** New `Hardware.I2cModule` schema (separate from pin-based outputs) stores chip config per device. `Train.DisplayBinding` maps a simulator endpoint to a display via a format string. `DisplayController` polls subscriptions and sends `WriteSegments` messages. Lua scripts can call `display.set(addr, text)` directly. All i2c chip logic is isolated per chip module (`HT16K33`) so future chips slot in cleanly.

**Tech Stack:** Elixir/Phoenix, Ecto, LiveView, existing `lua` library for scripting.

---

## File Map

**New files:**
- `lib/trenino/serial/protocol/write_segments.ex` — protocol message type 13
- `lib/trenino/serial/protocol/set_module_brightness.ex` — protocol message type 14
- `lib/trenino/serial/protocol/module_error.ex` — protocol message type 15
- `lib/trenino/hardware/i2c_module.ex` — Ecto schema
- `lib/trenino/hardware/ht16k33.ex` — chip module: encode_string/2
- `lib/trenino/train/display_binding.ex` — Ecto schema
- `lib/trenino/train/display_formatter.ex` — format string evaluator
- `lib/trenino/train/display_controller.ex` — GenServer
- `lib/trenino/mcp/tools/display_binding_tools.ex` — MCP tools
- `lib/trenino_web/live/components/i2c_module_form_component.ex` — LiveComponent
- `lib/trenino_web/live/components/display_binding_wizard.ex` — LiveComponent
- `priv/repo/migrations/20260503200000_create_device_i2c_modules.exs`
- `priv/repo/migrations/20260503200001_create_train_display_bindings.exs`
- `test/trenino/serial/protocol/write_segments_test.exs`
- `test/trenino/hardware/ht16k33_test.exs`
- `test/trenino/train/display_formatter_test.exs`
- `test/trenino/train/display_controller_test.exs`
- `test/trenino/mcp/tools/display_binding_tools_test.exs`

**Modified files:**
- `lib/trenino/serial/protocol/configure.ex` — add `:ht16k33` input_type
- `lib/trenino/serial/protocol/message.ex` — decode types 0x0D, 0x0E, 0x0F
- `lib/trenino/hardware/device.ex` — `has_many :i2c_modules`
- `lib/trenino/hardware.ex` — i2c module CRUD + `write_segments/3`
- `lib/trenino/hardware/configuration_manager.ex` — include i2c modules in config, handle `ModuleError`
- `lib/trenino/train.ex` — display binding CRUD + `list_i2c_modules/0`
- `lib/trenino/train/script_engine.ex` — add `display.set()`
- `lib/trenino/train/script_runner.ex` — handle `{:display_set, addr, text}`
- `lib/trenino/mcp/tools/device_tools.ex` — 4 new i2c module tools
- `lib/trenino/mcp/tool_registry.ex` — add `DisplayBindingTools`
- `lib/trenino/application.ex` — start `DisplayController`
- `lib/trenino_web/live/configuration_edit_live.ex` — i2c modules section
- `lib/trenino_web/live/train_edit_live.ex` — display bindings section
- `lib/trenino_web/live/components/output_binding_wizard.ex` — remove "coming soon" note
- `test/trenino/mcp/tool_registry_test.exs` — update count 29 → 37
- `test/trenino/mcp/server_test.exs` — update count 29 → 37
- `test/trenino_web/controllers/mcp/mcp_controller_test.exs` — update count 29 → 37

---

## Task 1: Protocol messages — WriteSegments, SetModuleBrightness, ModuleError

**Files:**
- Create: `lib/trenino/serial/protocol/write_segments.ex`
- Create: `lib/trenino/serial/protocol/set_module_brightness.ex`
- Create: `lib/trenino/serial/protocol/module_error.ex`
- Modify: `lib/trenino/serial/protocol/message.ex`
- Create: `test/trenino/serial/protocol/write_segments_test.exs`

- [ ] **Write the failing test**

```elixir
# test/trenino/serial/protocol/write_segments_test.exs
defmodule Trenino.Serial.Protocol.WriteSegmentsTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.WriteSegments

  test "encodes correctly" do
    msg = %WriteSegments{i2c_address: 0x70, data: <<0x3F, 0x12, 0x06, 0x10>>}
    assert {:ok, <<0x0D, 0x70, 4, 0x3F, 0x12, 0x06, 0x10>>} = WriteSegments.encode(msg)
  end

  test "returns error for data longer than 16 bytes" do
    msg = %WriteSegments{i2c_address: 0x70, data: :binary.copy(<<0>>, 17)}
    assert {:error, :data_too_long} = WriteSegments.encode(msg)
  end

  test "decodes correctly" do
    assert {:ok, %WriteSegments{i2c_address: 0x70, data: <<0x3F, 0x12>>}} =
             WriteSegments.decode_body(<<0x70, 2, 0x3F, 0x12>>)
  end
end
```

- [ ] **Run test to confirm failure**

```bash
mix test test/trenino/serial/protocol/write_segments_test.exs
```
Expected: compile error (module not defined).

- [ ] **Create the three protocol message modules**

```elixir
# lib/trenino/serial/protocol/write_segments.ex
defmodule Trenino.Serial.Protocol.WriteSegments do
  @moduledoc "WriteSegments (0x0D) — Host → Device. Write raw segment bytes to an I2C display."

  alias Trenino.Serial.Protocol.Message
  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), data: binary()}
  defstruct [:i2c_address, :data]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, data: data}) when byte_size(data) <= 16 do
    {:ok, <<0x0D, addr::8-unsigned, byte_size(data)::8-unsigned, data::binary>>}
  end

  def encode(%__MODULE__{}), do: {:error, :data_too_long}

  @impl Message
  def decode_body(<<addr::8-unsigned, num_bytes::8-unsigned, data::binary-size(num_bytes)>>) do
    {:ok, %__MODULE__{i2c_address: addr, data: data}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
```

```elixir
# lib/trenino/serial/protocol/set_module_brightness.ex
defmodule Trenino.Serial.Protocol.SetModuleBrightness do
  @moduledoc "SetModuleBrightness (0x0E) — Host → Device. Set brightness on an I2C display module."

  alias Trenino.Serial.Protocol.Message
  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), brightness: integer()}
  defstruct [:i2c_address, :brightness]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, brightness: b}) when b in 0..15 do
    {:ok, <<0x0E, addr::8-unsigned, b::8-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_brightness}

  @impl Message
  def decode_body(<<addr::8-unsigned, b::8-unsigned>>) do
    {:ok, %__MODULE__{i2c_address: addr, brightness: b}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
```

```elixir
# lib/trenino/serial/protocol/module_error.ex
defmodule Trenino.Serial.Protocol.ModuleError do
  @moduledoc "ModuleError (0x0F) — Device → Host. Sent after ConfigurationStored for each I2C module that failed init."

  alias Trenino.Serial.Protocol.Message
  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), error_code: integer()}
  defstruct [:i2c_address, :error_code]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, error_code: code}) do
    {:ok, <<0x0F, addr::8-unsigned, code::8-unsigned>>}
  end

  @impl Message
  def decode_body(<<addr::8-unsigned, code::8-unsigned>>) do
    {:ok, %__MODULE__{i2c_address: addr, error_code: code}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
```

- [ ] **Update Message.decode/1 and aliases**

In `lib/trenino/serial/protocol/message.ex`, add to the alias block:

```elixir
alias Trenino.Serial.Protocol.{
  # ... existing aliases ...
  ModuleError,
  SetModuleBrightness,
  WriteSegments
}
```

Add decode clauses after `decode(<<0x08, ...>>)`:

```elixir
def decode(<<0x0D, rest::binary>>), do: WriteSegments.decode_body(rest)
def decode(<<0x0E, rest::binary>>), do: SetModuleBrightness.decode_body(rest)
def decode(<<0x0F, rest::binary>>), do: ModuleError.decode_body(rest)
```

- [ ] **Run tests and confirm pass**

```bash
mix test test/trenino/serial/protocol/write_segments_test.exs
```

- [ ] **Commit**

```bash
git add lib/trenino/serial/protocol/write_segments.ex \
        lib/trenino/serial/protocol/set_module_brightness.ex \
        lib/trenino/serial/protocol/module_error.ex \
        lib/trenino/serial/protocol/message.ex \
        test/trenino/serial/protocol/write_segments_test.exs
git commit -m "feat: add WriteSegments, SetModuleBrightness, ModuleError protocol messages"
```

---

## Task 2: Configure message — add HT16K33 module type

**Files:**
- Modify: `lib/trenino/serial/protocol/configure.ex`

- [ ] **Update the Configure struct and typespecs**

Add `:ht16k33` to the `input_type` type and add i2c fields to the struct. In `configure.ex`:

```elixir
@type input_type :: :analog | :button | :matrix | :ht16k33

@type t() :: %__MODULE__{
        config_id: integer(),
        total_parts: integer(),
        part_number: integer(),
        input_type: input_type(),
        pin: integer() | nil,
        sensitivity: integer() | nil,
        debounce: integer() | nil,
        row_pins: [integer()] | nil,
        col_pins: [integer()] | nil,
        i2c_address: integer() | nil,
        brightness: integer() | nil,
        num_digits: integer() | nil
      }

defstruct [
  :config_id, :total_parts, :part_number, :input_type,
  :pin, :sensitivity, :debounce, :row_pins, :col_pins,
  :i2c_address, :brightness, :num_digits
]
```

- [ ] **Add HT16K33 encode clause**

After the matrix encode clause, add:

```elixir
def encode(%__MODULE__{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :ht16k33,
      i2c_address: i2c_address,
      brightness: brightness,
      num_digits: num_digits
    }) do
  {:ok,
   <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
     0x04::8-unsigned, i2c_address::8-unsigned, brightness::8-unsigned,
     num_digits::8-unsigned>>}
end
```

- [ ] **Run precommit to confirm no regressions**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/serial/protocol/configure.ex
git commit -m "feat: add HT16K33 module type to Configure protocol message"
```

---

## Task 3: I2cModule schema + migration

**Files:**
- Create: `priv/repo/migrations/20260503200000_create_device_i2c_modules.exs`
- Create: `lib/trenino/hardware/i2c_module.ex`
- Modify: `lib/trenino/hardware/device.ex`

- [ ] **Write the migration**

```elixir
# priv/repo/migrations/20260503200000_create_device_i2c_modules.exs
defmodule Trenino.Repo.Migrations.CreateDeviceI2cModules do
  use Ecto.Migration

  def change do
    create table(:device_i2c_modules) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :name, :string
      add :module_chip, :string, null: false
      add :i2c_address, :integer, null: false
      add :brightness, :integer, null: false, default: 8
      add :num_digits, :integer, null: false, default: 4
      timestamps(type: :utc_datetime)
    end

    create index(:device_i2c_modules, [:device_id])
    create unique_index(:device_i2c_modules, [:device_id, :i2c_address])
  end
end
```

- [ ] **Create the I2cModule schema**

```elixir
# lib/trenino/hardware/i2c_module.ex
defmodule Trenino.Hardware.I2cModule do
  @moduledoc "Schema for I2C-attached modules on a device (e.g. HT16K33 14-segment display)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Device

  @type module_chip :: :ht16k33

  @type t :: %__MODULE__{
          id: integer() | nil,
          device_id: integer() | nil,
          name: String.t() | nil,
          module_chip: module_chip(),
          i2c_address: integer() | nil,
          brightness: integer() | nil,
          num_digits: integer() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_i2c_modules" do
    field :name, :string
    field :module_chip, Ecto.Enum, values: [:ht16k33]
    field :i2c_address, :integer
    field :brightness, :integer, default: 8
    field :num_digits, :integer, default: 4

    belongs_to :device, Device
    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = mod, attrs) do
    mod
    |> cast(attrs, [:device_id, :name, :module_chip, :i2c_address, :brightness, :num_digits])
    |> validate_required([:device_id, :module_chip, :i2c_address])
    |> validate_number(:i2c_address, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:brightness, greater_than_or_equal_to: 0, less_than_or_equal_to: 15)
    |> validate_inclusion(:num_digits, [4, 8])
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:device_id)
    |> unique_constraint([:device_id, :i2c_address])
  end

  @doc "Parse an i2c address string — accepts decimal ('112') or hex ('0x70')."
  @spec parse_i2c_address(String.t()) :: {:ok, integer()} | :error
  def parse_i2c_address("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {n, ""} when n in 0..255 -> {:ok, n}
      _ -> :error
    end
  end

  def parse_i2c_address(dec) do
    case Integer.parse(dec) do
      {n, ""} when n in 0..255 -> {:ok, n}
      _ -> :error
    end
  end

  @doc "Format an integer i2c address as '112 (0x70)' for display."
  @spec format_i2c_address(integer()) :: String.t()
  def format_i2c_address(addr) when is_integer(addr) do
    "#{addr} (0x#{Integer.to_string(addr, 16) |> String.pad_leading(2, "0")})"
  end
end
```

- [ ] **Add has_many to Device**

In `lib/trenino/hardware/device.ex`, add the alias and association:

```elixir
alias Trenino.Hardware.I2cModule

# in schema block, after has_many :outputs, Output:
has_many :i2c_modules, I2cModule
```

Also add `I2cModule` to the `@type t` `:i2c_modules` field:

```elixir
i2c_modules: [I2cModule.t()] | Ecto.Association.NotLoaded.t()
```

- [ ] **Run migration**

```bash
mix ecto.migrate
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add priv/repo/migrations/20260503200000_create_device_i2c_modules.exs \
        lib/trenino/hardware/i2c_module.ex \
        lib/trenino/hardware/device.ex
git commit -m "feat: add I2cModule schema and migration"
```

---

## Task 4: Hardware context — I2cModule CRUD + write_segments/3

**Files:**
- Modify: `lib/trenino/hardware.ex`

- [ ] **Add CRUD functions and write_segments to hardware.ex**

After the existing `list_outputs/1` and `create_output/2` functions, add:

```elixir
alias Trenino.Hardware.I2cModule
alias Trenino.Serial.Protocol.WriteSegments

@doc "List all i2c modules for a device."
@spec list_i2c_modules(integer()) :: [I2cModule.t()]
def list_i2c_modules(device_id) do
  I2cModule
  |> where([m], m.device_id == ^device_id)
  |> order_by([m], m.i2c_address)
  |> Repo.all()
end

@doc "List all i2c modules across all devices (for MCP tools)."
@spec list_all_i2c_modules() :: [I2cModule.t()]
def list_all_i2c_modules do
  I2cModule
  |> order_by([m], m.i2c_address)
  |> preload(:device)
  |> Repo.all()
end

@doc "Get a single i2c module by id."
@spec get_i2c_module(integer()) :: {:ok, I2cModule.t()} | {:error, :not_found}
def get_i2c_module(id) do
  case Repo.get(I2cModule, id) do
    nil -> {:error, :not_found}
    mod -> {:ok, Repo.preload(mod, :device)}
  end
end

@doc "Create an i2c module on a device."
@spec create_i2c_module(integer(), map()) :: {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
def create_i2c_module(device_id, attrs) do
  %I2cModule{device_id: device_id}
  |> I2cModule.changeset(attrs)
  |> Repo.insert()
end

@doc "Update an i2c module."
@spec update_i2c_module(I2cModule.t(), map()) ::
        {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
def update_i2c_module(%I2cModule{} = mod, attrs) do
  mod
  |> I2cModule.changeset(attrs)
  |> Repo.update()
end

@doc "Delete an i2c module."
@spec delete_i2c_module(I2cModule.t()) :: {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
def delete_i2c_module(%I2cModule{} = mod) do
  Repo.delete(mod)
end

@doc "Send WriteSegments to an I2C display module. data must be <= 16 bytes."
@spec write_segments(String.t(), integer(), binary()) :: :ok | {:error, term()}
def write_segments(port, i2c_address, data) do
  message = %WriteSegments{i2c_address: i2c_address, data: data}
  Connection.send_message(port, message)
end
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/hardware.ex
git commit -m "feat: add I2cModule CRUD and write_segments to Hardware context"
```

---

## Task 5: ConfigurationManager — include i2c modules + handle ModuleError

**Files:**
- Modify: `lib/trenino/hardware/configuration_manager.ex`

- [ ] **Update do_apply_configuration to load i2c modules**

Find `do_apply_configuration/3`. Change the `with` block to also load i2c modules and pass them through:

```elixir
defp do_apply_configuration(port, device_id, %State{} = state) do
  with {:ok, device} <- Hardware.get_device(device_id),
       {:ok, inputs} <- Hardware.list_inputs(device_id),
       {:ok, matrices} <- Hardware.list_matrices(device_id),
       i2c_modules = Hardware.list_i2c_modules(device_id),
       :ok <- validate_configuration(inputs, matrices, i2c_modules),
       config_id = device.config_id,
       :ok <- send_configuration_messages(port, config_id, inputs, matrices, i2c_modules) do
    timer_ref = Process.send_after(self(), {:config_timeout, config_id}, @config_timeout_ms)
    in_flight_info = %{port: port, timer_ref: timer_ref, device_id: device_id}
    new_in_flight = Map.put(state.in_flight, config_id, in_flight_info)
    {:ok, config_id, %{state | in_flight: new_in_flight}}
  end
end
```

Update `validate_configuration` to accept i2c modules — a device with only i2c modules (no inputs) is still invalid, since inputs are always required:

```elixir
defp validate_configuration([], [], _i2c_modules), do: {:error, :no_inputs}
defp validate_configuration(_inputs, _matrices, _i2c_modules), do: :ok
```

- [ ] **Update send_configuration_messages and build_config_parts**

```elixir
defp send_configuration_messages(port, config_id, inputs, matrices, i2c_modules) do
  config_parts = build_config_parts(inputs, matrices, i2c_modules)
  total_parts = length(config_parts)

  Logger.info(
    "Sending configuration to device on #{port}: config_id=#{config_id}, total_parts=#{total_parts}"
  )

  config_parts
  |> Enum.with_index()
  |> Enum.reduce_while(:ok, fn {part, index}, :ok ->
    message = build_configure_message(config_id, total_parts, index, part)
    Logger.info("  [#{index + 1}/#{total_parts}] #{inspect(message)}")

    case Connection.send_message(port, message) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end)
end

defp build_config_parts(inputs, matrices, i2c_modules) do
  input_parts = Enum.map(inputs, &{:input, &1})
  matrix_parts = Enum.map(matrices, &{:matrix, &1})
  i2c_parts = Enum.map(i2c_modules, &{:i2c_module, &1})
  input_parts ++ matrix_parts ++ i2c_parts
end
```

- [ ] **Add build_configure_message clause for i2c modules**

```elixir
defp build_configure_message(
       config_id,
       total_parts,
       part_number,
       {:i2c_module, %I2cModule{module_chip: :ht16k33} = mod}
     ) do
  %Configure{
    config_id: config_id,
    total_parts: total_parts,
    part_number: part_number,
    input_type: :ht16k33,
    i2c_address: mod.i2c_address,
    brightness: mod.brightness,
    num_digits: mod.num_digits
  }
end
```

Add `alias Trenino.Hardware.I2cModule` near the top of the module.

- [ ] **Handle ModuleError in the message handler**

Find where `ConfigurationStored` is handled (look for `handle_info` for serial messages). Add a clause for `ModuleError`:

```elixir
def handle_info(
      {:serial_message, _port, %ModuleError{i2c_address: addr, error_code: code}},
      %State{} = state
    ) do
  Logger.warning(
    "[ConfigurationManager] ModuleError: I2C module at #{I2cModule.format_i2c_address(addr)} failed init (error_code=#{code})"
  )

  {:noreply, state}
end
```

Add `alias Trenino.Serial.Protocol.ModuleError` to the module aliases.

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/hardware/configuration_manager.ex
git commit -m "feat: include i2c modules in device configuration messages"
```

---

## Task 6: HT16K33 chip module

**Files:**
- Create: `lib/trenino/hardware/ht16k33.ex`
- Create: `test/trenino/hardware/ht16k33_test.exs`

- [ ] **Write the failing tests**

```elixir
# test/trenino/hardware/ht16k33_test.exs
defmodule Trenino.Hardware.HT16K33Test do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.HT16K33

  test "encodes a single known digit" do
    # '0' = low:0x3F high:0x12
    assert <<0x3F, 0x12>> = HT16K33.encode_string("0", 1)
  end

  test "pads with spaces to num_digits" do
    # "1" on a 4-digit display: '1' then 3 spaces
    result = HT16K33.encode_string("1", 4)
    assert byte_size(result) == 8
    assert <<0x06, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>> = result
  end

  test "truncates to num_digits" do
    result = HT16K33.encode_string("12345", 4)
    assert byte_size(result) == 8
    # First 4 chars: '1','2','3','4'
    assert <<0x06, 0x10, 0xDB, 0x00, _::binary>> = result
  end

  test "unknown character renders as space" do
    result = HT16K33.encode_string("~", 1)
    assert <<0x00, 0x00>> = result
  end

  test "encodes '-'" do
    assert <<0xC0, 0x00>> = HT16K33.encode_string("-", 1)
  end

  test "output is always num_digits * 2 bytes" do
    for n <- [4, 8] do
      result = HT16K33.encode_string("", n)
      assert byte_size(result) == n * 2
    end
  end
end
```

- [ ] **Run to confirm failure**

```bash
mix test test/trenino/hardware/ht16k63_test.exs
```

- [ ] **Create the HT16K33 module**

```elixir
# lib/trenino/hardware/ht16k33.ex
defmodule Trenino.Hardware.HT16K33 do
  @moduledoc """
  Segment encoder for the Holtek HT16K33 14-segment LED display.

  encode_string/2 converts a UTF-8 string into raw segment bytes suitable for
  WriteSegments. Each character maps to 2 bytes (low, high) per the Adafruit
  alphafonttable. Unknown characters are rendered as space (0x00, 0x00).
  """

  # {low_byte, high_byte} per ASCII codepoint.
  # Source: Adafruit alphafonttable in Adafruit_LEDBackpack.cpp
  @segment_table %{
    0x20 => <<0x00, 0x00>>,  # space
    0x21 => <<0x06, 0x20>>,  # !
    0x22 => <<0x20, 0x20>>,  # "
    0x23 => <<0xCE, 0x12>>,  # #
    0x24 => <<0xED, 0x12>>,  # $
    0x25 => <<0x24, 0x0C>>,  # %
    0x26 => <<0x9B, 0x01>>,  # &
    0x27 => <<0x00, 0x02>>,  # '
    0x28 => <<0x00, 0x0C>>,  # (
    0x29 => <<0x00, 0x21>>,  # )
    0x2A => <<0xC0, 0x3F>>,  # *
    0x2B => <<0xC0, 0x12>>,  # +
    0x2C => <<0x00, 0x20>>,  # ,
    0x2D => <<0xC0, 0x00>>,  # -
    0x2E => <<0x00, 0x40>>,  # .
    0x2F => <<0x00, 0x0C>>,  # /
    0x30 => <<0x3F, 0x12>>,  # 0
    0x31 => <<0x06, 0x10>>,  # 1
    0x32 => <<0xDB, 0x00>>,  # 2
    0x33 => <<0x0F, 0x10>>,  # 3
    0x34 => <<0xE6, 0x00>>,  # 4
    0x35 => <<0xED, 0x00>>,  # 5
    0x36 => <<0xFD, 0x00>>,  # 6
    0x37 => <<0x07, 0x12>>,  # 7
    0x38 => <<0xFF, 0x00>>,  # 8
    0x39 => <<0xEF, 0x00>>,  # 9
    0x3A => <<0x00, 0x12>>,  # :
    0x3B => <<0x00, 0x22>>,  # ;
    0x3C => <<0x00, 0x0C>>,  # <
    0x3D => <<0xC8, 0x00>>,  # =
    0x3E => <<0x00, 0x21>>,  # >
    0x3F => <<0x83, 0x10>>,  # ?
    0x40 => <<0xBB, 0x02>>,  # @
    0x41 => <<0xF7, 0x00>>,  # A
    0x42 => <<0x8F, 0x12>>,  # B
    0x43 => <<0x39, 0x00>>,  # C
    0x44 => <<0x0F, 0x12>>,  # D
    0x45 => <<0xF9, 0x00>>,  # E
    0x46 => <<0xF1, 0x00>>,  # F
    0x47 => <<0xBD, 0x00>>,  # G
    0x48 => <<0xF6, 0x00>>,  # H
    0x49 => <<0x00, 0x12>>,  # I
    0x4A => <<0x1E, 0x00>>,  # J
    0x4B => <<0x70, 0x0C>>,  # K
    0x4C => <<0x38, 0x00>>,  # L
    0x4D => <<0x36, 0x05>>,  # M
    0x4E => <<0x36, 0x09>>,  # N
    0x4F => <<0x3F, 0x00>>,  # O
    0x50 => <<0xF3, 0x00>>,  # P
    0x51 => <<0x3F, 0x08>>,  # Q
    0x52 => <<0xF3, 0x08>>,  # R
    0x53 => <<0xED, 0x00>>,  # S
    0x54 => <<0x01, 0x12>>,  # T
    0x55 => <<0x3E, 0x00>>,  # U
    0x56 => <<0x30, 0x06>>,  # V
    0x57 => <<0x36, 0x28>>,  # W
    0x58 => <<0x00, 0x2D>>,  # X
    0x59 => <<0x00, 0x15>>,  # Y
    0x5A => <<0x09, 0x0C>>,  # Z
    0x5B => <<0x39, 0x00>>,  # [
    0x5C => <<0x00, 0x09>>,  # \
    0x5D => <<0x0F, 0x00>>,  # ]
    0x5E => <<0x00, 0x06>>,  # ^
    0x5F => <<0x08, 0x00>>,  # _
    0x60 => <<0x00, 0x02>>,  # `
    0x61 => <<0xFB, 0x00>>,  # a
    0x62 => <<0xF8, 0x00>>,  # b
    0x63 => <<0xD8, 0x00>>,  # c
    0x64 => <<0xDE, 0x00>>,  # d
    0x65 => <<0xFB, 0x00>>,  # e
    0x66 => <<0xF1, 0x00>>,  # f
    0x67 => <<0xEF, 0x00>>,  # g
    0x68 => <<0xF4, 0x00>>,  # h
    0x69 => <<0x00, 0x10>>,  # i
    0x6A => <<0x0E, 0x00>>,  # j
    0x6B => <<0x70, 0x0C>>,  # k
    0x6C => <<0x30, 0x00>>,  # l
    0x6D => <<0xD4, 0x00>>,  # m
    0x6E => <<0xD4, 0x00>>,  # n
    0x6F => <<0xDC, 0x00>>,  # o
    0x70 => <<0xF3, 0x00>>,  # p
    0x71 => <<0xE7, 0x00>>,  # q
    0x72 => <<0xD0, 0x00>>,  # r
    0x73 => <<0xED, 0x00>>,  # s
    0x74 => <<0xF8, 0x00>>,  # t
    0x75 => <<0x1C, 0x00>>,  # u
    0x76 => <<0x30, 0x06>>,  # v
    0x77 => <<0x36, 0x28>>,  # w
    0x78 => <<0x00, 0x2D>>,  # x
    0x79 => <<0x00, 0x15>>,  # y
    0x7A => <<0x09, 0x0C>>   # z
  }

  @blank <<0x00, 0x00>>

  @doc """
  Encode a string into raw HT16K33 segment bytes.

  Returns exactly `num_digits * 2` bytes. The string is truncated if too long
  and padded with spaces if too short. Characters not in the font table render
  as space.
  """
  @spec encode_string(String.t(), integer()) :: binary()
  def encode_string(text, num_digits) when is_binary(text) and num_digits in [4, 8] do
    text
    |> String.to_charlist()
    |> Enum.take(num_digits)
    |> Enum.map(&Map.get(@segment_table, &1, @blank))
    |> then(fn chars ->
      padding = List.duplicate(@blank, num_digits - length(chars))
      chars ++ padding
    end)
    |> Enum.join()
  end
end
```

- [ ] **Run tests**

```bash
mix test test/trenino/hardware/ht16k33_test.exs
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/hardware/ht16k33.ex test/trenino/hardware/ht16k33_test.exs
git commit -m "feat: add HT16K33 segment encoder"
```

---

## Task 7: DisplayBinding schema + migration + Train context

**Files:**
- Create: `priv/repo/migrations/20260503200001_create_train_display_bindings.exs`
- Create: `lib/trenino/train/display_binding.ex`
- Modify: `lib/trenino/train.ex`
- Create: `test/trenino/train/display_formatter_test.exs` (formatter only — controller tested separately)

- [ ] **Write the migration**

```elixir
# priv/repo/migrations/20260503200001_create_train_display_bindings.exs
defmodule Trenino.Repo.Migrations.CreateTrainDisplayBindings do
  use Ecto.Migration

  def change do
    create table(:train_display_bindings) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :i2c_module_id, references(:device_i2c_modules, on_delete: :delete_all), null: false
      add :name, :string
      add :endpoint, :string, null: false
      add :format_string, :string, null: false, default: "{value}"
      add :enabled, :boolean, null: false, default: true
      add :script_id, references(:scripts, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:train_display_bindings, [:train_id])
    create unique_index(:train_display_bindings, [:train_id, :i2c_module_id])
  end
end
```

- [ ] **Create the DisplayBinding schema**

```elixir
# lib/trenino/train/display_binding.ex
defmodule Trenino.Train.DisplayBinding do
  @moduledoc """
  Binds a simulator endpoint to an I2C display module.

  The endpoint value is formatted via `format_string` and sent as segment bytes
  on every change. Supported format tokens:
  - `{value}` — raw value as string
  - `{value:.Nf}` — float formatted to N decimal places
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.I2cModule
  alias Trenino.Train.Train

  @type t :: %__MODULE__{
          id: integer() | nil,
          train_id: integer() | nil,
          i2c_module_id: integer() | nil,
          name: String.t() | nil,
          endpoint: String.t() | nil,
          format_string: String.t(),
          enabled: boolean(),
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          i2c_module: I2cModule.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_display_bindings" do
    field :name, :string
    field :endpoint, :string
    field :format_string, :string, default: "{value}"
    field :enabled, :boolean, default: true

    belongs_to :train, Train
    belongs_to :i2c_module, I2cModule

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [:train_id, :i2c_module_id, :name, :endpoint, :format_string, :enabled])
    |> validate_required([:train_id, :i2c_module_id, :endpoint, :format_string])
    |> validate_length(:name, max: 100)
    |> validate_length(:format_string, min: 1, max: 200)
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:i2c_module_id)
    |> unique_constraint([:train_id, :i2c_module_id])
  end
end
```

- [ ] **Add display binding functions to train.ex**

After the existing `delete_output_binding` function, add:

```elixir
alias Trenino.Train.DisplayBinding

def list_display_bindings(train_id) do
  DisplayBinding
  |> where([d], d.train_id == ^train_id)
  |> order_by([d], d.name)
  |> preload(i2c_module: :device)
  |> Repo.all()
end

def list_enabled_display_bindings(train_id) do
  DisplayBinding
  |> where([d], d.train_id == ^train_id and d.enabled == true)
  |> preload(i2c_module: :device)
  |> Repo.all()
end

def get_display_binding(id) do
  case Repo.get(DisplayBinding, id) do
    nil -> {:error, :not_found}
    b -> {:ok, Repo.preload(b, i2c_module: :device)}
  end
end

def create_display_binding(train_id, attrs) do
  %DisplayBinding{train_id: train_id}
  |> DisplayBinding.changeset(attrs)
  |> Repo.insert()
end

def update_display_binding(%DisplayBinding{} = binding, attrs) do
  binding
  |> DisplayBinding.changeset(attrs)
  |> Repo.update()
end

def delete_display_binding(%DisplayBinding{} = binding) do
  Repo.delete(binding)
end
```

Also add a convenience for MCP tools — expose i2c modules via Train context:

```elixir
def list_all_i2c_modules, do: Hardware.list_all_i2c_modules()
```

- [ ] **Run migration**

```bash
mix ecto.migrate
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add priv/repo/migrations/20260503200001_create_train_display_bindings.exs \
        lib/trenino/train/display_binding.ex \
        lib/trenino/train.ex
git commit -m "feat: add DisplayBinding schema, migration, and Train context functions"
```

---

## Task 8: DisplayFormatter

**Files:**
- Create: `lib/trenino/train/display_formatter.ex`
- Create: `test/trenino/train/display_formatter_test.exs`

- [ ] **Write tests first**

```elixir
# test/trenino/train/display_formatter_test.exs
defmodule Trenino.Train.DisplayFormatterTest do
  use ExUnit.Case, async: true
  alias Trenino.Train.DisplayFormatter

  test "{value} passes numeric value as string" do
    assert "42.5" = DisplayFormatter.format("{value}", 42.5)
  end

  test "{value} passes string value through" do
    assert "hello" = DisplayFormatter.format("{value}", "hello")
  end

  test "{value} passes boolean as string" do
    assert "true" = DisplayFormatter.format("{value}", true)
  end

  test "{value:.0f} formats float with 0 decimal places" do
    assert "43" = DisplayFormatter.format("{value:.0f}", 42.5)
  end

  test "{value:.2f} formats float with 2 decimal places" do
    assert "42.50" = DisplayFormatter.format("{value:.2f}", 42.5)
  end

  test "{value:.1f} with integer value" do
    assert "42.0" = DisplayFormatter.format("{value:.1f}", 42)
  end

  test "surrounding text is preserved" do
    assert "V:42.5" = DisplayFormatter.format("V:{value:.1f}", 42.5)
  end

  test "{value} with prefix and suffix" do
    assert "~42~" = DisplayFormatter.format("~{value}~", 42)
  end
end
```

- [ ] **Run to confirm failure**

```bash
mix test test/trenino/train/display_formatter_test.exs
```

- [ ] **Implement DisplayFormatter**

```elixir
# lib/trenino/train/display_formatter.ex
defmodule Trenino.Train.DisplayFormatter do
  @moduledoc """
  Evaluates display format strings against a runtime value.

  Supported tokens:
  - `{value}` — replaced with `to_string(value)`
  - `{value:.Nf}` — replaced with float formatted to N decimal places
  """

  @spec format(String.t(), term()) :: String.t()
  def format(format_string, value) when is_binary(format_string) do
    Regex.replace(~r/\{value(?:\.(\d+)f)?\}/, format_string, fn
      _, "" -> to_string(value)
      _, decimals -> format_float(value, String.to_integer(decimals))
    end)
  end

  defp format_float(value, decimals) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [{:decimals, decimals}])
  end

  defp format_float(value, _decimals), do: to_string(value)
end
```

- [ ] **Run tests**

```bash
mix test test/trenino/train/display_formatter_test.exs
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/train/display_formatter.ex test/trenino/train/display_formatter_test.exs
git commit -m "feat: add DisplayFormatter for format string evaluation"
```

---

## Task 9: DisplayController GenServer

**Files:**
- Create: `lib/trenino/train/display_controller.ex`
- Modify: `lib/trenino/application.ex`
- Create: `test/trenino/train/display_controller_test.exs`

- [ ] **Write tests**

```elixir
# test/trenino/train/display_controller_test.exs
defmodule Trenino.Train.DisplayControllerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train.DisplayController

  test "starts successfully" do
    assert pid = Process.whereis(DisplayController)
    assert Process.alive?(pid)
  end

  test "reload_bindings/0 returns :ok" do
    assert :ok = DisplayController.reload_bindings()
  end
end
```

- [ ] **Run to confirm failure** (DisplayController not started yet)

```bash
mix test test/trenino/train/display_controller_test.exs
```

- [ ] **Create DisplayController**

```elixir
# lib/trenino/train/display_controller.ex
defmodule Trenino.Train.DisplayController do
  @moduledoc """
  Drives I2C display modules based on simulator endpoint values.

  Mirrors OutputController but sends WriteSegments instead of SetOutput.
  Subscription ID range: 2000–2999.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.HT16K33
  alias Trenino.Hardware.I2cModule
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayFormatter

  @poll_interval_ms 200
  @subscription_id_base 2000

  defmodule State do
    @moduledoc false

    @type binding_info :: %{
            binding: DisplayBinding.t(),
            subscription_id: integer(),
            last_text: String.t() | nil
          }

    @type t :: %__MODULE__{
            active_train: map() | nil,
            bindings: %{integer() => binding_info()},
            subscriptions: %{String.t() => integer()},
            poll_timer: reference() | nil
          }

    defstruct active_train: nil, bindings: %{}, subscriptions: %{}, poll_timer: nil
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec reload_bindings() :: :ok
  def reload_bindings, do: GenServer.cast(__MODULE__, :reload_bindings)

  @impl true
  def init(:ok) do
    Train.subscribe()
    state = %State{}

    state =
      case Train.get_active_train() do
        nil -> state
        train -> load_bindings_for_train(state, train)
      end

    {:ok, state}
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state), do: {:noreply, state}

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[DisplayController] Train deactivated")
    state = cleanup(state)
    {:noreply, %{state | active_train: nil, bindings: %{}, subscriptions: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[DisplayController] Train activated: #{train.name}")
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, state), do: {:noreply, state}
  def handle_info({:detection_error, _}, state), do: {:noreply, state}

  def handle_info(:poll_displays, %State{} = state) do
    state = poll_and_update(state)
    {:noreply, schedule_poll(state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_display_bindings(train.id)

    if Enum.empty?(bindings) do
      %{state | active_train: train, bindings: %{}, subscriptions: %{}}
    else
      case get_simulator_client() do
        {:ok, client} ->
          {binding_map, sub_map} = setup_subscriptions(client, bindings)

          Logger.info(
            "[DisplayController] Loaded #{map_size(binding_map)} display bindings for #{train.name}"
          )

          schedule_poll(%{state | active_train: train, bindings: binding_map, subscriptions: sub_map})

        :error ->
          Logger.warning("[DisplayController] Simulator not connected, skipping subscriptions")
          %{state | active_train: train, bindings: %{}, subscriptions: %{}}
      end
    end
  end

  defp setup_subscriptions(client, bindings) do
    bindings
    |> Enum.group_by(& &1.endpoint)
    |> Enum.with_index()
    |> Enum.reduce({%{}, %{}}, fn {{endpoint, group}, index}, {b_acc, s_acc} ->
      sub_id = @subscription_id_base + index

      case SimulatorClient.subscribe(client, endpoint, sub_id) do
        {:ok, _} ->
          updated =
            Enum.reduce(group, b_acc, fn %DisplayBinding{} = binding, acc ->
              Map.put(acc, binding.id, %{binding: binding, subscription_id: sub_id, last_text: nil})
            end)

          {updated, Map.put(s_acc, endpoint, sub_id)}

        {:error, reason} ->
          Logger.warning("[DisplayController] Failed to subscribe to #{endpoint}: #{inspect(reason)}")
          {b_acc, s_acc}
      end
    end)
  end

  defp cleanup(%State{poll_timer: timer, subscriptions: subs, bindings: bindings} = state) do
    if timer, do: Process.cancel_timer(timer)

    case get_simulator_client() do
      {:ok, client} -> Enum.each(subs, fn {_, sub_id} -> SimulatorClient.unsubscribe(client, sub_id) end)
      :error -> :ok
    end

    Enum.each(bindings, fn {_, info} -> blank_display(info.binding) end)

    %{state | poll_timer: nil}
  end

  defp schedule_poll(%State{bindings: b} = state) when map_size(b) > 0 do
    %{state | poll_timer: Process.send_after(self(), :poll_displays, @poll_interval_ms)}
  end

  defp schedule_poll(%State{} = state), do: state

  defp poll_and_update(%State{} = state) do
    case get_simulator_client() do
      {:ok, client} ->
        state.bindings
        |> Enum.group_by(fn {_, info} -> info.subscription_id end)
        |> Enum.reduce(state, fn {sub_id, entries}, acc ->
          process_subscription(client, sub_id, entries, acc)
        end)

      :error ->
        state
    end
  end

  defp process_subscription(client, sub_id, entries, state) do
    case SimulatorClient.get_subscription(client, sub_id) do
      {:ok, %{"Entries" => [%{"Values" => values, "NodeValid" => true} | _]}}
      when map_size(values) > 0 ->
        raw = values |> Map.values() |> List.first()
        value = if is_number(raw), do: Float.round(raw * 1.0, 2), else: raw
        update_displays(state, entries, value)

      _ ->
        state
    end
  end

  defp update_displays(state, entries, value) do
    Enum.reduce(entries, state, fn {id, info}, acc ->
      text = DisplayFormatter.format(info.binding.format_string, value)

      if text != info.last_text do
        send_to_display(info.binding, text)
        %{acc | bindings: Map.put(acc.bindings, id, %{info | last_text: text})}
      else
        acc
      end
    end)
  end

  defp send_to_display(%DisplayBinding{i2c_module: %I2cModule{} = mod} = _binding, text) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      chip_mod = chip_module(mod.module_chip)
      bytes = chip_mod.encode_string(text, mod.num_digits)
      Hardware.write_segments(port, mod.i2c_address, bytes)
    end
  end

  defp blank_display(%DisplayBinding{i2c_module: %I2cModule{} = mod}) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      blank = :binary.copy(<<0>>, mod.num_digits * 2)
      Hardware.write_segments(port, mod.i2c_address, blank)
    end
  end

  defp chip_module(:ht16k33), do: HT16K33

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil -> {:ok, client}
      _ -> :error
    end
  end
end
```

- [ ] **Start DisplayController in application.ex**

Find the children list in `lib/trenino/application.ex`. After the line that starts `Trenino.Train.OutputController`, add:

```elixir
Trenino.Train.DisplayController,
```

- [ ] **Run tests**

```bash
mix test test/trenino/train/display_controller_test.exs
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/train/display_controller.ex \
        lib/trenino/application.ex \
        test/trenino/train/display_controller_test.exs
git commit -m "feat: add DisplayController GenServer"
```

---

## Task 10: Lua display.set() — ScriptEngine + ScriptRunner

**Files:**
- Modify: `lib/trenino/train/script_engine.ex`
- Modify: `lib/trenino/train/script_runner.ex`

- [ ] **Update ScriptEngine — add display.set()**

In `lib/trenino/train/script_engine.ex`, add `:display_set` to the `@type side_effect` union:

```elixir
@type side_effect ::
        {:api_get, String.t()}
        | {:api_set, String.t(), number()}
        | {:output_set, integer(), boolean()}
        | {:display_set, integer(), String.t()}
        | {:schedule, pos_integer()}
        | {:log, String.t()}
```

In `new/1`, add `|> setup_display()` in the pipeline after `|> setup_output()`.

Add the private function:

```elixir
defp setup_display(lua) do
  Lua.set!(lua, [:display, :set], fn args ->
    case args do
      [addr, text] when is_number(addr) and is_binary(text) ->
        add_side_effect({:display_set, trunc(addr), text})
        [true]

      _ ->
        [nil, "usage: display.set(i2c_address, text)"]
    end
  end)
end
```

- [ ] **Update ScriptRunner — handle :display_set**

In `lib/trenino/train/script_runner.ex`, find the `process_effect` clause for `{:output_set, ...}` and add after it:

```elixir
defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:display_set, addr, text}) do
  apply_display_set(addr, text)
  script_state
end
```

Add the private helper:

```elixir
defp apply_display_set(i2c_address, text) do
  # Find any connected device that has a module with this i2c address
  modules = Hardware.list_all_i2c_modules()

  case Enum.find(modules, &(&1.i2c_address == i2c_address)) do
    nil ->
      Logger.warning("[ScriptRunner] No i2c module found at address #{i2c_address}")

    mod ->
      port = ConfigurationManager.config_id_to_port(mod.device.config_id)

      if port do
        chip_mod = chip_module(mod.module_chip)
        bytes = chip_mod.encode_string(text, mod.num_digits)
        Hardware.write_segments(port, i2c_address, bytes)
      end
  end
end

defp chip_module(:ht16k33), do: Trenino.Hardware.HT16K33
```

Add `alias Trenino.Hardware` and `alias Trenino.Hardware.ConfigurationManager` if not already present.

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/train/script_engine.ex lib/trenino/train/script_runner.ex
git commit -m "feat: add display.set() to Lua scripting API"
```

---

## Task 11: MCP tools — i2c modules (DeviceTools) + DisplayBindingTools

**Files:**
- Modify: `lib/trenino/mcp/tools/device_tools.ex`
- Create: `lib/trenino/mcp/tools/display_binding_tools.ex`
- Modify: `lib/trenino/mcp/tool_registry.ex`
- Modify: `test/trenino/mcp/tool_registry_test.exs`
- Modify: `test/trenino/mcp/server_test.exs`
- Modify: `test/trenino_web/controllers/mcp/mcp_controller_test.exs`
- Create: `test/trenino/mcp/tools/display_binding_tools_test.exs`

- [ ] **Update tool count assertions from 29 to 37**

In each of the three test files, find the assertion on tool count and change `29` to `37`:

```bash
grep -n "29" test/trenino/mcp/tool_registry_test.exs \
            test/trenino/mcp/server_test.exs \
            test/trenino_web/controllers/mcp/mcp_controller_test.exs
```

Replace each occurrence of the count `29` with `37` (8 new tools: 4 i2c module + 4 display binding).

- [ ] **Add i2c module tools to DeviceTools**

In `lib/trenino/mcp/tools/device_tools.ex`, add to the `tools/0` list:

```elixir
%{
  name: "list_i2c_modules",
  description: "List all I2C modules configured on any device. Use this to find i2c_module_id when creating display bindings.",
  input_schema: %{type: "object", properties: %{}}
},
%{
  name: "create_i2c_module",
  description: "Add an I2C module to a device. i2c_address accepts decimal (112) or hex (0x70). module_chip must be 'ht16k33'. brightness 0–15. num_digits 4 or 8.",
  input_schema: %{
    type: "object",
    properties: %{
      device_id: %{type: "integer", description: "Device ID"},
      name: %{type: "string", description: "Human-readable name, e.g. 'Speed display'"},
      module_chip: %{type: "string", enum: ["ht16k33"]},
      i2c_address: %{type: "string", description: "I2C address: decimal '112' or hex '0x70'"},
      brightness: %{type: "integer", description: "0–15"},
      num_digits: %{type: "integer", enum: [4, 8]}
    },
    required: ["device_id", "module_chip", "i2c_address"]
  }
},
%{
  name: "update_i2c_module",
  description: "Update an I2C module's name, brightness, or num_digits.",
  input_schema: %{
    type: "object",
    properties: %{
      id: %{type: "integer"},
      name: %{type: "string"},
      brightness: %{type: "integer", description: "0–15"},
      num_digits: %{type: "integer", enum: [4, 8]}
    },
    required: ["id"]
  }
},
%{
  name: "delete_i2c_module",
  description: "Delete an I2C module from a device.",
  input_schema: %{
    type: "object",
    properties: %{id: %{type: "integer"}},
    required: ["id"]
  }
}
```

Add execute clauses in `DeviceTools.execute/2`:

```elixir
def execute("list_i2c_modules", _args) do
  modules = Hardware.list_all_i2c_modules()
  {:ok, %{i2c_modules: Enum.map(modules, &serialize_i2c_module/1)}}
end

def execute("create_i2c_module", %{"device_id" => device_id} = args) do
  with {:ok, addr} <- parse_i2c_address(Map.get(args, "i2c_address", "")) do
    attrs =
      args
      |> Map.take(["name", "module_chip", "brightness", "num_digits"])
      |> Enum.reduce(%{i2c_address: addr}, fn {k, v}, acc ->
        Map.put(acc, String.to_existing_atom(k), v)
      end)

    case Hardware.create_i2c_module(device_id, attrs) do
      {:ok, mod} -> {:ok, %{i2c_module: serialize_i2c_module(Repo.preload(mod, :device))}}
      {:error, changeset} -> {:error, format_changeset_errors(changeset)}
    end
  else
    :error -> {:error, "Invalid i2c_address: use decimal (112) or hex (0x70)"}
  end
end

def execute("update_i2c_module", %{"id" => id} = args) do
  case Hardware.get_i2c_module(id) do
    {:ok, mod} ->
      attrs = Map.take(args, ["name", "brightness", "num_digits"])
      |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v) end)

      case Hardware.update_i2c_module(mod, attrs) do
        {:ok, updated} -> {:ok, %{i2c_module: serialize_i2c_module(updated)}}
        {:error, changeset} -> {:error, format_changeset_errors(changeset)}
      end

    {:error, :not_found} -> {:error, "I2C module not found with id #{id}"}
  end
end

def execute("delete_i2c_module", %{"id" => id}) do
  case Hardware.get_i2c_module(id) do
    {:ok, mod} ->
      case Hardware.delete_i2c_module(mod) do
        {:ok, _} -> {:ok, %{deleted: true, id: id}}
        {:error, changeset} -> {:error, format_changeset_errors(changeset)}
      end

    {:error, :not_found} -> {:error, "I2C module not found with id #{id}"}
  end
end
```

Add the helpers (these go in the private section at the bottom):

```elixir
defp parse_i2c_address(str), do: Trenino.Hardware.I2cModule.parse_i2c_address(str)

defp serialize_i2c_module(mod) do
  %{
    id: mod.id,
    device_id: mod.device_id,
    device_name: mod.device.name,
    name: mod.name,
    module_chip: mod.module_chip,
    i2c_address: mod.i2c_address,
    i2c_address_display: Trenino.Hardware.I2cModule.format_i2c_address(mod.i2c_address),
    brightness: mod.brightness,
    num_digits: mod.num_digits
  }
end
```

Add `alias Trenino.Hardware` if not already present, and add `alias Trenino.Repo`.

- [ ] **Create DisplayBindingTools**

```elixir
# lib/trenino/mcp/tools/display_binding_tools.ex
defmodule Trenino.MCP.Tools.DisplayBindingTools do
  @moduledoc "MCP tools for CRUD operations on display bindings."

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.DisplayController

  def tools do
    [
      %{
        name: "list_display_bindings",
        description: "List all display bindings for a train.",
        input_schema: %{
          type: "object",
          properties: %{train_id: %{type: "integer"}},
          required: ["train_id"]
        }
      },
      %{
        name: "create_display_binding",
        description:
          "Create a display binding that shows a simulator endpoint value on an I2C display. " <>
            "Use list_i2c_modules to find i2c_module_id. " <>
            "format_string tokens: '{value}' (raw), '{value:.Nf}' (float with N decimals). " <>
            "Example: '{value:.0f}' shows speed as integer.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer"},
            name: %{type: "string", description: "e.g. 'Train speed'"},
            i2c_module_id: %{type: "integer"},
            endpoint: %{type: "string", description: "Simulator endpoint path"},
            format_string: %{type: "string", description: "e.g. '{value:.0f}' or '{value}'"},
            enabled: %{type: "boolean"}
          },
          required: ["train_id", "i2c_module_id", "endpoint", "format_string"]
        }
      },
      %{
        name: "update_display_binding",
        description: "Update an existing display binding.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer"},
            name: %{type: "string"},
            i2c_module_id: %{type: "integer"},
            endpoint: %{type: "string"},
            format_string: %{type: "string"},
            enabled: %{type: "boolean"}
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_display_binding",
        description: "Delete a display binding.",
        input_schema: %{
          type: "object",
          properties: %{id: %{type: "integer"}},
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_display_bindings", %{"train_id" => train_id}) do
    bindings = TrainContext.list_display_bindings(train_id) |> Enum.map(&serialize/1)
    {:ok, %{display_bindings: bindings}}
  end

  def execute("create_display_binding", %{"train_id" => train_id} = args) do
    attrs = build_attrs(args)

    case TrainContext.create_display_binding(train_id, attrs) do
      {:ok, binding} ->
        DisplayController.reload_bindings()
        {:ok, %{display_binding: serialize(binding)}}

      {:error, changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("update_display_binding", %{"id" => id} = args) do
    case TrainContext.get_display_binding(id) do
      {:ok, binding} ->
        case TrainContext.update_display_binding(binding, build_attrs(args)) do
          {:ok, updated} ->
            DisplayController.reload_bindings()
            {:ok, %{display_binding: serialize(updated)}}

          {:error, changeset} ->
            {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Display binding not found with id #{id}"}
    end
  end

  def execute("delete_display_binding", %{"id" => id}) do
    case TrainContext.get_display_binding(id) do
      {:ok, binding} ->
        case TrainContext.delete_display_binding(binding) do
          {:ok, _} ->
            DisplayController.reload_bindings()
            {:ok, %{deleted: true, id: id}}

          {:error, changeset} ->
            {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Display binding not found with id #{id}"}
    end
  end

  defp build_attrs(args) do
    args
    |> Map.take(["name", "i2c_module_id", "endpoint", "format_string", "enabled"])
    |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v) end)
  end

  defp serialize(b) do
    %{
      id: b.id,
      train_id: b.train_id,
      i2c_module_id: b.i2c_module_id,
      name: b.name,
      endpoint: b.endpoint,
      format_string: b.format_string,
      enabled: b.enabled
    }
  end

  defp format_changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    "Validation failed: " <>
      Enum.map_join(errors, "; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)
  end
end
```

- [ ] **Register DisplayBindingTools in the registry**

In `lib/trenino/mcp/tool_registry.ex`, add to the alias block:

```elixir
alias Trenino.MCP.Tools.DisplayBindingTools
```

Add to `@tool_modules`:

```elixir
DisplayBindingTools,
```

- [ ] **Write a basic smoke test for DisplayBindingTools**

```elixir
# test/trenino/mcp/tools/display_binding_tools_test.exs
defmodule Trenino.MCP.Tools.DisplayBindingToolsTest do
  use Trenino.DataCase, async: true
  alias Trenino.MCP.Tools.DisplayBindingTools

  test "tools/0 returns 4 tools" do
    assert length(DisplayBindingTools.tools()) == 4
  end

  test "list_display_bindings returns empty list for unknown train" do
    assert {:ok, %{display_bindings: []}} =
             DisplayBindingTools.execute("list_display_bindings", %{"train_id" => 0})
  end
end
```

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino/mcp/tools/device_tools.ex \
        lib/trenino/mcp/tools/display_binding_tools.ex \
        lib/trenino/mcp/tool_registry.ex \
        test/trenino/mcp/tools/display_binding_tools_test.exs \
        test/trenino/mcp/tool_registry_test.exs \
        test/trenino/mcp/server_test.exs \
        test/trenino_web/controllers/mcp/mcp_controller_test.exs
git commit -m "feat: add MCP tools for i2c modules and display bindings"
```

---

## Task 12: UI — I2cModuleFormComponent + configuration_edit_live.ex

**Files:**
- Create: `lib/trenino_web/live/components/i2c_module_form_component.ex`
- Modify: `lib/trenino_web/live/configuration_edit_live.ex`

- [ ] **Create I2cModuleFormComponent**

```elixir
# lib/trenino_web/live/components/i2c_module_form_component.ex
defmodule TreninoWeb.I2cModuleFormComponent do
  @moduledoc "Form for creating or editing an I2C module on a device."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule

  @impl true
  def update(%{module: mod, device_id: device_id} = _assigns, socket) do
    changeset = I2cModule.changeset(mod || %I2cModule{}, %{})

    {:ok,
     socket
     |> assign(:module, mod)
     |> assign(:device_id, device_id)
     |> assign(:form, to_form(changeset))
     |> assign(:i2c_address_input, if(mod, do: I2cModule.format_i2c_address(mod.i2c_address), else: ""))}
  end

  @impl true
  def handle_event("validate", %{"i2c_module" => params}, socket) do
    changeset =
      (socket.assigns.module || %I2cModule{})
      |> I2cModule.changeset(coerce_params(params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))}
  end

  def handle_event("save", %{"i2c_module" => params}, socket) do
    coerced = coerce_params(params)

    result =
      case socket.assigns.module do
        nil -> Hardware.create_i2c_module(socket.assigns.device_id, coerced)
        mod -> Hardware.update_i2c_module(mod, coerced)
      end

    case result do
      {:ok, _mod} ->
        send(self(), :i2c_module_saved)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp coerce_params(params) do
    addr_str = Map.get(params, "i2c_address_raw", "")

    addr =
      case I2cModule.parse_i2c_address(addr_str) do
        {:ok, n} -> n
        :error -> nil
      end

    params
    |> Map.put("i2c_address", addr)
    |> Map.take(["name", "module_chip", "i2c_address", "brightness", "num_digits"])
    |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_atom(k), v) end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="grid grid-cols-1 gap-4">
          <div>
            <.input field={@form[:name]} label="Name" placeholder="e.g. Speed display" />
          </div>
          <div>
            <label class="label"><span class="label-text font-medium">Chip</span></label>
            <select name="i2c_module[module_chip]" class="select select-bordered w-full">
              <option value="ht16k33" selected={to_string(@form[:module_chip].value) == "ht16k33"}>
                HT16K33 (14-segment display)
              </option>
            </select>
          </div>
          <div>
            <label class="label">
              <span class="label-text font-medium">I2C Address</span>
              <span class="label-text-alt text-base-content/50">decimal or hex (e.g. 112 or 0x70)</span>
            </label>
            <input
              type="text"
              name="i2c_module[i2c_address_raw]"
              value={@i2c_address_input}
              placeholder="0x70"
              class="input input-bordered w-full"
            />
            <.error :for={msg <- @form[:i2c_address].errors |> Enum.map(&elem(&1, 0))}>{msg}</.error>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="label"><span class="label-text font-medium">Brightness</span></label>
              <input
                type="number"
                name="i2c_module[brightness]"
                value={@form[:brightness].value || 8}
                min="0"
                max="15"
                class="input input-bordered w-full"
              />
            </div>
            <div>
              <label class="label"><span class="label-text font-medium">Digits</span></label>
              <select name="i2c_module[num_digits]" class="select select-bordered w-full">
                <option value="4" selected={to_string(@form[:num_digits].value) == "4"}>4 digits</option>
                <option value="8" selected={to_string(@form[:num_digits].value) == "8"}>8 digits</option>
              </select>
            </div>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" phx-click="close_i2c_modal" class="btn btn-ghost">Cancel</button>
          <button type="submit" class="btn btn-primary">
            {if @module, do: "Save", else: "Add"}
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
```

- [ ] **Update configuration_edit_live.ex — add i2c modules section**

Find the `mount_new/1` and `mount_existing/2` private functions. In each, add alongside the existing `outputs` assign:

```elixir
|> assign(:i2c_modules, [])
|> assign(:i2c_modal_open, false)
|> assign(:i2c_modal_module, nil)
```

In `mount_existing/2`, load i2c modules:

```elixir
i2c_modules = Hardware.list_i2c_modules(device.id)
# add to the assign chain:
|> assign(:i2c_modules, i2c_modules)
```

Add event handlers:

```elixir
def handle_event("open_add_i2c_modal", _params, socket) do
  {:noreply, socket |> assign(:i2c_modal_open, true) |> assign(:i2c_modal_module, nil)}
end

def handle_event("open_edit_i2c_modal", %{"id" => id_str}, socket) do
  case Hardware.get_i2c_module(String.to_integer(id_str)) do
    {:ok, mod} ->
      {:noreply, socket |> assign(:i2c_modal_open, true) |> assign(:i2c_modal_module, mod)}
    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Module not found")}
  end
end

def handle_event("close_i2c_modal", _params, socket) do
  {:noreply, socket |> assign(:i2c_modal_open, false) |> assign(:i2c_modal_module, nil)}
end

def handle_event("delete_i2c_module", %{"id" => id_str}, socket) do
  case Hardware.get_i2c_module(String.to_integer(id_str)) do
    {:ok, mod} ->
      {:ok, _} = Hardware.delete_i2c_module(mod)
      i2c_modules = Hardware.list_i2c_modules(socket.assigns.device.id)
      {:noreply, assign(socket, :i2c_modules, i2c_modules)}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Module not found")}
  end
end
```

Add info handler for save:

```elixir
def handle_info(:i2c_module_saved, socket) do
  i2c_modules = Hardware.list_i2c_modules(socket.assigns.device.id)

  {:noreply,
   socket
   |> assign(:i2c_modules, i2c_modules)
   |> assign(:i2c_modal_open, false)
   |> assign(:i2c_modal_module, nil)}
end
```

In the template (the `render/1` or `.heex` inline), add an i2c modules section after the outputs section. Place it where it logically fits with the existing outputs table:

```heex
<%!-- I2C Modules section --%>
<div class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <div class="flex items-center justify-between mb-4">
      <h3 class="card-title text-base">I2C Modules</h3>
      <button
        type="button"
        phx-click="open_add_i2c_modal"
        class="btn btn-sm btn-outline"
        disabled={@new_mode}
      >
        <.icon name="hero-plus" class="w-4 h-4" /> Add Module
      </button>
    </div>

    <div :if={Enum.empty?(@i2c_modules)} class="text-sm text-base-content/50 py-4 text-center">
      No I2C modules configured
    </div>

    <div :if={not Enum.empty?(@i2c_modules)} class="overflow-x-auto">
      <table class="table table-sm">
        <thead>
          <tr>
            <th>Name</th><th>Chip</th><th>Address</th><th>Digits</th><th>Brightness</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={mod <- @i2c_modules} class="hover:bg-base-200/50">
            <td>{mod.name || "—"}</td>
            <td class="uppercase text-xs">{mod.module_chip}</td>
            <td class="font-mono">{Trenino.Hardware.I2cModule.format_i2c_address(mod.i2c_address)}</td>
            <td>{mod.num_digits}</td>
            <td>{mod.brightness}</td>
            <td class="text-right">
              <button phx-click="open_edit_i2c_modal" phx-value-id={mod.id} class="btn btn-ghost btn-xs">
                <.icon name="hero-pencil" class="w-3.5 h-3.5" />
              </button>
              <button phx-click="delete_i2c_module" phx-value-id={mod.id}
                      data-confirm="Delete this I2C module?" class="btn btn-ghost btn-xs text-error">
                <.icon name="hero-trash" class="w-3.5 h-3.5" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<%!-- I2C module modal --%>
<div :if={@i2c_modal_open} class="modal modal-open">
  <div class="modal-box">
    <h3 class="font-bold text-lg mb-4">
      {if @i2c_modal_module, do: "Edit I2C Module", else: "Add I2C Module"}
    </h3>
    <.live_component
      module={TreninoWeb.I2cModuleFormComponent}
      id="i2c-module-form"
      module={@i2c_modal_module}
      device_id={@device.id}
    />
  </div>
  <div class="modal-backdrop" phx-click="close_i2c_modal" />
</div>
```

Add `alias Trenino.Hardware.I2cModule` to the module if not already present.

- [ ] **Verify UI manually** — navigate to a device config page and confirm the I2C modules section appears, add/edit/delete work, hex and decimal addresses both parse.

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino_web/live/components/i2c_module_form_component.ex \
        lib/trenino_web/live/configuration_edit_live.ex
git commit -m "feat: add I2C modules section to device configuration UI"
```

---

## Task 13: UI — DisplayBindingWizard + train_edit_live.ex

**Files:**
- Create: `lib/trenino_web/live/components/display_binding_wizard.ex`
- Modify: `lib/trenino_web/live/train_edit_live.ex`
- Modify: `lib/trenino_web/live/components/output_binding_wizard.ex`

- [ ] **Create DisplayBindingWizard**

```elixir
# lib/trenino_web/live/components/display_binding_wizard.ex
defmodule TreninoWeb.DisplayBindingWizard do
  @moduledoc """
  Wizard for creating/editing a display binding.

  Steps:
  1. :select_endpoint  — pick simulator endpoint via ApiExplorerComponent
  2. :select_module    — pick i2c module from list
  3. :configure        — set format_string and name, preview, save
  """

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Train
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayController
  alias Trenino.Train.DisplayFormatter

  @impl true
  def update(%{train_id: train_id} = assigns, socket) do
    socket =
      socket
      |> assign(:train_id, train_id)
      |> assign(:client, assigns.client)
      |> assign(:binding, Map.get(assigns, :binding))

    socket =
      if socket.assigns[:initialized] do
        socket
      else
        i2c_modules = Hardware.list_all_i2c_modules()
        socket
        |> assign(:i2c_modules, i2c_modules)
        |> initialize_wizard(assigns[:binding])
      end

    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, handle_explorer_event(assigns, socket)}
  end

  defp handle_explorer_event(%{explorer_event: {:select, _field, path}}, socket) do
    socket |> assign(:endpoint, path) |> assign(:wizard_step, :select_module)
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), :display_binding_cancelled)
    socket
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, nil) do
    socket
    |> assign(:wizard_step, :select_endpoint)
    |> assign(:endpoint, nil)
    |> assign(:selected_module_id, nil)
    |> assign(:format_string, "{value}")
    |> assign(:name, "")
    |> assign(:initialized, true)
  end

  defp initialize_wizard(socket, %DisplayBinding{} = binding) do
    socket
    |> assign(:wizard_step, :configure)
    |> assign(:endpoint, binding.endpoint)
    |> assign(:selected_module_id, binding.i2c_module_id)
    |> assign(:format_string, binding.format_string)
    |> assign(:name, binding.name || "")
    |> assign(:initialized, true)
  end

  @impl true
  def handle_event("select_module", %{"module-id" => id_str}, socket) do
    {:noreply,
     socket
     |> assign(:selected_module_id, String.to_integer(id_str))
     |> assign(:wizard_step, :configure)}
  end

  def handle_event("update_config", params, socket) do
    socket =
      socket
      |> maybe_assign(:format_string, params, "format_string")
      |> maybe_assign(:name, params, "name")

    {:noreply, socket}
  end

  def handle_event("back", _params, socket) do
    prev =
      case socket.assigns.wizard_step do
        :select_module -> :select_endpoint
        :configure -> :select_module
        _ -> :select_endpoint
      end

    {:noreply, assign(socket, :wizard_step, prev)}
  end

  def handle_event("save", _params, socket) do
    case save_binding(socket) do
      {:ok, binding} ->
        DisplayController.reload_bindings()
        send(self(), {:display_binding_saved, binding})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :display_binding_cancelled)
    {:noreply, socket}
  end

  defp maybe_assign(socket, key, params, param_key) do
    case Map.get(params, param_key) do
      nil -> socket
      val -> assign(socket, key, val)
    end
  end

  defp save_binding(socket) do
    %{
      train_id: train_id,
      binding: existing,
      endpoint: endpoint,
      selected_module_id: i2c_module_id,
      format_string: format_string,
      name: name
    } = socket.assigns

    params = %{
      i2c_module_id: i2c_module_id,
      endpoint: endpoint,
      format_string: format_string,
      name: name
    }

    case existing do
      nil -> Train.create_display_binding(train_id, params)
      b -> Train.update_display_binding(b, params)
    end
  end

  defp selected_module(assigns) do
    Enum.find(assigns.i2c_modules, &(&1.id == assigns.selected_module_id))
  end

  defp format_preview(format_string, sample_value \\ 42.5) do
    DisplayFormatter.format(format_string, sample_value)
  end

  defp can_save?(assigns) do
    assigns.endpoint != nil and
      assigns.selected_module_id != nil and
      assigns.format_string != "" and
      assigns.name != ""
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {f, msgs} -> "#{f}: #{Enum.join(msgs, ", ")}" end)
  end

  defp format_errors(_), do: "An error occurred"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected_module, selected_module(assigns))

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">
                {if @binding, do: "Edit Display Binding", else: "Add Display Binding"}
              </h2>
              <p class="text-sm text-base-content/60">Show a simulator value on an I2C display</p>
            </div>
            <button phx-click="cancel" phx-target={@myself} class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <div class="flex items-center gap-2 mt-4">
            <.step_indicator step={1} label="Endpoint" active={@wizard_step == :select_endpoint}
              completed={@wizard_step in [:select_module, :configure]} />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator step={2} label="Display" active={@wizard_step == :select_module}
              completed={@wizard_step == :configure} />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator step={3} label="Format" active={@wizard_step == :configure} />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :select_endpoint} class="flex-1 flex flex-col">
            <.live_component module={TreninoWeb.ApiExplorerComponent} id="display-wizard-api-explorer"
              field={:endpoint} client={@client} mode={:none} embedded={true} />
          </div>

          <div :if={@wizard_step == :select_module} class="flex-1 p-6 overflow-y-auto space-y-4">
            <h3 class="text-xl font-semibold">Select Display</h3>
            <div :if={Enum.empty?(@i2c_modules)} class="alert alert-warning">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
              <span>No I2C modules configured. Add one to a device configuration first.</span>
            </div>
            <div :if={not Enum.empty?(@i2c_modules)} class="space-y-2">
              <button
                :for={mod <- @i2c_modules}
                type="button"
                phx-click="select_module"
                phx-value-module-id={mod.id}
                phx-target={@myself}
                class={[
                  "w-full p-4 rounded-lg border-2 text-left transition-all",
                  @selected_module_id == mod.id && "border-primary bg-primary/10",
                  @selected_module_id != mod.id && "border-base-300 hover:border-primary/50"
                ]}
              >
                <p class="font-medium">{mod.name || "Module at #{Trenino.Hardware.I2cModule.format_i2c_address(mod.i2c_address)}"}</p>
                <p class="text-xs text-base-content/60">
                  {mod.device.name} · {mod.module_chip} · {mod.num_digits} digits · addr {Trenino.Hardware.I2cModule.format_i2c_address(mod.i2c_address)}
                </p>
              </button>
            </div>
            <div class="flex justify-between pt-4 border-t border-base-300">
              <button phx-click="back" phx-target={@myself} class="btn btn-ghost">
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
              </button>
            </div>
          </div>

          <div :if={@wizard_step == :configure} class="flex-1 p-6 overflow-y-auto space-y-6">
            <div class="bg-base-200 rounded-lg p-4 space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-base-content/60">Endpoint:</span>
                <span class="font-mono">{@endpoint}</span>
              </div>
              <div :if={@selected_module} class="flex justify-between">
                <span class="text-base-content/60">Display:</span>
                <span>{@selected_module.name} ({@selected_module.device.name})</span>
              </div>
            </div>

            <form phx-change="update_config" phx-target={@myself} class="space-y-4">
              <div>
                <label class="label"><span class="label-text font-medium">Binding Name</span></label>
                <input type="text" name="name" value={@name}
                  placeholder="e.g. Train speed" class="input input-bordered w-full" />
              </div>
              <div>
                <label class="label">
                  <span class="label-text font-medium">Format String</span>
                  <span class="label-text-alt text-base-content/50">
                    {"{value}"} = raw · {"{value:.0f}"} = no decimals · {"{value:.2f}"} = 2 decimals
                  </span>
                </label>
                <input type="text" name="format_string" value={@format_string}
                  placeholder="{value:.0f}" class="input input-bordered w-full font-mono" />
              </div>
            </form>

            <div class="bg-base-200 rounded-lg p-4">
              <p class="text-xs text-base-content/50 mb-2">Preview (sample value: 42.5)</p>
              <div class="font-mono text-2xl tracking-widest bg-base-300 rounded px-4 py-3 inline-block min-w-[8ch] text-center">
                {format_preview(@format_string)}
              </div>
            </div>

            <div class="flex justify-between pt-4 border-t border-base-300">
              <button phx-click="back" phx-target={@myself} class="btn btn-ghost">
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
              </button>
              <button phx-click="save" phx-target={@myself}
                disabled={not can_save?(assigns)} class="btn btn-primary">
                <.icon name="hero-check" class="w-4 h-4" /> Save
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :completed, :boolean, default: false

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class={[
        "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
        @active && "bg-primary text-primary-content",
        @completed && "bg-success text-success-content",
        (not @active and not @completed) && "bg-base-300 text-base-content/50"
      ]}>
        <.icon :if={@completed} name="hero-check" class="w-4 h-4" />
        <span :if={not @completed}>{@step}</span>
      </div>
      <span class={["text-sm", @active && "font-medium", (not @active and not @completed) && "text-base-content/50"]}>
        {@label}
      </span>
    </div>
    """
  end
end
```

- [ ] **Update train_edit_live.ex — add display bindings section**

In the initial assigns (both `mount` paths), add:

```elixir
|> assign(:display_bindings, [])
|> assign(:show_display_wizard, false)
|> assign(:display_wizard_binding, nil)
```

In the train-loaded path, load display bindings:

```elixir
display_bindings = TrainContext.list_display_bindings(train.id)
# add:
|> assign(:display_bindings, display_bindings)
```

Add event handlers (after the output binding handlers):

```elixir
def handle_event("open_add_display_binding", _params, socket) do
  case get_simulator_client() do
    nil ->
      {:noreply, put_flash(socket, :error, "Connect to the simulator to add display bindings")}

    _client ->
      {:noreply, socket |> assign(:show_display_wizard, true) |> assign(:display_wizard_binding, nil)}
  end
end

def handle_event("configure_display_binding", %{"id" => id_str}, socket) do
  case TrainContext.get_display_binding(String.to_integer(id_str)) do
    {:ok, binding} ->
      {:noreply, socket |> assign(:show_display_wizard, true) |> assign(:display_wizard_binding, binding)}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Display binding not found")}
  end
end

def handle_event("delete_display_binding", %{"id" => id_str}, socket) do
  case TrainContext.get_display_binding(String.to_integer(id_str)) do
    {:ok, binding} ->
      {:ok, _} = TrainContext.delete_display_binding(binding)
      DisplayController.reload_bindings()
      display_bindings = TrainContext.list_display_bindings(socket.assigns.train.id)
      {:noreply, assign(socket, :display_bindings, display_bindings)}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Display binding not found")}
  end
end
```

Add info handlers:

```elixir
def handle_info({:display_binding_saved, _binding}, socket) do
  display_bindings = TrainContext.list_display_bindings(socket.assigns.train.id)

  {:noreply,
   socket
   |> assign(:display_bindings, display_bindings)
   |> assign(:show_display_wizard, false)
   |> assign(:display_wizard_binding, nil)}
end

def handle_info(:display_binding_cancelled, socket) do
  {:noreply, socket |> assign(:show_display_wizard, false) |> assign(:display_wizard_binding, nil)}
end
```

Add `alias Trenino.Train.DisplayController` to the module.

In the template, add a display bindings section after the output bindings section. Follow the same card/table pattern as the existing output bindings section:

```heex
<.display_bindings_section
  display_bindings={@display_bindings}
  simulator_connected={not is_nil(@simulator_client)}
/>

<.live_component
  :if={@show_display_wizard}
  module={TreninoWeb.DisplayBindingWizard}
  id="display-wizard"
  train_id={@train.id}
  client={@simulator_client}
  binding={@display_wizard_binding}
  explorer_event={@display_wizard_event}
/>
```

Add the function component:

```elixir
attr :display_bindings, :list, required: true
attr :simulator_connected, :boolean, required: true

defp display_bindings_section(assigns) do
  ~H"""
  <div class="card bg-base-100 border border-base-300">
    <div class="card-body">
      <div class="flex items-center justify-between mb-4">
        <h3 class="card-title text-base">Display Bindings</h3>
        <button type="button" phx-click="open_add_display_binding" class="btn btn-sm btn-outline">
          <.icon name="hero-plus" class="w-4 h-4" /> Add Display Binding
        </button>
      </div>

      <div :if={Enum.empty?(@display_bindings)} class="text-sm text-base-content/50 py-4 text-center">
        No display bindings configured
      </div>

      <div :if={not Enum.empty?(@display_bindings)} class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr><th>Name</th><th>Endpoint</th><th>Display</th><th>Format</th><th>Enabled</th><th></th></tr>
          </thead>
          <tbody>
            <tr :for={b <- @display_bindings} class="hover:bg-base-200/50">
              <td>{b.name || "—"}</td>
              <td class="font-mono text-xs">{b.endpoint}</td>
              <td class="text-xs">{b.i2c_module.name} ({b.i2c_module.device.name})</td>
              <td class="font-mono text-xs">{b.format_string}</td>
              <td><input type="checkbox" class="checkbox checkbox-sm" checked={b.enabled} disabled /></td>
              <td class="text-right">
                <button phx-click="configure_display_binding" phx-value-id={b.id} class="btn btn-ghost btn-xs">
                  <.icon name="hero-pencil" class="w-3.5 h-3.5" />
                </button>
                <button phx-click="delete_display_binding" phx-value-id={b.id}
                        data-confirm="Delete this display binding?" class="btn btn-ghost btn-xs text-error">
                  <.icon name="hero-trash" class="w-3.5 h-3.5" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
  """
end
```

- [ ] **Update OutputBindingWizard — remove "coming soon" note**

In `lib/trenino_web/live/components/output_binding_wizard.ex`, find the line:

```elixir
<div class="text-center text-sm text-base-content/50 mt-4">
  More output types (servo, display, etc.) coming soon
</div>
```

Remove it entirely.

- [ ] **Verify UI manually** — open a train edit page, add a display binding, confirm the 3-step wizard works, confirm format preview updates live.

- [ ] **Run precommit**

```bash
mix precommit
```

- [ ] **Commit**

```bash
git add lib/trenino_web/live/components/display_binding_wizard.ex \
        lib/trenino_web/live/train_edit_live.ex \
        lib/trenino_web/live/components/output_binding_wizard.ex
git commit -m "feat: add display bindings UI to train edit page"
```

---

## Self-Review Checklist

- [x] **Protocol messages** (WriteSegments, SetModuleBrightness, ModuleError) — Task 1
- [x] **Configure HT16K33 encode** — Task 2
- [x] **I2cModule schema + migration** — Task 3
- [x] **Hardware context CRUD + write_segments** — Task 4
- [x] **ConfigurationManager includes i2c modules + handles ModuleError** — Task 5
- [x] **HT16K33.encode_string/2 with font table** — Task 6
- [x] **DisplayBinding schema + migration + Train context CRUD** — Task 7
- [x] **DisplayFormatter.format/2** — Task 8
- [x] **DisplayController GenServer** — Task 9
- [x] **Lua display.set()** — Task 10
- [x] **MCP tools: i2c modules + display bindings + registry + counts** — Task 11
- [x] **UI: I2cModuleFormComponent + configuration_edit_live.ex** — Task 12
- [x] **UI: DisplayBindingWizard + train_edit_live.ex + wizard cleanup** — Task 13
- [x] **Hex i2c address input** — covered by `I2cModule.parse_i2c_address/1` in Task 3, used in `I2cModuleFormComponent` in Task 12 and in MCP tools in Task 11
- [x] **format_i2c_address display** — `I2cModule.format_i2c_address/1` used in UI table and serializer

**One gap found and fixed:** The `display_wizard_event` assign referenced in the `train_edit_live.ex` template needs to be initialized. Add `|> assign(:display_wizard_event, nil)` to the initial assigns in `train_edit_live.ex` (alongside `show_display_wizard` in the mount paths).
