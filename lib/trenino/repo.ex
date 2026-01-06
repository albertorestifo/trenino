defmodule Trenino.Repo do
  use Ecto.Repo,
    otp_app: :trenino,
    adapter: Ecto.Adapters.SQLite3
end
