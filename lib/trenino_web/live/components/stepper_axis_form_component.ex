defmodule TreninoWeb.StepperAxisFormComponent do
  @moduledoc "Hardware axis editor. Validation and persistence never issue motion."
  use TreninoWeb, :live_component
  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.{StepperAxis, StepperManager, StepperPresets}
  alias TreninoWeb.GaugeFeedback

  @basic_numbers [
    axis_index: "Logical axis (0 or 1)",
    motor_port: "Shield motor port (1 or 2)",
    min_position: "Minimum position (transitions)",
    max_position: "Maximum position (transitions)",
    max_speed: "Maximum speed (transitions/s)",
    acceleration: "Acceleration (transitions/s²)"
  ]
  @advanced_numbers [
    shield_address: "Shield address (decimal or 0x60)",
    watchdog_ms: "Host watchdog (ms)",
    home_direction: "Home direction (-1 or +1)",
    home_steps: "Home sweep (transitions)",
    home_backoff: "Home backoff (transitions)",
    home_speed: "Home speed (transitions/s)",
    home_timeout_ms: "Home timeout (ms)",
    home_position: "Home reference position"
  ]
  @basic_selects [
    mode: {"Electrical mode", [:x27_six_state, :full_step, :half_step]}
  ]
  @advanced_selects [
    driver: {"Driver", [:adafruit_motor_shield]},
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
      |> assign_new(:notice, fn -> nil end)
      |> assign_new(:apply_needed, fn -> false end)
      |> assign_new(:snapshot, fn -> StepperManager.snapshot(assigns.device_id) end)

    {:ok,
     socket
     |> assign(:axes, Hardware.list_stepper_axes(socket.assigns.device_id))
     |> assign(:basic_numbers, @basic_numbers)
     |> assign(:advanced_numbers, @advanced_numbers)
     |> assign(:basic_selects, @basic_selects)
     |> assign(:advanced_selects, @advanced_selects)
     |> assign(:allcall_warning, Hardware.allcall_warning(socket.assigns.device_id))}
  end

  @impl true
  def handle_event(event, _, %{assigns: %{editing: nil}} = socket)
      when event in ["save", "validate"] do
    {:noreply, assign(socket, :error, "Open an axis configuration before continuing.")}
  end

  def handle_event("add", _, socket),
    do: {:noreply, edit(socket, %StepperAxis{device_id: socket.assigns.device_id})}

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

  def handle_event("preset", %{"name" => "x27"}, socket) do
    index = next_free_index(socket.assigns.axes)

    attrs = %{StepperPresets.x27_168_axis() | axis_index: index, motor_port: index + 1}

    {:noreply,
     edit(socket, struct(StepperAxis, Map.put(attrs, :device_id, socket.assigns.device_id)))}
  end

  def handle_event("preset", _, socket) do
    axis =
      struct(
        StepperAxis,
        Map.put(StepperPresets.class323_speedometer_axis(), :device_id, socket.assigns.device_id)
      )

    {:noreply, edit(socket, axis)}
  end

  def handle_event("flip_direction", %{"id" => id}, socket) do
    with %StepperAxis{} = axis <- own_axis(socket, id),
         {:ok, axis} <- Hardware.update_stepper_axis(axis, %{reverse: !axis.reverse}) do
      send(self(), {:stepper_axis_saved, axis})

      {:noreply,
       assign(socket,
         axes: Hardware.list_stepper_axes(axis.device_id),
         error: nil,
         notice: saved_notice(axis, "Direction flipped.")
       )}
    else
      error -> {:noreply, assign(socket, :error, GaugeFeedback.result(error))}
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
           notice: saved_notice(axis, "Saved."),
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

  defp next_free_index(axes) do
    used = Enum.map(axes, & &1.axis_index)
    Enum.find([0, 1], 0, &(&1 not in used))
  end

  defp saved_notice(axis, prefix) do
    "#{prefix} Nothing has moved and the device has not changed yet. Next: click Apply to Device, " <>
      "then take manual control, align the needle by hand and Assign reference" <>
      if(axis.reverse, do: " (direction is now reversed).", else: ".")
  end

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
      <div
        :if={@allcall_warning}
        id="stepper-allcall-warning"
        role="alert"
        class="alert alert-warning text-sm"
      >
        <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
        <div>
          <p class="font-semibold">Warning: display at 0x70 and a motor shield</p>
          <p>{@allcall_warning}</p>
          <p class="text-xs mt-1">This does not stop you from applying.</p>
        </div>
      </div>
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
      <div class="flex flex-wrap gap-2">
        <button
          id="stepper-preset-x27"
          type="button"
          phx-click="preset"
          phx-value-name="x27"
          phx-target={@myself}
          class="btn btn-sm btn-primary"
        >Quick setup: X27.168 motor</button>
        <button
          type="button"
          phx-click="preset"
          phx-value-name="class323"
          phx-target={@myself}
          class="btn btn-sm btn-ghost"
        >Class 323 speedometer starter</button>
      </div>
      <p class="text-xs text-base-content/60">
        Presets only fill the form. Winding order, direction and travel are unverified until you check them on the real motor. Nothing homes automatically.
      </p>
      <p :if={@notice} role="status" class="text-sm text-success">{@notice}</p>
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
            :for={{field, label} <- @basic_numbers}
            field={@form[field]}
            label={label}
            type="number"
          />
          <.input
            :for={{field, {label, options}} <- @basic_selects}
            field={@form[field]}
            label={label}
            type="select"
            options={Enum.map(options, &{Phoenix.Naming.humanize(&1), &1})}
          />
        </div>
        <.input field={@form[:reverse]} type="checkbox" label="Reverse electrical direction" />
        <details class="border border-base-300 rounded p-3">
          <summary>Advanced (home sweep, timeouts, watchdog, idle behavior)</summary>
          <div class="grid sm:grid-cols-2 gap-3 mt-3">
            <.input
              :for={{field, label} <- @advanced_numbers}
              field={@form[field]}
              label={label}
              type={if(field == :shield_address, do: "text", else: "number")}
            />
            <.input
              :for={{field, {label, options}} <- @advanced_selects}
              field={@form[field]}
              label={label}
              type="select"
              options={Enum.map(options, &{Phoenix.Naming.humanize(&1), &1})}
            />
          </div>
          <p class="text-xs mt-2">
            Idle release loses reference after every completion. Continuous gauges require hold. Automatic Home causes bounded motion on each new connection only after physical commissioning; selecting it does not move now.
          </p>
        </details>
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
          phx-click="flip_direction"
          phx-value-id={axis.id}
          phx-target={@myself}
          class="btn btn-sm"
        >Flip direction{if axis.reverse, do: " (currently reversed)"}</button>
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
          apply_needed={@apply_needed}
        />
      </article>
    </section>
    """
  end
end
