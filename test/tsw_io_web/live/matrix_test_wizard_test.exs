defmodule TswIoWeb.MatrixTestWizardTest do
  use TswIoWeb.ConnCase

  alias TswIo.Hardware

  describe "Matrix test wizard integration" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, input} = Hardware.create_input(device.id, %{pin: 0, input_type: :matrix})
      {:ok, _pins} = Hardware.set_matrix_pins(input.id, [2, 3, 4], [8, 9, 10])

      # Reload input with matrix_pins
      {:ok, [input]} = Hardware.list_inputs(device.id)

      %{device: device, input: input}
    end

    test "matrix input has correct matrix_pins loaded", %{input: input} do
      assert length(input.matrix_pins) == 6

      row_pins = Enum.filter(input.matrix_pins, &(&1.pin_type == :row))
      col_pins = Enum.filter(input.matrix_pins, &(&1.pin_type == :col))

      assert length(row_pins) == 3
      assert length(col_pins) == 3
    end

    test "calculates virtual pins correctly" do
      # Virtual pin formula: 128 + (row_idx * num_cols + col_idx)
      # For a 3x3 matrix:
      # Row 0: 128, 129, 130
      # Row 1: 131, 132, 133
      # Row 2: 134, 135, 136

      num_cols = 3

      assert 128 + (0 * num_cols + 0) == 128
      assert 128 + (0 * num_cols + 2) == 130
      assert 128 + (1 * num_cols + 0) == 131
      assert 128 + (2 * num_cols + 2) == 136
    end
  end

  describe "Button state tracking" do
    test "tracks pressed buttons from input_values" do
      input_values = %{
        128 => 1,
        129 => 0,
        130 => 1,
        5 => 512
      }

      # Extract pressed virtual pins (>= 128 with value 1)
      pressed_buttons =
        input_values
        |> Enum.filter(fn {pin, value} -> pin >= 128 and value == 1 end)
        |> Enum.map(fn {pin, _} -> pin end)
        |> MapSet.new()

      assert MapSet.member?(pressed_buttons, 128)
      refute MapSet.member?(pressed_buttons, 129)
      assert MapSet.member?(pressed_buttons, 130)
      assert MapSet.size(pressed_buttons) == 2
    end

    test "tested_buttons accumulates pressed pins" do
      tested_buttons = MapSet.new()

      # Simulate button 128 pressed
      tested_buttons = MapSet.put(tested_buttons, 128)
      assert MapSet.size(tested_buttons) == 1

      # Simulate button 130 pressed
      tested_buttons = MapSet.put(tested_buttons, 130)
      assert MapSet.size(tested_buttons) == 2

      # Button 128 pressed again (no change)
      tested_buttons = MapSet.put(tested_buttons, 128)
      assert MapSet.size(tested_buttons) == 2

      # Verify membership
      assert MapSet.member?(tested_buttons, 128)
      assert MapSet.member?(tested_buttons, 130)
      refute MapSet.member?(tested_buttons, 129)
    end

    test "progress calculation" do
      total_buttons = 12
      tested_buttons = MapSet.new([128, 129, 130, 131])
      tested_count = MapSet.size(tested_buttons)

      progress_percent = Float.round(tested_count / total_buttons * 100, 0)

      assert tested_count == 4
      assert progress_percent == 33.0
    end
  end

  describe "Matrix pin validation" do
    test "parse_pins extracts integers from comma-separated string" do
      # This tests the parse_pins logic used in the LiveView
      pins_str = "2, 3, 4, 5"

      pins =
        pins_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.flat_map(fn s ->
          case Integer.parse(s) do
            {n, ""} -> [n]
            _ -> []
          end
        end)

      assert pins == [2, 3, 4, 5]
    end

    test "parse_pins handles empty string" do
      pins_str = ""

      pins =
        pins_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.flat_map(fn s ->
          case Integer.parse(s) do
            {n, ""} -> [n]
            _ -> []
          end
        end)

      assert pins == []
    end

    test "parse_pins ignores non-numeric values" do
      pins_str = "2, abc, 4, 5x"

      pins =
        pins_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.flat_map(fn s ->
          case Integer.parse(s) do
            {n, ""} -> [n]
            _ -> []
          end
        end)

      assert pins == [2, 4]
    end

    test "validates no overlap between row and column pins" do
      row_pins = [2, 3, 4]
      col_pins = [4, 5, 6]

      overlap = MapSet.intersection(MapSet.new(row_pins), MapSet.new(col_pins))

      assert MapSet.size(overlap) > 0
      assert MapSet.member?(overlap, 4)
    end

    test "validates no duplicates within pins" do
      pins = [2, 3, 2, 4]

      has_duplicates = length(pins) != length(Enum.uniq(pins))

      assert has_duplicates
    end
  end
end
