defmodule TreninoWeb.StepperAxisCardTest do
  @moduledoc """
  The axis card at rest is one name, one state and at most one action. Manual controls
  live in Diagnostics, shown only on request; Stop is never hidden while the needle moves.
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

    {:ok, _} =
      Hardware.save_dial_calibration(axis, %{
        reviewed: true,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    test = self()

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

    stub(StepperManager, :rezero, fn _, opts ->
      send(test, {:rezero, opts})
      {:ok, :accepted}
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

  defp diagnostics(view, axis),
    do: view |> element("#stepper-diagnostics-toggle-#{axis.id}") |> render_click()

  test "a working axis shows its name, Ready and nothing else", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    assert has_element?(view, "#stepper-status-#{ctx.axis.id}[role=status]", "Ready")
    refute has_element?(view, "#stepper-next-step-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-stop-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-rezero-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-wizard-open-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-diagnostics-#{ctx.axis.id}")

    html = view |> element("#stepper-axis-#{ctx.axis.id}") |> render()
    refute html =~ "x27_six_state"
    refute html =~ ~r/>[^<]*(commission|reference)/i
  end

  test "Diagnostics opens from the menu with every manual control", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    diagnostics(view, ctx.axis)

    for id <- ~w(claim stop release enable resume recover reference) do
      assert has_element?(
               view,
               "#stepper-diagnostics-#{ctx.axis.id} #stepper-#{id}-#{ctx.axis.id}"
             )
    end

    refute render(view) =~ "complete commissioning"
    diagnostics(view, ctx.axis)
    refute has_element?(view, "#stepper-diagnostics-#{ctx.axis.id}")
  end

  test "Stop appears as soon as the needle moves, and one click stops it", ctx do
    moving = runtime(%{status: %{runtime().status | state: :moving}})

    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :ready,
        axes: %{ctx.axis.id => moving}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Moving")
    refute has_element?(view, "#stepper-stop-#{ctx.axis.id}[disabled]")

    view |> element("#stepper-stop-#{ctx.axis.id}") |> render_click()
    assert_received :claimed
    assert_received {:command, :stop}
    # Having taken manual control to stop, the operator is shown how to hand it back.
    assert has_element?(view, "#stepper-handback-#{ctx.axis.id}", "Resume train output")
    view |> element("#stepper-handback-#{ctx.axis.id}") |> render_click()
    assert_received :resumed
  end

  test "Stop claims again when the card's manual control was revoked", ctx do
    test = self()
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    diagnostics(view, ctx.axis)
    view |> element("#stepper-claim-#{ctx.axis.id}") |> render_click()
    assert_received :claimed

    stub(StepperManager, :command, fn _, op, _, token ->
      send(test, {:command, op, token})
      if Process.get(:revoked), do: {:ok, :accepted}, else: {:error, :invalid_lease}
    end)

    view |> element("#stepper-stop-#{ctx.axis.id}") |> render_click()
    assert_received {:command, :stop, _stale}
    assert_received :claimed
    assert_received {:command, :stop, _fresh}
  end

  test "zeroing shows its own state and Stop", ctx do
    homing = runtime(%{ready: false, status: %{runtime().status | state: :homing}})

    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :awaiting_reference,
        axes: %{ctx.axis.id => homing}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Zeroing")
    assert has_element?(view, "#stepper-stop-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-rezero-#{ctx.axis.id}")
  end

  test "a lost position on a set-up gauge asks for Re-zero, not the full setup", ctx do
    {:ok, axis} = Hardware.update_stepper_axis(ctx.axis, %{reference_strategy: :internal_stop})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)

    {:ok, _} =
      Hardware.save_dial_calibration(axis, %{
        reviewed: true,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    view =
      open_page(ctx.conn, ctx.device, axis, %{
        lifecycle: :awaiting_reference,
        axes: %{axis.id => runtime(%{ready: false})}
      })

    assert has_element?(view, "#stepper-status-#{axis.id}", "Needs re-zero")
    refute has_element?(view, "#stepper-wizard-open-#{axis.id}")
    assert has_element?(view, "#stepper-rezero-#{axis.id}.btn-primary", "Re-zero")
    view |> element("#stepper-rezero-#{axis.id}") |> render_click()
    assert_received {:rezero, [aligned: false]}
  end

  test "a host-reference gauge is lined up by hand before re-zeroing", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :awaiting_reference,
        axes: %{ctx.axis.id => runtime(%{ready: false})}
      })

    assert has_element?(view, "#stepper-next-step-#{ctx.axis.id}", "by hand")
    view |> element("#stepper-rezero-#{ctx.axis.id}", "The needle is on 0") |> render_click()
    assert_received {:rezero, [aligned: true]}
  end

  test "a paused gauge offers to resume train output", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :ready,
        axes: %{ctx.axis.id => runtime(%{paused: true})}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Paused")
    view |> element("#stepper-rezero-#{ctx.axis.id}", "Resume train output") |> render_click()
    assert_received {:rezero, _}
  end

  test "a fault on a set-up gauge offers Re-zero with the reason", ctx do
    view =
      open_page(ctx.conn, ctx.device, ctx.axis, %{
        lifecycle: :fault,
        error: :driver_i2c,
        axes: %{ctx.axis.id => runtime(%{ready: false})}
      })

    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Fault")
    assert has_element?(view, "#stepper-next-step-#{ctx.axis.id}[role=alert]", "Motor driver")
    view |> element("#stepper-rezero-#{ctx.axis.id}", "Re-zero") |> render_click()
    assert_received {:rezero, _}
  end

  test "a disconnected device says Offline and offers nothing urgent", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :disconnected, axes: %{}})
    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Offline")
    refute has_element?(view, "#stepper-stop-#{ctx.axis.id}")
    refute has_element?(view, "#stepper-rezero-#{ctx.axis.id}")
  end

  test "an unreviewed dial means the gauge still needs setup, whatever the axis says", ctx do
    {:ok, _} =
      Hardware.save_dial_calibration(ctx.axis, %{
        reviewed: false,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})
    assert has_element?(view, "#stepper-status-#{ctx.axis.id}", "Needs setup")
    assert has_element?(view, "#stepper-wizard-open-#{ctx.axis.id}.btn-primary", "Set up gauge")
  end

  test "setup again, edit, diagnostics and delete live in a small menu", ctx do
    view = open_page(ctx.conn, ctx.device, ctx.axis, %{lifecycle: :ready})

    for id <- ~w(setup-again edit diagnostics-toggle delete) do
      assert has_element?(view, "#stepper-menu-#{ctx.axis.id} #stepper-#{id}-#{ctx.axis.id}")
    end

    assert has_element?(view, "#stepper-delete-#{ctx.axis.id}[data-confirm]")
  end
end
