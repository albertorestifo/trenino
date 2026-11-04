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

      assert has_element?(view, "#gauge-dial-status a", "Set up gauge")
      assert has_element?(view, "#gauge-enable-reason", "Set up this gauge first")
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
      assert has_element?(view, "#gauge-enable-reason", "Run the gauge setup")
    end

    test "numbers are rendered with a dot decimal separator", %{conn: conn, train: train} do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      assert render(view) =~ ~s(value="1.0")
    end
  end

  describe "gauge card" do
    setup %{conn: conn} do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
      {:ok, axis} = Hardware.commission_stepper_axis(axis)

      {:ok, _} =
        Hardware.save_dial_calibration(axis, %{
          output_unit: :mph,
          reviewed: true,
          points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
        })

      {:ok, train} = Train.create_train(%{name: "T", identifiers: [%{identifier: "Card_T"}]})

      {:ok, binding} =
        Train.create_gauge_binding(train.id, %{
          stepper_axis_id: axis.id,
          name: "Speedometer",
          endpoint: "HUD_GetSpeed",
          input_unit: :mps
        })

      %{conn: conn, train: train, binding: binding}
    end

    test "rests as identity, one state and a switch; the endpoint is behind Details", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/trains/#{ctx.train.id}")
      id = ctx.binding.id
      assert has_element?(view, "#gauge-status-#{id}[role=status]", "Off")
      assert has_element?(view, "#gauge-toggle-#{id}[role=switch][aria-checked=false]")
      assert has_element?(view, "#gauge-details-#{id} p", "HUD_GetSpeed")
      refute has_element?(view, "#gauge-binding-#{id} > p", "HUD_GetSpeed")
      refute render(view) =~ "Awaiting fresh simulator data"
      refute has_element?(view, "#gauge-blocker-#{id}")
    end

    test "the switch enables the gauge and a stopped gauge gives one reason", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/trains/#{ctx.train.id}")
      id = ctx.binding.id
      view |> element("#gauge-toggle-#{id}") |> render_click()
      assert [%{enabled: true}] = Train.list_gauge_bindings(ctx.train.id)
      assert has_element?(view, "#gauge-toggle-#{id}[aria-checked=true]")
      assert has_element?(view, "#gauge-status-#{id}", "Not moving")
      assert has_element?(view, "#gauge-blocker-#{id}", "simulator is not connected")
      assert has_element?(view, "#gauge-binding-#{id} p", "simulator is not connected")
      # No axis link when the axis is not the problem.
      refute has_element?(view, "#gauge-binding-#{id} a", "Open axis")
    end
  end

  describe "guidance" do
    test "blocker says why a blocked dial keeps an enabled gauge still" do
      alias Trenino.Hardware.{DialCalibration, StepperAxis}
      alias Trenino.Train.GaugeBinding

      axis = %StepperAxis{
        id: 1,
        commissioned: true,
        dial_calibration: %DialCalibration{valid: false, reviewed: true}
      }

      b = %GaugeBinding{enabled: true, stepper_axis: axis}

      assert TreninoWeb.GaugeGuidance.blocker(b, %{lifecycle: :ready, axes: %{}}, true) =~
               "dial is blocked"
    end

    test "blocker explains why an enabled gauge cannot move" do
      alias Trenino.Train.GaugeBinding
      axis = %Trenino.Hardware.StepperAxis{id: 1, commissioned: false}
      b = %GaugeBinding{enabled: true, stepper_axis: axis}
      snap = %{lifecycle: :ready, axes: %{}}
      assert TreninoWeb.GaugeGuidance.blocker(b, snap, false) =~ "simulator"
      assert TreninoWeb.GaugeGuidance.blocker(b, snap, true) =~ "not set up"
      axis = %{axis | commissioned: true}
      b = %{b | stepper_axis: axis}

      assert TreninoWeb.GaugeGuidance.blocker(b, %{snap | lifecycle: :disconnected}, true) =~
               "not connected"

      assert TreninoWeb.GaugeGuidance.blocker(b, %{snap | lifecycle: :fault}, true) =~ "fault"

      assert TreninoWeb.GaugeGuidance.blocker(
               b,
               %{snap | axes: %{1 => %{ready: false, paused: false}}},
               true
             ) =~ "re-zero"

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

    test "axis status: one state and one action" do
      alias Trenino.Hardware.{DialCalibration, StepperAxis}

      dial = %DialCalibration{valid: true, reviewed: true}
      axis = %StepperAxis{id: 1, commissioned: true, dial_calibration: dial}
      status = &TreninoWeb.GaugeGuidance.axis_status(axis, &1)
      runtime = %{ready: true, paused: false, lease: nil, pending: nil, status: nil}

      assert %{state: :offline, primary: nil} = status.(%{lifecycle: :disconnected, axes: %{}})
      assert %{state: :fault, primary: :rezero} = status.(%{lifecycle: :fault, axes: %{}})

      assert %{state: :ready, primary: nil} =
               status.(%{lifecycle: :ready, axes: %{1 => runtime}})

      assert %{state: :needs_rezero, primary: :rezero} =
               status.(%{lifecycle: :ready, axes: %{1 => %{runtime | ready: false}}})

      assert %{state: :paused, primary: :resume} =
               status.(%{lifecycle: :ready, axes: %{1 => %{runtime | paused: true}}})

      assert %{state: :manual, primary: nil} =
               status.(%{lifecycle: :ready, axes: %{1 => %{runtime | lease: %{owner: :mcp}}}})

      assert %{state: :needs_apply, primary: nil} = status.(%{lifecycle: :ready, axes: %{}})

      moved = %{axis | max_position: 900}

      assert %{state: :needs_apply} =
               TreninoWeb.GaugeGuidance.axis_status(moved, %{
                 lifecycle: :ready,
                 axes: %{1 => Map.put(runtime, :config, axis)}
               })

      for unset <- [
            %{axis | idle_behavior: :release},
            %{axis | commissioned: false},
            %{axis | dial_calibration: nil},
            %{axis | dial_calibration: %{dial | reviewed: false}},
            %{axis | dial_calibration: %{dial | valid: false}}
          ] do
        assert %{state: :needs_setup, primary: :wizard} =
                 TreninoWeb.GaugeGuidance.axis_status(unset, %{
                   lifecycle: :ready,
                   axes: %{1 => runtime}
                 })
      end

      assert %{state: :fault, primary: :wizard} =
               TreninoWeb.GaugeGuidance.axis_status(%{axis | commissioned: false}, %{
                 lifecycle: :fault,
                 axes: %{}
               })
    end
  end
end
