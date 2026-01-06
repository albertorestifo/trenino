defmodule Trenino.Simulator.Config do
  @moduledoc """
  Schema for storing TSW API connection configuration.

  Only one configuration record should exist at a time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          url: String.t(),
          api_key: String.t(),
          auto_detected: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "simulator_configs" do
    field :url, :string
    field :api_key, :string
    field :auto_detected, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating simulator configuration.

  Validates that both URL and API key are present and that the URL
  is properly formatted.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:url, :api_key, :auto_detected])
    |> validate_required([:url, :api_key])
    |> validate_url(:url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      uri = URI.parse(value)

      case uri do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and not is_nil(host) ->
          []

        _ ->
          [{field, "must be a valid HTTP or HTTPS URL"}]
      end
    end)
  end
end
