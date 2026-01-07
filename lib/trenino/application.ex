defmodule Trenino.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        TreninoWeb.Telemetry,
        Trenino.Repo,
        {Ecto.Migrator,
         repos: Application.fetch_env!(:trenino, :ecto_repos), skip: skip_migrations?()},
        {DNSCluster, query: Application.get_env(:trenino, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Trenino.PubSub},
        {Registry, keys: :unique, name: Trenino.Registry},
        {Task.Supervisor, name: Trenino.TaskSupervisor},
        Trenino.Serial.Connection,
        Trenino.Hardware.ConfigurationManager,
        Trenino.Hardware.Calibration.SessionSupervisor,
        Trenino.Firmware.UploadManager,
        Trenino.Train.Detection,
        Trenino.Train.Calibration.SessionSupervisor,
        # Start to serve requests, typically the last entry
        TreninoWeb.Endpoint
      ] ++
        simulator_connection_child() ++
        lever_controller_child() ++
        button_controller_child() ++
        output_controller_child() ++
        update_checker_child() ++
        app_version_checker_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Trenino.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TreninoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # Skip migrations in dev/test (when not in a release).
    # Run migrations automatically when using a release (including Burrito desktop builds).
    # RELEASE_NAME is set by Mix releases, BURRITO is set by the Tauri sidecar launcher.
    System.get_env("RELEASE_NAME") == nil and System.get_env("BURRITO") == nil
  end

  # Returns the Simulator.Connection child spec only in non-test environments.
  # In test, this GenServer would interfere with the Ecto Sandbox since it
  # queries the database during initialization via AutoConfig.ensure_config/0.
  defp simulator_connection_child do
    if Application.get_env(:trenino, :start_simulator_connection, true) do
      [Trenino.Simulator.Connection]
    else
      []
    end
  end

  # Returns the LeverController child spec only in non-test environments.
  # In test, this GenServer subscribes to multiple pubsub topics and
  # interacts with other GenServers that may not be running.
  defp lever_controller_child do
    if Application.get_env(:trenino, :start_lever_controller, true) do
      [Trenino.Train.LeverController]
    else
      []
    end
  end

  # Returns the ButtonController child spec only in non-test environments.
  # In test, this GenServer subscribes to multiple pubsub topics and
  # interacts with other GenServers that may not be running.
  defp button_controller_child do
    if Application.get_env(:trenino, :start_button_controller, true) do
      [Trenino.Train.ButtonController]
    else
      []
    end
  end

  # Returns the OutputController child spec only in non-test environments.
  # In test, this GenServer subscribes to multiple pubsub topics and
  # interacts with other GenServers that may not be running.
  defp output_controller_child do
    if Application.get_env(:trenino, :start_output_controller, true) do
      [Trenino.Train.OutputController]
    else
      []
    end
  end

  # Returns the UpdateChecker child spec only in non-test environments.
  # In test, this GenServer performs automatic periodic checks and retains
  # state across tests, making it difficult to test in isolation. Tests that
  # need UpdateChecker can start it manually with proper setup/cleanup.
  defp update_checker_child do
    if Application.get_env(:trenino, :start_update_checker, true) do
      [Trenino.Firmware.UpdateChecker]
    else
      []
    end
  end

  # Returns the AppVersion.UpdateChecker child spec only in non-test environments.
  # In test, this GenServer performs automatic periodic checks that could
  # interfere with test isolation.
  defp app_version_checker_child do
    if Application.get_env(:trenino, :start_app_version_checker, true) do
      [Trenino.AppVersion.UpdateChecker]
    else
      []
    end
  end
end
