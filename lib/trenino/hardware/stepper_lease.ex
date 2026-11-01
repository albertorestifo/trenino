defmodule Trenino.Hardware.StepperLease do
  @moduledoc """
  Describes manual-control leases for status reports and refusal messages.

  A lease is reported as `%{owner: :mcp | :ui, expires_in_ms: integer | nil,
  finishing_motion: boolean}`. UI leases never expire by time, so `expires_in_ms` is nil.
  `finishing_motion` means an MCP lease has expired while an accepted move or home is
  still running; it is released as soon as the axis is stationary.
  """

  @type info :: %{
          owner: :mcp | :ui,
          expires_in_ms: non_neg_integer() | nil,
          finishing_motion: boolean()
        }

  @doc "Status view of a lease map held by the manager."
  @spec info(map(), integer()) :: info()
  def info(lease, now) do
    %{
      owner: owner(lease),
      expires_in_ms: expires_in(lease, now),
      finishing_motion: Map.get(lease, :expiring_since) != nil
    }
  end

  @doc "Refusal reason for an action blocked by an existing lease."
  @spec refusal(map(), integer(), :claim | :resume) :: {:lease_held, map()}
  def refusal(lease, now, action),
    do: {:lease_held, lease |> info(now) |> Map.put(:action, action)}

  @doc "A sentence saying who holds the lease and what to do about it."
  @spec message(map()) :: String.t()
  def message(%{action: :resume} = info),
    do: "Cannot resume train control: " <> reason(info)

  def message(info), do: "Cannot take manual control: " <> reason(info)

  defp reason(%{owner: :mcp, finishing_motion: true}) do
    "an MCP lease expired but its accepted move or home is still running. " <>
      "Control is released as soon as the axis stops; try again in a few seconds."
  end

  defp reason(%{owner: :mcp, expires_in_ms: ms}) do
    "an MCP session holds the lease#{expiry_hint(ms)}. Its holder can release it with " <>
      "release_lease and its lease token; otherwise wait for it to expire and retry."
  end

  defp reason(%{owner: :ui}) do
    "the Trenino UI holds manual control. Use Resume train control there (or close " <>
      "that page) first."
  end

  defp expiry_hint(ms) when is_integer(ms), do: " (expires in #{div(ms + 999, 1000)} s)"
  defp expiry_hint(_), do: ""

  defp owner(%{owner: :mcp}), do: :mcp
  defp owner(_), do: :ui

  defp expires_in(%{expires: expires}, now) when is_integer(expires), do: max(0, expires - now)
  defp expires_in(_, _), do: nil
end
