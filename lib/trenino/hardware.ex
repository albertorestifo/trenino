defmodule Trenino.Hardware do
  @moduledoc """
  Context for hardware device configurations and management.
  """

  import Ecto.Query

  alias Trenino.Hardware.Calibration.{Calculator, SessionSupervisor}
  alias Trenino.Hardware.{ConfigId, Device, Input, Matrix, Output}
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.Input.MatrixPin
  alias Trenino.Repo
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Protocol.SetOutput

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

    # Delete the device
    Repo.delete(device)
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
    Trenino.Serial.Connection.list_devices()
    |> Enum.any?(fn device ->
      device.status == :connected and device.device_config_id == config_id
    end)
  end

  @doc """
  Update device with config_id after successful configuration.

  This is called by the ConfigurationManager when a ConfigurationStored
  message is received from the device.
  """
  @spec confirm_configuration(integer(), integer()) :: {:ok, Device.t()} | {:error, term()}
  def confirm_configuration(device_id, config_id) do
    with {:ok, device} <- get_device(device_id) do
      device
      |> Device.changeset(%{config_id: config_id})
      |> Repo.update()
    end
  end

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
      output -> {:ok, output}
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
