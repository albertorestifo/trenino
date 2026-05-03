defmodule TreninoWeb.I2cModuleFormComponent do
  @moduledoc "Form for creating or editing an I2C module on a device."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params

  @impl true
  def update(%{i2c_module: mod, device_id: device_id} = _assigns, socket) do
    changeset = I2cModule.changeset(mod || %I2cModule{}, %{})
    params = (mod && mod.params) || %HT16K33Params{}
    brightness_pct = round((params.brightness || 8) * 100 / 15)

    {:ok,
     socket
     |> assign(:i2c_module, mod)
     |> assign(:device_id, device_id)
     |> assign(:form, to_form(changeset))
     |> assign(:brightness_pct, brightness_pct)
     |> assign(
       :i2c_address_input,
       if(mod && mod.i2c_address, do: to_string(mod.i2c_address), else: "")
     )}
  end

  @impl true
  def handle_event("validate", %{"i2c_module" => params}, socket) do
    pct =
      case Integer.parse(Map.get(params, "brightness_pct", "53")) do
        {n, ""} -> n
        _ -> 53
      end

    changeset =
      (socket.assigns.i2c_module || %I2cModule{})
      |> I2cModule.changeset(coerce_params(params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:brightness_pct, pct)
     |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))}
  end

  def handle_event("save", %{"i2c_module" => params}, socket) do
    coerced = coerce_params(params)

    result =
      case socket.assigns.i2c_module do
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

  defp coerce_params(raw) do
    addr =
      case I2cModule.parse_i2c_address(Map.get(raw, "i2c_address_raw", "")) do
        {:ok, n} -> n
        :error -> nil
      end

    pct = parse_pct(Map.get(raw, "brightness_pct"))
    brightness = round(pct * 15 / 100)

    min_value =
      case Float.parse(Map.get(raw, "min_value", "0")) do
        {f, _} -> f
        :error -> 0.0
      end

    %{
      name: Map.get(raw, "name"),
      module_chip: Map.get(raw, "module_chip"),
      i2c_address: addr,
      params: %{
        brightness: brightness,
        num_digits: Map.get(raw, "num_digits"),
        display_type: Map.get(raw, "display_type"),
        has_dot: Map.get(raw, "has_dot") == "true",
        align_right: Map.get(raw, "align_right") == "true",
        min_value: min_value
      }
    }
  end

  defp parse_pct(val) do
    case Integer.parse(val || "53") do
      {n, ""} -> n
      _ -> 53
    end
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
                HT16K33
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
            <p
              :for={msg <- @form[:i2c_address].errors |> Enum.map(&elem(&1, 0))}
              class="mt-1 text-sm text-error"
            >
              {msg}
            </p>
          </div>
          <div>
            <label class="label"><span class="label-text font-medium">Display Type</span></label>
            <select name="i2c_module[display_type]" class="select select-bordered w-full">
              <option
                value="fourteen_segment"
                selected={current_display_type(@form) != "seven_segment"}
              >
                14-segment (alphanumeric)
              </option>
              <option
                value="seven_segment"
                selected={current_display_type(@form) == "seven_segment"}
              >
                7-segment
              </option>
            </select>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="label">
                <span class="label-text font-medium">Brightness</span>
                <span class="label-text-alt text-base-content/50">{@brightness_pct}%</span>
              </label>
              <input
                type="range"
                name="i2c_module[brightness_pct]"
                value={@brightness_pct}
                min="0"
                max="100"
                class="range range-sm w-full"
              />
            </div>
            <div>
              <label class="label"><span class="label-text font-medium">Digits</span></label>
              <select name="i2c_module[num_digits]" class="select select-bordered w-full">
                <option value="4" selected={current_num_digits(@form) == 4}>4 digits</option>
                <option value="8" selected={current_num_digits(@form) == 8}>8 digits</option>
              </select>
            </div>
          </div>
          <div>
            <label class="label">
              <span class="label-text font-medium">Minimum value</span>
              <span class="label-text-alt text-base-content/50">Clamp negative values (e.g. 0)</span>
            </label>
            <input
              type="text"
              name="i2c_module[min_value]"
              value={current_min_value(@form)}
              placeholder="0"
              class="input input-bordered w-full"
            />
          </div>
          <div class="flex flex-col gap-2">
            <label class="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                name="i2c_module[align_right]"
                value="true"
                checked={current_align_right(@form)}
                class="checkbox"
              />
              <span class="label-text font-medium">Right-align value</span>
            </label>
            <label class="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                name="i2c_module[has_dot]"
                value="true"
                checked={current_has_dot(@form)}
                class="checkbox"
              />
              <span class="label-text font-medium">Has decimal point (dot)</span>
            </label>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" phx-click="close_i2c_modal" class="btn btn-ghost">Cancel</button>
          <button type="submit" class="btn btn-primary">
            {if @i2c_module, do: "Save", else: "Add"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp current_params(%{data: %{params: %HT16K33Params{} = p}}), do: p
  defp current_params(_form), do: %HT16K33Params{}

  defp current_display_type(form) do
    form |> current_params() |> Map.get(:display_type) |> to_string()
  end

  defp current_num_digits(form) do
    form |> current_params() |> Map.get(:num_digits)
  end

  defp current_min_value(form) do
    form |> current_params() |> Map.get(:min_value, 0.0)
  end

  defp current_align_right(form) do
    form |> current_params() |> Map.get(:align_right, true)
  end

  defp current_has_dot(form) do
    form |> current_params() |> Map.get(:has_dot, false)
  end
end
