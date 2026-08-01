defmodule Trenino.VirtualJoystick.Mapping do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Input

  @axes [:x, :y, :z, :rx, :ry, :rz, :slider_1, :slider_2]

  schema "virtual_joystick_mappings" do
    field :device_index, :integer, default: 1
    field :target_type, Ecto.Enum, values: [:axis, :button]
    field :axis, Ecto.Enum, values: @axes
    field :button, :integer
    field :inverted, :boolean, default: false

    belongs_to :input, Input

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:input_id, :device_index, :target_type, :axis, :button, :inverted])
    |> validate_required([:input_id, :device_index, :target_type, :inverted])
    |> validate_inclusion(:device_index, [1], message: "must be 1")
    |> validate_number(:button, greater_than_or_equal_to: 1, less_than_or_equal_to: 32)
    |> validate_target_shape()
    |> foreign_key_constraint(:input_id)
    |> unique_constraint(:input_id)
    |> unique_constraint(:axis, name: :virtual_joystick_mappings_device_index_axis_index)
    |> unique_constraint(:button, name: :virtual_joystick_mappings_device_index_button_index)
    |> check_constraint(:device_index, name: :virtual_joystick_mappings_device_index_check)
    |> check_constraint(:target_type, name: :virtual_joystick_mappings_target_shape_check)
    |> check_constraint(:axis, name: :virtual_joystick_mappings_axis_check)
    |> check_constraint(:button, name: :virtual_joystick_mappings_button_check)
  end

  @doc false
  def validate_input_type(changeset, %Input{input_type: :analog}) do
    if get_field(changeset, :target_type) == :axis do
      changeset
    else
      add_error(changeset, :target_type, "must target an axis")
    end
  end

  def validate_input_type(changeset, %Input{input_type: :button}) do
    if get_field(changeset, :target_type) == :button do
      changeset
    else
      add_error(changeset, :target_type, "must target a button")
    end
  end

  defp validate_target_shape(changeset) do
    case get_field(changeset, :target_type) do
      :axis ->
        changeset
        |> validate_required(:axis)
        |> validate_absent(:button)

      :button ->
        changeset
        |> validate_required(:button)
        |> validate_absent(:axis)

      _ ->
        changeset
    end
  end

  defp validate_absent(changeset, field) do
    if is_nil(get_field(changeset, field)) do
      changeset
    else
      add_error(changeset, field, "must be blank")
    end
  end
end
