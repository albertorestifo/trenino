defmodule Trenino.Simulator.Browse do
  @moduledoc """
  Browsing a connected simulator's values, for the API explorer and the
  `list_simulator_endpoints` MCP tool.

  Both simulators answer in the shape of Train Sim World's `/list`:
  `%{"Nodes" => [%{"Name" => name}], "Endpoints" => [%{"Name" => name, "Writable" => bool}]}`.

    * Train Sim World: the API tree, as `Trenino.Simulator.Client.list/2` returns it.
    * SimRail: the player train's IO groups are the nodes at the root, and each
      group's fields are its endpoints, so selecting one gives the `Group.field`
      path SimRail bindings use. Endpoints also carry their current `"Value"`.
      `Physics_Input_*` groups are writable; everything else is read-only.
  """

  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Client

  @type listing :: %{String.t() => list()}

  @doc "Lists the nodes and endpoints at `path` (`nil` for the root)."
  @spec list(Client.t() | SimRail.t(), String.t() | nil) :: {:ok, listing()} | {:error, term()}
  def list(handle, path \\ nil)

  def list(%Client{} = client, path), do: Client.list(client, path)

  def list(%SimRail{} = handle, path) do
    with {:ok, schema} <- SimRail.vehicle(handle) do
      groups = groups(schema)

      case path do
        blank when blank in [nil, ""] ->
          {:ok, %{"Nodes" => Enum.map(groups, &%{"Name" => &1.name}), "Endpoints" => []}}

        group_name ->
          list_group(handle, groups, group_name)
      end
    end
  end

  @doc """
  Reads one value for a preview: TSW's `/get` response, or `%{"Value" => number}`
  for SimRail.
  """
  @spec get(Client.t() | SimRail.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Client{} = client, path), do: Client.get(client, path)

  def get(%SimRail{} = handle, path) do
    with {:ok, value} <- SimRail.get(handle, path), do: {:ok, %{"Value" => value}}
  end

  @doc "True when the handle can be browsed."
  @spec supported?(term()) :: boolean()
  def supported?(%Client{}), do: true
  def supported?(%SimRail{}), do: true
  def supported?(_), do: false

  defp list_group(handle, groups, group_name) do
    case Enum.find(groups, &(&1.name == group_name)) do
      nil ->
        {:error, :invalid_path}

      group ->
        values =
          case SimRail.read(handle, [group.name <> ".*"]) do
            {:ok, values} -> values
            {:error, _} -> %{}
          end

        endpoints =
          Enum.map(group.fields, fn field ->
            path = group.name <> "." <> field

            %{"Name" => field, "Writable" => group.writable}
            |> put_value(Map.get(values, path))
          end)

        {:ok, %{"Nodes" => [], "Endpoints" => endpoints}}
    end
  end

  defp put_value(endpoint, nil), do: endpoint
  defp put_value(endpoint, value), do: Map.put(endpoint, "Value", value)

  defp groups(%{"groups" => groups}) when is_list(groups) do
    for %{"name" => name} = group <- groups, is_binary(name) do
      fields = for field <- Map.get(group, "fields", []), is_binary(field), do: field
      %{name: name, fields: fields, writable: String.starts_with?(name, "Physics_Input")}
    end
  end

  defp groups(_schema), do: []
end
