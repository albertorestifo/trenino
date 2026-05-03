defmodule Trenino.PubSubHelpers do
  @moduledoc """
  Test-only helpers for synchronizing on Phoenix.PubSub state.

  Replaces `Process.sleep/1`-based race patterns where a test broadcasts
  to a topic and assumes a freshly-spawned subscriber is ready in time.
  """

  @registry Trenino.PubSub

  @doc """
  Block until at least one process is subscribed to `topic`, or the timeout
  expires.

  Returns `:ok` on success or `{:error, :timeout}`.

  ## Example

      task = Task.async(fn -> SomeGenServer.subscribe_and_wait() end)
      :ok = wait_for_subscriber("hardware:input_values:test_port")
      Phoenix.PubSub.broadcast(Trenino.PubSub, "hardware:input_values:test_port", :event)
      assert {:ok, _} = Task.await(task, 1_000)
  """
  @spec wait_for_subscriber(String.t(), pos_integer()) :: :ok | {:error, :timeout}
  def wait_for_subscriber(topic, timeout_ms \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait(topic, deadline)
  end

  defp do_wait(topic, deadline) do
    if has_subscriber?(topic) do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        {:error, :timeout}
      else
        Process.sleep(5)
        do_wait(topic, deadline)
      end
    end
  end

  defp has_subscriber?(topic) do
    case Registry.lookup(@registry, topic) do
      [] -> false
      [_ | _] -> true
    end
  end
end
