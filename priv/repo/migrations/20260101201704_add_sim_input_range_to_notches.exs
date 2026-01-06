defmodule Trenino.Repo.Migrations.AddSimInputRangeToNotches do
  use Ecto.Migration

  def change do
    alter table(:train_lever_notches) do
      # Simulator input ranges - the InputValue to send to the simulator
      # These are set by LeverAnalyzer and represent what the simulator expects
      add :sim_input_min, :float
      add :sim_input_max, :float
    end

    # Copy existing input_min/input_max to sim_input_min/sim_input_max
    # since these originally contained simulator input values from the analyzer
    execute(
      "UPDATE train_lever_notches SET sim_input_min = input_min, sim_input_max = input_max",
      "SELECT 1"
    )
  end
end
