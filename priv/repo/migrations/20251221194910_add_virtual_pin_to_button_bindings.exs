defmodule TswIo.Repo.Migrations.AddVirtualPinToButtonBindings do
  use Ecto.Migration

  def change do
    alter table(:button_input_bindings) do
      # For matrix inputs, this stores the specific virtual pin (128+)
      # For regular button inputs, this is nil
      add :virtual_pin, :integer
    end
  end
end
