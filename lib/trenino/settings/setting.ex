defmodule Trenino.Settings.Setting do
  @moduledoc """
  Schema for the `app_settings` key/value store.

  Stores raw strings — atom-to-string conversion happens in
  `Trenino.Settings`, never here.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }

  @primary_key {:key, :string, autogenerate: false}
  schema "app_settings" do
    field :value, :string
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end
end
