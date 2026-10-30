defmodule TreninoWeb.StepperCommissioningComponent do
  @moduledoc "Explicit manual commissioning. No events are generated on mount or form change."
  use TreninoWeb, :live_component
  alias Trenino.Hardware.StepperManager
  alias TreninoWeb.GaugeFeedback

  @operations %{
    "home" => :home,
    "stop" => :stop,
    "release" => :release,
    "enable" => :enable,
    "reference" => :reference,
    "move_to" => :move_to,
    "jog" => :jog
  }
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:token, fn -> nil end)
     |> assign_new(:message, fn -> nil end)}
  end

  @impl true
  def handle_event("claim", _, socket) do
    case StepperManager.claim_manual(socket.assigns.axis.id, self()) do
      {:ok, token} ->
        {:noreply,
         assign(socket,
           token: token,
           message: "Manual control taken; automatic output remains paused until Resume."
         )}

      error ->
        {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  def handle_event("resume", _, socket) do
    if socket.assigns.token,
      do: StepperManager.release_manual(socket.assigns.axis.id, socket.assigns.token)

    result = StepperManager.resume(socket.assigns.axis.id)
    {:noreply, assign(socket, token: nil, message: GaugeFeedback.result(result))}
  end

  def handle_event("recover", _, socket) do
    result = StepperManager.recover(socket.assigns.axis.device_id)

    {:noreply,
     assign(socket,
       token: nil,
       message: "Recovery requires a fresh reference. #{GaugeFeedback.result(result)}"
     )}
  end

  def handle_event("command", params, socket) do
    with op when not is_nil(op) <- @operations[params["op"]],
         {:ok, args} <- arguments(op, params),
         true <- socket.assigns.token != nil do
      result = StepperManager.command(socket.assigns.axis.id, op, args, socket.assigns.token)

      {:noreply,
       assign(
         socket,
         :message,
         GaugeFeedback.result(result)
       )}
    else
      _ ->
        {:noreply,
         assign(socket, :message, "Take manual control and enter a valid integer position first.")}
    end
  end

  def handle_event("complete", _, socket) do
    case StepperManager.complete_commissioning(socket.assigns.axis.id, socket.assigns.token) do
      {:ok, axis} ->
        send(self(), {:stepper_axis_saved, axis})
        {:noreply, assign(socket, :message, "Physical commissioning recorded.")}

      error ->
        {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
    end
  end

  defp arguments(op, params) when op in [:reference, :move_to, :jog] do
    key = if op == :jog, do: :delta, else: :position

    case parse_position(Map.get(params, "position", "")) do
      {n, ""} -> {:ok, %{key => n}}
      _ -> {:error, :invalid_position}
    end
  end

  defp arguments(_, _), do: {:ok, %{}}
  defp parse_position(value) when is_binary(value), do: Integer.parse(value)
  defp parse_position(_), do: :error
  @impl true
  def render(assigns) do
    a = assigns.snapshot.axes[assigns.axis.id]
    assigns = assign(assigns, :runtime, a)

    ~H"""
    <div id={@id} class="space-y-3 pt-3">
      <p class="font-medium">{Phoenix.Naming.humanize(@snapshot.lifecycle)}</p>
      <p :if={@runtime && @runtime.status} class="text-sm">
        {@runtime.status.state} · estimated position: {if @runtime.status.known,
          do: @runtime.status.position,
          else: "unavailable"} · target: {if @runtime.status.known,
          do: @runtime.status.target,
          else: "unavailable"} · energized: {@runtime.status.energized} · fault: {@runtime.status.fault}
      </p>
      <p
        :if={
          @runtime && @runtime.status && @runtime.status.known &&
            @runtime.status.reference_kind == :assumed_stop
        }
        class="text-sm"
      >
        Assumed internal-stop reference
      </p>
      <p :if={@runtime && @runtime.pending} class="text-sm">
        Pending {@runtime.pending.command.operation}; waiting for firmware acknowledgement.
      </p>
      <p :if={@runtime && @runtime.error} role="alert">{GaugeFeedback.error(@runtime.error)}</p>
      <p :if={@message} role="status" class="text-sm">{@message}</p>
      <div class="flex flex-wrap gap-2">
        <button
          id={"stepper-claim-#{@axis.id}"}
          type="button"
          phx-click="claim"
          phx-target={@myself}
          class="btn btn-sm"
          disabled={@snapshot.lifecycle == :disconnected}
        >Take manual control</button>
        <button
          :for={op <- ["stop", "release", "enable"]}
          id={"stepper-#{op}-#{@axis.id}"}
          type="button"
          phx-click="command"
          phx-value-op={op}
          phx-target={@myself}
          class="btn btn-sm"
          disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
        >{Phoenix.Naming.humanize(op)}</button>
        <button
          :if={@axis.reference_strategy == :internal_stop}
          id={"stepper-home-#{@axis.id}"}
          type="button"
          phx-click="command"
          phx-value-op="home"
          phx-target={@myself}
          class="btn btn-sm"
          disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
        >Home (bounded, assumed stop)</button>
        <button
          id={"stepper-resume-#{@axis.id}"}
          disabled={@snapshot.lifecycle == :disconnected}
          type="button"
          phx-click="resume"
          phx-target={@myself}
          class="btn btn-sm"
        >Resume train control</button>
        <button
          type="button"
          phx-click="recover"
          phx-target={@myself}
          class="btn btn-sm"
          disabled={@snapshot.lifecycle == :disconnected}
        >Recover configuration</button>
      </div>
      <.form
        for={to_form(%{})}
        id={"stepper-reference-#{@axis.id}"}
        phx-submit="command"
        phx-target={@myself}
        class="flex gap-2 items-end"
      >
        <.input
          name="position"
          value="0"
          label="Physically aligned reference / target position"
          type="number"
        />
        <button
          :if={@axis.reference_strategy == :host_reference}
          name="op"
          value="reference"
          class="btn btn-sm"
          disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
        >Assign reference</button>
        <button
          name="op"
          value="move_to"
          class="btn btn-sm"
          disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
        >Move to target</button>
      </.form>
      <div class="flex gap-2">
        <button
          :for={n <- [-10, -1, 1, 10]}
          type="button"
          phx-click="command"
          phx-value-op="jog"
          phx-value-position={n}
          phx-target={@myself}
          class="btn btn-sm"
          disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
        >Jog {n}</button>
      </div>
      <button
        type="button"
        phx-click="complete"
        phx-target={@myself}
        class="btn btn-sm"
        disabled={is_nil(@token) or @snapshot.lifecycle == :disconnected}
      >I physically verified direction, travel and reference — complete commissioning</button>
    </div>
    """
  end
end
