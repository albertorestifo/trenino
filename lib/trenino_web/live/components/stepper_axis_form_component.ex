defmodule TreninoWeb.StepperAxisFormComponent do
  @moduledoc "Hardware axis editor. Validation and persistence never issue motion."
  use TreninoWeb, :live_component
  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.{StepperAxis, StepperManager, StepperPresets}
  alias TreninoWeb.GaugeFeedback

  @numbers [
    axis_index: "Logical axis (0–1)",
    shield_address: "Shield address (decimal or 0x60)",
    motor_port: "Shield motor port (1–2)",
    min_position: "Minimum position (transitions)",
    max_position: "Maximum position (transitions)",
    max_speed: "Maximum speed (transitions/s)",
    acceleration: "Acceleration (transitions/s²)",
    watchdog_ms: "Host watchdog (ms)",
    home_direction: "Home direction (-1 or +1)",
    home_steps: "Home sweep (transitions)",
    home_backoff: "Home backoff (transitions)",
    home_speed: "Home speed (transitions/s)",
    home_timeout_ms: "Home timeout (ms)",
    home_position: "Home reference position"
  ]
  @selects [
    driver: {"Driver", [:adafruit_motor_shield]},
    mode: {"Electrical mode", [:x27_six_state, :full_step, :half_step]},
    idle_behavior: {"Idle behavior", [:hold, :release]},
    host_loss_behavior: {"Host loss behavior", [:release, :hold]},
    reference_strategy: {"Reference strategy", [:host_reference, :internal_stop]},
    startup_reference:
      {"Startup reference (automatic Home requires commissioning)", [:manual, :home_on_connect]}
  ]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:editing, fn -> nil end)
      |> assign_new(:form, fn -> nil end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:snapshot, fn -> StepperManager.snapshot(assigns.device_id) end)

    {:ok,
     socket
     |> assign(:axes, Hardware.list_stepper_axes(socket.assigns.device_id))
     |> assign(:numbers, @numbers)
     |> assign(:selects, @selects)}
  end

  @impl true
  def handle_event(event, _, %{assigns: %{editing: nil}} = socket)
      when event in ["save", "validate"] do
    {:noreply, assign(socket, :error, "Open an axis configuration before continuing.")}
  end

  def handle_event("add", _, socket),
    do: {:noreply, edit(socket, %StepperAxis{device_id: socket.assigns.device_id})}

  def handle_event("ack_registration", _, socket) do
    send(self(), {:stepper_registration_acknowledged, socket.assigns.device_id})

    {:noreply,
     assign(
       socket,
       :error,
       "Registration order acknowledged. You can now Apply this configuration."
     )}
  end

  def handle_event("recommission", params, socket) do
    result =
      with address when is_binary(address) <- params["address"],
           {:ok, address} <- I2cModule.parse_i2c_address(address),
           do:
             StepperManager.recommission_address(
               socket.assigns.device_id,
               address,
               params["acknowledged"] == "true"
             )

    {:noreply, assign(socket, :error, GaugeFeedback.result(result))}
  end

  def handle_event("preset", _, socket) do
    axis =
      struct(
        StepperAxis,
        Map.put(StepperPresets.class323_speedometer_axis(), :device_id, socket.assigns.device_id)
      )

    {:noreply, edit(socket, axis)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case own_axis(socket, id) do
      nil -> {:noreply, assign(socket, :error, "Axis not found")}
      axis -> {:noreply, edit(socket, axis)}
    end
  end

  def handle_event("cancel", _, socket), do: {:noreply, assign(socket, form: nil, editing: nil)}

  def handle_event("validate", %{"stepper_axis" => params}, socket) when is_map(params) do
    cs = StepperAxis.changeset(socket.assigns.editing, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("save", %{"stepper_axis" => params}, socket) when is_map(params) do
    axis = socket.assigns.editing

    result =
      if axis.id,
        do: Hardware.update_stepper_axis(axis, params),
        else: Hardware.create_stepper_axis(socket.assigns.device_id, params)

    case result do
      {:ok, axis} ->
        send(self(), {:stepper_axis_saved, axis})

        {:noreply,
         socket
         |> assign(
           form: nil,
           editing: nil,
           error: nil,
           axes: Hardware.list_stepper_axes(axis.device_id)
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

  defp edit(socket, axis),
    do: assign(socket, editing: axis, form: to_form(StepperAxis.changeset(axis, %{})), error: nil)

  defp own_axis(socket, id), do: Enum.find(socket.assigns.axes, &(to_string(&1.id) == id))

  @impl true
  def render(assigns) do
    ~H"""
    <section id="stepper-axes" class="bg-base-200/50 rounded-xl p-6 mt-6 space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="text-lg font-semibold">Stepper axes</h2>
        <button id="stepper-add" type="button" phx-click="add" phx-target={@myself} class="btn btn-sm">Add axis</button>
      </div>
      <p class="text-sm">
        Firmware 3.1.0 or newer. Positions are open-loop estimates in commutation transitions.
      </p>
      <p class="text-sm text-warning">
        First registration: disconnect any 0x70 display, register the shield alone, then reconnect and Apply the display configuration. A new shield may respond to ALLCALL 0x70.
      </p>
      <button type="button" phx-click="ack_registration" phx-target={@myself} class="btn btn-sm">I confirm the shield is registered, or the 0x70 display is disconnected for first registration</button>
      <details :if={@axes != []} class="border border-base-300 rounded p-3">
        <summary>Recommission shield address (both axes lose reference)</summary>
        <.form
          for={to_form(%{})}
          id="stepper-recommission-address"
          phx-submit="recommission"
          phx-target={@myself}
        >
          <.input name="address" value="0x60" label="New shared shield address" />
          <.input
            name="acknowledged"
            type="checkbox"
            value="true"
            label="I followed the shield-alone ALLCALL registration order"
            checked={false}
          />
          <button type="submit" class="btn btn-sm" disabled={@snapshot.lifecycle == :disconnected}>Reset, forget old registration and configure new address</button>
        </.form>
      </details>
      <button type="button" phx-click="preset" phx-target={@myself} class="btn btn-sm btn-ghost">Use editable Class 323 starter</button>
      <p class="text-xs text-base-content/60">
        0–100 mph, approximately 240° / 720 transitions: unverified geometry. Verify winding order, direction and whole motor travel physically. Defaults never Home automatically.
      </p>
      <p :if={@error} role="alert" class="text-error">{@error}</p>
      <.form
        :if={@form}
        for={@form}
        id="stepper-axis-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        class="space-y-3"
      >
        <.input field={@form[:name]} label="Axis name" />
        <div class="grid sm:grid-cols-2 gap-3">
          <.input
            :for={{field, label} <- @numbers}
            field={@form[field]}
            label={label}
            type={if(field == :shield_address, do: "text", else: "number")}
          />
          <.input
            :for={{field, {label, options}} <- @selects}
            field={@form[field]}
            label={label}
            type="select"
            options={Enum.map(options, &{Phoenix.Naming.humanize(&1), &1})}
          />
        </div>
        <.input field={@form[:reverse]} type="checkbox" label="Reverse electrical direction" />
        <p class="text-xs">
          Idle release loses reference after every completion. Continuous gauges require hold. Automatic Home causes bounded motion on each new connection only after physical commissioning; selecting it does not move now.
        </p>
        <button type="submit" class="btn btn-primary">Save axis</button>
        <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">Cancel</button>
      </.form>
      <article
        :for={axis <- @axes}
        id={"stepper-axis-#{axis.id}"}
        class="border border-base-300 rounded-lg p-4 space-y-2"
      >
        <div class="flex justify-between">
          <strong>{axis.name}</strong><span>{if axis.commissioned,
            do: "Commissioned",
            else: "Needs physical commissioning"}</span>
        </div>
        <p class="text-sm">
          Axis {axis.axis_index} · port {axis.motor_port} · {axis.mode} · {axis.min_position}…{axis.max_position}
        </p>
        <button
          type="button"
          phx-click="edit"
          phx-value-id={axis.id}
          phx-target={@myself}
          class="btn btn-sm"
        >Edit</button>
        <button
          type="button"
          phx-click="delete"
          phx-value-id={axis.id}
          phx-target={@myself}
          class="btn btn-sm btn-ghost"
        >Delete</button>
        <.live_component
          module={TreninoWeb.StepperCommissioningComponent}
          id={"stepper-commissioning-#{axis.id}"}
          axis={axis}
          snapshot={@snapshot}
        />
      </article>
    </section>
    """
  end
end
