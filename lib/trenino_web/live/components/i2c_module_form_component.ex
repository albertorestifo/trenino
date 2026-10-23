defmodule TreninoWeb.I2cModuleFormComponent do
  @moduledoc "Form for creating or editing an I2C module on a device."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params
  alias Trenino.Hardware.I2cModule

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
        min_value: normalize_minimum(Map.get(raw, "min_value", "0"))
      }
    }
  end

  defp normalize_minimum(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp normalize_minimum(value), do: value

  defp parse_pct(val) do
    case Integer.parse(val || "53") do
      {n, ""} -> n
      _ -> 53
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :params_form, params_form(assigns.form))

    ~H"""
    <div>
      <.form
        id="i2c-module-form"
        for={@form}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <div class="space-y-4">
          <.input field={@form[:name]} label="Name" placeholder="e.g. Speed display" />
          <input type="hidden" name="i2c_module[module_chip]" value="ht16k33" />
          <p class="text-xs text-base-content/60">Uses an HT16K33 display driver.</p>
          <.input
            id="display-type"
            type="select"
            name="i2c_module[display_type]"
            label="Display type"
            value={current_display_type(@form)}
            options={[
              {"14-segment (letters and numbers)", "fourteen_segment"},
              {"7-segment (numbers)", "seven_segment"}
            ]}
          />
          <.input
            id="display-address"
            type="text"
            name="i2c_module[i2c_address_raw]"
            value={@i2c_address_input}
            label="I2C address"
            placeholder="0x70"
            class="input input-bordered w-full font-mono"
            aria-describedby="display-address-hint"
            errors={
              Enum.map(@form[:i2c_address].errors, &TreninoWeb.CoreComponents.translate_error/1)
            }
          />
          <p id="display-address-hint" class="text-xs text-base-content/60">
            Find this on the display board or its wiring guide. Enter decimal (112) or hex (0x70).
          </p>
          <.input
            id="display-digits"
            type="select"
            name="i2c_module[num_digits]"
            label="Digits"
            value={current_num_digits(@form)}
            options={[{"4 digits", 4}, {"8 digits", 8}]}
          />
          <details
            id="display-advanced"
            open={not @params_form.source.valid?}
            class="border-t border-base-300 pt-3"
          >
            <summary class="cursor-pointer font-medium text-sm py-2">
              Advanced display settings
            </summary>
            <div class="space-y-4 pt-3">
              <label for="display-brightness" class="block text-sm">Brightness ({@brightness_pct}%)</label>
              <input
                id="display-brightness"
                type="range"
                name="i2c_module[brightness_pct]"
                value={@brightness_pct}
                min="0"
                max="100"
                class="range range-sm w-full"
              />
              <.input
                id="display-minimum"
                type="text"
                field={@params_form[:min_value]}
                label="Minimum value"
                aria-describedby="display-minimum-hint"
              />
              <p id="display-minimum-hint" class="text-xs text-base-content/60">
                Values below this limit are shown at the limit. Leave blank for no limit.
              </p>
              <.input
                id="display-align-right"
                type="checkbox"
                name="i2c_module[align_right]"
                label="Right-align value"
                checked={current_align_right(@form)}
              />
              <.input
                id="display-has-dot"
                type="checkbox"
                name="i2c_module[has_dot]"
                label="Display has a decimal point"
                checked={current_has_dot(@form)}
              />
            </div>
          </details>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" phx-click="close_i2c_modal" class="btn btn-ghost">Cancel</button>
          <button type="submit" class="btn btn-primary" phx-disable-with="Saving…">
            {if @i2c_module, do: "Save display", else: "Add display"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp params_form(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    params_changeset =
      case Ecto.Changeset.get_field(changeset, :params) do
        %Ecto.Changeset{} = params -> params
        %HT16K33Params{} = params -> HT16K33Params.changeset(params, %{})
        _ -> HT16K33Params.changeset(%HT16K33Params{}, %{})
      end

    to_form(params_changeset, as: :i2c_module)
  end

  defp current_params(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    case Ecto.Changeset.get_field(changeset, :params) do
      %Ecto.Changeset{} = params -> Ecto.Changeset.apply_changes(params)
      %HT16K33Params{} = params -> params
      _ -> %HT16K33Params{}
    end
  end

  defp current_display_type(form),
    do: form |> current_params() |> Map.get(:display_type) |> to_string()

  defp current_num_digits(form), do: form |> current_params() |> Map.get(:num_digits)
  defp current_align_right(form), do: form |> current_params() |> Map.get(:align_right)
  defp current_has_dot(form), do: form |> current_params() |> Map.get(:has_dot)
end
