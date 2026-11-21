defmodule TreninoWeb.FirmwareLiveTest do
  use TreninoWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Trenino.Firmware
  alias Trenino.Firmware.FilePath
  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    stub(Circuits.UART, :enumerate, fn -> %{} end)
    start_supervised!(Connection)

    {:ok, release} =
      Firmware.create_release(%{
        version: "99.0.0",
        tag_name: "v99.0.0",
        published_at: DateTime.utc_now()
      })

    {:ok, _file} =
      Firmware.create_firmware_file(release.id, %{
        board_type: "uno",
        environment: "uno",
        download_url: "https://example.com/firmware.hex",
        file_size: 100
      })

    hex_path = FilePath.firmware_path("99.0.0", "uno")
    File.mkdir_p!(Path.dirname(hex_path))
    File.write!(hex_path, ":00000001FF\n")
    on_exit(fn -> File.rm(hex_path) end)

    :ok
  end

  test "an unresponsive serial port shows an upload error without logging an app error", %{
    conn: conn
  } do
    stub(Connection, :request_upload_access, fn "COM3" -> {:error, :port_timed_out} end)
    stub(Connection, :enumerate_ports, fn -> ["COM3"] end)

    {:ok, view, _html} = live(conn, ~p"/firmware?port=COM3")
    render_hook(view, "select_environment", %{"environment" => "uno"})

    log =
      capture_log([level: :error], fn ->
        html = render_hook(view, "start_upload", %{})
        assert html =~ "The upload could not start"
      end)

    refute log =~ "could not start"
    assert Process.alive?(view.pid)
  end
end
