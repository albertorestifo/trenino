defmodule TreninoWeb.GaugeWizardComponent do
  @moduledoc """
  Guided setup of one stepper gauge, from a freshly wired motor to a working speedometer.

  The component is a thin shell: all decisions live in `Trenino.Hardware.GaugeWizard`
  (a pure state machine) and every hardware or database action goes through
  `Trenino.Hardware.GaugeWizard.Runner`. This module only turns clicks into wizard events,
  runs the effects the wizard asks for, and renders the current step in plain language.

  ## API

      <.live_component
        module={TreninoWeb.GaugeWizardComponent}
        id={"gauge-wizard-\#{axis.id}"}
        axis={axis}
        snapshot={snapshot}
      />

    * `axis` (required) - the `%Trenino.Hardware.StepperAxis{}`; only its id is trusted.
    * `snapshot` (optional) - changes whenever the parent receives a device update. It is
      only a trigger: the wizard always re-reads the authoritative status itself.

  Sent to the parent LiveView: `{:stepper_axis_saved, axis}` after an axis setting changes,
  `{:dial_calibration_saved, calibration}` after the dial is saved and
  `{:gauge_wizard_closed, axis_id}` when the wizard is closed.

  Leaving the wizard (Close, or finishing) stops the axis, hands manual control back and,
  when the axis is commissioned, resumes train control. Manual control is held by the
  LiveView process, so it is dropped automatically if the page goes away.
  """
  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Hardware.GaugeWizard
  alias Trenino.Hardware.GaugeWizard.Runner
  alias Trenino.Train
  alias TreninoWeb.{DialCalibrationComponent, GaugeFeedback}

  @nudges [-20, -5, -1, 1, 5, 20]
  @max_rounds 8

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, id: assigns.id, axis_id: assigns.axis.id)

    socket =
      if Map.has_key?(socket.assigns, :wizard),
        do: socket,
        else: assign(socket, :wizard, new_wizard(assigns.axis))

    {:ok, socket |> assign(:snapshot, Map.get(assigns, :snapshot)) |> sync()}
  end

  defp new_wizard(axis) do
    {:ok, fresh} = Hardware.get_stepper_axis(axis.id)
    GaugeWizard.new(fresh, Hardware.allcall_warning(fresh.device_id))
  end

  # ---------------------------------------------------------------- events

  @impl true
  def handle_event("wiring", params, socket),
    do: {:noreply, dispatch(socket, {:confirm_wiring, params["wiring"] == "true"})}

  def handle_event("act", %{"do" => action}, socket) do
    case action_event(action) do
      nil -> {:noreply, socket}
      event -> {:noreply, dispatch(socket, event)}
    end
  end

  def handle_event("answer", %{"value" => value}, socket) when value in ["yes", "no"],
    do: {:noreply, dispatch(socket, {:answer, String.to_existing_atom(value)})}

  def handle_event("nudge", %{"delta" => delta}, socket) do
    case Integer.parse(delta) do
      {n, ""} -> {:noreply, dispatch(socket, {:nudge, n})}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("set_range", %{"range" => params}, socket),
    do: {:noreply, dispatch(socket, {:set_range, params})}

  def handle_event("capture", %{"reading" => reading}, socket),
    do: {:noreply, dispatch(socket, {:capture, reading})}

  def handle_event("rename", %{"name" => name}, socket),
    do: {:noreply, dispatch(socket, {:rename, name})}

  def handle_event("startup", params, socket),
    do: {:noreply, dispatch(socket, {:startup_on_connect, params["startup"] == "true"})}

  def handle_event("close", _, socket) do
    socket = dispatch(socket, :close)
    send(self(), {:gauge_wizard_closed, socket.assigns.axis_id})
    {:noreply, socket}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  @actions %{
    "continue" => :continue,
    "apply" => :apply,
    "fix_idle_hold" => :fix_idle_hold,
    "set_reference" => :set_reference,
    "home" => :home,
    "jog_up" => :jog_up,
    "extend_max" => :extend_max,
    "save_dial" => :save_dial,
    "restart_calibration" => :restart_calibration,
    "start_homing" => :start_homing,
    "skip_homing" => :skip_homing,
    "finish_nudging" => :finish_nudging,
    "commission" => :commission,
    "stop" => :stop,
    "recover" => :recover,
    "retry_claim" => :retry_claim
  }
  defp action_event(action), do: Map.get(@actions, action)

  # ---------------------------------------------------------------- running effects

  defp dispatch(socket, event) do
    wizard = socket.assigns.wizard
    {wizard, effects} = GaugeWizard.update(wizard, event)
    socket |> assign(:wizard, wizard) |> run(effects, @max_rounds) |> sync()
  end

  # Observe the authoritative status and let the wizard react (it may ask for more effects).
  defp sync(socket) do
    wizard = socket.assigns.wizard
    {wizard, effects} = GaugeWizard.update(wizard, {:observed, Runner.observe(wizard)})
    socket |> assign(:wizard, wizard) |> run(effects, @max_rounds)
  end

  defp run(socket, _effects, 0), do: socket
  defp run(socket, [], _rounds), do: socket

  defp run(socket, effects, rounds) do
    {wizard, more} =
      Enum.reduce(effects, {socket.assigns.wizard, []}, fn effect, {wizard, acc} ->
        {:result, ^effect, result} = event = Runner.run(effect, wizard)
        notify(effect, result)
        {wizard, effects} = GaugeWizard.update(wizard, event)
        {wizard, acc ++ effects}
      end)

    wizard = observe_after_effects(wizard)
    socket |> assign(:wizard, elem(wizard, 0)) |> run(more ++ elem(wizard, 1), rounds - 1)
  end

  defp observe_after_effects(wizard),
    do: GaugeWizard.update(wizard, {:observed, Runner.observe(wizard)})

  defp notify({:update_axis, _}, {:ok, axis}), do: send(self(), {:stepper_axis_saved, axis})
  defp notify({:save_dial, _}, {:ok, cal}), do: send(self(), {:dial_calibration_saved, cal})
  defp notify(:complete_commissioning, {:ok, axis}), do: send(self(), {:stepper_axis_saved, axis})
  defp notify(_, _), do: :ok

  # ---------------------------------------------------------------- copy

  @doc false
  def error_text(nil), do: nil
  def error_text(:prerequisites_missing), do: "Finish the checklist above first."
  def error_text(:busy), do: "Wait for the needle to stop moving, or press Stop."

  def error_text({:lease_held, %{owner: :mcp}}),
    do:
      "An AI assistant is controlling this gauge right now. Ask it to finish, wait a minute, then try again."

  def error_text({:lease_held, _}),
    do:
      "Manual control is already open elsewhere on this page. Use Resume train control in the axis controls, then try again."

  def error_text(:owned), do: "Another session is controlling this gauge. Close it there first."

  def error_text(:outside_limits),
    do: "That would move the needle past the end of its allowed travel."

  def error_text(:invalid_range),
    do: "Enter a lowest and highest dial value (lowest below highest) and a unit."

  def error_text(:invalid_number), do: "Enter a number."

  def error_text(:value_not_increasing),
    do: "Each mark must be a higher dial value than the one before."

  def error_text(:needle_not_advanced),
    do: "The needle is not further along than the previous mark. Nudge it up to the mark first."

  def error_text(:not_nudged), do: "Nudge the needle up to the 0 mark first."

  def error_text(:sweep_too_long),
    do: "This travel is too long for a safe automatic sweep. Skip automatic homing."

  def error_text(:mid_mark_off),
    do: "The dial is a little off. Measure the marks again more carefully."

  def error_text(:invalid_lease),
    do: "Control of the gauge was reset. Trenino is taking it back; try again in a moment."

  def error_text(:needs_apply), do: "Send the settings to the controller first."
  def error_text(%Ecto.Changeset{} = cs), do: changeset_text(cs)
  def error_text(reason), do: GaugeFeedback.error(reason)

  defp changeset_text(%Ecto.Changeset{errors: [{field, {message, _}} | _]}),
    do: "Could not save: #{Phoenix.Naming.humanize(field)} #{message}."

  defp changeset_text(_), do: "Could not save that change."

  defp step_name(:mark), do: "measuring the dial"
  defp step_name(:jog_test), do: "the direction check"
  defp step_name(:verify_zero), do: "the check at zero"
  defp step_name(:verify_mid), do: "the check at a middle mark"
  defp step_name(:home_nudge), do: "the zero adjustment"
  defp step_name(:home_confirm), do: "the homing check"
  defp step_name(:save_dial), do: "saving the dial"
  defp step_name(:finish), do: "the final confirmation"
  defp step_name(_), do: "setup"

  defp unit_label(:raw), do: ""
  defp unit_label(:mps), do: "m/s"
  defp unit_label(:kmh), do: "km/h"
  defp unit_label(:mph), do: "mph"
  defp unit_label(nil), do: ""

  defp format_value(value) when is_float(value),
    do:
      value
      |> Float.round(2)
      |> :erlang.float_to_binary(decimals: 2)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")

  defp format_value(value), do: to_string(value)

  defp prerequisite_text(:device), do: "Plug the controller into this computer with USB."
  defp prerequisite_text(:firmware), do: "Update the controller firmware to 3.1.0 or newer."
  defp prerequisite_text(:applied), do: "Send the saved axis settings to the controller."

  defp prerequisite_text(:idle_hold),
    do: "Keep the motor powered when idle so the needle holds its place."

  defp prerequisite_label(:device), do: "Controller connected"
  defp prerequisite_label(:firmware), do: "Controller firmware supports gauges"
  defp prerequisite_label(:applied), do: "Axis settings are on the controller"
  defp prerequisite_label(:idle_hold), do: "Motor holds its position when idle"

  defp prerequisite_text(:wiring), do: "Confirm the shield and motor are plugged in and powered."

  # ---------------------------------------------------------------- render

  @impl true
  def render(assigns) do
    wizard = assigns.wizard

    assigns =
      assigns
      |> assign(:progress, GaugeWizard.progress())
      |> assign(:group, GaugeWizard.group(wizard.step))
      |> assign(:nudges, @nudges)
      |> assign(:missing, GaugeWizard.prerequisites(wizard))
      |> assign(:moving?, GaugeWizard.moving?(wizard))
      |> assign(:stop?, GaugeWizard.stop_visible?(wizard))

    ~H"""
    <section
      id={@id}
      class="rounded-lg border border-primary/40 bg-base-100 p-4 space-y-4"
      aria-label="Guided gauge setup"
    >
      <header class="flex flex-wrap items-center justify-between gap-2">
        <h3 class="text-base font-semibold">Guided gauge setup: {@wizard.axis.name}</h3>
        <button
          id={"#{@id}-close"}
          type="button"
          phx-click="close"
          phx-target={@myself}
          class="btn btn-sm btn-ghost"
        >
          Close
        </button>
      </header>

      <ol id={"#{@id}-progress"} class="flex flex-wrap gap-1 text-xs">
        <li
          :for={{key, label} <- @progress}
          class={[
            "rounded-full px-2 py-0.5",
            if(key == @group, do: "bg-primary text-primary-content", else: "bg-base-200")
          ]}
          aria-current={key == @group && "step"}
        >
          {label}
        </li>
      </ol>

      <p :if={@wizard.error} id={"#{@id}-error"} role="alert" class="text-sm text-error">
        {error_text(@wizard.error)}
      </p>
      <p :if={@wizard.info == :stopped} class="text-sm text-warning">
        Stopped. The motor no longer holds a trusted position, so the next step starts by lining the needle up again.
      </p>

      <div
        :if={@wizard.interrupted}
        id={"#{@id}-interrupted"}
        role="alert"
        class="alert alert-warning text-sm"
      >
        <div class="space-y-2">
          <.interruption
            interrupted={@wizard.interrupted}
            step_name={step_name(@wizard.interrupted.step)}
          />
          <div class="flex flex-wrap gap-2">
            <button
              :if={match?({:fault, _}, @wizard.interrupted.reason)}
              id={"#{@id}-recover"}
              type="button"
              phx-click="act"
              phx-value-do="recover"
              phx-target={@myself}
              class="btn btn-sm"
            >
              Recover and continue
            </button>
          </div>
        </div>
      </div>

      <div :if={!@wizard.interrupted} id={"#{@id}-step-#{@wizard.step}"} class="space-y-3">
        <.step_body
          wizard={@wizard}
          myself={@myself}
          id={@id}
          missing={@missing}
          nudges={@nudges}
          moving?={@moving?}
        />
      </div>

      <div :if={@stop?} class="flex items-center gap-3">
        <button
          id={"#{@id}-stop"}
          type="button"
          phx-click="act"
          phx-value-do="stop"
          phx-target={@myself}
          class="btn btn-error"
        >
          Stop
        </button>
        <span class="text-sm" role="status">The needle is moving. Press Stop at any time.</span>
      </div>

      <p class="text-xs text-base-content/60">
        Closing at any point stops the gauge and gives control back. Steps already saved stay saved.
      </p>
    </section>
    """
  end

  attr :interrupted, :map, required: true
  attr :step_name, :string, required: true

  defp interruption(%{interrupted: %{reason: :disconnected}} = assigns) do
    ~H"""
    <p class="font-medium">The controller was disconnected.</p>
    <p>
      Plug it back in. Trenino carries on automatically, then asks you to line the needle up again before returning to {@step_name}.
    </p>
    """
  end

  defp interruption(%{interrupted: %{reason: {:fault, reason}}} = assigns) do
    assigns = assign(assigns, :text, GaugeFeedback.fault(reason))

    ~H"""
    <p class="font-medium">The motor stopped because of a problem.</p>
    <p>{@text}</p>
    <p>
      Recovering forgets where the needle is. Afterwards you line it up again and return to {@step_name}.
    </p>
    """
  end

  attr :wizard, :map, required: true
  attr :myself, :any, required: true
  attr :id, :string, required: true
  attr :missing, :list, required: true
  attr :nudges, :list, required: true
  attr :moving?, :boolean, required: true

  defp step_body(%{wizard: %{step: :prerequisites}} = assigns) do
    ~H"""
    <h4 class="font-medium">Get ready</h4>
    <p class="text-sm">
      This wizard walks you through direction, dial marks and (optionally) automatic zeroing. Nothing moves until you press a button that says it will.
    </p>
    <div
      :if={@wizard.warning}
      id={"#{@id}-allcall-warning"}
      role="alert"
      class="alert alert-warning text-sm"
    >
      <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
      <p>{@wizard.warning}</p>
    </div>
    <ul id={"#{@id}-checklist"} class="space-y-2 text-sm">
      <li :for={item <- [:device, :firmware, :applied, :idle_hold]} class="flex items-start gap-2">
        <.icon
          name={if item in @missing, do: "hero-x-circle", else: "hero-check-circle"}
          class={"size-5 shrink-0 " <> if(item in @missing, do: "text-error", else: "text-success")}
        />
        <span>
          <span class="font-medium">{prerequisite_label(item)}</span>
          <span :if={item in @missing} class="block text-base-content/70">{prerequisite_text(item)}</span>
          <button
            :if={item == :applied and :applied in @missing and :device not in @missing}
            id={"#{@id}-apply"}
            type="button"
            phx-click="act"
            phx-value-do="apply"
            phx-target={@myself}
            class="btn btn-xs ml-2"
          >
            Send settings
          </button>
          <button
            :if={item == :idle_hold and :idle_hold in @missing}
            id={"#{@id}-fix-idle"}
            type="button"
            phx-click="act"
            phx-value-do="fix_idle_hold"
            phx-target={@myself}
            class="btn btn-xs ml-2"
          >
            Turn on and send
          </button>
        </span>
      </li>
    </ul>
    <p :if={:applied in @missing and :device not in @missing} class="text-xs text-base-content/70">
      Sending settings only configures the controller. The motor does not move.
    </p>
    <form id={"#{@id}-wiring-form"} phx-change="wiring" phx-target={@myself}>
      <label class="flex items-start gap-2 text-sm">
        <input type="hidden" name="wiring" value="false" />
        <input
          id={"#{@id}-wiring"}
          type="checkbox"
          name="wiring"
          value="true"
          checked={@wizard.wiring_confirmed}
          class="checkbox checkbox-sm"
        />
        <span>{prerequisite_text(:wiring)}</span>
      </label>
    </form>
    <p class="text-sm">
      When you continue, Trenino takes over this gauge so trains stop moving it. It hands it back when you finish or close the wizard.
    </p>
    <button
      id={"#{@id}-continue"}
      type="button"
      phx-click="act"
      phx-value-do="continue"
      phx-target={@myself}
      class="btn btn-primary"
      disabled={@missing != [] or @wizard.claiming}
    >
      Continue
    </button>
    <p :if={@missing != []} class="text-xs text-warning">
      Still to do: {Enum.map_join(@missing, " ", &prerequisite_text/1)}
    </p>
    <.retry_claim wizard={@wizard} id={@id} myself={@myself} />
    """
  end

  defp step_body(%{wizard: %{step: :applying}} = assigns) do
    ~H"""
    <h4 class="font-medium">Sending the new settings to the controller</h4>
    <p class="text-sm" role="status">
      Waiting for the controller to confirm. This takes a few seconds and the motor does not move.
    </p>
    <button
      id={"#{@id}-apply"}
      type="button"
      phx-click="act"
      phx-value-do="apply"
      phx-target={@myself}
      class="btn btn-sm"
    >
      Send again
    </button>
    """
  end

  defp step_body(%{wizard: %{step: :align}} = assigns) do
    ~H"""
    <h4 class="font-medium">Start with the needle on zero</h4>
    <p
      :if={@wizard.flips > 0 and @wizard.return_to == :jog_test}
      id={"#{@id}-flipped"}
      class="text-sm text-warning"
    >
      The direction was flipped and sent to the controller. It forgot where the needle is, so line it up again.
    </p>
    <p
      :if={
        (@wizard.return_to not in [nil, :jog_test] and @wizard.flips == 0) or
          @wizard.info == :reference_lost
      }
      class="text-sm text-warning"
    >
      Trenino lost track of where the needle is. Line it up again and you will go straight back to {step_name(
        @wizard.return_to
      )}.
    </p>
    <%= if @wizard.axis.reference_strategy == :host_reference do %>
      <p class="text-sm">
        Line the needle up on the 0 mark by hand (the lowest mark on the dial). Turn it gently; do not force it.
      </p>
      <button
        id={"#{@id}-set-reference"}
        type="button"
        phx-click="act"
        phx-value-do="set_reference"
        phx-target={@myself}
        class="btn btn-primary"
        disabled={@moving?}
      >
        The needle is on 0
      </button>
    <% else %>
      <p class="text-sm">
        This gauge finds zero by itself. Press Home and the needle sweeps into its end stop, then backs off a little.
      </p>
      <button
        id={"#{@id}-home"}
        type="button"
        phx-click="act"
        phx-value-do="home"
        phx-target={@myself}
        class="btn btn-primary"
        disabled={@moving?}
      >
        Home
      </button>
    <% end %>
    <p :if={@moving?} role="status" class="text-sm">
      Working. Waiting for the controller to report the result.
    </p>
    """
  end

  defp step_body(%{wizard: %{step: :jog_test}} = assigns) do
    assigns =
      assign(
        assigns,
        :moved?,
        is_integer(assigns.wizard.obs.position) and
          assigns.wizard.obs.position != assigns.wizard.axis.home_position
      )

    ~H"""
    <h4 class="font-medium">Check the direction</h4>
    <p class="text-sm">
      Trenino will move the needle a small way ({GaugeWizard.jog_distance()} steps). Watch which way it goes.
    </p>
    <button
      id={"#{@id}-jog"}
      type="button"
      phx-click="act"
      phx-value-do="jog_up"
      phx-target={@myself}
      class="btn btn-primary"
      disabled={@moving?}
    >
      Move the needle up a little
    </button>
    <div :if={@moved? and not @moving?} id={"#{@id}-direction-question"} class="space-y-2">
      <p class="font-medium">Did the needle move up the dial?</p>
      <.yes_no id={@id} myself={@myself} yes="Yes, it moved up" no="No, it moved down" />
      <p class="text-xs text-base-content/70">
        If not, Trenino flips the direction and sends it to the controller. You then line the needle up on 0 again and repeat this check.
      </p>
    </div>
    """
  end

  defp step_body(%{wizard: %{step: :range}} = assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(
          %{
            "min" => "0",
            "max" => "100",
            "unit" => "mph",
            "marks" => to_string(GaugeWizard.default_marks())
          },
          as: :range
        )
      )

    ~H"""
    <h4 class="font-medium">Describe the dial</h4>
    <p class="text-sm">
      Tell Trenino what the printed dial shows, for example 0 to 100 mph. You will then move the needle to evenly spaced marks and confirm what it reads at each one.
    </p>
    <.form
      for={@form}
      id={"#{@id}-range-form"}
      phx-submit="set_range"
      phx-target={@myself}
      class="grid gap-3 sm:grid-cols-2"
    >
      <.input field={@form[:min]} type="number" step="0.01" label="Lowest mark" />
      <.input field={@form[:max]} type="number" step="0.01" label="Highest mark" />
      <.input
        field={@form[:unit]}
        type="select"
        label="Dial shows"
        options={DialCalibrationComponent.unit_options()}
      />
      <.input field={@form[:marks]} type="number" min="1" max="30" label="Marks to measure" />
      <button id={"#{@id}-range-submit"} type="submit" class="btn btn-primary sm:col-span-2">
        Start measuring
      </button>
    </.form>
    """
  end

  defp step_body(%{wizard: %{step: :mark}} = assigns) do
    wizard = assigns.wizard

    assigns =
      assigns
      |> assign(:current, wizard.current)
      |> assign(:unit, unit_label(wizard.range.unit))
      |> assign(:slope, GaugeWizard.slope(wizard.points))
      |> assign(:total, length(wizard.marks))

    ~H"""
    <h4 class="font-medium">
      Mark {min(@wizard.mark_index + 1, @total)} of {@total}: {format_value(@current.value)} {@unit}
    </h4>
    <p :if={@moving?} role="status" class="text-sm">
      Moving the needle to about where {format_value(@current.value)} {@unit} should be.
    </p>
    <div :if={@current.blocked} id={"#{@id}-blocked"} class="alert alert-warning text-sm">
      <div class="space-y-2">
        <p>
          This mark is further than the needle's allowed travel. The travel can be extended to {GaugeWizard.extended_max(
            @current.blocked.needed
          )} steps.
        </p>
        <p>
          That changes a motor setting, so the settings are sent again and you line the needle up on 0 once more. Nothing moves until you do.
        </p>
        <button
          id={"#{@id}-extend"}
          type="button"
          phx-click="act"
          phx-value-do="extend_max"
          phx-target={@myself}
          class="btn btn-sm btn-primary"
        >
          Allow more travel
        </button>
      </div>
    </div>
    <div :if={not @moving? and !@current.blocked} class="space-y-3">
      <p class="text-sm">
        Look at where the needle is. Nudge it until it sits exactly on the {format_value(
          @current.value
        )} {@unit} mark, then enter what the dial reads and capture it.
      </p>
      <p :if={@wizard.obs.position} class="text-xs text-base-content/70">
        Needle position: {@wizard.obs.position} steps
        <span :if={@slope}> · about {@slope} steps per {@unit}</span>
      </p>
      <.nudge_buttons id={@id} myself={@myself} nudges={@nudges} />
      <form
        id={"#{@id}-capture-form"}
        phx-submit="capture"
        phx-target={@myself}
        class="flex items-end gap-2"
      >
        <.input
          id={"#{@id}-reading"}
          name="reading"
          type="number"
          step="0.01"
          value={format_value(@current.value)}
          label={"The dial reads (#{@unit})"}
        />
        <button id={"#{@id}-capture"} type="submit" class="btn btn-primary">Capture this mark</button>
      </form>
    </div>
    <.points_table points={@wizard.points} unit={@unit} />
    """
  end

  defp step_body(%{wizard: %{step: :save_dial}} = assigns) do
    assigns = assign(assigns, :unit, unit_label(assigns.wizard.range.unit))

    ~H"""
    <h4 class="font-medium">All marks measured</h4>
    <.points_table points={@wizard.points} unit={@unit} />
    <p class="text-sm">
      Save the dial now. Saving only records numbers; the motor does not move. You review it in the next steps.
    </p>
    <button
      id={"#{@id}-save-dial"}
      type="button"
      phx-click="act"
      phx-value-do="save_dial"
      phx-target={@myself}
      class="btn btn-primary"
    >
      Save the dial
    </button>
    """
  end

  defp step_body(%{wizard: %{step: :verify_zero}} = assigns) do
    ~H"""
    <h4 class="font-medium">Check zero</h4>
    <p :if={@moving?} role="status" class="text-sm">Sending the needle back to 0.</p>
    <div :if={not @moving?} class="space-y-2">
      <p class="font-medium">Is the needle exactly on the 0 mark?</p>
      <.yes_no id={@id} myself={@myself} yes="Yes, exactly on 0" no="No, it is off" />
      <p class="text-xs text-base-content/70">
        If it is off, the motor skipped steps somewhere. You will line it up again and recheck.
      </p>
    </div>
    """
  end

  defp step_body(%{wizard: %{step: :verify_mid}} = assigns) do
    assigns = assign(assigns, :unit, unit_label(assigns.wizard.range.unit))

    ~H"""
    <h4 class="font-medium">Check a mark in between</h4>
    <p :if={@moving?} role="status" class="text-sm">
      Moving to {format_value(@wizard.current.value)} {@unit}.
    </p>
    <div :if={not @moving?} class="space-y-2">
      <p class="font-medium">Does the needle read {format_value(@wizard.current.value)} {@unit}?</p>
      <.yes_no id={@id} myself={@myself} yes="Yes, it matches" no="No, it is off" />
      <button
        :if={@wizard.error == :mid_mark_off}
        id={"#{@id}-restart"}
        type="button"
        phx-click="act"
        phx-value-do="restart_calibration"
        phx-target={@myself}
        class="btn btn-sm"
      >
        Measure the marks again
      </button>
    </div>
    """
  end

  defp step_body(%{wizard: %{step: :homing_offer}} = assigns) do
    assigns = assign(assigns, :plan, home_preview(assigns.wizard))

    ~H"""
    <h4 class="font-medium">Automatic zeroing (recommended)</h4>
    <p class="text-sm">
      With automatic zeroing the needle finds zero by itself every time the controller starts: it sweeps gently down into its end stop, then backs off to the 0 mark. You will not have to line it up by hand again.
    </p>
    <p class="text-sm">
      You will tune it once: Trenino sweeps, you nudge the needle onto 0, and Trenino remembers the distance. The motor may click against the stop; that is normal.
    </p>
    <p :if={@plan} id={"#{@id}-home-plan"} class="text-xs text-base-content/70">
      Sweep of {@plan.home_steps} steps at speed {@plan.home_speed}, allowed up to {@plan.home_timeout_ms} ms.
    </p>
    <p :if={@plan && @wizard.axis.home_steps < @plan.home_steps} class="text-sm text-warning">
      The current sweep ({@wizard.axis.home_steps} steps) is too short to reach the stop from the top of the dial. Trenino will lengthen it.
    </p>
    <div class="flex flex-wrap gap-2">
      <button
        id={"#{@id}-start-homing"}
        type="button"
        phx-click="act"
        phx-value-do="start_homing"
        phx-target={@myself}
        class="btn btn-primary"
      >
        Set up automatic zeroing
      </button>
      <button
        id={"#{@id}-skip-homing"}
        type="button"
        phx-click="act"
        phx-value-do="skip_homing"
        phx-target={@myself}
        class="btn"
      >
        Skip for now
      </button>
    </div>
    <p class="text-xs text-base-content/70">
      Setting it up sends new motor settings to the controller, so you will press Home next. The needle moves only when you press it.
    </p>
    """
  end

  defp step_body(%{wizard: %{step: :home_run}} = assigns) do
    ~H"""
    <h4 class="font-medium">
      {if @wizard.home.phase == :first, do: "Run the first sweep", else: "Run the sweep again"}
    </h4>
    <p
      :for={warning <- @wizard.home.warnings}
      :if={@wizard.home.phase == :first}
      class="text-sm text-warning"
    >
      {if warning == :sweep_too_small, do: "The old sweep was too short; it has been lengthened."}
    </p>
    <p class="text-sm">
      Press Home and watch. The needle sweeps down into the stop and backs off. {if @wizard.home.phase ==
                                                                                      :first,
                                                                                    do:
                                                                                      " It will not land on 0 yet; you fix that next.",
                                                                                    else:
                                                                                      " It should now land on 0."}
    </p>
    <button
      id={"#{@id}-home"}
      type="button"
      phx-click="act"
      phx-value-do="home"
      phx-target={@myself}
      class="btn btn-primary"
      disabled={@moving?}
    >
      Home
    </button>
    <p :if={@moving?} role="status" class="text-sm">
      Sweeping. Waiting for the controller to say it has finished.
    </p>
    """
  end

  defp step_body(%{wizard: %{step: :home_nudge}} = assigns) do
    assigns =
      assign(
        assigns,
        :moved,
        max((assigns.wizard.obs.position || 0) - assigns.wizard.axis.home_position, 0)
      )

    ~H"""
    <h4 class="font-medium">Nudge the needle onto 0</h4>
    <p class="text-sm">
      Nudge the needle up until it sits exactly on the 0 mark. Trenino remembers how far you moved it.
    </p>
    <p id={"#{@id}-nudge-distance"} class="text-xs text-base-content/70">
      Moved so far: {@moved} steps. Zeroing distance will become {@wizard.home.backoff + @moved} steps.
    </p>
    <.nudge_buttons id={@id} myself={@myself} nudges={[-5, -1, 1, 5, 20, 50]} />
    <button
      id={"#{@id}-finish-nudging"}
      type="button"
      phx-click="act"
      phx-value-do="finish_nudging"
      phx-target={@myself}
      class="btn btn-primary"
      disabled={@moving?}
    >
      The needle is on 0
    </button>
    <p class="text-xs text-base-content/70">
      This changes a motor setting, so the settings are sent again before the next sweep.
    </p>
    """
  end

  defp step_body(%{wizard: %{step: :home_confirm}} = assigns) do
    ~H"""
    <h4 class="font-medium">Check the sweep</h4>
    <p class="font-medium">Did the needle land exactly on the 0 mark?</p>
    <.yes_no id={@id} myself={@myself} yes="Yes, exactly on 0" no="No, adjust again" />
    """
  end

  defp step_body(%{wizard: %{step: :finish}} = assigns) do
    assigns =
      assign(assigns, :rename_form, to_form(%{"name" => assigns.wizard.axis.name}, as: :axis))

    ~H"""
    <h4 class="font-medium">Finish</h4>
    <.points_table points={@wizard.points} unit={unit_label(@wizard.range.unit)} />
    <form
      id={"#{@id}-rename-form"}
      phx-submit="rename"
      phx-target={@myself}
      class="flex items-end gap-2"
    >
      <.input field={@rename_form[:name]} label="Name this gauge" />
      <button type="submit" class="btn btn-sm">Rename</button>
    </form>
    <form
      :if={@wizard.axis.reference_strategy == :internal_stop}
      id={"#{@id}-startup-form"}
      phx-change="startup"
      phx-target={@myself}
    >
      <label class="flex items-start gap-2 text-sm">
        <input type="hidden" name="startup" value="false" />
        <input
          id={"#{@id}-startup"}
          type="checkbox"
          name="startup"
          value="true"
          checked={@wizard.home_on_connect}
          class="checkbox checkbox-sm"
        />
        <span>Find zero automatically whenever the controller connects (one gentle sweep, recommended).</span>
      </label>
    </form>
    <p class="text-sm">
      By confirming you say you checked direction, travel and zero on the real dial. Only then will trains be allowed to move this gauge.
    </p>
    <button
      id={"#{@id}-commission"}
      type="button"
      phx-click="act"
      phx-value-do="commission"
      phx-target={@myself}
      class="btn btn-primary"
      disabled={@moving?}
    >
      Confirm: the gauge works
    </button>
    """
  end

  defp step_body(%{wizard: %{step: :done}} = assigns) do
    assigns =
      assign(
        assigns,
        :bindings,
        Train.list_gauge_bindings_for_axis(assigns.wizard.axis.id)
      )

    ~H"""
    <h4 class="font-medium">Your gauge is set up</h4>
    <ul class="list-disc pl-5 text-sm space-y-1">
      <li>Direction checked and zero confirmed on the real dial.</li>
      <li>Dial saved and reviewed ({length(@wizard.points)} marks).</li>
      <li :if={@wizard.axis.reference_strategy == :internal_stop}>
        Automatic zeroing is on{if @wizard.axis.startup_reference == :home_on_connect,
          do: ", and it runs whenever the controller connects",
          else: ""}.
      </li>
      <li>Setup is confirmed. Closing hands the gauge back to train control.</li>
    </ul>
    <div id={"#{@id}-bindings"} class="space-y-1 text-sm">
      <p :if={@bindings == []}>
        No train uses this gauge yet. Open a train, choose Gauges, then Add gauge to make it show the speed.
      </p>
      <p :if={@bindings != []} class="font-medium">Trains using this gauge:</p>
      <p :for={binding <- @bindings}>
        <.link navigate={~p"/trains/#{binding.train_id}"} class="link">
          {binding.train.name}: {binding.name}
        </.link>
        <span :if={!binding.enabled} class="text-xs text-warning"> (not enabled yet)</span>
      </p>
      <.link :if={@bindings == []} navigate={~p"/trains"} class="link">Go to trains</.link>
    </div>
    <button
      id={"#{@id}-done"}
      type="button"
      phx-click="close"
      phx-target={@myself}
      class="btn btn-primary"
    >
      Done
    </button>
    """
  end

  defp step_body(assigns) do
    ~H"""
    <p>Working on it.</p>
    """
  end

  attr :wizard, :map, required: true
  attr :id, :string, required: true
  attr :myself, :any, required: true

  defp retry_claim(assigns) do
    ~H"""
    <button
      :if={@wizard.claim_blocked}
      id={"#{@id}-retry-claim"}
      type="button"
      phx-click="act"
      phx-value-do="retry_claim"
      phx-target={@myself}
      class="btn btn-sm"
    >
      Try again
    </button>
    """
  end

  attr :id, :string, required: true
  attr :myself, :any, required: true
  attr :yes, :string, required: true
  attr :no, :string, required: true

  defp yes_no(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <button
        id={"#{@id}-yes"}
        type="button"
        phx-click="answer"
        phx-value-value="yes"
        phx-target={@myself}
        class="btn btn-primary"
      >
        {@yes}
      </button>
      <button
        id={"#{@id}-no"}
        type="button"
        phx-click="answer"
        phx-value-value="no"
        phx-target={@myself}
        class="btn"
      >
        {@no}
      </button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :myself, :any, required: true
  attr :nudges, :list, required: true

  defp nudge_buttons(assigns) do
    ~H"""
    <div id={"#{@id}-nudges"} class="flex flex-wrap gap-2">
      <button
        :for={n <- @nudges}
        id={"#{@id}-nudge-#{n}"}
        type="button"
        phx-click="nudge"
        phx-value-delta={n}
        phx-target={@myself}
        class="btn btn-sm"
        aria-label={"Nudge #{if n > 0, do: "up", else: "down"} #{abs(n)}"}
      >
        {if n > 0, do: "▲ #{n}", else: "▼ #{abs(n)}"}
      </button>
    </div>
    """
  end

  attr :points, :list, required: true
  attr :unit, :string, required: true

  defp points_table(assigns) do
    ~H"""
    <table :if={@points != []} class="table table-xs w-auto">
      <thead>
        <tr>
          <th>Dial {@unit}</th>
          <th>Needle position</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={point <- @points}>
          <td>{format_value(point.value)}</td>
          <td>{point.position}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp home_preview(wizard) do
    top = wizard.points |> Enum.map(& &1.position) |> Enum.max(fn -> wizard.axis.max_position end)

    case GaugeWizard.home_plan(wizard.axis, top, wizard.axis.home_backoff, 400) do
      {:ok, attrs, _} -> attrs
      _ -> nil
    end
  end
end
