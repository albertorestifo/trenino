defmodule Trenino.Simulator.ControlDetector do
  @moduledoc """
  Detects and suggests train controls from the TSW API.

  Analyzes the CurrentDrivableActor to find lever and button controls,
  classifies them based on their available endpoints, and matches them
  to element names using fuzzy string matching.

  ## Control Detection

  - **Levers**: Controls with `Function.GetNotchCount` endpoint
  - **Buttons**: Controls with `Property.bDefaultToPressed` endpoint

  ## Endpoint Patterns

  **Lever endpoints:**
  - `InputValue` (writable) - Set value
  - `Function.GetMinimumInputValue` - Get min
  - `Function.GetMaximumInputValue` - Get max
  - `Function.GetNotchCount` - Get notch count
  - `Function.GetCurrentNotchIndex` - Get current notch

  **Button endpoint:**
  - `InputValue` (writable) - Set value
  """

  require Logger

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection

  @type lever_suggestion :: %{
          control_name: String.t(),
          min_endpoint: String.t(),
          max_endpoint: String.t(),
          value_endpoint: String.t(),
          notch_count_endpoint: String.t() | nil,
          notch_index_endpoint: String.t() | nil,
          confidence: float()
        }

  @type button_suggestion :: %{
          control_name: String.t(),
          endpoint: String.t(),
          confidence: float()
        }

  @doc """
  Suggests a lever control matching the given element name.

  Returns the best matching lever control from CurrentDrivableActor if found.

  ## Examples

      iex> ControlDetector.suggest_lever("Throttle")
      {:ok, %{
        control_name: "Throttle(Lever)",
        min_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMinimumInputValue",
        max_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMaximumInputValue",
        value_endpoint: "CurrentDrivableActor/Throttle(Lever).InputValue",
        notch_count_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetNotchCount",
        notch_index_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex",
        confidence: 0.95
      }}

      iex> ControlDetector.suggest_lever("Unknown")
      {:error, :no_match}

  """
  @spec suggest_lever(String.t()) :: {:ok, lever_suggestion()} | {:error, term()}
  def suggest_lever(element_name) when is_binary(element_name) do
    with {:ok, client} <- get_client(),
         {:ok, controls} <- list_controls(client),
         {:ok, levers} <- detect_levers(client, controls) do
      case find_best_match(element_name, levers) do
        {lever, confidence} when confidence > 0.3 ->
          {:ok,
           %{
             control_name: lever.name,
             min_endpoint: lever.min_endpoint,
             max_endpoint: lever.max_endpoint,
             value_endpoint: lever.value_endpoint,
             notch_count_endpoint: lever.notch_count_endpoint,
             notch_index_endpoint: lever.notch_index_endpoint,
             confidence: confidence
           }}

        _ ->
          {:error, :no_match}
      end
    end
  end

  @doc """
  Suggests a button control matching the given element name.

  Returns the best matching button control from CurrentDrivableActor if found.

  ## Examples

      iex> ControlDetector.suggest_button("Horn")
      {:ok, %{
        control_name: "Horn",
        endpoint: "CurrentDrivableActor/Horn.InputValue",
        confidence: 1.0
      }}

      iex> ControlDetector.suggest_button("Unknown")
      {:error, :no_match}

  """
  @spec suggest_button(String.t()) :: {:ok, button_suggestion()} | {:error, term()}
  def suggest_button(element_name) when is_binary(element_name) do
    with {:ok, client} <- get_client(),
         {:ok, controls} <- list_controls(client),
         {:ok, buttons} <- detect_buttons(client, controls) do
      case find_best_match(element_name, buttons) do
        {button, confidence} when confidence > 0.3 ->
          {:ok,
           %{
             control_name: button.name,
             endpoint: button.endpoint,
             confidence: confidence
           }}

        _ ->
          {:error, :no_match}
      end
    end
  end

  # Gets the simulator client from the connection
  defp get_client do
    case Connection.get_status() do
      %{status: :connected, client: client} when not is_nil(client) ->
        {:ok, client}

      _ ->
        {:error, :not_connected}
    end
  end

  # Lists all controls under CurrentDrivableActor
  defp list_controls(%Client{} = client) do
    case Client.list(client, "CurrentDrivableActor") do
      {:ok, %{"Nodes" => nodes}} when is_list(nodes) ->
        {:ok, nodes}

      {:ok, _} ->
        {:ok, []}

      error ->
        Logger.warning("[ControlDetector] Failed to list controls: #{inspect(error)}")
        error
    end
  end

  # Detects lever controls by checking for notch count endpoint
  defp detect_levers(%Client{} = client, controls) do
    levers =
      controls
      |> Enum.filter(&is_binary/1)
      |> Enum.map(fn control -> detect_lever(client, control) end)
      |> Enum.filter(&(&1 != nil))

    {:ok, levers}
  end

  # Checks if a control is a lever and extracts its endpoints
  defp detect_lever(%Client{} = client, control_name) do
    path = "CurrentDrivableActor/#{control_name}"

    with {:ok, %{"Nodes" => endpoints}} when is_list(endpoints) <- Client.list(client, path),
         true <- has_notch_count?(endpoints) do
      %{
        name: control_name,
        min_endpoint: "#{path}.Function.GetMinimumInputValue",
        max_endpoint: "#{path}.Function.GetMaximumInputValue",
        value_endpoint: "#{path}.InputValue",
        notch_count_endpoint: "#{path}.Function.GetNotchCount",
        notch_index_endpoint: "#{path}.Function.GetCurrentNotchIndex"
      }
    else
      _ -> nil
    end
  end

  # Checks if the control has a notch count endpoint (lever indicator)
  defp has_notch_count?(endpoints) do
    Enum.any?(endpoints, fn endpoint ->
      is_binary(endpoint) and String.contains?(endpoint, "Function.GetNotchCount")
    end)
  end

  # Detects button controls by checking for bDefaultToPressed property
  defp detect_buttons(%Client{} = client, controls) do
    buttons =
      controls
      |> Enum.filter(&is_binary/1)
      |> Enum.map(fn control -> detect_button(client, control) end)
      |> Enum.filter(&(&1 != nil))

    {:ok, buttons}
  end

  # Checks if a control is a button and extracts its endpoint
  defp detect_button(%Client{} = client, control_name) do
    path = "CurrentDrivableActor/#{control_name}"

    with {:ok, %{"Nodes" => endpoints}} when is_list(endpoints) <- Client.list(client, path),
         true <- has_default_pressed?(endpoints) do
      %{
        name: control_name,
        endpoint: "#{path}.InputValue"
      }
    else
      _ -> nil
    end
  end

  # Checks if the control has bDefaultToPressed property (button indicator)
  defp has_default_pressed?(endpoints) do
    Enum.any?(endpoints, fn endpoint ->
      is_binary(endpoint) and String.contains?(endpoint, "Property.bDefaultToPressed")
    end)
  end

  # Finds the best matching control for the element name using fuzzy matching
  defp find_best_match(element_name, controls) do
    element_lower = String.downcase(element_name)

    controls
    |> Enum.map(fn control ->
      confidence = calculate_confidence(element_lower, control.name)
      {control, confidence}
    end)
    |> Enum.max_by(fn {_control, confidence} -> confidence end, fn -> {nil, 0.0} end)
  end

  # Calculates confidence score between element name and control name
  # Uses multiple heuristics:
  # - Exact match (case-insensitive): 1.0
  # - Element name contained in control name: 0.8
  # - Control name contained in element name: 0.7
  # - Common word match: 0.5 per word
  # - Jaro distance similarity: 0.0-1.0
  defp calculate_confidence(element_name, control_name) do
    control_lower = String.downcase(control_name)

    cond do
      # Exact match
      element_name == control_lower ->
        1.0

      # Element name fully contained in control (e.g., "throttle" in "Throttle(Lever)")
      String.contains?(control_lower, element_name) ->
        0.85

      # Control name fully contained in element (rare but possible)
      String.contains?(element_name, control_lower) ->
        0.75

      # Check for common words
      true ->
        element_words = split_into_words(element_name)
        control_words = split_into_words(control_lower)

        word_matches = count_word_matches(element_words, control_words)

        if word_matches > 0 do
          # Give credit for each matching word
          base_score = min(0.5 + word_matches * 0.2, 0.9)
          # Blend with Jaro distance
          jaro_score = String.jaro_distance(element_name, control_lower)
          (base_score + jaro_score) / 2
        else
          # Fall back to pure Jaro distance
          String.jaro_distance(element_name, control_lower)
        end
    end
  end

  # Splits a string into words, handling common separators and camelCase
  defp split_into_words(str) do
    str
    # Split on common separators
    |> String.split(~r/[\s_\-\(\)]+/, trim: true)
    # Split camelCase
    |> Enum.flat_map(fn word ->
      # Insert space before capitals in camelCase
      word
      |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
      |> String.split(" ", trim: true)
      |> Enum.map(&String.downcase/1)
    end)
    |> Enum.reject(&(&1 == ""))
  end

  # Counts how many words from list1 appear in list2
  defp count_word_matches(words1, words2) do
    Enum.count(words1, fn word -> word in words2 end)
  end
end
