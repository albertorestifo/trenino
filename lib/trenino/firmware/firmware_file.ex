defmodule Trenino.Firmware.FirmwareFile do
  @moduledoc """
  Schema for individual firmware files per device environment.

  Each release has multiple firmware files, one for each supported device.
  Device configurations are loaded dynamically from release manifests.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Firmware.FilePath
  alias Trenino.Firmware.FirmwareRelease

  @type t :: %__MODULE__{
          id: integer() | nil,
          firmware_release_id: integer() | nil,
          firmware_release: FirmwareRelease.t() | Ecto.Association.NotLoaded.t(),
          board_type: String.t() | nil,
          environment: String.t() | nil,
          download_url: String.t() | nil,
          file_size: integer() | nil,
          checksum_sha256: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "firmware_files" do
    belongs_to :firmware_release, FirmwareRelease

    field :board_type, :string
    field :environment, :string
    field :download_url, :string
    field :file_size, :integer
    field :checksum_sha256, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a firmware file.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = file, attrs) do
    file
    |> cast(attrs, [
      :firmware_release_id,
      :board_type,
      :environment,
      :download_url,
      :file_size,
      :checksum_sha256
    ])
    |> validate_required([:firmware_release_id, :board_type, :download_url])
    |> foreign_key_constraint(:firmware_release_id)
    |> unique_constraint([:firmware_release_id, :board_type])
  end

  @doc """
  Returns true if this firmware file has been downloaded and cached locally.

  Checks for file existence on disk rather than relying on database fields.
  """
  @spec downloaded?(t()) :: boolean()
  def downloaded?(%__MODULE__{} = file) do
    FilePath.downloaded?(file)
  end
end
