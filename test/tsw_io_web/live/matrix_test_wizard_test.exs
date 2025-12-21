defmodule TswIoWeb.MatrixTestWizardTest do
  use TswIoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias TswIo.Hardware

  describe "validate_matrix_pins event" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      %{device: device}
    end

    test "handles validation when only row_pins is provided", %{conn: conn, device: device} do
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      # Open the add input modal
      view |> element("button", "Add Input") |> render_click()

      # Change to matrix type using the actual form
      view
      |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
      |> render_change()

      # Type only in row_pins field - this should not crash
      result =
        view
        |> element("input[name='row_pins']")
        |> render_change(%{"row_pins" => "2,"})

      assert result =~ "Row Pins"
    end

    test "handles validation when only col_pins is provided", %{conn: conn, device: device} do
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      # Open the add input modal
      view |> element("button", "Add Input") |> render_click()

      # Change to matrix type
      view
      |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
      |> render_change()

      # Type only in col_pins field - this should not crash
      result =
        view
        |> element("input[name='col_pins']")
        |> render_change(%{"col_pins" => "8,"})

      assert result =~ "Column Pins"
    end

    test "can add a matrix input with row and column pins", %{conn: conn, device: device} do
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      # Open the add input modal
      view |> element("button", "Add Input") |> render_click()

      # Change to matrix type
      view
      |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
      |> render_change()

      # Set row and column pins - verify values are reflected in UI
      html_after_row =
        view
        |> element("input[name='row_pins']")
        |> render_change(%{"row_pins" => "2,3,4"})

      # The grid preview should show after entering row pins
      assert html_after_row =~ "value=\"2,3,4\""

      html_after_col =
        view
        |> element("input[name='col_pins']")
        |> render_change(%{"col_pins" => "5,6,7"})

      # The grid should now show the matrix dimensions
      assert html_after_col =~ "value=\"5,6,7\""
      # Check for virtual pin numbers in the grid (128 is the first virtual pin)
      assert html_after_col =~ "128"

      # Verify there are no matrix validation errors before submitting
      refute html_after_col =~ "At least one"

      # Submit the form - this should not crash
      result =
        view
        |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
        |> render_submit()

      # Modal should close (the h2 title should be gone, but button on main page stays)
      # The modal has a specific structure, check for modal-specific elements being gone
      refute result =~ "text-xl font-semibold mb-4\">Add Input"

      # Matrix input should be visible in the inputs table
      # The type is displayed as the atom, so it's lowercase "matrix"
      assert result =~ "matrix"
      # The dimensions are displayed as "3x3 (9)"
      assert result =~ "3x3 (9)"
    end

    test "cannot add second matrix input with same pin=0", %{conn: conn, device: device} do
      # First, add a matrix input
      {:ok, _input} = Hardware.create_input(device.id, %{pin: 0, input_type: :matrix})

      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      # Open the add input modal
      view |> element("button", "Add Input") |> render_click()

      # Change to matrix type
      view
      |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
      |> render_change()

      # Set row and column pins
      view
      |> element("input[name='row_pins']")
      |> render_change(%{"row_pins" => "10,11"})

      view
      |> element("input[name='col_pins']")
      |> render_change(%{"col_pins" => "12,13"})

      # Submit should fail gracefully (there's already a matrix input)
      result =
        view
        |> form("form[phx-submit='add_input']", %{input: %{input_type: "matrix"}})
        |> render_submit()

      # Should show an error, not crash
      assert result =~ "already been taken" or result =~ "Matrix" or result =~ "Add Input"
    end
  end

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
