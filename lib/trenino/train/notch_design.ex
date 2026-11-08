defmodule Trenino.Train.NotchDesign do
  @moduledoc """
  Turns a calibrated lever's notches into a design for the train-lever notch
  disk generator, and builds the link that opens the generator with it.

  The generator's simple view spreads 2 to 13 positions evenly over the
  lever's travel, and each position is one of three feels:

    - Standard: a clear click.
    - Deep: a strong hold, for centre or emergency positions.
    - Smooth: a range. A run of Smooth positions is a flat floor at notch
      depth from its first to its last position, with a wall at each end:
      the lever rests anywhere on it and is pushed over a wall to leave.
      Walls beside an Emergency at an end of travel are higher. The first
      and last positions are always notches, never Smooth.

  ## Mapping

  Notches are taken in index order, which is the simulator's input order.

    - A gate is one position. It is Deep when it is the lever's emergency or
      centre position: its name contains Emergency, Off, Idle, Coast or
      Neutral, or it is the zero-output gate between negative and positive
      outputs (the BR430's "0"). Every other gate, such as stepped power
      notches, Set-up or 1A, is Standard.
    - A linear range is a run of Smooth positions. A range at an end of
      travel gets a Standard end-stop position named after the range, since
      the ends can't be Smooth. Two ranges next to each other are split by an
      unnamed Standard position. A range gets at least two positions
      when the disk has room, so its floor has length.

  ## Layout

  The generator spreads positions evenly, and a range's floor runs from its
  first to its last Smooth position, so the run lengths decide where the
  notches and the range ends land. Every
  position count up to 13 and every split of the Smooth positions is tried,
  and the design keeps the one that puts each gate closest to its simulator
  input on the travel (a centred Off becomes the middle position), with a
  small preference for floors that cover their range and for fewer
  positions. Disks with Deep positions stay within 9 positions unless the
  lever needs more.

  The generator checks the design when it opens. Deep needs room: with
  more than about 9 positions it doesn't fit, and the generator then makes
  those positions Standard and says so.
  """

  alias Trenino.Train.{LeverConfig, Notch}

  @max_positions 13
  @min_positions 2
  @default_generator_url "https://albertorestifo.github.io/train-lever-generator/"
  @deep_name ~r/\b(emergency|off|idle|coast|neutral)\b/i
  # Deep fits up to this many positions
  @max_deep_positions 9
  # A gate band this close to an end of travel (as a share of it) sits at the end
  @end_band 0.02
  # Layout scoring, in shares of the travel: a misplaced gate counts fully, a
  # floor falling short of its range a quarter, and each position costs a
  # little so the smallest good disk wins
  @edge_weight 0.25
  @position_cost 0.01

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
    travel = travel(notches)
    zero_centre = zero_centre?(notches)

    segments =
      notches
      |> Enum.map(&segment(&1, travel, zero_centre))
      |> add_stops()

    with :ok <- check_size(segments) do
      {:ok, %__MODULE__{name: name, positions: segments |> layout() |> expand()}}
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

  # Segments, before layout:
  #   {:notch, feel, label, anchor} - one position. `anchor` is where it
  #     belongs on the travel (0.0 to 1.0), or nil when it has no place.
  #   {:smooth, label, edges} - a Smooth run of one or more positions.
  #     `edges` is the range's {from, to} on the travel, or nil.

  defp segment(%Notch{type: :gate} = notch, travel, zero_centre) do
    feel = if deep?(notch, zero_centre), do: :deep, else: :standard
    {:notch, feel, label(notch), gate_anchor(notch, travel)}
  end

  defp segment(%Notch{type: :linear} = notch, travel, _zero_centre) do
    {:smooth, label(notch), range_edges(notch, travel)}
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

  # The simulator input travel, {low, high}. Simulator levers run from 0 or
  # -1 to 1, and the calibrated notches don't always reach the ends (the
  # BR430's power range stops at 0.85), so the travel is widened to those.
  defp travel(notches) do
    inputs =
      notches
      |> Enum.flat_map(&[&1.sim_input_min, &1.sim_input_max])
      |> Enum.filter(&is_number/1)

    case inputs do
      [] ->
        nil

      inputs ->
        {low, high} = Enum.min_max(inputs)
        low = min(low, if(low < 0, do: -1.0, else: 0.0))
        high = max(high, 1.0)
        if high > low, do: {low, high}
    end
  end

  defp fraction(value, {low, high}), do: (value - low) / (high - low)

  # A gate whose band touches an end of travel sits at that end, otherwise at
  # the middle of its band.
  defp gate_anchor(%Notch{sim_input_min: min, sim_input_max: max}, {low, high} = travel)
       when is_number(min) and is_number(max) do
    cond do
      fraction(min, travel) <= @end_band -> 0.0
      fraction(max, travel) >= 1 - @end_band -> 1.0
      true -> fraction((min + max) / 2, {low, high})
    end
  end

  defp gate_anchor(%Notch{}, _travel), do: nil

  defp range_edges(%Notch{sim_input_min: min, sim_input_max: max}, travel)
       when is_number(min) and is_number(max) and not is_nil(travel),
       do: {fraction(min, travel), fraction(max, travel)}

  defp range_edges(%Notch{}, _travel), do: nil

  defp add_stops(segments) do
    segments
    |> split_adjacent_ranges()
    |> cap_start(0.0)
    |> Enum.reverse()
    |> cap_start(1.0)
    |> Enum.reverse()
  end

  defp cap_start([{:smooth, label, _edges} | _] = segments, anchor),
    do: [{:notch, :standard, label, anchor} | segments]

  defp cap_start(segments, _anchor), do: segments

  defp split_adjacent_ranges([{:smooth, _, a_edges} = a, {:smooth, _, b_edges} = b | rest]) do
    [a, {:notch, :standard, "", between(a_edges, b_edges)} | split_adjacent_ranges([b | rest])]
  end

  defp split_adjacent_ranges([segment | rest]), do: [segment | split_adjacent_ranges(rest)]
  defp split_adjacent_ranges([]), do: []

  defp between({_, a_to}, {b_from, _}), do: (a_to + b_from) / 2
  defp between(_a, _b), do: nil

  defp check_size(segments) do
    case minimum_size(segments) do
      minimum when minimum > @max_positions -> {:error, :too_many_positions}
      minimum when minimum < @min_positions -> {:error, :too_few_positions}
      _minimum -> :ok
    end
  end

  # Every Smooth run keeps at least one position
  defp minimum_size(segments), do: length(segments)

  # A range's floor runs from its first to its last Smooth position, so a run
  # gets two positions when the disk has room, and one otherwise.
  defp min_run(segments) do
    runs = Enum.count(segments, &smooth?/1)
    if length(segments) + runs <= @max_positions, do: 2, else: 1
  end

  defp smooth?({:smooth, _label, _edges}), do: true
  defp smooth?(_segment), do: false

  # The generator spaces positions evenly, so the only freedom is how many
  # Smooth positions each run gets. Tries every position count and split, and
  # keeps the one that puts gates closest to where they sit on the
  # simulator's travel, and each range's floor closest to the range.
  # Returns the Smooth run lengths in order.
  defp layout(segments) do
    runs = Enum.count(segments, &smooth?/1)
    fixed = length(segments) - runs
    min_run = min_run(segments)
    minimum = fixed + runs * min_run

    for count <- minimum..max_count(segments, minimum),
        lengths <- compositions(count - fixed, runs, min_run) do
      {score(segments, count, lengths), lengths}
    end
    |> Enum.min_by(fn {score, _lengths} -> score end)
    |> then(fn {_score, lengths} -> {segments, lengths} end)
  end

  # Deep needs room, so a disk with Deep positions stays within the count
  # where it still fits, unless the lever needs more.
  defp max_count(segments, minimum) do
    if Enum.any?(segments, &match?({:notch, :deep, _, _}, &1)) and minimum <= @max_deep_positions,
      do: @max_deep_positions,
      else: @max_positions
  end

  # Every way to split `total` positions into `parts` runs of at least `min` each
  defp compositions(0, 0, _min), do: [[]]
  defp compositions(_total, 0, _min), do: []

  defp compositions(total, parts, min) do
    for first <- min..(total - (parts - 1) * min)//1,
        rest <- compositions(total - first, parts - 1, min),
        do: [first | rest]
  end

  defp score(segments, count, lengths) do
    placed = place(segments, lengths)
    last = count - 1

    gate_errors =
      for {:notch, _feel, anchor, i} <- placed, is_number(anchor), do: abs(i / last - anchor)

    edge_errors =
      placed
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.flat_map(fn
        [{:notch, _, _, a}, {:run, {from, to}}, {:notch, _, _, b}] ->
          # The floor runs from the first to the last Smooth position. Only a
          # floor shorter than the range counts.
          [max(0.0, (a + 1) / last - from), max(0.0, to - (b - 1) / last)]

        _ ->
          []
      end)

    worst(gate_errors) + @edge_weight * worst(edge_errors) + @position_cost * count
  end

  defp worst([]), do: 0.0
  defp worst(errors), do: Enum.max(errors)

  defp place(segments, lengths) do
    {placed, _i, []} =
      Enum.reduce(segments, {[], 0, lengths}, fn
        {:notch, feel, _label, anchor}, {acc, i, lengths} ->
          {[{:notch, feel, anchor, i} | acc], i + 1, lengths}

        {:smooth, _label, edges}, {acc, i, [length | lengths]} ->
          {[{:run, edges} | acc], i + length, lengths}
      end)

    Enum.reverse(placed)
  end

  defp expand({segments, lengths}) do
    {positions, []} =
      Enum.flat_map_reduce(segments, lengths, fn
        {:notch, feel, label, _anchor}, lengths ->
          {[{feel, label}], lengths}

        {:smooth, _label, _edges}, [length | lengths] ->
          {List.duplicate({:smooth, ""}, length), lengths}
      end)

    positions
  end
end
