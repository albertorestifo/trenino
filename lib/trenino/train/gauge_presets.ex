defmodule Trenino.Train.GaugePresets do
  @moduledoc "Physically unverified starter geometry; choose and verify a simulator endpoint."
  def class323_speedometer do
    %{
      name: "Class 323 speedometer (unverified)",
      endpoint: nil,
      input_unit: :mps,
      output_unit: :mph,
      enabled: false,
      points: [%{value: 0.0, position: 0}, %{value: 100.0, position: 720}]
    }
  end
end
