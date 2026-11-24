defmodule TreninoWeb.RedirectController do
  use TreninoWeb, :controller

  alias Trenino.Beta
  alias Trenino.Settings

  # The connection page of the simulator Trenino connects to.
  def simulator_config(conn, _params) do
    simulator = if Beta.enabled?(:simrail), do: Settings.simulator(), else: :tsw
    redirect(conn, to: ~p"/settings/simulators/#{simulator}")
  end
end
