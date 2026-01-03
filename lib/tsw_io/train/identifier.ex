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

  Uses the ObjectClass of the drivable actor (the vehicle the player is driving).
  This is more reliable than common prefix for freight trains where locomotives
  and wagons have different class prefixes.

  Falls back to common prefix for formations without a clear drivable index.
  """
  @spec derive_from_formation(Client.t()) :: {:ok, String.t()} | {:error, term()}
  def derive_from_formation(%Client{} = client) do
    with {:ok, drivable_class} <- get_drivable_object_class(client) do
      {:ok, normalize_object_class(drivable_class)}
    end
  end

  # Get the ObjectClass of the currently driven vehicle
  defp get_drivable_object_class(%Client{} = client) do
    with {:ok, drivable_index} <- Client.get_int(client, "CurrentFormation.DrivableIndex"),
         {:ok, object_class} <-
           Client.get_string(client, "CurrentFormation/#{drivable_index}.ObjectClass") do
      {:ok, object_class}
    else
      # Fallback to index 0 if DrivableIndex is not available
      {:error, _} ->
        Client.get_string(client, "CurrentFormation/0.ObjectClass")
    end
  end

  # Normalize the object class by removing the trailing _C suffix
  defp normalize_object_class(object_class) do
    object_class
    |> String.replace_suffix("_C", "")
    |> strip_trailing_non_alphanumeric()
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
