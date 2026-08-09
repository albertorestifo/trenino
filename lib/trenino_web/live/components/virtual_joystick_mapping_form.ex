defmodule TreninoWeb.Live.Components.VirtualJoystickMappingForm do
  @moduledoc false
  use TreninoWeb, :html

  attr :kind, :atom, required: true
  attr :inputs, :list, required: true
  attr :mapping, :any, default: nil
  attr :preview, :string, default: nil
  attr :selected_input_id, :integer, default: nil
  attr :transitioning, :boolean, default: false

  def mapping_form(assigns) do
    assigns = assign(assigns, :axes, axis_options())

    ~H"""
    <div
      class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mapping-title"
      phx-window-keydown="cancel-dialog"
      phx-key="Escape"
      phx-mounted={JS.push_focus() |> JS.focus_first()}
      phx-remove={JS.pop_focus()}
    >
      <.focus_wrap
        id="mapping-dialog-focus"
        class="w-full max-w-md rounded-xl border border-base-300 bg-base-100 p-6 shadow-xl"
      >
        <h2 id="mapping-title" tabindex="-1" class="text-lg font-semibold">
          {if @mapping, do: "Edit mapping", else: "Add mapping"}
        </h2>
        <form
          id="virtual-joystick-mapping-form"
          phx-submit="save-mapping"
          phx-change="select-mapping-input"
          data-testid="mapping-form"
          class="mt-5 space-y-4"
        >
          <input :if={@mapping} type="hidden" name="mapping[id]" value={@mapping.id} />
          <input type="hidden" name="mapping[target_type]" value={@kind} />
          <label class="block">
            <span class="text-sm font-medium">Hardware input</span>
            <input :if={@mapping} type="hidden" name="mapping[input_id]" value={@mapping.input_id} />
            <select
              name={if @mapping, do: nil, else: "mapping[input_id]"}
              class="select select-bordered mt-1 w-full"
              required
              disabled={not is_nil(@mapping) or @transitioning}
            >
              <option
                :for={input <- @inputs}
                value={input.id}
                selected={@selected_input_id == input.id}
              >
                {input.device.name} · {input.name || "Pin #{input.pin}"}
              </option>
            </select>
          </label>
          <label :if={@kind == :axis} class="block">
            <span class="text-sm font-medium">Joystick axis</span>
            <select name="mapping[axis]" class="select select-bordered mt-1 w-full" required>
              <option
                :for={{label, value} <- @axes}
                data-testid="axis-target-option"
                value={value}
                selected={@mapping && to_string(@mapping.axis) == value}
              >
                {label}
              </option>
            </select>
          </label>
          <label :if={@kind == :button} class="block">
            <span class="text-sm font-medium">Joystick button</span>
            <select name="mapping[button]" class="select select-bordered mt-1 w-full" required>
              <option
                :for={number <- 1..32}
                value={number}
                selected={@mapping && @mapping.button == number}
              >
                Button {number}
              </option>
            </select>
          </label>
          <label :if={@kind == :axis} class="flex min-h-11 items-center gap-3">
            <input type="hidden" name="mapping[inverted]" value="false" />
            <input
              type="checkbox"
              name="mapping[inverted]"
              value="true"
              checked={@mapping && @mapping.inverted}
              class="checkbox"
            />
            <span>Invert direction</span>
          </label>
          <p data-testid="input-preview" class="text-sm text-base-content/70">
            Live input: {if is_binary(@preview),
              do: @preview,
              else: "Move the control to preview it"}
          </p>
          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              phx-click="cancel-mapping"
              data-testid="cancel-mapping"
              class="btn btn-ghost"
            >Cancel</button>
            <button type="submit" disabled={@transitioning} class="btn btn-primary">Save mapping</button>
          </div>
        </form>
      </.focus_wrap>
    </div>
    """
  end

  defp axis_options do
    [
      {"X", "x"},
      {"Y", "y"},
      {"Z", "z"},
      {"Rx", "rx"},
      {"Ry", "ry"},
      {"Rz", "rz"},
      {"Slider 1", "slider_1"},
      {"Slider 2", "slider_2"}
    ]
  end
end
