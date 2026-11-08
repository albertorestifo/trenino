defmodule Trenino.Beta do
  @moduledoc """
  Feature flags for beta features.

  Every known flag is listed in `@features`. How flags resolve is set by
  `config :trenino, :beta_features`:

    * `:all` - every beta feature is on (dev and test).
    * `:setting` - the default, used by releases. Beta features follow the
      "Enable beta features" setting on the Settings page.

  Gate only entry points (UI sections, menu options, MCP tools), never
  contexts, schemas or GenServers. Gates call `enabled?/1` directly or use
  the `beta_<feature>` assigns set by `TreninoWeb.NavHook`, so graduating a
  feature means removing it from `@features` and deleting the matches of
  `beta_<feature>` and `Beta.enabled?(:<feature>)`.
  """

  alias Trenino.Settings

  @features [
    # Stepper-motor gauges such as speedometers: hardware gauges, gauge
    # bindings, dial calibration.
    :gauges,
    # Windows virtual joystick: the Joystick page and its MCP tools.
    :joystick,
    # Selectors: an analog input used as a rotary switch with fixed positions.
    :selectors
  ]

  @type feature :: :gauges | :joystick | :selectors

  @spec features() :: [feature()]
  def features, do: @features

  @spec enabled?(feature()) :: boolean()
  def enabled?(feature) when feature in @features do
    case Application.get_env(:trenino, :beta_features, :setting) do
      :all -> true
      :setting -> Settings.beta_features?()
    end
  end

  @doc "Whether the Settings page should offer the beta features toggle."
  @spec configurable?() :: boolean()
  def configurable?, do: Application.get_env(:trenino, :beta_features, :setting) == :setting
end
