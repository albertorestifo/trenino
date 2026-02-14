defmodule Trenino.Hardware.BLDCProfileBuilder do
  @moduledoc """
  Builds LoadBLDCProfile messages from LeverConfig data.

  This module converts a LeverConfig with notches (from the database) into
  a LoadBLDCProfile message ready to send to the firmware. It handles:

  - Converting gate notches into detents with haptic parameters
  - Converting linear notches into damped ranges between detents
  - Calculating position values (0.0-1.0 → 0-100)
  - Validating BLDC parameters are present

  ## Examples

      iex> lever_config = %LeverConfig{lever_type: :bldc, notches: [...]}
      iex> BLDCProfileBuilder.build_profile(lever_config)
      {:ok, %LoadBLDCProfile{pin: 0, detents: [...], ranges: [...]}}

  """

  alias Trenino.Serial.Protocol.LoadBLDCProfile
  alias Trenino.Train.LeverConfig
  alias Trenino.Train.Notch

  @doc """
  Builds a LoadBLDCProfile message from a LeverConfig.

  Returns `{:ok, LoadBLDCProfile.t()}` on success, or `{:error, reason}` if:
  - The lever is not a BLDC lever
  - Required BLDC parameters are missing
  """
  @spec build_profile(LeverConfig.t()) :: {:ok, LoadBLDCProfile.t()} | {:error, atom()}
  def build_profile(%LeverConfig{lever_type: :bldc, notches: notches}) do
    with :ok <- validate_bldc_parameters(notches),
         sorted_notches <- Enum.sort_by(notches, & &1.index),
         detents <- build_detents(sorted_notches),
         ranges <- build_linear_ranges(sorted_notches) do
      {:ok,
       %LoadBLDCProfile{
         pin: 0,
         detents: detents,
         ranges: ranges
       }}
    end
  end

  def build_profile(%LeverConfig{}) do
    {:error, :not_bldc_lever}
  end

  # Validates that all required BLDC parameters are present
  defp validate_bldc_parameters(notches) do
    missing_params? =
      Enum.any?(notches, fn notch ->
        case notch.type do
          :gate ->
            is_nil(notch.bldc_engagement) or is_nil(notch.bldc_hold) or is_nil(notch.bldc_exit) or
              is_nil(notch.bldc_spring_back) or is_nil(notch.bldc_damping)

          :linear ->
            is_nil(notch.bldc_damping)
        end
      end)

    if missing_params? do
      {:error, :missing_bldc_parameters}
    else
      :ok
    end
  end

  # Builds detents from gate notches
  defp build_detents(notches) do
    notches
    |> Enum.filter(&(&1.type == :gate))
    |> Enum.map(fn %Notch{} = notch ->
      %{
        position: calculate_position(notch),
        engagement: notch.bldc_engagement,
        hold: notch.bldc_hold,
        exit: notch.bldc_exit,
        spring_back: notch.bldc_spring_back
      }
    end)
  end

  # Calculates position from input_min (0.0-1.0 → 0-100)
  defp calculate_position(%Notch{input_min: input_min}) do
    round(input_min * 100)
  end

  # Builds linear ranges from linear notches
  # Each linear range connects the previous gate detent to the next gate detent
  defp build_linear_ranges(notches) do
    linear_notches = Enum.filter(notches, &(&1.type == :linear))

    if Enum.empty?(linear_notches) do
      []
    else
      # Build a map of gate notch indices to their detent index in the detents list
      gate_indices =
        notches
        |> Enum.filter(&(&1.type == :gate))
        |> Enum.with_index()
        |> Enum.map(fn {notch, detent_idx} -> {notch.index, detent_idx} end)
        |> Map.new()

      Enum.map(linear_notches, &build_range(&1, gate_indices))
    end
  end

  # For a linear notch, find the previous and next gate detent
  defp build_range(%Notch{} = linear_notch, gate_indices) do
    prev_detent_idx =
      gate_indices
      |> Enum.filter(fn {gate_idx, _} -> gate_idx < linear_notch.index end)
      |> Enum.max_by(fn {gate_idx, _} -> gate_idx end, fn -> {nil, nil} end)
      |> elem(1)

    next_detent_idx =
      gate_indices
      |> Enum.filter(fn {gate_idx, _} -> gate_idx > linear_notch.index end)
      |> Enum.min_by(fn {gate_idx, _} -> gate_idx end, fn -> {nil, nil} end)
      |> elem(1)

    %{
      start_detent: prev_detent_idx,
      end_detent: next_detent_idx,
      damping: linear_notch.bldc_damping
    }
  end
end
