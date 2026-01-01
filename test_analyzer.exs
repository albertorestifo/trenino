# Quick test script to analyze the MasterController
alias TswIo.Simulator.Client
alias TswIo.Simulator.LeverAnalyzer

# Read API key
api_key = File.read!("C:/Users/Alberto/Documents/My Games/TrainSimWorld6/Saved/Config/CommAPIKey.txt") |> String.trim()

# Create client
client = Client.new("http://localhost:31270", api_key)

IO.puts("Analyzing MasterController...")
IO.puts("=" |> String.duplicate(60))

case LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController") do
  {:ok, result} ->
    IO.puts("\nLever type: #{result.lever_type}")
    IO.puts("Output range: #{result.min_output} to #{result.max_output}")
    IO.puts("Unique outputs: #{result.unique_output_count}")
    IO.puts("\nDetected Zones (#{length(result.zones)}):")
    IO.puts("-" |> String.duplicate(60))
    
    result.zones
    |> Enum.sort_by(& &1.set_input_min)
    |> Enum.with_index()
    |> Enum.each(fn {zone, idx} ->
      case zone.type do
        :gate ->
          IO.puts("Zone #{idx}: GATE at output #{zone.value}")
          IO.puts("         set_input: #{zone.set_input_min} - #{zone.set_input_max}")
          IO.puts("         actual_input: #{zone.actual_input_min} - #{zone.actual_input_max}")
        :linear ->
          IO.puts("Zone #{idx}: LINEAR from #{zone.output_min} to #{zone.output_max}")
          IO.puts("         set_input: #{zone.set_input_min} - #{zone.set_input_max}")
          IO.puts("         actual_input: #{zone.actual_input_min} - #{zone.actual_input_max}")
      end
      IO.puts("")
    end)
    
    IO.puts("\nSuggested Notches (#{length(result.suggested_notches)}):")
    IO.puts("-" |> String.duplicate(60))
    Enum.each(result.suggested_notches, fn notch ->
      case notch.type do
        :gate -> IO.puts("  #{notch.index}: GATE value=#{notch.value}")
        :linear -> IO.puts("  #{notch.index}: LINEAR #{notch.min_value} to #{notch.max_value}")
      end
    end)

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end

# Restore lever to neutral
Client.set(client, "CurrentDrivableActor/MasterController.InputValue", 0.5)
IO.puts("\nLever restored to neutral (0.5)")
