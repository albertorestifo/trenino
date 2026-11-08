defmodule Trenino.Simulator.LeverAnalyzer.SweepSafetyTest do
  @moduledoc """
  Sweep behaviour against a fake simulator lever: pushing into gates, the
  speed guard, restoring the lever and the per-lever lock.
  """
  use Trenino.SerialSafetyCase, async: true

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.LeverAnalyzer

  @path "CurrentDrivableActor/FakeLever"
  @fast_opts [settling_time_ms: 0, push_delay_ms: 0, sweep_step: 0.05]

  setup :verify_on_exit!

  # A lever on 0..1. From 0.95 up is an Emergency gate (output 2) that only
  # engages after 3 sets in a row; one set stops at 0.9.
  # `speed` is a function of the current input; `nil` means not readable.
  defp start_lever(opts \\ []) do
    {:ok, lever} =
      Agent.start_link(fn ->
        %{
          input: Keyword.get(opts, :start_input, 0.3),
          target: nil,
          repeats: 0,
          sets: [],
          speed: Keyword.get(opts, :speed, fn _input -> 0.0 end)
        }
      end)

    stub(Req, :request, fn _req, req_opts -> handle(lever, req_opts) end)
    lever
  end

  defp handle(lever, opts) do
    case opts[:method] do
      :patch ->
        value = Keyword.fetch!(opts[:params], :Value)
        Agent.update(lever, &apply_set(&1, value))
        ok(%{"Result" => "Success"})

      :get ->
        state = Agent.get(lever, & &1)
        get(opts[:url], state)
    end
  end

  defp apply_set(state, value) do
    repeats = if state.target == value, do: state.repeats + 1, else: 1
    input = if value >= 0.95 and repeats < 3, do: 0.9, else: value
    %{state | input: input, target: value, repeats: repeats, sets: [value | state.sets]}
  end

  defp get(url, state) do
    cond do
      String.contains?(url, "HUD_GetSpeed") ->
        speed(state)

      String.contains?(url, "GetMinimumInputValue") ->
        value(0.0)

      String.contains?(url, "GetMaximumInputValue") ->
        value(1.0)

      String.contains?(url, "GetCurrentOutputValue") ->
        value(output(state.input))

      String.contains?(url, "GetCurrentNotchIndex") ->
        value(if state.input >= 0.95, do: 1, else: 0)

      String.ends_with?(url, ".InputValue") ->
        value(state.input)

      true ->
        ok(%{"Result" => "Error"})
    end
  end

  defp speed(state) do
    case state.speed.(state.input) do
      nil -> ok(%{"Result" => "Error"})
      speed -> ok(%{"Result" => "Success", "Values" => %{"Speed (ms)" => speed}})
    end
  end

  defp output(input) when input >= 0.95, do: 2.0
  defp output(input), do: Float.round(input, 2)

  defp value(v), do: ok(%{"Result" => "Success", "Values" => %{"ReturnValue" => v}})
  defp ok(body), do: {:ok, %Req.Response{status: 200, body: body}}

  defp client, do: Client.new("http://localhost:31270", "key")
  defp sets(lever), do: lever |> Agent.get(& &1.sets) |> Enum.reverse()

  test "pushes the lever into a gate that one set does not reach" do
    start_lever()

    assert {:ok, result} = LeverAnalyzer.analyze(client(), @path, @fast_opts)

    assert %{type: :gate, value: 2.0, input_min: 0.95} = List.last(result.suggested_notches)
  end

  test "puts the lever back where it was by default" do
    lever = start_lever(start_input: 0.3)

    assert {:ok, _result} = LeverAnalyzer.analyze(client(), @path, @fast_opts)

    assert List.last(sets(lever)) == 0.3
    assert Agent.get(lever, & &1.input) == 0.3
  end

  test "leaves the lever at the end of the sweep with restore_position: nil" do
    lever = start_lever(start_input: 0.3)

    assert {:ok, _result} =
             LeverAnalyzer.analyze(client(), @path, [restore_position: nil] ++ @fast_opts)

    assert Agent.get(lever, & &1.input) == 1.0
  end

  test "refuses to start while the train is moving" do
    lever = start_lever(speed: fn _input -> 3.0 end)

    assert {:error, :train_not_stopped} = LeverAnalyzer.analyze(client(), @path, @fast_opts)
    assert sets(lever) == []
  end

  test "stops when the train speeds up and still restores the lever" do
    lever =
      start_lever(start_input: 0.3, speed: fn input -> if input > 0.6, do: 5.0, else: 0.0 end)

    assert {:error, :train_moving} = LeverAnalyzer.analyze(client(), @path, @fast_opts)

    refute 1.0 in sets(lever)
    assert Agent.get(lever, & &1.input) == 0.3
  end

  test "warns and continues when the speed cannot be read" do
    start_lever(speed: fn _input -> nil end)

    assert {:ok, result} = LeverAnalyzer.analyze(client(), @path, @fast_opts)
    assert Enum.any?(result.warnings, &(&1 =~ "without the speed guard"))
  end

  test "refuses to run without the speed guard when it is required" do
    lever = start_lever(speed: fn _input -> nil end)

    assert {:error, :speed_unavailable} =
             LeverAnalyzer.analyze(client(), @path, [require_speed_guard: true] ++ @fast_opts)

    assert sets(lever) == []
  end

  test "refuses a second sweep of the same control" do
    start_lever()
    test_pid = self()

    holder =
      spawn_link(fn ->
        true = :global.set_lock({{LeverAnalyzer, @path}, self()}, [node()], 0)
        send(test_pid, :locked)

        receive do
          :release -> :ok
        end
      end)

    assert_receive :locked
    assert {:error, :calibration_running} = LeverAnalyzer.analyze(client(), @path, @fast_opts)

    send(holder, :release)
  end
end
