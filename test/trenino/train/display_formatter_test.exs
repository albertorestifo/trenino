defmodule Trenino.Train.DisplayFormatterTest do
  use ExUnit.Case, async: true
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
end
