defmodule Trenino.Train.ActionExecutor do
  @moduledoc """
  Runs `Trenino.Train.Action`s against the simulator and the keyboard.

  `run/2` is synchronous: a sequence blocks for the sum of its delays. Call it
  from a task, never from a controller's own process.

  Pass `owner: pid` to tie a run to the process that started it. If the owner
  goes down, a sequence stops before its next command instead of running on
  as an orphan.
  """

  require Logger

  alias Trenino.Keyboard
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train.Action

  @type result :: :ok | {:error, term()}

  @doc """
  Run a list of actions in order. Stops at the first action whose owner is
  gone; other failures are logged and the next action still runs.
  """
  @spec run_all([Action.t()], keyword()) :: result()
  def run_all(actions, opts \\ []) when is_list(actions) do
    with_owner(opts, fn owner_ref ->
      Enum.reduce_while(actions, :ok, &run_step(&1, &2, owner_ref))
    end)
  end

  defp run_step(%Action{} = action, acc, owner_ref) do
    case do_run(action, owner_ref) do
      {:error, :owner_down} = error -> {:halt, error}
      {:error, _reason} = error -> {:cont, error}
      :ok -> {:cont, acc}
    end
  end

  @doc """
  Run one action.
  """
  @spec run(Action.t(), keyword()) :: result()
  def run(%Action{} = action, opts \\ []) do
    with_owner(opts, &do_run(action, &1))
  end

  defp with_owner(opts, fun) do
    case Keyword.get(opts, :owner) do
      nil ->
        fun.(nil)

      owner when is_pid(owner) ->
        ref = Process.monitor(owner)

        try do
          fun.({owner, ref})
        after
          Process.demonitor(ref, [:flush])
        end
    end
  end

  defp do_run(%Action{kind: :set_value, endpoint: endpoint, value: value}, _owner_ref) do
    set_value(endpoint, value)
  end

  defp do_run(%Action{kind: :keystroke, keystroke: keystroke}, _owner_ref) do
    case Keyboard.tap(keystroke) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning("[ActionExecutor] Keystroke #{keystroke} failed: #{inspect(reason)}")
        error
    end
  end

  defp do_run(%Action{kind: :sequence, commands: commands}, owner_ref) do
    run_commands(commands, owner_ref, :ok)
  end

  defp run_commands([], _owner_ref, result), do: result

  defp run_commands([command | rest], owner_ref, result) do
    with :ok <- check_owner(owner_ref) do
      result =
        case set_value(command.endpoint, command.value) do
          :ok -> result
          {:error, _reason} = error -> error
        end

      case wait(command.delay_ms, owner_ref) do
        :ok -> run_commands(rest, owner_ref, result)
        {:error, :owner_down} = error -> error
      end
    end
  end

  defp check_owner(nil), do: :ok

  defp check_owner({owner, ref}) do
    receive do
      {:DOWN, ^ref, :process, ^owner, _reason} -> {:error, :owner_down}
    after
      0 -> :ok
    end
  end

  defp wait(delay_ms, _owner_ref) when not is_integer(delay_ms) or delay_ms <= 0, do: :ok
  defp wait(delay_ms, nil), do: Process.sleep(delay_ms)

  defp wait(delay_ms, {owner, ref}) do
    receive do
      {:DOWN, ^ref, :process, ^owner, _reason} -> {:error, :owner_down}
    after
      delay_ms -> :ok
    end
  end

  defp set_value(endpoint, value) when is_binary(endpoint) and is_number(value) do
    with {:ok, client} <- simulator_client(),
         {:ok, _response} <- SimulatorClient.set(client, endpoint, value) do
      :ok
    else
      {:error, reason} = error ->
        Logger.warning("[ActionExecutor] Failed to set #{endpoint}=#{value}: #{inspect(reason)}")
        error
    end
  end

  defp set_value(endpoint, value) do
    Logger.warning("[ActionExecutor] Skipping invalid command #{inspect({endpoint, value})}")
    {:error, :invalid_command}
  end

  defp simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil -> {:ok, client}
      _ -> {:error, :not_connected}
    end
  end
end
