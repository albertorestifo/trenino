defmodule TswIo.Repo.Migrations.AddKeystrokeToButtonBindings do
  use Ecto.Migration

  def change do
    alter table(:button_input_bindings) do
      add :keystroke, :string
    end
  end
end
