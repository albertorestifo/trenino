defmodule Trenino.Train.GaugePresets do
  @moduledoc "Physically unverified starter binding; choose and verify a simulator endpoint."
  def class323_speedometer do
    %{
      name: "Class 323 speedometer (unverified)",
      endpoint: nil,
      input_unit: :mps,
      enabled: false
    }
  end
end
