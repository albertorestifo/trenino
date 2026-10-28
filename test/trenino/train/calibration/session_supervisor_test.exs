defmodule Trenino.Train.Calibration.SessionSupervisorTest do
  @moduledoc """
  Regression tests for the notch mapping session lifecycle.

  Guards against the orphaned-session deadlock: a `NotchMappingSession` that
  outlives the lever setup wizard (e.g. after a completed save or unclean
  close) blocks the next wizard attempt with `{:error, :already_running}`,
  leaving the Map Positions step stuck on its loading spinner.
  """
  # async: false — NotchMappingSession processes are registered globally in
  # Trenino.Registry; parallel tests could observe each other's sessions.
  use Trenino.DataCase, async: false

  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Train
  alias Trenino.Train.Calibration.NotchMappingSession

  defp setup_lever do
    {:ok, train} =
      Train.create_train(%{
        name: "Test Train",
        identifiers: [%{identifier: "Test_Train_#{System.unique_integer([:positive])}"}]
      })

    {:ok, element} = Train.create_element(train.id, %{name: "Throttle", type: :lever})

    {:ok, config} =
      Train.create_lever_config(element.id, %{
        min_endpoint: "A/B.MinValue",
        max_endpoint: "A/B.MaxValue",
        value_endpoint: "A/B.InputValue"
      })

    # save_notches returns the config reloaded with notches preloaded,
    # which NotchMappingSession requires.
    {:ok, config} =
      Train.save_notches(config, [
        %{type: :gate, value: 0.0, description: "Idle"},
        %{type: :gate, value: 1.0, description: "Max"}
      ])

    config
  end

  defp session_opts(config) do
    [
      lever_config: config,
      port: "/dev/fake",
      pin: 0,
      calibration: %Calibration{
        min_value: 0,
        max_value: 1023,
        max_hardware_value: 1023,
        is_inverted: false,
        has_rollover: false
      }
    ]
  end

  describe "start_notch_mapping/1" do
    test "rejects a second session for the same lever config" do
      config = setup_lever()

      assert {:ok, pid} = Train.start_notch_mapping(session_opts(config))
      assert {:error, :already_running} = Train.start_notch_mapping(session_opts(config))

      assert :ok = Train.stop_notch_mapping(config.id)
      refute Process.alive?(pid)
    end
  end

  describe "stale session recovery (wizard re-entry)" do
    test "stop_notch_mapping/1 synchronously clears the session so a new one can start" do
      config = setup_lever()

      # Simulate a session orphaned by a previous wizard attempt
      assert {:ok, orphan_pid} = Train.start_notch_mapping(session_opts(config))

      # Wizard retry path: synchronous stop, then start again
      assert :ok = Train.stop_notch_mapping(config.id)
      refute Process.alive?(orphan_pid)
      assert Train.get_notch_mapping_session(config.id) == nil

      assert {:ok, new_pid} = Train.start_notch_mapping(session_opts(config))
      assert new_pid != orphan_pid

      # The replacement session is fully usable
      assert :ok = NotchMappingSession.start_mapping(new_pid)
      state = NotchMappingSession.get_public_state(new_pid)
      assert state.current_step == {:mapping_notch, 0}
      assert state.notch_count == 2

      assert :ok = Train.stop_notch_mapping(config.id)
    end

    test "stop_notch_mapping/1 is safe when no session is running" do
      config = setup_lever()

      assert {:error, :not_found} = Train.stop_notch_mapping(config.id)
    end
  end
end
