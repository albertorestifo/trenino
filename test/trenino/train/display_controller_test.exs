defmodule Trenino.Train.DisplayControllerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train.DisplayController

  setup do
    start_supervised!(DisplayController)
    :ok
  end

  test "starts successfully" do
    assert pid = Process.whereis(DisplayController)
    assert Process.alive?(pid)
  end

  test "reload_bindings/0 returns :ok" do
    assert :ok = DisplayController.reload_bindings()
  end
end
