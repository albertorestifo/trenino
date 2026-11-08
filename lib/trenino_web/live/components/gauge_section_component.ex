defmodule TreninoWeb.GaugeSectionComponent do
  @moduledoc """
  The Gauges section of a hardware configuration: one card per X27 gauge, the add/edit
  form, and the calibration panel. Saving never reaches the device; Apply sends the
  configuration and every gauge then sweeps to its end stop to zero itself.
  """
  use TreninoWeb, :live_component

  import TreninoWeb.SharedComponents

  alias Trenino.Hardware
  alias Trenino.Hardware.Gauge
  alias Trenino.Train.GaugeController
  alias TreninoWeb.{GaugeFeedback, GaugeGuidance}

  # Pin maps of the train-lever class 323 gauge driver board (rev 3): a Pro Micro over one
  # VID6606, RESET_N on D6. From the firmware's docs/GAUGE_WIRING.md.
  @board_presets [
    {"Gauge board channel A (J1)", "board_a", [8, 7, 6, 255]},
    {"Gauge board channel B (J2)", "board_b", [14, 16, 6, 255]},
    {"Gauge board channel C (J3)", "board_c", [21, 20, 6, 255]},
    {"Gauge board channel D (J4)", "board_d", [5, 4, 6, 255]}
  ]

  @driver_options [
    {"VID6606 driver chip (STEP/DIR)", :vid6606},
    {"Direct to board pins (AVR boards only)", :direct}
  ]

  @impl true
  # `:applied` means the device just stored a configuration, which re-zeros every gauge.
  def update(%{refresh: :applied}, socket),
    do: {:ok, socket |> update(:zero_epoch, &(&1 + 1)) |> refresh()}

  def update(%{refresh: _}, socket), do: {:ok, refresh(socket)}

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:editing, fn -> nil end)
     |> assign_new(:form, fn -> nil end)
     |> assign_new(:calibrating_id, fn -> nil end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:zero_epoch, fn -> 0 end)
     |> refresh()}
  end

  defp refresh(socket) do
    device_id = socket.assigns.device_id

    assign(socket,
      gauges: Hardware.list_gauges(device_id),
      link: Hardware.gauge_link(device_id)
    )
  end

  @impl true
  def handle_event("add", _, socket) do
    socket = stop_calibrating(socket)
    defaults = Gauge.defaults(:vid6606)

    gauge =
      struct(%Gauge{device_id: socket.assigns.device_id, pins: [nil, nil, 255, 255]}, defaults)

    {:noreply, edit(socket, gauge)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case own_gauge(socket, id) do
      nil -> {:noreply, assign(socket, :error, "Gauge not found.")}
      gauge -> {:noreply, socket |> stop_calibrating() |> edit(gauge)}
    end
  end

  def handle_event("cancel", _, socket), do: {:noreply, assign(socket, form: nil, editing: nil)}

  def handle_event(
        "validate",
        %{"gauge" => params} = event,
        %{assigns: %{editing: %Gauge{}}} = socket
      ) do
    preset = if event["_target"] == ["gauge", "preset"], do: params["preset"]
    params = normalize(params, socket.assigns.form, preset)

    cs =
      socket.assigns.editing
      |> Hardware.change_gauge(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event(
        "save",
        %{"gauge" => params},
        %{assigns: %{editing: %Gauge{} = gauge}} = socket
      ) do
    params = normalize(params, socket.assigns.form, nil)

    result =
      if gauge.id,
        do: Hardware.update_gauge(gauge, params),
        else: Hardware.create_gauge(socket.assigns.device_id, params)

    case result do
      {:ok, saved} ->
        send(self(), {:gauge_saved, saved})
        {:noreply, socket |> assign(form: nil, editing: nil, error: nil) |> refresh()}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :form, to_form(cs))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with %Gauge{} = gauge <- own_gauge(socket, id),
         {:ok, _} <- Hardware.delete_gauge(gauge) do
      GaugeController.release_manual(gauge.id)
      send(self(), {:gauge_saved, gauge})

      calibrating =
        if socket.assigns.calibrating_id == gauge.id, do: nil, else: socket.assigns.calibrating_id

      {:noreply, socket |> assign(calibrating_id: calibrating) |> refresh()}
    else
      error -> {:noreply, assign(socket, :error, GaugeFeedback.result(error))}
    end
  end

  def handle_event("calibrate", %{"id" => id}, socket) do
    case own_gauge(socket, id) do
      nil ->
        {:noreply, socket}

      gauge ->
        socket =
          if socket.assigns.calibrating_id != gauge.id, do: stop_calibrating(socket), else: socket

        {:noreply, assign(socket, calibrating_id: gauge.id, form: nil, editing: nil)}
    end
  end

  def handle_event("close_calibration", _, socket),
    do: {:noreply, socket |> stop_calibrating() |> refresh()}

  def handle_event(_, _, socket), do: {:noreply, socket}

  # Closing a calibration panel (or opening another) hands its gauge back to the train.
  defp stop_calibrating(%{assigns: %{calibrating_id: id}} = socket) when is_integer(id) do
    GaugeController.release_manual(id)
    assign(socket, :calibrating_id, nil)
  end

  defp stop_calibrating(socket), do: socket

  defp edit(socket, gauge),
    do:
      assign(socket,
        editing: gauge,
        form: to_form(Hardware.change_gauge(gauge, %{})),
        error: nil
      )

  defp own_gauge(socket, id),
    do: Enum.find(socket.assigns.gauges, &(to_string(&1.id) == to_string(id)))

  # The form sends pins as `pins[0..3]` and the driver. `preset` is the board preset just
  # picked (only when the preset select itself changed, so later edits to the pins are
  # kept); it fills the VID6606 pins. Switching driver swaps untouched motion defaults for
  # the new driver's. A blank optional slot is 255.
  defp normalize(params, form, preset) do
    params = Map.put(params, "pins", pins(params, driver_atom(params["driver"])))
    params = apply_preset(params, preset)
    previous = form && driver_atom(form[:driver].value)
    swap_defaults(params, previous, driver_atom(params["driver"]))
  end

  defp driver_atom(d) when d in [:direct, "direct"], do: :direct
  defp driver_atom(_), do: :vid6606

  defp pins(params, driver) do
    raw = Map.get(params, "pins", %{})

    list =
      for i <- 0..3 do
        case raw
             |> Map.get(to_string(i), "")
             |> to_string()
             |> String.trim()
             |> Integer.parse() do
          {n, ""} -> n
          _ -> blank_pin(driver, i)
        end
      end

    if driver == :vid6606, do: List.replace_at(list, 3, 255), else: list
  end

  # Required slots stay blank (nil) so the changeset reports them; optional ones are 255.
  defp blank_pin(:vid6606, i) when i in [2, 3], do: 255
  defp blank_pin(_, _), do: nil

  defp apply_preset(params, preset) do
    case Enum.find(@board_presets, fn {_, key, _} -> key == preset end) do
      {_, _, pins} -> Map.merge(params, %{"driver" => "vid6606", "pins" => pins})
      nil -> params
    end
  end

  defp swap_defaults(params, previous, driver)
       when previous in [:vid6606, :direct] and previous != driver do
    old = Gauge.defaults(previous)

    Enum.reduce(Gauge.defaults(driver), params, fn {key, value}, acc ->
      key = Atom.to_string(key)

      if to_string(acc[key]) in ["", to_string(Map.fetch!(old, String.to_existing_atom(key)))],
        do: Map.put(acc, key, value),
        else: acc
    end)
  end

  defp swap_defaults(params, _, _), do: params

  @doc false
  def pin_value(form, index) do
    case form[:pins].value do
      pins when is_list(pins) ->
        case Enum.at(pins, index) do
          255 -> ""
          nil -> ""
          pin -> pin
        end

      _ ->
        ""
    end
  end

  @doc false
  def pin_labels(:direct), do: ["Contact 1", "Contact 2", "Contact 3", "Contact 4"]
  def pin_labels(_), do: ["STEP pin", "DIR pin", "RESET_N pin (optional)"]

  @doc false
  def pins_summary(%Gauge{driver: :vid6606} = gauge) do
    [step, dir | _] = gauge.pins
    reset = Gauge.reset_pin(gauge)
    "STEP #{step} · DIR #{dir}" <> if(reset, do: " · RESET_N #{reset}", else: "")
  end

  def pins_summary(%Gauge{pins: pins}), do: "Contacts " <> Enum.join(pins, ", ")

  defp driver_label(:vid6606), do: "VID6606"
  defp driver_label(:direct), do: "Direct"

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        driver_options: @driver_options,
        board_presets: Enum.map(@board_presets, fn {label, key, _} -> {label, key} end),
        max: Hardware.max_gauges_per_device(),
        firmware: Hardware.gauge_firmware_version()
      )

    ~H"""
    <div>
      <.config_section
        id="gauges"
        title="Gauges"
        count={length(@gauges)}
        description="X27 gauge motors driven by the controller, through a VID6606 chip or straight from board pins."
        empty?={@gauges == [] and is_nil(@form)}
        empty_icon="hero-cog-6-tooth"
        empty_message="No gauges configured"
        empty_hint={"Drive a gauge needle from the sim. Needs controller firmware #{@firmware} or newer."}
      >
        <:actions>
          <.section_action
            id="gauge-add"
            label="Add gauge"
            on_click="add"
            target={@myself}
            disabled={length(@gauges) >= @max}
            disabled_reason={"A controller drives at most #{@max} gauges."}
          />
        </:actions>
        <:notice :if={@error}>
          <div role="alert" class="alert alert-soft alert-error text-sm">
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <p>{@error}</p>
          </div>
        </:notice>
        <div class="space-y-4">
          <.form
            :if={@form}
            for={@form}
            id="gauge-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-3 rounded-lg border border-base-300 bg-base-100 p-4"
          >
            <% driver = driver_atom(@form[:driver].value) %>
            <div class="grid sm:grid-cols-2 gap-3">
              <.input field={@form[:name]} label="Name" placeholder="Speedometer" />
              <.input field={@form[:driver]} label="Wiring" type="select" options={@driver_options} />
            </div>
            <.input
              :if={driver == :vid6606}
              name="gauge[preset]"
              id="gauge-preset"
              value=""
              label="Fill pins from a board"
              type="select"
              prompt="Enter pins by hand"
              options={@board_presets}
            />
            <div id="gauge-pins" class="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <.input
                :for={{label, index} <- Enum.with_index(pin_labels(driver))}
                name={"gauge[pins][#{index}]"}
                id={"gauge-pin-#{index}"}
                value={pin_value(@form, index)}
                label={label}
                type="number"
                class="w-full input font-mono"
              />
            </div>
            <p
              :for={msg <- Enum.map(@form[:pins].errors, &translate_error/1)}
              class="text-sm text-error"
            >
              Pins {msg}
            </p>
            <p
              :for={msg <- Enum.map(@form[:device_id].errors, &translate_error/1)}
              role="alert"
              class="text-sm text-error"
            >
              This controller {msg}.
            </p>
            <p class="text-xs text-muted">
              <%= if driver == :vid6606 do %>
                Configure all four channels of a VID6606 chip, even unused ones, and give them the same RESET_N pin.
              <% else %>
                Direct drive works on Pro Micro, Leonardo, Micro, Uno, Nano and Mega, up to two gauges. Not on Due or ESP32.
              <% end %>
            </p>
            <.disclosure id="gauge-form-motion" summary="Motion settings">
              <p class="text-xs text-muted">
                The defaults suit an X27 gauge. Lower the speed if the needle loses its place.
              </p>
              <div class="grid sm:grid-cols-3 gap-3">
                <.input field={@form[:travel]} label="Travel (steps)" type="number" />
                <.input field={@form[:max_speed]} label="Maximum speed (steps/s)" type="number" />
                <.input field={@form[:acceleration]} label="Acceleration (steps/s²)" type="number" />
              </div>
              <.input field={@form[:reverse]} label="Reverse direction" type="checkbox" />
            </.disclosure>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                {if @editing.id, do: "Save", else: "Add gauge"}
              </button>
              <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
                Cancel
              </button>
            </div>
          </.form>
          <article
            :for={gauge <- @gauges}
            id={"gauge-#{gauge.id}"}
            class="bg-base-100 border border-base-300 rounded-lg p-4 space-y-3 scroll-mt-36"
          >
            <% status = GaugeGuidance.dial_status(gauge) %>
            <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
              <div class="min-w-0 flex-1 basis-48">
                <h4 class="font-semibold break-words">{gauge.name}</h4>
                <p class="text-xs text-muted">
                  {driver_label(gauge.driver)} · <span class="font-mono">{pins_summary(gauge)}</span>
                  · <span class="tabular-nums">{gauge.travel}</span>
                  steps
                </p>
              </div>
              <div class="ml-auto flex shrink-0 items-center gap-1">
                <.status_chip id={"gauge-status-#{gauge.id}"} kind={status.kind} label={status.label} />
                <.row_actions
                  :if={@calibrating_id != gauge.id}
                  id={"gauge-actions-#{gauge.id}"}
                  name={gauge.name}
                >
                  <:action
                    id={"gauge-calibrate-#{gauge.id}"}
                    event="calibrate"
                    values={%{id: gauge.id}}
                    target={@myself}
                    icon="hero-adjustments-horizontal"
                    label="Calibrate"
                  />
                  <:action
                    id={"gauge-edit-#{gauge.id}"}
                    event="edit"
                    values={%{id: gauge.id}}
                    target={@myself}
                    icon="hero-pencil-square"
                    label="Edit"
                  />
                  <:action
                    id={"gauge-delete-#{gauge.id}"}
                    event="delete"
                    values={%{id: gauge.id}}
                    target={@myself}
                    kind={:danger}
                    label={"Delete #{gauge.name}"}
                    confirm={"Delete #{gauge.name}? Its dial and the train gauge bindings using it are deleted too."}
                  />
                </.row_actions>
              </div>
            </div>
            <.live_component
              :if={@calibrating_id == gauge.id}
              module={TreninoWeb.GaugeCalibrationComponent}
              id={"gauge-calibration-#{gauge.id}"}
              gauge={gauge}
              link={@link}
              zero_epoch={@zero_epoch}
              close_target={@myself}
            />
          </article>
        </div>
      </.config_section>
    </div>
    """
  end
end
