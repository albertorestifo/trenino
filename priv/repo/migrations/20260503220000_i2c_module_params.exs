defmodule Trenino.Repo.Migrations.I2cModuleParams do
  use Ecto.Migration

  import Ecto.Query

  def up do
    alter table(:device_i2c_modules) do
      add :params, :text
    end

    flush()

    rows =
      Trenino.Repo.all(
        from(m in "device_i2c_modules", select: {m.id, m.brightness, m.num_digits})
      )

    Enum.each(rows, fn {id, brightness, num_digits} ->
      params_json =
        Jason.encode!(%{
          brightness: brightness || 8,
          num_digits: num_digits || 4,
          display_type: "fourteen_segment",
          has_dot: false,
          align_right: true,
          min_value: 0.0
        })

      Trenino.Repo.update_all(
        from(m in "device_i2c_modules", where: m.id == ^id),
        set: [params: params_json]
      )
    end)

    alter table(:device_i2c_modules) do
      remove :brightness
      remove :num_digits
    end
  end

  def down do
    alter table(:device_i2c_modules) do
      add :brightness, :integer, null: false, default: 8
      add :num_digits, :integer, null: false, default: 4
    end

    flush()

    rows = Trenino.Repo.all(from(m in "device_i2c_modules", select: {m.id, m.params}))

    Enum.each(rows, fn {id, params_json} ->
      case Jason.decode(params_json || "{}") do
        {:ok, %{"brightness" => b, "num_digits" => n}} ->
          Trenino.Repo.update_all(
            from(m in "device_i2c_modules", where: m.id == ^id),
            set: [brightness: b, num_digits: n]
          )

        _ ->
          :ok
      end
    end)

    alter table(:device_i2c_modules) do
      remove :params
    end
  end
end
