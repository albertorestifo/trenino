defmodule Trenino.Train.DisplayFormatterTest do
  use ExUnit.Case, async: true
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayFormatter

  test "{value} passes numeric value as string" do
    assert "42.5" = DisplayFormatter.format("{value}", 42.5)
  end

  test "{value} passes string value through" do
    assert "hello" = DisplayFormatter.format("{value}", "hello")
  end

  test "{value} passes boolean as string" do
    assert "true" = DisplayFormatter.format("{value}", true)
  end

  test "{value:.0f} formats float with 0 decimal places" do
    assert "43" = DisplayFormatter.format("{value:.0f}", 42.5)
  end

  test "{value:.2f} formats float with 2 decimal places" do
    assert "42.50" = DisplayFormatter.format("{value:.2f}", 42.5)
  end

  test "{value:.1f} with integer value" do
    assert "42.0" = DisplayFormatter.format("{value:.1f}", 42)
  end

  test "surrounding text is preserved" do
    assert "V:42.5" = DisplayFormatter.format("V:{value:.1f}", 42.5)
  end

  test "{value} with prefix and suffix" do
    assert "~42~" = DisplayFormatter.format("~{value}~", 42)
  end

  test "format string with no tokens returns literal" do
    assert "HELLO" = DisplayFormatter.format("HELLO", 42)
  end

  test "validates supported tokens and precision boundaries" do
    for format <- ["literal", "{value}", "{value:.0f}", "{value:.10f}"] do
      assert :ok = DisplayFormatter.validate_format(format)
    end

    for format <- [
          "{value:.11f}",
          "{value:.999999999999999999999999f}",
          "{value:.2g}",
          "{value:bad}",
          "{value",
          "{value:.2f"
        ] do
      assert {:error, message} = DisplayFormatter.validate_format(format)
      assert is_binary(message)
    end
  end

  test "legacy invalid precision remains safe to render" do
    assert DisplayFormatter.format("{value:.999999999999999999999999f}", 42.5) == "42.5"
    assert DisplayFormatter.format("{value:.11f}", 42.5) == "42.5"
  end

  test "binding changesets reject unsupported value formats" do
    for format <- ["{value:.11f}", "{value:.2g}"] do
      changeset =
        DisplayBinding.changeset(%DisplayBinding{}, %{
          train_id: 1,
          i2c_module_id: 1,
          endpoint: "Speed",
          format_string: format
        })

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :format_string)
    end
  end
end
