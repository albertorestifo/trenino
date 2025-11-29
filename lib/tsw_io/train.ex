defmodule TswIo.Train do
  @moduledoc """
  Context for train configurations and management.

  Provides functions for managing train configurations, elements,
  and their calibrations for integration with Train Sim World.
  """

  import Ecto.Query

  alias TswIo.Repo
  alias TswIo.Train.{Train, Element, LeverConfig, Notch, Identifier}
  alias TswIo.Simulator.Client

  # Detection delegation
  defdelegate subscribe(), to: TswIo.Train.Detection
  defdelegate get_active_train(), to: TswIo.Train.Detection
  defdelegate get_current_identifier(), to: TswIo.Train.Detection
  defdelegate sync(), to: TswIo.Train.Detection

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
  Get a train by its identifier.

  The identifier is the common prefix derived from the train's ObjectClass values.
  """
  @spec get_train_by_identifier(String.t()) :: {:ok, Train.t()} | {:error, :not_found}
  def get_train_by_identifier(identifier) do
    case Repo.get_by(Train, identifier: identifier) do
      nil -> {:error, :not_found}
      train -> {:ok, Repo.preload(train, elements: :lever_config)}
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
      |> preload(lever_config: :notches)
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
          %Notch{lever_config_id: lever_config.id}
          |> Notch.changeset(Map.put(notch_attrs, :index, index))
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
  Update a notch description.
  """
  @spec update_notch_description(Notch.t(), String.t() | nil) ::
          {:ok, Notch.t()} | {:error, Ecto.Changeset.t()}
  def update_notch_description(%Notch{} = notch, description) do
    notch
    |> Notch.changeset(%{description: description})
    |> Repo.update()
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
end
