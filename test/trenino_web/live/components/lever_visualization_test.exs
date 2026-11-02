defmodule TreninoWeb.LeverVisualizationTest do
  use TreninoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TreninoWeb.LeverVisualization

  defp render_strip(preview, opts \\ []) do
    render_component(&LeverVisualization.hardware_strip/1,
      preview: preview,
      current_value: Keyword.get(opts, :current_value),
      total_travel: Keyword.get(opts, :total_travel, 1000),
      current_notch_index: Keyword.get(opts, :current_notch_index)
    )
  end

  defp empty_preview do
    %{
      status: :none,
      direction_known: false,
      inverted: false,
      low_end: nil,
      high_end: nil,
      live: nil,
      hardware_ranges: []
    }
  end

  describe "hardware_strip/1" do
    test "shows the live marker before any notch is captured" do
      html = render_strip(empty_preview(), current_value: 250)

      assert html =~ "Your lever"
      assert html =~ "left: 25.0%;"
      assert html =~ "Lever now at 25%"
      assert html =~ "Direction is detected after you capture a second notch"
    end

    test "omits the live marker when there is no reading" do
      html = render_strip(empty_preview())

      refute html =~ "Lever now at"
    end

    test "gives a single-point gate a visible width and falls back to a notch number" do
      range = %{
        notch_index: 3,
        description: nil,
        type: :gate,
        min_pct: 50.0,
        max_pct: 50.0,
        sim_at_min: 0.5,
        sim_at_max: 0.5,
        sim_output_min: 1.0,
        sim_output_max: 1.0
      }

      html = render_strip(%{empty_preview() | hardware_ranges: [range]})

      assert html =~ "left: 48.5%; width: 3.0%;"
      assert html =~ "Notch 4: 50–50% of travel"
    end
  end

  describe "display_name/2" do
    test "uses the description or a 1-based fallback" do
      assert LeverVisualization.display_name("Idle", 0) == "Idle"
      assert LeverVisualization.display_name(nil, 0) == "Notch 1"
      assert LeverVisualization.display_name("", 2) == "Notch 3"
    end
  end
end
