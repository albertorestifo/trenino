defmodule TreninoWeb.GaugeBindingWizard do
  @moduledoc "Human-field gauge binding and calibration workflow, usable offline."
  use TreninoWeb, :live_component
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperManager
  alias Trenino.Train
  alias Trenino.Train.{GaugeBinding, GaugeMapper, GaugePresets}
  alias TreninoWeb.GaugeFeedback

  @fields [
    name: "Name",
    endpoint: "Simulator endpoint (verify units)",
    value_key: "Value key (blank requires one numeric value)",
    multiplier: "Multiplier",
    offset: "Offset",
    stale_after_ms: "Sample stale after (ms)"
  ]
  @selects [
    input_unit: {"Input unit", [:raw, :mps, :kmh, :mph]},
    output_unit: {"Dial unit", [:raw, :mps, :kmh, :mph]},
    out_of_range: {"Out of range", [:clamp, :reject]},
    inactive_behavior: {"When inactive or stale", [:hold, :release]}
  ]
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
      |> assign_new(:preview, fn -> nil end)
      |> assign_new(:token, fn -> nil end)
      |> assign_new(:token_axis, fn -> nil end)
      |> assign_new(:explorer_open, fn -> false end)
      |> assign_new(:runtime, fn -> %{} end)

    {:ok,
     assign(socket,
       axes: Hardware.list_all_stepper_axes(),
       bindings: Train.list_gauge_bindings(socket.assigns.train_id),
       fields: @fields,
       selects: @selects
     )}
  end

  @impl true
  def handle_event(event, _, %{assigns: %{editing: nil}} = socket)
      when event in [
             "save",
             "validate",
             "preview",
             "preset",
             "point",
             "capture",
             "claim",
             "explore"
           ] do
    {:noreply, assign(socket, :message, "Open a gauge configuration before continuing.")}
  end

  def handle_event("add", _, socket) do
    axis = List.first(socket.assigns.axes)

    params = %{
      "stepper_axis_id" => if(axis, do: axis.id, else: nil),
      "points" => [%{"value" => 0.0, "position" => 0}, %{"value" => 100.0, "position" => 720}]
    }

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

  def handle_event("save", %{"gauge_binding" => params}, socket) when is_map(params) do
    b = socket.assigns.editing

    result =
      if b.id,
        do: Train.update_gauge_binding(b, params),
        else: Train.create_gauge_binding(socket.assigns.train_id, params)

    case result do
      {:ok, binding} ->
        release(socket)
        send(self(), {:gauge_binding_saved, binding})

        {:noreply,
         assign(socket,
           form: nil,
           editing: nil,
           token: nil,
           token_axis: nil,
           bindings: Train.list_gauge_bindings(binding.train_id),
           message: "Gauge saved. Commission and reference hardware before enabling."
         )}

      {:error, cs} ->
        {:noreply, assign(socket, form: to_form(cs), params: params)}
    end
  end

  def handle_event("cancel", _, socket) do
    release(socket)

    {:noreply,
     assign(socket, form: nil, editing: nil, token: nil, token_axis: nil, explorer_open: false)}
  end

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

  def handle_event("point", %{"action" => action} = event, socket) do
    points = point_list(socket.assigns.params["points"] || [])

    index =
      case parse_index(Map.get(event, "index", "-1")) do
        {n, ""} -> n
        _ -> -1
      end

    points = edit_points(points, action, index)

    {:noreply, change(socket, Map.put(socket.assigns.params, "points", points))}
  end

  def handle_event("explore", _, socket),
    do: {:noreply, assign(socket, :explorer_open, not socket.assigns.explorer_open)}

  def handle_event("preview", params, socket) do
    with {:ok, value} <- number(params["value"]),
         {:ok, axis} <- selected_axis(socket),
         cs = GaugeBinding.changeset(socket.assigns.editing, socket.assigns.params, axis),
         true <- cs.valid?,
         {:ok, mapped} <- GaugeMapper.map(Ecto.Changeset.apply_changes(cs), value, axis) do
      result =
        if params["action"] == "test",
          do:
            StepperManager.command(
              axis.id,
              :move_to,
              %{position: mapped.target},
              socket.assigns.token
            ),
          else: :preview_only

      {:noreply, assign(socket, preview: mapped, message: GaugeFeedback.result(result))}
    else
      error -> {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  def handle_event("claim", _, socket) do
    with {:ok, axis} <- selected_axis(socket),
         {:ok, token} <- StepperManager.claim_manual(axis.id, self()) do
      {:noreply,
       assign(socket,
         token: token,
         token_axis: axis.id,
         message:
           "Manual control taken. Automatic output remains paused until explicit Resume in hardware commissioning."
       )}
    else
      error -> {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  def handle_event("capture", %{"value" => value}, socket) do
    with {:ok, value} <- number(value),
         {:ok, axis} <- selected_axis(socket),
         true <- socket.assigns.token != nil and socket.assigns.token_axis == axis.id,
         a when not is_nil(a) <- StepperManager.snapshot(axis.device_id).axes[axis.id],
         true <-
           a.status != nil and a.status.known and a.status.state == :idle and
             System.monotonic_time(:millisecond) - a.updated_at < 1500 do
      points =
        point_list(socket.assigns.params["points"]) ++
          [%{"value" => Float.round(value, 2), "position" => a.status.position}]

      {:noreply, change(socket, Map.put(socket.assigns.params, "points", points))}
    else
      _ ->
        {:noreply,
         assign(
           socket,
           :message,
           "Capture requires manual control and a fresh stationary known estimate."
         )}
    end
  end

  def handle_event(_, _, socket),
    do:
      {:noreply, assign(socket, :message, "Enter valid configuration values before continuing.")}

  defp parse_index(value) when is_binary(value), do: Integer.parse(value)
  defp parse_index(_), do: :error

  defp begin_edit(socket, b, params),
    do:
      socket
      |> assign(editing: b, explorer_field: "gauge:#{System.unique_integer([:positive])}")
      |> change(params)

  defp change(socket, params) do
    axis =
      case selected_axis(socket, params) do
        {:ok, a} -> a
        _ -> nil
      end

    cs =
      GaugeBinding.changeset(socket.assigns.editing, params, axis) |> Map.put(:action, :validate)

    assign(socket, params: params, form: to_form(cs))
  end

  defp selected_axis(socket, params \\ nil) do
    id = (params || socket.assigns.params)["stepper_axis_id"]

    case Enum.find(socket.assigns.axes, &(to_string(&1.id) == to_string(id))) do
      nil -> {:error, :select_axis}
      axis -> {:ok, axis}
    end
  end

  defp own_binding(socket, id), do: Enum.find(socket.assigns.bindings, &(to_string(&1.id) == id))

  defp release(socket) do
    if socket.assigns.token,
      do: StepperManager.release_manual(socket.assigns.token_axis, socket.assigns.token)
  end

  defp point_list(points) when is_list(points), do: points

  defp point_list(points) when is_map(points),
    do: points |> Enum.sort_by(fn {i, _} -> Integer.parse(i) end) |> Enum.map(&elem(&1, 1))

  defp edit_points(points, "add", _), do: points ++ [%{"value" => "", "position" => ""}]
  defp edit_points(points, "remove", index) when index >= 0, do: List.delete_at(points, index)
  defp edit_points(points, "up", index) when index > 0, do: swap(points, index, index - 1)

  defp edit_points(points, "down", index) when index >= 0 and index < length(points) - 1,
    do: swap(points, index, index + 1)

  defp edit_points(points, _, _), do: points

  defp swap(points, a, b),
    do: points |> List.replace_at(a, Enum.at(points, b)) |> List.replace_at(b, Enum.at(points, a))

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {n, ""} -> {:ok, n}
      _ -> {:error, :invalid_number}
    end
  end

  defp number(_), do: {:error, :invalid_number}
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
      :output_unit,
      :multiplier,
      :offset,
      :absolute_value,
      :out_of_range,
      :inactive_behavior,
      :stale_after_ms,
      :enabled,
      :calibration_reviewed
    ])
    |> stringify()
    |> Map.put("points", Enum.map(b.points, &(Map.from_struct(&1) |> stringify())))
  end

  @impl true
  def render(assigns) do
    axis =
      Enum.find(assigns.axes, &(to_string(&1.id) == to_string(assigns.params["stepper_axis_id"])))

    connected = axis && StepperManager.snapshot(axis.device_id).lifecycle != :disconnected
    assigns = assign(assigns, :axis_connected, connected == true)

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
        Create a stepper axis in <.link navigate={~p"/"} class="link">Hardware configurations</.link>, Apply it and commission the physical dial.
      </p>
      <p :if={@message} role="status" class="text-sm">{@message}</p>
      <div :if={@form} class="space-y-4">
        <button
          id="gauge-class323"
          type="button"
          phx-click="preset"
          phx-target={@myself}
          class="btn btn-sm"
        >Class 323 speedometer starter</button>
        <p class="text-xs text-warning">
          Unverified estimate: 0–100 mph / approximately 240° / 720 transitions. Verify units and measure every dial; no endpoint is guessed and control stays disabled.
        </p>
        <.form
          for={@form}
          id="gauge-binding-form"
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-3"
        >
          <.input
            field={@form[:stepper_axis_id]}
            type="select"
            label="Hardware axis"
            options={Enum.map(@axes, &{"#{&1.device.name} · #{&1.name}", &1.id})}
          />
          <.input
            :for={{field, label} <- @fields}
            field={@form[field]}
            label={label}
            type={if(field in [:multiplier, :offset, :stale_after_ms], do: "number", else: "text")}
            step={if(field in [:multiplier, :offset], do: "0.01", else: "1")}
          />
          <.input
            :for={{field, {label, values}} <- @selects}
            field={@form[field]}
            type="select"
            label={label}
            options={Enum.map(values, &{Phoenix.Naming.humanize(&1), &1})}
          />
          <.input
            field={@form[:absolute_value]}
            type="checkbox"
            label="Use absolute input value (negative speed becomes positive)"
          />
          <div id="gauge-calibration-points" class="space-y-2">
            <p class="font-medium">Measured calibration points: dial value → estimated transitions</p>
            <p :for={{message, _} <- @form[:points].errors} class="text-error">{message}</p>
            <.inputs_for :let={p} field={@form[:points]}>
              <div class="grid grid-cols-2 gap-2 border border-base-300 p-2 rounded">
                <.input field={p[:value]} type="number" step="0.01" label="Dial value" />
                <.input field={p[:position]} type="number" label="Position (transitions)" />
                <div class="col-span-2 flex gap-2">
                  <button
                    :for={{label, action} <- [{"↑", "up"}, {"↓", "down"}, {"Remove", "remove"}]}
                    type="button"
                    phx-click="point"
                    phx-value-action={action}
                    phx-value-index={p.index}
                    phx-target={@myself}
                    class="btn btn-xs"
                  >{label}</button>
                </div>
              </div>
            </.inputs_for>
            <button
              type="button"
              phx-click="point"
              phx-value-action="add"
              phx-target={@myself}
              class="btn btn-sm"
            >Add measured point</button>
          </div>
          <.input
            field={@form[:calibration_reviewed]}
            type="checkbox"
            label="I reviewed these measured points for this axis and stepping mode"
          />
          <.input
            field={@form[:enabled]}
            type="checkbox"
            label="Enable continuous gauge (requires commissioned hold axis)"
          />
          <button type="submit" class="btn btn-primary">Save gauge</button><button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="btn btn-ghost"
          >Cancel</button>
        </.form>
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
        <div id="gauge-preview" class="space-y-2 border-t border-base-300 pt-4">
          <p>
            Preview converts units → optional absolute value → multiplier → offset → piecewise interpolation. Preview never moves hardware.
          </p>
          <.form for={to_form(%{})} id="gauge-preview-form" phx-submit="preview" phx-target={@myself}>
            <.input name="value" value="0" type="number" step="0.01" label="Simulator test value" />
            <button name="action" value="preview" class="btn btn-sm">Preview only</button>
            <button
              id="gauge-test-value"
              name="action"
              value="test"
              class="btn btn-sm"
              disabled={is_nil(@token) or not @axis_connected}
            >Move to test value</button>
          </.form>
          <p :if={@preview}>
            Converted value: {Float.round(@preview.value, 2)} · estimated target: {@preview.target} · clamped: {@preview.clamped}
          </p>
          <button
            type="button"
            phx-click="claim"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={not @axis_connected}
          >Take manual control for test/capture</button>
          <.form
            for={to_form(%{})}
            id="gauge-capture-position"
            phx-submit="capture"
            phx-target={@myself}
          >
            <.input
              name="value"
              value="0"
              type="number"
              step="0.01"
              label="Actual dial reading to capture"
            />
            <button class="btn btn-sm" disabled={is_nil(@token) or not @axis_connected}>Capture stationary estimated position</button>
          </.form>
        </div>
      </div>
      <article
        :for={b <- @bindings}
        id={"gauge-binding-#{b.id}"}
        class="border border-base-300 rounded p-4 space-y-2"
      >
        <strong>{b.name}</strong><p class="text-sm">
          {b.stepper_axis.device.name} · {b.stepper_axis.name} · {b.endpoint} · {b.input_unit} → {b.output_unit}
        </p>
        <p>
          {if b.enabled, do: "Enabled", else: "Disabled"} · {if b.calibration_valid and
                                                                  b.calibration_reviewed,
                                                                do: "Reviewed calibration recorded",
                                                                else:
                                                                  "Unverified points — calibration review required"}
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
end
