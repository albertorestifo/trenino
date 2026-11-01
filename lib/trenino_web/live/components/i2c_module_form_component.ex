defmodule TreninoWeb.I2cModuleFormComponent do
  @moduledoc "Form for creating or editing an I2C module on a device."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.ADS1115.Params, as: ADS1115Params
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.MCP23017.Params, as: MCP23017Params

  @chips ~w(ht16k33 mcp23017 ads1115)
  @pin_roles ~w(unused direct row col)
  @output_only_pins [7, 15]
  @default_sensitivity "5"

  @impl true
  def update(%{i2c_module: mod, device_id: device_id} = _assigns, socket) do
    chip = if mod, do: Atom.to_string(mod.module_chip), else: "ht16k33"
    changeset = I2cModule.changeset(mod || %I2cModule{}, %{})

    {:ok,
     socket
     |> assign(:i2c_module, mod)
     |> assign(:device_id, device_id)
     |> assign(:form, to_form(changeset))
     |> assign(:chip, chip)
     |> assign(:impact, nil)
     |> assign(:free_pins, Hardware.free_virtual_pin_count(device_id, mod && mod.id))
     |> assign(
       :i2c_address_input,
       if(mod && mod.i2c_address, do: to_string(mod.i2c_address), else: "")
     )
     |> assign_chip_state(chip, mod)}
  end

  @impl true
  def handle_event("validate", %{"i2c_module" => params}, socket) do
    chip = chip_of(params, socket.assigns.chip)

    if chip != socket.assigns.chip and is_nil(socket.assigns.i2c_module) do
      {:noreply, switch_chip(socket, chip, params)}
    else
      {:noreply, validate(socket, chip, params)}
    end
  end

  def handle_event("save", %{"i2c_module" => params}, socket) do
    chip = chip_of(params, socket.assigns.chip)
    coerced = coerce_params(params, chip)

    case pending_impact(socket.assigns.i2c_module, coerced, socket.assigns.impact) do
      {:confirm, impact} -> {:noreply, assign(socket, :impact, impact)}
      :proceed -> {:noreply, save(socket, coerced)}
    end
  end

  defp validate(socket, "ht16k33", params) do
    pct =
      case Integer.parse(Map.get(params, "brightness_pct", "53")) do
        {n, ""} -> n
        _ -> 53
      end

    changeset =
      (socket.assigns.i2c_module || %I2cModule{})
      |> I2cModule.changeset(coerce_params(params, "ht16k33"))
      |> Map.put(:action, :validate)

    socket
    |> assign(:form, to_form(changeset))
    |> assign(:brightness_pct, pct)
    |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))
    |> assign(:impact, nil)
  end

  defp validate(socket, chip, params) do
    socket = read_chip_state(socket, chip, params)

    changeset =
      (socket.assigns.i2c_module || %I2cModule{})
      |> I2cModule.changeset(coerce_params(params_from_state(socket, params), chip))
      |> Map.put(:action, :validate)

    socket
    |> assign(:form, to_form(changeset))
    |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))
    |> assign(:impact, nil)
  end

  # A new chip has its own fields, so only the name and address carry over.
  defp switch_chip(socket, chip, params) do
    attrs =
      params
      |> coerce_params(chip)
      |> Map.take([:name, :module_chip, :i2c_address])

    socket
    |> assign(:chip, chip)
    |> assign(:form, to_form(I2cModule.changeset(%I2cModule{}, attrs)))
    |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))
    |> assign(:impact, nil)
    |> assign_chip_state(chip, nil)
  end

  defp save(socket, coerced) do
    result =
      case socket.assigns.i2c_module do
        nil -> Hardware.create_i2c_module(socket.assigns.device_id, coerced)
        mod -> Hardware.update_i2c_module(mod, coerced)
      end

    case result do
      {:ok, _mod} ->
        send(self(), :i2c_module_saved)
        socket

      {:error, changeset} ->
        assign(socket, :form, to_form(changeset))
    end
  end

  # An edit that would remove bound inputs needs a second save to go through.
  defp pending_impact(%I2cModule{} = mod, coerced, shown) do
    if I2cModule.input_chip?(mod) do
      case Hardware.i2c_module_impact(mod, coerced) do
        [] -> :proceed
        ^shown -> :proceed
        impact -> {:confirm, impact}
      end
    else
      :proceed
    end
  end

  defp pending_impact(nil, _coerced, _shown), do: :proceed

  defp chip_of(params, fallback) do
    case Map.get(params, "module_chip") do
      chip when chip in @chips -> chip
      _ -> fallback
    end
  end

  # Per-chip form state

  defp assign_chip_state(socket, chip, mod) do
    socket
    |> assign(:brightness_pct, 53)
    |> assign(:pins, default_pins())
    |> assign(:debounce, Integer.to_string(MCP23017Params.default_debounce(0)))
    |> assign(:debounce_touched, false)
    |> assign(:channels, default_channels())
    |> assign(:gain, "0")
    |> assign(:ref_channel, "")
    |> init_chip_state(chip, mod)
  end

  defp init_chip_state(socket, "ht16k33", %I2cModule{params: %HT16K33Params{} = params}),
    do: assign(socket, :brightness_pct, round((params.brightness || 8) * 100 / 15))

  defp init_chip_state(socket, "mcp23017", %I2cModule{params: %MCP23017Params{} = params}) do
    default = MCP23017Params.default_debounce(params.row_mask)

    socket
    |> assign(:pins, pins_from_masks(params))
    |> assign(:debounce, to_string(params.debounce || default))
    |> assign(:debounce_touched, params.debounce not in [nil, default])
  end

  defp init_chip_state(socket, "ads1115", %I2cModule{params: %ADS1115Params{} = params} = mod) do
    inputs = Map.new(Hardware.list_i2c_module_inputs(mod), &{&1.i2c_channel, &1})

    channels =
      Map.new(0..3, fn channel ->
        input = Map.get(inputs, channel)

        {channel,
         %{
           enabled: Bitwise.band(params.channel_mask, Bitwise.bsl(1, channel)) != 0,
           name: (input && input.name) || "",
           sensitivity: to_string((input && input.sensitivity) || @default_sensitivity)
         }}
      end)

    socket
    |> assign(:channels, channels)
    |> assign(:gain, to_string(params.gain))
    |> assign(:ref_channel, if(params.ref_channel, do: to_string(params.ref_channel), else: ""))
  end

  defp init_chip_state(socket, "ads1115", nil),
    do: assign(socket, :channels, put_in(default_channels(), [0, :enabled], true))

  defp init_chip_state(socket, _chip, _mod), do: socket

  defp default_pins, do: Map.new(0..15, &{&1, "unused"})

  defp default_channels do
    Map.new(0..3, &{&1, %{enabled: false, name: "", sensitivity: @default_sensitivity}})
  end

  defp pins_from_masks(params) do
    Map.new(0..15, fn pin ->
      role =
        cond do
          bit_set?(params.direct_mask, pin) -> "direct"
          bit_set?(params.row_mask, pin) -> "row"
          bit_set?(params.col_mask, pin) -> "col"
          true -> "unused"
        end

      {pin, role}
    end)
  end

  defp bit_set?(mask, bit), do: Bitwise.band(mask, Bitwise.bsl(1, bit)) != 0

  defp read_chip_state(socket, "mcp23017", params) do
    pins = read_pins(Map.get(params, "pins"), socket.assigns.pins)
    row_mask = mask_for(pins, "row")
    shown = socket.assigns.debounce
    submitted = Map.get(params, "debounce", shown)

    touched =
      socket.assigns.debounce_touched or
        Map.get(params, "debounce_touched") == "true" or submitted != shown

    debounce =
      if touched,
        do: submitted,
        else: Integer.to_string(MCP23017Params.default_debounce(row_mask))

    socket
    |> assign(:pins, pins)
    |> assign(:debounce, debounce)
    |> assign(:debounce_touched, touched)
  end

  defp read_chip_state(socket, "ads1115", params) do
    raw = Map.get(params, "channels")

    channels =
      Map.new(socket.assigns.channels, fn {channel, old} ->
        new = if is_map(raw), do: Map.get(raw, Integer.to_string(channel), %{}), else: %{}

        {channel,
         %{
           enabled: read_enabled(Map.get(new, "enabled"), old.enabled),
           name: Map.get(new, "name", old.name),
           sensitivity: Map.get(new, "sensitivity", old.sensitivity)
         }}
      end)

    ref = Map.get(params, "ref_channel", socket.assigns.ref_channel)

    socket
    |> assign(:channels, channels)
    |> assign(:gain, Map.get(params, "gain", socket.assigns.gain))
    |> assign(:ref_channel, drop_enabled_ref(ref, channels))
  end

  defp read_chip_state(socket, _chip, _params), do: socket

  defp read_enabled("true", _old), do: true
  defp read_enabled("false", _old), do: false
  defp read_enabled(_missing, old), do: old

  # A reference cannot be an input, so enabling its channel clears it.
  defp drop_enabled_ref(ref, channels) do
    case Integer.parse(ref) do
      {channel, ""} -> if channels[channel][:enabled], do: "", else: ref
      _ -> ""
    end
  end

  defp read_pins(raw, old) when is_map(raw) do
    Map.new(old, fn {pin, role} ->
      case Map.get(raw, Integer.to_string(pin)) do
        new when new in @pin_roles -> {pin, new}
        _ -> {pin, role}
      end
    end)
  end

  defp read_pins(_raw, old), do: old

  defp mask_for(pins, role) do
    Enum.reduce(pins, 0, fn
      {pin, ^role}, mask -> Bitwise.bor(mask, Bitwise.bsl(1, pin))
      _, mask -> mask
    end)
  end

  # The validated state, written back over the posted params so that fields the
  # browser did not send (a disabled channel's name) are not lost.
  defp params_from_state(socket, params) do
    case socket.assigns.chip do
      "mcp23017" ->
        params
        |> Map.put(
          "pins",
          Map.new(socket.assigns.pins, fn {pin, role} -> {to_string(pin), role} end)
        )
        |> Map.put("debounce", socket.assigns.debounce)

      "ads1115" ->
        params
        |> Map.put("channels", state_channels(socket.assigns.channels))
        |> Map.put("gain", socket.assigns.gain)
        |> Map.put("ref_channel", socket.assigns.ref_channel)

      _ ->
        params
    end
  end

  defp state_channels(channels) do
    Map.new(channels, fn {channel, state} ->
      {to_string(channel), %{state | enabled: to_string(state.enabled)}}
    end)
  end

  # Params

  defp coerce_params(raw, "mcp23017") do
    pins = read_pins(Map.get(raw, "pins"), default_pins())

    base_attrs(raw, "mcp23017")
    |> Map.put(:params, %{
      direct_mask: mask_for(pins, "direct"),
      row_mask: mask_for(pins, "row"),
      col_mask: mask_for(pins, "col"),
      debounce: Map.get(raw, "debounce")
    })
  end

  defp coerce_params(raw, "ads1115") do
    channels = Map.get(raw, "channels") || %{}

    enabled =
      for channel <- 0..3,
          get_in(channels, [Integer.to_string(channel), "enabled"]) in ["true", true],
          do: channel

    base_attrs(raw, "ads1115")
    |> Map.put(:params, %{
      channel_mask: Enum.reduce(enabled, 0, &Bitwise.bor(&2, Bitwise.bsl(1, &1))),
      gain: Map.get(raw, "gain"),
      ref_channel: Map.get(raw, "ref_channel")
    })
    |> Map.put(
      :channels,
      Map.new(enabled, fn channel ->
        settings = Map.get(channels, Integer.to_string(channel))

        {channel,
         %{name: Map.get(settings, "name"), sensitivity: Map.get(settings, "sensitivity")}}
      end)
    )
  end

  defp coerce_params(raw, _chip), do: coerce_params(raw)

  defp base_attrs(raw, chip) do
    %{
      name: Map.get(raw, "name"),
      module_chip: chip,
      i2c_address: parse_address(raw)
    }
  end

  defp parse_address(raw) do
    case I2cModule.parse_i2c_address(Map.get(raw, "i2c_address_raw", "")) do
      {:ok, n} -> n
      :error -> nil
    end
  end

  defp coerce_params(raw) do
    addr = parse_address(raw)

    pct = parse_pct(Map.get(raw, "brightness_pct"))
    brightness = round(pct * 15 / 100)

    %{
      name: Map.get(raw, "name"),
      module_chip: Map.get(raw, "module_chip"),
      i2c_address: addr,
      params:
        %{
          brightness: brightness,
          num_digits: Map.get(raw, "num_digits"),
          display_type: Map.get(raw, "display_type"),
          has_dot: Map.get(raw, "has_dot") == "true",
          align_right: Map.get(raw, "align_right") == "true",
          min_value: normalize_minimum(Map.get(raw, "min_value", "0")),
          orientation: Map.get(raw, "orientation")
        }
        # Drop a missing orientation so updates keep the stored value instead of
        # casting nil into a required field.
        |> then(fn params ->
          if params.orientation, do: params, else: Map.delete(params, :orientation)
        end)
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
    assigns = assign(assigns, :params_form, params_form(assigns))

    ~H"""
    <div>
      <.form
        id="i2c-module-form"
        for={@form}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <.ht16k33_fields
          :if={@chip == "ht16k33"}
          form={@form}
          params_form={@params_form}
          brightness_pct={@brightness_pct}
          i2c_address_input={@i2c_address_input}
          create?={is_nil(@i2c_module)}
        />
        <.mcp23017_fields
          :if={@chip == "mcp23017"}
          form={@form}
          pins={@pins}
          debounce={@debounce}
          debounce_touched={@debounce_touched}
          free_pins={@free_pins}
          i2c_address_input={@i2c_address_input}
          create?={is_nil(@i2c_module)}
        />
        <.ads1115_fields
          :if={@chip == "ads1115"}
          form={@form}
          channels={@channels}
          gain={@gain}
          ref_channel={@ref_channel}
          i2c_address_input={@i2c_address_input}
          create?={is_nil(@i2c_module)}
        />
        <.impact_panel :if={@impact} impact={@impact} />
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" phx-click="close_i2c_modal" class="btn btn-ghost">Cancel</button>
          <button type="submit" class="btn btn-primary" phx-disable-with="Saving…">
            {submit_label(@chip, @i2c_module, @impact)}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp submit_label(_chip, _mod, impact) when is_list(impact), do: "Confirm and save"
  defp submit_label("ht16k33", mod, _impact), do: if(mod, do: "Save display", else: "Add display")
  defp submit_label(_chip, mod, _impact), do: if(mod, do: "Save module", else: "Add module")

  # Shared fields

  attr :chip, :string, required: true
  attr :create?, :boolean, required: true

  defp chip_field(%{create?: true} = assigns) do
    ~H"""
    <.input
      id="module-chip"
      type="select"
      name="i2c_module[module_chip]"
      label="Chip"
      value={@chip}
      options={[
        {"HT16K33 display driver", "ht16k33"},
        {"MCP23017 buttons and switches", "mcp23017"},
        {"ADS1115 analog inputs", "ads1115"}
      ]}
    />
    """
  end

  defp chip_field(%{chip: "ht16k33"} = assigns) do
    ~H"""
    <input type="hidden" name="i2c_module[module_chip]" value="ht16k33" />
    <p class="text-xs text-base-content/60">Uses an HT16K33 display driver.</p>
    """
  end

  defp chip_field(assigns) do
    ~H"""
    <input type="hidden" name="i2c_module[module_chip]" value={@chip} />
    <p class="text-xs text-base-content/60">{chip_title(@chip)}</p>
    """
  end

  defp chip_title("mcp23017"), do: "Uses an MCP23017 I/O expander."
  defp chip_title("ads1115"), do: "Uses an ADS1115 analog converter."

  attr :form, :any, required: true
  attr :i2c_address_input, :string, required: true
  attr :placeholder, :string, required: true
  attr :hint, :string, required: true

  defp chip_address_field(assigns) do
    assigns = assign(assigns, :errors, address_errors(assigns.form, assigns.i2c_address_input))

    ~H"""
    <.input
      id="chip-address"
      type="text"
      name="i2c_module[i2c_address_raw]"
      value={@i2c_address_input}
      label="I2C address"
      placeholder={@placeholder}
      class="input input-bordered w-full font-mono"
      aria-describedby="chip-address-hint"
      errors={@errors}
    />
    <p id="chip-address-hint" class="text-xs text-base-content/60">{@hint}</p>
    """
  end

  # A blank address is only an error once the user has tried to save.
  defp address_errors(%Phoenix.HTML.Form{source: %Ecto.Changeset{action: :validate}}, ""), do: []

  defp address_errors(form, _input),
    do: Enum.map(form[:i2c_address].errors, &TreninoWeb.CoreComponents.translate_error/1)

  attr :form, :any, required: true

  defp chip_errors(assigns) do
    assigns = assign(assigns, :messages, chip_error_messages(assigns.form))

    ~H"""
    <div :if={@messages != []} id="chip-errors" class="space-y-1" role="alert">
      <p :for={message <- @messages} class="flex gap-2 items-center text-sm text-error">
        <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
        {message}
      </p>
    </div>
    """
  end

  defp chip_error_messages(%Phoenix.HTML.Form{source: %Ecto.Changeset{action: nil}}), do: []

  defp chip_error_messages(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    top = for {:params, error} <- changeset.errors, do: translate(error)

    nested =
      case changeset.changes do
        %{params: %Ecto.Changeset{errors: errors}} ->
          for {field, error} <- errors, do: describe_error(field, error)

        _ ->
          []
      end

    Enum.uniq(top ++ nested)
  end

  defp describe_error(:channel_mask, _error), do: "Enable at least one channel."
  defp describe_error(:debounce, error), do: "Debounce " <> translate(error)
  defp describe_error(:gain, error), do: "Gain " <> translate(error)
  defp describe_error(:ref_channel, error), do: "Supply reference " <> translate(error)
  defp describe_error(_field, error), do: error |> translate() |> upcase_first()

  defp translate(error), do: TreninoWeb.CoreComponents.translate_error(error)

  defp upcase_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  defp upcase_first(other), do: other

  attr :impact, :list, required: true

  defp impact_panel(assigns) do
    ~H"""
    <div
      id="impact-confirmation"
      class="mt-4 rounded-lg border border-error/30 bg-error/5 p-3 space-y-2"
      role="alert"
    >
      <p class="flex gap-2 items-center text-sm font-medium">
        <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
        This change removes inputs that are in use.
      </p>
      <ul class="text-sm space-y-1">
        <li :for={item <- @impact}>
          <span class="font-medium">{item.name}</span>
          <span class="text-base-content/70">{item.binding}</span>
        </li>
      </ul>
      <p class="text-xs text-base-content/60">
        Save again to confirm. Their bindings and calibration will be deleted.
      </p>
    </div>
    """
  end

  # HT16K33

  attr :form, :any, required: true
  attr :params_form, :any, required: true
  attr :brightness_pct, :integer, required: true
  attr :i2c_address_input, :string, required: true
  attr :create?, :boolean, required: true

  defp ht16k33_fields(assigns) do
    ~H"""
    <div class="space-y-4">
      <.input field={@form[:name]} label="Name" placeholder="e.g. Speed display" />
      <.chip_field chip="ht16k33" create?={@create?} />
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
        errors={Enum.map(@form[:i2c_address].errors, &TreninoWeb.CoreComponents.translate_error/1)}
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
      <.input
        id="display-orientation"
        type="select"
        name="i2c_module[orientation]"
        label="Orientation"
        value={current_orientation(@form)}
        options={[
          {"Normal", "normal"},
          {"Rotated 180°", "rotated_180"},
          {"Flipped horizontal", "flipped_horizontal"},
          {"Flipped vertical", "flipped_vertical"}
        ]}
        aria-describedby="display-orientation-hint"
      />
      <p id="display-orientation-hint" class="text-xs text-base-content/60">
        Use if the display is mounted upside down or mirrored.
      </p>
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
    """
  end

  # MCP23017

  @role_options [
    {"Unused", "unused"},
    {"Button", "direct"},
    {"Matrix row", "row"},
    {"Matrix column", "col"}
  ]
  @output_only_options [{"Unused", "unused"}, {"Matrix row", "row"}]

  attr :form, :any, required: true
  attr :pins, :map, required: true
  attr :debounce, :string, required: true
  attr :debounce_touched, :boolean, required: true
  attr :free_pins, :integer, required: true
  attr :i2c_address_input, :string, required: true
  attr :create?, :boolean, required: true

  defp mcp23017_fields(assigns) do
    assigns = assign(assigns, :summary, mcp_summary(assigns.pins, assigns.free_pins))

    ~H"""
    <div class="space-y-4">
      <.input field={@form[:name]} label="Name" placeholder="e.g. Cab switches" />
      <.chip_field chip="mcp23017" create?={@create?} />
      <.chip_address_field
        form={@form}
        i2c_address_input={@i2c_address_input}
        placeholder="0x20"
        hint="Set by the A0, A1 and A2 pins: 0x20 to 0x27. Enter decimal (32) or hex (0x20)."
      />
      <div class="grid grid-cols-2 gap-4">
        <fieldset :for={{port, title} <- [{0, "Port A"}, {1, "Port B"}]} class="space-y-1">
          <legend class="text-sm font-medium mb-1">{title}</legend>
          <.input
            :for={n <- 0..7}
            id={"pin-#{port * 8 + n}"}
            type="select"
            name={"i2c_module[pins][#{port * 8 + n}]"}
            label={pin_label(port * 8 + n)}
            value={@pins[port * 8 + n]}
            options={pin_options(port * 8 + n)}
            class="select select-sm w-full"
            aria-describedby={if (port * 8 + n) in [7, 15], do: "pin-output-only-note"}
          />
        </fieldset>
      </div>
      <p id="pin-output-only-note" class="text-xs text-base-content/60">
        GPA7 and GPB7 are output-only on this chip, so they can only be matrix rows.
      </p>
      <div id="mcp-summary" class="rounded-lg bg-base-200/50 p-3 text-sm space-y-1" aria-live="polite">
        <p :if={@summary.direct > 0} id="mcp-direct-count">
          {@summary.direct} {if @summary.direct == 1, do: "button", else: "buttons"} on their own pins
        </p>
        <p :if={@summary.rows > 0 or @summary.cols > 0} id="mcp-matrix-size">
          <%= if @summary.rows > 0 and @summary.cols > 0 do %>
            Matrix: {@summary.rows} × {@summary.cols}, {@summary.rows * @summary.cols} buttons
          <% else %>
            A matrix needs at least one row and one column.
          <% end %>
        </p>
        <p id="mcp-pins-left" class="text-base-content/70">
          <%= if @summary.left >= 0 do %>
            {@summary.left} virtual {if @summary.left == 1, do: "pin", else: "pins"} left on this device
          <% else %>
            Needs {-@summary.left} more virtual pins than this device has free
          <% end %>
        </p>
      </div>
      <input type="hidden" name="i2c_module[debounce_touched]" value={to_string(@debounce_touched)} />
      <.input
        id="mcp-debounce"
        type="number"
        name="i2c_module[debounce]"
        label="Debounce (samples)"
        value={@debounce}
        min="1"
        max="255"
        aria-describedby="mcp-debounce-hint"
      />
      <p id="mcp-debounce-hint" class="text-xs text-base-content/60">
        How many samples in a row a pin must agree before a press counts. It follows the layout until you change it.
      </p>
      <.chip_errors form={@form} />
    </div>
    """
  end

  defp pin_label(pin) when pin < 8, do: "GPA#{pin}"
  defp pin_label(pin), do: "GPB#{pin - 8}"

  defp pin_options(pin) when pin in @output_only_pins, do: @output_only_options
  defp pin_options(_pin), do: @role_options

  defp mcp_summary(pins, free_pins) do
    count = fn role -> Enum.count(pins, fn {_pin, r} -> r == role end) end
    {direct, rows, cols} = {count.("direct"), count.("row"), count.("col")}
    needed = if(direct > 0, do: 16, else: 0) + rows * cols

    %{direct: direct, rows: rows, cols: cols, left: free_pins - needed}
  end

  # ADS1115

  attr :form, :any, required: true
  attr :channels, :map, required: true
  attr :gain, :string, required: true
  attr :ref_channel, :string, required: true
  attr :i2c_address_input, :string, required: true
  attr :create?, :boolean, required: true

  defp ads1115_fields(assigns) do
    assigns =
      assign(
        assigns,
        :reference_options,
        [{"None", ""}] ++
          for({channel, %{enabled: false}} <- assigns.channels, do: {"AIN#{channel}", channel})
      )

    ~H"""
    <div class="space-y-4">
      <.input field={@form[:name]} label="Name" placeholder="e.g. Cab levers" />
      <.chip_field chip="ads1115" create?={@create?} />
      <.chip_address_field
        form={@form}
        i2c_address_input={@i2c_address_input}
        placeholder="0x48"
        hint="Set by the ADDR pin: 0x48 to 0x4B. Enter decimal (72) or hex (0x48)."
      />
      <fieldset class="space-y-2">
        <legend class="text-sm font-medium mb-1">Channels</legend>
        <div
          :for={{channel, state} <- Enum.sort(@channels)}
          id={"ads-channel-#{channel}"}
          class="rounded-lg border border-base-300 p-3"
        >
          <.input
            id={"ads-enabled-#{channel}"}
            type="checkbox"
            name={"i2c_module[channels][#{channel}][enabled]"}
            label={"AIN#{channel}"}
            checked={state.enabled}
          />
          <div :if={state.enabled} class="grid grid-cols-2 gap-3">
            <.input
              id={"ads-name-#{channel}"}
              type="text"
              name={"i2c_module[channels][#{channel}][name]"}
              label="Name"
              value={state.name}
              placeholder={"AIN#{channel}"}
            />
            <.input
              id={"ads-sensitivity-#{channel}"}
              type="number"
              name={"i2c_module[channels][#{channel}][sensitivity]"}
              label="Sensitivity (1 to 10)"
              value={state.sensitivity}
              min="1"
              max="10"
            />
          </div>
        </div>
      </fieldset>
      <.input
        id="ads-gain"
        type="select"
        name="i2c_module[gain]"
        label="Input range"
        value={@gain}
        options={[{"±6.144 V (for a 5 V supply)", "0"}, {"±4.096 V", "1"}]}
      />
      <.input
        id="ads-reference"
        type="select"
        name="i2c_module[ref_channel]"
        label="Supply reference"
        value={@ref_channel}
        options={@reference_options}
        aria-describedby="ads-reference-hint"
      />
      <p id="ads-reference-hint" class="text-xs text-base-content/60">
        Wrapping sensors need a supply reference, which uses one channel. All sensors on this chip must share the supply wired to it.
      </p>
      <.chip_errors form={@form} />
    </div>
    """
  end

  defp params_form(%{chip: chip}) when chip != "ht16k33", do: nil

  defp params_form(%{form: %Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}}) do
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

  defp current_orientation(form),
    do: form |> current_params() |> Map.get(:orientation) |> to_string()

  defp current_align_right(form), do: form |> current_params() |> Map.get(:align_right)
  defp current_has_dot(form), do: form |> current_params() |> Map.get(:has_dot)
end
