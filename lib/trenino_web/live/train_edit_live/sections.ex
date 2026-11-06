defmodule TreninoWeb.TrainEditLive.Sections do
  @moduledoc """
  Function components for the page header, sections and modals of the train
  edit page (`TreninoWeb.TrainEditLive`).

  Events are handled by the LiveView; these components only render markup.
  """

  use TreninoWeb, :html

  import TreninoWeb.SharedComponents

  alias Trenino.Train.{DisplayBinding, Element, LeverConfig, LeverInputBinding, SelectorBinding}

  attr :train_form, :map, required: true
  attr :is_active, :boolean, required: true
  attr :new_mode, :boolean, required: true

  attr :current_identifier, :string, default: nil
  attr :simulator_connected, :boolean, default: false

  def train_header(assigns) do
    ~H"""
    <header>
      <h1 class="text-2xl font-semibold mb-4">{if @new_mode, do: "New train", else: "Edit train"}</h1>
      <.form
        id="train-form"
        for={@train_form}
        phx-change="validate_train"
        phx-submit="save_train"
      >
        <div>
          <.input
            label="Train name"
            field={@train_form[:name]}
            type="text"
            class="input input-bordered w-full text-xl font-semibold"
            placeholder="e.g., BR Class 66"
          />
        </div>
        <div class="mt-3">
          <.input
            label="Description"
            field={@train_form[:description]}
            type="textarea"
            class="textarea textarea-bordered w-full resize-none"
            placeholder="Add a description (optional)"
            rows="2"
          />
        </div>
        <div class="mt-3">
          <h2 class="text-sm font-semibold mb-2">Train identifiers</h2>
          <p id="train-identifiers-hint" class="text-xs text-muted mb-3">
            Use the simulator train ID shown on the Trains page, or connect to use it here. Each entry matches any train ID that starts with that text. Keep the full ID for one variant, or shorten the end to match several variants.
          </p>
          <div :if={@simulator_connected && @current_identifier} class="mb-3 space-y-2">
            <p class="text-xs text-muted">
              Current simulator train ID:
              <span class="font-mono break-all">{@current_identifier}</span>
            </p>
            <button
              id="use-current-train-id"
              type="button"
              phx-click="use_current_train_id"
              class="btn btn-outline btn-sm"
            >Use current train ID</button>
          </div>
          <p :if={not @simulator_connected} class="text-xs text-muted mb-3">
            <.link navigate={~p"/settings"} class="link">Connect to the simulator</.link>
            to use the current train ID, or enter one below.
          </p>
          <div class="space-y-2">
            <.inputs_for :let={identifier_form} field={@train_form[:identifiers]}>
              <div class="flex items-start gap-2">
                <input
                  type="hidden"
                  name="train[identifiers_sort][]"
                  value={identifier_form.index}
                />
                <div class="flex-1 min-w-0">
                  <.input
                    field={identifier_form[:identifier]}
                    type="text"
                    label={"Identifier #{identifier_form.index + 1}"}
                    aria-describedby="train-identifiers-hint"
                    class="input input-bordered w-full font-mono"
                    placeholder="e.g., BR_Class_66"
                  />
                </div>
                <button
                  type="button"
                  name="train[identifiers_drop][]"
                  value={identifier_form.index}
                  phx-click={Phoenix.LiveView.JS.dispatch("change")}
                  class="btn btn-ghost btn-sm text-error mt-6 shrink-0"
                  disabled={
                    length(Ecto.Changeset.get_field(@train_form.source, :identifiers, [])) <= 1
                  }
                  title={
                    if length(Ecto.Changeset.get_field(@train_form.source, :identifiers, [])) <= 1,
                      do: "Keep at least one identifier",
                      else: "Remove identifier"
                  }
                  aria-label={"Remove identifier #{identifier_form.index + 1}"}
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
            </.inputs_for>
            <input type="hidden" name="train[identifiers_drop][]" />
            <button
              type="button"
              name="train[identifiers_sort][]"
              value="new"
              phx-click={Phoenix.LiveView.JS.dispatch("change")}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Add identifier
            </button>
            <p
              :for={{message, options} <- @train_form[:identifiers].errors}
              class="text-sm text-error"
            >
              {TreninoWeb.CoreComponents.translate_error({message, options})}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-3 mt-4">
          <.status_chip :if={@is_active} kind={:ok} label="Active" />
          <button type="submit" class="btn btn-primary btn-sm ml-auto">
            <.icon name="hero-check" class="w-4 h-4" />
            {if @new_mode, do: "Create train", else: "Save"}
          </button>
        </div>
      </.form>
    </header>
    """
  end

  attr :elements, :list, required: true
  attr :selector_positions, :map, default: %{}

  def elements_section(assigns) do
    ~H"""
    <.config_section
      id="elements"
      title="Elements"
      count={length(@elements)}
      empty?={@elements == []}
      empty_icon="hero-adjustments-vertical"
      empty_message="No elements configured"
      empty_hint="Add elements to control train functions."
    >
      <:actions>
        <.section_action id="add-element" label="Add element" on_click="open_add_element_modal" />
      </:actions>
      <div class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Type</th>
              <th>Status</th>
              <th class="text-right"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <.element_row
              :for={element <- @elements}
              element={element}
              position={Map.get(@selector_positions, element.id)}
            />
          </tbody>
        </table>
      </div>
    </.config_section>
    """
  end

  attr :output_bindings, :list, required: true
  attr :simulator_connected, :boolean, required: true
  attr :outputs_available, :boolean, required: true

  def output_bindings_section(assigns) do
    assigns =
      assign(assigns, :blocked?, not (assigns.simulator_connected and assigns.outputs_available))

    ~H"""
    <.config_section
      id="output-bindings"
      title="Output bindings"
      count={length(@output_bindings)}
      empty?={@output_bindings == []}
      empty_icon="hero-light-bulb"
      empty_message="No output bindings configured"
      empty_hint="Bind outputs to simulator values to light LEDs from simulator data."
    >
      <:actions>
        <.section_action
          id="add-output-binding"
          label="Add output binding"
          on_click="open_add_output_binding"
          disabled={@blocked?}
          describedby="output-prerequisites"
        />
      </:actions>
      <:notice :if={@blocked?}>
        <div id="output-prerequisites" class="text-sm text-muted space-y-1">
          <p :if={not @simulator_connected}>
            <.link navigate={~p"/settings"} class="link">Connect to the simulator</.link>
            to choose a value for your output.
          </p>
          <p :if={not @outputs_available}>
            <.link navigate={~p"/"} class="link">Add an output to a hardware configuration</.link>
            before creating a binding.
          </p>
        </div>
      </:notice>
      <div class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Endpoint</th>
              <th>Condition</th>
              <th>Output</th>
              <th class="text-right"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={binding <- @output_bindings} class="hover:bg-base-200/50">
              <td class="font-medium">{binding.name}</td>
              <td class="font-mono text-xs max-w-[200px] truncate" title={binding.endpoint}>
                {binding.endpoint}
              </td>
              <td class="text-sm">
                <.condition_display
                  operator={binding.operator}
                  value_a={binding.value_a}
                  value_b={binding.value_b}
                />
              </td>
              <td class="text-sm">
                <span class="badge badge-ghost badge-sm">{binding.output_type}</span>
                <span class="text-muted ml-1">
                  {binding.output.name || "Pin #{binding.output.pin}"}
                </span>
              </td>
              <td>
                <.row_actions id={"output-binding-actions-#{binding.id}"} name={binding.name}>
                  <:action
                    event="configure_output_binding"
                    values={%{id: binding.id}}
                    icon="hero-cog-6-tooth"
                    label="Configure"
                  />
                  <:action
                    event="delete_output_binding"
                    values={%{id: binding.id}}
                    kind={:danger}
                    label={"Delete #{binding.name}"}
                    confirm={"Delete #{binding.name}?"}
                  />
                </.row_actions>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </.config_section>
    """
  end

  attr :display_bindings, :list, required: true
  attr :simulator_connected, :boolean, required: true
  attr :hardware_available, :boolean, required: true

  def display_bindings_section(assigns) do
    assigns =
      assign(assigns, :blocked?, not (assigns.simulator_connected and assigns.hardware_available))

    ~H"""
    <.config_section
      id="display-bindings"
      title="Display bindings"
      count={length(@display_bindings)}
      empty?={@display_bindings == []}
      empty_icon="hero-tv"
      empty_message="No display bindings configured"
      empty_hint="Show simulator values on your hardware displays."
    >
      <:actions>
        <.section_action
          id="add-display-binding"
          label="Add display binding"
          on_click="open_add_display_binding"
          disabled={@blocked?}
          describedby="display-prerequisites"
        />
      </:actions>
      <:notice :if={@blocked?}>
        <div id="display-prerequisites" class="text-sm text-muted space-y-1">
          <p :if={not @simulator_connected}>
            <.link navigate={~p"/settings"} class="link">Connect to the simulator</.link>
            to choose a value for your display.
          </p>
          <p :if={not @hardware_available}>
            <.link navigate={~p"/"} class="link">Add a display to a hardware configuration</.link>
            before creating a binding.
          </p>
        </div>
      </:notice>
      <div class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Endpoint</th>
              <th>Format</th>
              <th class="text-right"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={binding <- @display_bindings}
              id={"display-binding-#{binding.id}"}
              class="hover:bg-base-200/50"
            >
              <td class="min-w-0">
                <p :if={binding.name not in [nil, ""]} class="font-medium break-words">
                  {binding.name}
                </p>
                <p :if={binding.name in [nil, ""]} class="font-medium text-muted">Unnamed</p>
                <p class="text-xs text-muted break-words">
                  {if binding.i2c_module,
                    do: binding.i2c_module.name || "Display #{binding.i2c_module_id}",
                    else: "Display unavailable"}
                </p>
              </td>
              <td class="font-mono text-xs max-w-[200px] truncate" title={binding.endpoint}>
                {binding.endpoint}
              </td>
              <td class="font-mono text-xs">
                {binding.format_string}
                <span :if={binding.unit == "kmh"} class="badge badge-ghost badge-sm ml-1">
                  m/s → km/h
                </span>
                <span :if={binding.unit == "mph"} class="badge badge-ghost badge-sm ml-1">
                  m/s → mph
                </span>
              </td>
              <td>
                <.row_actions
                  id={"display-binding-actions-#{binding.id}"}
                  name={display_binding_name(binding)}
                >
                  <:action
                    id={"edit-display-binding-#{binding.id}"}
                    event="configure_display_binding"
                    values={%{id: binding.id}}
                    icon="hero-pencil-square"
                    label="Edit"
                  />
                  <:action
                    event="delete_display_binding"
                    values={%{id: binding.id}}
                    kind={:danger}
                    label={"Delete #{display_binding_name(binding)}"}
                    confirm={"Delete #{display_binding_name(binding)}?"}
                  />
                </.row_actions>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </.config_section>
    """
  end

  defp display_binding_name(%DisplayBinding{name: name}) when is_binary(name) and name != "",
    do: name

  # Descriptive fallback for aria-labels and confirm text only; the visible cell shows a
  # muted "Unnamed", like the other sections.
  defp display_binding_name(%DisplayBinding{}), do: "unnamed display binding"

  attr :scripts, :list, required: true
  attr :train_id, :integer, required: true

  def scripts_section(assigns) do
    ~H"""
    <.config_section
      id="scripts"
      title="Scripts"
      count={length(@scripts)}
      empty?={@scripts == []}
      empty_icon="hero-code-bracket"
      empty_message="No scripts configured"
      empty_hint="Add Lua scripts to automate actions based on simulator data."
    >
      <:actions>
        <.section_action
          id="add-script"
          label="Add script"
          navigate={~p"/trains/#{@train_id}/scripts/new"}
        />
      </:actions>
      <div class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Triggers</th>
              <th>Enabled</th>
              <th class="text-right"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={script <- @scripts} class="hover:bg-base-200/50">
              <td class="font-medium">{script.name}</td>
              <td class="text-sm text-muted tabular-nums">
                {length(script.triggers)} trigger{if length(script.triggers) != 1, do: "s"}
              </td>
              <td>
                <input
                  type="checkbox"
                  class="toggle toggle-sm toggle-primary"
                  checked={script.enabled}
                  aria-label={"#{script.name} enabled"}
                  phx-click="toggle_script_enabled"
                  phx-value-id={script.id}
                />
              </td>
              <td>
                <.row_actions id={"script-actions-#{script.id}"} name={script.name}>
                  <:action
                    id={"edit-script-#{script.id}"}
                    navigate={~p"/trains/#{@train_id}/scripts/#{script.id}"}
                    icon="hero-pencil-square"
                    label="Edit"
                  />
                  <:action
                    event="delete_script"
                    values={%{id: script.id}}
                    kind={:danger}
                    label={"Delete #{script.name}"}
                    confirm={"Delete #{script.name}?"}
                  />
                </.row_actions>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </.config_section>
    """
  end

  attr :operator, :atom, required: true
  attr :value_a, :float, default: nil
  attr :value_b, :float, default: nil

  defp condition_display(assigns) do
    ~H"""
    <span class="font-mono">
      <%= case @operator do %>
        <% :eq_true -> %>
          = true
        <% :eq_false -> %>
          = false
        <% :gt -> %>
          &gt; {@value_a}
        <% :gte -> %>
          &ge; {@value_a}
        <% :lt -> %>
          &lt; {@value_a}
        <% :lte -> %>
          &le; {@value_a}
        <% :between -> %>
          {@value_a} - {@value_b}
      <% end %>
    </span>
    """
  end

  attr :element, :map, required: true
  attr :position, :map, default: nil

  defp element_row(assigns) do
    {status_badges, configure_action} = element_status(assigns.element)

    assigns =
      assigns
      |> assign(:status_badges, status_badges)
      |> assign(:configure_action, configure_action)

    ~H"""
    <tr class="hover:bg-base-200/50">
      <td class="font-medium">
        <div class="flex items-center gap-2">
          <.icon
            name={element_type_icon(@element.type)}
            class="w-4 h-4 text-muted"
          />
          {@element.name}
        </div>
      </td>
      <td>
        <span class="badge badge-ghost badge-sm capitalize">{@element.type}</span>
      </td>
      <td>
        <.status_chip :for={{kind, label} <- @status_badges} kind={kind} label={label} />
        <span
          :if={@position}
          id={"selector-position-#{@element.id}"}
          class="ml-2 text-xs text-muted"
        >
          At {@position.label || "position #{@position.index + 1}"}
        </span>
      </td>
      <td>
        <.row_actions id={"element-actions-#{@element.id}"} name={@element.name}>
          <:action
            :if={@configure_action}
            event={@configure_action}
            values={%{id: @element.id}}
            icon="hero-cog-6-tooth"
            label="Configure"
          />
          <:action
            event="delete_element"
            values={%{id: @element.id}}
            kind={:danger}
            label={"Delete #{@element.name}"}
            confirm={"Delete #{@element.name}?"}
          />
        </.row_actions>
      </td>
    </tr>
    """
  end

  defp element_status(%{type: :lever} = element) do
    {lever_status_badge(element), "configure_lever"}
  end

  defp element_status(%{type: :button} = element) do
    {button_status_badge(element), "configure_button"}
  end

  defp element_status(%{type: :selector} = element) do
    {selector_status_badge(element), "configure_selector"}
  end

  defp element_status(_element) do
    {[{:muted, "Unknown"}], nil}
  end

  defp lever_status_badge(element) do
    lever_config = get_lever_config(element)
    input_binding = get_input_binding(lever_config)
    has_input_ranges = has_notch_input_ranges?(lever_config)

    cond do
      has_input_ranges -> [{:ok, "Ready"}]
      input_binding -> [{:warn, "Needs mapping"}]
      lever_config -> [{:warn, "Needs input"}]
      true -> [{:muted, "Not configured"}]
    end
  end

  defp button_status_badge(element) do
    button_binding = get_button_binding(element)

    cond do
      button_binding && button_fully_configured?(button_binding) -> [{:ok, "Ready"}]
      button_binding -> [{:warn, "Partial"}]
      true -> [{:muted, "Not configured"}]
    end
  end

  defp selector_status_badge(%Element{selector_binding: %SelectorBinding{enabled: false}}),
    do: [{:muted, "Disabled"}]

  defp selector_status_badge(%Element{selector_binding: %SelectorBinding{}}), do: [{:ok, "Ready"}]
  defp selector_status_badge(_element), do: [{:muted, "Not configured"}]

  defp element_type_icon(:lever), do: "hero-adjustments-vertical"
  defp element_type_icon(:button), do: "hero-cursor-arrow-rays"
  defp element_type_icon(:selector), do: "hero-queue-list"
  defp element_type_icon(_), do: "hero-cube"

  defp button_fully_configured?(%{mode: :sequence} = binding) do
    binding.on_sequence_id != nil or binding.off_sequence_id != nil
  end

  defp button_fully_configured?(%{mode: :keystroke} = binding) do
    binding.keystroke != nil and binding.keystroke != ""
  end

  defp button_fully_configured?(binding) do
    binding.endpoint != nil
  end

  defp get_lever_config(%Element{lever_config: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_lever_config(%Element{lever_config: config}), do: config

  defp get_input_binding(nil), do: nil
  defp get_input_binding(%LeverConfig{input_binding: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_input_binding(%LeverConfig{input_binding: nil}), do: nil

  defp get_input_binding(%LeverConfig{
         input_binding: %LeverInputBinding{input: %Ecto.Association.NotLoaded{}}
       }),
       do: nil

  defp get_input_binding(%LeverConfig{input_binding: binding}), do: binding

  defp has_notch_input_ranges?(nil), do: false

  defp has_notch_input_ranges?(%LeverConfig{notches: notches}) when is_list(notches) do
    Enum.any?(notches, fn notch ->
      notch.input_min != nil and notch.input_max != nil
    end)
  end

  defp has_notch_input_ranges?(_), do: false

  defp get_button_binding(%Element{button_binding: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_button_binding(%Element{button_binding: nil}), do: nil
  defp get_button_binding(%Element{button_binding: binding}), do: binding

  attr :form, :map, required: true

  def add_element_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_element_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-xl font-semibold mb-4">Add element</h2>

        <.form
          id="add-element-form"
          for={@form}
          phx-change="validate_element"
          phx-submit="add_element"
        >
          <div class="space-y-4">
            <div>
              <.input
                label="Element name"
                field={@form[:name]}
                type="text"
                placeholder="e.g., Throttle, Reverser"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <.input
                label="Type"
                field={@form[:type]}
                type="select"
                options={[{"Lever", :lever}, {"Button", :button}, {"Selector", :selector}]}
                class="select select-bordered w-full"
              />
              <p class="text-xs text-muted mt-1">
                Lever for analog inputs, Button for digital inputs, Selector for a potentiometer with fixed positions
              </p>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_element_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add element
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
