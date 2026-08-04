defmodule TreninoWeb.VirtualJoystickLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Trenino.VirtualJoystickFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Repo
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverInputBinding
  alias Trenino.VirtualJoystick

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    {:ok, _} = Trenino.Settings.set_error_reporting(:disabled)
    :ok
  end

  test "navigation opens the standalone page and reports unsupported platforms", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/virtual-joystick")

    assert html =~ "Virtual joystick"

    assert has_element?(
             view,
             "[data-testid='virtual-joystick-status'][aria-live='polite']",
             "Unavailable"
           )

    assert has_element?(view, "[data-testid='virtual-joystick-toggle'][disabled]")
    assert html =~ "Windows 10 or 11"
  end

  test "renders every manager state with only its permitted recovery action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")

    states = [
      {:off, "Off", "Enable", nil},
      {:enabling, "Turning on", nil, nil},
      {:active, "On", "Disable", nil},
      {:disabling, "Turning off", nil, nil},
      {:needs_setup, "Setup needed", nil, "Retry"},
      {:needs_cleanup, "Cleanup needed", nil, "Remove leftover device"},
      {:degraded, "Connection interrupted", nil, "Retry"},
      {:error, "Needs attention", nil, "Retry"}
    ]

    for {status, label, toggle, recovery} <- states do
      send(view.pid, {:virtual_joystick_status_changed, status})
      assert render(view) =~ label

      if toggle,
        do: assert(has_element?(view, "button[data-testid='virtual-joystick-toggle']", toggle))

      if recovery,
        do:
          assert(has_element?(view, "button[data-testid='virtual-joystick-recovery']", recovery))
    end
  end

  test "toggle confirmation explains elevation, can be cancelled, and transitions disable controls",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")
    send(view.pid, {:virtual_joystick_status_changed, :off})

    view |> element("button[data-testid='virtual-joystick-toggle']") |> render_click()
    assert has_element?(view, "[role='dialog'][aria-modal='true']", "administrator permission")

    view |> element("button[data-testid='cancel-transition']") |> render_click()
    refute has_element?(view, "[role='dialog']")

    send(view.pid, {:virtual_joystick_status_changed, :enabling})
    assert has_element?(view, "button[data-testid='virtual-joystick-toggle'][disabled]")
    assert render(view) =~ "You can cancel the Windows prompt. No change will be made."
  end

  test "groups all eight axes and 32 buttons and filters compatible inputs", %{conn: conn} do
    device = device_fixture(%{name: "Cab controls"})
    analog_input_fixture(%{device: device, name: "Throttle", pin: 3})
    button_input_fixture(%{device: device, name: "Acknowledge", pin: 4})

    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")
    view |> element("button[data-testid='add-axis-mapping']") |> render_click()

    assert has_element?(view, "[data-testid='axis-target-option']", "Slider 2")
    assert has_element?(view, "option", "Cab controls · Throttle")
    refute render(view) =~ "Cab controls · Acknowledge"

    view |> element("button[data-testid='cancel-mapping']") |> render_click()
    view |> element("button[data-testid='add-button-mapping']") |> render_click()

    assert length(has_element_ids(view, "[data-testid='button-target-option']")) == 32
    assert has_element?(view, "option", "Cab controls · Acknowledge")
  end

  test "creates, edits, previews, and deletes a mapping", %{conn: conn} do
    input = analog_input_fixture(%{name: "Brake"})
    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")

    view |> element("button[data-testid='add-axis-mapping']") |> render_click()
    send(view.pid, {:input_value_updated, "COM7", input.pin + 1, 900})
    assert has_element?(view, "[data-testid='input-preview']", "Move the control")
    send(view.pid, {:input_value_updated, "COM7", input.pin, 512})
    assert has_element?(view, "[data-testid='input-preview']", "50%")

    view
    |> form("[data-testid='mapping-form']",
      mapping: %{input_id: input.id, axis: "x", inverted: "false"}
    )
    |> render_submit()

    assert has_element?(view, "[data-testid='axis-mapping-x']", "Brake")
    mapping = hd(VirtualJoystick.list_mappings())

    view |> element("button[data-testid='edit-mapping-#{mapping.id}']") |> render_click()
    assert has_element?(view, "select[disabled]")

    view
    |> form("[data-testid='mapping-form']",
      mapping: %{input_id: input.id, axis: "y", inverted: "true"}
    )
    |> render_submit()

    assert has_element?(view, "[data-testid='axis-mapping-y']", "Inverted")
    view |> element("button[data-testid='delete-mapping-#{mapping.id}']") |> render_click()
    assert has_element?(view, "[data-testid='axis-mapping-y']", "Not assigned")
  end

  test "shows duplicate targets and requires explicit simulator destination replacement", %{
    conn: conn
  } do
    device = device_fixture()
    first = analog_input_fixture(%{name: "Power", pin: 5, device: device})
    second = analog_input_fixture(%{name: "Brake", pin: 6, device: device})
    {:ok, _} = VirtualJoystick.put_mapping(first.id, %{target_type: :axis, axis: :x})

    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")
    view |> element("button[data-testid='add-axis-mapping']") |> render_click()

    view
    |> form("[data-testid='mapping-form']",
      mapping: %{input_id: second.id, axis: "x", inverted: "false"}
    )
    |> render_submit()

    assert has_element?(view, "[role='alert']", "already assigned")

    {:ok, train} = TrainContext.create_train(%{name: "Test train", identifier: "test-train"})
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Brake", type: :lever})

    {:ok, config} =
      TrainContext.create_lever_config(element.id, %{
        min_endpoint: "Brake.MinValue",
        max_endpoint: "Brake.MaxValue",
        value_endpoint: "Brake.InputValue"
      })

    {:ok, _binding} =
      Repo.insert(
        LeverInputBinding.changeset(%LeverInputBinding{}, %{
          lever_config_id: config.id,
          input_id: second.id,
          enabled: true
        })
      )

    view
    |> form("[data-testid='mapping-form']",
      mapping: %{input_id: second.id, axis: "y", inverted: "false"}
    )
    |> render_submit()

    assert has_element?(view, "[role='dialog']", "simulator or API")
    assert has_element?(view, "button[data-testid='confirm-replacement']", "Replace binding")
  end

  test "transition states disable every mapping mutation and status reasons guide recovery", %{
    conn: conn
  } do
    input = analog_input_fixture(%{name: "Throttle"})
    {:ok, mapping} = VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :rx})
    {:ok, view, _html} = live(conn, ~p"/virtual-joystick")

    send(view.pid, {:virtual_joystick_status_details_changed, %{status: :enabling, reason: nil}})
    assert has_element?(view, "button[data-testid='add-axis-mapping'][disabled]")
    assert has_element?(view, "button[data-testid='add-button-mapping'][disabled]")
    assert has_element?(view, "button[data-testid='edit-mapping-#{mapping.id}'][disabled]")
    assert has_element?(view, "button[data-testid='delete-mapping-#{mapping.id}'][disabled]")

    send(
      view.pid,
      {:virtual_joystick_status_details_changed, %{status: :error, reason: :driver_missing}}
    )

    assert render(view) =~ "Repair the Trenino installation"

    assert has_element?(
             view,
             "button[data-testid='virtual-joystick-recovery']",
             "Check installation"
           )

    send(
      view.pid,
      {:virtual_joystick_status_details_changed, %{status: :needs_setup, reason: :uac_cancelled}}
    )

    assert render(view) =~ "Permission was cancelled. No change was made."
  end

  defp has_element_ids(view, selector) do
    testid =
      Regex.run(~r/data-testid='([^']+)'/, selector, capture: :all_but_first) |> List.first()

    Regex.scan(~r/data-testid="#{Regex.escape(testid)}"/, render(view))
  end
end
