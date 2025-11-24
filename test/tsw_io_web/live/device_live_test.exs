defmodule TswIoWeb.DeviceLiveTest do
  use TswIoWeb.ConnCase

  test "GET / renders device live", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "TWS IO"
    assert html_response(conn, 200) =~ "No Devices Connected"
  end
end
