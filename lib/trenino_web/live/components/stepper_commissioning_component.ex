defmodule TreninoWeb.StepperCommissioningComponent do
  @moduledoc "Explicit manual commissioning. No events are generated on mount or form change."
  use TreninoWeb, :live_component
  alias Trenino.Hardware.StepperManager
  alias TreninoWeb.{GaugeFeedback, GaugeGuidance}

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
     |> assign_new(:apply_needed, fn -> false end)
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

  # Stop must be one click away even when this page does not hold manual control (a needle
  # driven by a train). It uses the same guarded claim, then the same guarded stop command;
  # the axis stays paused until the operator chooses Resume train control.
  def handle_event("stop_now", _, socket) do
    id = socket.assigns.axis.id

    claimed =
      case socket.assigns.token do
        nil -> StepperManager.claim_manual(id, self())
        token -> {:ok, token}
      end

    case claimed do
      {:ok, token} ->
        result = StepperManager.command(id, :stop, %{}, token)
        {:noreply, assign(socket, token: token, message: GaugeFeedback.result(result))}

      error ->
        {:noreply, assign(socket, :message, GaugeFeedback.result(error))}
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
    runtime = assigns.snapshot.axes[assigns.axis.id]

    status =
      GaugeGuidance.axis_status(
        assigns.axis,
        assigns.snapshot,
        assigns.token != nil,
        assigns.apply_needed
      )

    assigns =
      assigns
      |> assign(:runtime, runtime)
      |> assign(:status, status)
      |> assign(:glossary, GaugeGuidance.glossary())
      |> assign(:offline, assigns.snapshot.lifecycle == :disconnected)
      |> assign(:show_stop, assigns.token != nil or GaugeGuidance.moving?(runtime))
      |> assign(:promote_resume, assigns.token != nil or status.primary == :resume)
      |> assign(:promote_recover, status.primary == :recover)
      |> assign(:promote_wizard, status.primary == :wizard)

    ~H"""
    <div id={@id} class="space-y-3">
      <p
        :if={@status.reason}
        id={"stepper-next-step-#{@axis.id}"}
        role={if @status.state == :fault, do: "alert"}
        class="text-sm text-base-content/80"
      >
        {@status.reason}
      </p>
      <p :if={@runtime && @runtime.pending} class="text-sm text-muted">
        Waiting for the device to confirm {@runtime.pending.command.operation}.
      </p>
      <p :if={@runtime && @runtime.error} role="alert" class="text-sm text-error">
        {GaugeFeedback.error(@runtime.error)}
      </p>
      <p :if={@message} role="status" class="text-sm">{@message}</p>
      <p :if={@token} class="text-sm font-medium">
        You have manual control. Train output is paused until you resume it.
      </p>

      <div
        :if={@show_stop or @promote_resume or @promote_recover or @promote_wizard}
        class="flex flex-wrap gap-2"
      >
        <button
          :if={@promote_wizard}
          id={"stepper-wizard-open-#{@axis.id}"}
          type="button"
          phx-click="open_wizard"
          phx-value-id={@axis.id}
          phx-target={@wizard_target}
          class="btn btn-primary"
        >
          Set up gauge
        </button>
        <button
          :if={@promote_recover}
          id={"stepper-recover-#{@axis.id}"}
          type="button"
          phx-click="recover"
          phx-target={@myself}
          class="btn btn-primary"
        >
          Recover configuration
        </button>
        <button
          :if={@promote_resume}
          id={"stepper-resume-#{@axis.id}"}
          type="button"
          phx-click="resume"
          phx-target={@myself}
          class={[
            "btn",
            @status.state == :paused && "btn-primary",
            @status.state != :paused && "btn-soft"
          ]}
          disabled={@offline}
        >
          Resume train control
        </button>
        <.stop_button
          :if={@show_stop}
          axis={@axis}
          token={@token}
          myself={@myself}
          offline={@offline}
        />
      </div>

      <.disclosure id={"stepper-advanced-#{@axis.id}"} summary="Advanced / manual controls">
        <p :for={{term, meaning} <- @glossary} class="text-xs text-muted">
          <span class="font-medium">{term}</span> is {meaning}
        </p>
        <p :if={@runtime && @runtime.status} class="text-sm">
          {@runtime.status.state} · estimated position: {if @runtime.status.known,
            do: @runtime.status.position,
            else: "unavailable"} · target: {if @runtime.status.known,
            do: @runtime.status.target,
            else: "unavailable"} · energized: {@runtime.status.energized}<span :if={
            @runtime.status.fault != :none
          }> · fault: {GaugeFeedback.fault(@runtime.status.fault)}</span>
          <span :if={@runtime.status.known and @runtime.status.reference_kind == :assumed_stop}>
            · assumed internal-stop reference
          </span>
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            id={"stepper-claim-#{@axis.id}"}
            type="button"
            phx-click="claim"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={@offline}
          >
            Take manual control
          </button>
          <.stop_button
            :if={not @show_stop}
            axis={@axis}
            token={@token}
            myself={@myself}
            offline={@offline}
            size="btn-sm"
            gated
          />
          <button
            :for={op <- ["release", "enable"]}
            id={"stepper-#{op}-#{@axis.id}"}
            type="button"
            phx-click="command"
            phx-value-op={op}
            phx-target={@myself}
            class="btn btn-sm"
            disabled={is_nil(@token) or @offline}
          >
            {Phoenix.Naming.humanize(op)}
          </button>
          <button
            :if={@axis.reference_strategy == :internal_stop}
            id={"stepper-home-#{@axis.id}"}
            type="button"
            phx-click="command"
            phx-value-op="home"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={is_nil(@token) or @offline}
          >
            Home (bounded, assumed stop)
          </button>
          <button
            :if={not @promote_resume}
            id={"stepper-resume-#{@axis.id}"}
            disabled={@offline}
            type="button"
            phx-click="resume"
            phx-target={@myself}
            class="btn btn-sm"
          >
            Resume train control
          </button>
          <button
            :if={not @promote_recover}
            id={"stepper-recover-#{@axis.id}"}
            type="button"
            phx-click="recover"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={@offline}
          >
            Recover configuration
          </button>
        </div>
        <.form
          for={to_form(%{})}
          id={"stepper-reference-#{@axis.id}"}
          phx-submit="command"
          phx-target={@myself}
          class="flex flex-wrap items-end gap-2"
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
            class="btn btn-sm mb-2"
            disabled={is_nil(@token) or @offline}
          >
            Assign reference
          </button>
          <button
            name="op"
            value="move_to"
            class="btn btn-sm mb-2"
            disabled={is_nil(@token) or @offline}
          >
            Move to target
          </button>
        </.form>
        <div class="flex flex-wrap gap-2">
          <button
            :for={n <- [-10, -1, 1, 10]}
            type="button"
            phx-click="command"
            phx-value-op="jog"
            phx-value-position={n}
            phx-target={@myself}
            class="btn btn-sm"
            disabled={is_nil(@token) or @offline}
          >
            Jog {n}
          </button>
        </div>
        <button
          type="button"
          phx-click="complete"
          phx-target={@myself}
          class="btn btn-sm"
          disabled={is_nil(@token) or @offline}
        >
          I physically verified direction, travel and reference — complete commissioning
        </button>
      </.disclosure>
    </div>
    """
  end

  attr :axis, :any, required: true
  attr :token, :any, default: nil
  attr :myself, :any, required: true
  attr :offline, :boolean, default: false
  attr :size, :string, default: nil
  attr :gated, :boolean, default: false

  # Stop is the one control that is never hidden while the needle moves or the operator
  # holds the axis. Without manual control it takes it first (see `stop_now`).
  defp stop_button(assigns) do
    ~H"""
    <button
      id={"stepper-stop-#{@axis.id}"}
      type="button"
      phx-click={if @token, do: "command", else: "stop_now"}
      phx-value-op="stop"
      phx-target={@myself}
      class={["btn btn-neutral", @size]}
      disabled={@offline or (@gated and is_nil(@token))}
    >
      <.icon name="hero-stop-solid" class="size-4" /> Stop
    </button>
    """
  end
end
