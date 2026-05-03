defmodule Trenino.Simulator do
  @moduledoc """
  Context for Train Sim World API simulator status and connection.

  Provides functions for accessing connection status and platform detection.
  Configuration (URL and API key) is now stored in `Trenino.Settings`.
  """

  alias Trenino.Settings.Simulator, as: SettingsSimulator
  alias Trenino.Simulator.Connection

  defdelegate windows?(), to: SettingsSimulator

  # Delegate connection operations to Connection module
  defdelegate subscribe(), to: Connection
  defdelegate get_status(), to: Connection
  defdelegate retry_connection(), to: Connection
end
