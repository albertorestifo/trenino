defmodule Trenino.Simulator.ControlDetector do
  @moduledoc """
  Detects and suggests train controls from the TSW API.

  Analyzes the CurrentDrivableActor to find lever and button controls and
  matches them to element names.

  ## Control Detection

  - **Levers**: Controls with `Function.GetNotchCount` endpoint, read through
    `Trenino.Simulator.LeverMetadata`. They are matched by their in-game role
    (`Property.InputIdentifier`, e.g. "Throttle" or "AutomaticBrake") first,
    and by node name second.
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
  alias Trenino.Simulator.LeverMetadata

  @type lever_suggestion :: %{lever: LeverMetadata.t(), score: float()}

  @type button_suggestion :: %{
          control_name: String.t(),
          endpoint: String.t(),
          confidence: float()
        }

  # Words in an element name that point at a lever role, with their weight.
  # "brake" alone means the train brake; other brakes need their own word.
  @role_keywords %{
    "Throttle" => %{
      "throttle" => 1.0,
      "power" => 1.0,
      "master" => 0.8,
      "controller" => 0.8,
      "traction" => 0.8,
      "combined" => 0.8,
      "notch" => 0.6,
      "brake" => 0.3
    },
    "AutomaticBrake" => %{"brake" => 0.9, "train" => 1.0, "automatic" => 1.0, "air" => 0.8},
    "TrainBrake" => %{"brake" => 0.9, "train" => 1.0},
    "IndependentBrake" => %{
      "independent" => 1.0,
      "loco" => 1.0,
      "locomotive" => 1.0,
      "direct" => 1.0,
      "engine" => 0.8,
      "brake" => 0.5
    },
    "DynamicBrake" => %{"dynamic" => 1.0, "regen" => 1.0, "regenerative" => 1.0, "brake" => 0.4},
    "Reverser" => %{"reverser" => 1.0, "direction" => 1.0, "reverse" => 0.8, "forward" => 0.6}
  }

  @min_lever_score 0.3

  @doc """
  Suggests simulator levers for an element, best match first.

  Each lever is scored by how well the element name matches its in-game role
  ("Power Handle" → "Throttle", "Train Brake" → "AutomaticBrake") or its node
  name. Levers below #{@min_lever_score} are left out. Front-cab controls rank
  above rear-cab ones.

  ## Examples

      iex> ControlDetector.suggest_levers(client, "Throttle")
      {:ok, [%{lever: %LeverMetadata{control_path: "CurrentDrivableActor/Throttle_F"}, score: 1.0}]}

  """
  @spec suggest_levers(Client.t(), String.t(), pos_integer()) ::
          {:ok, [lever_suggestion()]} | {:error, term()}
  def suggest_levers(%Client{} = client, element_name, limit \\ 3) when is_binary(element_name) do
    with {:ok, levers} <- LeverMetadata.list_levers(client) do
      {:ok, rank_levers(levers, element_name, limit)}
    end
  end

  @doc """
  Ranks already-read levers for an element name. See `suggest_levers/3`.
  """
  @spec rank_levers([LeverMetadata.t()], String.t(), pos_integer()) :: [lever_suggestion()]
  def rank_levers(levers, element_name, limit \\ 3) do
    words = element_name |> String.downcase() |> split_into_words()
    name = String.downcase(element_name)

    levers
    |> Enum.with_index()
    |> Enum.map(fn {lever, order} ->
      score = max(role_score(lever.role, name, words), 0.9 * name_score(name, lever.node_name))
      {%{lever: lever, score: Float.round(score, 2)}, order}
    end)
    |> Enum.filter(fn {%{score: score}, _} -> score >= @min_lever_score end)
    |> Enum.sort_by(fn {%{score: score}, order} -> {-score, order} end)
    |> Enum.take(limit)
    |> Enum.map(&elem(&1, 0))
  end

  defp role_score(nil, _name, _words), do: 0.0

  defp role_score(role, name, words) do
    weights = Map.get(@role_keywords, role, %{String.downcase(role) => 1.0})

    cond do
      String.downcase(role) == name -> 1.0
      names_other_role?(role, weights, words) -> 0.0
      true -> keyword_score(weights, words)
    end
  end

  # "Independent brake" names the IndependentBrake role, so it must not match
  # the train brake just because both contain "brake"
  defp names_other_role?(role, weights, words) do
    Enum.any?(words, fn word ->
      Map.get(weights, word, 0.0) < 1.0 and
        Enum.any?(@role_keywords, fn {other, other_weights} ->
          other != role and Map.get(other_weights, word) == 1.0
        end)
    end)
  end

  defp keyword_score(weights, words) do
    case words |> Enum.map(&Map.get(weights, &1, 0.0)) |> Enum.sort(:desc) do
      [best, next | _] when next > 0 -> min(best + 0.1, 1.0)
      [best | _] -> best
      [] -> 0.0
    end
  end

  # Only strong name matches count; fuzzy similarity alone is noise for levers
  @min_name_score 0.7

  defp name_score(_name, nil), do: 0.0

  defp name_score(name, node_name) do
    squashed_name = squash(name)

    score =
      if squashed_name != "" and String.contains?(squash(node_name), squashed_name),
        do: 0.85,
        else: calculate_confidence(name, node_name)

    if score >= @min_name_score, do: score, else: 0.0
  end

  defp squash(text), do: text |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")

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
