defmodule TreninoWeb.Api.ScriptController do
  use TreninoWeb, :controller

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Script
  alias Trenino.Train.ScriptRunner

  def index(conn, %{"train_api_id" => train_id}) do
    scripts = TrainContext.list_scripts(String.to_integer(train_id))
    json(conn, %{scripts: Enum.map(scripts, &script_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case TrainContext.get_script(String.to_integer(id)) do
      {:ok, script} -> json(conn, %{script: script_json(script)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "not found"})
    end
  end

  def create(conn, %{"train_api_id" => train_id} = params) do
    attrs = script_params(params)

    case TrainContext.create_script(String.to_integer(train_id), attrs) do
      {:ok, script} ->
        ScriptRunner.reload_scripts()
        conn |> put_status(201) |> json(%{script: script_json(script)})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: changeset_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case TrainContext.get_script(String.to_integer(id)) do
      {:ok, script} ->
        attrs = script_params(params)

        case TrainContext.update_script(script, attrs) do
          {:ok, updated} ->
            ScriptRunner.reload_scripts()
            json(conn, %{script: script_json(updated)})

          {:error, changeset} ->
            conn |> put_status(422) |> json(%{errors: changeset_errors(changeset)})
        end

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not found"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case TrainContext.get_script(String.to_integer(id)) do
      {:ok, script} ->
        {:ok, _} = TrainContext.delete_script(script)
        ScriptRunner.reload_scripts()
        json(conn, %{ok: true})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not found"})
    end
  end

  defp script_json(%Script{} = script) do
    %{
      id: script.id,
      train_id: script.train_id,
      name: script.name,
      enabled: script.enabled,
      code: script.code,
      triggers: script.triggers,
      inserted_at: script.inserted_at,
      updated_at: script.updated_at
    }
  end

  defp script_params(params) do
    params
    |> Map.take(["name", "enabled", "code", "triggers"])
    |> Enum.reduce(%{}, fn
      {"name", v}, acc -> Map.put(acc, :name, v)
      {"enabled", v}, acc -> Map.put(acc, :enabled, v)
      {"code", v}, acc -> Map.put(acc, :code, v)
      {"triggers", v}, acc -> Map.put(acc, :triggers, v)
      _, acc -> acc
    end)
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
