defmodule TreninoWeb.RedirectController do
  use TreninoWeb, :controller

  def simulator_config(conn, _params) do
    redirect(conn, to: ~p"/settings")
  end
end
