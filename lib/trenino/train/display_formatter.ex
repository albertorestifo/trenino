defmodule Trenino.Train.DisplayFormatter do
  @moduledoc """
  Evaluates display format strings against a runtime value.

  Supported tokens:
  - `{value}` — replaced with `to_string(value)`
  - `{value:.Nf}` — replaced with float formatted to N decimal places
  """

  @spec format(String.t(), term()) :: String.t()
  def format(format_string, value) when is_binary(format_string) do
    Regex.replace(~r/\{value(?::\.(\d+)f)?\}/, format_string, fn
      _, "" -> to_string(value)
      _, decimals -> format_float(value, String.to_integer(decimals))
    end)
  end

  defp format_float(value, decimals) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [{:decimals, decimals}])
  end

  defp format_float(value, _decimals), do: to_string(value)
end
