defmodule TreninoWeb.GaugeSetupTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.{Hardware, Train}

  test "offline gauge starter has editable endpoint and calibration and saves disabled", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
    assert has_element?(view, "#gauge-bindings")
    view |> element("#gauge-add") |> render_click()
    view |> element("#gauge-class323") |> render_click()
    assert has_element?(view, "#gauge-calibration-points")
    assert has_element?(view, "button#gauge-claim[disabled]")
    assert has_element?(view, "#gauge-claim-reason", "not connected")

    view
    |> form("#gauge-binding-form",
      gauge_binding: %{name: "Speedometer", endpoint: "VerifiedSpeed"}
    )
    |> render_submit()

    assert [
             %{
               id: binding_id,
               enabled: false,
               calibration_reviewed: false,
               endpoint: "VerifiedSpeed",
               input_unit: :mps,
               output_unit: :mph
             }
           ] =
             Train.list_gauge_bindings(train.id)

    assert render(view) =~ "Unverified points"

    send(
      view.pid,
      {:gauge_binding_updated, binding_id,
       %{
         sample: 44.704,
         value: 100.0,
         target: 720,
         stale: true,
         failure: {:error, :needs_reference}
       }}
    )

    html = render(view)
    assert html =~ "Estimated target: 720 transitions"
    assert html =~ "Simulator data is stale"
    assert html =~ "Reference the axis before moving it."
    refute html =~ ":needs_reference"
  end

  describe "wizard workflow" do
    setup %{conn: conn} do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

      {:ok, train} =
        Train.create_train(%{name: "T", identifiers: [%{identifier: "Class323_DMS_A"}]})

      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      %{view: view, axis: axis, train: train}
    end

    test "steps are ordered and every disabled control says why", %{view: view} do
      html = render(view)

      positions =
        for n <- [
              "Hardware axis",
              "Simulator endpoint and units",
              "Measure the dial",
              "Review the calibration",
              "Save, then enable"
            ],
            do: :binary.match(html, n) |> elem(0)

      assert positions == Enum.sort(positions)

      {measure, _} = :binary.match(html, "Measure the dial")
      {save, _} = :binary.match(html, "id=\"gauge-save\"")
      assert measure < save

      assert has_element?(view, "#gauge-claim-reason")
      assert has_element?(view, "#gauge-enable-reason", "commissioning")
      assert has_element?(view, "#gauge-review-reason") == false
      assert has_element?(view, "#gauge-advanced input[name='gauge_binding[multiplier]']")

      refute has_element?(
               view,
               "#gauge-binding-form > div input[name='gauge_binding[multiplier]']"
             )

      assert has_element?(view, "option", "m/s")
      assert has_element?(view, "option", "mph")
      refute render(view) =~ ">Mps<"
    end

    test "preview and save work from one form without a saved binding", %{
      view: view,
      train: train
    } do
      view |> element("#gauge-class323") |> render_click()

      view
      |> form("#gauge-binding-form", gauge_binding: %{endpoint: "Speed", name: "S"})
      |> render_submit(%{"intent" => "preview", "test_value" => "44.704"})

      assert has_element?(view, "#gauge-preview-result", "estimated target: 720")
      assert Train.list_gauge_bindings(train.id) == []
    end

    test "numbers are rendered with a dot decimal separator", %{view: view} do
      assert render(view) =~ ~s(value="1.0")
    end
  end

  describe "guidance" do
    test "blocker explains why an enabled gauge cannot move" do
      alias Trenino.Train.GaugeBinding
      axis = %Trenino.Hardware.StepperAxis{id: 1, commissioned: false}
      b = %GaugeBinding{enabled: true, stepper_axis: axis}
      snap = %{lifecycle: :ready, axes: %{}}
      assert TreninoWeb.GaugeGuidance.blocker(b, snap, false) =~ "simulator"
      assert TreninoWeb.GaugeGuidance.blocker(b, snap, true) =~ "not commissioned"
      axis = %{axis | commissioned: true}
      b = %{b | stepper_axis: axis}

      assert TreninoWeb.GaugeGuidance.blocker(b, %{snap | lifecycle: :disconnected}, true) =~
               "not connected"

      assert TreninoWeb.GaugeGuidance.blocker(b, %{snap | lifecycle: :fault}, true) =~ "fault"

      assert TreninoWeb.GaugeGuidance.blocker(
               b,
               %{snap | axes: %{1 => %{ready: false, paused: false}}},
               true
             ) =~ "reference"

      assert TreninoWeb.GaugeGuidance.blocker(
               b,
               %{snap | axes: %{1 => %{ready: true, paused: true}}},
               true
             ) =~ "paused"

      assert TreninoWeb.GaugeGuidance.blocker(
               b,
               %{snap | axes: %{1 => %{ready: true, paused: false}}},
               true
             ) == nil

      assert TreninoWeb.GaugeGuidance.blocker(%{b | enabled: false}, snap, false) == nil
    end

    test "train hint names the detected identifier" do
      train = %Trenino.Train.Train{
        identifiers: [%Trenino.Train.TrainIdentifier{identifier: "Class323_DMS_A"}]
      }

      assert TreninoWeb.GaugeGuidance.train_hint(train, nil) == nil
      assert TreninoWeb.GaugeGuidance.train_hint(train, "Class323_DMS_A-1") == nil
      assert TreninoWeb.GaugeGuidance.train_hint(train, "Class323_DMS_B") =~ "\"Class323_DMS_B\""
    end

    test "next step per lifecycle" do
      axis = %Trenino.Hardware.StepperAxis{
        id: 1,
        commissioned: false,
        reference_strategy: :host_reference
      }

      step = &TreninoWeb.GaugeGuidance.next_step(axis, &1, &2, &3)
      assert step.(%{lifecycle: :disconnected, axes: %{}}, false, true) =~ "Apply needed"
      assert step.(%{lifecycle: :fault, axes: %{}}, false, false) =~ "Recover"

      assert step.(
               %{lifecycle: :awaiting_reference, axes: %{1 => %{ready: false, paused: true}}},
               false,
               false
             ) =~ "take manual control"

      assert step.(
               %{lifecycle: :awaiting_reference, axes: %{1 => %{ready: false, paused: true}}},
               true,
               false
             ) =~ "Assign reference"

      commissioned = %{axis | commissioned: true}

      assert TreninoWeb.GaugeGuidance.next_step(
               commissioned,
               %{lifecycle: :ready, axes: %{1 => %{ready: true, paused: true}}},
               false,
               false
             ) =~ "Resume train control"
    end
  end
end
