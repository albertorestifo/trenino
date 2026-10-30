defmodule Trenino.Hardware.StepperSupervisor do
  @moduledoc "Supervises independent stepper sessions without opening UARTs."
  use DynamicSupervisor
  def start_link(opts), do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)
end
