defmodule TreninoWeb.ConfigurationEditLive.Modals do
  @moduledoc """
  Function components for the modals of the configuration edit page
  (`TreninoWeb.ConfigurationEditLive`).

  Events are handled by the LiveView; these components only render markup.
  """

  use TreninoWeb, :html

  alias Trenino.Hardware.Matrix

  attr :form, :map, required: true

  def add_input_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_input_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl w-full max-w-md mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-semibold mb-4">Add input</h2>

        <.form id="add-input-form" for={@form} phx-change="validate_input" phx-submit="add_input">
          <div class="space-y-4">
            <div>
              <.input
                label="Name (optional)"
                field={@form[:name]}
                type="text"
                placeholder="e.g., Horn Button, Throttle"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <.input
                label="Input type"
                field={@form[:input_type]}
                type="select"
                options={[{"Analog", :analog}, {"Button", :button}]}
                class="select select-bordered w-full"
              />
            </div>

            <div>
              <.input
                label="Pin number"
                field={@form[:pin]}
                type="number"
                placeholder="Enter pin number (0-254)"
                min="0"
                max="254"
                class="input input-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value in [:analog, "analog"]}>
              <.input
                label="Sensitivity (1-10)"
                field={@form[:sensitivity]}
                type="number"
                min="1"
                max="10"
                class="input input-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value in [:button, "button"]}>
              <.input
                label="Debounce (0-255 ms)"
                field={@form[:debounce]}
                type="number"
                min="0"
                max="255"
                placeholder="20"
                class="input input-bordered w-full"
              />
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_input_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add input
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :matrix_row_pins_input, :string, required: true
  attr :matrix_col_pins_input, :string, required: true
  attr :matrix_errors, :map, required: true

  def add_matrix_modal(assigns) do
    row_pins = Matrix.parse_pins(assigns.matrix_row_pins_input)
    col_pins = Matrix.parse_pins(assigns.matrix_col_pins_input)
    num_rows = length(row_pins)
    num_cols = length(col_pins)
    total_buttons = num_rows * num_cols

    assigns =
      assigns
      |> assign(:num_rows, num_rows)
      |> assign(:num_cols, num_cols)
      |> assign(:total_buttons, total_buttons)
      |> assign(:row_pins, row_pins)
      |> assign(:col_pins, col_pins)

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_matrix_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl w-full max-w-md mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-semibold mb-4">Add matrix</h2>

        <form
          id="add-matrix-form"
          phx-change="validate_matrix_pins"
          phx-submit="add_matrix"
          class="space-y-4"
        >
          <div class="bg-base-100 rounded-lg p-4">
            <p class="text-sm text-muted mb-3">
              Enter GPIO pin numbers for rows and columns, separated by commas.
            </p>

            <div class="space-y-3">
              <div>
                <label for="matrix-row-pins" class="label py-1">
                  <span class="label-text text-sm">Row pins</span>
                </label>
                <input
                  id="matrix-row-pins"
                  type="text"
                  name="row_pins"
                  value={@matrix_row_pins_input}
                  placeholder="e.g., 2, 3, 4, 5"
                  phx-debounce="300"
                  class={[
                    "input input-bordered input-sm w-full",
                    @matrix_errors[:row_pins] && "input-error"
                  ]}
                />
                <p :if={@matrix_errors[:row_pins]} class="text-error text-xs mt-1">
                  {@matrix_errors[:row_pins]}
                </p>
              </div>

              <div>
                <label for="matrix-col-pins" class="label py-1">
                  <span class="label-text text-sm">Column pins</span>
                </label>
                <input
                  id="matrix-col-pins"
                  type="text"
                  name="col_pins"
                  value={@matrix_col_pins_input}
                  placeholder="e.g., 8, 9, 10"
                  phx-debounce="300"
                  class={[
                    "input input-bordered input-sm w-full",
                    @matrix_errors[:col_pins] && "input-error"
                  ]}
                />
                <p :if={@matrix_errors[:col_pins]} class="text-error text-xs mt-1">
                  {@matrix_errors[:col_pins]}
                </p>
              </div>

              <p :if={@matrix_errors[:general]} class="text-error text-sm">
                {@matrix_errors[:general]}
              </p>
            </div>
          </div>

          <%!-- Grid Preview --%>
          <div :if={@num_rows > 0 and @num_cols > 0} class="bg-base-100 rounded-lg p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-sm font-medium">Grid Preview</span>
              <span class="badge badge-ghost badge-sm font-mono">
                {@num_rows}x{@num_cols} = {@total_buttons} buttons
              </span>
            </div>

            <div class="overflow-x-auto">
              <table class="text-xs">
                <thead>
                  <tr>
                    <th class="p-1"></th>
                    <th
                      :for={{col_pin, col_idx} <- Enum.with_index(@col_pins)}
                      class="p-1 text-center font-mono text-muted"
                    >
                      C{col_idx}<br /><span class="text-xs">({col_pin})</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{row_pin, row_idx} <- Enum.with_index(@row_pins)}>
                    <td class="p-1 font-mono text-muted">
                      R{row_idx} <span class="text-xs">({row_pin})</span>
                    </td>
                    <td :for={{_col_pin, col_idx} <- Enum.with_index(@col_pins)} class="p-1">
                      <div class="w-9 h-7 bg-base-300 rounded flex items-center justify-center text-xs font-mono">
                        {128 + row_idx * @num_cols + col_idx}
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="text-xs text-muted mt-2">
              Virtual pin = 128 + (row x cols + col)
            </p>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_matrix_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add matrix
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :form, :map, required: true

  def add_output_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_output_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-xl font-semibold mb-4">Add output</h2>

        <.form id="add-output-form" for={@form} phx-change="validate_output" phx-submit="add_output">
          <div class="space-y-4">
            <div>
              <.input
                label="Pin number"
                field={@form[:pin]}
                type="number"
                placeholder="Enter pin number (0-255)"
                min="0"
                max="255"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <.input
                label="Name (optional)"
                field={@form[:name]}
                type="text"
                placeholder="e.g., Brake Warning LED"
                class="input input-bordered w-full"
              />
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_output_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add output
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :device, :map, required: true
  attr :connected_devices, :list, required: true
  attr :allcall_warning, :string, default: nil

  def apply_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_apply_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl max-w-md w-full p-6">
        <h2 class="text-xl font-semibold mb-4">Apply configuration</h2>
        <p class="text-sm text-muted mb-6">
          Select a device to apply "<span class="font-medium">{@device.name}</span>" to:
        </p>

        <div
          :if={@allcall_warning}
          id="apply-allcall-warning"
          role="alert"
          class="alert alert-soft alert-warning text-sm mb-4"
        >
          <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
          <p>{@allcall_warning}</p>
        </div>

        <div class="space-y-2">
          <button
            :for={device <- @connected_devices}
            type="button"
            phx-click="apply_to_device"
            phx-value-port={device.port}
            class="w-full flex items-center gap-3 p-3 rounded-lg border border-base-300 hover:bg-base-300 transition-colors text-left"
          >
            <div class="min-w-0 flex-1">
              <p class="font-medium font-mono truncate">{device.port}</p>
              <p :if={device.device_version} class="text-xs text-muted font-mono">
                v{device.device_version}
              </p>
            </div>
            <span class="flex items-center gap-1 text-xs text-success">
              <.icon name="hero-check-circle-mini" class="size-4" /> Connected
            </span>
          </button>
        </div>

        <div class="mt-6 flex justify-end">
          <button type="button" phx-click="close_apply_modal" class="btn btn-ghost">
            Cancel
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :device, :map, required: true
  attr :active, :boolean, required: true

  def delete_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_delete_modal" />
      <div class="relative bg-base-200 rounded-xl shadow-xl max-w-md w-full p-6">
        <h2 class="text-xl font-semibold mb-4 text-error">Delete configuration</h2>

        <div :if={@active} class="alert alert-soft alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-sm">This configuration is currently active on a connected device.</span>
        </div>

        <p class="text-sm text-muted mb-6">
          Are you sure you want to delete "<span class="font-medium">{@device.name}</span>"?
          This will permanently delete the configuration and all its inputs and calibration data.
        </p>

        <div class="flex justify-end gap-2">
          <button type="button" phx-click="close_delete_modal" class="btn btn-ghost">
            Cancel
          </button>
          <button
            :if={not @active}
            type="button"
            phx-click="confirm_delete"
            class="btn btn-error"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :i2c_modal_module, :map, default: nil
  attr :device_id, :integer, required: true

  def i2c_display_modal(assigns) do
    ~H"""
    <div
      id="i2c-display-dialog"
      class="modal modal-open"
      role="dialog"
      aria-modal="true"
      aria-labelledby="i2c-display-title"
      phx-window-keydown="close_i2c_modal"
      phx-key="Escape"
      phx-mounted={
        JS.push_focus(
          to: if(@i2c_modal_module, do: "#edit-display-#{@i2c_modal_module.id}", else: "#add-display")
        )
        |> JS.focus(to: "#i2c-display-title")
      }
      phx-remove={JS.pop_focus()}
    >
      <.focus_wrap id="i2c-display-focus" class="modal-box bg-base-200">
        <h2 id="i2c-display-title" class="text-xl font-semibold mb-4" tabindex="-1">
          {if @i2c_modal_module, do: "Edit display", else: "Add display"}
        </h2>
        <.live_component
          module={TreninoWeb.I2cModuleFormComponent}
          id="i2c-module-form"
          i2c_module={@i2c_modal_module}
          device_id={@device_id}
        />
      </.focus_wrap>
      <div class="modal-backdrop" phx-click="close_i2c_modal" aria-hidden="true" />
    </div>
    """
  end
end
