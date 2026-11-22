defmodule Trenino.Train.LeverSetup do
  @moduledoc """
  The steps of setting up a lever, shared by the Lever Setup Wizard and the
  MCP lever tools so both produce the same configuration.

  1. `set_endpoint/2` points the lever at a simulator control.
  2. Its notches are saved: `calibrate/4` sweeps the control (Train Sim
     World), `configure_from_catalog/3` reads them from the control's notch
     table (simulators with `:control_catalog`, SimRail). `catalog?/0` says
     which one applies to the connected simulator.
  3. `bind_input/2` binds an analog hardware input.
  4. The user maps the physical lever's notches in the wizard (UI only).

  `next_step/1` says which of these is still missing.
  """

  import Ecto.Query, only: [where: 3]

  alias Trenino.Hardware
  alias Trenino.Hardware.Input
  alias Trenino.Repo
  alias Trenino.Simulator
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.LeverAnalyzer
  alias Trenino.Simulator.LeverAnalyzer.AnalysisResult
  alias Trenino.Simulator.SimRailLevers
  alias Trenino.Train
  alias Trenino.Train.{Element, LeverConfig, LeverController, LeverInputBinding, Notch}

  @wizard_steps ~w(select_lever_type select_input find_endpoint run_calibration map_notches)a

  @type step :: :set_endpoint | :calibrate | :bind_input | :map_notches | :done

  @type calibration :: %{lever_config: LeverConfig.t(), analysis: AnalysisResult.t()}

  @type catalog_configuration :: %{
          lever_config: LeverConfig.t(),
          analysis: SimRailLevers.Analysis.t()
        }

  @doc "Wizard steps a deep link may open."
  @spec wizard_steps() :: [atom()]
  def wizard_steps, do: @wizard_steps

  @doc """
  Whether the connected simulator reports its levers' notch tables, so lever
  notches come from `configure_from_catalog/3` instead of a sweep.
  """
  @spec catalog?() :: boolean()
  def catalog?, do: Simulator.supports?(:control_catalog)

  @doc """
  The simulator endpoints of the lever at `control_path`,
  e.g. `"CurrentDrivableActor/MasterController"` on Train Sim World or
  `"Physics_Input_General.main_brake"` on SimRail.
  """
  @spec endpoints_for(String.t(), Simulator.simulator()) :: map()
  def endpoints_for(control_path, simulator \\ :tsw)

  def endpoints_for(control_path, :simrail) when is_binary(control_path),
    do: SimRailLevers.endpoints(control_path)

  def endpoints_for(control_path, :tsw) when is_binary(control_path) do
    %{
      min_endpoint: "#{control_path}.Function.GetMinimumInputValue",
      max_endpoint: "#{control_path}.Function.GetMaximumInputValue",
      value_endpoint: "#{control_path}.InputValue",
      notch_count_endpoint: "#{control_path}.Function.GetNotchCount",
      notch_index_endpoint: "#{control_path}.Function.GetCurrentNotchIndex"
    }
  end

  @doc "The control path a lever config points at, or `nil`."
  @spec control_path(LeverConfig.t() | nil) :: String.t() | nil
  def control_path(%LeverConfig{value_endpoint: endpoint}) when is_binary(endpoint),
    do: String.replace_suffix(endpoint, ".InputValue", "")

  def control_path(_), do: nil

  @doc """
  Points a lever element at a simulator control. When the control changes,
  the old notches are removed because they belong to the old control.
  """
  @spec set_endpoint(integer(), String.t()) :: {:ok, LeverConfig.t()} | {:error, term()}
  def set_endpoint(element_id, control_path) do
    result =
      with {:ok, %Element{type: :lever} = element} <-
             fetch_lever_element(element_id, preload: :train),
           :ok <- check_simulator(element) do
        attrs = endpoints_for(control_path, element.train.simulator)

        case Train.get_lever_config(element_id) do
          {:ok, %LeverConfig{} = config} -> update_endpoint(config, control_path, attrs)
          {:error, :not_found} -> Train.create_lever_config(element_id, attrs)
        end
      end

    reload_after(result)
  end

  defp update_endpoint(%LeverConfig{} = config, control_path, attrs) do
    Repo.transaction(fn ->
      if control_path(config) != control_path do
        Notch |> where([n], n.lever_config_id == ^config.id) |> Repo.delete_all()
      end

      case Train.update_lever_config(config, attrs) do
        {:ok, updated} -> Repo.preload(updated, :notches, force: true)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Sweeps the lever's simulator control and saves the notches it finds.

  The sweep moves the lever in the game and can move the train; see
  `Trenino.Simulator.LeverAnalyzer.analyze/3` for the safety checks.

  ## Options

    - `:endpoints` - endpoint attrs to save with the config (default: derived from the path)
    - `:analyzer` - options passed to `LeverAnalyzer.analyze/3`
  """
  @spec calibrate(Client.t(), integer(), String.t(), keyword()) ::
          {:ok, calibration()} | {:error, term()}
  def calibrate(%Client{} = client, element_id, control_path, opts \\ []) do
    attrs = Keyword.get_lazy(opts, :endpoints, fn -> endpoints_for(control_path) end)
    attrs = Map.put(attrs, :calibrated_at, DateTime.utc_now(:second))

    result =
      with {:ok, %Element{type: :lever} = element} <-
             fetch_lever_element(element_id, preload: :train),
           :ok <- check_sweepable(element),
           {:ok, %AnalysisResult{} = analysis} <-
             LeverAnalyzer.analyze(client, control_path, Keyword.get(opts, :analyzer, [])),
           {:ok, config} <- save_analysis(element_id, attrs, analysis) do
        {:ok, %{lever_config: config, analysis: analysis}}
      end

    reload_after(result)
  end

  @doc """
  Saves the notches of the lever at `control_path` from the connected
  simulator's control catalogue (`Trenino.Simulator.controls/0`), without
  moving anything. See `Trenino.Simulator.SimRailLevers` for how a notch
  table becomes notches, including spring-return positions.

  The lever's train must be made for the connected simulator.

  ## Options

    - `:control_id` - which control to read when several controls write
      `control_path` with different notch tables (one per cab, or a smooth
      and a stepped variant); otherwise `{:error, {:ambiguous_control, ids}}`
  """
  @spec configure_from_catalog(integer(), String.t(), keyword()) ::
          {:ok, catalog_configuration()} | {:error, term()}
  def configure_from_catalog(element_id, control_path, opts \\ []) when is_binary(control_path) do
    result =
      with {:ok, %Element{type: :lever} = element} <-
             fetch_lever_element(element_id, preload: :train),
           :ok <- check_simulator(element),
           {:ok, controls} <- Simulator.controls(),
           {:ok, control} <-
             SimRailLevers.find(controls, control_path, Keyword.get(opts, :control_id)),
           {:ok, analysis} <- SimRailLevers.analyze(control),
           {:ok, config} <-
             save_analysis(element_id, catalog_attrs(element, control_path), analysis) do
        {:ok, %{lever_config: config, analysis: analysis}}
      end

    reload_after(result)
  end

  defp catalog_attrs(%Element{train: train}, control_path) do
    control_path
    |> endpoints_for(train.simulator)
    |> Map.put(:calibrated_at, DateTime.utc_now(:second))
  end

  # A sweep runs on a TSW client, so only Train Sim World profiles are swept.
  defp check_sweepable(%Element{train: %{simulator: :tsw}}), do: :ok

  defp check_sweepable(%Element{train: %{simulator: simulator}}),
    do: {:error, {:wrong_simulator, simulator, :tsw}}

  # The lever's train must be made for the connected simulator, so a profile
  # never gets endpoints or notches from another simulator.
  defp check_simulator(%Element{train: %{simulator: simulator}}) do
    case Simulator.current() do
      ^simulator -> :ok
      nil -> {:error, :not_connected}
      connected -> {:error, {:wrong_simulator, simulator, connected}}
    end
  end

  defp save_analysis(element_id, attrs, analysis) do
    case Train.get_lever_config(element_id) do
      {:ok, existing} -> Train.update_lever_config_with_analysis(existing, attrs, analysis)
      {:error, :not_found} -> Train.create_lever_config_with_analysis(element_id, attrs, analysis)
    end
  end

  @doc """
  Binds an analog hardware input to the lever. The input must be calibrated,
  because the notch mapping step reads its calibrated position.
  """
  @spec bind_input(integer(), integer()) :: {:ok, LeverInputBinding.t()} | {:error, term()}
  def bind_input(element_id, input_id) do
    result =
      with {:ok, %LeverConfig{} = config} <- lever_config(element_id),
           {:ok, %Input{} = input} <- Hardware.get_input(input_id, preload: [:calibration]),
           :ok <- check_bindable(input) do
        Train.bind_input(config.id, input.id)
      end

    reload_after(result)
  end

  defp check_bindable(%Input{input_type: type}) when type != :analog, do: {:error, :not_analog}
  defp check_bindable(%Input{calibration: nil}), do: {:error, :not_calibrated}
  defp check_bindable(%Input{}), do: :ok

  @doc """
  The next step a lever still needs, with a short reason for the user.
  """
  @spec next_step(integer()) :: {:ok, step(), String.t()} | {:error, term()}
  def next_step(element_id) do
    with {:ok, %Element{type: :lever} = element} <-
           fetch_lever_element(element_id,
             preload: [lever_config: [:notches, input_binding: [input: :calibration]]]
           ) do
      {step, reason} = step_for(element.lever_config)
      {:ok, step, reason}
    end
  end

  defp step_for(nil), do: {:set_endpoint, "The lever is not linked to a simulator control yet."}

  defp step_for(%LeverConfig{notches: []}),
    do: {:calibrate, "The simulator control has not been calibrated yet."}

  defp step_for(%LeverConfig{input_binding: nil}),
    do: {:bind_input, "No hardware input is bound to the lever yet."}

  defp step_for(%LeverConfig{input_binding: %LeverInputBinding{input: %Input{calibration: nil}}}),
    do: {:bind_input, "The bound hardware input is not calibrated. Calibrate it first."}

  defp step_for(%LeverConfig{notches: notches}) do
    if Enum.all?(notches, &(is_number(&1.input_min) and is_number(&1.input_max))) do
      {:done, "The lever is set up."}
    else
      {:map_notches,
       "Map the physical lever's notches in the Lever Setup Wizard; this needs the user."}
    end
  end

  @doc "The wizard step that matches a lever step."
  @spec wizard_step(step()) :: atom()
  def wizard_step(:set_endpoint), do: :find_endpoint
  def wizard_step(:calibrate), do: :run_calibration
  def wizard_step(:bind_input), do: :select_input
  def wizard_step(_), do: :map_notches

  @doc "The app path that opens the lever wizard on `element` at `step`."
  @spec ui_path(Element.t(), atom()) :: String.t()
  def ui_path(%Element{id: id, train_id: train_id}, step) do
    "/trains/#{train_id}?" <> URI.encode_query(lever: id, step: step)
  end

  defp lever_config(element_id) do
    case Train.get_lever_config(element_id) do
      {:ok, config} -> {:ok, config}
      {:error, :not_found} -> {:error, :no_endpoint}
    end
  end

  defp fetch_lever_element(element_id, opts) do
    case Train.get_element(element_id, opts) do
      {:ok, %Element{type: :lever}} = ok -> ok
      {:ok, %Element{}} -> {:error, :not_a_lever}
      error -> error
    end
  end

  defp reload_after({:ok, _} = ok) do
    LeverController.reload_bindings()
    ok
  end

  defp reload_after(error), do: error
end
