defmodule Trenino.Serial.Connection.State do
  @moduledoc """
  State for the Connection GenServer.

  Tracks all serial ports by name, regardless of their lifecycle state.
  This prevents race conditions by keeping ports tracked until cleanup
  is fully complete.
  """

  alias Trenino.Serial.Connection.DeviceConnection

  @typedoc """
  The process holding the upload token for `port`: Connection monitors `pid`
  (`monitor_ref`) and `request_ref` identifies the request that granted it.
  """
  @type upload_owner :: %{
          port: String.t(),
          pid: pid(),
          monitor_ref: reference(),
          request_ref: reference()
        }

  @type t :: %__MODULE__{
          ports: %{String.t() => DeviceConnection.t()},
          enumerate_failing?: boolean(),
          upload_owner: upload_owner() | nil
        }

  # enumerate_failing? is true while serial port enumeration keeps failing, so
  # the failure is logged once per streak instead of on every scan.
  defstruct ports: %{}, enumerate_failing?: false, upload_owner: nil

  @doc "Get a connection by port name"
  @spec get(t(), String.t()) :: DeviceConnection.t() | nil
  def get(%__MODULE__{ports: ports}, port), do: Map.get(ports, port)

  @doc "Put a connection into state"
  @spec put(t(), DeviceConnection.t()) :: t()
  def put(%__MODULE__{ports: ports} = state, %DeviceConnection{port: port} = conn) do
    %__MODULE__{state | ports: Map.put(ports, port, conn)}
  end

  @doc "Update a connection in state"
  @spec update(t(), String.t(), (DeviceConnection.t() -> DeviceConnection.t())) :: t()
  def update(%__MODULE__{ports: ports} = state, port, fun) do
    case Map.get(ports, port) do
      nil -> state
      conn -> %__MODULE__{state | ports: Map.put(ports, port, fun.(conn))}
    end
  end

  @doc "Remove a connection from state"
  @spec delete(t(), String.t()) :: t()
  def delete(%__MODULE__{ports: ports} = state, port) do
    %__MODULE__{state | ports: Map.delete(ports, port)}
  end

  @doc "Check if a port is being tracked (in any state)"
  @spec tracked?(t(), String.t()) :: boolean()
  def tracked?(%__MODULE__{ports: ports}, port), do: Map.has_key?(ports, port)

  @doc "Get all connected devices (status == :connected)"
  @spec connected_devices(t()) :: [DeviceConnection.t()]
  def connected_devices(%__MODULE__{ports: ports}) do
    ports
    |> Map.values()
    |> Enum.filter(&(&1.status == :connected))
  end
end
