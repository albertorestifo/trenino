defmodule TreninoWeb.ConsentGateHook do
  @moduledoc """
  LiveView `on_mount` hook that redirects to `/consent` until the
  user has explicitly chosen whether to share error reports.
  """

  import Phoenix.LiveView

  alias Trenino.Settings

  def on_mount(:default, _params, _session, socket) do
    if Settings.error_reporting_set?() do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/consent")}
    end
  end
end
