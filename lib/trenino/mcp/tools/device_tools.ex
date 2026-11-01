defmodule Trenino.MCP.Tools.DeviceTools do
  @moduledoc """
  MCP tools for listing connected hardware devices, inputs, outputs, and I2C modules.
  """

  alias Trenino.Hardware
  alias Trenino.Hardware.ADS1115.Params, as: ADS1115Params
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.InputLabel
  alias Trenino.Hardware.MCP23017.Params, as: MCP23017Params
  alias Trenino.Repo

  # Chip params accepted by create/update_i2c_module, per chip. display_type and
  # has_dot are HT16K33 keys because PolymorphicEmbed identifies the embed type by
  # them. Virtual pin bases are never accepted: the host allocates them.
  @i2c_param_keys %{
    "ht16k33" => ~w(brightness num_digits display_type has_dot align_right min_value orientation),
    "mcp23017" => ~w(direct_mask row_mask col_mask debounce),
    "ads1115" => ~w(channel_mask gain ref_channel)
  }

  defp i2c_param_overrides(chip, args) do
    keys = Map.get(@i2c_param_keys, to_string(chip), [])

    args
    |> Map.take(keys)
    |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp channels_attr(args) do
    case Map.fetch(args, "channels") do
      {:ok, channels} -> %{channels: channels}
      :error -> %{}
    end
  end

  def tools do
    [
      %{
        name: "list_devices",
        description:
          "List all connected hardware devices. Returns id, name, and connection status for each device.",
        input_schema: %{
          type: "object",
          properties: %{}
        }
      },
      %{
        name: "list_device_inputs",
        description:
          "List all inputs (buttons and analog sensors) for a specific device. " <>
            "Use this to find input IDs when creating button bindings. " <>
            "Includes inputs of I2C input chips (MCP23017, ADS1115), with a label such as 'MCP 0x20 GPA3'.",
        input_schema: %{
          type: "object",
          properties: %{
            device_id: %{type: "integer", description: "Device ID from list_devices"}
          },
          required: ["device_id"]
        }
      },
      %{
        name: "list_hardware_outputs",
        description:
          "List all available hardware outputs (LEDs, relays) across all devices. " <>
            "Use this to find output IDs when creating output bindings.",
        input_schema: %{
          type: "object",
          properties: %{}
        }
      },
      %{
        name: "list_i2c_modules",
        description:
          "List all I2C modules configured on any device, with chip params and, for input chips, their inputs (pin, label, channel). Use this to find i2c_module_id when creating display bindings.",
        input_schema: %{type: "object", properties: %{}}
      },
      %{
        name: "create_i2c_module",
        description:
          "Add an I2C module to a device. i2c_address accepts decimal (112) or hex (0x70). " <>
            "module_chip is 'ht16k33' (display, 0x70-0x77), 'mcp23017' (digital inputs, 0x20-0x27) or 'ads1115' (analog inputs, 0x48-0x4B). " <>
            "ht16k33: brightness 0-15, num_digits 4 or 8, orientation ('normal', 'rotated_180', 'flipped_horizontal', 'flipped_vertical'). " <>
            "mcp23017: direct_mask, row_mask and col_mask are integer bitmasks, bit 0-7 = GPA0-7 and bit 8-15 = GPB0-7. " <>
            "GPA7 and GPB7 (bits 7 and 15) are output-only: they may be matrix rows, never direct inputs or columns. " <>
            "A matrix needs both row_mask and col_mask (up to 8 each), and every switch needs a diode. debounce is in samples (optional). " <>
            "ads1115: channel_mask bits 0-3 enable AIN0-3, gain 0 (+-4.096 V) or 1 (+-2.048 V), ref_channel (0-3, optional) is a channel wired to the sensor supply and must not be in channel_mask. " <>
            "Input chips create one input per channel; use list_device_inputs to find them. " <>
            "channels optionally names them: an object keyed by channel number with name and sensitivity (analog only), e.g. {\"0\": {\"name\": \"Throttle\", \"sensitivity\": 7}}.",
        input_schema: %{
          type: "object",
          properties: %{
            device_id: %{type: "integer", description: "Device ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Speed display'"},
            module_chip: %{type: "string", enum: ["ht16k33", "mcp23017", "ads1115"]},
            i2c_address: %{
              type: "string",
              description: "I2C address: decimal '112' or hex '0x70'"
            },
            brightness: %{type: "integer", description: "ht16k33: 0-15"},
            num_digits: %{type: "integer", enum: [4, 8], description: "ht16k33"},
            orientation: %{
              type: "string",
              enum: ["normal", "rotated_180", "flipped_horizontal", "flipped_vertical"],
              description: "ht16k33: display orientation for physically rotated/mirrored mounts"
            },
            direct_mask: %{
              type: "integer",
              description: "mcp23017: pins read as buttons (bitmask)"
            },
            row_mask: %{type: "integer", description: "mcp23017: matrix row pins (bitmask)"},
            col_mask: %{type: "integer", description: "mcp23017: matrix column pins (bitmask)"},
            debounce: %{type: "integer", description: "mcp23017: debounce in samples"},
            channel_mask: %{type: "integer", description: "ads1115: enabled channels, bits 0-3"},
            gain: %{type: "integer", enum: [0, 1], description: "ads1115"},
            ref_channel: %{
              type: "integer",
              description: "ads1115: supply reference channel 0-3 (optional)"
            },
            channels: channels_schema()
          },
          required: ["device_id", "module_chip", "i2c_address"]
        }
      },
      %{
        name: "update_i2c_module",
        description:
          "Update an I2C module's name and chip params (same params as create_i2c_module, chip and address cannot change). " <>
            "For input chips, inputs of channels that stay keep their calibration and bindings; removing a channel deletes its input and bindings. " <>
            "channels renames inputs and sets sensitivity.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer"},
            name: %{type: "string"},
            brightness: %{type: "integer", description: "ht16k33: 0-15"},
            num_digits: %{type: "integer", enum: [4, 8], description: "ht16k33"},
            orientation: %{
              type: "string",
              enum: ["normal", "rotated_180", "flipped_horizontal", "flipped_vertical"],
              description: "ht16k33: display orientation for physically rotated/mirrored mounts"
            },
            direct_mask: %{type: "integer", description: "mcp23017 bitmask"},
            row_mask: %{type: "integer", description: "mcp23017 bitmask"},
            col_mask: %{type: "integer", description: "mcp23017 bitmask"},
            debounce: %{type: "integer", description: "mcp23017: samples"},
            channel_mask: %{type: "integer", description: "ads1115: bits 0-3"},
            gain: %{type: "integer", enum: [0, 1], description: "ads1115"},
            ref_channel: %{
              type: ["integer", "null"],
              description: "ads1115: 0-3, or null for none"
            },
            channels: channels_schema()
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_i2c_module",
        description:
          "Delete an I2C module from a device. For input chips this also deletes its child inputs with their calibrations and bindings.",
        input_schema: %{
          type: "object",
          properties: %{id: %{type: "integer"}},
          required: ["id"]
        }
      }
    ]
  end

  defp channels_schema do
    %{
      type: "object",
      description:
        "Input chips: per-channel settings keyed by channel number, e.g. {\"0\": {\"name\": \"Throttle\", \"sensitivity\": 7}}",
      additionalProperties: %{
        type: "object",
        properties: %{name: %{type: "string"}, sensitivity: %{type: "integer"}}
      }
    }
  end

  def execute("list_devices", _args) do
    devices = Hardware.list_configurations()

    {:ok,
     %{
       devices:
         Enum.map(devices, fn d ->
           %{id: d.id, name: d.name}
         end)
     }}
  end

  def execute("list_device_inputs", %{"device_id" => device_id}) do
    {:ok, inputs} = Hardware.list_inputs(device_id, include_chip_inputs: true)

    {:ok,
     %{
       inputs:
         Enum.map(inputs, fn i ->
           %{
             id: i.id,
             name: i.name,
             pin: i.pin,
             label: InputLabel.pin(i),
             input_type: i.input_type
           }
         end)
     }}
  end

  def execute("list_hardware_outputs", _args) do
    devices = Hardware.list_configurations(preload: [:outputs])

    outputs =
      Enum.flat_map(devices, fn device ->
        Enum.map(device.outputs, fn output ->
          %{
            id: output.id,
            name: output.name,
            pin: output.pin,
            device_name: device.name,
            device_id: device.id
          }
        end)
      end)

    {:ok, %{outputs: outputs}}
  end

  def execute("list_i2c_modules", _args) do
    modules = Hardware.list_all_i2c_modules()
    {:ok, %{i2c_modules: Enum.map(modules, &serialize_i2c_module/1)}}
  end

  def execute("create_i2c_module", %{"device_id" => device_id} = args) do
    case parse_i2c_address(Map.get(args, "i2c_address", "")) do
      {:ok, addr} ->
        attrs =
          args
          |> Map.take(["name", "module_chip"])
          |> Enum.reduce(%{i2c_address: addr}, fn {k, v}, acc ->
            Map.put(acc, String.to_existing_atom(k), v)
          end)
          |> Map.merge(channels_attr(args))
          |> Map.put(:params, create_params(args))

        case Hardware.create_i2c_module(device_id, attrs) do
          {:ok, mod} -> {:ok, %{i2c_module: serialize_i2c_module(Repo.preload(mod, :device))}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      :error ->
        {:error, "Invalid i2c_address: use decimal (112) or hex (0x70)"}
    end
  end

  def execute("update_i2c_module", %{"id" => id} = args) do
    case Hardware.get_i2c_module(id) do
      {:ok, mod} ->
        attrs =
          args
          |> Map.take(["name"])
          |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v) end)

        attrs = Map.merge(attrs, channels_attr(args))
        overrides = i2c_param_overrides(mod.module_chip, args)

        attrs =
          if map_size(overrides) > 0 do
            Map.put(attrs, :params, Map.merge(Map.from_struct(mod.params), overrides))
          else
            attrs
          end

        case Hardware.update_i2c_module(mod, attrs) do
          {:ok, updated} ->
            {:ok, %{i2c_module: serialize_i2c_module(Repo.preload(updated, :device))}}

          {:error, changeset} ->
            {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "I2C module not found with id #{id}"}
    end
  end

  def execute("delete_i2c_module", %{"id" => id}) do
    case Hardware.get_i2c_module(id) do
      {:ok, mod} ->
        case Hardware.delete_i2c_module(mod) do
          {:ok, _} -> {:ok, %{deleted: true, id: id}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "I2C module not found with id #{id}"}
    end
  end

  defp parse_i2c_address(str), do: I2cModule.parse_i2c_address(str)

  defp create_params(%{"module_chip" => "ht16k33"} = args),
    do: Map.merge(Map.from_struct(%HT16K33Params{}), i2c_param_overrides("ht16k33", args))

  defp create_params(args), do: i2c_param_overrides(Map.get(args, "module_chip"), args)

  defp serialize_i2c_module(%I2cModule{} = mod) do
    base = %{
      id: mod.id,
      device_id: mod.device_id,
      device_name: mod.device.name,
      name: mod.name,
      module_chip: mod.module_chip,
      i2c_address: mod.i2c_address,
      i2c_address_display: I2cModule.format_i2c_address(mod.i2c_address)
    }

    Map.merge(base, serialize_params(mod))
  end

  defp serialize_params(%I2cModule{params: %HT16K33Params{} = p}) do
    %{
      brightness: p.brightness,
      num_digits: p.num_digits,
      display_type: p.display_type,
      has_dot: p.has_dot,
      align_right: p.align_right,
      min_value: p.min_value,
      orientation: p.orientation
    }
  end

  defp serialize_params(%I2cModule{params: %MCP23017Params{} = p} = mod) do
    %{
      direct_mask: p.direct_mask,
      row_mask: p.row_mask,
      col_mask: p.col_mask,
      debounce: p.debounce,
      inputs: serialize_chip_inputs(mod)
    }
  end

  defp serialize_params(%I2cModule{params: %ADS1115Params{} = p} = mod) do
    %{
      channel_mask: p.channel_mask,
      gain: p.gain,
      ref_channel: p.ref_channel,
      inputs: serialize_chip_inputs(mod)
    }
  end

  defp serialize_params(%I2cModule{}), do: %{}

  defp serialize_chip_inputs(%I2cModule{} = mod) do
    mod
    |> Hardware.list_i2c_module_inputs()
    |> Enum.map(fn input ->
      %{
        id: input.id,
        name: input.name,
        pin: input.pin,
        i2c_channel: input.i2c_channel,
        input_type: input.input_type,
        sensitivity: input.sensitivity,
        label: InputLabel.pin(%{input | i2c_module: mod})
      }
    end)
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    "Validation failed: " <>
      Enum.map_join(collect_errors(changeset, []), "; ", fn {path, message} ->
        "#{Enum.join(path, ".")} #{message}"
      end)
  end

  # Polymorphic embeds keep their changeset in changes, which traverse_errors
  # does not descend into, so walk it here and name fields as params.field.
  defp collect_errors(%Ecto.Changeset{} = changeset, path) do
    own =
      Enum.map(changeset.errors, fn {field, {msg, opts}} ->
        {path ++ [field], interpolate(msg, opts)}
      end)

    nested =
      for {field, %Ecto.Changeset{} = child} <- changeset.changes,
          error <- collect_errors(child, path ++ [field]),
          do: error

    own ++ nested
  end

  defp interpolate(msg, opts) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
