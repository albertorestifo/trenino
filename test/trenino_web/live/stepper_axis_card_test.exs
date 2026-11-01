defmodule TreninoWeb.StepperAxisCardTest do
  @moduledoc """
  The axis card at rest is one name, one state and at most one action. Everything manual
  sits behind "Advanced / manual controls", except the controls the state makes urgent.
  """
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperManager

  setup :set_mimic_global

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)
    test = self()

    # Applied to the device: the page has no "apply needed" state to show.
    fingerprint = Hardware.config_fingerprint([], [], [], Hardware.list_stepper_axes(device.id))
    {:ok, _} = Hardware.confirm_configuration(device.id, device.config_id, fingerprint)

    claim = fn ->
      send(test, :claimed)
      {:ok, make_ref()}
    end

    stub(StepperManager, :claim_manual, fn _, _ -> claim.() end)
    stub(StepperManager, :claim_manual, fn _, _, _ -> claim.() end)

    stub(StepperManager, :command, fn _, op, _, _ ->
      send(test, {:command, op})
      {:ok, :accepted}
    end)

    stub(StepperManager, :resume, fn _ ->
      send(test, :resumed)
      :ok
    end)

    stub(StepperManager, :release_manual, fn _, _ -> :ok end)

    stub(StepperManager, :recover, fn _ ->
      send(test, :recovered)
      :ok
    end)

    %{device: device, axis: axis}
  end

  defp runtime(overrides \\ %{}) do
    Map.merge(
      %{
        ready: true,
        status: %{
          state: :idle,
          known: true,
          position: 0,
          target: 0,
          energized: true,
          fault: :none,
          reference_kind: :host
        },
        pending: nil,
        error: nil,
        paused: false,
        lease: nil,
        updated_at: System.monotonic_time(:millisecond)
      },
      overrides
    )
  end

  defp open_page(conn, device, axis, snapshot) do
    snapshot = Map.put_new(snapshot, :axes, %{axis.id => runtime()})
    stub(StepperManager, :snapshot, fn _ -> snapshot end)
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    view
  end

  # Present on the card face, not only inside the Advanced disclosure.
  defp promoted?(view, axis, name),
    do:
      has_element?(view, "##{name}-#{axis.id}") and
        not has_element?(view, "#stepper-advanced-#{axis.id} ##{name}-#{axis.id}")

  test "a working axis shows its name, Ready and nothing else to do", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    assert has_element?(view, "#stepper-status-#{ctx.axis.id}[role=status]", "Ready")
    refute has_element?(view, "#stepper-next-step-#{ctx.axis.id}")
    refute promoted?(view, ctx.axis, "stepper-stop")
    refute promoted?(view, ctx.axis, "stepper-resume")
    refute promoted?(view, ctx.axis, "stepper-recover")
    refute has_element?(view, "#stepper-wizard-open-#{ctx.axis.id}.btn-primary")

    # The resting view carries no jargon outside the disclosure.
    html = view |> element("#stepper-axis-#{ctx.axis.id}") |> render()
    refute html =~ "x27_six_state"
    refute html =~ "commutation"

    # Every manual control stays reachable inside the disclosure.
    for id <- ~w(claim stop release enable resume recover reference) do
      assert has_element?(view, "#stepper-advanced-#{ctx.axis.id} #stepper-#{id}-#{ctx.axis.id}")
    end

    assert has_element?(view, "#stepper-advanced-#{ctx.axis.id}", "complete commissioning")
  end

  test "Stop is promoted as soon as the needle moves, and one click stops it", ctx do
    moving = runtime(%{status: %{runtime().status | state: :moving}})

    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :ready,
        axes: %{ctx.axis.id => moving}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Moving")
    assert promoted?(view, ctx.axis, "stepper-stop")
    refute has_element?(view, "#stepper-stop-#{ctx.axis.id}[disabled]")

    view |> element("#stepper-stop-#{ctx.axis.id}") |> render_click()
    assert_received :claimed
    assert_received {:command, :stop}
    # Having taken manual control to stop, the operator is told how to hand it back.
    assert promoted?(view, ctx.axis, "stepper-resume")
  end

  test "Stop stays promoted while the operator holds manual control", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    refute promoted?(view, ctx.axis, "stepper-stop")

    view |> element("#stepper-claim-#{ctx.axis.id}") |> render_click()
    assert_received :claimed
    assert promoted?(view, ctx.axis, "stepper-stop")
    assert promoted?(view, ctx.axis, "stepper-resume")
    assert has_element?(view, "#stepper-commissioning-#{ctx.axis.id}", "You have manual control")

    view |> element("#stepper-stop-#{ctx.axis.id}") |> render_click()
    assert_received {:command, :stop}
    refute_received :claimed
  end

  test "Resume train control is promoted when the axis is paused", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :ready,
        axes: %{ctx.axis.id => runtime(%{paused: true})}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Paused")
    assert promoted?(view, ctx.axis, "stepper-resume")
    assert has_element?(view, "#stepper-resume-#{ctx.axis.id}.btn-primary")
    assert has_element?(view, "#stepper-next-step-#{ctx.axis.id}", "Resume train control")

    view |> element("#stepper-resume-#{ctx.axis.id}") |> render_click()
    assert_received :resumed
  end

  test "fault recovery is the primary action when the axis is faulted", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :fault,
        error: :driver_i2c,
        axes: %{ctx.axis.id => runtime(%{ready: false})}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Fault")
    assert has_element?(view, "#stepper-next-step-#{ctx.axis.id}[role=alert]", "Motor driver")
    assert promoted?(view, ctx.axis, "stepper-recover")
    assert has_element?(view, "#stepper-recover-#{ctx.axis.id}.btn-primary")

    view |> element("#stepper-recover-#{ctx.axis.id}") |> render_click()
    assert_received :recovered
  end

  test "a disconnected device says so and offers nothing urgent", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :disconnected, axes: %{}})
    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Device not connected")
    refute promoted?(view, ctx.axis, "stepper-stop")
    refute promoted?(view, ctx.axis, "stepper-resume")
    refute promoted?(view, ctx.axis, "stepper-recover")
  end

  test "an unreferenced axis needs setup and the wizard is the primary action", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :awaiting_reference,
        axes: %{ctx.axis.id => runtime(%{ready: false, status: nil})}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Needs setup")
    assert has_element?(view, "#stepper-wizard-open-#{ctx.axis.id}.btn-primary", "Set up gauge")
  end

  test "edit, flip and delete live in a small menu, not on the card face", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})

    for id <- ~w(edit flip delete) do
      assert has_element?(view, "#stepper-menu-#{ctx.axis.id} #stepper-#{id}-#{ctx.axis.id}")
    end
  end
end
