defmodule Trenino.VirtualJoystick do
  @moduledoc """
  Persistence operations for the virtual joystick configuration and mappings.
  """

  import Ecto.Query

  alias Trenino.Hardware.Input
  alias Trenino.Repo
  alias Trenino.Train.{ButtonController, ButtonInputBinding, LeverController, LeverInputBinding}
  alias Trenino.VirtualJoystick.{Configuration, Manager, Mapping}

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

  @spec confirm_enabled(boolean()) :: {:ok, Configuration.t()} | {:error, Ecto.Changeset.t()}
  def confirm_enabled(enabled?) when is_boolean(enabled?) do
    get_configuration()
    |> Configuration.changeset(%{enabled: enabled?})
    |> Repo.update()
  end

  @spec status() :: Trenino.VirtualJoystick.Manager.State.status()
  defdelegate status(), to: Trenino.VirtualJoystick.Manager
  defdelegate status_details(), to: Trenino.VirtualJoystick.Manager

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Trenino.PubSub, "virtual_joystick")

  defdelegate enable(), to: Trenino.VirtualJoystick.Manager
  defdelegate disable(), to: Trenino.VirtualJoystick.Manager
  defdelegate retry(), to: Trenino.VirtualJoystick.Manager
  defdelegate remove_leftover(), to: Trenino.VirtualJoystick.Manager
  defdelegate repair(), to: Trenino.VirtualJoystick.Manager
  defdelegate reload_mappings(), to: Trenino.VirtualJoystick.Manager

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
          {:ok, Mapping.t()} | {:error, :destination_conflict | :not_found | Ecto.Changeset.t()}
  def put_mapping(input_id, attrs, opts \\ []) do
    replace? = Keyword.get(opts, :replace?, false)
    attrs = Map.drop(attrs, [:input_id, "input_id"])

    case Repo.transaction(fn -> persist_mapping(input_id, attrs, replace?) end, mode: :immediate) do
      {:ok, {mapping, replaced}} ->
        maybe_notify_replacement(replaced)
        {:ok, mapping}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_mapping(input_id, attrs, replace?) do
    input = lock_input(input_id)
    if is_nil(input), do: Repo.rollback(:not_found)

    (Repo.get_by(Mapping, input_id: input.id) || %Mapping{input_id: input.id})
    |> Mapping.changeset(attrs)
    |> Mapping.validate_input_type(input)
    |> save_mapping(input.id, replace?)
  end

  defp save_mapping(%Ecto.Changeset{valid?: false} = changeset, _input_id, _replace?),
    do: Repo.rollback(changeset)

  defp save_mapping(%Ecto.Changeset{} = changeset, input_id, replace?) do
    replaced = maybe_replace_simulator_bindings(input_id, replace?)

    case Repo.insert_or_update(changeset) do
      {:ok, mapping} -> {Repo.preload(mapping, @mapping_preloads), replaced}
      {:error, invalid_changeset} -> Repo.rollback(invalid_changeset)
    end
  end

  defp maybe_replace_simulator_bindings(input_id, true) do
    %{
      lever?: delete_enabled_bindings(LeverInputBinding, input_id),
      button?: delete_enabled_bindings(ButtonInputBinding, input_id)
    }
  end

  defp maybe_replace_simulator_bindings(input_id, false) do
    if simulator_binding_exists?(input_id), do: Repo.rollback(:destination_conflict)

    %{lever?: false, button?: false}
  end

  # SQLite does not support `SELECT ... FOR UPDATE`. The surrounding immediate
  # transaction acquires its writer lock before this lookup, serializing every
  # destination change that shares this input.
  defp lock_input(input_id) do
    Input
    |> where([input], input.id == ^input_id)
    |> preload([:device, :calibration])
    |> Repo.one()
  end

  defp simulator_binding_exists?(input_id) do
    enabled_binding_exists?(LeverInputBinding, input_id) or
      enabled_binding_exists?(ButtonInputBinding, input_id)
  end

  defp enabled_binding_exists?(binding, input_id) do
    binding
    |> where([binding], binding.input_id == ^input_id and binding.enabled == true)
    |> Repo.exists?()
  end

  defp delete_enabled_bindings(binding, input_id) do
    {count, _} =
      binding
      |> where([binding], binding.input_id == ^input_id and binding.enabled == true)
      |> Repo.delete_all()

    count > 0
  end

  defp maybe_notify_replacement(%{lever?: lever?, button?: button?}) do
    if lever? and Process.whereis(LeverController), do: LeverController.reload_bindings()

    if button? and Process.whereis(ButtonController), do: ButtonController.reload_bindings()

    if (lever? or button?) and Process.whereis(Manager), do: Manager.reload_mappings()
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
