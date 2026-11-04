defmodule TreninoWeb.StepperAxisFormComponent do
  @moduledoc """
  The Gauges section (stepper axes): one card per axis, the add/edit form and the shared shield
  address. Validation and persistence never issue motion; the guided gauge setup does the
  physical part (zero, direction, dial).
  """
  use TreninoWeb, :live_component

  import TreninoWeb.SharedComponents

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.{StepperAxis, StepperManager}
  alias TreninoWeb.{GaugeFeedback, GaugeGuidance}

  @motor_numbers [
    min_position: "Minimum position (steps)",
    max_position: "Maximum position (steps)",
    max_speed: "Maximum speed (steps/s)",
    acceleration: "Acceleration (steps/s²)"
  ]
  @modes [
    {"X27 gauge motor", :x27_six_state},
    {"Full step", :full_step},
    {"Half step", :half_step}
  ]

  @impl true
  def update(%{wizard_closed: _}, socket) do
    axes = Hardware.list_stepper_axes(socket.assigns.device_id)
    {:ok, assign(socket, wizard_axis_id: nil, axes: axes)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:editing, fn -> nil end)
      |> assign_new(:wizard_axis_id, fn -> nil end)
      |> assign_new(:diagnostics, fn -> MapSet.new() end)
      |> assign_new(:changing_address, fn -> false end)
      |> assign_new(:form, fn -> nil end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:notice, fn -> nil end)
      |> assign_new(:snapshot, fn -> StepperManager.snapshot(assigns.device_id) end)

    {:ok,
     socket
     |> assign(:axes, Hardware.list_stepper_axes(socket.assigns.device_id))
     |> assign(:motor_numbers, @motor_numbers)
     |> assign(:modes, @modes)
     |> assign(:allcall_warning, Hardware.allcall_warning(socket.assigns.device_id))}
  end

  @impl true
  def handle_event(event, _, %{assigns: %{editing: nil}} = socket)
      when event in ["save", "validate"] do
    {:noreply, assign(socket, :error, "Open an axis configuration before continuing.")}
  end

  def handle_event("add", _, socket) do
    port = next_free_port(socket.assigns.axes)

    axis = %StepperAxis{
      device_id: socket.assigns.device_id,
      motor_port: port,
      axis_index: port - 1
    }

    {:noreply, edit(socket, axis)}
  end

  def handle_event("change_address", _, socket),
    do: {:noreply, assign(socket, changing_address: true, error: nil)}

  def handle_event("cancel_address", _, socket),
    do: {:noreply, assign(socket, :changing_address, false)}

  # The panel walks the operator through the shield-alone order before this button, so
  # pressing it is the acknowledgement the backend requires.
  def handle_event("recommission", params, socket) do
    result =
      with address when is_binary(address) <- params["address"],
           {:ok, address} when address in 0x60..0x77 <- I2cModule.parse_i2c_address(address),
           do: StepperManager.recommission_address(socket.assigns.device_id, address, true),
           else: (_ -> :error)

    case result do
      :ok ->
        {:noreply,
         assign(socket,
           changing_address: false,
           error: nil,
           notice: "Shield address changed. Re-zero each gauge.",
           axes: Hardware.list_stepper_axes(socket.assigns.device_id)
         )}

      :error ->
        {:noreply, assign(socket, :error, "Enter a shield address from 0x60 to 0x77.")}

      error ->
        {:noreply, assign(socket, :error, GaugeFeedback.result(error))}
    end
  end

  def handle_event("open_wizard", %{"id" => id}, socket) do
    case own_axis(socket, id) do
      nil ->
        {:noreply, assign(socket, :error, "Axis not found")}

      axis ->
        {:noreply, assign(socket, wizard_axis_id: axis.id, form: nil, editing: nil, error: nil)}
    end
  end

  def handle_event("toggle_diagnostics", %{"id" => id}, socket) do
    case own_axis(socket, id) do
      nil ->
        {:noreply, socket}

      axis ->
        diagnostics = socket.assigns.diagnostics

        diagnostics =
          if MapSet.member?(diagnostics, axis.id),
            do: MapSet.delete(diagnostics, axis.id),
            else: MapSet.put(diagnostics, axis.id)

        {:noreply, assign(socket, :diagnostics, diagnostics)}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case own_axis(socket, id) do
      nil -> {:noreply, assign(socket, :error, "Axis not found")}
      axis -> {:noreply, edit(socket, axis)}
    end
  end

  def handle_event("cancel", _, socket), do: {:noreply, assign(socket, form: nil, editing: nil)}

  def handle_event("validate", %{"stepper_axis" => params}, socket) when is_map(params) do
    cs =
      socket.assigns.editing
      |> StepperAxis.changeset(with_axis_index(params, socket.assigns.editing))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("save", %{"stepper_axis" => params}, socket) when is_map(params) do
    axis = socket.assigns.editing
    params = with_axis_index(params, axis)

    result =
      if axis.id,
        do: Hardware.update_stepper_axis(axis, params),
        else: Hardware.create_stepper_axis(socket.assigns.device_id, params)

    case result do
      {:ok, saved} ->
        send(self(), {:stepper_axis_saved, saved})
        # A new axis goes straight into the guided setup; nothing has moved yet.
        wizard = if axis.id, do: socket.assigns.wizard_axis_id, else: saved.id

        {:noreply,
         assign(socket,
           form: nil,
           editing: nil,
           error: nil,
           notice: nil,
           wizard_axis_id: wizard,
           axes: Hardware.list_stepper_axes(saved.device_id)
         )}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :form, to_form(cs))}

      error ->
        {:noreply, assign(socket, :error, GaugeFeedback.result(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with %StepperAxis{} = axis <- own_axis(socket, id),
         {:ok, _} <- Hardware.delete_stepper_axis(axis) do
      send(self(), {:stepper_axis_saved, axis})
      {:noreply, assign(socket, :axes, Hardware.list_stepper_axes(axis.device_id))}
    else
      error -> {:noreply, assign(socket, :error, GaugeFeedback.result(error))}
    end
  end

  def handle_event(_, _, socket),
    do: {:noreply, assign(socket, :error, "Enter valid configuration values before continuing.")}

  # The logical axis follows the motor port, so the operator only picks the port. An
  # existing axis keeps its index unless the port really changes: rewriting it would
  # count as a motion change and silently undo the gauge setup.
  defp with_axis_index(%{"motor_port" => port} = params, %StepperAxis{} = axis) do
    case Integer.parse(to_string(port)) do
      {n, ""} when n in [1, 2] and (is_nil(axis.id) or n != axis.motor_port) ->
        Map.put(params, "axis_index", n - 1)

      _ ->
        params
    end
  end

  defp with_axis_index(params, _axis), do: params

  defp next_free_port(axes) do
    used = Enum.map(axes, & &1.motor_port)
    Enum.find([1, 2], 1, &(&1 not in used))
  end

  defp edit(socket, axis),
    do:
      assign(socket,
        editing: axis,
        form: to_form(StepperAxis.changeset(axis, %{})),
        error: nil,
        changing_address: false
      )

  defp own_axis(socket, id),
    do: Enum.find(socket.assigns.axes, &(to_string(&1.id) == to_string(id)))

  defp port_options(axes, editing) do
    used = for a <- axes, a.id != editing.id, do: a.motor_port

    for port <- [1, 2] do
      label = if port in used, do: "Motor #{port} (in use)", else: "Motor #{port}"
      [key: label, value: port, disabled: port in used]
    end
  end

  defp shield_address(axes), do: axes |> List.first() |> Map.fetch!(:shield_address)

  defp hex(address),
    do: "0x" <> (address |> Integer.to_string(16) |> String.pad_leading(2, "0"))

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :show_allcall,
        assigns.allcall_warning != nil and not Enum.all?(assigns.axes, &GaugeGuidance.set_up?/1)
      )

    ~H"""
    <div>
      <.config_section
        id="stepper-axes"
        title="Gauges"
        count={length(@axes)}
        description="Stepper-motor gauges driven by the motor shield."
        empty?={@axes == [] and is_nil(@form)}
        empty_icon="hero-cog-6-tooth"
        empty_message="No gauges configured"
        empty_hint="Drive a gauge needle from the sim with a stepper motor. Needs controller firmware 3.1.0 or newer."
      >
        <:actions>
          <.section_action
            id="stepper-add"
            label="Add gauge"
            on_click="add"
            target={@myself}
            disabled={length(@axes) >= 2}
            disabled_reason="Both motor ports are in use."
          />
        </:actions>
        <:settings :if={@axes != []}>
          <div id="stepper-shield" class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>Motor shield address</span>
            <span class="font-mono text-base-content">{hex(shield_address(@axes))}</span>
            <button
              :if={not @changing_address}
              id="stepper-change-address"
              type="button"
              phx-click="change_address"
              phx-target={@myself}
              class="btn btn-ghost btn-xs text-xs"
            >
              <.icon name="hero-pencil-square" class="size-4" /> Change
            </button>
          </div>
        </:settings>
        <:notice :if={@show_allcall}>
          <div
            id="stepper-allcall-warning"
            role="alert"
            class="alert alert-soft alert-warning text-sm"
          >
            <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
            <div>
              <p class="font-semibold">Display at 0x70 and a new motor shield</p>
              <p>{@allcall_warning}</p>
            </div>
          </div>
        </:notice>
        <:notice :if={@notice}>
          <p role="status" class="text-sm text-success">{@notice}</p>
        </:notice>
        <:notice :if={@error}>
          <div role="alert" class="alert alert-soft alert-error text-sm">
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <p>{@error}</p>
          </div>
        </:notice>
        <div class="space-y-4">
          <.form
            :if={@changing_address and @axes != []}
            for={to_form(%{})}
            id="stepper-recommission-address"
            phx-submit="recommission"
            phx-target={@myself}
            class="space-y-3 rounded-lg border border-base-300 bg-base-100 p-4"
          >
            <p class="text-sm">
              Only needed if you moved the address jumpers on the shield. Every gauge on it will need re-zeroing.
            </p>
            <p :if={@allcall_warning} role="alert" class="text-sm text-warning">
              {@allcall_warning}
            </p>
            <ol class="list-decimal pl-5 text-sm space-y-1">
              <li>Unplug any display at address 0x70.</li>
              <li>
                Enter the new address and press Change address, with the shield alone connected.
              </li>
              <li>Plug the display back in and apply the configuration again.</li>
            </ol>
            <.input name="address" value={hex(shield_address(@axes))} label="New shield address" />
            <div class="flex gap-2">
              <button
                type="submit"
                class="btn btn-sm"
                disabled={@snapshot.lifecycle == :disconnected}
              >
                Change address
              </button>
              <button
                type="button"
                phx-click="cancel_address"
                phx-target={@myself}
                class="btn btn-sm btn-ghost"
              >
                Cancel
              </button>
            </div>
          </.form>
          <.form
            :if={@form}
            for={@form}
            id="stepper-axis-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-3 rounded-lg border border-base-300 bg-base-100 p-4"
          >
            <div class="grid sm:grid-cols-2 gap-3">
              <.input field={@form[:name]} label="Name" placeholder="Speedometer" />
              <.input
                field={@form[:motor_port]}
                label="Shield port"
                type="select"
                options={port_options(@axes, @editing)}
              />
            </div>
            <.disclosure id="stepper-form-motor" summary="Motor settings">
              <p class="text-xs text-muted">
                The defaults suit an X27 gauge motor. Changing them means running the gauge setup again.
              </p>
              <div class="grid sm:grid-cols-2 gap-3">
                <.input field={@form[:mode]} label="Motor type" type="select" options={@modes} />
                <.input
                  :for={{field, label} <- @motor_numbers}
                  field={@form[field]}
                  label={label}
                  type="number"
                />
              </div>
            </.disclosure>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                {if @editing.id, do: "Save", else: "Add and set up"}
              </button>
              <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
                Cancel
              </button>
            </div>
          </.form>
          <article
            :for={axis <- @axes}
            id={"stepper-axis-#{axis.id}"}
            class="bg-base-100 border border-base-300 rounded-lg p-4 space-y-3 scroll-mt-36"
          >
            <% status = GaugeGuidance.axis_status(axis, @snapshot) %>
            <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
              <div class="min-w-0 flex-1 basis-48">
                <h4 class="font-semibold break-words">{axis.name}</h4>
                <p class="text-xs text-muted">Motor {axis.motor_port}</p>
              </div>
              <div class="ml-auto flex shrink-0 items-center gap-1">
                <.status_chip
                  id={"stepper-status-#{axis.id}"}
                  kind={status.kind}
                  label={status.label}
                />
                <.row_actions
                  :if={@wizard_axis_id != axis.id}
                  id={"stepper-actions-#{axis.id}"}
                  menu_id={"stepper-menu-#{axis.id}"}
                  menu={:always}
                  name={axis.name}
                >
                  <:action
                    :if={status.primary != :wizard}
                    id={"stepper-setup-again-#{axis.id}"}
                    event="open_wizard"
                    values={%{id: axis.id}}
                    target={@myself}
                    icon="hero-arrow-path"
                    label="Run gauge setup again"
                  />
                  <:action
                    id={"stepper-edit-#{axis.id}"}
                    event="edit"
                    values={%{id: axis.id}}
                    target={@myself}
                    icon="hero-pencil-square"
                    label="Edit"
                  />
                  <:action
                    id={"stepper-diagnostics-toggle-#{axis.id}"}
                    event="toggle_diagnostics"
                    values={%{id: axis.id}}
                    target={@myself}
                    icon="hero-wrench-screwdriver"
                    label={
                      if MapSet.member?(@diagnostics, axis.id),
                        do: "Hide diagnostics",
                        else: "Diagnostics"
                    }
                  />
                  <:action
                    id={"stepper-delete-#{axis.id}"}
                    event="delete"
                    values={%{id: axis.id}}
                    target={@myself}
                    kind={:danger}
                    label={"Delete #{axis.name}"}
                    confirm={"Delete #{axis.name}? Train gauge bindings using it stop working."}
                  />
                </.row_actions>
              </div>
            </div>
            <.live_component
              :if={@wizard_axis_id == axis.id}
              module={TreninoWeb.GaugeWizardComponent}
              id={"gauge-wizard-#{axis.id}"}
              axis={axis}
              snapshot={@snapshot}
            />
            <.live_component
              :if={@wizard_axis_id != axis.id}
              module={TreninoWeb.StepperCommissioningComponent}
              id={"stepper-commissioning-#{axis.id}"}
              axis={axis}
              snapshot={@snapshot}
              diagnostics={MapSet.member?(@diagnostics, axis.id)}
              wizard_target={@myself}
            />
          </article>
        </div>
      </.config_section>
    </div>
    """
  end
end
