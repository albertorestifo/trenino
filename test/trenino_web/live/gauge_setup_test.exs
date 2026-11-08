defmodule TreninoWeb.GaugeSetupTest do
  # The gauge section and calibration panel call Trenino.Hardware from the LiveView
  # process, so the Mimic stubs are global.
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Trenino.GaugeFixtures

  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train
  alias Trenino.Train.{GaugeBinding, GaugeController}
  alias TreninoWeb.GaugeGuidance

  @port "/dev/ttyGAUGE"

  setup :set_mimic_global

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    %{device: device}
  end

  defp open_config(conn, device) do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    view
  end

  describe "gauges section" do
    setup do
      stub(Hardware, :gauge_link, fn _ -> {:error, :device_not_connected} end)
      :ok
    end

    test "adds a gauge from a board preset", %{conn: conn, device: device} do
      view = open_config(conn, device)
      assert has_element?(view, "#gauges [data-section-empty]", "No gauges configured")

      view |> element("#gauge-add") |> render_click()
      assert has_element?(view, "#gauge-form")

      view
      |> form("#gauge-form", gauge: %{preset: "board_b"})
      |> render_change(%{"_target" => ["gauge", "preset"]})

      assert has_element?(view, "#gauge-pin-0[value='14']")
      assert has_element?(view, "#gauge-pin-1[value='16']")
      assert has_element?(view, "#gauge-pin-2[value='6']")

      # A later pin edit is kept even though the preset select still reads board_b.
      view
      |> form("#gauge-form", gauge: %{preset: "board_b", pins: %{"2" => "9"}})
      |> render_change(%{"_target" => ["gauge", "pins", "2"]})

      assert has_element?(view, "#gauge-pin-2[value='9']")

      view
      |> form("#gauge-form", gauge: %{pins: %{"2" => "6"}})
      |> render_change(%{"_target" => ["gauge", "pins", "2"]})

      view
      |> form("#gauge-form", gauge: %{name: "Brake pipe", preset: "board_b"})
      |> render_submit()

      assert [%Gauge{id: id, name: "Brake pipe", driver: :vid6606, pins: [14, 16, 6, 255]}] =
               Hardware.list_gauges(device.id)

      refute has_element?(view, "#gauge-form")
      assert has_element?(view, "#gauge-#{id}", "Brake pipe")
      assert has_element?(view, "#gauge-#{id}", "STEP 14 · DIR 16 · RESET_N 6")
      assert has_element?(view, "#gauge-status-#{id}", "Needs calibration")
      assert has_element?(view, "#section-nav a[href='#gauges'] .badge", "1")
    end

    test "adds a gauge with pins entered by hand", %{conn: conn, device: device} do
      view = open_config(conn, device)
      view |> element("#gauge-add") |> render_click()

      view
      |> form("#gauge-form", gauge: %{name: "Speed", pins: %{"0" => "9", "1" => "10", "2" => ""}})
      |> render_submit()

      assert [%Gauge{pins: [9, 10, 255, 255], travel: 3780}] = Hardware.list_gauges(device.id)
    end

    test "a pin used by another gauge is reported and nothing is saved", %{
      conn: conn,
      device: device
    } do
      existing = gauge_fixture(device.id)
      view = open_config(conn, device)
      view |> element("#gauge-add") |> render_click()

      html =
        view
        |> form("#gauge-form", gauge: %{name: "Clash", pins: %{"0" => "8", "1" => "9"}})
        |> render_change()

      assert html =~ "Pins pin 8 is used by another gauge"

      view
      |> form("#gauge-form", gauge: %{name: "Clash", pins: %{"0" => "8", "1" => "9"}})
      |> render_submit()

      assert has_element?(view, "#gauge-form", "pin 8 is used by another gauge")
      assert [%Gauge{id: id}] = Hardware.list_gauges(device.id)
      assert id == existing.id
    end

    test "missing required pins are reported", %{conn: conn, device: device} do
      view = open_config(conn, device)
      view |> element("#gauge-add") |> render_click()

      view |> form("#gauge-form", gauge: %{name: "No pins"}) |> render_submit()

      assert has_element?(view, "#gauge-form p.text-error", "Pins")
      assert Hardware.list_gauges(device.id) == []
    end

    test "edits a gauge", %{conn: conn, device: device} do
      gauge = gauge_fixture(device.id)
      view = open_config(conn, device)

      view |> element("#gauge-edit-#{gauge.id}") |> render_click()
      assert has_element?(view, "#gauge-form input[name='gauge[name]'][value='Speedometer']")
      assert has_element?(view, "#gauge-pin-0[value='8']")

      view |> form("#gauge-form", gauge: %{name: "Tachometer"}) |> render_submit()

      assert {:ok, %Gauge{name: "Tachometer", pins: [8, 7, 6, 255]}} =
               Hardware.get_gauge(gauge.id)

      assert has_element?(view, "#gauge-#{gauge.id} h4", "Tachometer")
    end

    test "deletes a gauge", %{conn: conn, device: device} do
      gauge = gauge_fixture(device.id)
      view = open_config(conn, device)

      assert has_element?(view, "#gauge-delete-#{gauge.id}[data-confirm]")
      view |> element("#gauge-delete-#{gauge.id}") |> render_click()

      assert Hardware.list_gauges(device.id) == []
      refute has_element?(view, "#gauge-#{gauge.id}")
    end

    test "add is disabled once the device has four gauges", %{conn: conn, device: device} do
      for {pins, n} <-
            Enum.with_index([[8, 7, 6, 255], [14, 16, 6, 255], [21, 20, 6, 255], [5, 4, 6, 255]]) do
        gauge_fixture(device.id, %{name: "Gauge #{n}", pins: pins})
      end

      view = open_config(conn, device)
      assert has_element?(view, "#gauge-add[disabled]")
      assert has_element?(view, "#gauges", "A controller drives at most 4 gauges.")
    end
  end

  describe "calibration panel" do
    setup %{device: device} do
      %{gauge: gauge_fixture(device.id)}
    end

    # The gauge controller is not started in tests, so its hold API is stubbed to report
    # what the panel asks for.
    defp track_holds do
      test_pid = self()

      stub(GaugeController, :hold_manual, fn id, opts ->
        send(test_pid, {:hold, id, opts[:owner]})
        :ok
      end)

      stub(GaugeController, :release_manual, fn id ->
        send(test_pid, {:release, id})
        :ok
      end)

      stub(Hardware, :set_gauge_position, fn _port, %Gauge{id: id}, position ->
        send(test_pid, {:moved, id, position})
        :ok
      end)
    end

    test "opening takes the gauge, parks the needle at 0, and Done hands it back", %{
      conn: conn,
      device: device,
      gauge: gauge
    } do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      track_holds()
      id = gauge.id

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{id}") |> render_click()

      assert_receive {:hold, ^id, owner}
      assert owner == view.pid
      assert_receive {:moved, ^id, 0}

      view |> element("#gauge-calibration-close-#{id}") |> render_click()
      assert_receive {:release, ^id}
    end

    test "switching to another gauge, editing or adding hands the first gauge back", %{
      conn: conn,
      device: device,
      gauge: gauge
    } do
      other = gauge_fixture(device.id, %{name: "Brake", pins: [14, 16, 6, 255]})
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      track_holds()
      {id, other_id} = {gauge.id, other.id}

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{id}") |> render_click()
      assert_receive {:hold, ^id, _}

      view |> element("#gauge-calibrate-#{other_id}") |> render_click()
      assert_receive {:release, ^id}
      assert_receive {:hold, ^other_id, _}

      view |> element("#gauge-edit-#{id}") |> render_click()
      assert_receive {:release, ^other_id}
      refute has_element?(view, "#gauge-calibration-panel-#{other_id}")

      view |> element("#gauge-calibrate-#{id}") |> render_click()
      assert_receive {:hold, ^id, _}
      view |> element("#gauge-add") |> render_click()
      assert_receive {:release, ^id}
    end

    test "after an Apply the panel parks the re-zeroed needle at 0 again", %{
      conn: conn,
      device: device,
      gauge: gauge
    } do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      track_holds()
      id = gauge.id

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{id}") |> render_click()
      assert_receive {:moved, ^id, 0}

      view |> form("#gauge-position-#{id}", %{position: "500"}) |> render_change()
      assert_receive {:moved, ^id, 500}

      {:ok, device} = Hardware.get_device(device.id)
      send(view.pid, {:configuration_applied, @port, device, device.config_id})
      render(view)

      assert_receive {:moved, ^id, 0}
      assert render(view) =~ "the needle is back at 0"
      assert has_element?(view, "#gauge-position-range-#{id}[value='0']")
    end

    test "a malformed point index changes nothing", %{conn: conn, device: device, gauge: gauge} do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      track_holds()
      id = gauge.id

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{id}") |> render_click()

      for value <- ["0", "100"] do
        view |> form("#gauge-add-point-#{id}", %{value: value}) |> render_submit()
      end

      assert render(view) =~ "Remove point 100.0"

      view
      |> element("#gauge-points-#{id} button[aria-label='Remove point 100.0']")
      |> render_click(%{"index" => "-1"})

      assert render(view) =~ "Remove point 100.0"
      assert render(view) =~ "Remove point 0.0"
    end

    test "moves and re-zeroes the needle through the device link", %{
      conn: conn,
      device: device,
      gauge: gauge
    } do
      test_pid = self()
      gauge_id = gauge.id
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)

      stub(Hardware, :set_gauge_position, fn @port, %Gauge{id: ^gauge_id}, position ->
        send(test_pid, {:moved, position})
        :ok
      end)

      stub(Hardware, :zero_gauge, fn @port, %Gauge{id: ^gauge_id} ->
        send(test_pid, :zeroed)
        :ok
      end)

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{gauge.id}") |> render_click()
      assert has_element?(view, "#gauge-calibration-panel-#{gauge.id}")
      refute has_element?(view, "#gauge-calibration-panel-#{gauge.id} [role=alert]")

      view |> form("#gauge-position-#{gauge.id}", %{position: "500"}) |> render_change()
      assert_receive {:moved, 500}

      view |> element("#gauge-nudge-#{gauge.id}-10") |> render_click()
      assert_receive {:moved, 510}

      # Positions are clamped to the gauge's travel.
      view |> form("#gauge-position-#{gauge.id}", %{position: "99999"}) |> render_change()
      assert_receive {:moved, 3780}

      view |> element("#gauge-zero-#{gauge.id}") |> render_click()
      assert_receive :zeroed
      assert has_element?(view, "#gauge-calibration-panel-#{gauge.id} [role=status]", "Zeroing")

      view |> element("#gauge-calibration-close-#{gauge.id}") |> render_click()
      refute has_element?(view, "#gauge-calibration-panel-#{gauge.id}")
    end

    test "points saved as reviewed calibrate the dial and update the status chip", %{
      conn: conn,
      device: device,
      gauge: gauge
    } do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      stub(Hardware, :set_gauge_position, fn _, _, _ -> :ok end)

      view = open_config(conn, device)
      assert has_element?(view, "#gauge-status-#{gauge.id}", "Needs calibration")
      view |> element("#gauge-calibrate-#{gauge.id}") |> render_click()

      view |> form("#gauge-add-point-#{gauge.id}", %{value: "0"}) |> render_submit()
      view |> form("#gauge-position-#{gauge.id}", %{position: "1890"}) |> render_change()
      view |> form("#gauge-add-point-#{gauge.id}", %{value: "100"}) |> render_submit()
      view |> form("#gauge-unit-#{gauge.id}", %{unit: "mph"}) |> render_change()

      assert has_element?(view, "#gauge-points-#{gauge.id} tbody tr", "1890")

      view |> element("#gauge-save-reviewed-#{gauge.id}") |> render_click()

      assert {:ok,
              %DialCalibration{
                reviewed: true,
                valid: true,
                output_unit: :mph,
                points: [%{value: +0.0, position: 0}, %{value: 100.0, position: 1890}]
              }} = Hardware.get_dial_calibration(gauge.id)

      assert has_element?(view, "#gauge-calibration-panel-#{gauge.id}", "Dial saved and reviewed")

      # The page refreshes the section after the save message; let it settle.
      _ = render(view)
      _ = render(view)
      assert has_element?(view, "#gauge-status-#{gauge.id}", "Calibrated")
    end

    test "a draft save leaves the dial not reviewed", %{conn: conn, device: device, gauge: gauge} do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      stub(Hardware, :set_gauge_position, fn _, _, _ -> :ok end)

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{gauge.id}") |> render_click()
      view |> form("#gauge-add-point-#{gauge.id}", %{value: "0"}) |> render_submit()
      view |> form("#gauge-position-#{gauge.id}", %{position: "1000"}) |> render_change()
      view |> form("#gauge-add-point-#{gauge.id}", %{value: "50"}) |> render_submit()
      view |> element("#gauge-save-draft-#{gauge.id}") |> render_click()

      assert {:ok, %DialCalibration{reviewed: false}} = Hardware.get_dial_calibration(gauge.id)
      _ = render(view)
      _ = render(view)
      assert has_element?(view, "#gauge-status-#{gauge.id}", "Dial not reviewed")
    end

    test "a non-numeric dial value is rejected", %{conn: conn, device: device, gauge: gauge} do
      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      stub(Hardware, :set_gauge_position, fn _, _, _ -> :ok end)
      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{gauge.id}") |> render_click()

      view |> form("#gauge-add-point-#{gauge.id}", %{value: "fast"}) |> render_submit()

      assert has_element?(
               view,
               "#gauge-calibration-panel-#{gauge.id} [role=alert]",
               "Enter the number the dial shows."
             )

      refute has_element?(view, "#gauge-points-#{gauge.id}")
    end

    test "without an applied configuration the panel warns and disables the motion controls",
         %{conn: conn, device: device, gauge: gauge} do
      stub(Hardware, :gauge_link, fn _ -> {:error, :needs_apply} end)
      reject(&Hardware.set_gauge_position/3)
      reject(&Hardware.zero_gauge/2)

      view = open_config(conn, device)
      view |> element("#gauge-calibrate-#{gauge.id}") |> render_click()

      assert has_element?(
               view,
               "#gauge-calibration-panel-#{gauge.id} [role=alert]",
               "Apply the configuration first"
             )

      assert has_element?(view, "#gauge-position-range-#{gauge.id}[disabled]")
      assert has_element?(view, "#gauge-zero-#{gauge.id}[disabled]")
      assert has_element?(view, "#gauge-nudge-#{gauge.id}-10[disabled]")

      # Points can still be edited and saved offline.
      refute has_element?(view, "#gauge-save-reviewed-#{gauge.id}[disabled]")
      view |> form("#gauge-add-point-#{gauge.id}", %{value: "0"}) |> render_submit()
      assert has_element?(view, "#gauge-points-#{gauge.id} tbody tr", "0")
    end
  end

  describe "train gauge bindings" do
    setup %{device: device} do
      stub(Hardware, :gauge_link, fn _ -> {:error, :device_not_connected} end)

      {:ok, train} =
        Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

      %{train: train, gauge: gauge_fixture(device.id)}
    end

    test "add is disabled until a hardware gauge exists", %{conn: conn, gauge: gauge} do
      {:ok, _} = Hardware.delete_gauge(gauge)

      {:ok, train} =
        Train.create_train(%{name: "Empty", identifiers: [%{identifier: "EmptyTrain"}]})

      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      assert has_element?(view, "#gauge-add[disabled]")
      assert has_element?(view, "#gauge-prerequisites", "Add a gauge")
    end

    test "picks a gauge, and enabling is blocked until its dial is reviewed", %{
      conn: conn,
      device: device,
      train: train,
      gauge: gauge
    } do
      calibrated = calibrated_gauge_fixture(device.id, %{name: "Brake", pins: [14, 16, 6, 255]})

      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()

      assert has_element?(
               view,
               "select[name='gauge_binding[gauge_id]'] option[value='#{gauge.id}'][selected]",
               "Panel · Speedometer"
             )

      assert has_element?(view, "#gauge-dial-status", "No dial calibration")
      assert has_element?(view, "#gauge-dial-status a", "Set up gauge")

      assert has_element?(
               view,
               "#gauge-enable-reason",
               "Calibrate it in the hardware configuration"
             )

      assert has_element?(view, "input[name='gauge_binding[enabled]'][disabled]")

      view
      |> form("#gauge-binding-form", gauge_binding: %{gauge_id: calibrated.id})
      |> render_change()

      assert has_element?(view, "#gauge-dial-status", "Dial calibrated")
      refute has_element?(view, "#gauge-enable-reason")
      refute has_element?(view, "input[name='gauge_binding[enabled]'][disabled]")

      view
      |> form("#gauge-binding-form",
        gauge_binding: %{
          gauge_id: calibrated.id,
          name: "Brake gauge",
          endpoint: "BrakePipe",
          enabled: "true"
        }
      )
      |> render_submit()

      assert [%GaugeBinding{gauge_id: gauge_id, enabled: true, name: "Brake gauge"}] =
               Train.list_gauge_bindings(train.id)

      assert gauge_id == calibrated.id
    end

    test "a binding saves disabled on an uncalibrated gauge and shows simulator feedback", %{
      conn: conn,
      train: train,
      gauge: gauge
    } do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      view |> element("#gauge-add") |> render_click()
      view |> element("#gauge-class323") |> render_click()

      view
      |> form("#gauge-binding-form",
        gauge_binding: %{name: "Speedometer", endpoint: "VerifiedSpeed"}
      )
      |> render_submit()

      assert [%GaugeBinding{id: binding_id, enabled: false, input_unit: :mps, gauge_id: gauge_id}] =
               Train.list_gauge_bindings(train.id)

      assert gauge_id == gauge.id
      assert has_element?(view, "#gauge-status-#{binding_id}", "Off")
      assert has_element?(view, "#gauge-dial-#{binding_id}", "No dial calibration")

      # Enabling the saved binding is refused without a reviewed dial.
      view |> element("#gauge-toggle-#{binding_id}") |> render_click()
      assert [%GaugeBinding{enabled: false}] = Train.list_gauge_bindings(train.id)

      send(
        view.pid,
        {:gauge_binding_updated, binding_id,
         %{sample: 44.704, value: 100.0, target: 1890, stale: true, failure: nil}}
      )

      # The page forwards the event to the wizard with send_update, one message later.
      _ = render(view)
      html = render(view)
      assert html =~ "Estimated target: 1890 steps"
      assert html =~ "Simulator data is stale"
    end
  end

  describe "guidance" do
    test "blocker explains why an enabled binding cannot move", %{device: device} do
      uncalibrated = gauge_fixture(device.id)

      b = %GaugeBinding{enabled: true, gauge: uncalibrated}
      assert GaugeGuidance.blocker(b, false) =~ "simulator is not connected"
      assert GaugeGuidance.blocker(b, true) =~ "dial is not calibrated"
      assert GaugeGuidance.blocker(%{b | enabled: false}, true) == nil

      calibrated = calibrated_gauge_fixture(device.id, %{name: "Brake", pins: [14, 16, 6, 255]})
      b = %{b | gauge: calibrated}

      stub(Hardware, :gauge_link, fn _ -> {:error, :needs_apply} end)
      assert GaugeGuidance.blocker(b, true) =~ "Apply the configuration first"

      stub(Hardware, :gauge_link, fn _ -> {:ok, @port} end)
      assert GaugeGuidance.blocker(b, true) == nil
    end

    test "dial status names the calibration state", %{device: device} do
      gauge = gauge_fixture(device.id)
      assert %{label: "Needs calibration"} = GaugeGuidance.dial_status(gauge)

      assert %{label: "Dial not reviewed"} =
               GaugeGuidance.dial_status(%{
                 gauge
                 | dial_calibration: %DialCalibration{reviewed: false}
               })

      assert %{kind: :ok, label: "Calibrated"} =
               GaugeGuidance.dial_status(%{
                 gauge
                 | dial_calibration: %DialCalibration{valid: true, reviewed: true}
               })
    end

    test "train hint names the detected identifier" do
      train = %Trenino.Train.Train{
        identifiers: [%Trenino.Train.TrainIdentifier{identifier: "Class323_DMS_A"}]
      }

      assert GaugeGuidance.train_hint(train, nil) == nil
      assert GaugeGuidance.train_hint(train, "Class323_DMS_A-1") == nil
      assert GaugeGuidance.train_hint(train, "Class323_DMS_B") =~ "\"Class323_DMS_B\""
    end
  end
end
