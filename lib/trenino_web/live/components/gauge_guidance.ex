defmodule TreninoWeb.GaugeGuidance do
  @moduledoc """
  Plain-language guidance for gauges. Read-only: it explains why an enabled gauge
  binding is not moving, without changing any state.
  """
  alias Trenino.Hardware
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train.GaugeBinding
  alias Trenino.Train.Train
  alias TreninoWeb.GaugeFeedback

  @doc "The dial state of a gauge as a status chip: `%{kind, label}`."
  @spec dial_status(Gauge.t()) :: %{kind: atom(), label: String.t()}
  def dial_status(%Gauge{} = gauge) do
    case GaugeBinding.calibration(gauge) do
      %DialCalibration{valid: true, reviewed: true} -> %{kind: :ok, label: "Calibrated"}
      %DialCalibration{} -> %{kind: :warn, label: "Dial not reviewed"}
      nil -> %{kind: :warn, label: "Needs calibration"}
    end
  end

  @doc """
  Why an enabled binding cannot move right now, or `nil` when nothing blocks it.

  `simulator_connected?` is whether the simulator client is available. `link` is the
  device's `Hardware.gauge_link/1` result when the caller already has it; otherwise it is
  looked up.
  """
  @spec blocker(GaugeBinding.t(), boolean(), term()) :: String.t() | nil
  def blocker(binding, simulator_connected?, link \\ nil)

  def blocker(%GaugeBinding{enabled: false}, _, _), do: nil

  def blocker(%GaugeBinding{gauge: %Gauge{} = gauge}, simulator_connected?, link) do
    cond do
      not simulator_connected? ->
        "Not moving: the simulator is not connected."

      not GaugeBinding.enableable?(gauge) ->
        "Not moving: the gauge's dial is not calibrated. Calibrate it in the hardware configuration."

      true ->
        case link || Hardware.gauge_link(gauge.device_id) do
          {:ok, _port} -> nil
          {:error, reason} -> "Not moving: " <> GaugeFeedback.error(reason)
        end
    end
  end

  @doc """
  Hint shown when none of the train's identifiers match the detected train.

  Matching is the same prefix rule used by train detection. Returns `nil` when
  nothing is detected or the train matches.
  """
  @spec train_hint(Train.t(), String.t() | nil) :: String.t() | nil
  def train_hint(%Train{}, nil), do: nil

  def train_hint(%Train{identifiers: identifiers}, detected) when is_binary(detected) do
    if Enum.any?(identifiers, &String.starts_with?(detected, &1.identifier)) do
      nil
    else
      "This train profile does not match the detected train \"#{detected}\", so gauges here will not move. " <>
        "Add \"#{detected}\" as a train identifier to use them in this cab."
    end
  end
end
