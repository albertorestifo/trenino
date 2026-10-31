defmodule TreninoWeb.GaugeSetupTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.{Hardware, Train}

  test "offline gauge starter has an editable endpoint and saves disabled without a dial", %{
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
    refute has_element?(view, "#gauge-calibration-points")
    assert has_element?(view, "#gauge-dial-status", "No dial calibration")

    view
    |> form("#gauge-binding-form",
      gauge_binding: %{name: "Speedometer", endpoint: "VerifiedSpeed"}
    )
    |> render_submit()

    assert [%{id: binding_id, enabled: false, endpoint: "VerifiedSpeed", input_unit: :mps}] =
             Train.list_gauge_bindings(train.id)

    assert has_element?(view, "[id^=gauge-dial-]", "No dial calibration")

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

    _ = render(view)
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

      %{conn: conn, axis: axis, train: train, device: device}
    end

    test "three steps, no calibration, every disabled control says why", %{
      conn: conn,
      train: train
    } do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      html = render(view)

      positions =
        for n <- ["Hardware axis", "Simulator endpoint and units", "Save, then enable"],
            do: :binary.match(html, n) |> elem(0)

      assert positions == Enum.sort(positions)
      refute html =~ "Measure the dial"
      refute html =~ "Review the calibration"
      refute has_element?(view, "#gauge-claim")
      refute has_element?(view, "input[name='gauge_binding[points][0][value]']")

      assert has_element?(view, "#gauge-dial-status a", "Calibrate the dial")
      assert has_element?(view, "#gauge-enable-reason", "commissioning")
      assert has_element?(view, "#gauge-advanced input[name='gauge_binding[multiplier]']")

      refute has_element?(
               view,
               "#gauge-binding-form > div input[name='gauge_binding[multiplier]']"
             )

      assert has_element?(view, "option", "m/s")
      assert has_element?(view, "option", "mph")
      refute render(view) =~ ">Mps<"
    end

    test "a calibrated, reviewed axis shows its dial and enabling stops asking for it", %{
      conn: conn,
      train: train,
      axis: axis
    } do
      {:ok, axis} = Hardware.commission_stepper_axis(axis)

      {:ok, _} =
        Hardware.save_dial_calibration(axis, %{
          output_unit: :mph,
          reviewed: true,
          points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
        })

      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      assert has_element?(view, "#gauge-dial-status", "Dial calibrated, shows mph")
      # Default raw input cannot feed an mph dial: the unit step explains it.
      assert has_element?(view, "#gauge-enable-reason", "units")

      view
      |> form("#gauge-binding-form", gauge_binding: %{input_unit: "mps"})
      |> render_change()

      refute has_element?(view, "#gauge-enable-reason")

      view
      |> form("#gauge-binding-form",
        gauge_binding: %{name: "S", endpoint: "Speed", input_unit: "mps", enabled: "true"}
      )
      |> render_submit()

      assert [%{enabled: true, input_unit: :mps}] = Train.list_gauge_bindings(train.id)
    end

    test "a commissioned axis without a dial says the dial is what is missing", %{
      conn: conn,
      train: train,
      axis: axis
    } do
      {:ok, _} = Hardware.commission_stepper_axis(axis)
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      assert has_element?(view, "#gauge-enable-reason", "Calibrate and review the dial")
    end

    test "numbers are rendered with a dot decimal separator", %{conn: conn, train: train} do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
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
