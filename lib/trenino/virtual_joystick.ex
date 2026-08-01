defmodule Trenino.VirtualJoystick do
  @moduledoc """
  Persistence operations for the virtual joystick configuration and mappings.
  """

  import Ecto.Query

  alias Trenino.Hardware.Input
  alias Trenino.Repo
  alias Trenino.VirtualJoystick.{Configuration, Mapping}

  @mapping_preloads [input: [:device, :calibration]]

  @spec get_configuration() :: Configuration.t()
  def get_configuration do
    case Repo.get(Configuration, 1) do
      nil ->
        %Configuration{id: 1}
        |> Configuration.changeset(%{})
        |> Repo.insert(on_conflict: :nothing)

        Repo.get!(Configuration, 1)

      configuration ->
        configuration
    end
  end

  @spec list_mappings() :: [Mapping.t()]
  def list_mappings do
    Mapping
    |> order_by([mapping],
      asc: mapping.device_index,
      asc: mapping.target_type,
      asc: mapping.axis,
      asc: mapping.button
    )
    |> preload(^@mapping_preloads)
    |> Repo.all()
  end

  @spec get_mapping(integer()) :: {:ok, Mapping.t()} | {:error, :not_found}
  def get_mapping(mapping_id) do
    case Repo.get(Mapping, mapping_id) do
      nil -> {:error, :not_found}
      mapping -> {:ok, Repo.preload(mapping, @mapping_preloads)}
    end
  end

  @spec put_mapping(integer(), map(), keyword()) ::
          {:ok, Mapping.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def put_mapping(input_id, attrs, opts \\ []) do
    _replace? = Keyword.get(opts, :replace?, false)
    attrs = Map.drop(attrs, [:input_id, "input_id"])

    Repo.transaction(fn ->
      input =
        Input
        |> where([input], input.id == ^input_id)
        |> preload([:device, :calibration])
        |> Repo.one()

      if is_nil(input) do
        Repo.rollback(:not_found)
      end

      mapping = Repo.get_by(Mapping, input_id: input.id)

      mapping_changeset =
        (mapping || %Mapping{input_id: input.id})
        |> Mapping.changeset(attrs)
        |> Mapping.validate_input_type(input)

      case Repo.insert_or_update(mapping_changeset) do
        {:ok, saved_mapping} -> Repo.preload(saved_mapping, @mapping_preloads)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec delete_mapping(integer() | Mapping.t()) ::
          {:ok, Mapping.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_mapping(mapping_id) when is_integer(mapping_id) do
    case Repo.get(Mapping, mapping_id) do
      nil -> {:error, :not_found}
      mapping -> Repo.delete(mapping)
    end
  end

  def delete_mapping(%Mapping{} = mapping), do: Repo.delete(mapping)
end
