defmodule TswIo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        TswIoWeb.Telemetry,
        TswIo.Repo,
        {Ecto.Migrator,
         repos: Application.fetch_env!(:tsw_io, :ecto_repos), skip: skip_migrations?()},
        {DNSCluster, query: Application.get_env(:tsw_io, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: TswIo.PubSub},
        {Registry, keys: :unique, name: TswIo.Registry},
        TswIo.Serial.Connection,
        TswIo.Hardware.ConfigurationManager,
        TswIo.Hardware.Calibration.SessionSupervisor,
        TswIo.Train.Detection,
        TswIo.Train.Calibration.SessionSupervisor,
        # Start to serve requests, typically the last entry
        TswIoWeb.Endpoint
      ] ++ simulator_connection_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TswIo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TswIoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end

  # Returns the Simulator.Connection child spec only in non-test environments.
  # In test, this GenServer would interfere with the Ecto Sandbox since it
  # queries the database during initialization via AutoConfig.ensure_config/0.
  defp simulator_connection_child do
    if Application.get_env(:tsw_io, :start_simulator_connection, true) do
      [TswIo.Simulator.Connection]
    else
      []
    end
  end
end
