defmodule Trenino.Hardware.I2cInputs do
  @moduledoc """
  Virtual pin allocation and child input lifecycle for I2C input chips.

  Each chip owns blocks of virtual pins, allocated from 255 downward so the low
  end stays free for board-pin matrices. A child `Input` is identified across
  edits by `i2c_channel`, because its pin can change. A base of 0 marks a block
  as unused, and bases are always computed here, never taken from the caller.
  """

  import Bitwise
  import Ecto.Query

  alias Ecto.Changeset
  alias Trenino.Hardware.ADS1115.Params, as: ADS1115Params
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.MCP23017.Params, as: MCP23017Params
  alias Trenino.Repo
  alias Trenino.Train.ButtonController
  alias Trenino.Train.ButtonInputBinding
  alias Trenino.Train.Element
  alias Trenino.Train.LeverConfig
  alias Trenino.Train.LeverController
  alias Trenino.Train.LeverInputBinding
  alias Trenino.Train.Train
  alias Trenino.VirtualJoystick.Manager
  alias Trenino.VirtualJoystick.Mapping

  @type child :: %{
          i2c_channel: integer(),
          pin: integer(),
          input_type: :analog | :button,
          name: String.t()
        }

  @type impact :: %{input_id: integer(), name: String.t(), binding: String.t()}

  @type block :: {base_field :: atom(), size :: non_neg_integer()}

  @first_virtual_pin 128
  @last_virtual_pin 255
  @direct_block_size 16
  @ads_block_size 4
  @matrix_channel_offset 16
  @default_sensitivity 5
  @base_keys [:direct_base, :matrix_base, :pin_base]
  @no_room "not enough free virtual pins on this device"

  @doc "Find the highest block of `size` free virtual pins."
  @spec allocate(MapSet.t(integer()), pos_integer()) :: {:ok, integer()} | :error
  def allocate(%MapSet{} = used, size) when is_integer(size) and size > 0 do
    (@last_virtual_pin + 1 - size)..@first_virtual_pin//-1
    |> Enum.find(&free?(used, &1, size))
    |> case do
      nil -> :error
      base -> {:ok, base}
    end
  end

  @doc "The child inputs described by a module's params, in channel order."
  @spec children(I2cModule.t()) :: [child()]
  def children(%I2cModule{params: %MCP23017Params{} = params}) do
    direct_children(params) ++ matrix_children(params)
  end

  def children(%I2cModule{params: %ADS1115Params{} = params}) do
    for channel <- bits(params.channel_mask) do
      %{
        i2c_channel: channel,
        pin: params.pin_base + channel,
        input_type: :analog,
        name: "AIN#{channel}"
      }
    end
  end

  def children(%I2cModule{}), do: []

  @doc "The virtual pin blocks a module reserves, whether or not each pin has a child."
  @spec reserved_pins(I2cModule.t()) :: MapSet.t(integer())
  def reserved_pins(%I2cModule{params: params}) do
    for {field, size} <- blocks(params),
        base = Map.fetch!(params, field),
        base != 0,
        pin <- base..(base + size - 1),
        into: MapSet.new() do
      pin
    end
  end

  @doc "Every pin reserved by a chip on the device."
  @spec device_reserved_pins(integer()) :: MapSet.t(integer())
  def device_reserved_pins(device_id) do
    from(m in I2cModule, where: m.device_id == ^device_id)
    |> Repo.all()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&2, reserved_pins(&1)))
  end

  @doc """
  Drop host-computed and non-schema keys from module attrs.

  Returns the attrs to cast and the `:channels` map, keyed by integer channel with
  atom-keyed `:name` and `:sensitivity` entries, or `:invalid` when it cannot be
  read, which `save/2` reports as an error on `:params`.
  """
  @spec split_attrs(map()) :: {map(), %{integer() => map()} | :invalid}
  def split_attrs(attrs) when is_map(attrs) do
    channels = Map.get(attrs, :channels) || Map.get(attrs, "channels") || %{}
    attrs = Map.drop(attrs, [:channels, "channels"])

    {strip_bases(attrs), normalize_channels(channels)}
  end

  @doc """
  Insert or update a module and sync its child inputs in one transaction.

  The changeset must come from attrs passed through `split_attrs/1`.
  """
  @spec save(Changeset.t(), map() | :invalid) :: {:ok, I2cModule.t()} | {:error, Changeset.t()}
  def save(%Changeset{} = changeset, :invalid) do
    {:error, params_error(changeset, "has invalid channel settings")}
  end

  def save(%Changeset{} = changeset, channels) do
    if input_chip?(changeset) do
      fn -> save_chip(changeset, channels) end
      |> Repo.transaction(mode: :immediate)
      |> tap(&notify_on_success/1)
    else
      Repo.insert_or_update(changeset)
    end
  end

  @doc "Delete a module with its child inputs and their calibrations and bindings."
  @spec delete(I2cModule.t()) :: {:ok, I2cModule.t()} | {:error, Changeset.t()}
  def delete(%I2cModule{id: id} = mod) do
    fn ->
      from(i in Input, where: i.i2c_module_id == ^id, select: i.id)
      |> Repo.all()
      |> delete_inputs()

      case Repo.delete(mod) do
        {:ok, deleted} -> deleted
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end
    |> Repo.transaction()
    |> tap(&notify_on_success/1)
  end

  @doc """
  The bindings that would be lost. Empty `attrs` means deleting the module,
  otherwise the edit they describe. An invalid edit would remove nothing.
  """
  @spec impact(I2cModule.t(), map()) :: [impact()]
  def impact(%I2cModule{} = mod, attrs) when map_size(attrs) == 0 do
    mod |> child_inputs() |> bindings()
  end

  def impact(%I2cModule{} = mod, attrs) do
    {attrs, _channels} = split_attrs(attrs)
    changeset = I2cModule.changeset(Repo.get(I2cModule, mod.id) || mod, attrs)

    if changeset.valid? do
      kept = changeset |> Changeset.apply_changes() |> children() |> channel_set()

      mod
      |> child_inputs()
      |> Enum.reject(&MapSet.member?(kept, &1.i2c_channel))
      |> bindings()
    else
      []
    end
  end

  # Saving

  # Children sync from the row just written, never from the caller's copy, which
  # may be stale.
  defp save_chip(changeset, channels) do
    with {:ok, changeset} <- assign_bases(changeset),
         {:ok, written} <- Repo.insert_or_update(changeset),
         {:ok, mod} <- reload(written),
         :ok <- sync_children(mod, channels) do
      Repo.preload(mod, :inputs, force: true)
    else
      {:error, %Changeset{} = failed} -> Repo.rollback(failed)
      {:error, message} -> changeset |> params_error(message) |> Repo.rollback()
    end
  end

  defp reload(%I2cModule{id: id}) do
    case Repo.get(I2cModule, id) do
      nil -> {:error, "no longer exists"}
      mod -> {:ok, mod}
    end
  end

  # The controllers key inputs on {port, pin}, and pins move with their block.
  defp notify_on_success({:ok, _mod}) do
    LeverController.reload_inputs()
    LeverController.reload_bindings()
    ButtonController.reload_inputs()
    ButtonController.reload_bindings()
    Manager.reload_mappings()
  end

  defp notify_on_success(_result), do: :ok

  defp input_chip?(changeset) do
    chip = Changeset.get_field(changeset, :module_chip)
    changeset.valid? and I2cModule.input_chip?(%I2cModule{module_chip: chip})
  end

  # An edit without params changes no block.
  defp assign_bases(%Changeset{changes: %{params: params}} = changeset) do
    case place_blocks(current_bases(params, changeset), used_pins(changeset)) do
      {:ok, params} -> {:ok, Changeset.put_change(changeset, :params, params)}
      :error -> {:error, @no_room}
    end
  end

  defp assign_bases(changeset), do: {:ok, changeset}

  # Bases come from the row, as the caller's struct may be stale.
  defp current_bases(params, %Changeset{data: %I2cModule{id: nil}}), do: params

  defp current_bases(params, %Changeset{data: %I2cModule{id: id}}) do
    case Repo.get(I2cModule, id) do
      %I2cModule{params: %{__struct__: module} = row} when module == params.__struct__ ->
        params |> blocks() |> Enum.reduce(params, &copy_base(&2, row, &1))

      _ ->
        params
    end
  end

  defp copy_base(params, row, {field, _size}), do: Map.put(params, field, Map.fetch!(row, field))

  # Kept blocks claim their pins first, so a new or moved block cannot land on them.
  defp place_blocks(params, used) do
    {params, pending, used} =
      params
      |> blocks()
      |> Enum.reduce({params, [], used}, fn {field, size}, {params, pending, used} ->
        base = Map.fetch!(params, field)

        cond do
          size == 0 -> {Map.put(params, field, 0), pending, used}
          keep?(used, base, size) -> {params, pending, claim(used, base, size)}
          true -> {params, [{field, size} | pending], used}
        end
      end)

    pending
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, params, used}, fn {field, size}, {:ok, params, used} ->
      case allocate(used, size) do
        {:ok, base} -> {:cont, {:ok, Map.put(params, field, base), claim(used, base, size)}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, params, _used} -> {:ok, params}
      :error -> :error
    end
  end

  defp keep?(_used, base, _size) when base < @first_virtual_pin, do: false
  defp keep?(used, base, size), do: free?(used, base, size)

  defp free?(used, base, size) do
    base + size - 1 <= @last_virtual_pin and
      Enum.all?(base..(base + size - 1), &(not MapSet.member?(used, &1)))
  end

  defp claim(used, base, size), do: MapSet.union(used, MapSet.new(base..(base + size - 1)))

  defp blocks(%MCP23017Params{} = params) do
    rows = MCP23017Params.pin_count(params.row_mask)
    cols = MCP23017Params.pin_count(params.col_mask)

    [
      {:direct_base, if(params.direct_mask == 0, do: 0, else: @direct_block_size)},
      {:matrix_base, rows * cols}
    ]
  end

  defp blocks(%ADS1115Params{}), do: [{:pin_base, @ads_block_size}]
  defp blocks(_params), do: []

  # Everything on the device except this chip's own blocks and children.
  defp used_pins(%Changeset{data: %I2cModule{id: id}} = changeset) do
    device_id = Changeset.get_field(changeset, :device_id)

    modules =
      from(m in I2cModule, where: m.device_id == ^device_id)
      |> exclude_module(id)
      |> Repo.all()

    pins =
      from(i in Input,
        where: i.device_id == ^device_id and i.pin >= @first_virtual_pin,
        select: i.pin
      )
      |> exclude_children(id)
      |> Repo.all()

    Enum.reduce(modules, MapSet.new(pins), &MapSet.union(&2, reserved_pins(&1)))
  end

  defp exclude_module(query, nil), do: query
  defp exclude_module(query, id), do: where(query, [m], m.id != ^id)

  defp exclude_children(query, nil), do: query

  defp exclude_children(query, id),
    do: where(query, [i], is_nil(i.i2c_module_id) or i.i2c_module_id != ^id)

  # Removed rows go first so a kept row can take a freed pin, and moved rows are
  # parked on negative pins so they cannot collide on [device_id, pin] in passing.
  defp sync_children(%I2cModule{} = mod, channels) do
    wanted = children(mod)
    existing = child_inputs(mod)
    wanted_channels = channel_set(wanted)
    existing_by_channel = Map.new(existing, &{&1.i2c_channel, &1})

    existing
    |> Enum.reject(&MapSet.member?(wanted_channels, &1.i2c_channel))
    |> Enum.map(& &1.id)
    |> delete_inputs()

    park_moved(wanted, existing_by_channel)

    wanted
    |> Enum.reduce_while(:ok, fn child, :ok ->
      existing = Map.get(existing_by_channel, child.i2c_channel)

      case save_child(existing, child, mod, Map.get(channels, child.i2c_channel, %{})) do
        {:ok, _input} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, child_error(child, changeset)}}
      end
    end)
  end

  defp park_moved(wanted, existing_by_channel) do
    moved =
      for %{i2c_channel: channel, pin: pin} <- wanted,
          %Input{pin: current, id: id} <- [Map.get(existing_by_channel, channel)],
          current != pin do
        id
      end

    from(i in Input, where: i.id in ^moved, update: [set: [pin: fragment("-pin - 1")]])
    |> Repo.update_all([])
  end

  defp save_child(nil, child, %I2cModule{} = mod, channel) do
    attrs =
      child
      |> Map.merge(%{device_id: mod.device_id, i2c_module_id: mod.id})
      |> Map.merge(child_settings(child, nil, mod, channel))

    %Input{} |> Input.changeset(attrs) |> Repo.insert()
  end

  defp save_child(%Input{} = input, child, %I2cModule{} = mod, channel) do
    attrs = Map.merge(%{pin: child.pin}, child_settings(child, input, mod, channel))

    input |> Input.changeset(attrs) |> Repo.update()
  end

  defp child_settings(child, input, %I2cModule{params: params}, channel) do
    name = Map.get(channel, :name) || (input && input.name) || child.name

    case child.input_type do
      :analog ->
        kept = (input && input.sensitivity) || @default_sensitivity
        %{name: name, sensitivity: Map.get(channel, :sensitivity) || kept}

      :button ->
        %{name: name, debounce: params.debounce}
    end
  end

  defp child_error(child, %Changeset{} = changeset) do
    details =
      changeset
      |> Changeset.traverse_errors(fn {message, opts} ->
        Enum.reduce(opts, message, fn {key, value}, message ->
          String.replace(message, "%{#{key}}", to_string(value))
        end)
      end)
      |> Enum.map_join(", ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)

    "#{child.name}: #{details}"
  end

  defp params_error(changeset, message) do
    action = if changeset.data.id, do: :update, else: :insert
    %{Changeset.add_error(changeset, :params, message) | action: action}
  end

  defp delete_inputs(input_ids) do
    # Calibrations have no ON DELETE action. Bindings and mappings cascade.
    from(c in Calibration, where: c.input_id in ^input_ids) |> Repo.delete_all()
    from(i in Input, where: i.id in ^input_ids) |> Repo.delete_all()
    :ok
  end

  defp child_inputs(%I2cModule{id: id}) do
    from(i in Input, where: i.i2c_module_id == ^id, order_by: i.i2c_channel) |> Repo.all()
  end

  defp channel_set(children), do: MapSet.new(children, & &1.i2c_channel)

  # Child descriptions

  defp direct_children(%MCP23017Params{} = params) do
    for bit <- bits(params.direct_mask) do
      %{
        i2c_channel: bit,
        pin: params.direct_base + bit,
        input_type: :button,
        name: gpio_name(bit)
      }
    end
  end

  defp matrix_children(%MCP23017Params{} = params) do
    cols = bits(params.col_mask)

    for {row_bit, row_index} <- Enum.with_index(bits(params.row_mask)),
        {col_bit, col_index} <- Enum.with_index(cols) do
      %{
        i2c_channel: @matrix_channel_offset + row_bit * 16 + col_bit,
        pin: params.matrix_base + row_index * length(cols) + col_index,
        input_type: :button,
        name: "R#{row_index}C#{col_index}"
      }
    end
  end

  defp gpio_name(bit) when bit < 8, do: "GPA#{bit}"
  defp gpio_name(bit), do: "GPB#{bit - 8}"

  defp bits(mask), do: for(bit <- 0..15, (mask &&& 1 <<< bit) != 0, do: bit)

  # Attrs

  defp strip_bases(attrs) do
    Enum.reduce([:params, "params"], attrs, fn key, attrs ->
      case attrs do
        %{^key => %{} = params} ->
          Map.put(attrs, key, Map.drop(params, @base_keys ++ Enum.map(@base_keys, &to_string/1)))

        _ ->
          attrs
      end
    end)
  end

  defp normalize_channels(channels) when is_map(channels) do
    Enum.reduce_while(channels, %{}, fn {channel, settings}, acc ->
      case {to_channel(channel), settings} do
        {channel, %{} = settings} when is_integer(channel) ->
          entry = %{name: name(settings), sensitivity: sensitivity(settings)}
          {:cont, Map.put(acc, channel, entry)}

        _ ->
          {:halt, :invalid}
      end
    end)
  end

  defp normalize_channels(_channels), do: :invalid

  defp to_channel(channel) when is_integer(channel), do: channel

  defp to_channel(channel) when is_binary(channel) do
    case Integer.parse(channel) do
      {channel, ""} -> channel
      _ -> nil
    end
  end

  defp to_channel(_channel), do: nil

  defp name(settings) do
    case setting(settings, :name) do
      name when is_binary(name) -> if String.trim(name) == "", do: nil, else: name
      _ -> nil
    end
  end

  defp sensitivity(settings) do
    case setting(settings, :sensitivity) do
      "" -> nil
      value -> value
    end
  end

  defp setting(settings, key), do: Map.get(settings, key) || Map.get(settings, to_string(key))

  # Impact

  defp bindings(inputs) do
    ids = Enum.map(inputs, & &1.id)

    described =
      (lever_bindings(ids) ++ button_bindings(ids) ++ joystick_mappings(ids))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    for input <- inputs, binding <- Map.get(described, input.id, []) do
      %{input_id: input.id, name: input.name, binding: binding}
    end
  end

  defp lever_bindings(ids) do
    from(b in LeverInputBinding,
      join: c in LeverConfig,
      on: c.id == b.lever_config_id,
      join: e in Element,
      on: e.id == c.element_id,
      join: t in Train,
      on: t.id == e.train_id,
      where: b.input_id in ^ids,
      select: {b.input_id, e.name, t.name}
    )
    |> Repo.all()
    |> Enum.map(fn {id, element, train} -> {id, "Lever #{element} on #{train}"} end)
  end

  defp button_bindings(ids) do
    from(b in ButtonInputBinding,
      join: e in Element,
      on: e.id == b.element_id,
      join: t in Train,
      on: t.id == e.train_id,
      where: b.input_id in ^ids,
      select: {b.input_id, e.name, t.name}
    )
    |> Repo.all()
    |> Enum.map(fn {id, element, train} -> {id, "Button #{element} on #{train}"} end)
  end

  defp joystick_mappings(ids) do
    from(m in Mapping, where: m.input_id in ^ids)
    |> Repo.all()
    |> Enum.map(&{&1.input_id, "Virtual joystick #{joystick_target(&1)}"})
  end

  defp joystick_target(%Mapping{target_type: :axis, axis: axis}), do: "axis #{axis}"
  defp joystick_target(%Mapping{target_type: :button, button: button}), do: "button #{button}"
end
