defmodule TreninoWeb.DisplayBindingWizard do
  @moduledoc """
  Wizard for creating/editing a display binding.

  Steps:
  1. :select_endpoint  — pick simulator endpoint via ApiExplorerComponent
  2. :select_module    — pick i2c module from list
  3. :configure        — set format_string and name, preview, save
  """

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Train
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayController
  alias Trenino.Train.DisplayFormatter

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
        i2c_modules = Hardware.list_all_i2c_modules()

        socket
        |> assign(:i2c_modules, i2c_modules)
        |> initialize_wizard(assigns[:binding])
      end

    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, handle_explorer_event(assigns, socket)}
  end

  defp handle_explorer_event(%{explorer_event: {:select, _field, path}}, socket) do
    socket |> assign(:endpoint, path) |> assign(:wizard_step, :select_module)
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), :display_binding_cancelled)
    socket
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, nil) do
    socket
    |> assign(:wizard_step, :select_endpoint)
    |> assign(:endpoint, nil)
    |> assign(:selected_module_id, nil)
    |> assign(:format_string, "{value}")
    |> assign(:name, "")
    |> assign(:initialized, true)
  end

  defp initialize_wizard(socket, %DisplayBinding{} = binding) do
    socket
    |> assign(:wizard_step, :configure)
    |> assign(:endpoint, binding.endpoint)
    |> assign(:selected_module_id, binding.i2c_module_id)
    |> assign(:format_string, binding.format_string)
    |> assign(:name, binding.name || "")
    |> assign(:initialized, true)
  end

  @impl true
  def handle_event("select_module", %{"module-id" => id_str}, socket) do
    {:noreply,
     socket
     |> assign(:selected_module_id, String.to_integer(id_str))
     |> assign(:wizard_step, :configure)}
  end

  def handle_event("update_config", params, socket) do
    socket =
      socket
      |> maybe_assign(:format_string, params, "format_string")
      |> maybe_assign(:name, params, "name")

    {:noreply, socket}
  end

  def handle_event("back", _params, socket) do
    prev =
      case socket.assigns.wizard_step do
        :select_module -> :select_endpoint
        :configure -> :select_module
        _ -> :select_endpoint
      end

    {:noreply, assign(socket, :wizard_step, prev)}
  end

  def handle_event("save", _params, socket) do
    case save_binding(socket) do
      {:ok, binding} ->
        DisplayController.reload_bindings()
        send(self(), {:display_binding_saved, binding})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :display_binding_cancelled)
    {:noreply, socket}
  end

  defp maybe_assign(socket, key, params, param_key) do
    case Map.get(params, param_key) do
      nil -> socket
      val -> assign(socket, key, val)
    end
  end

  defp save_binding(socket) do
    %{
      train_id: train_id,
      binding: existing,
      endpoint: endpoint,
      selected_module_id: i2c_module_id,
      format_string: format_string,
      name: name
    } = socket.assigns

    params = %{
      i2c_module_id: i2c_module_id,
      endpoint: endpoint,
      format_string: format_string,
      name: name
    }

    case existing do
      nil -> Train.create_display_binding(train_id, params)
      b -> Train.update_display_binding(b, params)
    end
  end

  defp selected_module(assigns) do
    Enum.find(assigns.i2c_modules, &(&1.id == assigns.selected_module_id))
  end

  defp format_preview(format_string) do
    DisplayFormatter.format(format_string, 42.5)
  end

  defp can_save?(assigns) do
    assigns.endpoint != nil and
      assigns.selected_module_id != nil and
      assigns.format_string != "" and
      assigns.name != ""
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {f, msgs} -> "#{f}: #{Enum.join(msgs, ", ")}" end)
  end

  defp format_errors(_), do: "An error occurred"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected_module, selected_module(assigns))

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">
                {if @binding, do: "Edit Display Binding", else: "Add Display Binding"}
              </h2>
              <p class="text-sm text-base-content/60">Show a simulator value on an I2C display</p>
            </div>
            <button phx-click="cancel" phx-target={@myself} class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <div class="flex items-center gap-2 mt-4">
            <.step_indicator
              step={1}
              label="Endpoint"
              active={@wizard_step == :select_endpoint}
              completed={@wizard_step in [:select_module, :configure]}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={2}
              label="Display"
              active={@wizard_step == :select_module}
              completed={@wizard_step == :configure}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator step={3} label="Format" active={@wizard_step == :configure} />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :select_endpoint} class="flex-1 flex flex-col">
            <.live_component
              module={TreninoWeb.ApiExplorerComponent}
              id="display-wizard-api-explorer"
              field={:endpoint}
              client={@client}
              mode={:none}
              embedded={true}
            />
          </div>

          <div :if={@wizard_step == :select_module} class="flex-1 p-6 overflow-y-auto space-y-4">
            <h3 class="text-xl font-semibold">Select Display</h3>
            <div :if={Enum.empty?(@i2c_modules)} class="alert alert-warning">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
              <span>No I2C modules configured. Add one to a device configuration first.</span>
            </div>
            <div :if={not Enum.empty?(@i2c_modules)} class="space-y-2">
              <button
                :for={mod <- @i2c_modules}
                type="button"
                phx-click="select_module"
                phx-value-module-id={mod.id}
                phx-target={@myself}
                class={[
                  "w-full p-4 rounded-lg border-2 text-left transition-all",
                  @selected_module_id == mod.id && "border-primary bg-primary/10",
                  @selected_module_id != mod.id && "border-base-300 hover:border-primary/50"
                ]}
              >
                <p class="font-medium">
                  {mod.name ||
                    "Module at #{Trenino.Hardware.I2cModule.format_i2c_address(mod.i2c_address)}"}
                </p>
                <p class="text-xs text-base-content/60">
                  {mod.device.name} · {mod.module_chip} · {mod.params.num_digits} digits · addr {Trenino.Hardware.I2cModule.format_i2c_address(
                    mod.i2c_address
                  )}
                </p>
              </button>
            </div>
            <div class="flex justify-between pt-4 border-t border-base-300">
              <button phx-click="back" phx-target={@myself} class="btn btn-ghost">
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
              </button>
            </div>
          </div>

          <div :if={@wizard_step == :configure} class="flex-1 p-6 overflow-y-auto space-y-6">
            <div class="bg-base-200 rounded-lg p-4 space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-base-content/60">Endpoint:</span>
                <span class="font-mono">{@endpoint}</span>
              </div>
              <div :if={@selected_module} class="flex justify-between">
                <span class="text-base-content/60">Display:</span>
                <span>{@selected_module.name} ({@selected_module.device.name})</span>
              </div>
            </div>

            <form phx-change="update_config" phx-target={@myself} class="space-y-4">
              <div>
                <label class="label"><span class="label-text font-medium">Binding Name</span></label>
                <input
                  type="text"
                  name="name"
                  value={@name}
                  placeholder="e.g. Train speed"
                  class="input input-bordered w-full"
                />
              </div>
              <div>
                <label class="label">
                  <span class="label-text font-medium">Format String</span>
                  <span class="label-text-alt text-base-content/50">
                    {"{value}"} = raw · {"{value:.0f}"} = no decimals · {"{value:.2f}"} = 2 decimals
                  </span>
                </label>
                <input
                  type="text"
                  name="format_string"
                  value={@format_string}
                  placeholder="{value:.0f}"
                  class="input input-bordered w-full font-mono"
                />
              </div>
            </form>

            <div class="bg-base-200 rounded-lg p-4">
              <p class="text-xs text-base-content/50 mb-2">Preview (sample value: 42.5)</p>
              <div class="font-mono text-2xl tracking-widest bg-base-300 rounded px-4 py-3 inline-block min-w-[8ch] text-center">
                {format_preview(@format_string)}
              </div>
            </div>

            <div class="flex justify-between pt-4 border-t border-base-300">
              <button phx-click="back" phx-target={@myself} class="btn btn-ghost">
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
              </button>
              <button
                phx-click="save"
                phx-target={@myself}
                disabled={not can_save?(assigns)}
                class="btn btn-primary"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Save
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :completed, :boolean, default: false

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class={[
        "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
        @active && "bg-primary text-primary-content",
        @completed && "bg-success text-success-content",
        (not @active and not @completed) && "bg-base-300 text-base-content/50"
      ]}>
        <.icon :if={@completed} name="hero-check" class="w-4 h-4" />
        <span :if={not @completed}>{@step}</span>
      </div>
      <span class={[
        "text-sm",
        @active && "font-medium",
        (not @active and not @completed) && "text-base-content/50"
      ]}>
        {@label}
      </span>
    </div>
    """
  end
end
