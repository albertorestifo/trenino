defmodule TreninoWeb.I2cModuleFormComponent do
  @moduledoc "Form for creating or editing an I2C module on a device."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule

  @impl true
  def update(%{i2c_module: mod, device_id: device_id} = _assigns, socket) do
    changeset = I2cModule.changeset(mod || %I2cModule{}, %{})
    wire = (mod && mod.brightness) || 8
    brightness_pct = round(wire * 100 / 15)

    {:ok,
     socket
     |> assign(:i2c_module, mod)
     |> assign(:device_id, device_id)
     |> assign(:form, to_form(changeset))
     |> assign(:brightness_pct, brightness_pct)
     |> assign(
       :i2c_address_input,
       if(mod, do: I2cModule.format_i2c_address(mod.i2c_address), else: "")
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

  defp coerce_params(params) do
    addr_str = Map.get(params, "i2c_address_raw", "")

    addr =
      case I2cModule.parse_i2c_address(addr_str) do
        {:ok, n} -> n
        :error -> nil
      end

    pct =
      case Integer.parse(Map.get(params, "brightness_pct", "53")) do
        {n, ""} -> n
        _ -> 53
      end

    brightness = round(pct * 15 / 100)

    params
    |> Map.put("i2c_address", addr)
    |> Map.put("brightness", brightness)
    |> Map.take(["name", "module_chip", "i2c_address", "brightness", "num_digits"])
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      Map.put(acc, String.to_existing_atom(k), v)
    end)
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
              <option
                value="ht16k33"
                selected={to_string(@form[:module_chip].value) == "ht16k33"}
              >
                HT16K33 (14-segment display)
              </option>
            </select>
          </div>
          <div>
            <label class="label">
              <span class="label-text font-medium">I2C Address</span>
              <span class="label-text-alt text-base-content/50">
                decimal or hex (e.g. 112 or 0x70)
              </span>
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
                <option value="4" selected={to_string(@form[:num_digits].value) == "4"}>
                  4 digits
                </option>
                <option value="8" selected={to_string(@form[:num_digits].value) == "8"}>
                  8 digits
                </option>
              </select>
            </div>
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
end
