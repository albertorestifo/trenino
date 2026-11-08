defmodule TreninoWeb.SectionStructureTest do
  @moduledoc """
  Guardrails for the edit-page sections on the hardware configuration and train pages.

  Every section renders through `config_section/1` inside a `section_group/1`: it has a
  DOM id (the anchor target) and an h3 title, every h3 in a group belongs to a section
  card, every delete action in a group asks for confirmation and has an accessible name,
  and every section nav entry points at a section and shows that section's count.
  Hand-rolled section wrappers and the old empty-state components must not come back in
  the page sources.
  """
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Desk panel"})

    {:ok, _input} =
      Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

    {:ok, _matrix} =
      Hardware.create_matrix(device.id, %{name: "Panel keys", row_pins: [2, 3], col_pins: [4]})

    {:ok, output} = Hardware.create_output(device.id, %{pin: 13})

    {:ok, display} =
      Hardware.create_i2c_module(device.id, %{
        name: "Speed",
        module_chip: :ht16k33,
        i2c_address: 112,
        params: %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: true,
          align_right: true,
          min_value: 0.0
        }
      })

    gauge = Trenino.GaugeFixtures.gauge_fixture(device.id)

    {:ok, train} =
      TrainContext.create_train(%{name: "Class 66", identifiers: [%{identifier: "BR_Class_66"}]})

    {:ok, _element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

    {:ok, _output_binding} =
      TrainContext.create_output_binding(train.id, %{
        name: "Speed warning",
        output_id: output.id,
        endpoint: "Speed.Value",
        operator: :gt,
        value_a: 50.0
      })

    {:ok, _display_binding} =
      TrainContext.create_display_binding(train.id, %{
        i2c_module_id: display.id,
        endpoint: "CurrentDrivableActor/Speed",
        name: "Speed readout",
        format_string: "{value:.1f}"
      })

    {:ok, _gauge_binding} =
      TrainContext.create_gauge_binding(train.id, %{
        name: "Speed gauge",
        gauge_id: gauge.id,
        endpoint: "VerifiedSpeed",
        input_unit: :mps
      })

    {:ok, _sequence} = TrainContext.create_sequence(train.id, %{name: "Door open"})

    {:ok, _script} =
      TrainContext.create_script(train.id, %{
        name: "Speed watcher",
        code: "function on_change(event) end"
      })

    %{device: device, train: train}
  end

  describe "hardware configuration page" do
    test "every section has an id and an h3, and every delete is confirmed and labelled", %{
      conn: conn,
      device: device
    } do
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      html = render(view)
      assert_sections(html, ~w(inputs matrices outputs displays gauges))
      assert_groups(html, ~w(controls-group feedback-group))
      assert_nav_matches_sections(html)
    end
  end

  describe "train page" do
    test "every section has an id and an h3, and every delete is confirmed and labelled", %{
      conn: conn,
      train: train
    } do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

      html = render(view)

      assert_sections(
        html,
        ~w(elements gauge-bindings display-bindings output-bindings sequences scripts)
      )

      assert_groups(html, ~w(controls displays-lights automation))
      assert_nav_matches_sections(html)
    end
  end

  describe "page sources" do
    @section_sources [
      "lib/trenino_web/live/configuration_edit_live.ex",
      "lib/trenino_web/live/configuration_edit_live/*.ex",
      "lib/trenino_web/live/train_edit_live.ex",
      "lib/trenino_web/live/train_edit_live/*.ex",
      "lib/trenino_web/live/components/*.ex"
    ]

    defp section_source_files do
      files = Enum.flat_map(@section_sources, &Path.wildcard/1)
      assert files != [], "no edit-page sources matched #{inspect(@section_sources)}"
      files
    end

    # Any string literal (a class attribute or a class list entry) carrying both card
    # classes, in any order and with anything in between.
    @card_classes ~r/"[^"\n]*(?:\bbg-base-200\/50\b[^"\n]*\brounded-xl\b|\brounded-xl\b[^"\n]*\bbg-base-200\/50\b)/

    test "sections are not hand-rolled outside config_section" do
      offenders =
        for file <- section_source_files(),
            {line, number} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
            Regex.match?(@card_classes, line),
            do: "#{file}:#{number}"

      assert offenders == [],
             "use <.config_section> instead of a hand-rolled section wrapper: " <>
               Enum.join(offenders, ", ")
    end

    test "the card-class check catches any order and spacing" do
      for line <- [
            ~s(<section class="bg-base-200/50 rounded-xl p-4">),
            ~s(<section class="rounded-xl bg-base-200/50 p-4">),
            ~s(<div class="bg-base-200/50 p-6 rounded-xl">),
            ~s(class={["p-4 rounded-xl border bg-base-200/50", @class]})
          ] do
        assert Regex.match?(@card_classes, line), line
      end

      refute Regex.match?(@card_classes, ~s(<div class="bg-base-200/50 p-4">))
      refute Regex.match?(@card_classes, ~s(<div class="rounded-xl p-4">))
    end

    # Any string literal carrying both group-heading classes, in any order.
    @group_heading_classes ~r/"[^"\n]*(?:\buppercase\b[^"\n]*\btracking-wide\b|\btracking-wide\b[^"\n]*\buppercase\b)/

    test "section groups are not hand-rolled outside section_group" do
      offenders =
        for file <- section_source_files(),
            {line, number} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
            Regex.match?(@group_heading_classes, line),
            do: "#{file}:#{number}"

      assert offenders == [],
             "use <.section_group> instead of a hand-rolled group heading: " <>
               Enum.join(offenders, ", ")
    end

    test "the group-heading check catches any order and spacing" do
      for line <- [
            ~s(<h2 class="text-sm font-semibold uppercase tracking-wide text-muted mb-3">),
            ~s(<h2 class="text-muted tracking-wide uppercase">),
            ~s(<p class="uppercase text-xs tracking-wide mb-4">)
          ] do
        assert Regex.match?(@group_heading_classes, line), line
      end

      refute Regex.match?(@group_heading_classes, ~s(<td class="uppercase text-xs">))
      refute Regex.match?(@group_heading_classes, ~s(<p class="tracking-wide">))
    end

    test "old empty-state components are gone" do
      offenders =
        for file <- section_source_files(),
            source = File.read!(file),
            name <- ["compact_empty_state", "empty_collection_state"],
            String.contains?(source, name),
            do: "#{file} (#{name})"

      assert offenders == [],
             "use <.section_empty> (or config_section's empty? attr) instead: " <>
               Enum.join(offenders, ", ")
    end
  end

  defp assert_sections(html, expected_ids) do
    doc = LazyHTML.from_fragment(html)
    cards = Enum.to_list(LazyHTML.query(doc, "[data-section-card]"))

    ids = Enum.flat_map(cards, &LazyHTML.attribute(&1, "id"))
    assert length(ids) == length(cards), "every [data-section-card] needs an id"
    assert Enum.sort(ids) == Enum.sort(expected_ids)

    for card <- cards do
      [id] = LazyHTML.attribute(card, "id")

      assert card |> LazyHTML.query("h3") |> Enum.count() == 1,
             "section ##{id} needs exactly one h3 (its title); nested headings rank below it"

      assert card |> LazyHTML.query("h1, h2") |> Enum.empty?(),
             "section ##{id} has a heading that outranks its title"

      assert delete_buttons(card) != [],
             "section ##{id} renders a row but no delete action"
    end

    # A section built without config_section has an h3 that no card owns.
    group_h3s = doc |> LazyHTML.query("[data-section-group] h3") |> Enum.count()

    card_h3s =
      doc |> LazyHTML.query("[data-section-group] [data-section-card] h3") |> Enum.count()

    assert group_h3s == card_h3s,
           "every section in a group must render through <.config_section>"

    assert doc |> LazyHTML.query("[data-section-card]") |> Enum.count() ==
             doc |> LazyHTML.query("[data-section-group] [data-section-card]") |> Enum.count(),
           "every section card must sit inside a <.section_group>"

    # Deletes are checked across every group, not only inside cards.
    for group <- LazyHTML.query(doc, "[data-section-group]"),
        button <- delete_buttons(group) do
      assert [confirm] = LazyHTML.attribute(button, "data-confirm"),
             "a delete button has no data-confirm: #{LazyHTML.to_html(button)}"

      assert confirm =~ ~r/^Delete .+\?/

      assert [label] = LazyHTML.attribute(button, "aria-label"),
             "a delete button has no aria-label: #{LazyHTML.to_html(button)}"

      assert label =~ ~r/^Delete \S/
    end
  end

  defp assert_groups(html, expected_ids) do
    groups = html |> LazyHTML.from_fragment() |> LazyHTML.query("[data-section-group]")
    ids = Enum.flat_map(groups, &LazyHTML.attribute(&1, "id"))
    assert ids == expected_ids

    for group <- groups do
      [id] = LazyHTML.attribute(group, "id")
      assert [_] = Enum.to_list(LazyHTML.query(group, "h2")), "group ##{id} needs one h2"
    end
  end

  # Each nav entry points at a section card, and its count is the one on the card.
  defp assert_nav_matches_sections(html) do
    doc = LazyHTML.from_fragment(html)
    links = Enum.to_list(LazyHTML.query(doc, "#section-nav a"))
    assert links != []

    for link <- links do
      ["#" <> id] = LazyHTML.attribute(link, "href")
      card = LazyHTML.query(doc, "[data-section-card]##{id}")
      refute Enum.empty?(card), "nav entry ##{id} does not point at a section"

      title = card |> LazyHTML.query("h3") |> LazyHTML.text() |> String.trim()
      assert link |> LazyHTML.text() |> String.trim() |> String.starts_with?(title)

      card_count = card |> LazyHTML.query("h3 + .badge") |> LazyHTML.text() |> String.trim()
      nav_count = link |> LazyHTML.query(".badge") |> LazyHTML.text() |> String.trim()
      assert nav_count == card_count, "nav count for ##{id} differs from its section badge"
    end
  end

  # A delete button is any button whose click event starts with "delete" or that
  # shows the trash icon.
  defp delete_buttons(card) do
    card
    |> LazyHTML.query("button")
    |> Enum.filter(fn button ->
      click = button |> LazyHTML.attribute("phx-click") |> List.first("")

      String.starts_with?(click, "delete") or
        not Enum.empty?(LazyHTML.query(button, ".hero-trash"))
    end)
  end
end
