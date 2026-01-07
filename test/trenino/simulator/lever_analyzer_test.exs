defmodule Trenino.Simulator.LeverAnalyzerTest do
  @moduledoc """
  Integration tests for LeverAnalyzer.

  These tests verify the full analyze/3 flow with mocked HTTP responses.
  For fast unit tests of the analysis logic, see LeverAnalyzer.AnalysisTest.
  """
  use ExUnit.Case, async: true
  use Mimic

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.LeverAnalyzer
  alias Trenino.Simulator.LeverAnalyzer.AnalysisResult

  @base_url "http://localhost:31270"
  @api_key "test-api-key"

  # Use settling_time_ms: 0 to avoid slow sleeps in tests
  @fast_opts [settling_time_ms: 0]

  setup :verify_on_exit!

  describe "analyze/3 integration" do
    test "sweeps lever and collects samples for discrete lever" do
      client = Client.new(@base_url, @api_key)

      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            input < 0.33 -> {0.0, -1.0, 0}
            input < 0.66 -> {0.5, 0.0, 1}
            true -> {1.0, 1.0, 2}
          end

        %{actual_input: actual_input, output: output, notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/Reverser", @fast_opts)

      assert result.lever_type == :discrete
      assert result.all_outputs_integers == true
      assert result.unique_output_count == 3
      assert Enum.all?(result.suggested_notches, &(&1[:type] == :gate))
    end

    test "sweeps lever and collects samples for continuous lever" do
      client = Client.new(@base_url, @api_key)

      stub_sweep_responses(fn input ->
        %{actual_input: input, output: input, notch_index: 0}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/Throttle", @fast_opts)

      assert result.lever_type == :continuous
      assert result.all_outputs_integers == false
      assert result.unique_output_count >= 20
      assert length(result.suggested_notches) == 1
      assert hd(result.suggested_notches)[:type] == :linear
    end

    test "sweeps lever and collects samples for hybrid lever" do
      client = Client.new(@base_url, @api_key)

      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            input < 0.08 -> {0.0, -11.0, 0}
            input < 0.15 -> {0.1, -10.0, 1}
            input < 0.25 -> {0.2, -6.0, 2}
            input < 0.35 -> {0.3, -2.0, 3}
            input < 0.45 -> {0.4, -0.9, 4}
            input < 0.55 -> {0.5, 0.0, 5}
            true -> {0.6 + (input - 0.56) * 0.5, 1.0 + (input - 0.56) * 20, 6}
          end

        %{actual_input: actual_input, output: Float.round(output, 2), notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController", @fast_opts)

      assert result.lever_type == :hybrid
      assert length(result.zones) >= 2

      gates = Enum.filter(result.suggested_notches, &(&1[:type] == :gate))
      linears = Enum.filter(result.suggested_notches, &(&1[:type] == :linear))

      assert gates != []
      assert linears != []
    end

    test "returns error when insufficient samples are collected" do
      client = Client.new(@base_url, @api_key)

      stub(Req, :request, fn _req, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, :insufficient_samples} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/TestLever", @fast_opts)
    end
  end

  describe "quick_check/2" do
    test "returns :discrete for integer outputs" do
      client = Client.new(@base_url, @api_key)

      # Mock responses for 5 test points returning integer values
      expect(Req, :request, 10, fn _req, opts ->
        case opts[:method] do
          :patch ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          :get ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{"Result" => "Success", "Values" => %{"ReturnValue" => 1.0}}
             }}
        end
      end)

      assert {:ok, :discrete} = LeverAnalyzer.quick_check(client, "CurrentDrivableActor/Reverser")
    end

    test "returns :continuous for fractional outputs" do
      client = Client.new(@base_url, @api_key)

      counter = :counters.new(1, [])

      expect(Req, :request, 10, fn _req, opts ->
        case opts[:method] do
          :patch ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          :get ->
            :counters.add(counter, 1, 1)
            val = :counters.get(counter, 1) * 0.25

            {:ok,
             %Req.Response{
               status: 200,
               body: %{"Result" => "Success", "Values" => %{"ReturnValue" => val}}
             }}
        end
      end)

      assert {:ok, :continuous} =
               LeverAnalyzer.quick_check(client, "CurrentDrivableActor/Throttle")
    end
  end

  # Helper to stub sweep responses using an Agent to track state
  defp stub_sweep_responses(response_fn) do
    # Start an agent to track the last set input value
    {:ok, agent} = Agent.start_link(fn -> 0.0 end)

    stub(Req, :request, fn _req, opts ->
      handle_stubbed_request(opts, agent, response_fn)
    end)
  end

  defp handle_stubbed_request(opts, agent, response_fn) do
    case opts[:method] do
      :patch -> handle_patch_request(opts, agent)
      :get -> handle_get_request(opts, agent, response_fn)
    end
  end

  defp handle_patch_request(opts, agent) do
    params = opts[:params] || []
    input_value = Keyword.get(params, :Value, 0.0)
    Agent.update(agent, fn _ -> input_value end)
    {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
  end

  defp handle_get_request(opts, agent, response_fn) do
    url = opts[:url]
    last_input = Agent.get(agent, & &1)
    response = response_fn.(last_input)
    build_get_response(url, response)
  end

  defp build_get_response(url, response) do
    cond do
      String.contains?(url, "InputValue") ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "Result" => "Success",
             "Values" => %{"InputValue" => response.actual_input}
           }
         }}

      String.contains?(url, "GetCurrentOutputValue") ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "Result" => "Success",
             "Values" => %{"ReturnValue" => response.output}
           }
         }}

      String.contains?(url, "GetCurrentNotchIndex") ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "Result" => "Success",
             "Values" => %{"ReturnValue" => response[:notch_index] || 0}
           }
         }}

      true ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => 0.0}}
         }}
    end
  end
end
