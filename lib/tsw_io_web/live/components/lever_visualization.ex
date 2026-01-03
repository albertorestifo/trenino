defmodule TswIoWeb.LeverVisualization do
  @moduledoc """
  Horizontal bar visualization for lever notch positions.

  Displays:
  - Gates as dots/circles on the bar
  - Linear notches as segments spanning their range
  - Small gaps between adjacent notches
  - Live position indicator showing current hardware value
  - Highlighting for the active notch being mapped
  - Captured min/max values below each notch

  ## Usage

      <.live_component
        module={TswIoWeb.LeverVisualization}
        id="lever-viz"
        notches={@notches}
        captured_ranges={@captured_ranges}
        current_value={@current_value}
        total_travel={@total_travel}
        current_notch_index={@current_notch_index}
      />
  """

  use TswIoWeb, :live_component

  @gap_percent 1.0
  @gate_width_percent 3.0

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    # Calculate positions for each notch
    notch_positions = calculate_notch_positions(assigns)

    # Calculate live indicator position
    indicator_position = calculate_indicator_position(assigns)

    assigns =
      assigns
      |> assign(:notch_positions, notch_positions)
      |> assign(:indicator_position, indicator_position)

    ~H"""
    <div class="w-full py-4">
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

        <%!-- Live position indicator --%>
        <div
          :if={@indicator_position != nil}
          class="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-1 h-8 bg-primary rounded-full shadow-lg transition-[left] duration-75"
          style={"left: #{@indicator_position}%;"}
        >
          <div class="absolute -top-1 left-1/2 -translate-x-1/2 w-3 h-3 bg-primary rounded-full" />
        </div>
      </div>

      <%!-- Labels row --%>
      <div class="relative h-8 mx-4 mt-2">
        <div
          :for={{notch_data, idx} <- Enum.with_index(@notch_positions)}
          class="absolute text-center"
          style={"left: #{notch_data.left}%; width: #{notch_data.width}%;"}
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

      <%!-- Min/Max labels at ends --%>
      <div class="flex justify-between mx-4 text-xs text-base-content/50 -mt-1">
        <span>MIN</span>
        <span>MAX</span>
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
      "text-xs truncate",
      @is_active && "text-primary font-medium",
      not @is_active && "text-base-content/60"
    ]}>
      <div class="font-medium truncate" title={@notch.description || "Notch #{@index}"}>
        {short_description(@notch.description, @index)}
      </div>
      <div :if={@captured_range} class="font-mono text-[10px] text-base-content/50">
        {format_range(@captured_range, @total_travel)}
      </div>
    </div>
    """
  end

  # Helper functions

  defp calculate_notch_positions(assigns) do
    notches = assigns[:notches] || []
    captured_ranges = assigns[:captured_ranges] || []
    total_count = length(notches)

    if total_count == 0 do
      []
    else
      # Calculate total gaps
      total_gap_percent = (total_count - 1) * @gap_percent
      available_percent = 100.0 - total_gap_percent

      # Each notch gets equal space (for simplicity)
      # For more accurate representation, we could use the actual input_min/input_max values
      notch_width = available_percent / total_count

      notches
      |> Enum.with_index()
      |> Enum.map(fn {notch, idx} ->
        left = idx * (notch_width + @gap_percent)

        # Adjust width for gates (make them narrower)
        width =
          if notch.type == :gate do
            @gate_width_percent
          else
            notch_width
          end

        # Adjust left position for gates to center them
        left =
          if notch.type == :gate do
            left + (notch_width - @gate_width_percent) / 2
          else
            left
          end

        captured_range = Enum.at(captured_ranges, idx)

        %{
          notch: notch,
          left: left,
          width: width,
          is_captured: captured_range != nil,
          captured_range: captured_range
        }
      end)
    end
  end

  defp calculate_indicator_position(assigns) do
    current_value = assigns[:current_value]
    total_travel = assigns[:total_travel] || 1
    inverted = assigns[:inverted] || false

    if current_value && total_travel > 0 do
      # Normalize to 0-100%
      position = current_value / total_travel * 100.0

      # Apply inversion if enabled (so user sees "logical" position)
      position = if inverted, do: 100.0 - position, else: position

      min(100.0, max(0.0, position))
    else
      nil
    end
  end

  defp short_description(nil, index), do: "##{index}"
  defp short_description(desc, _index) when byte_size(desc) <= 8, do: desc

  defp short_description(desc, _index) do
    String.slice(desc, 0, 6) <> "…"
  end

  defp format_range(nil, _), do: ""

  defp format_range(%{min: min, max: max}, total_travel) when total_travel > 0 do
    min_pct = Float.round(min / total_travel * 100, 0)
    max_pct = Float.round(max / total_travel * 100, 0)
    "#{trunc(min_pct)}–#{trunc(max_pct)}%"
  end

  defp format_range(_, _), do: ""
end
