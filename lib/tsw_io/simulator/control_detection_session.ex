defmodule TswIo.Simulator.ControlDetectionSession do
  @moduledoc """
  Manages an auto-detection session for discovering simulator controls.

  Subscribes to all InputValue endpoints, takes snapshots, and detects
  which control(s) the user interacts with in the simulator.

  ## Usage

      {:ok, pid} = ControlDetectionSession.start(client, self())
      # Wait for message...
      receive do
        {:control_detected, changes} ->
          # changes is a list of %{endpoint: ..., control_name: ..., previous_value: ..., current_value: ...}
        {:detection_timeout} ->
          # No control was detected within timeout
        {:detection_error, reason} ->
          # An error occurred during setup or polling
      end

  """

  use GenServer
  require Logger

  alias TswIo.Simulator.Client

  @poll_interval_ms 150
  @detection_threshold 0.01
  @timeout_ms 30_000
  @subscription_id 99

  defmodule State do
    @moduledoc false

    @type detected_change :: %{
            endpoint: String.t(),
            control_name: String.t(),
            previous_value: float(),
            current_value: float()
          }

    @type t :: %__MODULE__{
            client: Client.t(),
            endpoints: [String.t()],
            baseline_values: %{String.t() => float()},
            callback_pid: pid(),
            poll_timer: reference() | nil,
            timeout_timer: reference() | nil
          }

    defstruct [
      :client,
      :endpoints,
      :baseline_values,
      :callback_pid,
      :poll_timer,
      :timeout_timer
    ]
  end

  # Client API

  @doc """
  Start a detection session. Returns {:ok, pid} or {:error, reason}.

  The session will:
  1. Discover all InputValue endpoints
  2. Subscribe and take baseline snapshot
  3. Poll for changes every 150ms
  4. Send {:control_detected, changes} to callback_pid when changes detected
  5. Auto-terminate after 30 seconds if no detection
  """
  @spec start(Client.t(), pid()) :: {:ok, pid()} | {:error, term()}
  def start(%Client{} = client, callback_pid) when is_pid(callback_pid) do
    GenServer.start(__MODULE__, {client, callback_pid})
  end

  @doc """
  Stop the detection session and cleanup subscription.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Server Callbacks

  @impl true
  def init({client, callback_pid}) do
    # Link to callback_pid so we stop if they crash
    Process.monitor(callback_pid)

    case setup_detection(client) do
      {:ok, endpoints, baseline} ->
        state = %State{
          client: client,
          endpoints: endpoints,
          baseline_values: baseline,
          callback_pid: callback_pid
        }

        Logger.info("[ControlDetectionSession] Started monitoring #{length(endpoints)} endpoints")

        # Start polling
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        timeout_timer = Process.send_after(self(), :timeout, @timeout_ms)

        {:ok, %{state | poll_timer: poll_timer, timeout_timer: timeout_timer}}

      {:error, reason} ->
        Logger.error("[ControlDetectionSession] Setup failed: #{inspect(reason)}")
        send(callback_pid, {:detection_error, reason})
        {:stop, :normal}
    end
  end

  @impl true
  def handle_info(:poll, %State{} = state) do
    case poll_for_changes(state) do
      {:changes_detected, changes} ->
        Logger.info("[ControlDetectionSession] Detected #{length(changes)} control changes")
        send(state.callback_pid, {:control_detected, changes})
        {:stop, :normal, state}

      :no_changes ->
        # Schedule next poll
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        {:noreply, %{state | poll_timer: poll_timer}}

      {:error, reason} ->
        Logger.warning("[ControlDetectionSession] Poll error: #{inspect(reason)}")
        # Continue polling despite errors
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        {:noreply, %{state | poll_timer: poll_timer}}
    end
  end

  def handle_info(:timeout, %State{} = state) do
    Logger.info("[ControlDetectionSession] Timeout - no control detected")
    send(state.callback_pid, {:detection_timeout})
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{} = state) do
    # Callback process died, stop gracefully
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %State{} = state) do
    # Cleanup timers
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)
    if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

    # Cleanup subscription
    Client.unsubscribe(state.client, @subscription_id)

    :ok
  end

  # Private Functions

  defp setup_detection(%Client{} = client) do
    with {:ok, endpoints} <- discover_input_endpoints(client),
         :ok <- create_subscriptions(client, endpoints),
         {:ok, baseline} <- take_baseline_snapshot(client) do
      {:ok, endpoints, baseline}
    end
  end

  defp discover_input_endpoints(%Client{} = client) do
    case Client.list(client, "CurrentDrivableActor") do
      {:ok, %{"Children" => children}} when is_list(children) ->
        # Find all nodes that have InputValue endpoints
        endpoints = find_input_value_endpoints(children, "CurrentDrivableActor")

        Logger.debug(
          "[ControlDetectionSession] Discovered #{length(endpoints)} InputValue endpoints"
        )

        {:ok, endpoints}

      {:ok, response} ->
        Logger.error("[ControlDetectionSession] Unexpected list response: #{inspect(response)}")
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, {:list_failed, reason}}
    end
  end

  defp find_input_value_endpoints(children, parent_path) do
    children
    |> Enum.flat_map(fn child ->
      case child do
        %{"Name" => name, "Children" => sub_children} when is_list(sub_children) ->
          # It's a node with children, recurse
          child_path = "#{parent_path}/#{name}"
          find_input_value_endpoints(sub_children, child_path)

        %{"Name" => "InputValue", "Type" => "Endpoint"} ->
          # Found an InputValue endpoint
          ["#{parent_path}.InputValue"]

        %{"Name" => name, "Type" => "Node"} ->
          # Node without children loaded, could have InputValue
          # We'll try to subscribe directly
          ["#{parent_path}/#{name}.InputValue"]

        _ ->
          []
      end
    end)
  end

  defp create_subscriptions(%Client{} = client, endpoints) do
    # First clear any existing subscription with this ID
    Client.unsubscribe(client, @subscription_id)

    # Subscribe to each endpoint
    results =
      endpoints
      |> Enum.map(fn endpoint ->
        case Client.subscribe(client, endpoint, @subscription_id) do
          {:ok, _} -> :ok
          {:error, _} = error -> error
        end
      end)

    # Check if any subscriptions succeeded
    if Enum.any?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :no_subscriptions_created}
    end
  end

  defp take_baseline_snapshot(%Client{} = client) do
    case Client.get_subscription(client, @subscription_id) do
      {:ok, %{"Entries" => entries}} when is_list(entries) ->
        baseline =
          entries
          |> Enum.reduce(%{}, fn entry, acc ->
            case extract_path_and_value(entry) do
              {path, value} when is_number(value) ->
                Map.put(acc, path, value)

              _ ->
                acc
            end
          end)

        Logger.debug("[ControlDetectionSession] Baseline snapshot: #{map_size(baseline)} values")
        {:ok, baseline}

      {:ok, response} ->
        Logger.warning(
          "[ControlDetectionSession] Unexpected subscription response: #{inspect(response)}"
        )

        {:ok, %{}}

      {:error, reason} ->
        {:error, {:snapshot_failed, reason}}
    end
  end

  defp poll_for_changes(%State{} = state) do
    case Client.get_subscription(state.client, @subscription_id) do
      {:ok, %{"Entries" => entries}} when is_list(entries) ->
        changes =
          entries
          |> Enum.filter(fn entry ->
            case extract_path_and_value(entry) do
              {path, current} when is_number(current) ->
                baseline = Map.get(state.baseline_values, path)
                baseline != nil and abs(current - baseline) > @detection_threshold

              _ ->
                false
            end
          end)
          |> Enum.map(fn entry ->
            {path, current} = extract_path_and_value(entry)

            %{
              endpoint: path,
              control_name: extract_control_name(path),
              previous_value: Map.get(state.baseline_values, path),
              current_value: current
            }
          end)

        if changes != [] do
          {:changes_detected, changes}
        else
          :no_changes
        end

      {:ok, _response} ->
        :no_changes

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_path_and_value(%{"Path" => path, "Values" => values}) when is_map(values) do
    value = values |> Map.values() |> List.first()
    {path, value}
  end

  defp extract_path_and_value(_), do: nil

  defp extract_control_name(path) do
    # "CurrentDrivableActor/Horn.InputValue" -> "Horn"
    # "CurrentDrivableActor/Throttle(Lever).InputValue" -> "Throttle(Lever)"
    path
    |> String.replace("CurrentDrivableActor/", "")
    |> String.replace(".InputValue", "")
    |> String.split("/")
    |> List.last()
  end
end
