defmodule Trenino.Train do
  @moduledoc """
  Context for train configurations and management.

  Provides functions for managing train configurations, elements,
  and their calibrations for integration with Train Sim World.
  """

  import Ecto.Query

  alias Trenino.Repo

  alias Trenino.Train.{
    Train,
    Element,
    LeverConfig,
    LeverInputBinding,
    ButtonInputBinding,
    Notch,
    Identifier
  }

  alias Trenino.Train.Calibration.{SessionSupervisor, LeverSession}
  alias Trenino.Simulator.Client

  # Detection delegation
  defdelegate subscribe(), to: Trenino.Train.Detection
  defdelegate get_active_train(), to: Trenino.Train.Detection
  defdelegate get_current_identifier(), to: Trenino.Train.Detection
  defdelegate sync(), to: Trenino.Train.Detection

  # ===================
  # Train Operations
  # ===================

  @doc """
  List all trains.

  Returns trains ordered by name.

  ## Options

    * `:preload` - List of associations to preload (default: [])

  """
  @spec list_trains(keyword()) :: [Train.t()]
  def list_trains(opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    Train
    |> order_by([t], t.name)
    |> Repo.all()
    |> Repo.preload(preloads)
  end

  @doc """
  Get a train by ID.

  ## Options

    * `:preload` - List of associations to preload (default: [])

  """
  @spec get_train(integer(), keyword()) :: {:ok, Train.t()} | {:error, :not_found}
  def get_train(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    case Repo.get(Train, id) do
      nil -> {:error, :not_found}
      train -> {:ok, Repo.preload(train, preloads)}
    end
  end

  @doc """
  Find a train whose identifier is a prefix of the detected identifier.

  The stored identifier acts as a prefix matcher - any detected ObjectClass
  that starts with the stored identifier will match that train.

  ## Returns

    * `{:ok, train}` - Exactly one train matches
    * `{:error, :not_found}` - No trains match
    * `{:error, {:multiple_matches, trains}}` - Multiple trains match (ambiguous)

  ## Examples

      # Stored: "RVM_LIRREX_M9"
      # Detected: "RVM_LIRREX_M9-A" -> matches
      # Detected: "RVM_LIRREX_M9-B" -> matches
      # Detected: "RVM_LIRREX_M7" -> no match
  """
  @spec get_train_by_identifier(String.t()) ::
          {:ok, Train.t()} | {:error, :not_found} | {:error, {:multiple_matches, [Train.t()]}}
  def get_train_by_identifier(detected_identifier) do
    # Find all trains whose identifier is a prefix of the detected identifier
    matching_trains =
      Train
      |> Repo.all()
      |> Enum.filter(fn train ->
        String.starts_with?(detected_identifier, train.identifier)
      end)
      |> Enum.map(fn train -> Repo.preload(train, elements: :lever_config) end)

    case matching_trains do
      [] -> {:error, :not_found}
      [train] -> {:ok, train}
      trains -> {:error, {:multiple_matches, trains}}
    end
  end

  @doc """
  Create a new train.
  """
  @spec create_train(map()) :: {:ok, Train.t()} | {:error, Ecto.Changeset.t()}
  def create_train(attrs \\ %{}) do
    %Train{}
    |> Train.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a train.
  """
  @spec update_train(Train.t(), map()) :: {:ok, Train.t()} | {:error, Ecto.Changeset.t()}
  def update_train(%Train{} = train, attrs) do
    train
    |> Train.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a train.

  This will cascade delete all associated elements, lever configs, and notches.
  """
  @spec delete_train(Train.t()) :: {:ok, Train.t()} | {:error, Ecto.Changeset.t()}
  def delete_train(%Train{} = train) do
    Repo.delete(train)
  end

  # ===================
  # Element Operations
  # ===================

  @doc """
  List all elements for a train.
  """
  @spec list_elements(integer()) :: {:ok, [Element.t()]}
  def list_elements(train_id) do
    elements =
      Element
      |> where([e], e.train_id == ^train_id)
      |> order_by([e], e.name)
      |> preload(
        lever_config: [:notches, input_binding: [input: :device]],
        button_binding: [input: :device]
      )
      |> Repo.all()

    {:ok, elements}
  end

  @doc """
  Get an element by ID.

  ## Options

    * `:preload` - List of associations to preload (default: [])
  """
  @spec get_element(integer(), keyword()) :: {:ok, Element.t()} | {:error, :not_found}
  def get_element(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    case Repo.get(Element, id) do
      nil -> {:error, :not_found}
      element -> {:ok, Repo.preload(element, preloads)}
    end
  end

  @doc """
  Create an element for a train.
  """
  @spec create_element(integer(), map()) :: {:ok, Element.t()} | {:error, Ecto.Changeset.t()}
  def create_element(train_id, attrs) do
    %Element{train_id: train_id}
    |> Element.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Delete an element.
  """
  @spec delete_element(Element.t()) :: {:ok, Element.t()} | {:error, Ecto.Changeset.t()}
  def delete_element(%Element{} = element) do
    Repo.delete(element)
  end

  # ===================
  # Lever Config Operations
  # ===================

  @doc """
  Get a lever config by element ID.
  """
  @spec get_lever_config(integer()) :: {:ok, LeverConfig.t()} | {:error, :not_found}
  def get_lever_config(element_id) do
    case Repo.get_by(LeverConfig, element_id: element_id) do
      nil -> {:error, :not_found}
      config -> {:ok, Repo.preload(config, :notches)}
    end
  end

  @doc """
  Create a lever config for an element.
  """
  @spec create_lever_config(integer(), map()) ::
          {:ok, LeverConfig.t()} | {:error, Ecto.Changeset.t()}
  def create_lever_config(element_id, attrs) do
    %LeverConfig{element_id: element_id}
    |> LeverConfig.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Create a lever config with analysis results from LeverAnalyzer.

  This creates the lever config and automatically populates notches based on
  the analyzer's suggested_notches, which are derived from empirical testing
  of the lever's actual behavior.

  ## Parameters

    * `element_id` - The element ID to create the config for
    * `attrs` - Map with endpoint paths (min_endpoint, max_endpoint, value_endpoint)
    * `analysis_result` - The result from `LeverAnalyzer.analyze/2`

  ## Example

      {:ok, result} = LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController")
      {:ok, config} = Train.create_lever_config_with_analysis(element_id, endpoints, result)
  """
  @spec create_lever_config_with_analysis(integer(), map(), map()) ::
          {:ok, LeverConfig.t()} | {:error, term()}
  def create_lever_config_with_analysis(element_id, attrs, %{
        lever_type: lever_type,
        suggested_notches: suggested_notches
      }) do
    Repo.transaction(fn ->
      # Create the lever config with lever_type
      config_attrs = Map.put(attrs, :lever_type, lever_type)

      case create_lever_config(element_id, config_attrs) do
        {:ok, lever_config} ->
          # Create notches from analysis results
          case create_notches_from_suggestions(lever_config.id, suggested_notches) do
            :ok ->
              Repo.preload(lever_config, :notches)

            {:error, reason} ->
              Repo.rollback(reason)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Update a lever config with new analysis results.

  Replaces existing notches with those from the new analysis.
  """
  @spec update_lever_config_with_analysis(LeverConfig.t(), map(), map()) ::
          {:ok, LeverConfig.t()} | {:error, term()}
  def update_lever_config_with_analysis(%LeverConfig{} = config, attrs, %{
        lever_type: lever_type,
        suggested_notches: suggested_notches
      }) do
    Repo.transaction(fn ->
      # Update the lever config with lever_type
      config_attrs = Map.put(attrs, :lever_type, lever_type)

      case update_lever_config(config, config_attrs) do
        {:ok, updated_config} ->
          # Delete existing notches
          Notch
          |> where([n], n.lever_config_id == ^updated_config.id)
          |> Repo.delete_all()

          # Create notches from analysis results
          case create_notches_from_suggestions(updated_config.id, suggested_notches) do
            :ok ->
              Repo.preload(updated_config, :notches)

            {:error, reason} ->
              Repo.rollback(reason)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_notches_from_suggestions(lever_config_id, suggested_notches) do
    results =
      Enum.map(suggested_notches, fn notch ->
        # The analyzer's input_min/input_max represent the simulator's InputValue range
        # for this notch. We save these to sim_input_min/sim_input_max.
        # The Notch schema's input_min/input_max are for hardware input mapping,
        # which is set separately via NotchMappingSession.
        attrs = %{
          index: notch[:index] || 0,
          type: notch[:type],
          value: notch[:value],
          min_value: notch[:min_value],
          max_value: notch[:max_value],
          # Simulator input ranges from analyzer
          sim_input_min: notch[:input_min],
          sim_input_max: notch[:input_max],
          description: notch[:description]
        }

        %Notch{lever_config_id: lever_config_id}
        |> Notch.changeset(attrs)
        |> Repo.insert()
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      :ok
    else
      {:error, {:notch_errors, errors}}
    end
  end

  @doc """
  Update a lever config.
  """
  @spec update_lever_config(LeverConfig.t(), map()) ::
          {:ok, LeverConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_lever_config(%LeverConfig{} = config, attrs) do
    config
    |> LeverConfig.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Save calibration data for a lever config.

  This deletes existing notches and creates new ones from the provided list.
  Sets the calibrated_at timestamp.
  """
  @spec save_calibration(LeverConfig.t(), [map()]) ::
          {:ok, LeverConfig.t()} | {:error, term()}
  def save_calibration(%LeverConfig{} = lever_config, notches) when is_list(notches) do
    Repo.transaction(fn ->
      # Delete existing notches
      Notch
      |> where([n], n.lever_config_id == ^lever_config.id)
      |> Repo.delete_all()

      # Create new notches
      notch_results =
        notches
        |> Enum.with_index()
        |> Enum.map(fn {notch_attrs, index} ->
          # Ensure all keys are strings to avoid mixed key types
          attrs_with_index =
            notch_attrs
            |> Map.new(fn {k, v} -> {to_string(k), v} end)
            |> Map.put("index", index)

          %Notch{lever_config_id: lever_config.id}
          |> Notch.changeset(attrs_with_index)
          |> Repo.insert()
        end)

      # Check for errors
      errors = Enum.filter(notch_results, &match?({:error, _}, &1))

      if errors != [] do
        Repo.rollback({:notch_errors, errors})
      else
        # Update calibrated_at timestamp
        case update_lever_config(lever_config, %{calibrated_at: DateTime.utc_now()}) do
          {:ok, updated_config} ->
            Repo.preload(updated_config, :notches)

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end
    end)
  end

  # ===================
  # Notch Operations
  # ===================

  @doc """
  Create a notch for a lever config.
  """
  @spec create_notch(integer(), map()) :: {:ok, Notch.t()} | {:error, Ecto.Changeset.t()}
  def create_notch(lever_config_id, attrs) do
    %Notch{lever_config_id: lever_config_id}
    |> Notch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a notch.
  """
  @spec update_notch(Notch.t(), map()) :: {:ok, Notch.t()} | {:error, Ecto.Changeset.t()}
  def update_notch(%Notch{} = notch, attrs) do
    notch
    |> Notch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Update a notch description.
  """
  @spec update_notch_description(Notch.t(), String.t() | nil) ::
          {:ok, Notch.t()} | {:error, Ecto.Changeset.t()}
  def update_notch_description(%Notch{} = notch, description) do
    notch
    |> Notch.changeset(%{description: description})
    |> Repo.update()
  end

  @doc """
  Delete a notch.
  """
  @spec delete_notch(Notch.t()) :: {:ok, Notch.t()} | {:error, Ecto.Changeset.t()}
  def delete_notch(%Notch{} = notch) do
    Repo.delete(notch)
  end

  @doc """
  Save notches for a lever config, replacing any existing notches.

  This is similar to save_calibration but doesn't set the calibrated_at timestamp.
  Used when manually mapping notches rather than calibrating hardware.
  """
  @spec save_notches(LeverConfig.t(), [map()]) ::
          {:ok, LeverConfig.t()} | {:error, term()}
  def save_notches(%LeverConfig{} = lever_config, notches) when is_list(notches) do
    Repo.transaction(fn ->
      # Delete existing notches
      Notch
      |> where([n], n.lever_config_id == ^lever_config.id)
      |> Repo.delete_all()

      # Create new notches
      notch_results =
        notches
        |> Enum.with_index()
        |> Enum.map(fn {notch_attrs, index} ->
          # Ensure all keys are strings to avoid mixed key types
          attrs_with_index =
            notch_attrs
            |> Map.new(fn {k, v} -> {to_string(k), v} end)
            |> Map.put("index", index)

          %Notch{lever_config_id: lever_config.id}
          |> Notch.changeset(attrs_with_index)
          |> Repo.insert()
        end)

      # Check for errors
      errors = Enum.filter(notch_results, &match?({:error, _}, &1))

      if errors != [] do
        Repo.rollback({:notch_errors, errors})
      else
        # Reload the config with notches
        case get_lever_config(lever_config.element_id) do
          {:ok, reloaded} -> reloaded
          {:error, reason} -> Repo.rollback(reason)
        end
      end
    end)
  end

  @doc """
  Update input ranges for multiple notches.

  Takes a list of maps with `:id`, `:input_min`, and `:input_max` keys
  and updates each notch's input range. Used by the guided notch mapping wizard.

  ## Parameters

    * `lever_config_id` - The lever config ID
    * `notch_updates` - List of maps: `[%{id: 1, input_min: 0.0, input_max: 0.33}, ...]`

  ## Returns

    * `{:ok, LeverConfig.t()}` - Updated lever config with reloaded notches
    * `{:error, term()}` - Error if any update fails
  """
  @spec update_notch_input_ranges(integer(), [map()], keyword()) ::
          {:ok, LeverConfig.t()} | {:error, term()}
  def update_notch_input_ranges(lever_config_id, notch_updates, opts \\ [])
      when is_list(notch_updates) do
    inverted = Keyword.get(opts, :inverted)

    Repo.transaction(fn ->
      results =
        Enum.map(notch_updates, fn %{id: notch_id, input_min: input_min, input_max: input_max} ->
          case Repo.get(Notch, notch_id) do
            nil ->
              {:error, {:not_found, notch_id}}

            notch ->
              notch
              |> Notch.changeset(%{input_min: input_min, input_max: input_max})
              |> Repo.update()
          end
        end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if errors != [] do
        Repo.rollback({:update_errors, errors})
      else
        # Find the element_id from the lever config
        case Repo.get(LeverConfig, lever_config_id) do
          nil ->
            Repo.rollback(:lever_config_not_found)

          lever_config ->
            # Update inverted flag if provided (auto-detected during notch mapping)
            if is_boolean(inverted) do
              lever_config
              |> LeverConfig.changeset(%{inverted: inverted})
              |> Repo.update!()
            end

            case get_lever_config(lever_config.element_id) do
              {:ok, reloaded} -> reloaded
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end
    end)
  end

  # ===================
  # Identifier Operations
  # ===================

  @doc """
  Derive train identifier from the current formation in the simulator.

  Returns the common prefix of all ObjectClass values as a string.
  """
  @spec derive_identifier(Client.t()) :: {:ok, String.t()} | {:error, term()}
  defdelegate derive_identifier(client), to: Identifier, as: :derive_from_formation

  # ===================
  # Calibration Operations
  # ===================

  @doc """
  Start a calibration session for a lever.

  The calibration process runs asynchronously, stepping through the lever's
  full range and detecting notch types. Subscribe to calibration events
  to receive progress updates and the final result.

  Returns `{:ok, pid}` if the session starts successfully,
  `{:error, :already_running}` if a session for this lever is already active.
  """
  @spec start_calibration(Client.t(), LeverConfig.t()) ::
          {:ok, pid()} | {:error, :already_running} | {:error, term()}
  defdelegate start_calibration(client, lever_config), to: SessionSupervisor

  @doc """
  Stop a running calibration session.
  """
  @spec stop_calibration(integer()) :: :ok | {:error, :not_found}
  defdelegate stop_calibration(lever_config_id), to: SessionSupervisor

  @doc """
  Check if a calibration session is running for a lever config.
  """
  @spec calibration_running?(integer()) :: boolean()
  defdelegate calibration_running?(lever_config_id), to: SessionSupervisor, as: :session_running?

  @doc """
  Get the current state of a calibration session.
  """
  @spec get_calibration_state(integer()) :: LeverSession.State.t() | nil
  defdelegate get_calibration_state(lever_config_id), to: LeverSession, as: :get_state

  @doc """
  Subscribe to calibration events for a lever config.

  Events sent on topic `"train:calibration:{lever_config_id}"`:
  - `{:calibration_progress, state}` - Progress updates during calibration
  - `{:calibration_result, {:ok, LeverConfig.t()} | {:error, reason}}` - Final result
  """
  @spec subscribe_calibration(integer()) :: :ok
  defdelegate subscribe_calibration(lever_config_id), to: LeverSession, as: :subscribe

  # ===================
  # Notch Mapping Operations
  # ===================

  alias Trenino.Train.Calibration.NotchMappingSession

  @doc """
  Start a notch mapping session for guided input-to-notch boundary mapping.

  ## Options

    * `:lever_config` - Required. The lever config with preloaded notches.
    * `:port` - Required. The serial port of the bound device.
    * `:pin` - Required. The pin number of the bound input.
    * `:calibration` - Required. The input's calibration data.

  Returns `{:ok, pid}` if the session starts successfully,
  `{:error, :already_running}` if a mapping session for this lever is already active.
  """
  @spec start_notch_mapping(keyword()) ::
          {:ok, pid()} | {:error, :already_running} | {:error, term()}
  defdelegate start_notch_mapping(opts), to: SessionSupervisor

  @doc """
  Stop a running notch mapping session.
  """
  @spec stop_notch_mapping(integer()) :: :ok | {:error, :not_found}
  defdelegate stop_notch_mapping(lever_config_id), to: SessionSupervisor

  @doc """
  Check if a notch mapping session is running for a lever config.
  """
  @spec notch_mapping_running?(integer()) :: boolean()
  defdelegate notch_mapping_running?(lever_config_id), to: SessionSupervisor

  @doc """
  Get the PID of a running notch mapping session.
  """
  @spec get_notch_mapping_session(integer()) :: pid() | nil
  defdelegate get_notch_mapping_session(lever_config_id), to: SessionSupervisor

  @doc """
  Subscribe to notch mapping events for a lever config.

  Events sent on topic `"train:notch_mapping:{lever_config_id}"`:
  - `{:session_started, public_state}` - Session began
  - `{:step_changed, public_state}` - Advanced to next step
  - `{:sample_updated, public_state}` - Current value updated
  - `{:mapping_result, {:ok, LeverConfig.t()} | {:error, reason}}` - Final result
  """
  @spec subscribe_notch_mapping(integer()) :: :ok
  defdelegate subscribe_notch_mapping(lever_config_id), to: NotchMappingSession, as: :subscribe

  # ===================
  # Input Binding Operations
  # ===================

  @doc """
  Get the input binding for a lever config.
  """
  @spec get_binding(integer()) :: {:ok, LeverInputBinding.t()} | {:error, :not_found}
  def get_binding(lever_config_id) do
    case Repo.get_by(LeverInputBinding, lever_config_id: lever_config_id) do
      nil -> {:error, :not_found}
      binding -> {:ok, Repo.preload(binding, :input)}
    end
  end

  @doc """
  Bind an input to a lever config.

  Creates a new binding or updates an existing one.
  """
  @spec bind_input(integer(), integer()) ::
          {:ok, LeverInputBinding.t()} | {:error, Ecto.Changeset.t()}
  def bind_input(lever_config_id, input_id) do
    case Repo.get_by(LeverInputBinding, lever_config_id: lever_config_id) do
      nil ->
        %LeverInputBinding{}
        |> LeverInputBinding.changeset(%{
          lever_config_id: lever_config_id,
          input_id: input_id
        })
        |> Repo.insert()

      existing ->
        existing
        |> LeverInputBinding.changeset(%{input_id: input_id})
        |> Repo.update()
    end
  end

  @doc """
  Unbind an input from a lever config.
  """
  @spec unbind_input(integer()) :: :ok | {:error, :not_found}
  def unbind_input(lever_config_id) do
    case Repo.get_by(LeverInputBinding, lever_config_id: lever_config_id) do
      nil ->
        {:error, :not_found}

      binding ->
        Repo.delete(binding)
        :ok
    end
  end

  @doc """
  Enable or disable an input binding.
  """
  @spec set_binding_enabled(integer(), boolean()) ::
          {:ok, LeverInputBinding.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def set_binding_enabled(lever_config_id, enabled) do
    case Repo.get_by(LeverInputBinding, lever_config_id: lever_config_id) do
      nil ->
        {:error, :not_found}

      binding ->
        binding
        |> LeverInputBinding.changeset(%{enabled: enabled})
        |> Repo.update()
    end
  end

  @doc """
  List all input bindings for a train.

  Returns bindings with their associated lever configs and inputs preloaded.
  """
  @spec list_bindings_for_train(integer()) :: [LeverInputBinding.t()]
  def list_bindings_for_train(train_id) do
    LeverInputBinding
    |> join(:inner, [b], lc in LeverConfig, on: b.lever_config_id == lc.id)
    |> join(:inner, [b, lc], e in Element, on: lc.element_id == e.id)
    |> where([b, lc, e], e.train_id == ^train_id)
    |> preload([b], [:input, lever_config: [:element, :notches]])
    |> Repo.all()
  end

  @doc """
  Auto-distribute input ranges across notches for a lever config.

  Divides the 0.0-1.0 input range evenly across all notches.
  """
  @spec auto_distribute_input_ranges(integer()) ::
          {:ok, LeverConfig.t()} | {:error, :not_found} | {:error, term()}
  def auto_distribute_input_ranges(lever_config_id) do
    case get_lever_config(lever_config_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, config} ->
        notches = config.notches |> Enum.sort_by(& &1.index)
        count = length(notches)

        if count == 0 do
          {:ok, config}
        else
          step = 1.0 / count

          Repo.transaction(fn ->
            notches
            |> Enum.with_index()
            |> Enum.each(fn {notch, idx} ->
              input_min = Float.round(idx * step, 2)
              input_max = Float.round((idx + 1) * step, 2)

              notch
              |> Notch.changeset(%{input_min: input_min, input_max: input_max})
              |> Repo.update!()
            end)

            # Reload the config with updated notches
            case get_lever_config(lever_config_id) do
              {:ok, reloaded} -> reloaded
              {:error, reason} -> Repo.rollback(reason)
            end
          end)
        end
    end
  end

  @doc """
  Validate that notch input ranges cover the full 0.0-1.0 range without gaps.

  Returns `:ok` if valid, or `{:error, :gaps_detected, gaps}` with a list of gap ranges.
  """
  @spec validate_notch_ranges(integer()) ::
          :ok | {:error, :not_found} | {:error, :gaps_detected, [{float(), float()}]}
  def validate_notch_ranges(lever_config_id) do
    case get_lever_config(lever_config_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, config} ->
        notches = config.notches |> Enum.sort_by(& &1.index)

        # Collect all ranges and find gaps
        ranges =
          notches
          |> Enum.filter(fn n -> n.input_min != nil and n.input_max != nil end)
          |> Enum.map(fn n -> {n.input_min, n.input_max} end)
          |> Enum.sort_by(&elem(&1, 0))

        gaps = find_gaps(ranges, 0.0, 1.0)

        if gaps == [] do
          :ok
        else
          {:error, :gaps_detected, gaps}
        end
    end
  end

  defp find_gaps([], start_val, end_val) when start_val < end_val do
    [{start_val, end_val}]
  end

  defp find_gaps([], _start_val, _end_val), do: []

  defp find_gaps([{range_start, range_end} | rest], current, end_val) do
    gaps =
      if range_start > current + 0.001 do
        [{current, range_start}]
      else
        []
      end

    gaps ++ find_gaps(rest, max(current, range_end), end_val)
  end

  # ===================
  # Button Binding Operations
  # ===================

  @doc """
  Get the button binding for an element.
  """
  @spec get_button_binding(integer()) :: {:ok, ButtonInputBinding.t()} | {:error, :not_found}
  def get_button_binding(element_id) do
    case Repo.get_by(ButtonInputBinding, element_id: element_id) do
      nil -> {:error, :not_found}
      binding -> {:ok, Repo.preload(binding, input: :device)}
    end
  end

  @doc """
  Create a button binding for an element.

  ## Parameters

    * `element_id` - The button element ID
    * `input_id` - The button input ID
    * `attrs` - Map with `:endpoint` or `"endpoint"`, and optionally `:on_value`, `:off_value`, `:enabled`

  Merges `element_id` and `input_id` into `attrs` for the changeset.
  """
  @spec create_button_binding(integer(), integer(), map()) ::
          {:ok, ButtonInputBinding.t()} | {:error, Ecto.Changeset.t()}
  def create_button_binding(element_id, input_id, attrs) do
    # Changesets require consistent key types (all atoms or all strings).
    # Since form params come as strings, ensure IDs use the same key type as attrs.
    params =
      case Map.keys(attrs) do
        [key | _] when is_binary(key) ->
          # String keys from form - add IDs as strings
          Map.merge(attrs, %{"element_id" => element_id, "input_id" => input_id})

        _ ->
          # Atom keys from direct map - add IDs as atoms
          Map.merge(attrs, %{element_id: element_id, input_id: input_id})
      end

    %ButtonInputBinding{}
    |> ButtonInputBinding.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Update a button binding.
  """
  @spec update_button_binding(ButtonInputBinding.t(), map()) ::
          {:ok, ButtonInputBinding.t()} | {:error, Ecto.Changeset.t()}
  def update_button_binding(%ButtonInputBinding{} = binding, attrs) do
    binding
    |> ButtonInputBinding.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a button binding by element ID.
  """
  @spec delete_button_binding(integer()) :: :ok | {:error, :not_found}
  def delete_button_binding(element_id) do
    case Repo.get_by(ButtonInputBinding, element_id: element_id) do
      nil ->
        {:error, :not_found}

      binding ->
        Repo.delete(binding)
        :ok
    end
  end

  @doc """
  Enable or disable a button binding.
  """
  @spec set_button_binding_enabled(integer(), boolean()) ::
          {:ok, ButtonInputBinding.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def set_button_binding_enabled(element_id, enabled) do
    case Repo.get_by(ButtonInputBinding, element_id: element_id) do
      nil ->
        {:error, :not_found}

      binding ->
        binding
        |> ButtonInputBinding.changeset(%{enabled: enabled})
        |> Repo.update()
    end
  end

  @doc """
  List all button bindings for a train.

  Returns bindings with their associated elements and inputs preloaded.
  """
  @spec list_button_bindings_for_train(integer()) :: [ButtonInputBinding.t()]
  def list_button_bindings_for_train(train_id) do
    ButtonInputBinding
    |> join(:inner, [b], e in Element, on: b.element_id == e.id)
    |> where([b, e], e.train_id == ^train_id)
    |> preload([b], [:element, input: :device])
    |> Repo.all()
  end

  @doc """
  List all button elements for a train.

  Returns elements that have type :button.
  """
  @spec list_button_elements(integer()) :: [Element.t()]
  def list_button_elements(train_id) do
    Element
    |> where([e], e.train_id == ^train_id and e.type == :button)
    |> order_by([e], e.name)
    |> preload(button_binding: [input: :device])
    |> Repo.all()
  end

  # =============================================================================
  # Sequence functions
  # =============================================================================

  alias Trenino.Train.Sequence
  alias Trenino.Train.SequenceCommand

  @doc """
  Create a new sequence for a train.
  """
  @spec create_sequence(integer(), map()) :: {:ok, Sequence.t()} | {:error, Ecto.Changeset.t()}
  def create_sequence(train_id, attrs) do
    params = Map.put(attrs, :train_id, train_id)

    %Sequence{}
    |> Sequence.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Get a sequence by ID with commands preloaded.
  """
  @spec get_sequence(integer()) :: {:ok, Sequence.t()} | {:error, :not_found}
  def get_sequence(id) do
    case Repo.get(Sequence, id) |> Repo.preload(:commands) do
      nil -> {:error, :not_found}
      sequence -> {:ok, sequence}
    end
  end

  @doc """
  Get a sequence by ID without preloading.
  """
  @spec get_sequence!(integer()) :: Sequence.t()
  def get_sequence!(id) do
    Repo.get!(Sequence, id)
  end

  @doc """
  Update a sequence.
  """
  @spec update_sequence(Sequence.t(), map()) :: {:ok, Sequence.t()} | {:error, Ecto.Changeset.t()}
  def update_sequence(%Sequence{} = sequence, attrs) do
    sequence
    |> Sequence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a sequence.
  """
  @spec delete_sequence(Sequence.t()) :: {:ok, Sequence.t()} | {:error, Ecto.Changeset.t()}
  def delete_sequence(%Sequence{} = sequence) do
    Repo.delete(sequence)
  end

  @doc """
  List all sequences for a train.
  """
  @spec list_sequences(integer()) :: [Sequence.t()]
  def list_sequences(train_id) do
    Sequence
    |> where([s], s.train_id == ^train_id)
    |> order_by([s], s.name)
    |> preload(:commands)
    |> Repo.all()
  end

  @doc """
  Set the commands for a sequence.

  Replaces all existing commands with the new ones.
  Positions are automatically assigned based on list order (0-indexed).

  ## Parameters

  - `sequence` - The sequence to update
  - `commands` - List of command maps with `:endpoint`, `:value`, and optionally `:delay_ms`

  ## Example

      Train.set_sequence_commands(sequence, [
        %{endpoint: "Horn.InputValue", value: 1.0, delay_ms: 500},
        %{endpoint: "Horn.InputValue", value: 0.0}
      ])
  """
  @spec set_sequence_commands(Sequence.t(), [map()]) ::
          {:ok, [SequenceCommand.t()]} | {:error, term()}
  def set_sequence_commands(%Sequence{id: sequence_id}, commands) when is_list(commands) do
    Repo.transaction(fn ->
      # Delete existing commands
      SequenceCommand
      |> where([c], c.sequence_id == ^sequence_id)
      |> Repo.delete_all()

      # Insert new commands with positions
      results =
        commands
        |> Enum.with_index()
        |> Enum.map(fn {attrs, position} ->
          params =
            attrs
            |> Map.put(:sequence_id, sequence_id)
            |> Map.put(:position, position)

          %SequenceCommand{}
          |> SequenceCommand.changeset(params)
          |> Repo.insert()
        end)

      # Check for errors
      case Enum.find(results, fn
             {:error, _} -> true
             _ -> false
           end) do
        {:error, changeset} ->
          Repo.rollback(changeset)

        nil ->
          Enum.map(results, fn {:ok, cmd} -> cmd end)
      end
    end)
  end

  @doc """
  Add a single command to a sequence at the end.
  """
  @spec add_sequence_command(Sequence.t(), map()) ::
          {:ok, SequenceCommand.t()} | {:error, Ecto.Changeset.t()}
  def add_sequence_command(%Sequence{id: sequence_id}, attrs) do
    # Get the highest position
    max_position =
      SequenceCommand
      |> where([c], c.sequence_id == ^sequence_id)
      |> select([c], max(c.position))
      |> Repo.one() || -1

    params =
      attrs
      |> Map.put(:sequence_id, sequence_id)
      |> Map.put(:position, max_position + 1)

    %SequenceCommand{}
    |> SequenceCommand.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Delete a sequence command.
  """
  @spec delete_sequence_command(SequenceCommand.t()) ::
          {:ok, SequenceCommand.t()} | {:error, Ecto.Changeset.t()}
  def delete_sequence_command(%SequenceCommand{} = command) do
    Repo.delete(command)
  end
end
