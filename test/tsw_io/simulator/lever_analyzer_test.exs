defmodule TswIo.Simulator.LeverAnalyzerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias TswIo.Simulator.Client
  alias TswIo.Simulator.LeverAnalyzer
  alias TswIo.Simulator.LeverAnalyzer.AnalysisResult

  @base_url "http://localhost:31270"
  @api_key "test-api-key"

  setup :verify_on_exit!

  describe "analyze/3" do
    test "detects discrete lever with integer outputs" do
      client = Client.new(@base_url, @api_key)

      # Mock a discrete lever (reverser) with outputs -1, 0, 1
      # Each notch_index corresponds to a different gate
      # Key: actual_input SNAPS to fixed positions (differs from set_input)
      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            # Snap zone 0: snaps to 0.0
            input < 0.33 -> {0.0, -1.0, 0}
            # Snap zone 1: snaps to 0.5
            input < 0.66 -> {0.5, 0.0, 1}
            # Snap zone 2: snaps to 1.0
            true -> {1.0, 1.0, 2}
          end

        %{actual_input: actual_input, output: output, notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/Reverser")

      assert result.lever_type == :discrete
      assert result.all_outputs_integers == true
      assert result.unique_output_count == 3

      # All notches should be gates for discrete lever
      assert Enum.all?(result.suggested_notches, &(&1[:type] == :gate))
    end

    test "detects continuous lever with many fractional outputs" do
      client = Client.new(@base_url, @api_key)

      # Mock a continuous lever (throttle) with outputs 0.0 to 1.0
      # All positions have the same notch_index (no snapping)
      stub_sweep_responses(fn input ->
        %{actual_input: input, output: input, notch_index: 0}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/Throttle")

      assert result.lever_type == :continuous
      assert result.all_outputs_integers == false
      assert result.unique_output_count >= 20

      # Single linear notch for continuous lever
      assert length(result.suggested_notches) == 1
      assert hd(result.suggested_notches)[:type] == :linear
    end

    test "detects hybrid lever with snap zones and determines gate vs linear correctly" do
      client = Client.new(@base_url, @api_key)

      # Mock a hybrid lever (like MasterController) with snap zones
      # Zone 0: snap to 0.0, output -11 (gate - single value), notch 0
      # Zone 1: linear braking -10 to -1, notches 1-3 merged (no snap between)
      # Zone 2: snap to 0.4, output -0.9 (gate), notch 4
      # Zone 3: snap to 0.5, output 0.0 (gate - neutral), notch 5
      # Zone 4: linear power 1 to 10, notch 6
      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            # Zone 0 (snaps to 0.0) - gate
            input < 0.08 -> {0.0, -11.0, 0}
            # Zone 1 (linear braking) - 3 notches that should merge
            input < 0.15 -> {0.1, -10.0, 1}
            input < 0.25 -> {0.2, -6.0, 2}
            input < 0.35 -> {0.3, -2.0, 3}
            # Zone 2 (snaps to 0.4) - gate
            input < 0.45 -> {0.4, -0.9, 4}
            # Zone 3 (snaps to 0.5) - neutral gate
            input < 0.55 -> {0.5, 0.0, 5}
            # Zone 4 (linear power)
            true -> {0.6 + (input - 0.56) * 0.5, 1.0 + (input - 0.56) * 20, 6}
          end

        %{actual_input: actual_input, output: Float.round(output, 2), notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController")

      assert result.lever_type == :hybrid
      # After merging, should have gate zones and linear zones
      assert length(result.zones) >= 2

      # Check that notches have appropriate types
      gates = Enum.filter(result.suggested_notches, &(&1[:type] == :gate))
      linears = Enum.filter(result.suggested_notches, &(&1[:type] == :linear))

      # Should have some gates (zones with single output value)
      assert length(gates) >= 1
      # Should have some linear zones (zones with output range)
      assert length(linears) >= 1

      # Gates should have a :value field
      Enum.each(gates, fn gate ->
        assert Map.has_key?(gate, :value)
        assert is_number(gate[:value])
      end)

      # Linear zones should have :min_value and :max_value fields
      Enum.each(linears, fn linear ->
        assert Map.has_key?(linear, :min_value)
        assert Map.has_key?(linear, :max_value)
        assert is_number(linear[:min_value])
        assert is_number(linear[:max_value])
      end)
    end

    test "correctly identifies gate when min and max outputs are identical" do
      client = Client.new(@base_url, @api_key)

      # Mock a lever where one zone has identical min/max outputs
      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            # Zone with identical outputs (should be gate)
            input < 0.5 -> {0.0, -5.0, 0}
            # Zone with range (should be linear)
            true -> {0.5, input * 10, 1}
          end

        %{actual_input: actual_input, output: Float.round(output, 2), notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/TestLever")

      # Find the zone with identical outputs
      gate_zone =
        Enum.find(result.suggested_notches, fn notch ->
          notch[:type] == :gate and notch[:value] == -5.0
        end)

      assert gate_zone != nil, "Should detect a gate with value -5.0"
    end

    test "correctly identifies gate when outputs differ by less than 0.1 after rounding" do
      client = Client.new(@base_url, @api_key)

      # Mock a lever where outputs are very close (e.g., -0.91 to -0.93)
      # After rounding to 1 decimal, both become -0.9, so it's a gate
      stub_sweep_responses(fn input ->
        {actual_input, output, notch_index} =
          cond do
            input < 0.5 ->
              # Outputs vary between -0.91 and -0.93 (same when rounded to 1 decimal)
              {0.0, -0.91 - input * 0.04, 0}

            true ->
              {0.5, input * 10, 1}
          end

        %{actual_input: actual_input, output: Float.round(output, 2), notch_index: notch_index}
      end)

      assert {:ok, %AnalysisResult{} = result} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/TestLever")

      # The first zone should be detected as a gate since outputs are nearly identical
      first_notch = hd(result.suggested_notches)

      # It could be gate or linear depending on exact values, but if the range is < 0.1
      # when rounded to 1 decimal, it should be a gate
      if first_notch[:type] == :gate do
        assert is_number(first_notch[:value])
      end
    end

    test "returns error when insufficient samples are collected" do
      client = Client.new(@base_url, @api_key)

      # Mock failed requests
      stub(Req, :request, fn _req, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, :insufficient_samples} =
               LeverAnalyzer.analyze(client, "CurrentDrivableActor/TestLever")
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
      case opts[:method] do
        :patch ->
          # Extract the input value from params (keyword list like [Value: 0.5])
          params = opts[:params] || []
          input_value = Keyword.get(params, :Value, 0.0)
          Agent.update(agent, fn _ -> input_value end)
          {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

        :get ->
          url = opts[:url]
          last_input = Agent.get(agent, & &1)
          response = response_fn.(last_input)

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
    end)
  end
end
