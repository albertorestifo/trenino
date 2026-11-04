defmodule TreninoWeb.ConfigurationEditLive.Sections do
  @moduledoc """
  Function components for the page header and the sections of the
  configuration edit page (`TreninoWeb.ConfigurationEditLive`).

  Events are handled by the LiveView; these components only render markup.
  """

  use TreninoWeb, :html

  import TreninoWeb.SharedComponents

  alias Trenino.Hardware
  alias Trenino.Hardware.{I2cModule, Input, Matrix, Output}

  attr :device, :map, required: true
  attr :device_form, :map, required: true
  attr :active_port, :string, default: nil
  attr :new_mode, :boolean, required: true
  attr :can_apply, :boolean, required: true
  attr :has_parts, :boolean, required: true
  attr :device_connected, :boolean, required: true
  attr :apply_needed, :boolean, required: true
  attr :apply_unknown, :boolean, default: false
  attr :applying, :boolean, required: true

  def device_header(assigns) do
    ~H"""
    <header>
      <h1 class="text-2xl font-semibold mb-4">
        {if @new_mode, do: "New configuration", else: "Edit configuration"}
      </h1>
      <.form id="device-form" for={@device_form} phx-change="validate_device">
        <div>
          <.input
            label="Configuration name"
            field={@device_form[:name]}
            type="text"
            class="input input-bordered w-full text-lg font-semibold"
            placeholder="e.g., Arduino Mega Controller"
          />
        </div>
        <div class="mt-3">
          <.input
            label="Description"
            field={@device_form[:description]}
            type="textarea"
            class="textarea textarea-bordered w-full resize-none"
            placeholder="Add a description (optional)"
            rows="2"
          />
        </div>
        <div class="flex items-center gap-3 mt-4">
          <span class="text-xs text-muted font-mono">ID: {@device.config_id}</span>
          <.status_chip :if={@active_port} kind={:ok} label="Active" />
          <div class="ml-auto flex items-center gap-2">
            <button
              :if={@can_apply}
              type="button"
              phx-click="show_apply_modal"
              disabled={@applying}
              class="btn btn-outline btn-sm"
            >
              <.icon :if={@applying} name="hero-arrow-path" class="w-4 h-4 motion-safe:animate-spin" />
              <.icon :if={!@applying} name="hero-play" class="w-4 h-4" />
              {if @applying, do: "Applying...", else: "Apply to device"}
            </button>
          </div>
        </div>
        <p
          :if={not @can_apply and not @new_mode}
          id="apply-unavailable-reason"
          class="mt-2 text-xs text-muted"
        >
          {apply_unavailable_reason(@has_parts, @device_connected)}
        </p>
      </.form>
      <div
        :if={@apply_needed and not @new_mode}
        id="apply-needed-banner"
        role="status"
        class="mt-4 rounded-lg border border-warning/40 bg-warning/10 p-3 text-sm"
      >
        <%= if @apply_unknown do %>
          <strong>Not confirmed on the device.</strong>
          Trenino has no record of this configuration being applied, so it cannot tell whether
          the device matches. {if @can_apply,
            do: "Click Apply to device to be sure.",
            else: "Connect the device, then click Apply to device to be sure."}
        <% else %>
          <strong>Apply needed.</strong>
          Saved changes are not on the device yet. {if @can_apply,
            do: "Click Apply to device to send them.",
            else: "Connect the device, then click Apply to device."}
        <% end %>
      </div>
    </header>
    """
  end

  defp apply_unavailable_reason(false, _),
    do: "Apply is unavailable: add at least one input, matrix, display or gauge first."

  defp apply_unavailable_reason(true, false),
    do:
      "Apply is unavailable: no device is connected. Plug in the controller; Apply appears once it is connected."

  defp apply_unavailable_reason(_, _), do: ""

  attr :inputs, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  def inputs_section(assigns) do
    ~H"""
    <.config_section
      id="inputs"
      title="Inputs"
      count={length(@inputs)}
      empty?={@inputs == []}
      empty_icon="hero-plus-circle"
      empty_message="No inputs configured"
      empty_hint="Add your first input to get started."
    >
      <:actions>
        <.section_action id="add-input" label="Add input" on_click="open_add_input_modal" />
      </:actions>
      <.inputs_table inputs={@inputs} input_values={@input_values} active_port={@active_port} />
    </.config_section>
    """
  end

  attr :inputs, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  defp inputs_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th class="text-center">Pin</th>
            <th>Name</th>
            <th>Type</th>
            <th>Value</th>
            <th class="text-right"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={input <- @inputs} class="hover:bg-base-200/50">
            <td class="text-center font-mono">{input.pin}</td>
            <td>
              <input
                type="text"
                value={input.name || ""}
                placeholder="Unnamed"
                aria-label={"Name for input on pin #{input.pin}"}
                phx-blur="update_input_name"
                phx-value-id={input.id}
                class="input input-ghost input-xs w-full max-w-32 placeholder:text-muted"
              />
            </td>
            <td>
              <span class="badge badge-ghost badge-sm capitalize">
                {input.input_type}
              </span>
            </td>
            <td class="min-w-24">
              <.input_value
                raw_value={Map.get(@input_values, input.pin)}
                calibration={input.calibration}
                active={@active_port != nil}
                input_type={input.input_type}
              />
            </td>
            <td>
              <.row_actions id={"input-actions-#{input.id}"} name={input_name(input)}>
                <:action
                  :if={@active_port != nil && input.input_type == :analog}
                  event="start_calibration"
                  values={%{id: input.id}}
                  icon="hero-adjustments-horizontal"
                  label="Calibrate"
                />
                <:action
                  event="delete_input"
                  values={%{id: input.id}}
                  kind={:danger}
                  label={"Delete #{input_name(input)}"}
                  confirm={"Delete #{input_name(input)}?"}
                />
              </.row_actions>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # Matrices section

  attr :matrices, :list, required: true
  attr :active_port, :string, default: nil

  def matrices_section(assigns) do
    ~H"""
    <.config_section
      id="matrices"
      title="Matrices"
      count={length(@matrices)}
      empty?={@matrices == []}
      empty_icon="hero-squares-2x2"
      empty_message="No matrices configured"
      empty_hint="Add a button matrix for multiple buttons using fewer pins."
    >
      <:actions>
        <.section_action id="add-matrix" label="Add matrix" on_click="open_add_matrix_modal" />
      </:actions>
      <.matrices_table matrices={@matrices} active_port={@active_port} />
    </.config_section>
    """
  end

  attr :matrices, :list, required: true
  attr :active_port, :string, default: nil

  defp matrices_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th>Name</th>
            <th>Size</th>
            <th>Buttons</th>
            <th class="text-right"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={matrix <- @matrices} class="hover:bg-base-200/50">
            <td>
              <input
                type="text"
                value={matrix.name || ""}
                placeholder="Unnamed"
                aria-label={"Name for #{length(matrix.row_pins)}x#{length(matrix.col_pins)} matrix"}
                phx-blur="update_matrix_name"
                phx-value-id={matrix.id}
                class="input input-ghost input-xs w-full max-w-32 font-medium placeholder:text-muted placeholder:font-normal"
              />
            </td>
            <td class="font-mono text-sm">
              {length(matrix.row_pins)}x{length(matrix.col_pins)}
            </td>
            <td class="font-mono text-sm">
              {length(matrix.buttons)} buttons
            </td>
            <td>
              <.row_actions id={"matrix-actions-#{matrix.id}"} name={matrix_name(matrix)}>
                <:action
                  :if={@active_port != nil}
                  event="start_matrix_test"
                  values={%{id: matrix.id}}
                  icon="hero-squares-2x2"
                  label="Test"
                />
                <:action
                  event="delete_matrix"
                  values={%{id: matrix.id}}
                  kind={:danger}
                  label={"Delete #{matrix_name(matrix)}"}
                  confirm={"Delete #{matrix_name(matrix)}? Its buttons are removed too."}
                />
              </.row_actions>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :raw_value, :integer, default: nil
  attr :calibration, :map, default: nil
  attr :active, :boolean, required: true
  attr :input_type, :atom, default: :analog

  defp input_value(assigns) do
    calibration = loaded_calibration(assigns.calibration)

    calibrated =
      if assigns.raw_value && calibration do
        Hardware.normalize_value(assigns.raw_value, calibration)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:calibration, calibration)
      |> assign(:calibrated, calibrated)

    ~H"""
    <%!-- Not active --%>
    <span :if={!@active} class="text-muted text-sm">
      <.icon name="hero-lock-closed" class="w-3 h-3 inline mr-1" /> N/A
    </span>
    <%!-- Button inputs --%>
    <span :if={@active && @input_type == :button && is_nil(@raw_value)} class="text-muted">
      &mdash;
    </span>
    <span
      :if={@active && @input_type == :button && @raw_value == 1}
      class="badge badge-soft badge-success badge-xs"
    >
      Pressed
    </span>
    <span
      :if={@active && @input_type == :button && @raw_value == 0}
      class="badge badge-ghost badge-xs"
    >
      Released
    </span>
    <%!-- Analog inputs --%>
    <span
      :if={@active && @input_type == :analog && is_nil(@raw_value)}
      class="text-muted"
    >
      &mdash;
    </span>
    <span
      :if={@active && @input_type == :analog && !is_nil(@raw_value)}
      class="font-mono tabular-nums"
    >
      <span class="text-muted text-xs">{@raw_value}</span>
      <span :if={@calibrated} class="text-muted text-xs">/</span>
      <span :if={@calibrated}>{@calibrated}</span>
      <span :if={is_nil(@calibration)} class="text-muted text-xs ml-1">
        (uncalibrated)
      </span>
    </span>
    """
  end

  defp loaded_calibration(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded_calibration(nil), do: nil
  defp loaded_calibration(calibration), do: calibration

  attr :outputs, :list, required: true
  attr :active_port, :string, default: nil
  attr :output_states, :map, default: %{}

  def outputs_section(assigns) do
    ~H"""
    <.config_section
      id="outputs"
      title="Outputs"
      count={length(@outputs)}
      empty?={@outputs == []}
      empty_icon="hero-light-bulb"
      empty_message="No outputs configured"
      empty_hint="Add LEDs or indicators to control."
    >
      <:actions>
        <.section_action id="add-output" label="Add output" on_click="open_add_output_modal" />
      </:actions>
      <.outputs_table outputs={@outputs} active_port={@active_port} output_states={@output_states} />
    </.config_section>
    """
  end

  attr :outputs, :list, required: true
  attr :active_port, :string, default: nil
  attr :output_states, :map, default: %{}

  defp outputs_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th class="text-center">Pin</th>
            <th>Name</th>
            <th :if={@active_port} class="text-center">Test</th>
            <th class="text-right"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={output <- @outputs} class="hover:bg-base-200/50">
            <td class="text-center font-mono">{output.pin}</td>
            <td>
              <input
                type="text"
                value={output.name || ""}
                placeholder="Unnamed"
                aria-label={"Name for output on pin #{output.pin}"}
                phx-blur="update_output_name"
                phx-value-id={output.id}
                class="input input-ghost input-xs w-full max-w-40 placeholder:text-muted"
              />
            </td>
            <td :if={@active_port} class="text-center">
              <button
                type="button"
                phx-click="toggle_output"
                phx-value-id={output.id}
                aria-label={"Test #{output_name(output)}"}
                aria-pressed={to_string(Map.get(@output_states, output.id, false))}
                class={[
                  "btn btn-xs text-xs",
                  if(Map.get(@output_states, output.id, false),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
                title={if Map.get(@output_states, output.id, false), do: "Turn off", else: "Turn on"}
              >
                <.icon
                  name={
                    if Map.get(@output_states, output.id, false),
                      do: "hero-bolt-solid",
                      else: "hero-bolt"
                  }
                  class="w-3 h-3"
                />
                <span class="text-xs">
                  {if Map.get(@output_states, output.id, false), do: "ON", else: "OFF"}
                </span>
              </button>
            </td>
            <td>
              <.row_actions id={"output-actions-#{output.id}"} name={output_name(output)}>
                <:action
                  event="delete_output"
                  values={%{id: output.id}}
                  kind={:danger}
                  label={"Delete #{output_name(output)}"}
                  confirm={"Delete #{output_name(output)}?"}
                />
              </.row_actions>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  The Gauges section shown while a new configuration is not saved yet.

  The real section is `TreninoWeb.StepperAxisFormComponent`, which needs a saved
  device. Until then this shows the same header with a disabled "Add gauge" and the
  reason, matching the Displays section next to it.
  """
  def new_gauges_section(assigns) do
    ~H"""
    <.config_section
      id="stepper-axes"
      title="Gauges"
      description="Stepper-motor gauges driven by the motor shield."
      empty?
      empty_icon="hero-cog-6-tooth"
      empty_message="No gauges configured"
      empty_hint="Drive a gauge needle from the sim with a stepper motor. Needs controller firmware 3.1.0 or newer."
    >
      <:actions>
        <.section_action
          id="stepper-add"
          label="Add gauge"
          disabled
          disabled_reason="Name the configuration first to add a gauge."
        />
      </:actions>
    </.config_section>
    """
  end

  attr :i2c_modules, :list, required: true
  attr :new_mode, :boolean, required: true
  attr :active_port, :string, default: nil

  def i2c_modules_section(assigns) do
    ~H"""
    <.config_section
      id="displays"
      title="Displays"
      count={length(@i2c_modules)}
      empty?={@i2c_modules == []}
      empty_icon="hero-calculator"
      empty_message="No displays configured"
      empty_hint="Add a display to show simulator values."
    >
      <:actions>
        <.section_action
          id="add-display"
          label="Add display"
          on_click="open_add_i2c_modal"
          disabled={@new_mode}
          disabled_reason="Name the configuration first to add a display."
        />
      </:actions>
      <div class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Chip</th>
              <th>Address</th>
              <th>Digits</th>
              <th>Brightness</th>
              <th class="text-right"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={mod <- @i2c_modules} class="hover:bg-base-200/50">
              <td>
                <span :if={mod.name not in [nil, ""]}>{mod.name}</span>
                <span :if={mod.name in [nil, ""]} class="text-muted">Unnamed</span>
              </td>
              <td class="uppercase text-xs">{mod.module_chip}</td>
              <td class="font-mono">{I2cModule.format_i2c_address(mod.i2c_address)}</td>
              <td class="tabular-nums">{mod.params.num_digits}</td>
              <td class="tabular-nums">{round(mod.params.brightness * 100 / 15)}%</td>
              <td>
                <.row_actions id={"display-actions-#{mod.id}"} name={display_name(mod)}>
                  <:action
                    :if={@active_port}
                    id={"test-display-#{mod.id}"}
                    event="test_display"
                    values={%{id: mod.id}}
                    icon="hero-play"
                    label="Test"
                  />
                  <:action
                    id={"edit-display-#{mod.id}"}
                    event="open_edit_i2c_modal"
                    values={%{id: mod.id}}
                    icon="hero-pencil-square"
                    label="Edit"
                  />
                  <:action
                    id={"delete-display-#{mod.id}"}
                    event="delete_i2c_module"
                    values={%{id: mod.id}}
                    kind={:danger}
                    label={"Delete #{display_name(mod)}"}
                    confirm={"Delete #{display_name(mod)}?"}
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

  defp input_name(%Input{} = input), do: input.name || "input on pin #{input.pin}"
  defp matrix_name(%Matrix{} = matrix), do: matrix.name || "unnamed matrix"
  defp output_name(%Output{} = output), do: output.name || "output on pin #{output.pin}"

  defp display_name(%I2cModule{} = mod),
    do: mod.name || "display at #{I2cModule.format_i2c_address(mod.i2c_address)}"
end
