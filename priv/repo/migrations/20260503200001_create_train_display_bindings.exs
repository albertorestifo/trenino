defmodule Trenino.Repo.Migrations.CreateTrainDisplayBindings do
  use Ecto.Migration

  def change do
    create table(:train_display_bindings) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :i2c_module_id, references(:device_i2c_modules, on_delete: :delete_all), null: false
      add :name, :string
      add :endpoint, :string, null: false
      add :format_string, :string, null: false, default: "{value}"
      add :enabled, :boolean, null: false, default: true
      add :script_id, references(:scripts, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:train_display_bindings, [:train_id])
    create unique_index(:train_display_bindings, [:train_id, :i2c_module_id])
  end
end
