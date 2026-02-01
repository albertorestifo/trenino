defmodule Trenino.Simulator.ConnectionState do
  @moduledoc """
  Represents the state of a TSW API connection.

  This struct tracks the current connection status, any errors,
  and the API client instance when connected.
  """

  alias Trenino.Simulator.Client

  @type status :: :disconnected | :connecting | :connected | :error | :needs_config
  @type error_reason :: :invalid_key | :connection_failed | :timeout | term()

  @type t :: %__MODULE__{
          status: status(),
          client: Client.t() | nil,
          last_error: error_reason() | nil,
          last_check: DateTime.t() | nil,
          info: map() | nil,
          health_failures: non_neg_integer()
        }

  defstruct status: :needs_config,
            client: nil,
            last_error: nil,
            last_check: nil,
            info: nil,
            health_failures: 0

  @doc """
  Create a new connection state in needs_config status.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Mark the connection as connecting with a client instance.
  """
  @spec mark_connecting(t(), Client.t()) :: t()
  def mark_connecting(%__MODULE__{} = state, %Client{} = client) do
    %{state | status: :connecting, client: client, last_error: nil}
  end

  @doc """
  Mark the connection as connected with API info.
  """
  @spec mark_connected(t(), map()) :: t()
  def mark_connected(%__MODULE__{} = state, info) when is_map(info) do
    %{
      state
      | status: :connected,
        last_check: DateTime.utc_now(),
        last_error: nil,
        info: info,
        health_failures: 0
    }
  end

  @doc """
  Mark the connection as disconnected.
  """
  @spec mark_disconnected(t()) :: t()
  def mark_disconnected(%__MODULE__{} = state) do
    %{state | status: :disconnected, client: nil, last_check: nil, info: nil, health_failures: 0}
  end

  @doc """
  Mark the connection as needing configuration.
  """
  @spec mark_needs_config(t()) :: t()
  def mark_needs_config(%__MODULE__{} = state) do
    %{
      state
      | status: :needs_config,
        client: nil,
        last_error: nil,
        last_check: nil,
        info: nil,
        health_failures: 0
    }
  end

  @doc """
  Mark the connection as errored with a reason.
  """
  @spec mark_error(t(), error_reason()) :: t()
  def mark_error(%__MODULE__{} = state, reason) do
    %{
      state
      | status: :error,
        last_error: reason,
        last_check: DateTime.utc_now(),
        health_failures: 0
    }
  end

  @doc """
  Record a transient health check failure without changing connection status.

  Increments the health_failures counter and records the error/timestamp,
  but keeps the current status (typically :connected) unchanged.
  """
  @spec record_health_failure(t(), error_reason()) :: t()
  def record_health_failure(%__MODULE__{} = state, reason) do
    %{
      state
      | health_failures: state.health_failures + 1,
        last_error: reason,
        last_check: DateTime.utc_now()
    }
  end
end
