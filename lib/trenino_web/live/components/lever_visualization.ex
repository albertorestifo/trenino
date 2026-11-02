defmodule TreninoWeb.LeverVisualization do
  @moduledoc """
  Visualizations for lever notch mapping.

  The live component renders the simulator-order bar: one slot per notch in
  the order the simulator defines them. Its x-axis is the notch list, not the
  hardware travel, so it never shows a live hardware position.

  - Gates as dots, linear notches as segments
  - Highlighting for the active notch being mapped
  - Full notch descriptions (wrapping) and captured hardware ranges below
  - Ends labelled with the first and last notch descriptions

  `hardware_strip/1` renders the "Your lever" strip in physical order: each
  captured notch at its real position on the hardware travel, plus a live
  marker at the current reading.

  ## Usage

      <.live_component
        module={TreninoWeb.LeverVisualization}
        id="lever-viz"
        notches={@notches}
        captured_ranges={@captured_ranges}
        total_travel={@total_travel}
        current_notch_index={@current_notch_index}
      />

      <TreninoWeb.LeverVisualization.hardware_strip
        preview={@preview}
        current_value={@current_value}
        total_travel={@total_travel}
      />
  """

  use TreninoWeb, :live_component

  @gap_percent 1.0
  @gate_width_percent 3.0

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    notches = assigns[:notches] || []

    assigns =
      assigns
      |> assign(:notch_positions, calculate_notch_positions(assigns))
      |> assign(:label_gap, @gap_percent)
      |> assign(:first_name, notches |> List.first() |> end_name(0))
      |> assign(:last_name, notches |> List.last() |> end_name(length(notches) - 1))

    ~H"""
    <div class="w-full py-4">
      <div class="text-sm font-medium mb-1">Simulator notches (in simulator order)</div>

      <%!-- Main visualization container --%>
      <div class="relative h-12 mx-4">
        <%!-- Background track --%>
        <div class="absolute top-1/2 left-0 right-0 h-2 -translate-y-1/2 bg-base-300 rounded-full" />

        <%!-- Notch markers --%>
        <div
          :for={{notch_data, idx} <- Enum.with_index(@notch_positions)}
          class="absolute top-1/2 -translate-y-1/2"
          style={"left: #{notch_data.left}%; width: #{notch_data.width}%;"}
        >
          <.notch_marker
            notch={notch_data.notch}
            index={idx}
            is_active={idx == @current_notch_index}
            is_captured={notch_data.is_captured}
            width_percent={notch_data.width}
            event_target={assigns[:event_target]}
          />
        </div>
      </div>

      <%!-- Labels row: equal slots matching the marker layout --%>
      <div class="flex mx-4 mt-2" style={"column-gap: #{@label_gap}%;"}>
        <div
          :for={{notch_data, idx} <- Enum.with_index(@notch_positions)}
          class="flex-1 min-w-0 text-center"
        >
          <.notch_label
            notch={notch_data.notch}
            index={idx}
            captured_range={notch_data.captured_range}
            is_active={idx == @current_notch_index}
            total_travel={@total_travel}
          />
        </div>
      </div>

      <%!-- End labels: simulator notch names, not hardware ends --%>
      <div
        :if={@notch_positions != []}
        class="flex justify-between gap-4 mx-4 mt-2 text-xs text-base-content/60"
      >
        <span>← {@first_name}</span>
        <span class="text-right">{@last_name} →</span>
      </div>
    </div>
    """
  end

  # Notch marker component
  attr :notch, :map, required: true
  attr :index, :integer, required: true
  attr :is_active, :boolean, default: false
  attr :is_captured, :boolean, default: false
  attr :width_percent, :float, required: true
  attr :event_target, :any, default: nil

  defp notch_marker(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event_target && "go_to_notch"}
      phx-value-index={@index}
      phx-target={@event_target}
      title={notch_name(@notch, @index)}
      aria-label={"Go to notch #{@index + 1}: #{notch_name(@notch, @index)}"}
      class={[
        "w-full h-full transition-all",
        @event_target &&
          "cursor-pointer hover:opacity-80 focus:outline-none focus:ring-2 focus:ring-primary/50 rounded",
        !@event_target && "cursor-default"
      ]}
    >
      <div
        :if={@notch.type == :gate}
        class={[
          "mx-auto w-4 h-4 rounded-full transition-all",
          marker_color(@is_active, @is_captured),
          @is_active && "ring-4 ring-primary/30 scale-110"
        ]}
      />

      <div
        :if={@notch.type == :linear}
        class={[
          "w-full h-2 rounded transition-all",
          marker_color(@is_active, @is_captured),
          @is_active && "ring-2 ring-primary/30 scale-y-125"
        ]}
      />
    </button>
    """
  end

  defp marker_color(true, _), do: "bg-primary"
  defp marker_color(false, true), do: "bg-success"
  defp marker_color(false, false), do: "bg-base-content/30"

  # Notch label component
  attr :notch, :map, required: true
  attr :index, :integer, required: true
  attr :captured_range, :map, default: nil
  attr :is_active, :boolean, default: false
  attr :total_travel, :integer, required: true

  defp notch_label(assigns) do
    ~H"""
    <div class={[
      "text-xs leading-tight",
      @is_active && "text-primary font-medium",
      not @is_active && "text-base-content/60"
    ]}>
      <div class="font-medium break-words" title={notch_name(@notch, @index)}>
        {notch_name(@notch, @index)}
      </div>
      <div :if={@captured_range} class="font-mono text-[10px] text-base-content/60 mt-0.5">
        {format_range(@captured_range, @total_travel)}
      </div>
    </div>
    """
  end

  @doc """
  Renders the "Your lever" strip: captured notches in physical (hardware)
  order, placed at their real `min_pct..max_pct`, with a live marker at the
  current reading.

  `preview` is the `mapping_state.preview` map from the notch mapping session.
  """
  attr :preview, :map, required: true
  attr :current_value, :integer, default: nil
  attr :total_travel, :integer, default: nil
  attr :current_notch_index, :integer, default: nil

  def hardware_strip(assigns) do
    assigns =
      assigns
      |> assign(:segments, Enum.map(assigns.preview[:hardware_ranges] || [], &strip_segment/1))
      |> assign(:live_pct, live_percent(assigns.current_value, assigns.total_travel))

    ~H"""
    <div class="w-full py-4" data-role="hardware-strip">
      <div class="flex flex-wrap items-center justify-between gap-2 mb-1">
        <span class="text-sm font-medium">Your lever</span>
        <span
          :if={@preview[:direction_known] && @preview[:inverted]}
          class="badge badge-warning badge-sm gap-1"
        >
          <.icon name="hero-arrows-right-left" class="w-3 h-3" /> Reversed vs. simulator
        </span>
        <span
          :if={@preview[:direction_known] && !@preview[:inverted]}
          class="badge badge-ghost badge-sm"
        >
          Same direction as simulator
        </span>
        <span :if={!@preview[:direction_known]} class="text-xs text-base-content/60">
          Direction is detected after you capture a second notch
        </span>
      </div>

      <div class="relative h-10 mx-4">
        <div class="absolute top-1/2 left-0 right-0 h-2 -translate-y-1/2 bg-base-300 rounded-full" />

        <div
          :for={segment <- @segments}
          class={[
            "absolute top-1/2 -translate-y-1/2 rounded",
            segment.type == :gate && "h-4",
            segment.type != :gate && "h-2",
            segment.notch_index == @current_notch_index && "bg-primary",
            segment.notch_index != @current_notch_index && "bg-success"
          ]}
          style={"left: #{segment.left}%; width: #{segment.width}%;"}
          title={segment.label}
        />

        <div
          :if={@live_pct}
          class="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-1 h-8 bg-primary rounded-full shadow-lg transition-[left] duration-75"
          style={"left: #{@live_pct}%;"}
          title={"Lever now at #{round(@live_pct)}%"}
        >
          <div class="absolute -top-1 left-1/2 -translate-x-1/2 w-3 h-3 bg-primary rounded-full" />
        </div>
      </div>

      <ul class="sr-only">
        <li :for={segment <- @segments}>{segment.label}</li>
        <li :if={@live_pct}>Lever now at {round(@live_pct)}%</li>
      </ul>

      <div class="flex justify-between gap-4 mx-4 mt-2 text-xs">
        <div>
          <div class="text-base-content/60">Low end (0%)</div>
          <div :if={@preview[:low_end]} class="font-medium">
            {display_name(@preview.low_end.description, @preview.low_end.notch_index)}
          </div>
        </div>
        <div class="text-right">
          <div class="text-base-content/60">High end (100%)</div>
          <div :if={@preview[:high_end]} class="font-medium">
            {display_name(@preview.high_end.description, @preview.high_end.notch_index)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp strip_segment(range) do
    min_pct = clamp_pct(range.min_pct)
    max_pct = clamp_pct(range.max_pct)
    width = max_pct - min_pct

    {left, width} =
      if width < @gate_width_percent do
        center = (min_pct + max_pct) / 2
        left = center - @gate_width_percent / 2
        {clamp_pct(min(left, 100.0 - @gate_width_percent)), @gate_width_percent}
      else
        {min_pct, width}
      end

    %{
      notch_index: range.notch_index,
      type: range.type,
      left: Float.round(left / 1, 2),
      width: Float.round(width / 1, 2),
      label:
        "#{display_name(range.description, range.notch_index)}: #{round(min_pct)}–#{round(max_pct)}% of travel"
    }
  end

  defp live_percent(value, total) when is_number(value) and is_number(total) and total > 0 do
    Float.round(clamp_pct(value / total * 100.0), 2)
  end

  defp live_percent(_, _), do: nil

  defp clamp_pct(value), do: value |> max(0.0) |> min(100.0)

  defp end_name(nil, _index), do: nil
  defp end_name(notch, index), do: notch_name(notch, index)

  defp notch_name(notch, index), do: display_name(Map.get(notch, :description), index)

  @doc """
  Returns a notch's description, or "Notch N" (1-based) when it has none.
  """
  @spec display_name(String.t() | nil, non_neg_integer()) :: String.t()
  def display_name(desc, _index) when is_binary(desc) and desc != "", do: desc
  def display_name(_desc, index), do: "Notch #{index + 1}"

  defp calculate_notch_positions(assigns) do
    notches = assigns[:notches] || []
    captured_ranges = assigns[:captured_ranges] || []
    total_count = length(notches)

    if total_count == 0 do
      []
    else
      total_gap_percent = (total_count - 1) * @gap_percent
      available_percent = 100.0 - total_gap_percent

      # Each notch gets an equal slot: this axis is notch order, not hardware travel
      notch_width = available_percent / total_count

      notches
      |> Enum.with_index()
      |> Enum.map(fn {notch, idx} ->
        build_notch_position(notch, idx, notch_width, captured_ranges)
      end)
    end
  end

  defp build_notch_position(notch, idx, notch_width, captured_ranges) do
    base_left = idx * (notch_width + @gap_percent)
    {left, width} = notch_dimensions(notch.type, base_left, notch_width)
    captured_range = Enum.at(captured_ranges, idx)

    %{
      notch: notch,
      left: left,
      width: width,
      is_captured: captured_range != nil,
      captured_range: captured_range
    }
  end

  defp notch_dimensions(:gate, base_left, notch_width) do
    {base_left + (notch_width - @gate_width_percent) / 2, @gate_width_percent}
  end

  defp notch_dimensions(_type, base_left, notch_width), do: {base_left, notch_width}

  defp format_range(%{min: min, max: max}, total_travel)
       when is_number(total_travel) and total_travel > 0 do
    min_pct = round(min / total_travel * 100)
    max_pct = round(max / total_travel * 100)
    "#{min_pct}–#{max_pct}%"
  end

  defp format_range(_, _), do: ""
end
