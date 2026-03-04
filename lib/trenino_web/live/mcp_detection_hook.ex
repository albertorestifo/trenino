defmodule TreninoWeb.MCPDetectionHook do
  @moduledoc """
  LiveView on_mount hook that subscribes to MCP detection events
  and renders a detection modal overlay.

  Add to your router's live_session:

      live_session :default, on_mount: [{TreninoWeb.MCPDetectionHook, :default}] do
        ...
      end

  Then render in your app layout:

      <TreninoWeb.MCPDetectionHook.detection_modal detection={assigns[:mcp_detection]} />
  """

  use Phoenix.Component
  import Phoenix.LiveView
  import TreninoWeb.CoreComponents, only: [icon: 1]

  @detection_topic "mcp:detection"

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Trenino.PubSub, @detection_topic)
    end

    socket =
      socket
      |> assign(:mcp_detection, nil)
      |> attach_hook(:mcp_detection, :handle_info, &handle_mcp_detection/2)

    {:cont, socket}
  end

  defp handle_mcp_detection({:detection_request, request}, socket) do
    {:halt, assign(socket, :mcp_detection, request)}
  end

  defp handle_mcp_detection({:detection_complete, _id}, socket) do
    {:halt, assign(socket, :mcp_detection, nil)}
  end

  defp handle_mcp_detection(_msg, socket) do
    {:cont, socket}
  end

  attr :detection, :map, default: nil

  def detection_modal(assigns) do
    ~H"""
    <div
      :if={@detection}
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
    >
      <div class="absolute inset-0 bg-black/50" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold flex items-center gap-2">
              <.icon name="hero-cpu-chip" class="w-5 h-5 text-primary" />
              <span :if={@detection.type == :hardware}>Hardware Detection</span>
              <span :if={@detection.type == :simulator}>Simulator Detection</span>
            </h2>
            <span class="badge badge-sm badge-primary">MCP</span>
          </div>
        </div>

        <div class="p-6 text-center space-y-4">
          <div class="relative">
            <span class="loading loading-ring loading-lg text-primary"></span>
          </div>
          <div>
            <h3 class="font-semibold text-lg">Listening...</h3>
            <p class="text-sm text-base-content/60 mt-2">
              {@detection.prompt}
            </p>
          </div>
          <p :if={@detection.type == :hardware} class="text-xs text-base-content/40">
            Press a button or move a lever on your hardware controller
          </p>
          <p :if={@detection.type == :simulator} class="text-xs text-base-content/40">
            Interact with a control in Train Sim World
          </p>
        </div>
      </div>
    </div>
    """
  end
end
