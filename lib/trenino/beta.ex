defmodule Trenino.Beta do
  @moduledoc """
  Feature flags for beta features.

  Every known flag is listed in `@features`. How flags resolve is set by
  `config :trenino, :beta_features`:

    * `:all` - every beta feature is on (dev and test).
    * `:setting` - the default, used by releases. Beta features follow the
      "Enable beta features" setting on the Settings page.

  Opt-in features (`opt_in_features/0`) also need their own toggle, shown under
  the beta features toggle once that is on, and they need the feature they
  build on (`@requires`). They are for parts of a beta feature that are not
  ready for everyone who tries the beta.

  Gate only entry points (UI sections, menu options, MCP tools), never
  contexts, schemas or GenServers. Gates call `enabled?/1` directly or use
  the `beta_<feature>` assigns set by `TreninoWeb.NavHook`, so graduating a
  feature means removing it from `@features` and deleting the matches of
  `beta_<feature>` and `Beta.enabled?(:<feature>)`.
  """

  alias Trenino.Settings

  @features [
    # X27 gauges such as speedometers (firmware 3.3.0): hardware gauges, dial
    # calibration, gauge bindings and their MCP tools.
    :gauges,
    # Selectors: an analog input used as a rotary switch with fixed positions.
    :selectors,
    # SimRail support through the TreninoBridge mod: choosing SimRail as the
    # simulator, its settings and SimRail-specific setup screens and MCP tools.
    :simrail,
    # Guided SimRail setup: finds SimRail, checks MelonLoader and installs the
    # bundled TreninoBridge mod. Opt-in, on top of :simrail.
    :simrail_onboarding
  ]

  @opt_in_features [:simrail_onboarding]

  @requires %{simrail_onboarding: :simrail}

  @type feature :: :gauges | :selectors | :simrail | :simrail_onboarding

  @spec features() :: [feature()]
  def features, do: @features

  @doc "Features that need their own toggle on top of the beta features toggle."
  @spec opt_in_features() :: [feature()]
  def opt_in_features, do: @opt_in_features

  @spec enabled?(feature()) :: boolean()
  def enabled?(feature) when feature in @features do
    case Application.get_env(:trenino, :beta_features, :setting) do
      :all -> true
      :setting -> setting_enabled?(feature)
    end
  end

  defp setting_enabled?(feature) when feature in @opt_in_features do
    Settings.beta_features?() and Settings.beta_feature?(feature) and
      required_enabled?(feature)
  end

  defp setting_enabled?(_feature), do: Settings.beta_features?()

  defp required_enabled?(feature) do
    case Map.fetch(@requires, feature) do
      {:ok, required} -> enabled?(required)
      :error -> true
    end
  end

  @doc "Whether the Settings page should offer the beta features toggle."
  @spec configurable?() :: boolean()
  def configurable?, do: Application.get_env(:trenino, :beta_features, :setting) == :setting
end
