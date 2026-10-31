defmodule Trenino.Hardware.GaugeWizard do
  @moduledoc """
  Pure state machine behind the guided gauge setup of one stepper axis.

  It turns the manual commissioning procedure (reference, direction, dial marks,
  verification, automatic homing, commissioning) into a short sequence of steps. It never
  touches hardware or the database: `update/2` takes an event and returns the new state
  plus a list of *effects* for a runner to carry out (`Trenino.Hardware.GaugeWizard.Runner`).
  The runner reports each effect's outcome back as a `{:result, effect, result}` event, and
  the live device status arrives as `{:observed, observation}` events, so every motion wait
  follows real status instead of timers.

  ## Events

    * `{:observed, %Observation{}}` - latest device status
    * `{:result, effect, result}` - outcome of an effect
    * user events: `:continue`, `{:confirm_wiring, bool}`, `:apply`, `:set_reference`,
      `:home`, `:jog_up`, `{:answer, :yes | :no}`, `{:set_range, map}`, `{:nudge, delta}`,
      `{:capture, reading}`, `:extend_max`, `:save_dial`, `:restart_calibration`,
      `:start_homing`, `:skip_homing`, `:finish_nudging`, `{:startup_on_connect, bool}`,
      `{:rename, name}`, `:commission`, `:stop`, `:recover`, `:close`

  ## Effects

  `:claim`, `:release`, `:resume`, `:recover`, `:apply`, `:complete_commissioning`,
  `{:command, op, params}`, `{:update_axis, attrs}`, `{:save_dial, attrs}`.

  Safety rules are kept by construction: nothing here moves a motor on its own, motion only
  follows an explicit user event, saving never moves, and commissioning is only ever
  requested through `:complete_commissioning`.
  """

  alias Trenino.Hardware.{DialCalibration, DialPoint, StepperAxis}
  alias Trenino.Hardware.GaugeWizard.Observation
  alias Trenino.Train.GaugeMapper

  @type step ::
          :prerequisites
          | :applying
          | :align
          | :jog_test
          | :range
          | :mark
          | :save_dial
          | :verify_zero
          | :verify_mid
          | :homing_offer
          | :home_run
          | :home_nudge
          | :home_confirm
          | :finish
          | :done

  @type t :: %__MODULE__{}
  @type effect :: atom() | tuple()

  defstruct step: :prerequisites,
            axis: nil,
            token: nil,
            obs: %Observation{},
            wiring_confirmed: false,
            warning: nil,
            error: nil,
            info: nil,
            pending: nil,
            interrupted: nil,
            return_to: nil,
            after_apply: nil,
            flips: 0,
            range: nil,
            marks: [],
            mark_index: 0,
            points: [],
            current: nil,
            lost_steps: 0,
            home: nil,
            home_on_connect: true,
            claiming: false,
            claim_blocked: false,
            paused: false,
            closed: false

  @jog_distance 20
  @fresh_ms 1500
  @home_speed 50
  @timeout_margin_ms 1500
  @sweep_margin 100
  @provisional_stop 400
  @max_timeout_ms 60_000
  @default_marks 5
  @needs_reference [
    :jog_test,
    :mark,
    :save_dial,
    :verify_zero,
    :verify_mid,
    :home_nudge,
    :home_confirm,
    :finish
  ]
  @motion_steps [
    :jog_test,
    :mark,
    :verify_zero,
    :verify_mid,
    :home_run,
    :home_nudge,
    :home_confirm,
    :align
  ]

  @doc "Starts a wizard for the given axis, with the optional 0x70 display warning."
  @spec new(StepperAxis.t(), String.t() | nil) :: t()
  def new(%StepperAxis{} = axis, warning \\ nil), do: %__MODULE__{axis: axis, warning: warning}

  @doc "Number of dial marks offered by default."
  def default_marks, do: @default_marks

  @doc "Distance of the direction test jog, in transitions."
  def jog_distance, do: @jog_distance

  @doc "True while a motion the user may need to interrupt is running or being requested."
  @spec moving?(t()) :: boolean()
  def moving?(%__MODULE__{pending: pending, obs: obs}),
    do: pending != nil or obs.state in [:moving, :homing]

  @doc "True when the Stop button must be shown."
  @spec stop_visible?(t()) :: boolean()
  def stop_visible?(%__MODULE__{step: step} = state), do: step in @motion_steps and moving?(state)

  # ---------------------------------------------------------------- pure helpers

  @doc """
  Builds an observation from a manager snapshot. `now` is a monotonic millisecond clock,
  injected so the function stays pure.
  """
  @spec observation(map(), StepperAxis.t(), integer()) :: Observation.t()
  def observation(%{lifecycle: lifecycle} = snapshot, %StepperAxis{} = axis, now) do
    runtime = Map.get(snapshot.axes || %{}, axis.id)

    %Observation{
      lifecycle: lifecycle,
      fault: fault_of(snapshot, runtime && runtime.status),
      config_applied?: config_applied?(lifecycle, runtime, axis)
    }
    |> runtime_fields(runtime, now)
  end

  defp runtime_fields(obs, nil, _now), do: obs

  defp runtime_fields(obs, runtime, now) do
    %{
      obs
      | ready: runtime.ready == true,
        pending?: runtime.pending != nil,
        lease_held?: match?(%{owner: :ui}, runtime.lease),
        age_ms: runtime.updated_at && now - runtime.updated_at
    }
    |> status_fields(runtime.status)
  end

  defp status_fields(obs, nil), do: obs

  defp status_fields(obs, status) do
    known? = status.known == true
    %{obs | state: status.state, known: known?, position: if(known?, do: status.position)}
  end

  defp fault_of(%{lifecycle: :fault} = snapshot, _), do: Map.get(snapshot, :error) || :unknown
  defp fault_of(%{lifecycle: :unsupported}, _), do: :unsupported_capabilities
  defp fault_of(_, %{fault: fault}) when fault not in [nil, :none], do: fault
  defp fault_of(_, _), do: :none

  defp config_applied?(lifecycle, %{config: %StepperAxis{} = config}, axis)
       when lifecycle in [:awaiting_reference, :ready] do
    axis.axis_index == config.axis_index and
      StepperAxis.to_protocol_config(axis) == StepperAxis.to_protocol_config(config)
  end

  defp config_applied?(_, _, _), do: false

  @doc "Evenly spaced dial values above the minimum: `count` marks ending on the maximum."
  @spec mark_values(number(), number(), pos_integer()) :: [float()]
  def mark_values(min, max, count) when count >= 1 and max > min do
    for i <- 1..count, do: Float.round(min + (max - min) * i / count, 2)
  end

  @doc """
  Estimated position for a dial value, from the points measured so far.

  With one point the slope comes from the axis travel spread over the dial range; with two
  or more it is the slope of the last two points (transitions per dial unit).
  """
  @spec estimate_position(
          [%{value: number(), position: integer()}],
          number(),
          StepperAxis.t(),
          map()
        ) ::
          integer()
  def estimate_position([only], value, %StepperAxis{} = axis, range) do
    span = max(range.max - range.min, 1.0e-6)
    slope = max((axis.max_position - only.position) / span, 1.0e-6)
    round(only.position + slope * (value - only.value))
  end

  def estimate_position(points, value, _axis, _range) do
    [previous, last] = Enum.take(points, -2)
    slope = (last.position - previous.position) / (last.value - previous.value)
    round(last.position + slope * (value - last.value))
  end

  @doc "Transitions per dial unit from the last two points, or nil with fewer than two."
  def slope(points) when length(points) >= 2 do
    [previous, last] = Enum.take(points, -2)
    Float.round((last.position - previous.position) / (last.value - previous.value), 2)
  end

  def slope(_), do: nil

  @doc "The new home backoff: the previous one plus how far the needle was nudged up."
  @spec backoff_from_nudge(integer(), integer(), integer()) ::
          {:ok, integer()} | {:error, :not_nudged}
  def backoff_from_nudge(previous_backoff, home_position, position)
      when position >= home_position,
      do: {:ok, previous_backoff + (position - home_position)}

  def backoff_from_nudge(_, _, _), do: {:error, :not_nudged}

  @doc "Smallest timeout the axis validator accepts for a sweep plus backoff."
  @spec min_timeout_ms(integer(), integer(), integer()) :: integer()
  def min_timeout_ms(steps, backoff, speed), do: ceil(1000 * (steps + backoff) / speed) + 500 + 1

  @doc """
  Sweep length needed so the needle reaches the stop from anywhere in its travel and still
  has the backoff to give back: top of the dial (or the soft limit, whichever is higher), down
  to the home position, plus the backoff and a small margin.
  """
  @spec required_sweep(StepperAxis.t(), integer(), integer()) :: integer()
  def required_sweep(%StepperAxis{} = axis, top_position, backoff) do
    reach = max(top_position, axis.max_position)
    reach - axis.home_position + backoff + @sweep_margin
  end

  @doc """
  Home settings for the automatic-homing step: internal stop at a gentle speed, a sweep long
  enough for the whole travel plus the backoff, and a timeout the axis validator accepts.

  `backoff` is the current backoff and `stop_allowance` extra distance assumed between the
  dial zero and the stop while that distance is still unmeasured. Returns `{:ok, attrs,
  warnings}` or `{:error, :sweep_too_long}` when no allowed speed can finish in 60 seconds.
  """
  @spec home_plan(StepperAxis.t(), integer(), integer(), non_neg_integer()) ::
          {:ok, map(), [atom()]} | {:error, :sweep_too_long}
  def home_plan(%StepperAxis{} = axis, top_position, backoff, stop_allowance \\ 0) do
    steps = required_sweep(axis, top_position, backoff) + stop_allowance
    warnings = if axis.home_steps < steps, do: [:sweep_too_small], else: []

    [@home_speed, 100, 200]
    |> Enum.filter(&(&1 <= axis.max_speed))
    |> Enum.find_value({:error, :sweep_too_long}, fn speed ->
      timeout = min_timeout_ms(steps, backoff, speed) + @timeout_margin_ms

      if steps <= 65_535 and backoff < steps and timeout <= @max_timeout_ms do
        {:ok,
         %{
           reference_strategy: :internal_stop,
           idle_behavior: :hold,
           home_speed: speed,
           home_steps: steps,
           home_backoff: backoff,
           home_timeout_ms: timeout
         }, warnings}
      end
    end)
  end

  @doc "Where a nudge of `delta` from `position` would land, within the soft limits."
  @spec nudge_target(StepperAxis.t(), integer(), integer()) ::
          {:ok, integer()} | {:error, :outside_limits, integer()}
  def nudge_target(%StepperAxis{} = axis, position, delta) do
    target = position + delta

    if target >= axis.min_position and target <= axis.max_position,
      do: {:ok, target},
      else: {:error, :outside_limits, target}
  end

  @doc "A max position with headroom that makes `needed` reachable."
  def extended_max(needed), do: ceil(needed / 10) * 10 + 20

  # ---------------------------------------------------------------- state machine

  @doc "Applies an event; returns the new state and the effects to run."
  @spec update(t(), term()) :: {t(), [effect()]}

  # Leaving is the only thing that still reports back after the wizard is closed.
  def update(%__MODULE__{closed: true} = state, {:result, effect, result})
      when effect in [:release, :resume],
      do: result(state, effect, result)

  def update(%__MODULE__{closed: true} = state, _), do: {state, []}

  def update(%__MODULE__{} = state, {:observed, %Observation{} = obs}),
    do: observe(%{state | obs: obs})

  def update(%__MODULE__{} = state, {:result, effect, result}), do: result(state, effect, result)
  def update(%__MODULE__{} = state, :close), do: close(state)

  def update(%__MODULE__{interrupted: %{}} = state, :recover),
    do: {%{state | info: :recovering}, [:recover]}

  def update(%__MODULE__{interrupted: %{}} = state, _), do: {state, []}
  def update(%__MODULE__{} = state, :stop), do: stop(state)

  def update(%__MODULE__{} = state, event) do
    state = %{state | error: nil, info: nil}

    if state.pending == nil,
      do: handle(state, event),
      else: {%{state | error: :busy}, []}
  end

  # A moving Stop may lose the reference; the next observation then sends the user to realign.
  defp stop(state) do
    effects = if state.token, do: [{:command, :stop, %{}}], else: []
    {%{state | pending: nil, info: :stopped}, effects}
  end

  # Releasing stops the axis. Train control resumes for a commissioned axis the wizard paused,
  # even if a fault or disconnect already dropped the token. The token is kept until the
  # release has run, because the runner reads it from this state.
  defp close(state) do
    effects =
      if(state.token, do: [:release], else: []) ++
        if(state.paused and state.axis.commissioned, do: [:resume], else: [])

    {%{state | closed: true, pending: nil, error: nil}, effects}
  end

  defp claim(%{claiming: true} = state), do: {state, []}
  defp claim(state), do: {%{state | claiming: true, claim_blocked: false}, [:claim]}

  # --- prerequisites

  defp handle(%{step: :prerequisites} = state, {:confirm_wiring, value}),
    do: {%{state | wiring_confirmed: value == true}, []}

  defp handle(%{step: step} = state, :apply) when step in [:prerequisites, :applying],
    do: {state, [:apply]}

  defp handle(%{step: :prerequisites} = state, :fix_idle_hold),
    do: reconfigure(state, %{idle_behavior: :hold}, :prerequisites, nil)

  defp handle(%{step: :prerequisites} = state, :continue) do
    case prerequisites(state) do
      [] -> claim(state)
      _ -> {%{state | error: :prerequisites_missing}, []}
    end
  end

  defp handle(%{claim_blocked: true} = state, :retry_claim), do: claim(state)

  # --- align (set the reference)

  defp handle(%{step: :align} = state, :set_reference) do
    position = state.axis.home_position
    pending = %{kind: :reference, position: position}
    {%{state | pending: pending}, [{:command, :reference, %{position: position}}]}
  end

  defp handle(%{step: step} = state, :home) when step in [:align, :home_run],
    do: {%{state | pending: %{kind: :home, seen: false}}, [{:command, :home, %{}}]}

  # --- direction test

  defp handle(%{step: :jog_test} = state, :jog_up) do
    with true <- stationary?(state.obs),
         {:ok, target} <- nudge_target(state.axis, state.obs.position, @jog_distance) do
      {%{state | pending: %{kind: :move, target: target}},
       [{:command, :jog, %{delta: @jog_distance}}]}
    else
      {:error, :outside_limits, _} -> {%{state | error: :outside_limits}, []}
      _ -> {%{state | error: :needs_fresh_stationary_position}, []}
    end
  end

  defp handle(%{step: :jog_test} = state, {:answer, :yes}), do: {%{state | step: :range}, []}

  defp handle(%{step: :jog_test} = state, {:answer, :no}) do
    state = %{state | flips: state.flips + 1}
    reconfigure(state, %{reverse: !state.axis.reverse}, :align, :jog_test)
  end

  # --- range

  defp handle(%{step: :range} = state, {:set_range, params}) do
    case parse_range(params) do
      {:ok, range} ->
        state = %{state | range: range, marks: marks_for(state, range), mark_index: 0}
        begin_mark(%{state | step: :mark, points: seed_points(state, range)})

      {:error, reason} ->
        {%{state | error: reason}, []}
    end
  end

  # --- marks

  defp handle(%{step: step} = state, {:nudge, delta}) when step in [:mark, :home_nudge],
    do: nudge(state, delta)

  defp handle(%{step: :mark} = state, {:capture, reading}), do: capture(state, reading)

  defp handle(%{step: :mark, current: %{blocked: %{needed: needed}}} = state, :extend_max),
    do: reconfigure(state, %{max_position: extended_max(needed)}, :align, :mark)

  defp handle(%{step: :save_dial} = state, :save_dial),
    do: {state, [{:save_dial, dial_attrs(state, false)}]}

  # --- verify

  defp handle(%{step: :verify_zero} = state, {:answer, :yes}), do: enter(state, :verify_mid)

  defp handle(%{step: :verify_zero} = state, {:answer, :no}),
    do: {%{state | lost_steps: state.lost_steps + 1, step: :align, return_to: :verify_zero}, []}

  defp handle(%{step: :verify_mid} = state, {:answer, :yes}),
    do: {state, [{:save_dial, dial_attrs(state, true)}]}

  defp handle(%{step: :verify_mid} = state, {:answer, :no}),
    do: {%{state | error: :mid_mark_off}, []}

  defp handle(%{step: step} = state, :restart_calibration)
       when step in [:verify_zero, :verify_mid] do
    {%{state | step: :range, points: [], mark_index: 0, lost_steps: 0, current: nil}, []}
  end

  # --- homing

  defp handle(%{step: :homing_offer} = state, :skip_homing), do: enter(state, :finish)

  defp handle(%{step: :homing_offer} = state, :start_homing) do
    top = top_position(state)
    backoff = state.axis.home_backoff

    case home_plan(state.axis, top, backoff, @provisional_stop) do
      {:ok, attrs, warnings} ->
        home = %{backoff: backoff, warnings: warnings, top: top, phase: :first}
        reconfigure(%{state | home: home}, attrs, :home_run, :first)

      {:error, reason} ->
        {%{state | error: reason}, []}
    end
  end

  defp handle(%{step: :home_nudge} = state, :finish_nudging) do
    obs = state.obs

    with true <- stationary?(obs),
         {:ok, backoff} <-
           backoff_from_nudge(state.home.backoff, state.axis.home_position, obs.position),
         {:ok, attrs, _} <- home_plan(state.axis, state.home.top, backoff, 0) do
      reconfigure(%{state | home: %{state.home | backoff: backoff}}, attrs, :home_run, :second)
    else
      {:error, reason} -> {%{state | error: reason}, []}
      _ -> {%{state | error: :needs_fresh_stationary_position}, []}
    end
  end

  defp handle(%{step: :home_confirm} = state, {:answer, :yes}), do: enter(state, :finish)

  # Keep the measured backoff as the new starting point and nudge again from the stop.
  defp handle(%{step: :home_confirm} = state, {:answer, :no}),
    do: {%{state | step: :home_nudge}, []}

  # --- finish

  defp handle(%{step: :finish} = state, {:startup_on_connect, value}),
    do: {%{state | home_on_connect: value == true}, []}

  defp handle(%{step: :finish} = state, {:rename, name}) when is_binary(name) do
    name = String.trim(name)

    if name == "" or name == state.axis.name,
      do: {state, []},
      else: {state, [{:update_axis, %{name: name}}]}
  end

  defp handle(%{step: :finish} = state, :commission), do: {state, [:complete_commissioning]}
  defp handle(%{step: :done} = state, :continue), do: close(state)
  defp handle(state, _event), do: {state, []}

  # ---------------------------------------------------------------- effect results

  # An unreachable or already-lost lease cannot be released again; anything else is shown and
  # the wizard stays open so Close can be pressed again.
  defp result(state, :release, :ok), do: {%{state | token: nil}, []}
  defp result(state, :release, {:error, :invalid_lease}), do: {%{state | token: nil}, []}
  defp result(state, :release, error), do: {leave_failed(state, error), []}

  defp result(state, :resume, :ok), do: {%{state | paused: false}, []}
  defp result(state, :resume, error), do: {leave_failed(state, error), []}

  defp result(state, :claim, {:ok, token}) do
    state = %{state | token: token, paused: true, claiming: false, claim_blocked: false}
    if state.step == :prerequisites, do: enter(state, :align), else: {state, []}
  end

  defp result(state, :claim, error),
    do: {%{state | claiming: false, claim_blocked: true, error: reason(error), pending: nil}, []}

  defp result(state, :apply, {:ok, _}), do: {%{state | info: :applying}, []}
  defp result(state, :apply, error), do: {%{state | error: reason(error)}, []}

  defp result(state, {:command, _, _}, {:ok, _}), do: {state, []}

  defp result(state, {:command, _, _}, {:error, :invalid_lease}) do
    claim(%{state | pending: nil, token: nil, error: :invalid_lease})
  end

  defp result(state, {:command, _, _}, error),
    do: {%{state | pending: nil, error: reason(error)}, []}

  defp result(state, {:update_axis, %{startup_reference: _}}, {:ok, axis}),
    do: {%{state | axis: axis, step: :done}, []}

  defp result(state, {:update_axis, attrs}, {:ok, axis}) do
    state = %{state | axis: axis}

    if state.after_apply != nil and motion_attrs?(attrs),
      do: {%{state | step: :applying}, [:apply]},
      else: {state, []}
  end

  defp result(state, {:update_axis, _}, error),
    do: {%{state | error: reason(error), after_apply: nil}, []}

  defp result(state, {:save_dial, %{reviewed: true}}, {:ok, _}) do
    next = if state.axis.reference_strategy == :internal_stop, do: :finish, else: :homing_offer
    enter(state, next)
  end

  defp result(state, {:save_dial, _}, {:ok, _}), do: enter(state, :verify_zero)
  defp result(state, {:save_dial, _}, error), do: {%{state | error: reason(error)}, []}

  defp result(state, :complete_commissioning, {:ok, axis}) do
    state = %{state | axis: axis}

    if axis.reference_strategy == :internal_stop and state.home_on_connect,
      do: {state, [{:update_axis, %{startup_reference: :home_on_connect}}]},
      else: {%{state | step: :done}, []}
  end

  defp result(state, :complete_commissioning, error), do: {%{state | error: reason(error)}, []}
  defp result(state, :recover, :ok), do: {state, []}
  defp result(state, :recover, error), do: {%{state | error: reason(error)}, []}
  defp result(state, _effect, _result), do: {state, []}

  defp leave_failed(state, error),
    do: %{state | closed: false, error: state.error || {:leave_failed, reason(error)}}

  defp reason({:error, reason}), do: reason
  defp reason(other), do: other

  defp motion_attrs?(attrs),
    do: Enum.any?(Map.keys(attrs), &(&1 not in [:name, :startup_reference]))

  # ---------------------------------------------------------------- observations

  defp observe(%{step: :done} = state), do: {state, []}

  defp observe(%{interrupted: %{} = interrupted} = state) do
    if recovered?(state.obs),
      do: resume(state, interrupted),
      else:
        {%{
           state
           | interrupted: %{interrupted | reason: reason_now(state.obs, interrupted.reason)}
         }, []}
  end

  defp observe(%{step: step} = state) when step in [:prerequisites, :applying],
    do: settle(state)

  defp observe(%{obs: obs} = state) do
    cond do
      obs.lifecycle == :disconnected ->
        interrupt(state, :disconnected)

      obs.lifecycle in [:fault, :unsupported] or obs.fault != :none ->
        interrupt(state, {:fault, obs.fault})

      true ->
        settle(state)
    end
  end

  defp interrupt(state, reason),
    do:
      {%{
         state
         | interrupted: %{reason: reason, step: state.step},
           pending: nil,
           token: nil,
           claiming: false
       }, []}

  defp reason_now(%Observation{lifecycle: :disconnected}, _), do: :disconnected

  defp reason_now(%Observation{lifecycle: lifecycle, fault: fault}, _)
       when lifecycle in [:fault, :unsupported] or fault != :none,
       do: {:fault, fault}

  defp reason_now(_, current), do: current

  defp recovered?(%Observation{} = obs),
    do:
      obs.lifecycle in [:awaiting_reference, :ready] and obs.config_applied? and
        obs.fault == :none

  # After a disconnect or fault the position is no longer trusted, so go back to the point
  # where the reference is set and return to the interrupted step afterwards.
  defp resume(state, %{step: step}) do
    state = %{state | interrupted: nil, info: :reconnected}
    state = if step in @needs_reference, do: %{state | step: :align, return_to: step}, else: state
    claim(state)
  end

  defp settle(state) do
    {state, e1} = claim_if_needed(state)
    {state, e2} = complete_pending(state)
    {state, e3} = check_reference_lost(state)
    {state, e4} = check_applied(state)
    {state, e1 ++ e2 ++ e3 ++ e4}
  end

  defp claim_if_needed(%{step: step} = state) when step in [:prerequisites, :applying, :done],
    do: {state, []}

  defp claim_if_needed(%{claim_blocked: true} = state), do: {state, []}

  defp claim_if_needed(%{obs: obs} = state) when obs.lifecycle in [:awaiting_reference, :ready] do
    cond do
      state.token == nil -> claim(state)
      not obs.lease_held? -> claim(%{state | token: nil, pending: nil})
      true -> {state, []}
    end
  end

  defp claim_if_needed(state), do: {state, []}

  defp complete_pending(%{pending: nil} = state), do: {state, []}

  defp complete_pending(%{pending: %{kind: :reference, position: position}, obs: obs} = state) do
    if obs.ready and stationary?(obs) and obs.position == position,
      do: motion_done(%{state | pending: nil}),
      else: {state, []}
  end

  defp complete_pending(%{pending: %{kind: :move, target: target}, obs: obs} = state) do
    if not obs.pending? and obs.state == :idle and obs.known and obs.position == target,
      do: motion_done(%{state | pending: nil}),
      else: {state, []}
  end

  defp complete_pending(%{pending: %{kind: :home} = pending, obs: obs} = state) do
    pending = if obs.state == :homing or obs.pending?, do: %{pending | seen: true}, else: pending
    state = %{state | pending: pending}

    if pending.seen and not obs.pending? and obs.state == :idle and obs.ready,
      do: motion_done(%{state | pending: nil}),
      else: {state, []}
  end

  defp check_reference_lost(%{pending: nil, step: step, obs: obs, token: token} = state)
       when step in @needs_reference and token != nil do
    if obs.ready or obs.state in [:moving, :homing] or obs.pending?,
      do: {state, []},
      else: {%{state | step: :align, return_to: step, info: :reference_lost}, []}
  end

  defp check_reference_lost(state), do: {state, []}

  defp check_applied(%{step: :applying, obs: obs} = state) do
    if obs.config_applied? and state.after_apply != nil,
      do: apply_done(state),
      else: {state, []}
  end

  defp check_applied(state), do: {state, []}

  defp apply_done(%{after_apply: {:prerequisites, _}} = state),
    do: {%{state | after_apply: nil, step: :prerequisites}, []}

  defp apply_done(%{after_apply: {step, detail}} = state) do
    home = if step == :home_run, do: %{state.home | phase: detail}, else: state.home
    state = %{state | after_apply: nil, token: nil, claiming: false, home: home, step: step}
    claim(state)
  end

  # A finished motion advances the step that asked for it.
  defp motion_done(%{step: :align} = state),
    do: enter(%{state | return_to: nil, info: nil}, state.return_to || :jog_test)

  defp motion_done(%{step: :home_run, home: %{phase: :first}} = state),
    do: enter(state, :home_nudge)

  defp motion_done(%{step: :home_run} = state), do: enter(state, :home_confirm)
  defp motion_done(state), do: {state, []}

  # ---------------------------------------------------------------- step entry

  defp enter(state, :mark), do: begin_mark(%{state | step: :mark})

  defp enter(state, :verify_zero) do
    state = %{state | step: :verify_zero}
    first = hd(state.points)
    if state.obs.position == first.position, do: {state, []}, else: move(state, first.position)
  end

  defp enter(state, :verify_mid) do
    {value, target} = mid_target(state)
    state = %{state | step: :verify_mid, current: %{value: value, estimate: target, blocked: nil}}
    if state.obs.position == target, do: {state, []}, else: move(state, target)
  end

  defp enter(state, step), do: {%{state | step: step}, []}

  defp move(state, target),
    do:
      {%{state | pending: %{kind: :move, target: target}},
       [{:command, :move_to, %{position: target}}]}

  # ---------------------------------------------------------------- marks

  defp parse_range(%{"min" => min, "max" => max} = params), do: parse_range(params, min, max)
  defp parse_range(%{min: min, max: max} = params), do: parse_range(params, min, max)
  defp parse_range(_), do: {:error, :invalid_range}

  defp parse_range(params, min, max) do
    unit = to_unit(Map.get(params, "unit", Map.get(params, :unit)))
    count = to_int(Map.get(params, "marks", Map.get(params, :marks, @default_marks)))

    with {:ok, min} <- to_number(min),
         {:ok, max} <- to_number(max),
         true <- max > min,
         true <- is_integer(count) and count in 1..30,
         true <- unit != nil do
      {:ok, %{min: Float.round(min, 2), max: Float.round(max, 2), unit: unit, count: count}}
    else
      _ -> {:error, :invalid_range}
    end
  end

  defp to_unit(unit) when unit in [:raw, :mps, :kmh, :mph], do: unit
  defp to_unit(unit) when unit in ["raw", "mps", "kmh", "mph"], do: String.to_existing_atom(unit)
  defp to_unit(_), do: nil

  defp to_int(n) when is_integer(n), do: n

  defp to_int(n) when is_binary(n) do
    case Integer.parse(n) do
      {i, ""} -> i
      _ -> nil
    end
  end

  defp to_int(_), do: nil

  defp to_number(n) when is_number(n), do: {:ok, n * 1.0}

  defp to_number(n) when is_binary(n) do
    case Float.parse(n) do
      {f, ""} -> {:ok, f}
      _ -> :error
    end
  end

  defp to_number(_), do: :error

  # With a hand-aligned reference the lowest mark is already measured at the reference.
  # An internal-stop axis has no hand alignment, so its lowest mark is measured like the rest.
  defp seed_points(%{axis: %{reference_strategy: :host_reference} = axis}, range),
    do: [%{value: range.min, position: axis.home_position}]

  defp seed_points(_, _), do: []

  defp marks_for(%{axis: %{reference_strategy: :host_reference}}, range),
    do: mark_values(range.min, range.max, range.count)

  defp marks_for(_, range), do: [range.min | mark_values(range.min, range.max, range.count)]

  defp begin_mark(%{mark_index: index, marks: marks} = state) when index >= length(marks),
    do: enter(%{state | current: nil}, :save_dial)

  defp begin_mark(state) do
    value = Enum.at(state.marks, state.mark_index)

    estimate =
      case state.points do
        [] -> state.obs.position || state.axis.home_position
        points -> estimate_position(points, value, state.axis, state.range)
      end

    current = %{value: value, estimate: max(estimate, state.axis.min_position), blocked: nil}

    if estimate > state.axis.max_position,
      do: {%{state | current: %{current | blocked: %{needed: estimate}}}, []},
      else: move_to_estimate(%{state | current: current})
  end

  defp move_to_estimate(%{current: %{estimate: estimate}} = state) do
    if state.obs.position == estimate, do: {state, []}, else: move(state, estimate)
  end

  defp nudge(state, delta) when is_integer(delta) do
    obs = state.obs

    with true <- stationary?(obs),
         {:ok, target} <- nudge_target(state.axis, obs.position, delta) do
      {%{state | pending: %{kind: :move, target: target}}, [{:command, :jog, %{delta: delta}}]}
    else
      {:error, :outside_limits, target} -> outside_limits(state, target)
      _ -> {%{state | error: :needs_fresh_stationary_position}, []}
    end
  end

  defp nudge(state, _), do: {%{state | error: :invalid_number}, []}

  # Only the top mark can legitimately need more travel than the soft limit allows.
  defp outside_limits(%{step: :mark, current: current} = state, target) do
    if target > state.axis.max_position and state.mark_index == length(state.marks) - 1,
      do:
        {%{state | current: %{current | blocked: %{needed: target}}, error: :outside_limits}, []},
      else: {%{state | error: :outside_limits}, []}
  end

  defp outside_limits(state, _), do: {%{state | error: :outside_limits}, []}

  defp capture(state, reading) do
    obs = state.obs

    with {:ok, value} <- to_number(reading),
         true <- stationary?(obs),
         value = Float.round(value, 2),
         point = %{value: value, position: obs.position},
         :ok <- validate_point(state.points, point) do
      points = state.points ++ [point]
      begin_mark(%{state | points: points, mark_index: state.mark_index + 1})
    else
      :error -> {%{state | error: :invalid_number}, []}
      {:error, reason} -> {%{state | error: reason}, []}
      false -> {%{state | error: :needs_fresh_stationary_position}, []}
    end
  end

  defp validate_point([], _), do: :ok

  defp validate_point(points, point) do
    last = List.last(points)

    cond do
      point.value <= last.value -> {:error, :value_not_increasing}
      point.position <= last.position -> {:error, :needle_not_advanced}
      true -> :ok
    end
  end

  defp stationary?(%Observation{} = obs),
    do:
      obs.known and obs.state == :idle and is_integer(obs.position) and not obs.pending? and
        is_integer(obs.age_ms) and obs.age_ms < @fresh_ms

  defp dial_attrs(state, reviewed) do
    %{output_unit: state.range.unit, points: state.points, reviewed: reviewed}
  end

  defp top_position(state),
    do: state.points |> Enum.map(& &1.position) |> Enum.max(fn -> state.axis.max_position end)

  defp mid_target(state) do
    points = state.points
    index = max(div(length(points), 2), 1)
    a = Enum.at(points, index - 1)
    b = Enum.at(points, index)
    value = Float.round((a.value + b.value) / 2, 2)

    calibration = %DialCalibration{
      output_unit: state.range.unit,
      points: Enum.map(points, &%DialPoint{value: &1.value, position: &1.position})
    }

    {:ok, mapped} = GaugeMapper.dial_target(calibration, value, :clamp)
    {value, mapped.target}
  end

  # ---------------------------------------------------------------- reconfiguration

  # Changing a motion setting needs Apply, and Apply drops the reference, so the user is
  # sent back to realign (or home) before the interrupted step resumes. For `:align`,
  # `detail` is the step to return to afterwards.
  defp reconfigure(state, attrs, next, detail) do
    return_to = if next == :align, do: detail
    {%{state | after_apply: {next, detail}, return_to: return_to}, [{:update_axis, attrs}]}
  end

  # ---------------------------------------------------------------- prerequisites

  @doc "Unmet prerequisites as atoms: `:device`, `:firmware`, `:applied`, `:idle_hold`, `:wiring`."
  @spec prerequisites(t()) :: [atom()]
  def prerequisites(%__MODULE__{obs: obs} = state) do
    [
      {:device, obs.lifecycle != :disconnected},
      {:firmware, obs.lifecycle != :unsupported},
      {:applied, obs.config_applied?},
      {:idle_hold, state.axis.idle_behavior == :hold},
      {:wiring, state.wiring_confirmed}
    ]
    |> Enum.reject(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Steps shown in the progress bar: `{key, label}`."
  def progress do
    [
      {:prerequisites, "Check"},
      {:direction, "Direction"},
      {:calibrate, "Dial"},
      {:verify, "Verify"},
      {:homing, "Homing"},
      {:finish, "Finish"}
    ]
  end

  @doc "The progress group a step belongs to."
  def group(step) when step in [:prerequisites, :applying], do: :prerequisites
  def group(step) when step in [:align, :jog_test], do: :direction
  def group(step) when step in [:range, :mark, :save_dial], do: :calibrate
  def group(step) when step in [:verify_zero, :verify_mid], do: :verify
  def group(step) when step in [:homing_offer, :home_run, :home_nudge, :home_confirm], do: :homing
  def group(_), do: :finish
end
