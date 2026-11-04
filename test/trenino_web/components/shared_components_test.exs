defmodule TreninoWeb.SharedComponentsTest do
  use TreninoWeb.ConnCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import TreninoWeb.SharedComponents

  defp parse(html), do: LazyHTML.from_fragment(html)

  defp attr(doc, selector, name) do
    doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name)
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  describe "config_section/1" do
    test "renders a labelled section card with an h3 title and count badge" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.config_section id="inputs" title="Inputs" count={3} description="Pins read by the device.">
          <p id="body">Table</p>
        </.config_section>
        """)

      doc = parse(html)

      assert attr(doc, "section[data-section-card]", "id") == ["inputs"]
      assert attr(doc, "section#inputs", "aria-labelledby") == ["inputs-title"]
      assert [class] = attr(doc, "section#inputs", "class")
      assert class =~ "bg-base-200/50 rounded-xl"
      assert class =~ "scroll-mt-36"

      assert doc |> LazyHTML.query("h3#inputs-title") |> LazyHTML.text() == "Inputs"
      assert attr(doc, "h3#inputs-title", "class") == ["text-xl font-semibold"]

      badge = LazyHTML.query(doc, ".badge.badge-ghost")
      assert badge |> LazyHTML.text() |> String.trim() == "3"
      assert [badge_class] = LazyHTML.attribute(badge, "class")
      assert badge_class =~ "tabular-nums"

      assert html =~ "Pins read by the device."
      assert count(doc, "#body") == 1
    end

    test "hides the count badge when count is nil or zero" do
      for value <- [nil, 0] do
        assigns = %{value: value}

        html =
          rendered_to_string(~H"""
          <.config_section id="outputs" title="Outputs" count={@value}>body</.config_section>
          """)

        assert count(parse(html), ".badge") == 0
      end
    end

    test "renders the compact empty state instead of the body when empty?" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.config_section
          id="matrices"
          title="Matrices"
          empty?={true}
          empty_icon="hero-squares-2x2"
          empty_message="No matrices yet"
          empty_hint="Add a matrix to scan a button grid."
        >
          <p id="body">Table</p>
        </.config_section>
        """)

      doc = parse(html)

      assert count(doc, "#body") == 0
      assert count(doc, "[data-section-empty]") == 1
      assert html =~ "No matrices yet"
      assert html =~ "Add a matrix to scan a button grid."
      assert html =~ "hero-squares-2x2"
    end

    test "renders the body and no empty state when not empty?" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.config_section id="matrices" title="Matrices" empty?={false} empty_message="No matrices yet">
          <p id="body">Table</p>
        </.config_section>
        """)

      doc = parse(html)

      assert count(doc, "#body") == 1
      assert count(doc, "[data-section-empty]") == 0
      refute html =~ "No matrices yet"
    end

    test "renders actions, then settings and notice before the body" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.config_section id="gauges" title="Gauges">
          <:actions><button id="add-gauge">Add gauge</button></:actions>
          <:settings><span id="shield">Motor shield address 0x60</span></:settings>
          <:notice>
            <div id="notice" class="alert alert-soft alert-warning">Heads up</div>
          </:notice>
          <p id="body">Cards</p>
        </.config_section>
        """)

      doc = parse(html)

      for id <- ~w(add-gauge shield notice body) do
        assert count(doc, "##{id}") == 1
      end

      positions =
        for marker <- ["id=\"gauges-title\"", "id=\"shield\"", "id=\"notice\"", "id=\"body\""] do
          html |> :binary.match(marker) |> elem(0)
        end

      assert positions == Enum.sort(positions)

      assert [settings_class] =
               doc
               |> LazyHTML.query("section#gauges > div:has(> #shield)")
               |> LazyHTML.attribute("class")

      assert settings_class =~ "text-muted"
    end
  end

  describe "section_empty/1" do
    test "renders a compact single row with muted icon and hint" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_empty icon="hero-cpu-chip" message="No elements yet" hint="Add an element." />
        """)

      doc = parse(html)

      assert [class] = attr(doc, "[data-section-empty]", "class")
      assert class =~ "bg-base-100 rounded-lg px-4 py-3 flex items-center gap-3"
      refute class =~ "border"
      assert [icon_class] = attr(doc, ".hero-cpu-chip", "class")
      assert icon_class =~ "size-5"
      assert icon_class =~ "text-muted"
      assert doc |> LazyHTML.query("p.text-sm") |> LazyHTML.text() == "No elements yet"
      assert doc |> LazyHTML.query("p.text-xs.text-muted") |> LazyHTML.text() == "Add an element."
    end
  end

  describe "section_action/1" do
    test "a disabled navigate action renders a disabled button, not a working link" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action
          id="add-script"
          label="Add script"
          navigate="/trains/1/scripts/new"
          disabled
          disabled_reason="Save the train first."
        />
        """)

      doc = parse(html)
      assert count(doc, "a") == 0
      assert count(doc, "button#add-script[disabled]") == 1
      assert attr(doc, "button#add-script", "aria-describedby") == ["add-script-reason"]
    end

    test "renders an outline button with a plus icon and label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action id="add-input" label="Add input" on_click="open_add_input_modal" />
        """)

      doc = parse(html)

      assert attr(doc, "button#add-input", "class") == ["btn btn-outline btn-sm"]
      assert attr(doc, "button#add-input", "phx-click") == ["open_add_input_modal"]
      assert count(doc, "button#add-input[disabled]") == 0

      assert count(doc, "button#add-input .hero-plus") == 1
      assert doc |> LazyHTML.query("button#add-input") |> LazyHTML.text() =~ "Add input"
      assert count(doc, "button#add-input[aria-describedby]") == 0
    end

    test "shows the disabled reason as visible text wired with aria-describedby" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action
          id="add-sequence"
          label="Add sequence"
          on_click="open_add_modal"
          disabled={true}
          disabled_reason="Connect the simulator to add a sequence."
        />
        """)

      doc = parse(html)

      assert count(doc, "button#add-sequence[disabled]") == 1
      assert [described_by] = attr(doc, "button#add-sequence", "aria-describedby")
      assert is_binary(described_by)

      reason = LazyHTML.query(doc, "##{described_by}")
      assert LazyHTML.text(reason) =~ "Connect the simulator to add a sequence."
      assert [reason_class] = LazyHTML.attribute(reason, "class")
      assert reason_class =~ "text-xs"
      assert reason_class =~ "text-muted"
      refute reason_class =~ "hidden"
      refute reason_class =~ "sr-only"
    end

    test "does not show the reason while enabled" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action id="add-script" label="Add script" disabled_reason="Not shown" />
        """)

      refute html =~ "Not shown"
      assert count(parse(html), "button#add-script[aria-describedby]") == 0
    end

    test "points aria-describedby at an existing explanation instead of repeating it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action id="add-gauge" label="Add gauge binding" disabled describedby="gauge-why" />
        """)

      doc = parse(html)
      assert attr(doc, "button#add-gauge[disabled]", "aria-describedby") == ["gauge-why"]
      assert count(doc, "#add-gauge-reason") == 0
    end

    test "renders a real link when navigate is set" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_action id="add-script" label="Add script" navigate="/trains/1/scripts/new" />
        """)

      doc = parse(html)
      assert attr(doc, "a#add-script", "href") == ["/trains/1/scripts/new"]
      assert attr(doc, "a#add-script", "data-phx-link") == ["redirect"]
      assert attr(doc, "a#add-script", "class") == ["btn btn-outline btn-sm"]
      assert count(doc, "button") == 0
    end
  end

  describe "row_actions/1" do
    test "adds the item name to inline action aria-labels and keeps labels at 12px" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-9" name="Horn">
          <:action event="edit" icon="hero-pencil-square" label="Edit" />
          <:action id="open-9" navigate="/scripts/9" label="Open" />
          <:action event="delete" label="Delete Horn" kind={:danger} />
        </.row_actions>
        """)

      doc = parse(html)
      assert attr(doc, "#row-9 > button[phx-click='edit']", "aria-label") == ["Edit Horn"]
      assert attr(doc, "#row-9 > a#open-9", "aria-label") == ["Open Horn"]
      assert attr(doc, "#row-9 > button:last-child", "aria-label") == ["Delete Horn"]

      for class <- attr(doc, "#row-9 > button[phx-click='edit'], #row-9 > a#open-9", "class") do
        assert class =~ "text-xs"
      end
    end

    test "the overflow menu closes on outside click and Escape" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-10" menu={:always}>
          <:action event="edit" label="Edit" />
        </.row_actions>
        """)

      doc = parse(html)
      assert [click_away] = attr(doc, "details#row-10-menu", "phx-click-away")
      assert click_away =~ "remove_attr"

      # Key bindings fire only on the event target, which is the focused summary or
      # menu item, never the non-focusable <details>.
      assert attr(doc, "details#row-10-menu", "phx-keydown") == []

      focusable = "details#row-10-menu > summary, details#row-10-menu li > button"
      assert attr(doc, focusable, "phx-key") == ["Escape", "Escape"]
      assert [_, _] = keydowns = attr(doc, focusable, "phx-keydown")

      for keydown <- keydowns do
        assert keydown =~ "remove_attr"
        assert keydown =~ "focus_first"
        assert keydown =~ "closest"
      end
    end

    test "renders the delete action last as an icon-only trash with confirm and aria-label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-1">
          <:action event="delete_input" values={%{id: 7}} label="Delete Throttle" kind={:danger} />
          <:action event="calibrate" values={%{id: 7}} icon="hero-adjustments-vertical" label="Calibrate" />
        </.row_actions>
        """)

      doc = parse(html)
      buttons = LazyHTML.query(doc, "#row-1 > button")

      assert LazyHTML.attribute(buttons, "phx-click") == ["calibrate", "delete_input"]

      delete = LazyHTML.query(doc, "#row-1 > button:last-child")
      assert LazyHTML.attribute(delete, "aria-label") == ["Delete Throttle"]
      assert LazyHTML.attribute(delete, "data-confirm") == ["Delete Throttle?"]
      assert LazyHTML.attribute(delete, "phx-value-id") == ["7"]
      assert LazyHTML.attribute(delete, "class") == ["btn btn-ghost btn-xs text-error"]
      assert delete |> LazyHTML.query(".hero-trash") |> Enum.count() == 1
      assert delete |> LazyHTML.text() |> String.trim() == ""

      calibrate = LazyHTML.query(doc, "#row-1 > button:first-child")
      assert LazyHTML.attribute(calibrate, "class") == ["btn btn-ghost btn-xs text-xs"]
      assert LazyHTML.attribute(calibrate, "aria-label") == ["Calibrate"]
      assert LazyHTML.text(calibrate) =~ "Calibrate"
      assert calibrate |> LazyHTML.query(".hero-adjustments-vertical") |> Enum.count() == 1
      assert count(doc, "details") == 0
    end

    test "uses an explicit confirm message on the delete action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions>
          <:action
            event="delete"
            label="Delete Horn"
            kind={:danger}
            confirm="Delete Horn? Sequences using it stop working."
          />
        </.row_actions>
        """)

      assert attr(parse(html), "button", "data-confirm") == [
               "Delete Horn? Sequences using it stop working."
             ]
    end

    test "collapses three or more non-destructive actions into a menu but keeps delete visible" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-2" name="Brake">
          <:action event="edit" values={%{id: 2}} icon="hero-pencil-square" label="Edit" />
          <:action event="delete" values={%{id: 2}} label="Delete Brake" kind={:danger} />
          <:action event="test" values={%{id: 2}} label="Test" />
          <:action event="calibrate" values={%{id: 2}} label="Calibrate" />
        </.row_actions>
        """)

      doc = parse(html)

      assert count(doc, "#row-2 > details#row-2-menu") == 1

      assert attr(doc, "#row-2-menu > summary", "aria-label") == ["More actions for Brake"]
      assert count(doc, "#row-2-menu > summary .hero-ellipsis-horizontal") == 1

      menu_buttons = LazyHTML.query(doc, "#row-2-menu li > button")
      assert menu_buttons |> LazyHTML.text() =~ "Edit"
      assert Enum.count(menu_buttons) == 3
      assert LazyHTML.attribute(menu_buttons, "phx-value-id") == ["2", "2", "2"]

      for click <- LazyHTML.attribute(menu_buttons, "phx-click") do
        assert click =~ "push"
        assert click =~ "remove_attr"
      end

      assert count(doc, "#row-2-menu .hero-trash") == 0
      delete = LazyHTML.query(doc, "#row-2 > button:last-child")
      assert LazyHTML.attribute(delete, "aria-label") == ["Delete Brake"]
      assert LazyHTML.attribute(delete, "data-confirm") == ["Delete Brake?"]
      assert count(doc, "#row-2 > button") == 1
    end

    test "uses an explicit menu_id for the overflow menu" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-4" menu_id="custom-menu">
          <:action event="edit" label="Edit" />
          <:action event="test" label="Test" />
          <:action event="calibrate" label="Calibrate" />
        </.row_actions>
        """)

      doc = parse(html)
      assert count(doc, "#row-4 > details#custom-menu") == 1
      assert count(doc, "#row-4-menu") == 0
    end

    test "keeps two non-destructive actions inline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-3">
          <:action event="edit" label="Edit" />
          <:action event="test" label="Test" />
        </.row_actions>
        """)

      doc = parse(html)
      assert count(doc, "details") == 0
      assert count(doc, "#row-3 > button") == 2
    end

    test "menu={:always} keeps even one or two actions in the menu" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_actions id="row-5" menu={:always}>
          <:action event="edit" label="Edit" />
          <:action event="delete" label="Delete Brake" kind={:danger} />
        </.row_actions>
        """)

      doc = parse(html)
      assert count(doc, "#row-5 > details#row-5-menu li > button") == 1
      assert count(doc, "#row-5 > button") == 1
    end

    test "renders navigate actions as links, inline and in the menu" do
      assigns = %{}

      inline =
        rendered_to_string(~H"""
        <.row_actions id="row-6">
          <:action id="edit-6" navigate="/scripts/6" icon="hero-pencil-square" label="Edit" />
          <:action event="delete" label="Delete Watcher" kind={:danger} />
        </.row_actions>
        """)

      doc = parse(inline)
      assert attr(doc, "#row-6 > a#edit-6", "href") == ["/scripts/6"]
      assert attr(doc, "#row-6 > a#edit-6", "data-phx-link") == ["redirect"]
      assert attr(doc, "#row-6 > a#edit-6", "class") == ["btn btn-ghost btn-xs text-xs"]

      menu =
        rendered_to_string(~H"""
        <.row_actions id="row-7" menu={:always}>
          <:action id="edit-7" navigate="/scripts/7" label="Edit" />
        </.row_actions>
        """)

      assert attr(parse(menu), "#row-7-menu li > a#edit-7", "href") == ["/scripts/7"]
    end
  end

  describe "section_group/1" do
    test "renders a labelled group with an h2 heading around its sections" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_group id="inputs-group" title="Inputs">
          <p id="body">Sections</p>
        </.section_group>
        """)

      doc = parse(html)
      assert attr(doc, "div[data-section-group]", "id") == ["inputs-group"]
      # A plain wrapper, not a second named region next to its sections.
      assert count(doc, "section") == 0
      assert attr(doc, "#inputs-group", "aria-labelledby") == []
      assert [class] = attr(doc, "div#inputs-group", "class")
      assert class =~ "scroll-mt-36"
      assert class =~ "mt-8"

      assert doc |> LazyHTML.query("h2#inputs-group-title") |> LazyHTML.text() |> String.trim() ==
               "Inputs"

      assert count(doc, "div#inputs-group .space-y-4 > p#body") == 1
    end
  end

  describe "section_nav/1" do
    test "renders sticky anchor links with optional counts" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_nav
          label="Hardware configuration sections"
          items={[
            %{id: "inputs-group", label: "Inputs", count: 4},
            %{id: "outputs-group", label: "Outputs", count: 0},
            %{id: "gauges", label: "Gauges"}
          ]}
        />
        """)

      doc = parse(html)

      assert attr(doc, "nav", "aria-label") == ["Hardware configuration sections"]
      assert [nav_class] = attr(doc, "nav", "class")
      # Sticky from md up, just under the app header; it scrolls with the page below md.
      assert nav_class =~ "md:sticky"
      assert nav_class =~ "md:top-19"
      assert nav_class =~ "z-10"
      assert nav_class =~ "bg-base-100"
      assert nav_class =~ "border-b"

      links = LazyHTML.query(doc, "nav > a")
      assert LazyHTML.attribute(links, "href") == ["#inputs-group", "#outputs-group", "#gauges"]

      assert LazyHTML.attribute(links, "class") ==
               List.duplicate("btn btn-ghost btn-sm", 3)

      assert links |> LazyHTML.text() =~ "Inputs"
      assert links |> LazyHTML.text() =~ "Gauges"

      badges = LazyHTML.query(doc, "nav .badge")
      assert badges |> LazyHTML.text() |> String.trim() == "4"
    end
  end
end
