defmodule Trenino.Hardware.Calibration.SessionTest do
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.Input.Calibration
  alias TreninoWeb.CalibrationWizard

  @port "/dev/test"

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Cal Device"})

    {:ok, input} =
      Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

    %{device: device, input: input}
  end

  defp start_session(input, opts \\ []) do
    {:ok, pid} =
      Session.start_link(Keyword.merge([input_id: input.id, port: @port, pin: input.pin], opts))

    Sandbox.allow(Trenino.Repo, self(), pid)
    pid
  end

  defp feed(pid, input, values) do
    for v <- values, do: send(pid, {:input_value_updated, @port, input.pin, v})
    # Synchronous call flushes the mailbox
    Session.get_state(pid)
  end

  defp run_flow(pid, input, min, sweep, max) do
    :ok = Session.advance_step(pid)
    feed(pid, input, min)
    :ok = Session.advance_step(pid)
    feed(pid, input, sweep)
    :ok = Session.advance_step(pid)
    feed(pid, input, max)
    Session.advance_step(pid)
  end

  defp create_ads1115(device, params) do
    {:ok, module} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: Map.merge(%{channel_mask: 0x01, gain: 0}, params)
      })

    Repo.get_by!(Input, i2c_module_id: module.id, i2c_channel: 0)
  end

  describe "min_unique_samples" do
    test "identical samples advance with min_unique_samples 1", %{input: input} do
      pid = start_session(input, min_unique_samples: 1)
      :ok = Session.advance_step(pid)
      feed(pid, input, List.duplicate(500, 10))

      assert Session.get_public_state(pid).can_advance
      assert :ok = Session.advance_step(pid)
      Session.cancel(pid)
    end

    test "identical samples still fail by default", %{input: input} do
      pid = start_session(input)
      :ok = Session.advance_step(pid)
      feed(pid, input, List.duplicate(500, 10))

      refute Session.get_public_state(pid).can_advance
      assert {:error, :insufficient_samples} = Session.advance_step(pid)
      Session.cancel(pid)
    end
  end

  describe "rollover" do
    @rollover_sweep [1010, 1015, 1020, 1023, 0, 5, 10, 15, 20, 25]

    test "rollover sweep fails when allow_rollover is false, and saves nothing", %{input: input} do
      Session.subscribe(input.id)
      pid = start_session(input, allow_rollover: false)
      ref = Process.monitor(pid)

      assert :ok =
               run_flow(pid, input, [5, 6, 7, 5, 6, 7, 5, 6, 7, 5], @rollover_sweep, [
                 100,
                 101,
                 102,
                 100,
                 101,
                 102,
                 100,
                 101,
                 102,
                 100
               ])

      assert_receive {:calibration_result, {:error, :rollover_needs_reference}}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert Repo.get_by(Calibration, input_id: input.id) == nil
    end

    test "rollover sweep saves has_rollover with a reference", %{input: input} do
      Session.subscribe(input.id)
      pid = start_session(input)

      assert :ok =
               run_flow(pid, input, [5, 6, 7, 5, 6, 7, 5, 6, 7, 5], @rollover_sweep, [
                 100,
                 101,
                 102,
                 100,
                 101,
                 102,
                 100,
                 101,
                 102,
                 100
               ])

      assert_receive {:calibration_result, {:ok, calibration}}
      assert calibration.has_rollover
    end
  end

  describe "Hardware.start_calibration_session/3" do
    test "sets options for ADS1115 with and without reference", %{device: device} do
      with_ref = create_ads1115(device, %{ref_channel: 3})
      {:ok, pid} = Hardware.start_calibration_session(with_ref, @port)
      state = Session.get_state(pid)
      assert state.min_unique_samples == 1
      assert state.allow_rollover == true
      Session.cancel(pid)

      {:ok, device2} = Hardware.create_device(%{name: "Cal Device 2"})
      no_ref = create_ads1115(device2, %{})
      {:ok, pid} = Hardware.start_calibration_session(no_ref, @port)
      state = Session.get_state(pid)
      assert state.min_unique_samples == 1
      assert state.allow_rollover == false
      Session.cancel(pid)
    end

    test "explicit options win over the chip lookup", %{device: device} do
      no_ref = create_ads1115(device, %{})
      {:ok, pid} = Hardware.start_calibration_session(no_ref, @port, allow_rollover: true)
      assert Session.get_state(pid).allow_rollover == true
      Session.cancel(pid)
    end

    test "board inputs get defaults", %{input: input} do
      {:ok, pid} = Hardware.start_calibration_session(input, @port)
      state = Session.get_state(pid)
      assert state.min_unique_samples == 3
      assert state.allow_rollover == true
      Session.cancel(pid)
    end
  end

  describe "wizard copy" do
    test "the wizard shows the reference message" do
      assert CalibrationWizard.error_message({:error, :rollover_needs_reference}) =~
               "needs a supply reference on its ADS1115"
    end
  end
end
