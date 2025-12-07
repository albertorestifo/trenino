defmodule TswIo.Train.LeverConfig do
  @moduledoc """
  Schema for lever configuration.

  Stores the API endpoint paths for a lever element and its calibration data.
  The calibration data includes the timestamp of when calibration was performed
  and the notch positions discovered during calibration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Train.Element
  alias TswIo.Train.LeverInputBinding
  alias TswIo.Train.Notch

  @type t :: %__MODULE__{
          id: integer() | nil,
          element_id: integer() | nil,
          min_endpoint: String.t() | nil,
          max_endpoint: String.t() | nil,
          value_endpoint: String.t() | nil,
          notch_count_endpoint: String.t() | nil,
          notch_index_endpoint: String.t() | nil,
          calibrated_at: DateTime.t() | nil,
          element: Element.t() | Ecto.Association.NotLoaded.t(),
          notches: [Notch.t()] | Ecto.Association.NotLoaded.t(),
          input_binding: LeverInputBinding.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_lever_configs" do
    field :min_endpoint, :string
    field :max_endpoint, :string
    field :value_endpoint, :string
    field :notch_count_endpoint, :string
    field :notch_index_endpoint, :string
    field :calibrated_at, :utc_datetime

    belongs_to :element, Element
    has_many :notches, Notch, on_delete: :delete_all
    has_one :input_binding, LeverInputBinding, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [
      :min_endpoint,
      :max_endpoint,
      :value_endpoint,
      :notch_count_endpoint,
      :notch_index_endpoint,
      :calibrated_at,
      :element_id
    ])
    |> validate_required([:min_endpoint, :max_endpoint, :value_endpoint])
    |> validate_notch_endpoints()
    |> foreign_key_constraint(:element_id)
    |> unique_constraint(:element_id)
  end

  defp validate_notch_endpoints(changeset) do
    notch_count = get_field(changeset, :notch_count_endpoint)
    notch_index = get_field(changeset, :notch_index_endpoint)

    cond do
      notch_count != nil and notch_index == nil ->
        add_error(
          changeset,
          :notch_index_endpoint,
          "is required when notch_count_endpoint is set"
        )

      notch_count == nil and notch_index != nil ->
        add_error(
          changeset,
          :notch_count_endpoint,
          "is required when notch_index_endpoint is set"
        )

      true ->
        changeset
    end
  end
end
