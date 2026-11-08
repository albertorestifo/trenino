defmodule TreninoWeb.GaugeCalibrationComponent do
  @moduledoc """
  Calibrates a gauge's dial by hand: move the needle to a step position, read the
  printed dial, and record "this position shows this value". The firmware gives no
  feedback, so the operator's eyes are the measurement.

  Opening the panel takes manual control of the gauge (`GaugeController.hold_manual/2`,
  owned by this LiveView process) and parks the needle at 0, so the position shown is the
  position the needle is at and an active train does not fight the panel. It parks again
  whenever the gauge re-zeros under it (a new configuration, or the device coming back).
  Closing the panel or the page hands the gauge back to the train.
  """
  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train.GaugeController
  alias TreninoWeb.GaugeFeedback

  @impl true
  def update(assigns, socket) do
    first? = not Map.has_key?(socket.assigns, :gauge)
    previous_link = socket.assigns[:link]
    previous_epoch = socket.assigns[:zero_epoch]
    socket = assign(socket, assigns)

    socket =
      if first? do
        calibration = socket.assigns.gauge.dial_calibration

        assign(socket,
          position: 0,
          points: points(calibration),
          unit:
            if(match?(%DialCalibration{}, calibration), do: calibration.output_unit, else: :raw),
          message: nil,
          error: nil
        )
      else
        socket
      end

    # The firmware zeros the gauge on every new configuration and at boot, forgetting
    # where the panel put it. Park it at 0 again so the shown position stays true.
    rezeroed? =
      first? or socket.assigns[:zero_epoch] != previous_epoch or
        (match?({:ok, _}, socket.assigns.link) and not match?({:ok, _}, previous_link))

    {:ok, if(rezeroed?, do: park(socket, first?), else: socket)}
  end

  defp park(socket, first?) do
    socket = assign(socket, :position, 0)

    case socket.assigns.link do
      {:ok, _port} ->
        message = if first?, do: nil, else: "The gauge re-zeroed, so the needle is back at 0."
        move(assign(socket, :message, message), 0, message)

      _ ->
        socket
    end
  end

  defp points(%DialCalibration{points: points}),
    do: Enum.map(points, &%{value: &1.value, position: &1.position})

  defp points(_), do: []

  @impl true
  def handle_event("move", %{"position" => position}, socket),
    do: {:noreply, move(socket, parse_int(position, socket.assigns.position))}

  def handle_event("nudge", %{"by" => by}, socket),
    do: {:noreply, move(socket, socket.assigns.position + parse_int(by, 0))}

  def handle_event("goto", %{"index" => index}, socket) do
    case point_at(socket.assigns.points, index) do
      %{position: position} -> {:noreply, move(socket, position)}
      nil -> {:noreply, socket}
    end
  end

  def handle_event("zero", _, socket) do
    gauge = socket.assigns.gauge

    result =
      with {:ok, port} <- socket.assigns.link,
           :ok <- GaugeController.hold_manual(gauge.id, owner: self()),
           do: Hardware.zero_gauge(port, gauge)

    {:noreply, feedback(socket, result, "Zeroing: the needle sweeps to its stop and comes back.")}
  end

  def handle_event("add_point", %{"value" => value}, socket) do
    case Float.parse(String.trim(value)) do
      {number, ""} ->
        point = %{value: Float.round(number, 2), position: socket.assigns.position}

        points =
          socket.assigns.points
          |> Enum.reject(&(&1.value == point.value))
          |> Kernel.++([point])
          |> Enum.sort_by(& &1.value)

        {:noreply, assign(socket, points: points, error: nil, message: nil)}

      _ ->
        {:noreply, assign(socket, :error, "Enter the number the dial shows.")}
    end
  end

  def handle_event("remove", %{"index" => index}, socket) do
    case point_index(socket.assigns.points, index) do
      nil ->
        {:noreply, socket}

      i ->
        {:noreply, assign(socket, points: List.delete_at(socket.assigns.points, i), message: nil)}
    end
  end

  def handle_event("unit", %{"unit" => unit}, socket) do
    unit =
      Enum.find_value(GaugeFeedback.unit_options(), socket.assigns.unit, fn {_, u} ->
        to_string(u) == unit && u
      end)

    {:noreply, assign(socket, unit: unit, message: nil)}
  end

  def handle_event("save", %{"reviewed" => reviewed}, socket) do
    attrs = %{
      output_unit: socket.assigns.unit,
      points: socket.assigns.points,
      reviewed: reviewed == "true"
    }

    case Hardware.save_dial_calibration(socket.assigns.gauge, attrs) do
      {:ok, calibration} ->
        send(self(), {:dial_calibration_saved, calibration})

        message =
          if calibration.reviewed,
            do: "Dial saved and reviewed. Train gauge bindings on this gauge can be enabled.",
            else: "Dial saved. Review it against the real dial before enabling bindings."

        {:noreply, assign(socket, message: message, error: nil)}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, error: changeset_error(cs), message: nil)}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  # A point index from the page, or nil when it is not one of the listed points.
  defp point_index(points, index) do
    case Integer.parse(to_string(index)) do
      {i, ""} when i >= 0 and i < length(points) -> i
      _ -> nil
    end
  end

  defp point_at(points, index) do
    case point_index(points, index) do
      nil -> nil
      i -> Enum.at(points, i)
    end
  end

  defp move(socket, position, message \\ nil) do
    gauge = socket.assigns.gauge
    position = position |> max(0) |> min(gauge.travel)

    result =
      with {:ok, port} <- socket.assigns.link,
           :ok <- GaugeController.hold_manual(gauge.id, owner: self()),
           do: Hardware.set_gauge_position(port, gauge, position)

    socket |> assign(:position, position) |> feedback(result, message)
  end

  defp feedback(socket, :ok, message), do: assign(socket, message: message, error: nil)

  defp feedback(socket, error, _message),
    do: assign(socket, error: GaugeFeedback.result(error), message: nil)

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp changeset_error(cs) do
    cs
    |> Ecto.Changeset.traverse_errors(&translate_error/1)
    |> Map.get(:points, ["Check the dial points."])
    |> List.first()
    |> then(&"Points #{&1}.")
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        connected?: match?({:ok, _}, assigns.link),
        unit_options: GaugeFeedback.unit_options(),
        degrees: degrees(assigns.gauge, assigns.position)
      )

    ~H"""
    <section
      id={"gauge-calibration-panel-#{@gauge.id}"}
      class="space-y-4 border-t border-base-300 pt-3"
    >
      <div class="flex items-center justify-between gap-2">
        <h5 class="font-semibold">Calibrate the dial</h5>
        <button
          type="button"
          id={"gauge-calibration-close-#{@gauge.id}"}
          phx-click="close_calibration"
          phx-target={@close_target}
          class="btn btn-ghost btn-xs text-xs"
        >
          <.icon name="hero-check" class="size-4" /> Done
        </button>
      </div>
      <div :if={not @connected?} role="alert" class="alert alert-soft alert-warning text-sm">
        <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
        <p>{GaugeFeedback.result(@link)} You can still edit and save the points.</p>
      </div>
      <p :if={@connected?} class="text-sm text-muted">
        The needle starts at 0. Move it onto a printed mark, type the value that mark shows and add it. Train data is paused for this gauge until you press Done.
      </p>

      <form
        id={"gauge-position-#{@gauge.id}"}
        phx-change="move"
        phx-submit="move"
        phx-target={@myself}
        class="space-y-2"
      >
        <label for={"gauge-position-range-#{@gauge.id}"} class="text-sm">
          Needle position: <span class="font-mono">{@position}</span>
          <span class="text-muted">of <span class="font-mono">{@gauge.travel}</span>
          steps (about <span class="tabular-nums">{@degrees}</span>°)</span>
        </label>
        <input
          type="range"
          id={"gauge-position-range-#{@gauge.id}"}
          name="position"
          min="0"
          max={@gauge.travel}
          value={@position}
          phx-throttle="100"
          disabled={not @connected?}
          class="range range-sm range-primary w-full"
        />
      </form>
      <div class="flex flex-wrap items-center gap-1">
        <button
          :for={by <- [-10, -1, 1, 10]}
          type="button"
          id={"gauge-nudge-#{@gauge.id}-#{by}"}
          phx-click="nudge"
          phx-value-by={by}
          phx-target={@myself}
          disabled={not @connected?}
          class="btn btn-outline btn-xs text-xs font-mono"
          aria-label={"Move #{abs(by)} #{if abs(by) == 1, do: "step", else: "steps"} #{if by < 0, do: "back", else: "forward"}"}
        >
          {if by > 0, do: "+#{by}", else: by}
        </button>
        <button
          type="button"
          id={"gauge-zero-#{@gauge.id}"}
          phx-click="zero"
          phx-target={@myself}
          disabled={not @connected?}
          class="btn btn-ghost btn-xs text-xs ml-auto"
        >
          <.icon name="hero-arrow-uturn-left" class="size-4" /> Re-zero
        </button>
      </div>

      <form
        id={"gauge-add-point-#{@gauge.id}"}
        phx-submit="add_point"
        phx-target={@myself}
        class="flex items-end gap-2"
      >
        <.input
          name="value"
          id={"gauge-point-value-#{@gauge.id}"}
          value=""
          label="The dial shows"
          type="text"
          inputmode="decimal"
        />
        <button type="submit" class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="size-4" /> Add point at {@position}
        </button>
      </form>

      <form id={"gauge-unit-#{@gauge.id}"} phx-change="unit" phx-target={@myself}>
        <.input
          name="unit"
          id={"gauge-unit-select-#{@gauge.id}"}
          value={@unit}
          label="Dial unit"
          type="select"
          options={@unit_options}
        />
      </form>

      <table :if={@points != []} id={"gauge-points-#{@gauge.id}"} class="table table-sm">
        <thead>
          <tr>
            <th>Dial value</th>
            <th>Position (steps)</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{point, index} <- Enum.with_index(@points)}>
            <td class="tabular-nums">{point.value}</td>
            <td class="font-mono">{point.position}</td>
            <td class="text-right">
              <button
                type="button"
                phx-click="goto"
                phx-value-index={index}
                phx-target={@myself}
                disabled={not @connected?}
                class="btn btn-ghost btn-xs text-xs"
                aria-label={"Move the needle to #{point.value}"}
              >
                <.icon name="hero-arrow-right-circle" class="size-4" /> Go to
              </button>
              <button
                type="button"
                phx-click="remove"
                phx-value-index={index}
                phx-target={@myself}
                class="btn btn-ghost btn-xs"
                aria-label={"Remove point #{point.value}"}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p :if={@points == []} class="text-sm text-muted">
        No points yet. Add at least two, for example the lowest and highest marks.
      </p>

      <p :if={@message} role="status" class="text-sm">{@message}</p>
      <div :if={@error} role="alert" class="alert alert-soft alert-error text-sm">
        <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
        <p>{@error}</p>
      </div>

      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          id={"gauge-save-reviewed-#{@gauge.id}"}
          phx-click="save"
          phx-value-reviewed="true"
          phx-target={@myself}
          class="btn btn-primary btn-sm"
        >
          Save, dial checked
        </button>
        <button
          type="button"
          id={"gauge-save-draft-#{@gauge.id}"}
          phx-click="save"
          phx-value-reviewed="false"
          phx-target={@myself}
          class="btn btn-ghost btn-sm"
        >
          Save draft
        </button>
      </div>
    </section>
    """
  end

  # Steps per degree: VID6606 microsteps at 1/12 degree, direct drive at 1/3 degree.
  defp degrees(%Gauge{driver: :vid6606}, position), do: round(position / 12)
  defp degrees(%Gauge{driver: :direct}, position), do: round(position / 3)
end
