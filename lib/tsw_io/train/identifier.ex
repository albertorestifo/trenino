defmodule TswIo.Train.Identifier do
  @moduledoc """
  Generates train identifiers from formation ObjectClass values.

  The identifier is the common prefix among all ObjectClass values
  in the current formation, providing a stable way to identify
  specific train types across sessions.
  """

  alias TswIo.Simulator.Client

  @doc """
  Derives train identifier from the current formation in the simulator.

  Returns the common prefix of all ObjectClass values as a string.
  Fetches object classes in parallel using async tasks.
  """
  @spec derive_from_formation(Client.t()) :: {:ok, String.t()} | {:error, term()}
  def derive_from_formation(%Client{} = client) do
    with {:ok, length} <- Client.get_int(client, "CurrentFormation.FormationLength"),
         {:ok, object_classes} <- get_object_classes(client, length) do
      {:ok, common_prefix(object_classes)}
    end
  end

  @doc """
  Finds the common prefix among a list of strings.
  """
  @spec common_prefix([String.t()]) :: String.t()
  def common_prefix([]), do: ""
  def common_prefix([single]), do: single

  def common_prefix([first | rest]) do
    prefix =
      Enum.reduce(rest, first, fn string, acc ->
        find_common_prefix(acc, string)
      end)

    strip_trailing_non_alphanumeric(prefix)
  end

  @doc """
  Extracts a human-readable train name from a TSW6 train identifier.

  The identifier follows the pattern: `RVM_<ROUTE>_<CLASS>_<VARIANT>_C`
  The function attempts to extract meaningful train names from common patterns.

  ## Examples

      iex> extract_train_name("RVM_PBO_Class142_DMSL_New_GMPTE_C")
      "Class 142"

      iex> extract_train_name("RVM_FSN_DB_BR430_ETW4_C")
      "DB BR 430"

      iex> extract_train_name("RVM_LIRREX_M9-B_C")
      "M9"

      iex> extract_train_name("RVM_CJP_BNSF_ES44C4_C")
      "BNSF ES44C4"

      iex> extract_train_name("unknown_format")
      ""
  """
  @spec extract_train_name(String.t()) :: String.t()
  def extract_train_name(identifier) when is_binary(identifier) do
    # Strip optional _C suffix and split by underscores
    parts =
      identifier
      |> String.replace_suffix("_C", "")
      |> String.split("_")

    extract_name_from_parts(parts)
  end

  # Private functions

  # Handle RVM prefix pattern: RVM_<ROUTE>_...
  defp extract_name_from_parts(["RVM" | rest]) do
    extract_name_from_parts(rest)
  end

  # Skip route code (usually 3-6 char abbreviation) and process remaining parts
  defp extract_name_from_parts([_route | rest]) when length(rest) > 0 do
    candidate = find_train_name_pattern(rest)

    if candidate != "", do: candidate, else: fallback_name(rest)
  end

  defp extract_name_from_parts(_), do: ""

  # Pattern matching for common train name formats
  defp find_train_name_pattern(parts) do
    # First check for multi-part patterns (DB + BR, company + model)
    case find_db_br_pattern(parts) do
      "" ->
        case find_company_model_pattern(parts) do
          "" -> find_single_part_pattern(parts)
          name -> name
        end

      name ->
        name
    end
  end

  # Match single-part patterns like "Class142" or "M9"
  defp find_single_part_pattern(parts) do
    Enum.find_value(parts, "", fn part ->
      cond do
        # Match "Class" followed by number (e.g., "Class142")
        String.match?(part, ~r/^Class\d+$/i) ->
          String.replace(part, ~r/^(Class)(\d+)$/i, "\\1 \\2")

        # Match standalone model numbers (M9, M7, etc.) - single letter followed by 1-2 digits
        String.match?(part, ~r/^[A-Z]\d{1,2}(-[A-Z])?$/i) ->
          String.replace(part, ~r/^([A-Z]\d+)(-[A-Z])?$/i, "\\1")

        true ->
          nil
      end
    end)
  end

  defp find_db_br_pattern(parts) do
    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value("", fn
      ["DB", br] ->
        if String.match?(br, ~r/^BR\d+$/i) do
          number = String.replace(br, ~r/^BR(\d+)$/i, "\\1")
          "DB BR #{number}"
        else
          nil
        end

      _ ->
        nil
    end)
  end

  defp find_company_model_pattern(parts) do
    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value("", fn
      [company, model] ->
        if is_company_name?(company) and String.match?(model, ~r/^[A-Z0-9]+/i) do
          "#{company} #{model}"
        else
          nil
        end

      _ ->
        nil
    end)
  end

  defp is_company_name?(part) do
    # Common railway company abbreviations
    part in ["BNSF", "UP", "NS", "CSX", "DB", "SNCF", "LIRR", "MBTA", "NJT", "AMTK"]
  end

  defp fallback_name(parts) do
    # As a last resort, try to find the most "train-like" part
    # (contains letters and numbers, not too long)
    parts
    |> Enum.find("", fn part ->
      String.match?(part, ~r/^[A-Z0-9]{2,10}$/i) and
        String.match?(part, ~r/\d/) and
        String.match?(part, ~r/[A-Z]/i)
    end)
  end

  defp get_object_classes(_client, 0), do: {:error, :empty_formation}
  defp get_object_classes(_client, 1), do: {:error, :single_car_formation}

  defp get_object_classes(%Client{} = client, length) when length > 1 do
    # Fetch all object classes in parallel using async tasks
    tasks =
      0..(length - 1)
      |> Enum.map(fn index ->
        Task.async(fn ->
          Client.get_string(client, "CurrentFormation/#{index}.ObjectClass")
        end)
      end)

    # Collect results, filtering out errors
    results =
      tasks
      |> Task.await_many(:timer.seconds(5))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, class} -> class end)

    # We need at least 2 results to compute a meaningful common prefix
    if length(results) >= 2 do
      {:ok, results}
    else
      {:error, :insufficient_formation_data}
    end
  end

  defp find_common_prefix(s1, s2) do
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)

    s1_chars
    |> Enum.zip(s2_chars)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(fn {a, _} -> a end)
    |> Enum.join()
  end

  defp strip_trailing_non_alphanumeric(string) do
    String.replace(string, ~r/[^a-zA-Z0-9]+$/, "")
  end
end
