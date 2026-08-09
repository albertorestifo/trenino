defmodule Trenino.VirtualJoystick.Configuration do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}

  schema "virtual_joystick_configurations" do
    field :enabled, :boolean, default: false
    field :device_index, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:enabled, :device_index])
    |> validate_required([:enabled, :device_index])
    |> validate_inclusion(:device_index, [1], message: "must be 1")
    |> check_constraint(:id, name: :virtual_joystick_configurations_singleton)
    |> check_constraint(:device_index, name: :virtual_joystick_configurations_device_index_check)
  end
end
