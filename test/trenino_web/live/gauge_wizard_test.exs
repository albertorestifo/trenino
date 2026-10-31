defmodule TreninoWeb.GaugeWizardTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.{Hardware, Train}
  alias Trenino.Hardware.StepperManager

  setup :set_mimic_global

  # A fake device behind StepperManager: the LiveView reads real-looking snapshots and every
  # command is recorded, so the test sees exactly what the page asked the hardware to do.
  setup %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, fake} =
      Agent.start_link(fn ->
        %{
          lifecycle: :awaiting_reference,
          ready: false,
          position: 0,
          lease: false,
          log: [],
          axis: axis,
          config_axis: axis
        }
      end)

    stub(Hardware, :apply_saved_configuration, fn device_id ->
      {:ok, fresh} = Hardware.get_stepper_axis(axis.id)

      Agent.update(fake, fn state ->
        record(%{state | config_axis: fresh, ready: false, lease: false}, {:apply, device_id})
      end)

      {:ok, 1}
    end)

    stub(StepperManager, :snapshot, fn _ -> snapshot(fake) end)

    stub(StepperManager, :claim_manual, fn _, _ ->
      Agent.update(fake, &record(%{&1 | lease: true}, :claim))
      {:ok, make_ref()}
    end)

    stub(StepperManager, :release_manual, fn _, _ ->
      Agent.update(fake, &record(%{&1 | lease: false}, :release))
      :ok
    end)

    stub(StepperManager, :resume, fn _ ->
      Agent.update(fake, &record(&1, :resume))
      :ok
    end)

    stub(StepperManager, :command, fn _, op, params, _ ->
      Agent.update(fake, &command(&1, op, params))
      {:ok, :accepted}
    end)

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    %{view: view, axis: axis, device: device, fake: fake, id: "gauge-wizard-#{axis.id}"}
  end

  defp record(state, entry), do: %{state | log: [entry | state.log]}

  defp command(state, :reference, %{position: p}),
    do: record(%{state | ready: true, position: p}, {:reference, p})

  defp command(state, :jog, %{delta: d}),
    do: record(%{state | position: state.position + d}, {:jog, d})

  defp command(state, :move_to, %{position: p}),
    do: record(%{state | position: p}, {:move_to, p})

  defp command(state, op, _), do: record(state, op)

  defp snapshot(fake) do
    state = Agent.get(fake, & &1)
    {:ok, axis} = Hardware.get_stepper_axis(state.axis.id)

    runtime = %{
      ready: state.ready,
      status:
        if state.ready do
          %{
            state: :idle,
            known: true,
            position: state.position,
            fault: :none,
            reference_kind: :host
          }
        end,
      pending: nil,
      updated_at: System.monotonic_time(:millisecond),
      lease: if(state.lease, do: %{owner: :ui, expires_in_ms: nil, finishing_motion: false}),
      config: state.config_axis,
      paused: state.lease,
      error: nil
    }

    %{lifecycle: state.lifecycle, axes: %{axis.id => runtime}}
  end

  defp log(fake), do: fake |> Agent.get(& &1.log) |> Enum.reverse()

  defp open(view, axis), do: view |> element("#stepper-wizard-open-#{axis.id}") |> render_click()

  defp click(view, selector), do: view |> element(selector) |> render_click()

  test "the axis card offers the guided setup and nothing moves on open", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    assert has_element?(view, "#stepper-wizard-open-#{axis.id}", "Guided gauge setup")
    open(view, axis)
    assert has_element?(view, "##{id}-step-prerequisites")
    assert has_element?(view, "##{id}-checklist", "Controller connected")
    assert log(fake) == []
  end

  test "the checklist gates Continue and never mentions leases", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    html = open(view, axis)
    refute html =~ ~r/lease/i
    assert has_element?(view, "button##{id}-continue[disabled]")

    view |> form("##{id}-wiring-form", %{"wiring" => "true"}) |> render_change()
    refute has_element?(view, "button##{id}-continue[disabled]")
    refute log(fake) |> Enum.any?(&(&1 == :claim))

    click(view, "##{id}-continue")
    assert has_element?(view, "##{id}-step-align")
    assert :claim in log(fake)
    refute render(view) =~ ~r/lease/i
  end

  test "reference, direction check and range lead to the first mark", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    open(view, axis)
    view |> form("##{id}-wiring-form", %{"wiring" => "true"}) |> render_change()
    click(view, "##{id}-continue")

    click(view, "##{id}-set-reference")
    assert has_element?(view, "##{id}-step-jog_test")
    assert {:reference, 0} in log(fake)

    click(view, "##{id}-jog")
    assert {:jog, 20} in log(fake)
    assert has_element?(view, "##{id}-direction-question", "Did the needle move up the dial?")

    click(view, "##{id}-yes")
    assert has_element?(view, "##{id}-range-form")

    view
    |> form("##{id}-range-form", range: %{min: "0", max: "100", unit: "mph", marks: "5"})
    |> render_submit()

    assert has_element?(view, "##{id}-step-mark", "Mark 1 of 5: 20 mph")
    assert {:move_to, 144} in log(fake)
    assert has_element?(view, "##{id}-capture-form")

    click(view, "##{id}-nudge-1")
    assert {:jog, 1} in log(fake)

    view |> form("##{id}-capture-form", %{"reading" => "20"}) |> render_submit()
    assert has_element?(view, "##{id}-step-mark", "Mark 2 of 5: 40 mph")
  end

  test "answering no to the direction question flips the setting", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    open(view, axis)
    view |> form("##{id}-wiring-form", %{"wiring" => "true"}) |> render_change()
    click(view, "##{id}-continue")
    click(view, "##{id}-set-reference")
    click(view, "##{id}-jog")
    click(view, "##{id}-no")

    assert {:ok, %{reverse: true}} = Hardware.get_stepper_axis(axis.id)
    assert {:apply, axis.device_id} in log(fake)
    assert has_element?(view, "##{id}-step-align")
    assert has_element?(view, "##{id}-flipped", "line it up again")
    refute log(fake) |> Enum.any?(&(&1 == :resume))
  end

  test "a disconnect shows a plain explanation and waits for the device", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    open(view, axis)
    view |> form("##{id}-wiring-form", %{"wiring" => "true"}) |> render_change()
    click(view, "##{id}-continue")
    click(view, "##{id}-set-reference")

    Agent.update(fake, &%{&1 | lifecycle: :disconnected, ready: false})
    send_update_for_test(view, axis)

    assert has_element?(view, "##{id}-interrupted", "controller was disconnected")
    refute has_element?(view, "##{id}-recover")
  end

  test "closing hands the gauge back and resumes train control only when commissioned", %{
    view: view,
    axis: axis,
    id: id,
    fake: fake
  } do
    open(view, axis)
    view |> form("##{id}-wiring-form", %{"wiring" => "true"}) |> render_change()
    click(view, "##{id}-continue")

    click(view, "##{id}-close")
    assert :release in log(fake)
    refute :resume in log(fake)
    refute has_element?(view, "##{id}")
    assert has_element?(view, "#stepper-wizard-open-#{axis.id}")
  end

  test "the wizard can be opened for an axis that trains already use", %{
    view: view,
    axis: axis,
    id: id
  } do
    {:ok, train} = Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "C323"}]})

    {:ok, _} =
      Train.create_gauge_binding(train.id, %{
        name: "Speed",
        endpoint: "x",
        stepper_axis_id: axis.id
      })

    assert [%{train: %{name: "Class 323"}}] = Train.list_gauge_bindings_for_axis(axis.id)
    open(view, axis)
    assert has_element?(view, "##{id}")
  end

  # The parent LiveView forwards device updates to the axis card, which re-renders the wizard.
  defp send_update_for_test(view, axis) do
    send(view.pid, {:stepper_updated, axis.device_id, %{lifecycle: :disconnected, axes: %{}}})
    render(view)
  end
end
