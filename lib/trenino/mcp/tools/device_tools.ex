defmodule Trenino.MCP.Tools.DeviceTools do
  @moduledoc """
  MCP tools for listing connected hardware devices, inputs, outputs, and I2C modules.
  """

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Repo

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
            "Use this to find input IDs when creating button bindings.",
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
          "List all I2C modules configured on any device. Use this to find i2c_module_id when creating display bindings.",
        input_schema: %{type: "object", properties: %{}}
      },
      %{
        name: "create_i2c_module",
        description:
          "Add an I2C module to a device. i2c_address accepts decimal (112) or hex (0x70). module_chip must be 'ht16k33'. brightness 0–15. num_digits 4 or 8.",
        input_schema: %{
          type: "object",
          properties: %{
            device_id: %{type: "integer", description: "Device ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Speed display'"},
            module_chip: %{type: "string", enum: ["ht16k33"]},
            i2c_address: %{
              type: "string",
              description: "I2C address: decimal '112' or hex '0x70'"
            },
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
    ]
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
    {:ok, inputs} = Hardware.list_inputs(device_id)

    {:ok,
     %{
       inputs:
         Enum.map(inputs, fn i ->
           %{
             id: i.id,
             name: i.name,
             pin: i.pin,
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
          |> Map.take(["name", "module_chip", "brightness", "num_digits"])
          |> Enum.reduce(%{i2c_address: addr}, fn {k, v}, acc ->
            Map.put(acc, String.to_existing_atom(k), v)
          end)

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
          Map.take(args, ["name", "brightness", "num_digits"])
          |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v) end)

        case Hardware.update_i2c_module(mod, attrs) do
          {:ok, updated} ->
            {:ok, %{i2c_module: serialize_i2c_module(updated)}}

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

  defp serialize_i2c_module(%I2cModule{} = mod) do
    %{
      id: mod.id,
      device_id: mod.device_id,
      device_name: mod.device.name,
      name: mod.name,
      module_chip: mod.module_chip,
      i2c_address: mod.i2c_address,
      i2c_address_display: I2cModule.format_i2c_address(mod.i2c_address),
      brightness: mod.brightness,
      num_digits: mod.num_digits
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
