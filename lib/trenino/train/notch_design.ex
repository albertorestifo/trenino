defmodule Trenino.Train.NotchDesign do
  @moduledoc """
  Turns a calibrated lever's notches into a design for the train-lever notch
  disk generator, and builds the link that opens the generator with it.

  The generator's simple view spreads 2 to 13 positions evenly over the
  lever's travel, and each position is one of three feels:

    - Standard: a clear click.
    - Deep: a strong hold, for centre or emergency positions.
    - Smooth: no notch, the lever glides through. The first and last
      positions are always notches, never Smooth.

  ## Mapping

  Notches are taken in index order, which is the simulator's input order.

    - A gate is one position. It is Deep when it is the lever's emergency or
      centre position: its name contains Emergency, Off, Idle, Coast or
      Neutral, or it is the zero-output gate between negative and positive
      outputs (the BR430's "0"). Every other gate, such as stepped power
      notches, Set-up or 1A, is Standard.
    - A linear range is a run of Smooth positions. Its length follows the
      range's share of the simulator input travel: one position per
      `travel / notch count`, at least one. A range at an end of travel gets
      a Standard end-stop position named after the range, since the ends
      can't be Smooth. Two ranges next to each other are split by an
      unnamed Standard position.
    - When there are more than 13 positions, the longest Smooth runs are
      shortened first, down to one position each.

  The generator checks the design when it opens. Deep needs room: with
  more than about 9 positions it doesn't fit, and the generator then makes
  those positions Standard and says so.
  """

  alias Trenino.Train.{LeverConfig, Notch}

  @max_positions 13
  @min_positions 2
  @default_generator_url "https://albertorestifo.github.io/train-lever-generator/"
  @deep_name ~r/\b(emergency|off|idle|coast|neutral)\b/i

  @type feel :: :standard | :deep | :smooth

  @type t :: %__MODULE__{
          name: String.t() | nil,
          positions: [{feel(), String.t()}]
        }

  @enforce_keys [:positions]
  defstruct [:name, :positions]

  @type error :: :no_notches | :too_few_positions | :too_many_positions

  @doc """
  Builds the design for a lever's notches. `name` becomes the disk name.
  """
  @spec from_notches([Notch.t()], String.t() | nil) :: {:ok, t()} | {:error, error()}
  def from_notches(notches, name \\ nil)

  def from_notches([], _name), do: {:error, :no_notches}

  def from_notches(notches, name) when is_list(notches) do
    notches = Enum.sort_by(notches, fn %Notch{index: index} -> index end)
    pitch = pitch(notches)
    zero_centre = zero_centre?(notches)

    segments =
      notches
      |> Enum.map(&segment(&1, pitch, zero_centre))
      |> add_end_stops()

    with :ok <- check_size(segments) do
      positions = segments |> fit(@max_positions) |> expand()
      {:ok, %__MODULE__{name: name, positions: positions}}
    end
  end

  @doc "The number of positions on the disk."
  @spec count(t()) :: pos_integer()
  def count(%__MODULE__{positions: positions}), do: length(positions)

  @doc "1-based positions with the given feel."
  @spec positions_with(t(), feel()) :: [pos_integer()]
  def positions_with(%__MODULE__{positions: positions}, feel) do
    for {{^feel, _label}, i} <- Enum.with_index(positions, 1), do: i
  end

  @doc """
  The generator link that opens this design, ready to download. The base URL
  comes from `config :trenino, :notch_generator_url`.
  """
  @spec generator_url(t()) :: String.t()
  def generator_url(%__MODULE__{} = design) do
    base = Application.get_env(:trenino, :notch_generator_url, @default_generator_url)

    query =
      [
        {"positions", count(design)},
        {"deep", Enum.join(positions_with(design, :deep), ",")},
        {"smooth", Enum.join(positions_with(design, :smooth), ",")}
      ] ++
        Enum.map(design.positions, fn {_feel, label} -> {"label", label} end) ++
        if(design.name, do: [{"name", design.name}], else: [])

    base <> "?" <> URI.encode_query(query)
  end

  @doc """
  The generator link for a lever, or a sentence saying why it has none.
  Takes the lever config with its notches preloaded (or `nil`).
  """
  @spec generator_link(LeverConfig.t() | nil, String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def generator_link(lever_config, name \\ nil)

  def generator_link(%LeverConfig{notches: notches}, name) when is_list(notches) do
    case from_notches(notches, name) do
      {:ok, design} -> {:ok, generator_url(design)}
      {:error, reason} -> {:error, error_message(reason)}
    end
  end

  def generator_link(_lever_config, _name), do: {:error, error_message(:no_notches)}

  @doc "Says why a lever has no design, for a tooltip or tool error."
  @spec error_message(error()) :: String.t()
  def error_message(:no_notches), do: "Calibrate the lever first to detect its notches."

  def error_message(:too_few_positions),
    do: "The lever has a single notch, so there is nothing to design."

  def error_message(:too_many_positions),
    do: "The lever has more than #{@max_positions} notches, more than a disk can hold."

  # Segments: {:notch, feel, label} or {:smooth, length, label}

  defp segment(%Notch{type: :gate} = notch, _pitch, zero_centre) do
    feel = if deep?(notch, zero_centre), do: :deep, else: :standard
    {:notch, feel, label(notch)}
  end

  defp segment(%Notch{type: :linear} = notch, pitch, _zero_centre) do
    length =
      case {width(notch), pitch} do
        {width, pitch} when is_number(width) and is_number(pitch) and pitch > 0 ->
          max(1, round(width / pitch))

        _ ->
          1
      end

    {:smooth, length, label(notch)}
  end

  defp label(%Notch{description: description}) when is_binary(description),
    do: String.trim(description)

  defp label(%Notch{}), do: ""

  defp deep?(%Notch{} = notch, zero_centre) do
    Regex.match?(@deep_name, label(notch)) or (zero_centre and zero?(notch.value))
  end

  defp zero?(value), do: is_number(value) and value == 0

  # A zero-output gate is the centre when outputs go both negative and positive.
  defp zero_centre?(notches) do
    outputs = Enum.flat_map(notches, &[&1.value, &1.min_value, &1.max_value])
    numbers = Enum.filter(outputs, &is_number/1)
    Enum.any?(numbers, &(&1 < 0)) and Enum.any?(numbers, &(&1 > 0))
  end

  defp width(%Notch{sim_input_min: min, sim_input_max: max})
       when is_number(min) and is_number(max),
       do: max - min

  defp width(%Notch{}), do: nil

  # One position's share of the simulator input travel
  defp pitch(notches) do
    mins = notches |> Enum.map(& &1.sim_input_min) |> Enum.filter(&is_number/1)
    maxs = notches |> Enum.map(& &1.sim_input_max) |> Enum.filter(&is_number/1)

    if mins != [] and maxs != [] do
      (Enum.max(maxs) - Enum.min(mins)) / length(notches)
    end
  end

  defp add_end_stops(segments) do
    segments
    |> split_adjacent_ranges()
    |> cap_start()
    |> Enum.reverse()
    |> cap_start()
    |> Enum.reverse()
  end

  defp cap_start([{:smooth, _length, label} | _] = segments),
    do: [{:notch, :standard, label} | segments]

  defp cap_start(segments), do: segments

  defp split_adjacent_ranges([{:smooth, _, _} = a, {:smooth, _, _} = b | rest]),
    do: [a, {:notch, :standard, ""} | split_adjacent_ranges([b | rest])]

  defp split_adjacent_ranges([segment | rest]), do: [segment | split_adjacent_ranges(rest)]
  defp split_adjacent_ranges([]), do: []

  defp check_size(segments) do
    # Every Smooth run keeps at least one position
    minimum = Enum.count(segments, &match?({:notch, _, _}, &1)) + Enum.count(segments, &smooth?/1)

    cond do
      minimum > @max_positions -> {:error, :too_many_positions}
      minimum < @min_positions -> {:error, :too_few_positions}
      true -> :ok
    end
  end

  defp smooth?({:smooth, _length, _label}), do: true
  defp smooth?(_segment), do: false

  # Shortens the longest Smooth run (the first one on a tie) until the disk fits.
  defp fit(segments, max) do
    total = Enum.sum_by(segments, &size/1)

    longest =
      segments
      |> Enum.with_index()
      |> Enum.filter(fn {segment, _i} -> smooth?(segment) end)
      |> Enum.max_by(fn {{:smooth, length, _}, _i} -> length end, fn -> nil end)

    case longest do
      {{:smooth, length, label}, i} when total > max and length > 1 ->
        segments |> List.replace_at(i, {:smooth, length - 1, label}) |> fit(max)

      _ ->
        segments
    end
  end

  defp size({:notch, _feel, _label}), do: 1
  defp size({:smooth, length, _label}), do: length

  defp expand(segments) do
    Enum.flat_map(segments, fn
      {:notch, feel, label} -> [{feel, label}]
      {:smooth, length, _label} -> List.duplicate({:smooth, ""}, length)
    end)
  end
end
