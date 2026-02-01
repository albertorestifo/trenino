# Ensure the application is started before setting up test infrastructure
{:ok, _} = Application.ensure_all_started(:trenino)

Mimic.copy(Req, type_check: true)
Mimic.copy(Trenino.Train.Identifier)
Mimic.copy(Trenino.Simulator.Client)
Mimic.copy(Trenino.Simulator)
Mimic.copy(Trenino.Simulator.AutoConfig)
Mimic.copy(Trenino.AppVersion)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Trenino.Repo, :manual)
