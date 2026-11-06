defmodule TreninoWeb.SelectorWizard do
  @moduledoc """
  Wizard for configuring a selector: a potentiometer used as a
  multi-position switch.

  Steps:

  1. **Input** - pick a calibrated analog input.
  2. **Positions** - choose how many positions, then split the range evenly
     or capture each detent with the knob. Ranges stay editable.
  3. **Actions** - what each position does when the knob enters and leaves
     it.

  Works without the simulator: endpoints and values can be typed. With the
  simulator connected, endpoints can be browsed and values read from it.

  ## Parent contract

  The parent LiveView renders this component with `element`, `train_id`,
  `client`, `sequences` and `inputs` (analog inputs with `:device` and
  `:calibration` preloaded). It must:

  - handle `{:selector_wizard_watch, input_id}` by streaming that input's raw
    readings back with `send_update(SelectorWizard, id: id, reading: raw)`
    (`reading: :offline` when the device is not connected)
  - route `{:api_explorer_select, "selector:" <> _, path}` and
    `{:api_explorer_close}` back with `explorer_event: {field, path}` and
    `explorer_event: :close`
  - handle `{:selector_wizard_saved, element_id}` and
    `{:selector_wizard_cancelled, element_id}`
  """

  use TreninoWeb, :live_component

  require Logger

  alias Trenino.Hardware.Input
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.InputNormalizer
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Train
  alias Trenino.Train.{SelectorBinding, SelectorMapper, SelectorPosition}

  @kind_options [
    {"Do nothing", "none"},
    {"Set a simulator value", "set_value"},
    {"Run a sequence", "sequence"},
    {"Tap a key", "keystroke"}
  ]

  @action_fields ~w(kind endpoint value sequence_id keystroke)

  @impl true
  def update(%{reading: raw}, socket), do: {:ok, apply_reading(socket, raw)}

  def update(%{explorer_event: event}, socket), do: {:ok, apply_explorer_event(socket, event)}

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:element, assigns.element)
      |> assign(:train_id, assigns.train_id)
      |> assign(:client, assigns.client)
      |> assign(:sequences, assigns.sequences)
      |> assign(:inputs, assigns.inputs)
      |> assign(:lever_input_ids, Map.get(assigns, :lever_input_ids, MapSet.new()))

    socket = if socket.assigns[:initialized], do: socket, else: initialize(socket)
    {:ok, socket}
  end

  defp initialize(socket) do
    binding =
      case Train.get_selector_binding(socket.assigns.element.id) do
        {:ok, binding} -> binding
        {:error, :not_found} -> nil
      end

    positions =
      if binding,
        do: Enum.map(binding.positions, &position_from_struct/1),
        else: default_positions(3)

    socket =
      socket
      |> assign(:binding, binding)
      |> assign(:positions, positions)
      |> assign(:input_id, binding && binding.input_id)
      |> assign(:step, if(binding, do: :positions, else: :input))
      |> assign(:reading, nil)
      |> assign(:offline, false)
      |> assign(:explorer_field, nil)
      |> assign(:error, nil)
      |> assign(:conflict, false)
      |> assign(:initialized, true)

    if binding, do: watch_input(binding.input_id)
    socket
  end

  defp default_positions(count) do
    count
    |> SelectorMapper.even_split()
    |> Enum.map(fn range ->
      %{
        label: "",
        input_min: format_number(range.input_min),
        input_max: format_number(range.input_max),
        detent: nil,
        enter: blank_action(),
        exit: blank_action()
      }
    end)
  end

  defp blank_action, do: Map.new(@action_fields, &{&1, if(&1 == "kind", do: "none", else: "")})

  defp position_from_struct(%SelectorPosition{} = position) do
    %{
      label: position.label || "",
      input_min: format_number(position.input_min),
      input_max: format_number(position.input_max),
      detent: nil,
      enter: action_from_struct(position, :enter),
      exit: action_from_struct(position, :exit)
    }
  end

  defp action_from_struct(%SelectorPosition{} = position, prefix) do
    Map.new(@action_fields, fn field ->
      value = Map.fetch!(position, String.to_existing_atom("#{prefix}_#{field}"))
      {field, if(is_nil(value), do: "", else: to_string(value))}
    end)
  end

  defp watch_input(input_id), do: send(self(), {:selector_wizard_watch, input_id})

  # Readings

  defp apply_reading(socket, :offline), do: assign(socket, reading: nil, offline: true)

  defp apply_reading(socket, raw) when is_integer(raw) do
    case InputNormalizer.normalize(raw, selected_calibration(socket.assigns)) do
      {:ok, value} -> assign(socket, reading: value, offline: false)
      {:error, _reason} -> assign(socket, :reading, nil)
    end
  end

  defp apply_reading(socket, _raw), do: socket

  defp selected_input(%{inputs: inputs, input_id: input_id}),
    do: Enum.find(inputs, &(&1.id == input_id))

  defp selected_calibration(assigns) do
    case selected_input(assigns) do
      %Input{calibration: %Calibration{} = calibration} -> calibration
      _ -> nil
    end
  end

  # API explorer

  defp apply_explorer_event(socket, {"selector:" <> rest, path}) do
    with [index, prefix] <- String.split(rest, ":"),
         {index, ""} <- Integer.parse(index),
         true <- prefix in ["enter", "exit"] do
      socket
      |> update_action(index, prefix, %{"endpoint" => path})
      |> assign(:explorer_field, nil)
    else
      _ -> socket
    end
  end

  defp apply_explorer_event(socket, :close), do: assign(socket, :explorer_field, nil)
  defp apply_explorer_event(socket, _event), do: socket

  # Events

  @impl true
  def handle_event("select_input", %{"input-id" => id}, socket) do
    case Integer.parse(id) do
      {input_id, ""} ->
        watch_input(input_id)

        {:noreply,
         socket
         |> assign(input_id: input_id, reading: nil, offline: false, error: nil)
         |> assign(:step, :positions)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("set_count", %{"count" => count}, socket) do
    {min, max} = SelectorBinding.position_limits()

    case Integer.parse(count) do
      {count, ""} when count >= min and count <= max ->
        {:noreply, assign(socket, positions: resize(socket.assigns.positions, count), error: nil)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("even_split", _params, socket) do
    positions = socket.assigns.positions
    ranges = SelectorMapper.even_split(length(positions))
    positions = positions |> with_ranges(ranges) |> Enum.map(&%{&1 | detent: nil})

    {:noreply, assign(socket, positions: positions, error: nil)}
  end

  def handle_event("capture", %{"index" => index}, socket) do
    with {index, ""} <- Integer.parse(index),
         value when is_float(value) <- socket.assigns.reading do
      positions = List.update_at(socket.assigns.positions, index, &%{&1 | detent: value})
      {:noreply, apply_detents(socket, positions)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_positions", %{"positions" => params}, socket) do
    positions =
      socket.assigns.positions
      |> Enum.with_index()
      |> Enum.map(fn {position, index} ->
        case Map.get(params, to_string(index)) do
          nil ->
            position

          row ->
            %{
              position
              | label: Map.get(row, "label", position.label),
                input_min: Map.get(row, "input_min", position.input_min),
                input_max: Map.get(row, "input_max", position.input_max)
            }
        end
      end)

    {:noreply, assign(socket, :positions, positions)}
  end

  def handle_event("update_positions", _params, socket), do: {:noreply, socket}

  def handle_event("update_actions", %{"positions" => params}, socket) do
    socket =
      Enum.reduce(params, socket, fn {index, row}, acc ->
        case Integer.parse(index) do
          {index, ""} ->
            acc
            |> update_action(index, "enter", Map.get(row, "enter", %{}))
            |> update_action(index, "exit", Map.get(row, "exit", %{}))

          _ ->
            acc
        end
      end)

    {:noreply, socket}
  end

  def handle_event("update_actions", _params, socket), do: {:noreply, socket}

  def handle_event("browse", %{"index" => index, "prefix" => prefix}, socket) do
    {:noreply, assign(socket, :explorer_field, "selector:#{index}:#{prefix}")}
  end

  def handle_event("close_browser", _params, socket),
    do: {:noreply, assign(socket, :explorer_field, nil)}

  def handle_event("read_value", %{"index" => index, "prefix" => prefix}, socket) do
    with {index, ""} <- Integer.parse(index),
         %{} = position <- Enum.at(socket.assigns.positions, index),
         %SimulatorClient{} = client <- socket.assigns.client,
         endpoint when endpoint != "" <- position[String.to_existing_atom(prefix)]["endpoint"] do
      case SimulatorClient.get_float(client, endpoint) do
        {:ok, value} ->
          {:noreply,
           socket
           |> update_action(index, prefix, %{"value" => format_number(value)})
           |> assign(:error, nil)}

        {:error, reason} ->
          Logger.warning("[SelectorWizard] Could not read #{endpoint}: #{inspect(reason)}")

          {:noreply,
           assign(
             socket,
             :error,
             "Could not read that value. Check the endpoint, or type the value instead."
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("go", %{"step" => step}, socket) when step in ~w(input positions actions) do
    {:noreply,
     assign(socket, step: String.to_existing_atom(step), error: nil, explorer_field: nil)}
  end

  def handle_event("save", _params, socket), do: {:noreply, save(socket, [])}

  def handle_event("save_replacing", _params, socket),
    do: {:noreply, save(socket, replace?: true)}

  def handle_event("cancel", _params, socket) do
    send(self(), {:selector_wizard_cancelled, socket.assigns.element.id})
    {:noreply, socket}
  end

  defp update_action(socket, index, prefix, changes) do
    key = String.to_existing_atom(prefix)
    changes = Map.take(changes, @action_fields)

    positions =
      List.update_at(socket.assigns.positions, index, fn position ->
        Map.update!(position, key, &Map.merge(&1, changes))
      end)

    assign(socket, :positions, positions)
  end

  # Changing the count re-splits the range evenly; existing positions keep
  # their labels and actions.
  defp resize(positions, count) do
    count
    |> default_positions()
    |> Enum.with_index(fn fresh, index ->
      case Enum.at(positions, index) do
        nil -> fresh
        old -> %{old | detent: nil}
      end
    end)
    |> with_ranges(SelectorMapper.even_split(count))
  end

  defp with_ranges(positions, ranges) do
    Enum.zip_with(positions, ranges, fn position, range ->
      %{
        position
        | input_min: format_number(range.input_min),
          input_max: format_number(range.input_max)
      }
    end)
  end

  # Once every position has a captured detent, ranges are rebuilt around them.
  defp apply_detents(socket, positions) do
    detents = Enum.map(positions, & &1.detent)

    if Enum.any?(detents, &is_nil/1) do
      assign(socket, positions: positions, error: nil)
    else
      case SelectorMapper.ranges_from_detents(detents) do
        {:ok, ranges} ->
          assign(socket, positions: with_ranges(positions, ranges), error: nil)

        {:error, :too_close} ->
          assign(
            socket,
            positions: positions,
            error:
              "Two detents are too close together. Turn the knob firmly into each detent and capture it again."
          )
      end
    end
  end

  defp save(socket, opts) do
    attrs = %{
      "input_id" => socket.assigns.input_id,
      "positions" =>
        socket.assigns.positions
        |> Enum.with_index()
        |> Enum.map(fn {position, index} -> position_attrs(position, index) end)
    }

    case Train.save_selector(socket.assigns.element.id, attrs, opts) do
      {:ok, _binding} ->
        send(self(), {:selector_wizard_saved, socket.assigns.element.id})
        socket

      {:error, :destination_conflict} ->
        assign(socket,
          conflict: true,
          error:
            "This input is mapped to the virtual joystick. Replace that mapping to use it here."
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, conflict: false, error: describe_errors(changeset))
    end
  end

  defp position_attrs(position, index) do
    actions =
      for prefix <- ["enter", "exit"],
          {field, value} <- position[String.to_existing_atom(prefix)],
          into: %{},
          do: {"#{prefix}_#{field}", blank_to_nil(value)}

    Map.merge(actions, %{
      "index" => index,
      "label" => blank_to_nil(position.label),
      "input_min" => blank_to_nil(position.input_min),
      "input_max" => blank_to_nil(position.input_max)
    })
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  # "Position 2: enter endpoint can't be blank" style messages. Positions
  # being replaced are skipped so numbers match the rows on screen.
  defp describe_errors(%Ecto.Changeset{} = changeset) do
    binding_errors =
      for {field, error} <- changeset.errors do
        prefix = if field == :positions, do: "Positions", else: humanize(field)
        "#{prefix} #{error_message(error)}"
      end

    position_errors =
      changeset.changes
      |> Map.get(:positions, [])
      |> Enum.reject(&(&1.action == :replace))
      |> Enum.flat_map(&position_errors/1)

    Enum.join(binding_errors ++ position_errors, ". ")
  end

  defp position_errors(%Ecto.Changeset{} = position) do
    number = Ecto.Changeset.get_field(position, :index) + 1

    for {field, error} <- position.errors,
        do: "Position #{number}: #{humanize(field)} #{error_message(error)}"
  end

  defp error_message({message, opts}) do
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end

  defp humanize(:input_id), do: "Input"
  defp humanize(:element_id), do: "Element"

  defp humanize(field) do
    field |> to_string() |> String.replace("_", " ") |> String.replace("input ", "range ")
  end

  # View helpers

  defp format_number(nil), do: ""
  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_number(value) when is_integer(value), do: format_number(value * 1.0)

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp parse_number(_value), do: nil

  defp live_position(%{reading: reading, positions: positions}) when is_float(reading) do
    positions
    |> Enum.with_index()
    |> Enum.find_value(fn {position, index} ->
      min = parse_number(position.input_min)
      max = parse_number(position.input_max)
      if min && max && reading >= min && reading <= max, do: index
    end)
  end

  defp live_position(_assigns), do: nil

  defp position_name(position, index) do
    if position.label in [nil, ""], do: "Position #{index + 1}", else: position.label
  end

  defp segment_style(position) do
    min = parse_number(position.input_min)
    max = parse_number(position.input_max)

    if min && max && max >= min,
      do: "left: #{min * 100}%; width: #{max(max - min, 0.005) * 100}%",
      else: "display: none"
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:kind_options, @kind_options)
      |> assign(:selected_input, selected_input(assigns))
      |> assign(:live_index, live_position(assigns))
      |> assign(:count_options, Enum.map(2..12, &{to_string(&1), to_string(&1)}))
      |> assign(:sequence_options, Enum.map(assigns.sequences, &{&1.name, to_string(&1.id)}))

    ~H"""
    <div
      id="selector-wizard-dialog"
      role="dialog"
      aria-modal="true"
      aria-labelledby="selector-wizard-title"
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      phx-window-keydown="cancel"
      phx-key="Escape"
      phx-target={@myself}
      phx-mounted={JS.focus(to: "#selector-wizard-title")}
    >
      <div
        class="absolute inset-0 bg-black/50"
        phx-click="cancel"
        phx-target={@myself}
        aria-hidden="true"
      />
      <.focus_wrap
        id="selector-wizard-focus"
        class="relative bg-base-200 rounded-xl shadow-xl w-full max-w-3xl max-h-[90vh] flex flex-col min-h-0"
      >
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <h2 id="selector-wizard-title" tabindex="-1" class="text-xl font-semibold">
                Configure {@element.name}
              </h2>
              <p class="text-sm text-muted">
                Turn a potentiometer into a switch with fixed positions.
              </p>
            </div>
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              aria-label="Close selector setup"
              class="btn btn-ghost btn-sm btn-circle shrink-0"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <ol class="flex flex-wrap gap-x-6 gap-y-2 mt-4 text-sm" aria-label="Selector setup steps">
            <li aria-current={@step == :input && "step"} class={[@step == :input && "font-semibold"]}>
              1. Input
            </li>
            <li
              aria-current={@step == :positions && "step"}
              class={[@step == :positions && "font-semibold"]}
            >
              2. Positions
            </li>
            <li
              aria-current={@step == :actions && "step"}
              class={[@step == :actions && "font-semibold"]}
            >
              3. Actions
            </li>
          </ol>
        </div>

        <div :if={@error} id="selector-wizard-error" role="alert" class="px-4 pt-4">
          <div class="alert alert-soft alert-error text-sm">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
            <span>{@error}</span>
            <button
              :if={@conflict}
              type="button"
              id="selector-replace-mapping"
              phx-click="save_replacing"
              phx-target={@myself}
              class="btn btn-sm btn-primary"
            >
              Replace mapping
            </button>
          </div>
        </div>

        <div :if={@step == :input} class="p-4 sm:p-6 overflow-y-auto space-y-3">
          <h3 class="font-semibold">Choose the potentiometer</h3>
          <p :if={@inputs == []} class="text-sm">
            Add an analog input to a hardware configuration first.
            <.link navigate={~p"/"} class="link">Open hardware configurations</.link>
          </p>
          <button
            :for={input <- @inputs}
            id={"selector-input-#{input.id}"}
            type="button"
            phx-click="select_input"
            phx-value-input-id={input.id}
            phx-target={@myself}
            disabled={is_nil(input.calibration)}
            aria-describedby={is_nil(input.calibration) && "selector-input-#{input.id}-hint"}
            class={[
              "w-full p-4 rounded-lg border text-left hover:bg-base-200 disabled:opacity-60 disabled:cursor-not-allowed focus-visible:outline-2 focus-visible:outline-primary",
              if(input.id == @input_id, do: "border-primary", else: "border-base-300")
            ]}
          >
            <span class="block font-medium break-words">{input.name || "Analog input"}</span>
            <span class="block text-xs text-muted">
              {input.device.name} · pin <span class="font-mono">{input.pin}</span>
            </span>
            <span
              :if={is_nil(input.calibration)}
              id={"selector-input-#{input.id}-hint"}
              class="block text-xs text-muted mt-1"
            >
              Calibrate this input on its hardware page first.
            </span>
            <span
              :if={input.calibration && MapSet.member?(@lever_input_ids, input.id)}
              id={"selector-input-#{input.id}-lever"}
              class="block text-xs text-warning mt-1"
            >
              Also drives a lever on this train. Both will react when it moves.
            </span>
          </button>
        </div>

        <div :if={@step == :positions} class="p-4 sm:p-6 overflow-y-auto space-y-4">
          <h3 class="font-semibold">Define the positions</h3>
          <p class="text-sm text-muted">
            Split the range evenly, or turn the knob into each detent and capture it. Gaps between positions are dead zones: the selector keeps its last position there.
          </p>

          <div id="selector-live" class="bg-base-100 rounded-lg p-3 space-y-2" aria-live="polite">
            <div class="flex flex-wrap items-center justify-between gap-2 text-sm">
              <span :if={@reading}>
                Reading <span class="font-mono">{format_number(@reading)}</span>
                · {if @live_index,
                  do: "in #{position_name(Enum.at(@positions, @live_index), @live_index)}",
                  else: "in a dead zone"}
              </span>
              <span :if={is_nil(@reading) and @offline} class="text-muted">
                The device is not connected. Connect it to capture detents.
              </span>
              <span :if={is_nil(@reading) and not @offline} class="text-muted">
                Move the knob to see its reading.
              </span>
            </div>
            <div class="relative h-6 rounded bg-base-300" role="img" aria-label="Position ranges">
              <div
                :for={{position, index} <- Enum.with_index(@positions)}
                class={[
                  "absolute inset-y-0 rounded",
                  if(index == @live_index, do: "bg-primary", else: "bg-primary/40")
                ]}
                style={segment_style(position)}
              />
              <div
                :if={@reading}
                class="absolute inset-y-0 w-0.5 bg-base-content"
                style={"left: #{@reading * 100}%"}
              />
            </div>
          </div>

          <div class="flex flex-wrap items-end gap-3">
            <.form
              for={to_form(%{})}
              id="selector-count-form"
              phx-change="set_count"
              phx-target={@myself}
            >
              <.input
                id="selector-count"
                type="select"
                name="count"
                label="Positions"
                value={to_string(length(@positions))}
                options={@count_options}
              />
            </.form>
            <button
              type="button"
              id="selector-even-split"
              phx-click="even_split"
              phx-target={@myself}
              class="btn btn-outline btn-sm mb-2"
            >
              Split evenly
            </button>
          </div>

          <.form
            for={to_form(%{})}
            id="selector-positions-form"
            phx-change="update_positions"
            phx-target={@myself}
          >
            <div class="overflow-x-auto">
              <table class="table table-sm bg-base-100 rounded-lg">
                <thead>
                  <tr class="bg-base-200">
                    <th>#</th>
                    <th>Label</th>
                    <th>From</th>
                    <th>To</th>
                    <th>Detent</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={{position, index} <- Enum.with_index(@positions)}
                    id={"selector-position-#{index}"}
                    class={[index == @live_index && "bg-primary/10"]}
                  >
                    <td class="tabular-nums">{index + 1}</td>
                    <td>
                      <.input
                        id={"selector-position-#{index}-label"}
                        name={"positions[#{index}][label]"}
                        value={position.label}
                        placeholder={"Position #{index + 1}"}
                        aria-label={"Label of position #{index + 1}"}
                        class="input input-sm w-full"
                      />
                    </td>
                    <td>
                      <.input
                        id={"selector-position-#{index}-min"}
                        type="number"
                        step="0.01"
                        min="0"
                        max="1"
                        name={"positions[#{index}][input_min]"}
                        value={position.input_min}
                        aria-label={"Start of position #{index + 1}"}
                        class="input input-sm w-24 font-mono"
                      />
                    </td>
                    <td>
                      <.input
                        id={"selector-position-#{index}-max"}
                        type="number"
                        step="0.01"
                        min="0"
                        max="1"
                        name={"positions[#{index}][input_max]"}
                        value={position.input_max}
                        aria-label={"End of position #{index + 1}"}
                        class="input input-sm w-24 font-mono"
                      />
                    </td>
                    <td>
                      <button
                        type="button"
                        id={"selector-capture-#{index}"}
                        phx-click="capture"
                        phx-value-index={index}
                        phx-target={@myself}
                        disabled={is_nil(@reading)}
                        aria-label={"Capture detent of #{position_name(position, index)}"}
                        class="btn btn-ghost btn-xs text-xs"
                      >
                        <.icon name="hero-map-pin-mini" class="w-4 h-4" />
                        {if position.detent, do: format_number(position.detent), else: "Capture"}
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </.form>
        </div>

        <div :if={@step == :actions} class="p-4 sm:p-6 overflow-y-auto space-y-4">
          <h3 class="font-semibold">Choose what each position does</h3>
          <p class="text-sm text-muted">
            Enter actions run when the knob moves into a position, exit actions when it leaves. When a train loads or the simulator reconnects, the current position's enter action runs again, except key taps.
          </p>
          <.form
            for={to_form(%{})}
            id="selector-actions-form"
            phx-change="update_actions"
            phx-target={@myself}
            class="space-y-4"
          >
            <section
              :for={{position, index} <- Enum.with_index(@positions)}
              id={"selector-actions-#{index}"}
              class="bg-base-100 rounded-lg p-4 space-y-3"
            >
              <h4 class="font-medium">{position_name(position, index)}</h4>
              <div class="grid gap-4 sm:grid-cols-2">
                <.action_fields
                  :for={{prefix, title} <- [{"enter", "When entering"}, {"exit", "When leaving"}]}
                  index={index}
                  prefix={prefix}
                  title={title}
                  action={position[String.to_existing_atom(prefix)]}
                  kind_options={@kind_options}
                  sequence_options={@sequence_options}
                  client={@client}
                  myself={@myself}
                />
              </div>
            </section>
          </.form>
          <.live_component
            :if={@client && @explorer_field}
            module={TreninoWeb.ApiExplorerComponent}
            id="selector-api-explorer"
            client={@client}
            field={@explorer_field}
            mode={:none}
            embedded={true}
          />
          <button
            :if={@explorer_field}
            type="button"
            phx-click="close_browser"
            phx-target={@myself}
            class="btn btn-ghost btn-sm"
          >
            Close browser
          </button>
        </div>

        <div class="flex flex-wrap justify-between gap-3 p-4 border-t border-base-300">
          <button
            :if={@step != :input}
            type="button"
            phx-click="go"
            phx-value-step={if @step == :actions, do: "positions", else: "input"}
            phx-target={@myself}
            class="btn btn-ghost"
          >
            Back
          </button>
          <span :if={@step == :input} />
          <button
            :if={@step == :positions}
            type="button"
            id="selector-next"
            phx-click="go"
            phx-value-step="actions"
            phx-target={@myself}
            class="btn btn-primary"
          >
            Next
          </button>
          <button
            :if={@step == :input and @selected_input}
            type="button"
            phx-click="go"
            phx-value-step="positions"
            phx-target={@myself}
            class="btn btn-primary"
          >
            Next
          </button>
          <button
            :if={@step == :actions}
            type="button"
            id="selector-save"
            phx-click="save"
            phx-target={@myself}
            class="btn btn-primary"
            phx-disable-with="Saving…"
          >
            Save selector
          </button>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :index, :integer, required: true
  attr :prefix, :string, required: true
  attr :title, :string, required: true
  attr :action, :map, required: true
  attr :kind_options, :list, required: true
  attr :sequence_options, :list, required: true
  attr :client, :any, required: true
  attr :myself, :any, required: true

  defp action_fields(assigns) do
    assigns = assign(assigns, :base, "selector-#{assigns.index}-#{assigns.prefix}")

    ~H"""
    <fieldset class="space-y-2">
      <legend class="text-sm font-medium">{@title}</legend>
      <.input
        id={"#{@base}-kind"}
        type="select"
        name={"positions[#{@index}][#{@prefix}][kind]"}
        label="Action"
        value={@action["kind"]}
        options={@kind_options}
      />
      <div :if={@action["kind"] == "set_value"} class="space-y-2">
        <.input
          id={"#{@base}-endpoint"}
          name={"positions[#{@index}][#{@prefix}][endpoint]"}
          label="Simulator endpoint"
          value={@action["endpoint"]}
          placeholder="CurrentDrivableActor/Headlights.InputValue"
          class="input w-full font-mono text-xs"
        />
        <button
          :if={@client}
          type="button"
          phx-click="browse"
          phx-value-index={@index}
          phx-value-prefix={@prefix}
          phx-target={@myself}
          class="btn btn-ghost btn-xs text-xs"
        >
          <.icon name="hero-magnifying-glass-mini" class="w-4 h-4" /> Browse simulator API
        </button>
        <.input
          id={"#{@base}-value"}
          type="number"
          step="0.01"
          name={"positions[#{@index}][#{@prefix}][value]"}
          label="Value"
          value={@action["value"]}
          class="input w-full font-mono"
        />
        <button
          :if={@client && @action["endpoint"] != ""}
          type="button"
          id={"#{@base}-read"}
          phx-click="read_value"
          phx-value-index={@index}
          phx-value-prefix={@prefix}
          phx-target={@myself}
          class="btn btn-ghost btn-xs text-xs"
        >
          <.icon name="hero-arrow-down-tray-mini" class="w-4 h-4" /> Use the simulator's current value
        </button>
      </div>
      <.input
        :if={@action["kind"] == "sequence"}
        id={"#{@base}-sequence"}
        type="select"
        name={"positions[#{@index}][#{@prefix}][sequence_id]"}
        label="Sequence"
        value={@action["sequence_id"]}
        prompt="Choose a sequence"
        options={@sequence_options}
      />
      <.input
        :if={@action["kind"] == "keystroke"}
        id={"#{@base}-keystroke"}
        name={"positions[#{@index}][#{@prefix}][keystroke]"}
        label="Key"
        value={@action["keystroke"]}
        placeholder="e.g. L or CTRL+L"
        class="input w-full font-mono"
      />
    </fieldset>
    """
  end
end
