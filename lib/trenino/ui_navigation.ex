defmodule Trenino.UINavigation do
  @moduledoc """
  Lets the MCP server move open Trenino windows to a page, so the AI can hand
  the user over to the right screen (for example the lever wizard's notch
  mapping step).

  Every LiveView subscribes through `TreninoWeb.MCPDetectionHook`. A request
  is broadcast to all of them; each one acknowledges and navigates.
  """

  @topic "ui:navigate"
  @default_timeout_ms 500

  @doc "Subscribes the calling process to navigation requests."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Trenino.PubSub, @topic)

  @doc """
  Asks open windows to navigate to `path`.

  Returns `:ok` when at least one window acknowledged within the timeout, or
  `{:error, :no_window}` when none did (Trenino is not open in a window).
  """
  @spec request(String.t(), non_neg_integer()) :: :ok | {:error, :no_window}
  def request(path, timeout \\ @default_timeout_ms) when is_binary(path) do
    ref = make_ref()
    Phoenix.PubSub.broadcast(Trenino.PubSub, @topic, {:ui_navigate, path, self(), ref})

    receive do
      {:ui_navigate_ack, ^ref} -> :ok
    after
      timeout -> {:error, :no_window}
    end
  end

  @doc "Acknowledges a request; called by the window that received it."
  @spec ack(pid(), reference()) :: :ok
  def ack(from, ref) do
    send(from, {:ui_navigate_ack, ref})
    :ok
  end
end
