defmodule Trenino.Simulator.Backend do
  @moduledoc """
  The contract every simulator integration implements (Train Sim World,
  SimRail).

  A backend is a module; a connected backend is a `handle` - an opaque term
  the backend creates in `connect/1` and receives in every other callback.
  `Trenino.Simulator.Connection` owns the handle (in
  `Trenino.Simulator.ConnectionState`, field `client`), and the rest of the
  app reaches the backend only through the `Trenino.Simulator` facade.

  Paths are strings in the backend's own format, stored as-is in train
  configuration: TSW uses `"CurrentDrivableActor/Throttle(Lever).InputValue"`,
  SimRail uses `"Physics_Input_EN57.maincontroller_a"`.
  """

  alias Trenino.Simulator.Control

  @type handle :: term()
  @type path :: String.t()
  @type value :: number() | boolean() | String.t() | map()
  @type error :: {:error, term()}

  @typedoc "Backend configuration, as stored in settings."
  @type config :: %{
          optional(:url) => String.t(),
          optional(:api_key) => String.t() | nil,
          optional(atom()) => term()
        }

  @typedoc "Optional abilities, see `capabilities/0`."
  @type capability :: :push_values | :control_catalog | :vehicle_events

  @doc "Stable identifier of the simulator, stored with train configuration."
  @callback id() :: Trenino.Simulator.simulator()

  @doc """
  What the backend can do beyond the required callbacks:

    * `:push_values` - `watch/3` pushes changed values; otherwise the caller
      polls `read/2`.
    * `:control_catalog` - `controls/1` returns the vehicle's controls with
      notch tables; otherwise levers are discovered by sweeping.
    * `:vehicle_events` - `watch/3` also reports vehicle changes.
  """
  @callback capabilities() :: [capability()]

  @doc "Create a handle from configuration. Must not block on the network."
  @callback connect(config()) :: {:ok, handle()} | error()

  @doc "Reach the simulator: used for the initial check and health checks."
  @callback check(handle()) :: {:ok, map()} | error()

  @doc "Release resources held by the handle (sockets, processes)."
  @callback disconnect(handle()) :: :ok

  @doc "Read one value."
  @callback get(handle(), path()) :: {:ok, value()} | error()

  @doc "Read several values at once. Missing paths are left out of the map."
  @callback read(handle(), [path()]) :: {:ok, %{path() => value()}} | error()

  @doc "Write one value."
  @callback set(handle(), path(), value()) :: :ok | error()

  @doc """
  Identify the vehicle the player is driving, as the string train
  configurations are matched against (TSW: the formation's ObjectClass;
  SimRail: the vehicle name such as `"4e/eu07-193"`).
  """
  @callback vehicle_id(handle()) :: {:ok, String.t()} | error()

  @doc "The player vehicle's controls (only with `:control_catalog`)."
  @callback controls(handle()) :: {:ok, [Control.t()]} | error()

  @doc """
  Push changes of `paths` to `pid` as
  `{:simulator_values, %{path => value}}` messages, and with
  `:vehicle_events` also `{:simulator_vehicle, vehicle_id | nil}`.
  Calling it again replaces the watched set for `pid`; `[]` stops watching.
  Only with `:push_values`.
  """
  @callback watch(handle(), [path()], pid()) :: :ok | error()

  @doc """
  The process that pushes `watch/3` values for this handle, or nil when none
  runs. It keeps its watched paths in memory only, so a watcher monitors it
  and calls `watch/3` again when it goes down. Only with `:push_values`.
  """
  @callback watch_process(handle()) :: pid() | nil

  @optional_callbacks controls: 1, watch: 3, watch_process: 1
end
