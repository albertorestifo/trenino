defmodule Trenino.Hardware.GaugeWizardTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware.GaugeWizard
  alias Trenino.Hardware.GaugeWizard.Observation
  alias Trenino.Hardware.StepperAxis

  # A tiny stand-in for the device: a needle whose dial reads position / 6.8, applied
  # configuration, a reference flag and a manual-control flag. Moves finish instantly; tests
  # that care about waiting feed their own observations.
  defmodule Sim do
    @moduledoc false
    defstruct axis: nil,
              position: 0,
              ready: false,
              lifecycle: :awaiting_reference,
              lease?: false,
              applied?: true,
              fault: :none,
              busy: nil,
              log: [],
              saved: []

    @per_unit 6.8

    def new(attrs \\ %{}) do
      axis =
        struct(
          StepperAxis,
          Map.merge(%{id: 1, device_id: 1, name: "Speed", max_position: 720}, attrs)
        )

      %__MODULE__{axis: axis}
    end

    # The device finishes whatever it was doing and settles at the home position.
    def finish(%__MODULE__{busy: :homing} = s),
      do: %{s | busy: nil, ready: true, position: s.axis.home_position}

    def finish(s), do: s

    def dial(%__MODULE__{position: p}), do: Float.round(p / @per_unit, 2)

    def observation(%__MODULE__{} = s) do
      %Observation{
        lifecycle: s.lifecycle,
        ready: s.ready and s.busy == nil,
        state: if(s.busy, do: s.busy, else: if(s.ready, do: :idle)),
        known: s.ready or s.busy != nil,
        position: if(s.ready, do: s.position),
        fault: s.fault,
        age_ms: 10,
        lease_held?: s.lease?,
        config_applied?: s.applied? and s.lifecycle in [:awaiting_reference, :ready]
      }
    end

    def run({:command, op, params} = effect, s) do
      s = %{s | log: [effect | s.log]}

      case {op, params} do
        {:reference, %{position: p}} -> {{:ok, :accepted}, %{s | ready: true, position: p}}
        {:jog, %{delta: d}} -> {{:ok, :accepted}, %{s | position: s.position + d}}
        {:move_to, %{position: p}} -> {{:ok, :accepted}, %{s | position: p}}
        {:home, _} -> {{:ok, :accepted}, %{s | busy: :homing}}
        {:stop, _} -> {{:ok, :accepted}, s}
      end
    end

    def run(:claim, s), do: {{:ok, make_ref()}, %{s | lease?: true, log: [:claim | s.log]}}

    def run(:apply, s),
      do: {{:ok, 1}, %{s | applied?: true, ready: false, lease?: false, log: [:apply | s.log]}}

    def run({:update_axis, attrs} = effect, s) do
      axis = struct(s.axis, attrs)
      motion? = Enum.any?(Map.keys(attrs), &(&1 not in [:name, :startup_reference]))
      axis = if motion?, do: %{axis | commissioned: false}, else: axis

      {{:ok, axis},
       %{s | axis: axis, applied?: s.applied? and not motion?, log: [effect | s.log]}}
    end

    def run({:save_dial, attrs} = effect, s),
      do: {{:ok, :calibration}, %{s | saved: [attrs | s.saved], log: [effect | s.log]}}

    def run(:complete_commissioning, s) do
      axis = %{s.axis | commissioned: true}
      {{:ok, axis}, %{s | axis: axis, log: [:complete_commissioning | s.log]}}
    end

    def run(effect, s), do: {:ok, %{s | log: [effect | s.log]}}
  end

  # Feed an event, run its effects against the sim, feed results and fresh observations
  # until nothing more is requested.
  defp send_event({wizard, sim}, event), do: settle(GaugeWizard.update(wizard, event), sim)

  defp observe({wizard, sim}),
    do: settle(GaugeWizard.update(wizard, {:observed, Sim.observation(sim)}), sim)

  defp settle({wizard, effects}, sim) do
    {wizard, sim, more} =
      Enum.reduce(effects, {wizard, sim, []}, fn effect, {w, s, acc} ->
        {result, s} = Sim.run(effect, s)
        {w, eff} = GaugeWizard.update(w, {:result, effect, result})
        {w, s, acc ++ eff}
      end)

    wizard = %{wizard | axis: sim.axis}
    {wizard, observed} = GaugeWizard.update(wizard, {:observed, Sim.observation(sim)})

    # a homing sweep is seen in progress first, then seen finished
    {wizard, finished} =
      if sim.busy,
        do: GaugeWizard.update(wizard, {:observed, Sim.observation(Sim.finish(sim))}),
        else: {wizard, []}

    case more ++ observed ++ finished do
      [] -> {wizard, Sim.finish(sim)}
      pending -> settle({wizard, pending}, Sim.finish(sim))
    end
  end

  defp start(attrs \\ %{}) do
    sim = Sim.new(attrs)
    observe({GaugeWizard.new(sim.axis), sim})
  end

  defp to_align(attrs \\ %{}) do
    attrs |> start() |> send_event({:confirm_wiring, true}) |> send_event(:continue)
  end

  defp to_jog_test(attrs \\ %{}), do: attrs |> to_align() |> send_event(:set_reference)

  defp to_range(attrs \\ %{}) do
    attrs |> to_jog_test() |> send_event(:jog_up) |> send_event({:answer, :yes})
  end

  @range %{"min" => "0", "max" => "100", "unit" => "mph", "marks" => "5"}

  defp step({wizard, _}), do: wizard.step

  # The user nudges until the needle reads within half a unit of the mark, then captures
  # what the dial really reads.
  defp measure_mark({wizard, sim} = pair) do
    target = wizard.current.value

    if abs(Sim.dial(sim) - target) < 0.5 do
      send_event(pair, {:capture, Sim.dial(sim)})
    else
      delta = if Sim.dial(sim) < target, do: 1, else: -1
      pair |> send_event({:nudge, delta}) |> measure_mark()
    end
  end

  defp measure_all(pair) do
    if step(pair) == :mark, do: pair |> measure_mark() |> measure_all(), else: pair
  end

  defp to_verify(attrs \\ %{}) do
    attrs
    |> to_range()
    |> send_event({:set_range, @range})
    |> measure_all()
    |> send_event(:save_dial)
  end

  defp to_homing_offer do
    to_verify() |> send_event({:answer, :yes}) |> send_event({:answer, :yes})
  end

  describe "helpers" do
    test "mark_values spaces marks evenly and ends on the maximum" do
      assert GaugeWizard.mark_values(0, 100, 5) == [20.0, 40.0, 60.0, 80.0, 100.0]
      assert GaugeWizard.mark_values(0, 100, 4) == [25.0, 50.0, 75.0, 100.0]
    end

    test "the first estimate spreads the axis travel over the dial, later ones use the last slope" do
      axis = %StepperAxis{max_position: 720}
      range = %{min: 0.0, max: 100.0}

      assert GaugeWizard.estimate_position([%{value: 0.0, position: 0}], 20.0, axis, range) ==
               144

      points = [%{value: 0.0, position: 0}, %{value: 20.0, position: 136}]
      assert GaugeWizard.estimate_position(points, 40.0, axis, range) == 272
      assert GaugeWizard.slope(points) == 6.8
    end

    test "backoff is the previous backoff plus the nudge distance" do
      assert GaugeWizard.backoff_from_nudge(10, 0, 253) == {:ok, 263}
      assert GaugeWizard.backoff_from_nudge(263, 0, 0) == {:ok, 263}
      assert GaugeWizard.backoff_from_nudge(10, 5, 2) == {:error, :not_nudged}
    end

    test "home plan keeps speed 50 and a timeout the axis validator accepts" do
      axis = %StepperAxis{max_position: 720, max_speed: 100, home_position: 0, home_steps: 2000}

      assert {:ok, attrs, []} = GaugeWizard.home_plan(axis, 680, 263)
      assert attrs.reference_strategy == :internal_stop
      assert attrs.home_speed == 50
      assert attrs.home_steps >= 720 + 263
      assert attrs.home_timeout_ms > ceil(1000 * (attrs.home_steps + 263) / 50) + 500

      cs =
        StepperAxis.changeset(
          %StepperAxis{device_id: 1},
          axis |> Map.from_struct() |> Map.merge(%{name: "x"}) |> Map.merge(attrs)
        )

      refute Keyword.has_key?(cs.errors, :home_timeout_ms)
    end

    test "a sweep that is too small is warned about and fixed" do
      axis = %StepperAxis{max_position: 720, max_speed: 100, home_position: 0, home_steps: 300}
      assert {:ok, attrs, [:sweep_too_small]} = GaugeWizard.home_plan(axis, 700, 263)
      assert attrs.home_steps > 300
    end

    test "a sweep that cannot finish within the longest allowed timeout is refused" do
      axis = %StepperAxis{max_position: 60_000, max_speed: 50, home_position: 0}
      assert {:error, :sweep_too_long} = GaugeWizard.home_plan(axis, 60_000, 100)
    end

    test "nudges respect the soft limits" do
      axis = %StepperAxis{min_position: 0, max_position: 100}
      assert {:ok, 90} = GaugeWizard.nudge_target(axis, 80, 10)
      assert {:error, :outside_limits, 110} = GaugeWizard.nudge_target(axis, 100, 10)
      assert {:error, :outside_limits, -1} = GaugeWizard.nudge_target(axis, 0, -1)
    end

    test "observation reads real snapshot data" do
      axis = %StepperAxis{id: 1, axis_index: 0}
      status = %{state: :moving, known: true, position: 40, fault: :none, reference_kind: :host}

      runtime = %{
        ready: true,
        status: status,
        pending: nil,
        updated_at: 900,
        lease: %{owner: :ui},
        config: axis
      }

      snapshot = %{lifecycle: :ready, axes: %{1 => runtime}}
      obs = GaugeWizard.observation(snapshot, axis, 1000)

      assert %Observation{
               state: :moving,
               position: 40,
               age_ms: 100,
               lease_held?: true,
               config_applied?: true
             } = obs

      refute GaugeWizard.observation(%{snapshot | lifecycle: :disconnected}, axis, 1000).config_applied?
    end
  end

  describe "prerequisites" do
    test "nothing is claimed until device, applied configuration and wiring are confirmed" do
      {w, s} = start()
      assert w.step == :prerequisites
      assert GaugeWizard.prerequisites(w) == [:wiring]

      {w, s} = send_event({w, s}, :continue)
      assert w.step == :prerequisites
      assert w.error == :prerequisites_missing
      refute :claim in s.log
    end

    test "an unapplied configuration is listed and Apply is offered" do
      sim = %{Sim.new() | applied?: false}
      {w, s} = observe({GaugeWizard.new(sim.axis), sim})
      assert :applied in GaugeWizard.prerequisites(w)

      {w, s} = send_event({w, s}, :apply)
      assert :apply in s.log
      assert :applied not in GaugeWizard.prerequisites(w)
    end

    test "a disconnected device blocks continuing" do
      sim = %{Sim.new() | lifecycle: :disconnected}
      {w, _} = observe({GaugeWizard.new(sim.axis), sim})
      assert :device in GaugeWizard.prerequisites(w)
    end

    test "an axis that releases when idle is offered the hold setting" do
      {w, s} = start(%{idle_behavior: :release})
      assert :idle_hold in GaugeWizard.prerequisites(w)

      {w, s} = send_event({w, s}, :fix_idle_hold)
      assert w.step == :prerequisites
      assert s.axis.idle_behavior == :hold
      assert :idle_hold not in GaugeWizard.prerequisites(w)
    end

    test "the 0x70 warning is carried for display" do
      assert GaugeWizard.new(%StepperAxis{}, "careful").warning == "careful"
    end

    test "continuing takes manual control and moves to alignment without moving the motor" do
      {w, s} = to_align()
      assert w.step == :align
      assert w.token
      assert Enum.all?(s.log, &(&1 == :claim))
    end
  end

  describe "direction" do
    test "set reference then jog waits for real status before asking" do
      {w, s} = to_align() |> send_event(:set_reference)
      assert w.step == :jog_test

      {w, effects} = GaugeWizard.update(w, :jog_up)
      assert [{:command, :jog, %{delta: 20}}] = effects
      assert w.pending == %{kind: :move, target: 20}
      assert GaugeWizard.stop_visible?(w)

      moving = Map.put(Sim.observation(%{s | position: 8}), :state, :moving)
      {w, _} = GaugeWizard.update(w, {:observed, moving})
      assert w.pending
      assert GaugeWizard.moving?(w)

      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(%{s | position: 20})})
      assert w.pending == nil
    end

    test "answering no flips the direction, applies, and sends the user back to realign" do
      {w, s} = to_jog_test() |> send_event(:jog_up)
      assert w.step == :jog_test

      {w, s} = send_event({w, s}, {:answer, :no})
      assert s.axis.reverse
      assert :apply in s.log
      assert w.step == :align
      assert w.return_to == :jog_test
      assert w.flips == 1
      refute s.ready

      {w, s} = send_event({w, s}, :set_reference)
      assert w.step == :jog_test

      {w, s} = send_event({w, s}, :jog_up)
      {w, s} = send_event({w, s}, {:answer, :no})
      assert w.flips == 2
      refute s.axis.reverse
      assert w.step == :align

      {w, s} = send_event({w, s}, :set_reference)
      {w, s} = send_event({w, s}, :jog_up)
      {w, _} = send_event({w, s}, {:answer, :yes})
      assert w.step == :range
    end

    test "events during a pending motion are refused as busy" do
      {w, _s} = to_jog_test()
      {w, _} = GaugeWizard.update(w, :jog_up)
      assert {%{error: :busy}, []} = GaugeWizard.update(w, {:answer, :yes})
    end
  end

  describe "calibration" do
    test "an invalid range is refused" do
      {w, s} = to_range()
      {w, _} = send_event({w, s}, {:set_range, %{"min" => "50", "max" => "10", "unit" => "mph"}})
      assert w.step == :range
      assert w.error == :invalid_range
    end

    test "measures every mark, using the first mark to estimate later ones" do
      {w, s} = to_verify()
      assert w.step == :verify_zero
      [attrs] = s.saved
      assert attrs.reviewed == false
      assert attrs.output_unit == :mph
      assert length(attrs.points) == 6
      assert hd(attrs.points) == %{value: 0.0, position: 0}

      moves = for {:command, :move_to, %{position: p}} <- Enum.reverse(s.log), do: p
      assert length(moves) >= 5

      # moves to the 20..100 marks come first, then the verification moves
      ideal = [136, 272, 408, 544, 680]
      later = Enum.zip(Enum.drop(moves, 1), Enum.drop(ideal, 1))

      assert Enum.all?(later, fn {estimate, truth} ->
               abs(estimate - truth) <= truth * 0.02 + 2
             end)
    end

    test "capture needs a stationary, fresh position" do
      {w, s} = to_range()
      {w, _} = send_event({w, s}, {:set_range, @range})
      {w, _} = GaugeWizard.update(w, {:observed, Map.put(w.obs, :age_ms, 5000)})
      {w, _} = GaugeWizard.update(w, {:capture, 20})
      assert w.error == :needs_fresh_stationary_position
    end

    test "capture rejects a needle that did not advance" do
      {w, s} = to_range()
      {w, s} = send_event({w, s}, {:set_range, @range})
      {w, s} = send_event({w, s}, {:nudge, -w.obs.position})
      {w, _} = send_event({w, s}, {:capture, 20})
      assert w.error == :needle_not_advanced
    end

    test "nudges stay within soft limits" do
      {w, s} = to_range(%{max_position: 100})
      {w, s} = send_event({w, s}, {:set_range, %{@range | "max" => "10", "marks" => "2"}})
      {w, s} = send_event({w, s}, {:nudge, 10_000})
      assert w.error == :outside_limits
      refute w.pending
      refute Enum.any?(s.log, &match?({:command, :jog, %{delta: 10_000}}, &1))
    end

    test "when the top mark is out of reach the user may extend the travel" do
      {w, s} = to_range(%{max_position: 100})
      {w, s} = send_event({w, s}, {:set_range, %{@range | "marks" => "1"}})
      assert s.position == 100

      {w, s} = send_event({w, s}, {:nudge, 1})
      assert w.error == :outside_limits
      assert w.current.blocked == %{needed: 101}
      refute Enum.any?(s.log, &match?({:command, :jog, %{delta: 1}}, &1))

      {w, s} = send_event({w, s}, :extend_max)
      assert s.axis.max_position > 100
      assert :apply in s.log
      assert w.step == :align
      assert w.return_to == :mark

      {w, _} = send_event({w, s}, :set_reference)
      assert w.step == :mark
      refute w.current.blocked
    end

    test "saving the dial never moves the motor" do
      {w, s} = to_verify()
      assert w.step == :verify_zero

      # the only command after the save is none: the move to zero was requested by entering the step
      assert match?({:save_dial, _}, Enum.find(s.log, &match?({:save_dial, _}, &1)))
    end
  end

  describe "verification" do
    test "returning to zero is checked; lost steps send the user back to realign" do
      {w, s} = to_verify()
      assert w.step == :verify_zero
      assert s.position == 0

      {w, s} = send_event({w, s}, {:answer, :no})
      assert w.step == :align
      assert w.return_to == :verify_zero
      assert w.lost_steps == 1

      {w, s} = send_event({w, s}, :set_reference)
      assert w.step == :verify_zero
      {w, _} = send_event({w, s}, {:answer, :yes})
      assert w.step == :verify_mid
    end

    test "a mid mark between two measured points is checked and the dial is then reviewed" do
      {w, s} = to_verify() |> send_event({:answer, :yes})
      assert w.step == :verify_mid
      assert w.current.value > 0

      {w, s} = send_event({w, s}, {:answer, :yes})
      assert w.step == :homing_offer
      assert hd(s.saved).reviewed == true
    end

    test "a wrong mid mark offers measuring again" do
      {w, s} = to_verify() |> send_event({:answer, :yes}) |> send_event({:answer, :no})
      assert w.error == :mid_mark_off
      {w, _} = send_event({w, s}, :restart_calibration)
      assert w.step == :range
      assert w.points == []
    end
  end

  describe "automatic homing" do
    test "skipping goes straight to finishing" do
      {w, _} = to_homing_offer() |> send_event(:skip_homing)
      assert w.step == :finish
    end

    test "the backoff is measured by nudging and the final settings are valid" do
      {w, s} = to_homing_offer() |> send_event(:start_homing)
      assert s.axis.reference_strategy == :internal_stop
      assert s.axis.home_speed == 50
      assert s.axis.home_steps >= 720 + 10
      assert w.step == :home_run
      assert w.home.phase == :first

      {w, s} = send_event({w, s}, :home)
      assert w.step == :home_nudge
      assert s.position == 0

      {w, s} = send_event({w, s}, {:nudge, 100})
      {w, s} = send_event({w, s}, {:nudge, 153})
      {w, s} = send_event({w, s}, :finish_nudging)
      assert s.axis.home_backoff == 10 + 253
      assert s.axis.home_timeout_ms > ceil(1000 * (s.axis.home_steps + 263) / 50) + 500
      assert s.axis.home_steps >= 720 + 263
      assert w.step == :home_run
      assert w.home.phase == :second
      assert :apply in s.log

      {w, s} = send_event({w, s}, :home)
      assert w.step == :home_confirm
      {w, s} = send_event({w, s}, {:answer, :yes})
      assert w.step == :finish

      {w, s} = send_event({w, s}, :commission)
      assert :complete_commissioning in s.log
      assert s.axis.commissioned
      assert s.axis.startup_reference == :home_on_connect
      assert w.step == :done
    end

    test "answering no after the second home nudges again from the measured backoff" do
      {w, s} = to_homing_offer() |> send_event(:start_homing) |> send_event(:home)
      {w, s} = send_event({w, s}, {:nudge, 250})
      {w, s} = send_event({w, s}, :finish_nudging)
      {w, s} = send_event({w, s}, :home)
      {w, s} = send_event({w, s}, {:answer, :no})
      assert w.step == :home_nudge
      {w, s} = send_event({w, s}, {:nudge, 13})
      {_, s} = send_event({w, s}, :finish_nudging)
      assert s.axis.home_backoff == 10 + 250 + 13
    end

    test "a too-small sweep is warned about and fixed before homing" do
      {w, s} = to_homing_offer()
      axis = %{s.axis | home_steps: 100}
      {w, s} = send_event({%{w | axis: axis}, %{s | axis: axis}}, :start_homing)
      assert :sweep_too_small in w.home.warnings
      assert s.axis.home_steps > 100
    end

    test "commissioning is only requested through complete_commissioning" do
      {w, s} = to_homing_offer() |> send_event(:skip_homing)
      refute s.axis.commissioned

      {w, s} = send_event({w, s}, :commission)
      assert s.axis.commissioned
      assert w.step == :done
      refute Enum.any?(s.log, &match?({:update_axis, %{commissioned: _}}, &1))
    end

    test "renaming the axis from the wizard" do
      {w, s} = to_homing_offer() |> send_event(:skip_homing)
      {_, s} = send_event({w, s}, {:rename, "Class 323 speedometer"})
      assert s.axis.name == "Class 323 speedometer"
    end
  end

  describe "faults, disconnects and leaving" do
    test "a fault mid-calibration offers recovery and resumes at the same mark" do
      {w, s} = to_range()
      {w, s} = send_event({w, s}, {:set_range, @range})
      {w, s} = measure_mark({w, s})
      assert w.mark_index == 1
      captured = w.points

      s = %{s | lifecycle: :fault, fault: :driver_i2c, ready: false, lease?: false}
      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(s)})
      assert w.interrupted.reason == {:fault, :driver_i2c}
      assert w.interrupted.step == :mark
      assert w.token == nil

      # nothing else is accepted while interrupted, except recover and close
      assert {^w, []} = GaugeWizard.update(w, {:nudge, 1})

      {w, effects} = GaugeWizard.update(w, :recover)
      assert effects == [:recover]

      s = %{s | lifecycle: :awaiting_reference, fault: :none}
      {w, s} = observe({w, s})
      assert w.interrupted == nil
      assert w.step == :align
      assert w.return_to == :mark
      assert w.points == captured

      {w, _} = send_event({w, s}, :set_reference)
      assert w.step == :mark
      assert w.mark_index == 1
    end

    test "a disconnect waits for the device and then resumes" do
      {w, s} = to_jog_test()
      s = %{s | lifecycle: :disconnected, ready: false, lease?: false}
      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(s)})
      assert w.interrupted.reason == :disconnected

      s = %{s | lifecycle: :awaiting_reference}
      {w, s} = observe({w, s})
      assert w.interrupted == nil
      assert w.step == :align
      assert w.return_to == :jog_test
      assert s.lease?
    end

    test "a fault that arrives while disconnected replaces the waiting message with recovery" do
      {w, s} = to_jog_test()
      gone = %{s | lifecycle: :disconnected, ready: false, lease?: false}
      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(gone)})
      assert w.interrupted.reason == :disconnected

      faulted = %{gone | lifecycle: :fault, fault: :unexpected_reset}
      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(faulted)})
      assert w.interrupted.reason == {:fault, :unexpected_reset}
      assert w.interrupted.step == :jog_test
    end

    test "a moving Stop is visible, clears the wait, and loses the reference honestly" do
      {w, s} = to_jog_test()
      {w, _} = GaugeWizard.update(w, :jog_up)
      assert GaugeWizard.stop_visible?(w)

      {w, effects} = GaugeWizard.update(w, :stop)
      assert effects == [{:command, :stop, %{}}]
      assert w.pending == nil

      {w, _} = GaugeWizard.update(w, {:observed, Sim.observation(%{s | ready: false})})
      assert w.step == :align
      assert w.return_to == :jog_test
    end

    test "closing releases manual control and does not resume an axis that is not commissioned" do
      {w, _s} = to_jog_test()
      {w, effects} = GaugeWizard.update(w, :close)
      assert effects == [:release]
      assert w.closed
    end

    test "closing resumes train control when the axis was commissioned" do
      {w, _s} = to_jog_test(%{commissioned: true})
      {_, effects} = GaugeWizard.update(w, :close)
      assert effects == [:release, :resume]
    end

    test "closing before manual control was taken does nothing to the device" do
      {w, _} = start()
      assert {%{closed: true}, []} = GaugeWizard.update(w, :close)
    end

    test "a refused claim is shown and not retried in a loop" do
      {w, s} = start()
      {w, _} = GaugeWizard.update(w, {:confirm_wiring, true})
      {w, [:claim]} = GaugeWizard.update(w, :continue)
      {w, []} = GaugeWizard.update(w, {:result, :claim, {:error, :owned}})
      assert w.error == :owned
      assert {_, []} = GaugeWizard.update(w, {:observed, Sim.observation(s)})
    end
  end
end
