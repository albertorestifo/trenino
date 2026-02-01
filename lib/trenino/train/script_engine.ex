defmodule Trenino.Train.ScriptEngine do
  @moduledoc """
  Lua scripting engine for train scripts.

  Wraps the `lua` library to provide a sandboxed Lua VM with the Trenino
  scripting API: `api.get`, `api.set`, `output.set`, `schedule`, and `state`.

  Each script gets its own VM instance. The VM is created once when the script
  loads, and `on_change(event)` is called on each trigger.

  ## Callbacks

  The engine collects "side effects" during execution rather than performing
  them inline. This allows the caller (ScriptRunner) to handle API calls,
  output commands, and scheduling after the Lua execution completes.

  Side effects are returned as a list:
  - `{:api_get, path}` - Read simulator endpoint
  - `{:api_set, path, value}` - Write simulator endpoint
  - `{:output_set, output_id, on?}` - Set hardware output
  - `{:schedule, ms}` - Schedule re-invocation
  - `{:log, message}` - Print output from script
  """

  @type side_effect ::
          {:api_get, String.t()}
          | {:api_set, String.t(), number()}
          | {:output_set, integer(), boolean()}
          | {:schedule, pos_integer()}
          | {:log, String.t()}

  @type execute_result ::
          {:ok, Lua.t(), [side_effect()]}
          | {:error, term()}

  @doc """
  Create a new Lua VM with the Trenino API loaded and the given script compiled.

  Returns `{:ok, lua_state}` or `{:error, reason}`.
  """
  @spec new(String.t()) :: {:ok, Lua.t()} | {:error, term()}
  def new(code) do
    try do
      lua =
        Lua.new()
        |> setup_api()
        |> setup_output()
        |> setup_schedule()
        |> setup_print()
        |> setup_state()

      {_, lua} = Lua.eval!(lua, code)
      {:ok, lua}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Execute `on_change(event)` in the Lua VM.

  Returns `{:ok, updated_lua_state, side_effects}` or `{:error, reason}`.
  Side effects are collected during execution via process dictionary.
  """
  @spec execute(Lua.t(), map()) :: execute_result()
  def execute(lua, event) do
    # Reset side effects collector
    Process.put(:lua_side_effects, [])

    try do
      {encoded_event, lua} = Lua.encode!(lua, event)
      {_, lua} = Lua.call_function!(lua, [:on_change], [encoded_event])
      effects = Process.get(:lua_side_effects, []) |> Enum.reverse()
      {:ok, lua, effects}
    rescue
      e -> {:error, Exception.message(e)}
    after
      Process.delete(:lua_side_effects)
    end
  end

  # -- Private: API setup --

  defp setup_api(lua) do
    lua
    |> Lua.set!([:api, :get], fn args ->
      path = args |> List.first() |> to_string()
      add_side_effect({:api_get, path})
      [nil, "not available"]
    end)
    |> Lua.set!([:api, :set], fn args ->
      path = args |> Enum.at(0) |> to_string()
      value = Enum.at(args, 1)
      add_side_effect({:api_set, path, value})
      [true]
    end)
  end

  defp setup_output(lua) do
    Lua.set!(lua, [:output, :set], fn args ->
      case args do
        [id, on] when is_number(id) ->
          add_side_effect({:output_set, trunc(id), truthy?(on)})
          [true]

        _ ->
          [nil, "usage: output.set(id, true/false)"]
      end
    end)
  end

  defp setup_schedule(lua) do
    Lua.set!(lua, [:schedule], fn args ->
      case args do
        [ms] when is_number(ms) and ms > 0 ->
          add_side_effect({:schedule, trunc(ms)})
          [true]

        _ ->
          [nil, "usage: schedule(milliseconds) where milliseconds > 0"]
      end
    end)
  end

  defp setup_print(lua) do
    Lua.set!(lua, [:print], fn args ->
      message = args |> Enum.map(&to_string/1) |> Enum.join("\t")
      add_side_effect({:log, message})
      []
    end)
  end

  defp setup_state(lua) do
    # Initialize empty state table
    {_, lua} = Lua.eval!(lua, "state = {}")
    lua
  end

  defp add_side_effect(effect) do
    effects = Process.get(:lua_side_effects, [])
    Process.put(:lua_side_effects, [effect | effects])
  end

  defp truthy?(value) when value == false or value == nil, do: false
  defp truthy?(_), do: true
end
