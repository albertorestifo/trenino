defmodule TreninoWeb.ConfigurationEditLive.SensorHealth do
  @moduledoc """
  Which angle sensors on the connected controller are not responding.

  The firmware sends an angle sensor's reading at least every 2 s while it answers, and
  goes quiet when it is lost. So a sensor counts as not responding when it reported a
  `ModuleError` since its last reading, or when nothing came from its report pin for
  5 s. The silence rule also covers a sensor that was already missing when the
  app connected, when no `ModuleError` reaches this page.

  Times are monotonic milliseconds.
  """

  @silence_ms 5_000

  @enforce_keys [:watch_since]
  defstruct watch_since: 0, last_seen: %{}, errors: MapSet.new()

  @type t :: %__MODULE__{
          watch_since: integer(),
          last_seen: %{integer() => integer()},
          errors: MapSet.t(integer())
        }

  @doc "Start watching at `now`: every sensor gets the full silence window."
  @spec new(integer()) :: t()
  def new(now), do: %__MODULE__{watch_since: now}

  @doc "A reading arrived on `pin`."
  @spec seen(t(), integer(), integer()) :: t()
  def seen(%__MODULE__{} = health, pin, now) do
    %{
      health
      | last_seen: Map.put(health.last_seen, pin, now),
        errors: MapSet.delete(health.errors, pin)
    }
  end

  @doc "The device reported the sensor on `pin` as missing."
  @spec failed(t(), integer()) :: t()
  def failed(%__MODULE__{} = health, pin),
    do: %{health | errors: MapSet.put(health.errors, pin)}

  @doc "The pins among `pins` whose sensor is not responding at `now`."
  @spec unresponsive(t(), [integer()], integer()) :: MapSet.t(integer())
  def unresponsive(%__MODULE__{} = health, pins, now) do
    pins
    |> Enum.filter(fn pin ->
      MapSet.member?(health.errors, pin) or
        now - Map.get(health.last_seen, pin, health.watch_since) > @silence_ms
    end)
    |> MapSet.new()
  end
end
