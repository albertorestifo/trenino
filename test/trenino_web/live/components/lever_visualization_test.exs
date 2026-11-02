defmodule TreninoWeb.LeverVisualizationTest do
  use TreninoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TreninoWeb.LeverVisualization

  defp render_strip(preview, opts \\ []) do
    render_component(&LeverVisualization.hardware_strip/1,
      preview: preview,
      current_value: Keyword.get(opts, :current_value),
      total_travel: Keyword.get(opts, :total_travel, 1000),
      current_notch_index: Keyword.get(opts, :current_notch_index),
      event_target: Keyword.get(opts, :event_target)
    )
  end

  defp empty_preview do
    %{
      status: :none,
      direction_known: false,
      direction_detectable: false,
      direction_pending: false,
      direction_overridable: false,
      direction_source: :auto,
      detected_inverted: false,
      inverted: false,
      low_end: nil,
      high_end: nil,
      live: nil,
      hardware_ranges: []
    }
  end

  describe "hardware_strip/1" do
    test "shows the live marker before any notch is captured" do
      html = render_strip(%{empty_preview() | direction_pending: true}, current_value: 250)

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

  describe "hardware_strip/1 direction controls" do
    @target %Phoenix.LiveComponent.CID{cid: 1}

    defp controls(html) do
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("[data-role=direction-controls] button")
      |> Enum.map(fn button ->
        {LazyHTML.attribute(button, "phx-value-direction") |> List.first(),
         button |> LazyHTML.text() |> String.trim()}
      end)
    end

    defp known_preview(attrs) do
      Map.merge(
        %{empty_preview() | status: :ready, direction_known: true, direction_detectable: true},
        Map.new(attrs)
      )
    end

    test "are omitted without an event target" do
      html = render_strip(known_preview([]))

      refute html =~ "direction-controls"
      refute html =~ "Flip direction"
    end

    test "detectable: shows the auto-detected direction without buttons" do
      html = render_strip(known_preview([]), event_target: @target)

      assert html =~ "Direction: auto-detected (same as simulator)."
      assert html =~ "Detected from the notches you captured."
      assert controls(html) == []
      refute html =~ "Flip direction"
      refute html =~ "Set manually"
    end

    test "detectable reversed: says reversed" do
      html =
        render_strip(known_preview(inverted: true, detected_inverted: true),
          event_target: @target
        )

      assert html =~ "Direction: auto-detected (reversed)."
      assert html =~ "Reversed vs. simulator"
      assert controls(html) == []
    end

    test "detection pending: shows only the hint, no manual choices" do
      html =
        render_strip(%{empty_preview() | status: :partial, direction_pending: true},
          event_target: @target
        )

      assert html =~ "Direction is detected after you capture a second notch"
      refute html =~ "direction-controls"
      refute html =~ "Set manually"
      refute html =~ "Same direction as simulator"
      refute html =~ "Reversed vs. simulator"
      assert controls(html) == []
    end

    test "overridable without override: defaults to same and offers manual choices" do
      preview = %{empty_preview() | status: :ready, direction_overridable: true}
      html = render_strip(preview, event_target: @target)

      refute html =~ "Direction is detected after"
      assert html =~ "Same direction as simulator"
      refute html =~ "Reversed vs. simulator"
      assert html =~ "Set manually:"
      assert controls(html) == [{"same", "Same as simulator"}, {"reversed", "Reversed"}]
      assert html =~ ~s(type="button")
      assert html =~ ~s(phx-click="set_direction")
      assert html =~ ~s(phx-target="1")
      assert html =~ "focus-visible:ring-2"
    end

    test "manual: shows the choice and offers auto-detect" do
      preview = %{
        empty_preview()
        | direction_known: true,
          direction_overridable: true,
          direction_source: :manual,
          inverted: true
      }

      html = render_strip(preview, event_target: @target)

      assert html =~ "Direction: set manually (reversed)"
      assert html =~ "Reversed vs. simulator"
      assert controls(html) == [{"auto", "Reset to default"}]
      refute html =~ "Direction is detected after"
      refute html =~ "Set manually:"
    end

    test "manual same as simulator" do
      preview = %{
        empty_preview()
        | direction_known: true,
          direction_overridable: true,
          direction_source: :manual
      }

      html = render_strip(preview, event_target: @target)

      assert html =~ "Direction: set manually (same as simulator)"
      assert html =~ "Same direction as simulator"
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
