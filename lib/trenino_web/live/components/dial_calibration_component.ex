defmodule TreninoWeb.DialCalibrationComponent do
  @moduledoc """
  Measures and reviews the dial of one stepper axis: points (dial value -> position),
  the unit the printed dial shows, and the review checkbox. The tools to measure it
  (preview, take manual control, test move, capture) live here too, each with a
  "why disabled" line.

  ## API

  Render with `live_component`:

      <.live_component
        module={TreninoWeb.DialCalibrationComponent}
        id={"dial-calibration-\#{axis.id}"}
        axis={axis}
      />

    * `axis` (required) - the `%Trenino.Hardware.StepperAxis{}`. Only its id is trusted;
      limits and the stored calibration are reloaded on every update.
    * `snapshot` (optional) - a `StepperManager.snapshot/1` result. Defaults to a fresh
      snapshot for the axis's device. Pass it to keep the component in step with the
      parent's `{:stepper_updated, ...}` stream.

  Sent to the parent LiveView after a successful save:
  `{:dial_calibration_saved, %Trenino.Hardware.DialCalibration{}}`.

  Nothing here moves hardware except the explicit "Move to test value" button, which
  needs a manual lease taken in this component. Saving never moves the motor.
  """
  use TreninoWeb, :live_component
  alias Phoenix.HTML.Form
  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, StepperManager, StepperPresets}
  alias Trenino.Train.GaugeMapper
  alias TreninoWeb.GaugeFeedback

  @unit_options [
    {"Raw (no conversion)", :raw},
    {"m/s", :mps},
    {"km/h", :kmh},
    {"mph", :mph}
  ]

  @doc "Unit choices shared with other gauge forms: `{label, unit}`."
  @spec unit_options() :: [{String.t(), atom()}]
  def unit_options, do: @unit_options

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:token, fn -> nil end)
      |> assign_new(:message, fn -> nil end)
      |> assign_new(:preview, fn -> nil end)
      |> assign_new(:test_value, fn -> "0" end)
      |> assign_new(:capture_value, fn -> "0" end)
      |> assign_new(:open?, fn -> false end)
      |> load()

    {:ok, assign_new(socket, :params, fn -> initial_params(socket) end) |> build_form()}
  end

  defp load(socket) do
    {:ok, axis} = Hardware.get_stepper_axis(socket.assigns.axis.id)

    calibration =
      case Hardware.get_dial_calibration(axis.id) do
        {:ok, calibration} -> calibration
        {:error, :not_found} -> nil
      end

    snapshot =
      Map.get(socket.assigns, :snapshot) || StepperManager.snapshot(axis.device_id)

    assign(socket, axis: axis, calibration: calibration, snapshot: snapshot)
  end

  defp initial_params(%{assigns: %{calibration: %DialCalibration{} = c}}) do
    %{
      "output_unit" => to_string(c.output_unit),
      "points" => Enum.map(c.points, &%{"value" => &1.value, "position" => &1.position})
    }
  end

  defp initial_params(%{assigns: %{axis: axis}}) do
    %{
      "output_unit" => "raw",
      "points" => [
        %{"value" => 0.0, "position" => axis.min_position},
        %{"value" => 100.0, "position" => axis.max_position}
      ]
    }
  end

  defp build_form(socket) do
    cs =
      socket
      |> changeset(socket.assigns.params)
      |> Map.put(:action, :validate)

    assign(socket, form: to_form(cs, as: :dial))
  end

  defp changeset(%{assigns: %{axis: axis, calibration: calibration}}, params) do
    base = calibration || %DialCalibration{stepper_axis_id: axis.id, points: []}
    DialCalibration.changeset(base, params, axis)
  end

  @impl true
  def handle_event("toggle", _, socket),
    do: {:noreply, assign(socket, :open?, not socket.assigns.open?)}

  def handle_event("starter", _, socket) do
    params = StepperPresets.class323_dial_calibration() |> stringify()
    {:noreply, change(socket, params)}
  end

  def handle_event("validate", %{"dial" => params} = all, socket) when is_map(params) do
    socket =
      assign(socket,
        test_value: Map.get(all, "test_value", socket.assigns.test_value),
        capture_value: Map.get(all, "capture_value", socket.assigns.capture_value)
      )

    {:noreply, change(socket, params)}
  end

  def handle_event("validate", _, socket), do: {:noreply, socket}

  def handle_event("point", %{"action" => action} = event, socket) do
    points = point_list(socket.assigns.params["points"] || [])

    index =
      case Integer.parse(Map.get(event, "index", "-1")) do
        {n, ""} -> n
        _ -> -1
      end

    {:noreply,
     change(socket, Map.put(socket.assigns.params, "points", edit_points(points, action, index)))}
  end

  def handle_event("submit", %{"dial" => params} = all, socket) when is_map(params) do
    socket =
      socket
      |> change(params)
      |> assign(
        test_value: all["test_value"] || "0",
        capture_value: all["capture_value"] || "0"
      )

    case all["intent"] do
      "preview" -> {:noreply, preview(socket, all["test_value"], false)}
      "test" -> {:noreply, preview(socket, all["test_value"], true)}
      "capture" -> {:noreply, capture(socket, all["capture_value"])}
      _ -> {:noreply, save(socket, params)}
    end
  end

  def handle_event("claim", _, socket) do
    case StepperManager.claim_manual(socket.assigns.axis.id, self()) do
      {:ok, token} ->
        {:noreply,
         assign(socket,
           token: token,
           message:
             "Manual control taken. Automatic output remains paused until you Resume train control in the axis controls."
         )}

      error ->
        {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  # Gives the lease back without saving, so Resume train control works again.
  def handle_event("release", _, %{assigns: %{token: nil}} = socket), do: {:noreply, socket}

  def handle_event("release", _, socket) do
    result = release(socket)

    message =
      if result in [:ok, {:error, :invalid_lease}],
        do: "Manual control released. Use Resume train control in the axis controls to continue.",
        else: GaugeFeedback.result(result)

    {:noreply, assign(socket, token: nil, message: message)}
  end

  def handle_event(_, _, socket),
    do: {:noreply, assign(socket, :message, "Enter valid calibration values before continuing.")}

  # Editing points or the unit withdraws the review: the operator must tick it again.
  defp change(socket, params) do
    params =
      if signature(params) == signature(socket.assigns.params),
        do: params,
        else: Map.put(params, "reviewed", "false")

    socket |> assign(:params, params) |> build_form()
  end

  defp signature(params) do
    points =
      params
      |> Map.get("points", [])
      |> point_list()
      |> Enum.map(&{to_string(&1["value"]), to_string(&1["position"])})

    {to_string(params["output_unit"]), points}
  end

  defp preview(socket, raw, move?) do
    cs = changeset(socket, socket.assigns.params)

    with {:ok, value} <- number(raw),
         true <- cs.valid?,
         {:ok, mapped} <-
           GaugeMapper.dial_target(Ecto.Changeset.apply_changes(cs), value, :clamp) do
      result =
        if move?,
          do:
            StepperManager.command(
              socket.assigns.axis.id,
              :move_to,
              %{position: mapped.target},
              socket.assigns.token
            ),
          else: :preview_only

      assign(socket, preview: mapped, message: GaugeFeedback.result(result))
    else
      false -> assign(socket, :message, "Fix the calibration points first.")
      error -> assign(socket, :message, GaugeFeedback.result(error))
    end
  end

  defp capture(socket, raw) do
    axis = socket.assigns.axis

    with {:ok, value} <- number(raw),
         true <- socket.assigns.token != nil,
         %{status: %{known: true, state: :idle} = status, updated_at: at} <-
           StepperManager.snapshot(axis.device_id).axes[axis.id],
         true <- System.monotonic_time(:millisecond) - at < 1500 do
      point = %{"value" => Float.round(value, 2), "position" => status.position}
      points = point_list(socket.assigns.params["points"]) ++ [point]
      change(socket, Map.put(socket.assigns.params, "points", points))
    else
      _ ->
        assign(
          socket,
          :message,
          "Capture requires manual control and a fresh stationary known estimate."
        )
    end
  end

  defp save(socket, params) do
    case Hardware.save_dial_calibration(socket.assigns.axis, params) do
      {:ok, calibration} ->
        send(self(), {:dial_calibration_saved, calibration})
        release(socket)

        socket
        |> assign(
          token: nil,
          calibration: calibration,
          message: saved_message(calibration)
        )
        |> assign(:params, initial_params(%{assigns: %{calibration: calibration}}))
        |> build_form()

      {:error, cs} ->
        assign(socket, form: to_form(%{cs | action: :validate}, as: :dial))
    end
  end

  defp saved_message(%DialCalibration{reviewed: true}),
    do: "Dial saved and reviewed. Gauges on this axis can be enabled."

  defp saved_message(%DialCalibration{}),
    do:
      "Dial saved but not reviewed: gauges on this axis stay disabled until you review it. Nothing moved."

  defp release(%{assigns: %{token: nil}}), do: :ok

  defp release(%{assigns: %{token: token, axis: axis}}),
    do: StepperManager.release_manual(axis.id, token)

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

  defp stringify(map) do
    Map.new(map, fn
      {k, v} when is_atom(v) -> {to_string(k), to_string(v)}
      {k, v} when is_list(v) -> {to_string(k), Enum.map(v, &stringify/1)}
      {k, v} -> {to_string(k), v}
    end)
  end

  # Why each measuring control is unavailable (nil when it is available).
  defp measure_reasons(snapshot, axis, token) do
    runtime = snapshot.axes[axis.id]

    if snapshot.lifecycle == :disconnected do
      reason =
        "The device is not connected. Connect it and Apply the saved axis configuration first."

      %{claim: reason, move: reason, capture: reason}
    else
      held? = token != nil

      %{
        claim: nil,
        move: if(held?, do: reference_reason(runtime), else: "Take manual control first."),
        capture: if(held?, do: capture_reason(runtime), else: "Take manual control first.")
      }
    end
  end

  defp reference_reason(%{ready: true}), do: nil

  defp reference_reason(_),
    do: "The axis has no reference yet. Set it in the axis controls above, then come back."

  defp capture_reason(runtime) do
    cond do
      reason = reference_reason(runtime) ->
        reason

      runtime.status == nil or runtime.status.state != :idle ->
        "Wait for the needle to stop. Capture needs a fresh, stationary position."

      true ->
        nil
    end
  end

  defp review_reason(form) do
    if form[:points].errors != [], do: "Fix the calibration points first.", else: nil
  end

  defp checked?(field), do: Form.normalize_value("checkbox", field.value)

  defp status_label(nil), do: "No dial calibration yet"
  defp status_label(%DialCalibration{valid: false}), do: "Needs re-measuring (axis changed)"
  defp status_label(%DialCalibration{reviewed: false}), do: "Saved, not reviewed"
  defp status_label(%DialCalibration{}), do: "Calibrated and reviewed"

  attr :id, :string, required: true
  attr :reason, :string, default: nil

  defp why_disabled(assigns) do
    ~H"""
    <p :if={@reason} id={@id} class="text-xs text-warning">Unavailable: {@reason}</p>
    """
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:reasons, measure_reasons(assigns.snapshot, assigns.axis, assigns.token))
      |> assign(:unit_options, @unit_options)

    ~H"""
    <div id={@id} class="border-t border-base-300 pt-3 space-y-3">
      <div class="flex justify-between items-center gap-2">
        <p class="text-sm">
          <span class="font-medium">Dial calibration:</span>
          <span id={"#{@id}-status"}>{status_label(@calibration)}</span>
        </p>
        <button
          id={"#{@id}-toggle"}
          type="button"
          phx-click="toggle"
          phx-target={@myself}
          class="btn btn-sm"
        >{if @open?, do: "Close", else: "Calibrate dial"}</button>
      </div>
      <p :if={@message && !@open?} role="status" class="text-sm">{@message}</p>
      <.form
        :if={@open?}
        for={@form}
        id={"#{@id}-form"}
        phx-change="validate"
        phx-submit="submit"
        phx-target={@myself}
        class="space-y-3"
      >
        <p class="text-sm">
          The dial belongs to this axis: every train gauge on it uses these points. Record
          2–32 dial readings and the needle position for each. Preview never moves hardware.
        </p>
        <button
          id={"#{@id}-starter"}
          type="button"
          phx-click="starter"
          phx-target={@myself}
          class="btn btn-sm btn-ghost"
        >Fill with Class 323 speedometer starter</button>
        <p class="text-xs text-warning">
          The starter is an unverified estimate (0–100 mph, about 240°, 720 transitions). Measure the real dial.
        </p>
        <.input
          field={@form[:output_unit]}
          type="select"
          label="Dial shows"
          options={@unit_options}
        />
        <div id={"#{@id}-points"} class="space-y-2">
          <p class="font-medium">Measured points: dial value → estimated transitions</p>
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
        <div id={"#{@id}-preview"} class="space-y-2 border-t border-base-300 pt-3">
          <.input
            name="test_value"
            id={"#{@id}-test-input"}
            value={@test_value}
            type="number"
            step="0.01"
            label="Test dial value"
          />
          <button
            id={"#{@id}-preview-only"}
            type="submit"
            name="intent"
            value="preview"
            class="btn btn-sm"
          >Preview only</button>
          <p :if={@preview} id={"#{@id}-preview-result"}>
            Dial value: {Float.round(@preview.value, 2)} · estimated target: {@preview.target} · clamped: {@preview.clamped}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <button
              id={"#{@id}-claim"}
              type="button"
              phx-click="claim"
              phx-target={@myself}
              class="btn btn-sm"
              disabled={@reasons.claim != nil}
            >Take manual control</button>
            <button
              :if={@token}
              id={"#{@id}-release"}
              type="button"
              phx-click="release"
              phx-target={@myself}
              class="btn btn-sm"
            >Release manual control</button>
            <button
              id={"#{@id}-test-value"}
              type="submit"
              name="intent"
              value="test"
              class="btn btn-sm"
              disabled={@reasons.move != nil}
            >Move to test value</button>
          </div>
          <.why_disabled id={"#{@id}-claim-reason"} reason={@reasons.claim} />
          <.why_disabled
            :if={is_nil(@reasons.claim)}
            id={"#{@id}-test-reason"}
            reason={@reasons.move}
          />
          <.input
            name="capture_value"
            id={"#{@id}-capture-input"}
            value={@capture_value}
            type="number"
            step="0.01"
            label="Actual dial reading to capture"
          />
          <button
            id={"#{@id}-capture"}
            type="submit"
            name="intent"
            value="capture"
            class="btn btn-sm"
            disabled={@reasons.capture != nil}
          >Capture stationary estimated position</button>
          <.why_disabled
            :if={is_nil(@reasons.claim)}
            id={"#{@id}-capture-reason"}
            reason={@reasons.capture}
          />
          <p :if={@message} role="status" class="text-sm">{@message}</p>
        </div>
        <div class="space-y-2 border-t border-base-300 pt-3">
          <.input
            field={@form[:reviewed]}
            type="checkbox"
            label="I reviewed these measured points for this axis and stepping mode"
            disabled={review_reason(@form) != nil}
          />
          <.why_disabled id={"#{@id}-review-reason"} reason={review_reason(@form)} />
          <p class="text-xs">
            Saving never moves the motor. A dial that is saved without review (or whose axis mode or limits later change) leaves every gauge on this axis disabled until it is reviewed again.
          </p>
          <button
            id={"#{@id}-save"}
            type="submit"
            name="intent"
            value="save"
            class="btn btn-primary btn-sm"
          >{if checked?(@form[:reviewed]), do: "Save reviewed dial", else: "Save dial (unreviewed)"}</button>
        </div>
      </.form>
    </div>
    """
  end
end
