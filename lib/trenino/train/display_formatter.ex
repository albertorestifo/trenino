defmodule Trenino.Train.DisplayFormatter do
  @moduledoc """
  Evaluates display format strings against a runtime value.

  Supported tokens:
  - `{value}` — replaced with `to_string(value)`
  - `{value:.Nf}` — replaced with float formatted to N decimal places
  """

  @doc "Validates value tokens; decimal precision must be between 0 and 10."
  @spec validate_format(String.t()) :: :ok | {:error, String.t()}
  def validate_format(format_string) when is_binary(format_string) do
    remaining = Regex.replace(~r/\{value(?::\.(?:[0-9]|10)f)?\}/, format_string, "")

    if String.contains?(remaining, "{value") do
      {:error, "Use {value} or {value:.Nf}, with precision from 0 to 10"}
    else
      :ok
    end
  end

  @spec format(String.t(), term()) :: String.t()
  def format(format_string, value) when is_binary(format_string) do
    Regex.replace(~r/\{value(?::\.(\d+)f)?\}/, format_string, fn
      _, "" ->
        to_string(value)

      _, decimals ->
        if decimals in Enum.map(0..10, &Integer.to_string/1) do
          format_float(value, String.to_integer(decimals))
        else
          to_string(value)
        end
    end)
  end

  defp format_float(value, decimals) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [{:decimals, decimals}])
  end

  defp format_float(value, _decimals), do: to_string(value)
end
