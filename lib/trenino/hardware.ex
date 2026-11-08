defmodule Trenino.Hardware do
  @moduledoc """
  Context for hardware device configurations and management.
  """

  import Ecto.Query

  alias Trenino.Hardware.Calibration.{Calculator, SessionSupervisor}

  alias Trenino.Hardware.{
    ConfigId,
    Device,
    DialCalibration,
    Gauge,
    I2cModule,
    Input,
    Matrix,
    Output
  }

  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.Input.MatrixPin
  alias Trenino.Repo
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Protocol.SetGaugePosition
  alias Trenino.Serial.Protocol.SetOutput
  alias Trenino.Serial.Protocol.WriteSegments
  alias Trenino.Serial.Protocol.ZeroGauge

  # Gauge operations (X27 gauge modules, firmware >= 3.3.0)

  @max_gauges_per_device 4
  @gauge_firmware "3.3.0"

  @doc "Most gauges one device accepts in a configuration (firmware limit)."
  @spec max_gauges_per_device() :: pos_integer()
  def max_gauges_per_device, do: @max_gauges_per_device

  @doc "Lowest firmware version that drives gauges."
  @spec gauge_firmware_version() :: String.t()
  def gauge_firmware_version, do: @gauge_firmware

  @spec list_gauges(integer()) :: [Gauge.t()]
  def list_gauges(device_id),
    do:
      Repo.all(
        from g in Gauge,
          where: g.device_id == ^device_id,
          order_by: g.id,
          preload: :dial_calibration
      )

  @spec list_all_gauges() :: [Gauge.t()]
  def list_all_gauges,
    do: Repo.all(from g in Gauge, order_by: g.id) |> Repo.preload([:device, :dial_calibration])

  @spec get_gauge(term()) :: {:ok, Gauge.t()} | {:error, :not_found}
  def get_gauge(id) when is_integer(id) and id > 0 do
    case Repo.get(Gauge, id) do
      nil -> {:error, :not_found}
      gauge -> {:ok, Repo.preload(gauge, [:device, :dial_calibration])}
    end
  end

  def get_gauge(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> get_gauge(n)
      _ -> {:error, :not_found}
    end
  end

  def get_gauge(_), do: {:error, :not_found}

  @doc """
  Creates a gauge. Missing travel, speed and acceleration take the driver's defaults.
  """
  @spec create_gauge(integer(), map()) :: {:ok, Gauge.t()} | {:error, Ecto.Changeset.t()}
  def create_gauge(device_id, attrs) do
    attrs = with_driver_defaults(attrs)
    save_gauge(%Gauge{device_id: device_id}, attrs, :insert)
  end

  @doc """
  Updates a gauge. Changing the driver, pins or direction changes what a stored dial
  position means, so the dial is cleared and the gauge's bindings are disabled; so is a
  travel change that leaves a dial point out of range.
  """
  @spec update_gauge(Gauge.t(), map()) :: {:ok, Gauge.t()} | {:error, Ecto.Changeset.t()}
  def update_gauge(%Gauge{} = gauge, attrs),
    do: save_gauge(gauge, swap_driver_defaults(gauge, attrs), :update)

  # Switching driver without giving travel, speed or acceleration moves the fields still at
  # the old driver's defaults to the new driver's (the old ones may be out of range).
  defp swap_driver_defaults(%Gauge{driver: old} = gauge, attrs) do
    string_keys? = Enum.any?(Map.keys(attrs), &is_binary/1)
    key = fn field -> if string_keys?, do: Atom.to_string(field), else: field end

    new =
      case Map.get(attrs, key.(:driver)) do
        d when d in [:direct, "direct"] -> :direct
        d when d in [:vid6606, "vid6606"] -> :vid6606
        _ -> old
      end

    old_defaults = Gauge.defaults(old)

    untouched? = fn field ->
      not Map.has_key?(attrs, key.(field)) and Map.fetch!(gauge, field) == old_defaults[field]
    end

    if new == old,
      do: attrs,
      else:
        Gauge.defaults(new)
        |> Enum.filter(fn {field, _} -> untouched?.(field) end)
        |> Enum.reduce(attrs, fn {field, value}, acc -> Map.put(acc, key.(field), value) end)
  end

  @spec delete_gauge(Gauge.t()) :: {:ok, Gauge.t()} | {:error, Ecto.Changeset.t()}
  def delete_gauge(%Gauge{} = gauge), do: gauge |> Repo.delete() |> notify_gauge_configuration()

  @doc "A changeset for gauge forms, with the device-wide checks applied."
  @spec change_gauge(Gauge.t(), map()) :: Ecto.Changeset.t()
  def change_gauge(%Gauge{} = gauge, attrs \\ %{}), do: gauge_changeset(gauge, attrs)

  defp with_driver_defaults(attrs) do
    driver =
      case Map.get(attrs, :driver, Map.get(attrs, "driver")) do
        d when d in [:direct, "direct"] -> :direct
        _ -> :vid6606
      end

    string_keys? = Enum.any?(Map.keys(attrs), &is_binary/1)

    Enum.reduce(Gauge.defaults(driver), attrs, fn {key, value}, acc ->
      key = if string_keys?, do: Atom.to_string(key), else: key

      case Map.get(acc, key) do
        blank when blank in [nil, ""] -> Map.put(acc, key, value)
        _ -> acc
      end
    end)
  end

  defp save_gauge(gauge, attrs, operation) do
    Repo.transact(fn ->
      with {:ok, saved} <- apply(Repo, operation, [gauge_changeset(gauge, attrs)]) do
        invalidate_dial(gauge, saved)
        {:ok, saved}
      end
    end)
    |> notify_gauge_configuration()
  end

  defp gauge_changeset(gauge, attrs) do
    cs = Gauge.changeset(gauge, attrs)

    with true <- cs.valid?,
         %Device{} <-
           Repo.get(Device, cs.data.device_id || Ecto.Changeset.get_field(cs, :device_id)) do
      validate_gauge_on_device(cs)
    else
      nil -> Ecto.Changeset.add_error(cs, :device_id, "does not exist")
      false -> cs
    end
  end

  # Device-wide rules the firmware enforces at Configure: four gauges at most, and a gauge's
  # own pins (STEP/DIR or coils) used by no other gauge, not even as its RESET_N. Gauges on
  # one VID6606 share RESET_N. Pins are also kept clear of inputs, matrices and outputs,
  # because the firmware ignores SetOutput on a gauge pin.
  defp validate_gauge_on_device(cs) do
    gauge = Ecto.Changeset.apply_changes(cs)
    peers = gauge.device_id |> list_gauges() |> Enum.reject(&(&1.id == gauge.id))
    own = Gauge.own_pins(gauge)
    reset = Gauge.reset_pin(gauge)
    taken_by_gauges = Enum.flat_map(peers, &Gauge.used_pins/1)
    peer_own = Enum.flat_map(peers, &Gauge.own_pins/1)
    others = other_device_pins(gauge.device_id)

    cond do
      length(peers) >= @max_gauges_per_device ->
        Ecto.Changeset.add_error(
          cs,
          :device_id,
          "already has #{@max_gauges_per_device} gauges, the most one device can drive"
        )

      clash = Enum.find(own, &(&1 in taken_by_gauges)) ->
        Ecto.Changeset.add_error(cs, :pins, "pin #{clash} is used by another gauge")

      reset && reset in peer_own ->
        Ecto.Changeset.add_error(cs, :pins, "pin #{reset} is used by another gauge")

      clash = Enum.find(Gauge.used_pins(gauge), &Map.has_key?(others, &1)) ->
        Ecto.Changeset.add_error(
          cs,
          :pins,
          "pin #{clash} is used by #{Map.fetch!(others, clash)}"
        )

      true ->
        cs
    end
  end

  defp other_device_pins(device_id) do
    inputs =
      Repo.all(
        from i in Input,
          where: i.device_id == ^device_id and i.input_type in [:analog, :button],
          select: {i.pin, "an input"}
      )

    matrix =
      Repo.all(
        from p in MatrixPin,
          join: m in assoc(p, :matrix),
          where: m.device_id == ^device_id,
          select: {p.pin, "a button matrix"}
      )

    outputs =
      Repo.all(from o in Output, where: o.device_id == ^device_id, select: {o.pin, "an output"})

    Map.new(inputs ++ matrix ++ outputs)
  end

  # Dial points are positions in steps from the end stop. Driver, pins or direction
  # change what physical angle a step count means, so the dial is dropped; a shorter
  # travel only matters when a point no longer fits.
  @dial_meaning_fields [:driver, :pins, :reverse]

  defp invalidate_dial(%Gauge{id: nil}, _), do: :ok

  defp invalidate_dial(old, updated) do
    if Enum.any?(@dial_meaning_fields, &(Map.get(old, &1) != Map.get(updated, &1))) or
         point_outside_travel?(updated) do
      Repo.delete_all(from(c in DialCalibration, where: c.gauge_id == ^old.id))

      Repo.update_all(from(b in Trenino.Train.GaugeBinding, where: b.gauge_id == ^old.id),
        set: [enabled: false]
      )
    end

    :ok
  end

  defp point_outside_travel?(%Gauge{id: id, travel: travel}) do
    case get_dial_calibration(id) do
      {:ok, %DialCalibration{points: points}} -> Enum.any?(points, &(&1.position > travel))
      {:error, :not_found} -> false
    end
  end

  @doc """
  The dial calibration of a gauge, or `{:error, :not_found}` when none is recorded yet.
  """
  @spec get_dial_calibration(integer()) :: {:ok, DialCalibration.t()} | {:error, :not_found}
  def get_dial_calibration(gauge_id) do
    case Repo.get_by(DialCalibration, gauge_id: gauge_id) do
      nil -> {:error, :not_found}
      calibration -> {:ok, calibration}
    end
  end

  @doc """
  Creates or replaces the dial calibration of a gauge (`points`, `output_unit`,
  `reviewed`), validated against its travel. Pure data: never moves the needle.

  Saving a dial that is not marked reviewed disables every train binding on the gauge,
  because a binding cannot run on an unreviewed dial.
  """
  @spec save_dial_calibration(Gauge.t(), map()) ::
          {:ok, DialCalibration.t()} | {:error, Ecto.Changeset.t()}
  def save_dial_calibration(%Gauge{} = gauge, attrs) do
    current =
      case get_dial_calibration(gauge.id) do
        {:ok, calibration} -> calibration
        {:error, :not_found} -> %DialCalibration{gauge_id: gauge.id, points: []}
      end

    current
    |> DialCalibration.changeset(attrs, gauge)
    |> Repo.insert_or_update()
    |> disable_bindings_unless_reviewed(gauge)
    |> notify_gauge_configuration()
  end

  defp disable_bindings_unless_reviewed({:ok, %DialCalibration{reviewed: false}} = result, gauge) do
    Repo.update_all(from(b in Trenino.Train.GaugeBinding, where: b.gauge_id == ^gauge.id),
      set: [enabled: false]
    )

    result
  end

  defp disable_bindings_unless_reviewed(result, _gauge), do: result

  defp notify_gauge_configuration({:ok, _} = result) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "train:gauges:configuration",
      {:gauge_bindings_changed, :all}
    )

    result
  end

  defp notify_gauge_configuration(error), do: error

  @doc """
  Sends the saved configuration (inputs, displays and gauges) to the connected device.
  Every gauge re-zeros when the device stores it.
  """
  @spec apply_saved_configuration(integer()) :: {:ok, integer()} | {:error, term()}
  def apply_saved_configuration(device_id) do
    with {:ok, device} <- get_device(device_id),
         %{port: port} <- connected_device(device) || {:error, :device_not_connected} do
      apply_configuration(port, device_id)
    end
  end

  defp connected_device(%Device{config_id: config_id}),
    do:
      Enum.find(
        Connection.list_devices(),
        &(&1.device_config_id == config_id and &1.status == :connected)
      )

  @doc """
  Where to send gauge commands for a device: its serial port, once the device is
  connected, runs firmware that drives gauges and has confirmed the saved configuration.
  """
  @spec gauge_link(Device.t() | integer()) ::
          {:ok, String.t()}
          | {:error, :device_not_connected | :firmware_update_required | :needs_apply}
  def gauge_link(device_id) when is_integer(device_id) do
    case get_device(device_id) do
      {:ok, device} -> gauge_link(device)
      _ -> {:error, :device_not_connected}
    end
  end

  def gauge_link(%Device{} = device) do
    with %{port: port, device_version: version} <-
           connected_device(device) || {:error, :device_not_connected},
         :ok <- gauge_firmware(version),
         :applied <- config_status(device, device_fingerprint(device.id)) do
      {:ok, port}
    else
      {:error, _} = error -> error
      _status -> {:error, :needs_apply}
    end
  end

  @doc "`:ok` when a firmware version string drives gauges."
  @spec gauge_firmware(String.t() | nil) :: :ok | {:error, :firmware_update_required}
  def gauge_firmware(version) do
    with true <- is_binary(version),
         {:ok, parsed} <- Version.parse(version),
         true <- parsed.pre == [] and Version.compare(parsed, @gauge_firmware) != :lt do
      :ok
    else
      _ -> {:error, :firmware_update_required}
    end
  end

  @doc """
  Moves a gauge's needle to `position` steps from the end stop (clamped to its travel).
  Fire-and-forget: the device never confirms.
  """
  @spec set_gauge_position(String.t(), Gauge.t(), integer()) :: :ok | {:error, term()}
  def set_gauge_position(port, %Gauge{} = gauge, position) when is_integer(position) do
    message = %SetGaugePosition{
      pin: Gauge.wire_pin(gauge),
      position: position |> max(0) |> min(gauge.travel)
    }

    Connection.send_message(port, message)
  end

  @doc "Sweeps a gauge into its end stop again, then back to its latest position."
  @spec zero_gauge(String.t(), Gauge.t()) :: :ok | {:error, term()}
  def zero_gauge(port, %Gauge{} = gauge),
    do: Connection.send_message(port, %ZeroGauge{pin: Gauge.wire_pin(gauge)})

  # Delegate configuration operations to ConfigurationManager
  defdelegate apply_configuration(port, device_id), to: Trenino.Hardware.ConfigurationManager
  defdelegate subscribe_configuration(), to: Trenino.Hardware.ConfigurationManager
  defdelegate subscribe_input_values(port), to: Trenino.Hardware.ConfigurationManager
  defdelegate get_input_values(port), to: Trenino.Hardware.ConfigurationManager

  @doc """
  Set a digital output pin to high or low.

  This is a fire-and-forget operation with no acknowledgment from the device.

  ## Parameters
    - port: Serial port identifier
    - pin: Output pin number (0-255)
    - value: `:low` or `:high`

  ## Examples

      iex> Hardware.set_output("/dev/ttyUSB0", 13, :high)
      :ok

      iex> Hardware.set_output("/dev/ttyUSB0", 13, :low)
      :ok

  """
  @spec set_output(String.t(), integer(), :low | :high) :: :ok | {:error, term()}
  def set_output(port, pin, value) when value in [:low, :high] do
    message = %SetOutput{pin: pin, value: value}
    Connection.send_message(port, message)
  end

  # Configuration operations

  @doc """
  List all configurations.

  Returns configurations ordered by name.

  ## Options

    * `:preload` - List of associations to preload (default: [])

  """
  @spec list_configurations(keyword()) :: [Device.t()]
  def list_configurations(opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    Device
    |> order_by([d], d.name)
    |> Repo.all()
    |> Repo.preload(preloads)
  end

  # Device operations

  @doc """
  Get a device by ID.

  ## Options

    * `:preload` - List of associations to preload (default: [])

  ## Examples

      iex> get_device(123)
      {:ok, %Device{}}

      iex> get_device(999)
      {:error, :not_found}

  """
  @spec get_device(integer(), keyword()) :: {:ok, Device.t()} | {:error, :not_found}
  def get_device(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    case Repo.get(Device, id) do
      nil -> {:error, :not_found}
      device -> {:ok, Repo.preload(device, preloads)}
    end
  end

  @doc """
  Get a device by config_id.

  The config_id is the stable link between a physical device and its configuration
  in the database. It's stored on the device and returned in IdentityResponse.
  """
  @spec get_device_by_config_id(integer()) :: {:ok, Device.t()} | {:error, :not_found}
  def get_device_by_config_id(config_id) do
    case Repo.get_by(Device, config_id: config_id) do
      nil -> {:error, :not_found}
      device -> {:ok, Repo.preload(device, :inputs)}
    end
  end

  @doc """
  Map config_ids to their configuration names. Unknown config_ids are left out.
  """
  @spec configuration_names([integer()]) :: %{integer() => String.t()}
  def configuration_names([]), do: %{}

  def configuration_names(config_ids) when is_list(config_ids) do
    Device
    |> where([d], d.config_id in ^config_ids)
    |> select([d], {d.config_id, d.name})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Create a new device.
  """
  @spec create_device(map()) :: {:ok, Device.t()} | {:error, Ecto.Changeset.t()}
  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a device.
  """
  @spec update_device(Device.t(), map()) :: {:ok, Device.t()} | {:error, Ecto.Changeset.t()}
  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a device configuration.

  This will cascade delete all associated inputs, matrices, and calibrations.
  Returns an error if the configuration is currently active on any connected device.

  ## Examples

      iex> delete_device(device)
      {:ok, %Device{}}

      iex> delete_device(device)  # when active on a device
      {:error, :configuration_active}

  """
  @spec delete_device(Device.t()) ::
          {:ok, Device.t()} | {:error, :configuration_active | Ecto.Changeset.t()}
  def delete_device(%Device{} = device) do
    if configuration_active?(device.config_id) do
      {:error, :configuration_active}
    else
      delete_device_cascade(device)
    end
  end

  defp delete_device_cascade(%Device{} = device) do
    # Delete inputs and their calibrations first (cascade)
    {:ok, inputs} = list_inputs(device.id, include_virtual_buttons: true)
    Enum.each(inputs, &delete_input_with_calibration/1)

    # Delete matrices (will cascade delete matrix pins)
    {:ok, matrices} = list_matrices(device.id)
    Enum.each(matrices, &Repo.delete/1)

    # Delete the device (its gauges and dials go with it)
    device |> Repo.delete() |> notify_gauge_configuration()
  end

  defp delete_input_with_calibration(%Input{} = input) do
    # Delete calibration if exists
    case Repo.get_by(Calibration, input_id: input.id) do
      nil -> :ok
      calibration -> Repo.delete(calibration)
    end

    Repo.delete(input)
  end

  defp configuration_active?(config_id) when is_nil(config_id), do: false

  defp configuration_active?(config_id) do
    Connection.list_devices()
    |> Enum.any?(fn device ->
      device.status == :connected and device.device_config_id == config_id
    end)
  end

  @doc """
  Update device with config_id after successful configuration.

  This is called by the ConfigurationManager when a ConfigurationStored
  message is received from the device.
  """
  @spec confirm_configuration(integer(), integer(), String.t() | nil) ::
          {:ok, Device.t()} | {:error, term()}
  def confirm_configuration(device_id, config_id, fingerprint \\ nil) do
    with {:ok, device} <- get_device(device_id) do
      device
      |> Device.changeset(%{config_id: config_id})
      |> Ecto.Changeset.put_change(
        :applied_fingerprint,
        fingerprint || device.applied_fingerprint
      )
      |> Repo.update()
    end
  end

  @doc """
  Fingerprint of everything that is sent to the device when a configuration is applied.

  Names, descriptions and calibration data are excluded because they never reach the
  device. Compare with `Device.applied_fingerprint` to know whether the saved
  configuration differs from the one last confirmed by the device.
  """
  @spec config_fingerprint(list(), list(), list(), [Gauge.t()]) :: String.t()
  def config_fingerprint(inputs, matrices, i2c_modules, gauges) do
    term = {
      inputs |> Enum.map(&{&1.pin, &1.input_type, &1.sensitivity, &1.debounce}) |> Enum.sort(),
      matrices |> Enum.map(&matrix_pins/1) |> Enum.sort(),
      i2c_modules |> Enum.map(&i2c_wire_config/1) |> Enum.sort(),
      gauges
      |> Enum.map(&{&1.pins, &1.driver, &1.travel, &1.max_speed, &1.acceleration, &1.reverse})
      |> Enum.sort()
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(term, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  # Mirrors ConfigurationManager.build_configure_message/4: only these reach the device.
  # The other display params (orientation, dot, alignment, min value) are applied in software.
  defp i2c_wire_config(%{module_chip: :ht16k33, i2c_address: address, params: params}),
    do: {:ht16k33, address, params.brightness, params.num_digits}

  defp matrix_pins(matrix),
    do: {Enum.map(matrix.row_pins, & &1.pin), Enum.map(matrix.col_pins, & &1.pin)}

  @doc "Fingerprint of a device's saved configuration, loaded from the database."
  @spec device_fingerprint(integer()) :: String.t()
  def device_fingerprint(device_id) do
    {:ok, inputs} = list_inputs(device_id)
    {:ok, matrices} = list_matrices(device_id)
    config_fingerprint(inputs, matrices, list_i2c_modules(device_id), list_gauges(device_id))
  end

  @doc """
  Whether the saved configuration matches what the device last confirmed.

  `:unknown` when the device never recorded a fingerprint (created before fingerprints
  existed, or never applied): there is nothing to compare against, so no claim is made.
  """
  @spec config_status(Device.t(), String.t()) :: :applied | :unapplied | :unknown
  def config_status(%Device{applied_fingerprint: nil}, _current), do: :unknown
  def config_status(%Device{applied_fingerprint: current}, current), do: :applied
  def config_status(%Device{}, _current), do: :unapplied

  @doc """
  Generate a unique random configuration ID.

  Generates a random ID within the i32 range that doesn't conflict
  with existing IDs in the database.
  """
  @spec generate_config_id() :: {:ok, integer()}
  defdelegate generate_config_id(), to: ConfigId, as: :generate

  # Input operations

  @doc """
  List all inputs for a device, ordered by pin.

  ## Options

    * `:include_virtual_buttons` - Include virtual buttons from matrices (default: false)

  """
  @spec list_inputs(integer(), keyword()) :: {:ok, [Input.t()]}
  def list_inputs(device_id, opts \\ []) do
    include_virtual = Keyword.get(opts, :include_virtual_buttons, false)

    query =
      Input
      |> where([i], i.device_id == ^device_id)
      |> order_by([i], i.pin)
      |> preload([:calibration])

    query =
      if include_virtual do
        query
      else
        where(query, [i], is_nil(i.matrix_id))
      end

    inputs = Repo.all(query)

    {:ok, inputs}
  end

  @doc """
  List all inputs across all devices.

  Returns inputs with their device preloaded, ordered by device name then pin.
  Only includes calibrated inputs by default.

  ## Options

    * `:include_uncalibrated` - Include inputs without calibration (default: false)
    * `:include_virtual_buttons` - Include virtual buttons from matrices (default: false)

  """
  @spec list_all_inputs(keyword()) :: [Input.t()]
  def list_all_inputs(opts \\ []) do
    include_uncalibrated = Keyword.get(opts, :include_uncalibrated, false)
    include_virtual = Keyword.get(opts, :include_virtual_buttons, false)

    query =
      Input
      |> join(:inner, [i], d in Device, on: i.device_id == d.id)
      |> order_by([i, d], [d.name, i.pin])
      |> preload([:device, :calibration])

    query =
      if include_uncalibrated do
        query
      else
        query
        |> join(:inner, [i, d], c in Calibration, on: c.input_id == i.id)
      end

    query =
      if include_virtual do
        query
      else
        where(query, [i], is_nil(i.matrix_id))
      end

    Repo.all(query)
  end

  @doc """
  Create an input for a device.
  """
  @spec create_input(integer(), map()) :: {:ok, Input.t()} | {:error, Ecto.Changeset.t()}
  def create_input(device_id, attrs) do
    %Input{device_id: device_id}
    |> Input.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Delete an input by ID or Input struct.
  """
  @spec delete_input(integer() | Input.t()) ::
          {:ok, Input.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_input(input_id) when is_integer(input_id) do
    case Repo.get(Input, input_id) do
      nil -> {:error, :not_found}
      input -> Repo.delete(input)
    end
  end

  def delete_input(%Input{} = input) do
    Repo.delete(input)
  end

  @doc """
  Update an input.
  """
  @spec update_input(Input.t(), map()) :: {:ok, Input.t()} | {:error, Ecto.Changeset.t()}
  def update_input(%Input{} = input, attrs) do
    input
    |> Input.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Get an input by ID.

  ## Options

    * `:preload` - List of associations to preload (default: [])
  """
  @spec get_input(integer(), keyword()) :: {:ok, Input.t()} | {:error, :not_found}
  def get_input(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    case Repo.get(Input, id) do
      nil -> {:error, :not_found}
      input -> {:ok, Repo.preload(input, preloads)}
    end
  end

  # Matrix operations

  @doc """
  List all matrices for a device.
  """
  @spec list_matrices(integer()) :: {:ok, [Matrix.t()]}
  def list_matrices(device_id) do
    matrices =
      Matrix
      |> where([m], m.device_id == ^device_id)
      |> order_by([m], m.name)
      |> preload([:row_pins, :col_pins, :buttons])
      |> Repo.all()

    {:ok, matrices}
  end

  @doc """
  Get a matrix by ID.

  ## Options

    * `:preload` - List of associations to preload (default: [:row_pins, :col_pins, :buttons])
  """
  @spec get_matrix(integer(), keyword()) :: {:ok, Matrix.t()} | {:error, :not_found}
  def get_matrix(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:row_pins, :col_pins, :buttons])

    case Repo.get(Matrix, id) do
      nil -> {:error, :not_found}
      matrix -> {:ok, Repo.preload(matrix, preloads)}
    end
  end

  @doc """
  Create a matrix configuration with row/column pins.

  Automatically creates virtual button inputs for each cell in the matrix.

  ## Parameters
    - device_id: The device ID
    - attrs: Map containing :name, :row_pins, :col_pins
      - row_pins: [2, 3, 4]  (list of pin numbers)
      - col_pins: [5, 6, 7]  (list of pin numbers)

  ## Examples

      iex> create_matrix(device_id, %{
        name: "Main Panel",
        row_pins: [2, 3, 4],
        col_pins: [5, 6, 7]
      })
      {:ok, %Matrix{}}
  """
  @spec create_matrix(integer(), map()) :: {:ok, Matrix.t()} | {:error, Ecto.Changeset.t()}
  def create_matrix(device_id, attrs) do
    row_pins = Map.get(attrs, :row_pins, [])
    col_pins = Map.get(attrs, :col_pins, [])

    Repo.transaction(fn ->
      with {:ok, matrix} <- insert_matrix(device_id, attrs),
           :ok <- setup_matrix_pins_and_buttons(device_id, matrix.id, row_pins, col_pins) do
        Repo.preload(matrix, [:row_pins, :col_pins, :buttons])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_matrix(device_id, attrs) do
    %Matrix{device_id: device_id}
    |> Matrix.changeset(Map.take(attrs, [:name]))
    |> Repo.insert()
  end

  @doc """
  Update matrix configuration.

  If row_pins or col_pins are provided, removes old virtual buttons and creates new ones.
  Existing button bindings for removed buttons will be cascade deleted.
  """
  @spec update_matrix(Matrix.t(), map()) :: {:ok, Matrix.t()} | {:error, term()}
  def update_matrix(%Matrix{} = matrix, attrs) do
    row_pins = Map.get(attrs, :row_pins)
    col_pins = Map.get(attrs, :col_pins)

    Repo.transaction(fn ->
      with {:ok, matrix} <- maybe_update_name(matrix, attrs),
           {:ok, matrix} <- maybe_update_pins(matrix, row_pins, col_pins) do
        matrix
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp maybe_update_name(matrix, attrs) do
    if Map.has_key?(attrs, :name) do
      matrix
      |> Matrix.changeset(Map.take(attrs, [:name]))
      |> Repo.update()
    else
      {:ok, matrix}
    end
  end

  defp maybe_update_pins(matrix, nil, _col_pins), do: {:ok, matrix}
  defp maybe_update_pins(matrix, _row_pins, nil), do: {:ok, matrix}

  defp maybe_update_pins(matrix, row_pins, col_pins) do
    delete_matrix_children(matrix.id)

    with :ok <- setup_matrix_pins_and_buttons(matrix.device_id, matrix.id, row_pins, col_pins) do
      {:ok, Repo.preload(matrix, [:row_pins, :col_pins, :buttons], force: true)}
    end
  end

  defp delete_matrix_children(matrix_id) do
    from(i in Input, where: i.matrix_id == ^matrix_id) |> Repo.delete_all()
    from(mp in MatrixPin, where: mp.matrix_id == ^matrix_id) |> Repo.delete_all()
  end

  defp setup_matrix_pins_and_buttons(device_id, matrix_id, row_pins, col_pins) do
    with {:ok, _pins} <- create_matrix_pins(matrix_id, row_pins, col_pins),
         {:ok, _buttons} <- create_virtual_buttons(device_id, matrix_id, row_pins, col_pins) do
      :ok
    end
  end

  @doc """
  Delete a matrix and all its virtual buttons.

  Button bindings for virtual buttons will be cascade deleted.
  """
  @spec delete_matrix(Matrix.t()) :: {:ok, Matrix.t()} | {:error, term()}
  def delete_matrix(%Matrix{} = matrix) do
    Repo.delete(matrix)
  end

  @spec delete_matrix(integer()) :: {:ok, Matrix.t()} | {:error, :not_found | term()}
  def delete_matrix(matrix_id) when is_integer(matrix_id) do
    case Repo.get(Matrix, matrix_id) do
      nil -> {:error, :not_found}
      matrix -> Repo.delete(matrix)
    end
  end

  # Private matrix helpers

  defp create_matrix_pins(matrix_id, row_pins, col_pins) do
    # Create row pins
    row_results =
      row_pins
      |> Enum.with_index()
      |> Enum.map(fn {pin, position} ->
        %MatrixPin{}
        |> MatrixPin.changeset(%{
          matrix_id: matrix_id,
          pin_type: :row,
          pin: pin,
          position: position
        })
        |> Repo.insert()
      end)

    # Create col pins
    col_results =
      col_pins
      |> Enum.with_index()
      |> Enum.map(fn {pin, position} ->
        %MatrixPin{}
        |> MatrixPin.changeset(%{
          matrix_id: matrix_id,
          pin_type: :col,
          pin: pin,
          position: position
        })
        |> Repo.insert()
      end)

    all_results = row_results ++ col_results

    case Enum.find(all_results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(all_results, fn {:ok, pin} -> pin end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_virtual_buttons(device_id, matrix_id, row_pins, col_pins) do
    num_rows = length(row_pins)
    num_cols = length(col_pins)

    buttons =
      for row_idx <- 0..(num_rows - 1),
          col_idx <- 0..(num_cols - 1) do
        virtual_pin = Matrix.virtual_pin(row_idx, col_idx, num_cols)

        %Input{}
        |> Input.changeset(%{
          device_id: device_id,
          matrix_id: matrix_id,
          input_type: :button,
          pin: virtual_pin,
          name: "R#{row_idx}C#{col_idx}",
          debounce: 50
        })
        |> Repo.insert()
      end

    case Enum.find(buttons, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(buttons, fn {:ok, btn} -> btn end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # Output operations

  @doc """
  List all outputs for a device, ordered by pin.
  """
  @spec list_outputs(integer()) :: {:ok, [Output.t()]}
  def list_outputs(device_id) do
    outputs =
      Output
      |> where([o], o.device_id == ^device_id)
      |> order_by([o], o.pin)
      |> Repo.all()

    {:ok, outputs}
  end

  @doc """
  Get an output by ID.
  """
  @spec get_output(integer()) :: {:ok, Output.t()} | {:error, :not_found}
  def get_output(id) do
    case Repo.get(Output, id) do
      nil -> {:error, :not_found}
      output -> {:ok, Repo.preload(output, :device)}
    end
  end

  @doc """
  Create an output for a device.
  """
  @spec create_output(integer(), map()) :: {:ok, Output.t()} | {:error, Ecto.Changeset.t()}
  def create_output(device_id, attrs) do
    %Output{device_id: device_id}
    |> Output.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Delete an output by ID or Output struct.
  """
  @spec delete_output(integer() | Output.t()) ::
          {:ok, Output.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_output(output_id) when is_integer(output_id) do
    case Repo.get(Output, output_id) do
      nil -> {:error, :not_found}
      output -> Repo.delete(output)
    end
  end

  def delete_output(%Output{} = output) do
    Repo.delete(output)
  end

  @doc """
  Update an output.
  """
  @spec update_output(Output.t(), map()) :: {:ok, Output.t()} | {:error, Ecto.Changeset.t()}
  def update_output(%Output{} = output, attrs) do
    output
    |> Output.changeset(attrs)
    |> Repo.update()
  end

  # I2C module operations

  @doc "List all i2c modules for a device."
  @spec list_i2c_modules(integer()) :: [I2cModule.t()]
  def list_i2c_modules(device_id) do
    I2cModule
    |> where([m], m.device_id == ^device_id)
    |> order_by([m], m.i2c_address)
    |> Repo.all()
  end

  @doc "List all i2c modules across all devices (for MCP tools)."
  @spec list_all_i2c_modules() :: [I2cModule.t()]
  def list_all_i2c_modules do
    I2cModule
    |> order_by([m], m.i2c_address)
    |> preload(:device)
    |> Repo.all()
  end

  @doc "Get a single i2c module by id."
  @spec get_i2c_module(integer()) :: {:ok, I2cModule.t()} | {:error, :not_found}
  def get_i2c_module(id) do
    case Repo.get(I2cModule, id) do
      nil -> {:error, :not_found}
      mod -> {:ok, Repo.preload(mod, :device)}
    end
  end

  @doc "Create an i2c module on a device."
  @spec create_i2c_module(integer(), map()) :: {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
  def create_i2c_module(device_id, attrs) do
    %I2cModule{device_id: device_id}
    |> I2cModule.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update an i2c module."
  @spec update_i2c_module(I2cModule.t(), map()) ::
          {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
  def update_i2c_module(%I2cModule{} = mod, attrs) do
    mod
    |> I2cModule.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete an i2c module."
  @spec delete_i2c_module(I2cModule.t()) :: {:ok, I2cModule.t()} | {:error, Ecto.Changeset.t()}
  def delete_i2c_module(%I2cModule{} = mod) do
    Repo.delete(mod)
  end

  @doc "Send WriteSegments to an I2C display module."
  @spec write_segments(String.t(), integer(), binary()) :: :ok | {:error, term()}
  def write_segments(port, i2c_address, data) do
    message = %WriteSegments{i2c_address: i2c_address, data: data}
    Connection.send_message(port, message)
  end

  # Calibration operations

  @doc """
  Start a calibration session for an input.

  ## Options

    * `:max_hardware_value` - Optional. Hardware max value (default: 1023).

  Returns `{:ok, pid}` on success.
  """
  @spec start_calibration_session(Input.t(), String.t(), keyword()) ::
          {:ok, pid()} | {:error, term()}
  def start_calibration_session(%Input{} = input, port, opts \\ []) do
    session_opts =
      Keyword.merge(opts,
        input_id: input.id,
        port: port,
        pin: input.pin
      )

    SessionSupervisor.start_session(session_opts)
  end

  @doc """
  Save calibration data for an input.

  Creates or updates the calibration for the given input.
  """
  @spec save_calibration(integer(), map()) ::
          {:ok, Calibration.t()} | {:error, Ecto.Changeset.t()}
  def save_calibration(input_id, attrs) do
    attrs_with_input = Map.put(attrs, :input_id, input_id)

    case Repo.get_by(Calibration, input_id: input_id) do
      nil ->
        %Calibration{}
        |> Calibration.changeset(attrs_with_input)
        |> Repo.insert()

      existing ->
        existing
        |> Calibration.changeset(attrs_with_input)
        |> Repo.update()
    end
  end

  @doc """
  Normalize a raw input value using its calibration.

  Returns the normalized value (0 to total_travel).
  """
  @spec normalize_value(integer(), Calibration.t()) :: integer()
  defdelegate normalize_value(raw_value, calibration), to: Calculator, as: :normalize

  @doc """
  Get the total travel range for a calibration.
  """
  @spec total_travel(Calibration.t()) :: integer()
  defdelegate total_travel(calibration), to: Calculator
end
