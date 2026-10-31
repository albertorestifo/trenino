defmodule TreninoWeb.GaugeBindingWizard do
  @moduledoc """
  Human-field gauge binding workflow, usable offline. A train's gauge only chooses its
  speed source (axis, endpoint, units) and whether it is enabled; the dial itself is
  calibrated once per axis in the hardware configuration
  (`TreninoWeb.DialCalibrationComponent`).
  """
  use TreninoWeb, :live_component
  alias Phoenix.HTML.Form
  alias Trenino.Hardware
  alias Trenino.Hardware.DialCalibration
  alias Trenino.Hardware.StepperManager
  alias Trenino.Train
  alias Trenino.Train.{Detection, GaugeBinding, GaugePresets}
  alias TreninoWeb.{DialCalibrationComponent, GaugeFeedback, GaugeGuidance}

  @impl true
  def update(%{runtime_event: {id, status}}, socket) do
    {:ok, assign(socket, :runtime, Map.put(socket.assigns.runtime, id, status))}
  end

  def update(%{explorer_event: {field, endpoint}}, socket) do
    if socket.assigns.form && socket.assigns.explorer_field == field do
      {:ok, change(socket, Map.put(socket.assigns.params, "endpoint", endpoint))}
    else
      {:ok, socket}
    end
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> nil end)
      |> assign_new(:editing, fn -> nil end)
      |> assign_new(:params, fn -> %{} end)
      |> assign_new(:message, fn -> nil end)
      |> assign_new(:explorer_open, fn -> false end)
      |> assign_new(:runtime, fn -> %{} end)

    {:ok,
     assign(socket,
       axes: Hardware.list_all_stepper_axes(),
       bindings: Train.list_gauge_bindings(socket.assigns.train_id)
     )}
  end

  @impl true
  def handle_event(event, _, %{assigns: %{editing: nil}} = socket)
      when event in ["save", "submit", "validate", "preset", "explore"] do
    {:noreply, assign(socket, :message, "Open a gauge configuration before continuing.")}
  end

  def handle_event("add", _, socket) do
    axis = List.first(socket.assigns.axes)
    params = %{"stepper_axis_id" => if(axis, do: axis.id, else: nil)}
    {:noreply, begin_edit(socket, %GaugeBinding{train_id: socket.assigns.train_id}, params)}
  end

  def handle_event("preset", _, socket) do
    params = GaugePresets.class323_speedometer() |> stringify()
    params = Map.put(params, "stepper_axis_id", socket.assigns.params["stepper_axis_id"])
    {:noreply, change(socket, params)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case own_binding(socket, id) do
      nil -> {:noreply, assign(socket, :message, "Binding not found")}
      b -> {:noreply, begin_edit(socket, b, serializable(b))}
    end
  end

  def handle_event("validate", %{"gauge_binding" => params}, socket) when is_map(params),
    do: {:noreply, change(socket, params)}

  # Typing in the embedded API explorer search box also bubbles a form change.
  def handle_event("validate", _, socket), do: {:noreply, socket}

  def handle_event("submit", params, socket), do: handle_event("save", params, socket)

  def handle_event("save", %{"gauge_binding" => params}, socket) when is_map(params) do
    b = socket.assigns.editing

    result =
      if b.id,
        do: Train.update_gauge_binding(b, params),
        else: Train.create_gauge_binding(socket.assigns.train_id, params)

    case result do
      {:ok, binding} ->
        send(self(), {:gauge_binding_saved, binding})

        {:noreply,
         assign(socket,
           form: nil,
           editing: nil,
           bindings: Train.list_gauge_bindings(binding.train_id),
           message: "Gauge saved. Commission and reference hardware before enabling."
         )}

      {:error, cs} ->
        {:noreply, assign(socket, form: to_form(cs), params: params)}
    end
  end

  def handle_event("cancel", _, socket),
    do: {:noreply, assign(socket, form: nil, editing: nil, explorer_open: false)}

  def handle_event("delete", %{"id" => id}, socket) do
    with %GaugeBinding{} = b <- own_binding(socket, id),
         {:ok, _} <- Train.delete_gauge_binding(b) do
      {:noreply, assign(socket, :bindings, Train.list_gauge_bindings(b.train_id))}
    else
      error -> {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    with %GaugeBinding{} = b <- own_binding(socket, id),
         {:ok, _} <- Train.update_gauge_binding(b, %{enabled: not b.enabled}) do
      {:noreply, assign(socket, :bindings, Train.list_gauge_bindings(b.train_id))}
    else
      error -> {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  def handle_event("explore", _, socket),
    do: {:noreply, assign(socket, :explorer_open, not socket.assigns.explorer_open)}

  def handle_event(_, _, socket),
    do:
      {:noreply, assign(socket, :message, "Enter valid configuration values before continuing.")}

  defp begin_edit(socket, b, params),
    do:
      socket
      |> assign(editing: b, explorer_field: "gauge:#{System.unique_integer([:positive])}")
      |> change(params)

  defp change(socket, params) do
    axis = find_axis(socket.assigns.axes, params["stepper_axis_id"])

    cs =
      GaugeBinding.changeset(socket.assigns.editing, params, axis) |> Map.put(:action, :validate)

    assign(socket, params: params, form: to_form(cs))
  end

  defp find_axis(axes, id), do: Enum.find(axes, &(to_string(&1.id) == to_string(id)))

  defp own_binding(socket, id), do: Enum.find(socket.assigns.bindings, &(to_string(&1.id) == id))

  defp stringify(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp serializable(b) do
    b
    |> Map.from_struct()
    |> Map.take([
      :stepper_axis_id,
      :name,
      :endpoint,
      :value_key,
      :input_unit,
      :multiplier,
      :offset,
      :absolute_value,
      :out_of_range,
      :inactive_behavior,
      :stale_after_ms,
      :enabled
    ])
    |> stringify()
  end

  @doc false
  # Short description of the axis dial for the wizard and the saved gauge cards.
  def dial_status(axis) do
    case GaugeBinding.calibration(axis) do
      nil -> {:missing, "No dial calibration on this axis yet."}
      %DialCalibration{valid: false} -> {:missing, "The dial needs re-measuring (axis changed)."}
      %DialCalibration{reviewed: false} -> {:missing, "The dial is saved but not reviewed."}
      %DialCalibration{output_unit: unit} -> {:ok, "Dial calibrated, shows #{unit_label(unit)}."}
    end
  end

  defp enable_reason(form, axis) do
    cond do
      is_nil(axis) ->
        "Choose a hardware axis in step 1."

      not axis.commissioned ->
        "Complete physical commissioning of this axis first (Stepper axes in Hardware configurations)."

      axis.idle_behavior != :hold ->
        "Continuous gauges need the axis idle behavior set to hold."

      match?({:missing, _}, dial_status(axis)) ->
        {_, reason} = dial_status(axis)
        "#{reason} Calibrate and review the dial on the axis first."

      form[:input_unit].errors != [] ->
        "Fix the units in step 2 first."

      true ->
        nil
    end
  end

  defp checked?(field), do: Form.normalize_value("checkbox", field.value)

  defp detected_identifier do
    Detection.get_current_identifier()
  catch
    :exit, _ -> nil
  end

  defp binding_blocker(binding, client) do
    snapshot = StepperManager.snapshot(binding.stepper_axis.device_id)
    GaugeGuidance.blocker(binding, snapshot, client != nil)
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-300 p-4 space-y-3">
      <h3 class="font-semibold flex items-center gap-2">
        <span class="badge badge-sm badge-neutral">{@number}</span>{@title}
      </h3>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, required: true
  attr :reason, :string, default: nil

  defp why_disabled(assigns) do
    ~H"""
    <p :if={@reason} id={@id} class="text-xs text-warning">Unavailable: {@reason}</p>
    """
  end

  attr :axis, :any, required: true
  attr :id, :string, required: true

  defp dial_line(assigns) do
    assigns = assign(assigns, :status, dial_status(assigns.axis))

    ~H"""
    <p id={@id} class={["text-sm", match?({:missing, _}, @status) && "text-warning"]}>
      {elem(@status, 1)}
      <.link
        navigate={"/configurations/#{@axis.device.config_id}#dial-calibration-#{@axis.id}"}
        class="link"
      >{if match?({:ok, _}, @status), do: "Review the dial", else: "Calibrate the dial"}</.link>
    </p>
    """
  end

  @impl true
  def render(assigns) do
    axis = find_axis(assigns.axes, assigns.params["stepper_axis_id"])

    assigns =
      assigns
      |> assign(:axis, axis)
      |> assign(:unit_options, DialCalibrationComponent.unit_options())
      |> assign(:train_hint, train_hint(assigns))

    ~H"""
    <section id="gauge-bindings" class="bg-base-200/50 rounded-xl p-6 mt-6 space-y-4">
      <div class="flex justify-between">
        <h2 class="text-lg font-semibold">Gauges</h2><button
          id="gauge-add"
          type="button"
          phx-click="add"
          phx-target={@myself}
          class="btn btn-sm"
          disabled={@axes == []}
        >Add gauge</button>
      </div>
      <p :if={@axes == []}>
        Create a stepper axis in <.link navigate={~p"/"} class="link">Hardware configurations</.link>, Apply it, commission the physical dial and calibrate it there.
      </p>
      <p :if={@message && is_nil(@form)} role="status" class="text-sm">{@message}</p>
      <div :if={@form} class="space-y-4">
        <p class="text-sm">
          Choose which simulator value drives which hardware dial. Saving never moves hardware.
        </p>
        <.form
          for={@form}
          id="gauge-binding-form"
          phx-change="validate"
          phx-submit="submit"
          phx-target={@myself}
          class="space-y-4"
        >
          <.step number={1} title="Hardware axis">
            <.input
              field={@form[:stepper_axis_id]}
              type="select"
              label="Hardware axis"
              options={Enum.map(@axes, &{"#{&1.device.name} · #{&1.name}", &1.id})}
            />
            <.dial_line :if={@axis} id="gauge-dial-status" axis={@axis} />
          </.step>

          <.step number={2} title="Simulator endpoint and units">
            <button
              id="gauge-class323"
              type="button"
              phx-click="preset"
              phx-target={@myself}
              class="btn btn-sm"
            >Fill with Class 323 speedometer starter</button>
            <p class="text-xs text-warning">
              The starter only suggests the units (m/s in). Verify the endpoint and units; no endpoint is guessed.
            </p>
            <.input field={@form[:name]} label="Name" />
            <.input field={@form[:endpoint]} label="Simulator endpoint (verify units)" />
            <button
              :if={@client}
              type="button"
              phx-click="explore"
              phx-target={@myself}
              class="btn btn-sm"
            >Browse simulator API</button>
            <.live_component
              :if={@client && @explorer_open}
              module={TreninoWeb.ApiExplorerComponent}
              id="gauge-api-explorer"
              client={@client}
              field={@explorer_field}
              mode={:none}
              embedded={true}
            />
            <p :if={is_nil(@client)} class="text-sm">
              Offline editing: enter the exact endpoint now, or connect the simulator to browse it.
            </p>
            <.input field={@form[:value_key]} label="Value key (blank requires one numeric value)" />
            <.input
              field={@form[:input_unit]}
              type="select"
              label="Simulator reports in"
              options={@unit_options}
            />
            <p :if={@axis && GaugeBinding.calibration(@axis)} id="gauge-dial-unit" class="text-xs">
              The dial unit is set on the axis: {unit_label(
                GaugeBinding.calibration(@axis).output_unit
              )}.
            </p>
          </.step>

          <.step number={3} title="Save, then enable">
            <.input
              field={@form[:enabled]}
              type="checkbox"
              label="Enable continuous gauge"
              disabled={enable_reason(@form, @axis) != nil and not checked?(@form[:enabled])}
            />
            <.why_disabled
              :if={not checked?(@form[:enabled])}
              id="gauge-enable-reason"
              reason={enable_reason(@form, @axis)}
            />
            <p class="text-xs">
              Saving never moves the motor. If you cannot enable yet, save it disabled, finish commissioning and the dial calibration, then use Enable on the saved gauge.
            </p>
            <button id="gauge-save" type="submit" name="intent" value="save" class="btn btn-primary">
              {if checked?(@form[:enabled]),
                do: "Save and enable gauge",
                else: "Save gauge (disabled)"}
            </button>
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
              Cancel
            </button>
          </.step>

          <details id="gauge-advanced" class="border border-base-300 rounded p-3">
            <summary class="cursor-pointer">
              Advanced (multiplier, offset, stale time, out of range)
            </summary>
            <div class="grid sm:grid-cols-2 gap-3 mt-3">
              <.input field={@form[:multiplier]} type="number" step="0.01" label="Multiplier" />
              <.input field={@form[:offset]} type="number" step="0.01" label="Offset" />
              <.input
                field={@form[:stale_after_ms]}
                type="number"
                step="1"
                label="Sample stale after (ms)"
              />
              <.input
                field={@form[:out_of_range]}
                type="select"
                label="Out of range"
                options={[{"Clamp to the ends", :clamp}, {"Reject the value", :reject}]}
              />
              <.input
                field={@form[:inactive_behavior]}
                type="select"
                label="When inactive or stale"
                options={[{"Hold position", :hold}, {"Release motor", :release}]}
              />
            </div>
            <.input
              field={@form[:absolute_value]}
              type="checkbox"
              label="Use absolute input value (negative speed becomes positive)"
            />
          </details>
        </.form>
      </div>
      <p :if={@train_hint} id="gauge-train-hint" role="status" class="text-sm text-warning">
        {@train_hint}
      </p>
      <article
        :for={b <- @bindings}
        id={"gauge-binding-#{b.id}"}
        class="border border-base-300 rounded p-4 space-y-2"
      >
        <strong>{b.name}</strong><p class="text-sm">
          {b.stepper_axis.device.name} · {b.stepper_axis.name} · {b.endpoint} · {unit_label(
            b.input_unit
          )}
        </p>
        <p>{if b.enabled, do: "Enabled", else: "Disabled"}</p>
        <.dial_line id={"gauge-dial-#{b.id}"} axis={b.stepper_axis} />
        <p
          :if={blocker = binding_blocker(b, @client)}
          id={"gauge-blocker-#{b.id}"}
          role="status"
          class="text-sm text-warning"
        >
          {blocker}
        </p>
        <p :if={@runtime[b.id]} class="text-sm">
          Latest sample: {GaugeFeedback.value(@runtime[b.id][:sample])} ·
          Converted value: {GaugeFeedback.value(@runtime[b.id][:value])} ·
          Estimated target: {GaugeFeedback.value(@runtime[b.id][:target])} transitions
        </p>
        <p :if={@runtime[b.id] && @runtime[b.id][:stale]} role="status">
          Simulator data is stale; movement is suspended.
        </p>
        <p :if={@runtime[b.id] && @runtime[b.id][:failure]} role="status">
          {GaugeFeedback.result(@runtime[b.id][:failure])}
        </p>
        <p :if={is_nil(@runtime[b.id])} class="text-sm">
          Awaiting fresh simulator data and referenced hardware. Manual pause, stale values or faults suspend movement.
        </p>
        <button
          :for={
            {label, event} <- [{"Edit", "edit"}, {"Enable / disable", "toggle"}, {"Delete", "delete"}]
          }
          type="button"
          phx-click={event}
          phx-value-id={b.id}
          phx-target={@myself}
          class="btn btn-sm"
        >{label}</button>
        <.link navigate={~p"/configurations/#{b.stepper_axis.device.config_id}"} class="link text-sm">Hardware commissioning</.link>
      </article>
    </section>
    """
  end

  defp unit_label(unit),
    do:
      Enum.find_value(
        DialCalibrationComponent.unit_options(),
        &(elem(&1, 1) == unit && elem(&1, 0))
      )

  defp train_hint(%{bindings: []}), do: nil

  defp train_hint(assigns) do
    case Train.get_train(assigns.train_id, preload: [:identifiers]) do
      {:ok, train} -> GaugeGuidance.train_hint(train, detected_identifier())
      _ -> nil
    end
  end
end
