defmodule TreninoWeb.I2cModuleFormComponentTest.Host do
  @moduledoc false
  use TreninoWeb, :live_view

  @impl true
  def mount(_params, %{"device_id" => device_id, "module_id" => module_id}, socket) do
    mod =
      case module_id do
        nil ->
          nil

        id ->
          {:ok, mod} = Trenino.Hardware.get_i2c_module(id)
          mod
      end

    {:ok, assign(socket, device_id: device_id, mod: mod, saved: false), layout: false}
  end

  @impl true
  def handle_info(:i2c_module_saved, socket), do: {:noreply, assign(socket, :saved, true)}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={TreninoWeb.I2cModuleFormComponent}
      id="i2c-module-form-host"
      i2c_module={@mod}
      device_id={@device_id}
    />
    <p :if={@saved} id="saved">saved</p>
    """
  end
end

defmodule TreninoWeb.I2cModuleFormComponentTest do
  use TreninoWeb.ConnCase, async: false

  import Bitwise
  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Hardware.Input
  alias Trenino.Repo
  alias Trenino.VirtualJoystick

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Chip panel"})
    %{device: device}
  end

  defp open(conn, device, module \\ nil) do
    {:ok, view, _} =
      live_isolated(conn, TreninoWeb.I2cModuleFormComponentTest.Host,
        session: %{"device_id" => device.id, "module_id" => module && module.id}
      )

    view
  end

  defp choose_chip(view, chip) do
    view
    |> element("#i2c-module-form")
    |> render_change(%{"i2c_module" => %{"module_chip" => chip}})
  end

  defp pins(map) do
    for {pin, role} <- map, into: %{}, do: {to_string(pin), role}
  end

  defp create_mcp(device, params) do
    Hardware.create_i2c_module(device.id, %{
      module_chip: :mcp23017,
      i2c_address: 0x20,
      params: params
    })
  end

  defp create_ads(device, params, channels \\ %{}) do
    Hardware.create_i2c_module(device.id, %{
      module_chip: :ads1115,
      i2c_address: 0x48,
      params: params,
      channels: channels
    })
  end

  describe "chip selector" do
    test "create offers all chips with HT16K33 selected", %{conn: conn, device: device} do
      view = open(conn, device)

      assert has_element?(view, "#module-chip option[value='ht16k33'][selected]")
      assert has_element?(view, "#module-chip option[value='mcp23017']")
      assert has_element?(view, "#module-chip option[value='ads1115']")
      assert has_element?(view, "#display-type")
    end

    test "edit has no selector", %{conn: conn, device: device} do
      {:ok, mod} = create_ads(device, %{channel_mask: 1, gain: 0})
      view = open(conn, device, mod)

      refute has_element?(view, "#module-chip")

      assert has_element?(
               view,
               "input[type=hidden][name='i2c_module[module_chip]'][value=ads1115]"
             )
    end
  end

  describe "MCP23017 form" do
    test "renders 16 pins in two port columns", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      for pin <- 0..15, do: assert(has_element?(view, "select#pin-#{pin}"))
      refute has_element?(view, "#pin-16")
      assert has_element?(view, "fieldset legend", "Port A")
      assert has_element?(view, "fieldset legend", "Port B")
      assert has_element?(view, "label", "GPA0")
      assert has_element?(view, "label", "GPB7")
    end

    test "GPA7 and GPB7 offer only Unused and Row, with a note", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      for pin <- [7, 15] do
        assert has_element?(view, "#pin-#{pin} option[value='unused']")
        assert has_element?(view, "#pin-#{pin} option[value='row']")
        refute has_element?(view, "#pin-#{pin} option[value='direct']")
        refute has_element?(view, "#pin-#{pin} option[value='col']")
      end

      assert has_element?(view, "#pin-0 option[value='direct']")
      assert has_element?(view, "#pin-0 option[value='col']")
      assert has_element?(view, "#pin-output-only-note", "output-only")
    end

    test "assigning pins saves the masks and creates the inputs", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      view
      |> form("#i2c-module-form",
        i2c_module: %{
          name: "Switches",
          i2c_address_raw: "0x21",
          pins:
            pins(%{0 => "direct", 1 => "direct", 8 => "row", 9 => "row", 2 => "col", 3 => "col"})
        }
      )
      |> render_submit()

      assert has_element?(view, "#saved")
      assert [mod] = Hardware.list_i2c_modules(device.id)
      assert mod.module_chip == :mcp23017
      assert mod.i2c_address == 0x21
      assert mod.params.direct_mask == 0b11
      assert mod.params.row_mask == 0b11 <<< 8
      assert mod.params.col_mask == 0b1100
      assert length(Hardware.list_i2c_module_inputs(mod)) == 2 + 4
    end

    test "shows matrix size and remaining virtual pins", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      view
      |> element("#i2c-module-form")
      |> render_change(%{
        "i2c_module" => %{
          "module_chip" => "mcp23017",
          "pins" =>
            pins(%{
              0 => "row",
              1 => "row",
              2 => "row",
              3 => "row",
              8 => "col",
              9 => "col",
              10 => "col",
              11 => "col"
            })
        }
      })

      assert has_element?(view, "#mcp-matrix-size", "4 × 4, 16 buttons")
      assert has_element?(view, "#mcp-pins-left", "112 virtual pins left")
    end

    test "direct pins reserve a block of 16", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      view
      |> element("#i2c-module-form")
      |> render_change(%{
        "i2c_module" => %{
          "module_chip" => "mcp23017",
          "pins" => pins(%{0 => "direct", 1 => "direct"})
        }
      })

      assert has_element?(view, "#mcp-direct-count", "2 buttons")
      assert has_element?(view, "#mcp-pins-left", "112 virtual pins left")
    end

    test "debounce follows the layout until the user changes it", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")
      assert has_element?(view, "#mcp-debounce[value='3']")

      change = fn params ->
        view
        |> element("#i2c-module-form")
        |> render_change(%{"i2c_module" => Map.put(params, "module_chip", "mcp23017")})
      end

      change.(%{"pins" => pins(%{0 => "row", 8 => "col"})})
      assert has_element?(view, "#mcp-debounce[value='2']")

      change.(%{"debounce" => "7"})
      assert has_element?(view, "#mcp-debounce[value='7']")

      change.(%{"pins" => pins(%{0 => "unused", 8 => "unused", 1 => "direct"})})
      assert has_element?(view, "#mcp-debounce[value='7']")
    end

    test "debounce is sent explicitly on save", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      view
      |> form("#i2c-module-form",
        i2c_module: %{i2c_address_raw: "32", pins: pins(%{0 => "direct"}), debounce: "6"}
      )
      |> render_submit()

      assert [mod] = Hardware.list_i2c_modules(device.id)
      assert mod.params.debounce == 6
    end

    test "edit prefills the saved layout", %{conn: conn, device: device} do
      {:ok, mod} = create_mcp(device, %{direct_mask: 0b1, row_mask: 0x80, col_mask: 0b10})
      view = open(conn, device, mod)

      assert has_element?(view, "#pin-0 option[value='direct'][selected]")
      assert has_element?(view, "#pin-7 option[value='row'][selected]")
      assert has_element?(view, "#pin-1 option[value='col'][selected]")
      assert has_element?(view, "#pin-2 option[value='unused'][selected]")
      assert has_element?(view, "#mcp-matrix-size", "1 × 1, 1 buttons")
    end

    test "validation errors appear in the form", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "mcp23017")

      view
      |> form("#i2c-module-form", i2c_module: %{i2c_address_raw: "0x30"})
      |> render_submit()

      html = render(view)
      assert html =~ "The chip needs at least one input"
      assert has_element?(view, "input#chip-address.input-error")
      assert html =~ "must be between"
      refute has_element?(view, "#saved")
    end
  end

  describe "ADS1115 form" do
    test "saves channels, gain, reference, names and sensitivity", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      view
      |> element("#i2c-module-form")
      |> render_change(%{
        "i2c_module" => %{
          "module_chip" => "ads1115",
          "channels" => %{"1" => %{"enabled" => "true"}, "2" => %{"enabled" => "true"}}
        }
      })

      view
      |> form("#i2c-module-form",
        i2c_module: %{
          i2c_address_raw: "0x49",
          gain: "1",
          ref_channel: "3",
          channels: %{
            "0" => %{enabled: "true", name: "Throttle", sensitivity: "7"},
            "1" => %{enabled: "false"},
            "2" => %{enabled: "true", name: "", sensitivity: "3"}
          }
        }
      )
      |> render_submit()

      assert has_element?(view, "#saved")
      assert [mod] = Hardware.list_i2c_modules(device.id)
      assert mod.params.channel_mask == 0b101
      assert mod.params.gain == 1
      assert mod.params.ref_channel == 3

      inputs = Map.new(Hardware.list_i2c_module_inputs(mod), &{&1.i2c_channel, &1})
      assert inputs[0].name == "Throttle"
      assert inputs[0].sensitivity == 7
      assert inputs[2].name == "AIN2"
      assert inputs[2].sensitivity == 3
    end

    test "reference choices exclude enabled channels", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      assert has_element?(view, "#ads-reference option[value='']")
      refute has_element?(view, "#ads-reference option[value='0']")
      assert has_element?(view, "#ads-reference option[value='1']")

      view
      |> element("#i2c-module-form")
      |> render_change(%{
        "i2c_module" => %{
          "module_chip" => "ads1115",
          "ref_channel" => "1",
          "channels" => %{"1" => %{"enabled" => "true"}}
        }
      })

      refute has_element?(view, "#ads-reference option[value='1']")
      assert has_element?(view, "#ads-reference option[value=''][selected]")
    end

    test "gain defaults to 6.144 V for a 5 V supply", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      assert has_element?(view, "#ads-gain option[value='0'][selected]", "±6.144 V")
      assert has_element?(view, "#ads-gain option[value='0']", "5 V supply")
      assert has_element?(view, "#ads-gain option[value='1']", "±4.096 V")
    end

    test "explains the supply reference", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      assert has_element?(
               view,
               "#ads-reference-hint",
               "Wrapping sensors need a supply reference, which uses one channel."
             )

      assert has_element?(view, "#ads-reference-hint", "must share the supply wired to it")
    end

    test "no channel enabled is an error", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      view
      |> form("#i2c-module-form",
        i2c_module: %{i2c_address_raw: "0x48", channels: %{"0" => %{enabled: "false"}}}
      )
      |> render_submit()

      assert has_element?(view, "#chip-errors", "Enable at least one channel.")
    end

    test "malformed channel params do not crash", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      view
      |> element("#i2c-module-form")
      |> render_submit(%{
        "i2c_module" => %{
          "module_chip" => "ads1115",
          "i2c_address_raw" => "0x48",
          "channels" => "oops"
        }
      })

      assert has_element?(view, "#chip-errors", "Enable at least one channel.")
    end

    test "a bad sensitivity is reported", %{conn: conn, device: device} do
      view = open(conn, device)
      choose_chip(view, "ads1115")

      view
      |> form("#i2c-module-form",
        i2c_module: %{
          i2c_address_raw: "0x48",
          channels: %{"0" => %{enabled: "true", name: "", sensitivity: "11"}}
        }
      )
      |> render_submit()

      # Raised by the child input, so it sits on the top-level :params error.
      assert has_element?(view, "#chip-errors", "AIN0: sensitivity")
      refute has_element?(view, "#saved")
    end
  end

  describe "editing with bindings" do
    setup %{device: device} do
      {:ok, mod} = create_ads(device, %{channel_mask: 0b11, gain: 0})
      input = Repo.get_by!(Input, i2c_module_id: mod.id, i2c_channel: 1)
      {:ok, _} = VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :x})
      %{mod: mod}
    end

    test "removing a bound channel asks for confirmation first", %{
      conn: conn,
      device: device,
      mod: mod
    } do
      view = open(conn, device, mod)

      submit = fn ->
        view
        |> form("#i2c-module-form", i2c_module: %{channels: %{"1" => %{enabled: "false"}}})
        |> render_submit()
      end

      submit.()
      refute has_element?(view, "#saved")
      assert has_element?(view, "#impact-confirmation", "AIN1")
      assert has_element?(view, "#impact-confirmation", "Virtual joystick")
      assert has_element?(view, "button[type=submit]", "Confirm and save")
      assert {:ok, %{params: %{channel_mask: 0b11}}} = Hardware.get_i2c_module(mod.id)

      submit.()
      assert has_element?(view, "#saved")
      assert {:ok, %{params: %{channel_mask: 0b01}}} = Hardware.get_i2c_module(mod.id)
    end

    test "changing the form resets the confirmation", %{conn: conn, device: device, mod: mod} do
      view = open(conn, device, mod)
      attrs = [i2c_module: %{channels: %{"1" => %{enabled: "false"}}}]

      view |> form("#i2c-module-form", attrs) |> render_submit()
      assert has_element?(view, "#impact-confirmation")

      view |> form("#i2c-module-form", i2c_module: %{name: "Renamed"}) |> render_change()
      refute has_element?(view, "#impact-confirmation")
    end

    test "an edit that removes nothing saves at once", %{conn: conn, device: device, mod: mod} do
      view = open(conn, device, mod)

      view
      |> form("#i2c-module-form", i2c_module: %{name: "Renamed"})
      |> render_submit()

      assert has_element?(view, "#saved")
    end

    test "a calibrated channel without bindings is listed too", %{
      conn: conn,
      device: device,
      mod: mod
    } do
      input = Repo.get_by!(Input, i2c_module_id: mod.id, i2c_channel: 0)

      {:ok, _} =
        Hardware.save_calibration(input.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })

      view = open(conn, device, mod)

      view
      |> form("#i2c-module-form",
        i2c_module: %{channels: %{"0" => %{enabled: "false"}, "1" => %{enabled: "true"}}}
      )
      |> render_submit()

      assert has_element?(view, "#impact-confirmation", "Calibration will be removed")
    end
  end

  describe "HT16K33 form" do
    test "still creates a display", %{conn: conn, device: device} do
      view = open(conn, device)

      view
      |> form("#i2c-module-form",
        i2c_module: %{name: "Speed", i2c_address_raw: "0x70", display_type: "seven_segment"}
      )
      |> render_submit()

      assert has_element?(view, "#saved")

      assert [%{module_chip: :ht16k33, params: %{display_type: :seven_segment}}] =
               Hardware.list_i2c_modules(device.id)
    end
  end
end
