defmodule TreninoWeb.ConsentLive do
  @moduledoc """
  First-run gate that asks the user whether to share Sentry error
  reports. Reachable from `/consent` and required before any other
  route renders.
  """

  use TreninoWeb, :live_view

  alias Trenino.Settings

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket, layout: false}

  @impl true
  def handle_event("accept", _params, socket) do
    {:ok, _} = Settings.set_error_reporting(:enabled)
    {:noreply, redirect(socket, to: "/")}
  end

  @impl true
  def handle_event("decline", _params, socket) do
    {:ok, _} = Settings.set_error_reporting(:disabled)
    {:noreply, redirect(socket, to: "/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 p-4">
      <div class="card max-w-md w-full bg-base-100 shadow-xl">
        <div class="card-body items-center text-center">
          <div class="rounded-full bg-primary/10 p-3 mb-2">
            <.icon name="hero-shield-check" class="w-8 h-8 text-primary" />
          </div>
          <h2 class="card-title text-lg">Help improve Trenino</h2>
          <p class="text-sm text-base-content/70">
            Share anonymous error reports so bugs can be found and fixed faster. No personal data, no usage tracking — only crash reports.
          </p>
          <div class="card-actions w-full flex flex-col gap-2 mt-4">
            <button phx-click="accept" class="btn btn-primary w-full">
              Share error reports
            </button>
            <button phx-click="decline" class="btn btn-ghost w-full">
              No thanks
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
