defmodule Trenino.Train.GaugePoint do
  @moduledoc "Measured dial value and open-loop position in selected mode transitions."
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  @type t :: %__MODULE__{}
  embedded_schema do
    field :value, :float
    field :position, :integer
  end

  def changeset(%__MODULE__{} = point, attrs) do
    point
    |> cast(attrs, [:value, :position])
    |> validate_required([:value, :position])
    |> update_change(:value, &Float.round(&1, 2))
  end
end
