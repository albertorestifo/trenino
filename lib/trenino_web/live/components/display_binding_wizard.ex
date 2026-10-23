defmodule TreninoWeb.DisplayBindingWizard do
  @moduledoc "Wizard for selecting a display, simulator value, and number format."

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Train
  alias Trenino.Train.{DisplayBinding, DisplayController, DisplayFormatter}

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
        socket
        |> assign(:i2c_modules, Hardware.list_all_i2c_modules())
        |> initialize_wizard(assigns[:binding])
      end

    {:ok, handle_explorer_event(assigns, socket)}
  end

  @impl true
  def update(assigns, socket), do: {:ok, handle_explorer_event(assigns, socket)}

  defp handle_explorer_event(%{explorer_event: {:select, _field, path} = event}, socket) do
    if socket.assigns[:last_explorer_event] == event do
      socket
    else
      socket
      |> assign(:endpoint, path)
      |> assign(:wizard_step, :configure)
      |> assign(:last_explorer_event, event)
    end
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), :display_binding_cancelled)
    socket
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, binding) do
    format = if binding, do: binding.format_string, else: "{value:.0f}"
    {mode, decimals} = format_options(format)

    socket
    |> assign(:wizard_step, if(binding, do: :configure, else: :select_module))
    |> assign(:endpoint, binding && binding.endpoint)
    |> assign(:selected_module_id, binding && binding.i2c_module_id)
    |> assign(:format_string, format)
    |> assign(:format_mode, mode)
    |> assign(:decimals, decimals)
    |> assign(:name, (binding && binding.name) || "")
    |> assign(:save_error, nil)
    |> assign(:last_explorer_event, nil)
    |> assign(:initialized, true)
  end

  defp format_options(format) do
    case Regex.run(~r/^\{value:\.(\d+)f\}$/, format) do
      [_, decimals] -> {"decimals", decimals}
      _ -> {"custom", "0"}
    end
  end

  @impl true
  def handle_event("select_module", %{"module-id" => id}, socket) do
    case Enum.find(socket.assigns.i2c_modules, &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, assign(socket, :save_error, "This display is no longer available.")}

      mod ->
        {:noreply,
         socket
         |> assign(:selected_module_id, mod.id)
         |> assign(:wizard_step, :select_endpoint)
         |> assign(:last_explorer_event, nil)}
    end
  end

  def handle_event("update_config", params, socket), do: {:noreply, update_config(socket, params)}

  def handle_event("back", _params, socket) do
    previous =
      if socket.assigns.wizard_step == :configure, do: :select_endpoint, else: :select_module

    {:noreply, socket |> assign(:wizard_step, previous) |> assign(:last_explorer_event, nil)}
  end

  def handle_event("save", params, socket) do
    socket = update_config(socket, params)

    if can_save?(socket.assigns) do
      case save_binding(socket) do
        {:ok, binding} ->
          DisplayController.reload_bindings()
          send(self(), {:display_binding_saved, binding})
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, assign(socket, :save_error, format_errors(changeset))}
      end
    else
      {:noreply,
       assign(
         socket,
         :save_error,
         "Choose a display and simulator value, enter a name, and check the format below."
       )}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :display_binding_cancelled)
    {:noreply, socket}
  end

  defp update_config(socket, params) do
    mode = Map.get(params, "format_mode", socket.assigns.format_mode)
    decimals = Map.get(params, "decimals", socket.assigns.decimals)

    format =
      if mode == "custom",
        do: Map.get(params, "format_string", socket.assigns.format_string),
        else: "{value:.#{decimals}f}"

    socket
    |> assign(:format_mode, mode)
    |> assign(:decimals, decimals)
    |> assign(:format_string, format)
    |> assign(:name, Map.get(params, "name", socket.assigns.name))
    |> assign(:save_error, nil)
  end

  defp save_binding(socket) do
    params = Map.take(socket.assigns, [:endpoint, :format_string, :name])
    params = Map.put(params, :i2c_module_id, socket.assigns.selected_module_id)

    case socket.assigns.binding do
      nil -> Train.create_display_binding(socket.assigns.train_id, params)
      %DisplayBinding{} = binding -> Train.update_display_binding(binding, params)
    end
  end

  defp can_save?(assigns) do
    assigns.endpoint not in [nil, ""] and
      Enum.any?(assigns.i2c_modules, &(&1.id == assigns.selected_module_id)) and
      String.trim(assigns.name) != "" and
      String.trim(assigns.format_string) != "" and
      DisplayFormatter.validate_format(assigns.format_string) == :ok
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&TreninoWeb.CoreComponents.translate_error/1)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
  end

  @impl true
  def render(assigns) do
    selected = Enum.find(assigns.i2c_modules, &(&1.id == assigns.selected_module_id))

    error =
      if String.trim(assigns.format_string) == "" do
        "Enter a format or choose decimal places."
      else
        case DisplayFormatter.validate_format(assigns.format_string) do
          :ok -> nil
          {:error, message} -> message
        end
      end

    preview =
      if is_nil(error), do: DisplayFormatter.format(assigns.format_string, 42.5), else: "—"

    overflow =
      selected && is_nil(error) &&
        String.length(String.replace(preview, ".", "")) > selected.params.num_digits

    assigns =
      assign(assigns,
        selected_module: selected,
        format_error: error,
        preview: preview,
        preview_overflow: overflow
      )

    ~H"""
    <div
      id="display-binding-dialog"
      role="dialog"
      aria-modal="true"
      aria-labelledby="display-binding-title"
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      phx-window-keydown="cancel"
      phx-key="Escape"
      phx-target={@myself}
      phx-mounted={
        JS.push_focus(
          to: if(@binding, do: "#edit-display-binding-#{@binding.id}", else: "#add-display-binding")
        )
        |> JS.focus(to: "#display-binding-title")
      }
      phx-remove={JS.pop_focus()}
    >
      <div
        class="absolute inset-0 bg-black/50"
        phx-click="cancel"
        phx-target={@myself}
        aria-hidden="true"
      />
      <.focus_wrap
        id="display-binding-focus"
        class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col min-h-0"
      >
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <h2 id="display-binding-title" tabindex="-1" class="text-lg font-semibold">
                {if @binding, do: "Edit display binding", else: "Add display binding"}
              </h2>
              <p class="text-sm text-base-content/60">
                Show a simulator value on a hardware display.
              </p>
            </div>
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              aria-label="Close display binding"
              class="btn btn-ghost btn-sm btn-circle shrink-0"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <ol class="flex flex-wrap gap-x-6 gap-y-2 mt-4 text-sm" aria-label="Display binding steps">
            <li
              aria-current={@wizard_step == :select_module && "step"}
              class={[@wizard_step == :select_module && "font-semibold"]}
            >
              1. Display
            </li>
            <li
              aria-current={@wizard_step == :select_endpoint && "step"}
              class={[@wizard_step == :select_endpoint && "font-semibold"]}
            >
              2. Simulator value
            </li>
            <li
              aria-current={@wizard_step == :configure && "step"}
              class={[@wizard_step == :configure && "font-semibold"]}
            >
              3. Format
            </li>
          </ol>
        </div>
        <div :if={@save_error} role="alert" class="px-4 pt-4 text-sm text-error">{@save_error}</div>
        <div :if={@wizard_step == :select_module} class="p-4 sm:p-6 overflow-y-auto space-y-4">
          <h3 class="font-semibold">Choose a display</h3>
          <p :if={Enum.empty?(@i2c_modules)} class="text-sm">
            Add a display to a hardware configuration first.
            <.link navigate={~p"/"} class="link">Open hardware configurations</.link>
          </p>
          <button
            :for={mod <- @i2c_modules}
            type="button"
            phx-click="select_module"
            phx-value-module-id={mod.id}
            phx-target={@myself}
            class="w-full p-4 rounded-lg border border-base-300 text-left hover:bg-base-200 focus-visible:outline-2 focus-visible:outline-primary"
          >
            <span class="block font-medium break-words">{mod.name || "Display"}</span>
            <span class="block text-xs text-base-content/60 break-words">
              {mod.device.name} · {mod.params.num_digits} digits ·
              <span class="font-mono">{Hardware.I2cModule.format_i2c_address(mod.i2c_address)}</span>
            </span>
          </button>
        </div>
        <div
          :if={@wizard_step == :select_endpoint}
          class="flex-1 min-h-0 flex flex-col overflow-y-auto"
        >
          <div :if={is_nil(@client)} class="p-6 text-sm">
            Connect to the simulator to choose a value.
            <.link navigate={~p"/settings"} class="link">Open connection settings</.link>
          </div>
          <.live_component
            :if={@client != nil}
            module={TreninoWeb.ApiExplorerComponent}
            id="display-wizard-api-explorer"
            field={:endpoint}
            client={@client}
            mode={:none}
            embedded={true}
          />
          <div class="p-4 border-t border-base-300">
            <button type="button" phx-click="back" phx-target={@myself} class="btn btn-ghost">Back to displays</button>
          </div>
        </div>
        <div :if={@wizard_step == :configure} class="p-4 sm:p-6 overflow-y-auto space-y-4">
          <dl class="text-sm space-y-2">
            <div :if={@selected_module}>
              <dt class="text-base-content/60">Display</dt><dd class="break-words">
                {@selected_module.name} ({@selected_module.device.name})
              </dd>
            </div>
            <div>
              <dt class="text-base-content/60">Simulator value</dt><dd class="font-mono text-xs break-all">
                {@endpoint}
              </dd>
            </div>
          </dl>
          <.form
            for={to_form(%{})}
            id="display-binding-config-form"
            phx-change="update_config"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-4"
          >
            <.input
              id="display-binding-name"
              name="name"
              value={@name}
              label="Name"
              placeholder="e.g. Train speed"
            />
            <.input
              id="display-decimals"
              type="select"
              name="decimals"
              label="Decimal places"
              value={@decimals}
              options={Enum.map(0..10, &{to_string(&1), to_string(&1)})}
              disabled={@format_mode == "custom"}
            />
            <details
              id="display-format-advanced"
              open={@format_mode == "custom"}
              class="border-t border-base-300 pt-3"
            >
              <summary class="cursor-pointer font-medium text-sm py-2">Advanced formatting</summary>
              <div class="pt-3 space-y-3">
                <.input
                  id="display-format-mode"
                  type="select"
                  name="format_mode"
                  label="Formatting"
                  value={@format_mode}
                  options={[{"Decimal places", "decimals"}, {"Custom format", "custom"}]}
                />
                <.input
                  id="display-custom-format"
                  name="format_string"
                  value={@format_string}
                  label="Custom format"
                  class="input w-full font-mono"
                  disabled={@format_mode != "custom"}
                  aria-describedby="display-format-hint display-format-error"
                />
                <p id="display-format-hint" class="text-xs text-base-content/60">
                  Use {"{value}"} for the raw value or {"{value:.2f}"} for two decimals (0–10 supported).
                </p>
              </div>
            </details>
            <p :if={@format_error} id="display-format-error" role="alert" class="text-sm text-error">
              {@format_error}
            </p>
            <div class="bg-base-200 rounded-lg p-4" aria-live="polite">
              <p class="text-xs text-base-content/60 mb-2">Preview · sample value 42.5</p>
              <output id="display-format-preview" class="font-mono text-2xl break-all">{@preview}</output>
              <p :if={@preview_overflow} class="mt-2 text-sm">
                This sample is longer than your display's {@selected_module.params.num_digits} digits. Use fewer decimal places or a shorter format.
              </p>
              <p
                :if={
                  @selected_module && not @selected_module.params.has_dot &&
                    String.contains?(@preview, ".")
                }
                class="mt-2 text-sm"
              >
                Your display is configured without a decimal point. Use zero decimal places or update its hardware settings.
              </p>
            </div>
            <div class="flex flex-wrap justify-between gap-3 pt-4 border-t border-base-300">
              <button type="button" phx-click="back" phx-target={@myself} class="btn btn-ghost">Back</button>
              <button
                id="save-display-binding"
                type="submit"
                disabled={not can_save?(assigns)}
                class="btn btn-primary"
                phx-disable-with="Saving…"
              >Save binding</button>
            </div>
          </.form>
        </div>
      </.focus_wrap>
    </div>
    """
  end
end
