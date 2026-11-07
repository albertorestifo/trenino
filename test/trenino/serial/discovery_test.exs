defmodule Trenino.Serial.DiscoveryTest do
  use Trenino.SerialSafetyCase, async: true

  alias Circuits.UART
  alias Trenino.Serial.Discovery
  alias Trenino.Serial.Protocol.Heartbeat
  alias Trenino.Serial.Protocol.IdentityResponse
  alias Trenino.Serial.Protocol.InputValue

  @identity %IdentityResponse{request_id: 1, version: "3.2.1", config_id: 42}

  # Runs the real Discovery against a stubbed UART. `reads` is the sequence of
  # results returned by UART.read/2; once exhausted, reads time out (`<<>>`).
  # Returns the discovery result and the number of identity requests written.
  defp run_discovery(reads) do
    {:ok, agent} = Agent.start_link(fn -> %{reads: reads, writes: 0, read_timeouts: []} end)
    uart = self()

    stub(UART, :flush, fn ^uart, :receive -> :ok end)
    stub(UART, :drain, fn ^uart -> :ok end)

    stub(UART, :write, fn ^uart, _data ->
      Agent.update(agent, &%{&1 | writes: &1.writes + 1})
    end)

    stub(UART, :read, fn ^uart, timeout ->
      Agent.get_and_update(agent, fn
        %{reads: [next | rest]} = s ->
          {next, %{s | reads: rest, read_timeouts: [timeout | s.read_timeouts]}}

        %{reads: []} = s ->
          {{:ok, <<>>}, %{s | read_timeouts: [timeout | s.read_timeouts]}}
      end)
    end)

    result = Mimic.call_original(Discovery, :discover, [uart])
    stats = Agent.get(agent, & &1)
    {result, stats}
  end

  defp frame(message) do
    {:ok, data} = message.__struct__.encode(message)
    {:ok, data}
  end

  describe "discover/1" do
    test "returns the identity response on the first attempt" do
      {result, stats} = run_discovery([frame(@identity)])

      assert {:ok, %IdentityResponse{version: "3.2.1", config_id: 42}} = result
      assert stats.writes == 1
    end

    test "skips input values and heartbeats streamed by configured firmware" do
      # Configured firmware streams input values from boot. More than 5 of them
      # used to exhaust every attempt before the identity response was read.
      noise =
        for pin <- 0..11 do
          frame(%InputValue{pin: pin, value: 512})
        end

      {result, stats} = run_discovery(noise ++ [frame(%Heartbeat{}), frame(@identity)])

      assert {:ok, %IdentityResponse{config_id: 42}} = result
      assert stats.writes == 1
    end

    test "skips undecodable frames such as bootloader noise" do
      {result, stats} =
        run_discovery([{:ok, <<0xFF, 0x13>>}, {:ok, <<0x14, 0x10>>}, frame(@identity)])

      assert {:ok, %IdentityResponse{}} = result
      assert stats.writes == 1
    end

    test "retries after an attempt with no data and finds a late-booting board" do
      {result, stats} = run_discovery([{:ok, <<>>}, {:ok, <<>>}, frame(@identity)])

      assert {:ok, %IdentityResponse{}} = result
      assert stats.writes == 3
    end

    test "gives up with :no_valid_response after 5 silent attempts" do
      {result, stats} = run_discovery([])

      assert {:error, :no_valid_response} = result
      assert stats.writes == 5
    end

    test "never waits longer than one second per read" do
      {_result, stats} = run_discovery([frame(%InputValue{pin: 1, value: 0})])

      assert Enum.all?(stats.read_timeouts, &(&1 > 0 and &1 <= 1_000))
    end

    test "returns a read error immediately" do
      {result, stats} = run_discovery([{:error, :eio}])

      assert {:error, :eio} = result
      assert stats.writes == 1
    end

    test "returns a write error without reading" do
      uart = self()
      stub(UART, :flush, fn ^uart, :receive -> :ok end)
      stub(UART, :write, fn ^uart, _data -> {:error, :ebadf} end)

      assert {:error, :ebadf} = Mimic.call_original(Discovery, :discover, [uart])
    end
  end
end
