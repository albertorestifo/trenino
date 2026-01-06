defmodule Trenino.Repo.Migrations.RemoveNanoOldBootloaderFirmware do
  use Ecto.Migration

  def change do
    execute(
      "DELETE FROM firmware_files WHERE board_type = 'nano_old_bootloader'",
      "SELECT 1"
    )
  end
end
