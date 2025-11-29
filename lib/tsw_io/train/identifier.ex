defmodule TswIo.Train.Identifier do
  @moduledoc """
  Generates train identifiers from formation ObjectClass values.

  The identifier is the common prefix among all ObjectClass values
  in the current formation, providing a stable way to identify
  specific train types across sessions.
  """

  alias TswIo.Simulator.Client

  @type formation_info :: %{
          length: non_neg_integer(),
          object_classes: [String.t()],
          identifier: String.t()
        }

  @doc """
  Derives train identifier from the current formation in the simulator.

  Returns the common prefix of all ObjectClass values.
  """
  @spec derive_from_formation(Client.t()) :: {:ok, formation_info()} | {:error, term()}
  def derive_from_formation(%Client{} = client) do
    with {:ok, length} <- get_formation_length(client),
         {:ok, object_classes} <- get_object_classes(client, length) do
      identifier = common_prefix(object_classes)
      {:ok, %{length: length, object_classes: object_classes, identifier: identifier}}
    end
  end

  @doc """
  Finds the common prefix among a list of strings.
  """
  @spec common_prefix([String.t()]) :: String.t()
  def common_prefix([]), do: ""
  def common_prefix([single]), do: single

  def common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn string, acc ->
      find_common_prefix(acc, string)
    end)
  end

  # Private functions

  defp get_formation_length(%Client{} = client) do
    case Client.get(client, "CurrentFormation.FormationLength") do
      {:ok, %{"Values" => values}} ->
        case Map.values(values) do
          [length | _] when is_integer(length) -> {:ok, length}
          _ -> {:error, :invalid_formation_length}
        end

      {:ok, _response} ->
        {:error, :invalid_formation_length}

      error ->
        error
    end
  end

  defp get_object_classes(%Client{} = client, length) when length > 0 do
    results =
      0..(length - 1)
      |> Enum.map(fn index ->
        case Client.get(client, "CurrentFormation/#{index}.ObjectClass") do
          {:ok, %{"Values" => values}} ->
            case Map.values(values) do
              [class | _] when is_binary(class) -> {:ok, class}
              _ -> {:error, {:invalid_object_class, index}}
            end

          error ->
            error
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      classes = Enum.map(results, fn {:ok, class} -> class end)
      {:ok, classes}
    else
      {:error, {:failed_to_get_classes, errors}}
    end
  end

  defp get_object_classes(_client, 0), do: {:ok, []}

  defp find_common_prefix(s1, s2) do
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)

    s1_chars
    |> Enum.zip(s2_chars)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(fn {a, _} -> a end)
    |> Enum.join()
  end
end
