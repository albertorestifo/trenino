defmodule Trenino.Hardware.InputTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.Input

  describe "changeset/2" do
    setup do
      {:ok, device} =
        Trenino.Hardware.create_device(%{
          name: "Test Device",
          config_id: :rand.uniform(999_999)
        })

      %{device: device}
    end

    test "valid analog changeset", %{device: device} do
      attrs = %{input_type: :analog, pin: 0, sensitivity: 5}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "valid button changeset", %{device: device} do
      attrs = %{input_type: :button, pin: 0, debounce: 20}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end
  end
end
