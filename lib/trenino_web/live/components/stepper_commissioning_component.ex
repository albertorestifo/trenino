defmodule TreninoWeb.StepperCommissioningComponent do
  @moduledoc """
  The body of one stepper axis card: one reason, at most one primary action and Stop while
  the needle moves. Manual controls live in the Diagnostics panel, shown only on request.
  No events are generated on mount or form change.
  """
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
     |> assign_new(:diagnostics, fn -> false end)
     |> assign_new(:message, fn -> nil end)}
  end

  @impl true
  def handle_event("rezero", params, socket) do
    result =
      StepperManager.rezero(socket.assigns.axis.id, aligned: params["aligned"] == "true")

    {:noreply, assign(socket, token: nil, message: rezero_message(result))}
  end

  def handle_event("claim", _, socket) do
    case StepperManager.claim_manual(socket.assigns.axis.id, self()) do
      {:ok, token} ->
        {:noreply,
         assign(socket,
           token: token,
           message: "Manual control taken; train output stays paused until you resume it."
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
       message: "Recovery needs a fresh zero. #{GaugeFeedback.result(result)}"
     )}
  end

  def handle_event("command", params, socket) do
    with op when not is_nil(op) <- @operations[params["op"]],
         {:ok, args} <- arguments(op, params),
         true <- socket.assigns.token != nil do
      result = StepperManager.command(socket.assigns.axis.id, op, args, socket.assigns.token)
      {:noreply, assign(socket, :message, GaugeFeedback.result(result))}
    else
      _ ->
        {:noreply,
         assign(socket, :message, "Take manual control and enter a valid integer position first.")}
    end
  end

  # Stop must be one click away even when this page does not hold manual control (a needle
  # driven by a train). It uses the same guarded claim, then the same guarded stop command;
  # the axis stays paused until the operator resumes it. A token revoked behind our back
  # (reconnect, fault, Re-zero) is dropped and the claim is taken again.
  def handle_event("stop_now", _, socket) do
    id = socket.assigns.axis.id

    {token, result} =
      with token when not is_nil(token) <- socket.assigns.token,
           {:error, :invalid_lease} <- StepperManager.command(id, :stop, %{}, token) do
        claim_and_stop(id)
      else
        nil -> claim_and_stop(id)
        result -> {socket.assigns.token, result}
      end

    {:noreply, assign(socket, token: token, message: GaugeFeedback.result(result))}
  end

  defp claim_and_stop(id) do
    case StepperManager.claim_manual(id, self()) do
      {:ok, token} -> {token, StepperManager.command(id, :stop, %{}, token)}
      error -> {nil, error}
    end
  end

  defp rezero_message({:ok, :reconfigured}),
    do: "Controller reconfigured. Line the needle up on 0 by hand, then confirm."

  defp rezero_message({:ok, :recovering}),
    do: "Reconfiguring the controller. The needle zeroes itself once it is ready."

  defp rezero_message({:ok, :resumed}), do: "Train output resumed."
  defp rezero_message({:ok, _}), do: "Re-zeroing. Train output resumes when it is done."
  defp rezero_message(error), do: GaugeFeedback.result(error)

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
    status = GaugeGuidance.axis_status(assigns.axis, assigns.snapshot)

    assigns =
      assigns
      |> assign(:runtime, runtime)
      |> assign(:status, status)
      |> assign(:offline, assigns.snapshot.lifecycle == :disconnected)
      |> assign(:show_stop, assigns.token != nil or GaugeGuidance.moving?(runtime))
      |> assign(
        :align_by_hand,
        status.state == :needs_rezero and assigns.axis.reference_strategy == :host_reference
      )

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
      <p :if={@message} role="status" class="text-sm">{@message}</p>
      <p :if={@token && @runtime && @runtime.lease} class="text-sm font-medium">
        You have manual control. Train output is paused until you resume it.
      </p>

      <div :if={@show_stop or @status.primary} class="flex flex-wrap gap-2">
        <button
          :if={@status.primary == :wizard}
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
          :if={@status.primary in [:rezero, :resume]}
          id={"stepper-rezero-#{@axis.id}"}
          type="button"
          phx-click="rezero"
          phx-value-aligned={to_string(@align_by_hand)}
          phx-target={@myself}
          class="btn btn-primary"
          disabled={@offline}
        >
          {rezero_label(@status.primary, @align_by_hand)}
        </button>
        <button
          :if={@token}
          id={"stepper-handback-#{@axis.id}"}
          type="button"
          phx-click="resume"
          phx-target={@myself}
          class="btn btn-primary"
          disabled={@offline}
        >
          Resume train output
        </button>
        <.stop_button
          :if={@show_stop}
          axis={@axis}
          token={@token}
          myself={@myself}
          offline={@offline}
        />
      </div>

      <section
        :if={@diagnostics}
        id={"stepper-diagnostics-#{@axis.id}"}
        aria-label={"Diagnostics for #{@axis.name}"}
        class="space-y-3 rounded-lg border border-base-300 p-3"
      >
        <div>
          <h5 class="text-sm font-medium">Diagnostics</h5>
          <p class="text-xs text-muted">
            For troubleshooting. Taking manual control pauses train output until you resume it.
          </p>
        </div>
        <p :if={@runtime && @runtime.status} class="text-xs font-mono">
          {@runtime.status.state} · position {if @runtime.status.known,
            do: @runtime.status.position,
            else: "unknown"} · target {if @runtime.status.known,
            do: @runtime.status.target,
            else: "unknown"} · energized {@runtime.status.energized}<span :if={
            @runtime.status.fault != :none
          }> · fault {GaugeFeedback.fault(@runtime.status.fault)}</span>
        </p>
        <p :if={@runtime && @runtime.pending} class="text-xs text-muted">
          Waiting for the device to confirm {@runtime.pending.command.operation}.
        </p>
        <p :if={@runtime && @runtime.error} role="alert" class="text-sm text-error">
          {GaugeFeedback.error(@runtime.error)}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            id={"stepper-claim-#{@axis.id}"}
            type="button"
            phx-click="claim"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={@offline or @token != nil}
          >
            Take manual control
          </button>
          <button
            id={"stepper-resume-#{@axis.id}"}
            type="button"
            phx-click="resume"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={@offline}
          >
            Resume train control
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
            Home
          </button>
          <button
            id={"stepper-recover-#{@axis.id}"}
            type="button"
            phx-click="recover"
            phx-target={@myself}
            class="btn btn-sm"
            disabled={@offline}
          >
            Reconfigure device
          </button>
        </div>
        <.form
          for={to_form(%{})}
          id={"stepper-reference-#{@axis.id}"}
          phx-submit="command"
          phx-target={@myself}
          class="flex flex-wrap items-end gap-2"
        >
          <.input name="position" value="0" label="Position" type="number" />
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
            Move to
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
      </section>
    </div>
    """
  end

  defp rezero_label(:resume, _), do: "Resume train output"
  defp rezero_label(_, true), do: "The needle is on 0"
  defp rezero_label(_, false), do: "Re-zero"

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
      phx-click="stop_now"
      phx-target={@myself}
      class={["btn btn-neutral", @size]}
      disabled={@offline or (@gated and is_nil(@token))}
    >
      <.icon name="hero-stop-solid" class="size-4" /> Stop
    </button>
    """
  end
end
