defmodule Trenino.Hardware.Device do
  @moduledoc """
  Schema for device configurations.

  Each configuration represents a set of inputs that can be applied to
  a physical device. The config_id is a unique random identifier that
  links the configuration to a device.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.ConfigId
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.Output

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          config_id: integer() | nil,
          inputs: [Input.t()] | Ecto.Association.NotLoaded.t(),
          outputs: [Output.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "devices" do
    field :name, :string
    field :description, :string
    field :config_id, :integer

    has_many :inputs, Input
    has_many :outputs, Output

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a device configuration.

  When creating a new device (no existing config_id), a random config_id
  is automatically generated.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = device, attrs) do
    device
    |> cast(attrs, [:name, :description, :config_id])
    |> validate_required([:name])
    |> maybe_generate_config_id()
    |> validate_required([:config_id])
    |> unique_constraint(:config_id)
  end

  defp maybe_generate_config_id(changeset) do
    case get_field(changeset, :config_id) do
      nil ->
        {:ok, config_id} = ConfigId.generate()
        put_change(changeset, :config_id, config_id)

      _ ->
        changeset
    end
  end
end
