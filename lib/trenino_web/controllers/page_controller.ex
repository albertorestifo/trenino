defmodule TreninoWeb.PageController do
  use TreninoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
