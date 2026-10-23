defmodule TreninoWeb.DisplaySetupTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Simulator
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Train, as: TrainContext

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    {:ok, device} = Hardware.create_device(%{name: "Desk panel"})

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

    {:ok, train} =
      TrainContext.create_train(%{
        name: "Class 66",
        identifiers: [%{identifier: "BR_Class_66"}]
      })

    %{device: device, display: display, train: train}
  end

  test "display settings survive validation and a failed save", %{
    conn: conn,
    device: device,
    display: display
  } do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view
    |> element("[phx-click='open_edit_i2c_modal'][phx-value-id='#{display.id}']")
    |> render_click()

    params = %{
      name: String.duplicate("x", 101),
      module_chip: "ht16k33",
      i2c_address_raw: "0x70",
      display_type: "seven_segment",
      num_digits: "8",
      brightness_pct: "80",
      min_value: "-20",
      align_right: "false",
      has_dot: "false"
    }

    view |> element("#i2c-module-form") |> render_change(%{"i2c_module" => params})

    assert has_element?(
             view,
             "select[name='i2c_module[display_type]'] option[value='seven_segment'][selected]"
           )

    assert has_element?(view, "select[name='i2c_module[num_digits]'] option[value='8'][selected]")
    assert has_element?(view, "input[name='i2c_module[min_value]'][value='-20.0']")
    refute has_element?(view, "input[name='i2c_module[align_right]'][checked]")
    refute has_element?(view, "input[name='i2c_module[has_dot]'][checked]")
    view |> form("#i2c-module-form", i2c_module: params) |> render_submit()
    send(view.pid, {:devices_updated, []})
    render(view)
    assert has_element?(view, "select[name='i2c_module[num_digits]'] option[value='8'][selected]")
    assert has_element?(view, "#i2c-display-dialog[role='dialog'][aria-modal='true']")
  end

  test "invalid minimum stays visible with a field error", %{
    conn: conn,
    device: device,
    display: display
  } do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view
    |> element("[phx-click='open_edit_i2c_modal'][phx-value-id='#{display.id}']")
    |> render_click()

    view |> form("#i2c-module-form", i2c_module: %{min_value: "oops"}) |> render_change()
    assert has_element?(view, "#display-minimum[value='oops']")
    assert has_element?(view, "#display-advanced .text-error", "is invalid")
  end

  for minimum <- [0.0, -20.0, nil] do
    @minimum minimum
    test "blank minimum saves no limit from #{inspect(minimum)}", %{
      conn: conn,
      device: device,
      display: display
    } do
      {:ok, _} = Hardware.update_i2c_module(display, %{params: %{min_value: @minimum}})
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      view
      |> element("[phx-click='open_edit_i2c_modal'][phx-value-id='#{display.id}']")
      |> render_click()

      view |> form("#i2c-module-form", i2c_module: %{min_value: ""}) |> render_submit()
      {:ok, saved} = Hardware.get_i2c_module(display.id)
      assert saved.params.min_value == nil
    end
  end

  test "unchecked display options save as false", %{conn: conn, device: device, display: display} do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view
    |> element("[phx-click='open_edit_i2c_modal'][phx-value-id='#{display.id}']")
    |> render_click()

    view
    |> form("#i2c-module-form", i2c_module: %{align_right: "false", has_dot: "false"})
    |> render_submit()

    {:ok, saved} = Hardware.get_i2c_module(display.id)
    refute saved.params.align_right
    refute saved.params.has_dot
  end

  test "missing simulator and hardware have direct setup links", %{
    conn: conn,
    train: train,
    display: display
  } do
    {:ok, _} = Hardware.delete_i2c_module(display)
    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
    assert has_element?(view, "#display-prerequisites a[href='/settings']")
    assert has_element?(view, "#display-prerequisites a[href='/']")
    refute has_element?(view, "[role='dialog'][aria-labelledby='display-binding-title']")
  end

  test "choose a display before exploring simulator values and validate formats", %{
    conn: conn,
    train: train,
    display: display
  } do
    client = Client.new("http://localhost:8080", "test")
    stub(Simulator, :get_status, fn -> %ConnectionState{status: :connected, client: client} end)

    stub(Client, :list, fn _ ->
      send(self(), :explorer_loaded)
      {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
    end)

    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
    render(view)
    view |> element("[phx-click='open_add_display_binding']") |> render_click()
    assert has_element?(view, "#display-binding-dialog [phx-click='select_module']")
    refute has_element?(view, "#display-wizard-api-explorer")

    view
    |> element("[phx-click='select_module'][phx-value-module-id='#{display.id}']")
    |> render_click()

    send(view.pid, {:api_explorer_select, :endpoint, "CurrentDrivableActor/Speed"})
    render(view)

    view
    |> form("#display-binding-config-form", %{name: "Train speed", decimals: "2"})
    |> render_change()

    assert has_element?(view, "#display-format-preview", "42.50")

    view |> form("#display-binding-config-form", %{format_mode: "custom"}) |> render_change()

    view |> form("#display-binding-config-form", %{format_string: ""}) |> render_change()
    assert has_element?(view, "#save-display-binding[disabled]")

    view
    |> form("#display-binding-config-form", %{format_string: "{value:.999f}"})
    |> render_change()

    assert has_element?(view, "#display-format-error")
    assert has_element?(view, "#save-display-binding[disabled]")

    view
    |> form("#display-binding-config-form", %{format_string: "{value:.2f}"})
    |> render_change()

    view |> form("#display-binding-config-form") |> render_submit()
    [binding] = TrainContext.list_display_bindings(train.id)
    assert binding.format_string == "{value:.2f}"
    assert binding.name == "Train speed"
    refute has_element?(view, "#display-binding-dialog")
  end

  test "saved display bindings can be edited offline and save the submitted options", %{
    conn: conn,
    train: train,
    display: display
  } do
    {:ok, binding} =
      TrainContext.create_display_binding(train.id, %{
        i2c_module_id: display.id,
        endpoint: "CurrentDrivableActor/Speed",
        name: "Speed",
        format_string: "{value:.1f}"
      })

    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

    view
    |> element("[phx-click='configure_display_binding'][phx-value-id='#{binding.id}']")
    |> render_click()

    view
    |> form("#display-binding-config-form", %{name: "Precise speed", decimals: "3"})
    |> render_submit()

    {:ok, updated} = TrainContext.get_display_binding(binding.id)
    assert updated.name == "Precise speed"
    assert updated.format_string == "{value:.3f}"
  end

  test "current train ID can populate a full-width identifier row", %{conn: conn} do
    client = Client.new("http://localhost:8080", "test")
    stub(Simulator, :get_status, fn -> %ConnectionState{status: :connected, client: client} end)
    {:ok, view, _} = live(conn, ~p"/trains/new")

    view
    |> form("#train-form", train: %{name: "Detected class 66", description: "My panel"})
    |> render_change()

    send(view.pid, {:train_detected, %{identifier: "RVM_CURRENT_CLASS_66", train: nil}})
    render(view)
    view |> element("#use-current-train-id") |> render_click()

    assert has_element?(
             view,
             "input[name='train[identifiers][0][identifier]'][value='RVM_CURRENT_CLASS_66']"
           )

    assert has_element?(view, "button[name='train[identifiers_drop][]'][disabled]")
    view |> element("#use-current-train-id") |> render_click()
    assert has_element?(view, "#train_name[value='Detected class 66']")
    view |> form("#train-form") |> render_submit()
    trains = TrainContext.list_trains(preload: :identifiers)
    saved = Enum.find(trains, &(&1.name == "Detected class 66"))
    assert Enum.map(saved.identifiers, & &1.identifier) == ["RVM_CURRENT_CLASS_66"]
    assert saved.description == "My panel"
  end
end
