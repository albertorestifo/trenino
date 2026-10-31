defmodule TreninoWeb.DialCalibrationTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.{Hardware, Train}
  alias Trenino.Hardware.StepperManager

  setup :set_mimic_global

  setup %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    %{view: view, axis: axis, device: device, id: "dial-calibration-#{axis.id}"}
  end

  defp open(view, id), do: view |> element("##{id}-toggle") |> render_click()

  test "the axis card shows the dial status and the editor starts closed", %{view: view, id: id} do
    assert has_element?(view, "##{id}-status", "No dial calibration yet")
    refute has_element?(view, "##{id}-form")
    open(view, id)
    assert has_element?(view, "##{id}-form")
    assert has_element?(view, "##{id}-points")
  end

  test "every measuring control states why it is disabled", %{view: view, id: id} do
    open(view, id)
    assert has_element?(view, "button##{id}-claim[disabled]")
    assert has_element?(view, "##{id}-claim-reason", "not connected")
    assert has_element?(view, "button##{id}-test-value[disabled]")
    assert has_element?(view, "button##{id}-capture[disabled]")
  end

  test "manual control taken for the dial can be released without saving", %{
    conn: conn,
    axis: axis,
    device: device,
    id: id
  } do
    test_pid = self()

    stub(StepperManager, :snapshot, fn _ ->
      runtime = %{
        ready: false,
        status: nil,
        pending: nil,
        updated_at: System.monotonic_time(:millisecond),
        lease: nil,
        config: axis,
        paused: false,
        error: nil
      }

      %{lifecycle: :awaiting_reference, axes: %{axis.id => runtime}}
    end)

    stub(StepperManager, :claim_manual, fn _, _ -> {:ok, :token} end)

    stub(StepperManager, :release_manual, fn _, token ->
      send(test_pid, {:released, token})
      :ok
    end)

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    open(view, id)
    refute has_element?(view, "##{id}-release")

    view |> element("##{id}-claim") |> render_click()
    assert has_element?(view, "##{id}-release")

    view |> element("##{id}-release") |> render_click()
    assert_receive {:released, :token}
    refute has_element?(view, "##{id}-release")
    assert has_element?(view, "##{id}-form")
    assert Hardware.get_dial_calibration(axis.id) == {:error, :not_found}
  end

  test "preview is pure: it reports the target and saves nothing", %{view: view, id: id} do
    open(view, id)
    view |> element("##{id}-starter") |> render_click()

    view
    |> form("##{id}-form")
    |> render_submit(%{"intent" => "preview", "test_value" => "50"})

    assert has_element?(view, "##{id}-preview-result", "estimated target: 360")
    assert Hardware.get_dial_calibration(1) == {:error, :not_found}
  end

  test "save unreviewed, then reviewed, and the status follows", %{
    view: view,
    axis: axis,
    id: id
  } do
    open(view, id)
    view |> element("##{id}-starter") |> render_click()
    view |> form("##{id}-form") |> render_submit(%{"intent" => "save"})

    assert {:ok, %{reviewed: false, output_unit: :mph}} = Hardware.get_dial_calibration(axis.id)
    assert has_element?(view, "##{id}-status", "not reviewed")

    assert has_element?(view, "##{id}-form")
    view |> form("##{id}-form", dial: %{reviewed: "true"}) |> render_submit(%{"intent" => "save"})

    assert {:ok, %{reviewed: true, valid: true}} = Hardware.get_dial_calibration(axis.id)
    assert has_element?(view, "##{id}-status", "Calibrated and reviewed")
  end

  test "invalid points are shown, block review and are not saved", %{
    view: view,
    axis: axis,
    id: id
  } do
    open(view, id)

    view
    |> form("##{id}-form",
      dial: %{points: %{"0" => %{value: "5", position: "0"}, "1" => %{value: "5", position: "9"}}}
    )
    |> render_change()

    assert has_element?(view, "##{id}-points", "values must increase")
    assert has_element?(view, "##{id}-review-reason", "Fix the calibration points")
    view |> form("##{id}-form") |> render_submit(%{"intent" => "save"})
    assert Hardware.get_dial_calibration(axis.id) == {:error, :not_found}
  end

  test "editing points withdraws a previous review", %{
    conn: conn,
    device: device,
    axis: axis,
    id: id
  } do
    {:ok, _} =
      Hardware.save_dial_calibration(axis, %{
        reviewed: true,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    {:ok, device_view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    open(device_view, id)

    device_view
    |> form("##{id}-form",
      dial: %{
        points: %{"0" => %{value: "0", position: "0"}, "1" => %{value: "90", position: "700"}}
      }
    )
    |> render_change()

    device_view |> form("##{id}-form") |> render_submit(%{"intent" => "save"})
    assert {:ok, %{reviewed: false}} = Hardware.get_dial_calibration(axis.id)
  end

  test "a train gauge sees the axis dial without any points of its own", %{axis: axis} do
    {:ok, _} =
      Hardware.save_dial_calibration(axis, %{
        reviewed: true,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    {:ok, train} = Train.create_train(%{name: "T", identifiers: [%{identifier: "T"}]})

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{name: "S", endpoint: "S", stepper_axis_id: axis.id})

    assert binding.stepper_axis_id == axis.id
  end
end
