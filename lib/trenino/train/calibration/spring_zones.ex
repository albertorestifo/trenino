defmodule Trenino.Train.Calibration.SpringZones do
  @moduledoc """
  Spring-back notches during notch mapping.

  A spring notch (`springs_back_to` set) is a position the cab lever returns
  from to its target notch. It can't be wiggled like a gate, so it is mapped
  differently:

  1. Resting notches (no `springs_back_to`) are captured first, as usual. A
     target gets a dead zone of `dead_zone/1` on each side that has spring
     notches, so a lever settling slightly off centre still reads as the
     target.
  2. Each spring notch is captured by pushing the lever from its target to
     the notch disk's wall and releasing. The furthest reading on the spring
     side is the wall point.
  3. The spring area runs from the inner edge (the target's dead-zone edge,
     or the wall of the spring notch nearer the target) to the wall point.

  All values are calibrated integers (0..total_travel). Notches are maps with
  at least `:index` and `:springs_back_to` (a notch index); captures are
  `%{min: integer, max: integer}` or nil, in the same list order.
  """

  @type notch :: %{
          required(:index) => non_neg_integer(),
          required(:springs_back_to) => non_neg_integer() | nil,
          optional(atom()) => term()
        }
  @type range :: %{min: integer(), max: integer()} | nil
  @type wall_error ::
          :target_not_mapped | :inner_not_mapped | :inside_dead_zone | :past_next_position

  # Share of the total travel.
  @dead_zone 0.03
  @min_area 0.01

  @doc "True when the notch springs back to another one."
  @spec spring?(notch()) :: boolean()
  def spring?(%{springs_back_to: target}), do: is_integer(target)

  @doc "True when any notch springs back."
  @spec any_spring?([notch()]) :: boolean()
  def any_spring?(notches), do: Enum.any?(notches, &spring?/1)

  @doc "Dead zone added on a target's spring side, in calibrated units."
  @spec dead_zone(integer()) :: non_neg_integer()
  def dead_zone(total_travel), do: round(total_travel * @dead_zone)

  @doc """
  List positions in mapping order: resting notches by index, then spring
  notches from their target outwards. Without spring notches, list order.
  """
  @spec step_order([notch()]) :: [non_neg_integer()]
  def step_order(notches) do
    indexed = Enum.with_index(notches)
    {springs, resting} = Enum.split_with(indexed, fn {n, _} -> spring?(n) end)

    resting_positions =
      resting |> Enum.sort_by(fn {n, _} -> n.index end) |> Enum.map(&elem(&1, 1))

    spring_positions =
      springs
      |> Enum.sort_by(fn {n, _} -> {abs(n.index - n.springs_back_to), n.index} end)
      |> Enum.map(&elem(&1, 1))

    resting_positions ++ spring_positions
  end

  @doc """
  The ranges the lever is mapped with: captures, with targets widened by the
  dead zone and spring notches turned into their areas. A spring notch whose
  area can't be computed yet is nil.
  """
  @spec effective_ranges([notch()], [range()], integer()) :: [range()]
  def effective_ranges(notches, captured, total_travel) do
    if any_spring?(notches) do
      notches
      |> Enum.with_index()
      |> Enum.map(fn {notch, pos} -> effective(notches, captured, total_travel, notch, pos) end)
    else
      captured
    end
  end

  @doc """
  The range a resting notch was captured at before any dead zone: the
  wiggled range. Nil for spring notches and uncaptured notches.
  """
  @spec core_range([notch()], [range()], non_neg_integer()) :: range()
  def core_range(notches, captured, pos) do
    if spring?(Enum.at(notches, pos)), do: nil, else: Enum.at(captured, pos)
  end

  @doc """
  Checks a spring notch capture before it is stored. `capture` spans the
  readings taken while the lever was pushed to the wall and released.
  """
  @spec check_wall([notch()], [range()], integer(), non_neg_integer(), range()) ::
          :ok | {:error, wall_error()}
  def check_wall(notches, captured, total_travel, pos, %{min: _, max: _} = capture) do
    notch = Enum.at(notches, pos)
    target_pos = position_of(notches, notch.springs_back_to)

    cond do
      target_pos == nil or Enum.at(captured, target_pos) == nil ->
        {:error, :target_not_mapped}

      inner_spring(notches, notch) != nil and
          Enum.at(captured, inner_spring(notches, notch)) == nil ->
        {:error, :inner_not_mapped}

      true ->
        trial = List.replace_at(captured, pos, capture)
        dir = side(notches, trial, pos)
        start = inner_edge(notches, trial, total_travel, pos, dir)
        wall = wall_point(capture, dir)
        area = (wall - start) * dir

        cond do
          area < max(1, round(total_travel * @min_area)) ->
            {:error, :inside_dead_zone}

          past_next?(notches, captured, total_travel, pos, dir, wall) ->
            {:error, :past_next_position}

          true ->
            :ok
        end
    end
  end

  # -- effective ranges -------------------------------------------------------

  defp effective(notches, captured, total_travel, notch, pos) do
    cond do
      Enum.at(captured, pos) == nil -> nil
      spring?(notch) -> spring_area(notches, captured, total_travel, pos)
      true -> buffered(notches, captured, total_travel, pos)
    end
  end

  defp spring_area(notches, captured, total_travel, pos) do
    notch = Enum.at(notches, pos)
    target_pos = position_of(notches, notch.springs_back_to)
    inner = inner_spring(notches, notch)

    if target_pos == nil or Enum.at(captured, target_pos) == nil or
         (inner != nil and Enum.at(captured, inner) == nil) do
      nil
    else
      dir = side(notches, captured, pos)
      start = inner_edge(notches, captured, total_travel, pos, dir)
      wall = wall_point(Enum.at(captured, pos), dir)
      %{min: min(start, wall), max: max(start, wall)}
    end
  end

  # A resting notch widened by the dead zone on each side with spring notches,
  # never into another resting capture.
  defp buffered(notches, captured, total_travel, pos) do
    %{min: lo, max: hi} = range = Enum.at(captured, pos)
    sides = spring_sides(notches, captured, pos)
    dz = dead_zone(total_travel)

    if sides == [] do
      range
    else
      {floor, ceiling} = neighbour_limits(notches, captured, pos, total_travel)
      lo = if -1 in sides, do: max(floor, lo - dz), else: lo
      hi = if 1 in sides, do: min(ceiling, hi + dz), else: hi
      %{min: lo, max: hi}
    end
  end

  # The hardware directions (-1/1) of the spring notches returning to `pos`.
  defp spring_sides(notches, captured, pos) do
    index = Enum.at(notches, pos).index

    notches
    |> Enum.with_index()
    |> Enum.filter(fn {n, _} -> n.springs_back_to == index end)
    |> Enum.map(fn {_, spos} -> side(notches, captured, spos) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  # Nearest edges of other resting captures below and above `pos`.
  defp neighbour_limits(notches, captured, pos, total_travel) do
    %{min: lo, max: hi} = Enum.at(captured, pos)

    others =
      for {n, p} <- Enum.with_index(notches),
          p != pos,
          not spring?(n),
          r = Enum.at(captured, p),
          r != nil,
          do: r

    floor = others |> Enum.map(& &1.max) |> Enum.filter(&(&1 <= lo)) |> Enum.max(fn -> 0 end)

    ceiling =
      others |> Enum.map(& &1.min) |> Enum.filter(&(&1 >= hi)) |> Enum.min(fn -> total_travel end)

    {floor, ceiling}
  end

  # -- geometry --------------------------------------------------------------

  # Hardware direction (-1 or 1) from the target to the spring notch at `pos`.
  # Taken from another captured resting notch when there is one (its index tells
  # which way the lever runs), else from the spring capture itself; nil when
  # neither is known.
  defp side(notches, captured, pos) do
    notch = Enum.at(notches, pos)
    target_pos = position_of(notches, notch.springs_back_to)
    target = target_pos && Enum.at(captured, target_pos)
    index_dir = sign(notch.index - notch.springs_back_to)

    cond do
      target == nil ->
        nil

      reference = reference_notch(notches, captured, target_pos) ->
        {ref_notch, ref_range} = reference
        hw = sign(mid(ref_range) - mid(target)) * sign(ref_notch.index - notch.springs_back_to)
        if hw == 0, do: from_capture(Enum.at(captured, pos), target), else: hw * index_dir

      true ->
        from_capture(Enum.at(captured, pos), target)
    end
  end

  defp reference_notch(notches, captured, target_pos) do
    notches
    |> Enum.with_index()
    |> Enum.find_value(fn {n, p} ->
      r = Enum.at(captured, p)
      if p != target_pos and not spring?(n) and r != nil, do: {n, r}
    end)
  end

  defp from_capture(nil, _target), do: nil

  defp from_capture(%{min: lo, max: hi}, %{min: tlo, max: thi}),
    do: if(hi - thi >= tlo - lo, do: 1, else: -1)

  defp wall_point(%{max: hi}, 1), do: hi
  defp wall_point(%{min: lo}, -1), do: lo

  # Where the spring notch's area starts: the wall of the spring notch nearer
  # the target, or the target's dead-zone edge.
  defp inner_edge(notches, captured, total_travel, pos, dir) do
    notch = Enum.at(notches, pos)

    case inner_spring(notches, notch) do
      nil ->
        target_pos = position_of(notches, notch.springs_back_to)
        target = buffered(notches, captured, total_travel, target_pos)
        if dir == 1, do: target.max, else: target.min

      inner ->
        wall_point(Enum.at(captured, inner), dir)
    end
  end

  # The spring notch one step nearer the same target, if any.
  defp inner_spring(notches, %{index: index, springs_back_to: target}) do
    inner_index = index - sign(index - target)

    if inner_index != target,
      do: Enum.find_index(notches, &(&1.index == inner_index and &1.springs_back_to == target))
  end

  # True when the wall reaches into a range that isn't part of this spring
  # notch's own chain (its target, or spring notches returning to that target).
  defp past_next?(notches, captured, total_travel, pos, dir, wall) do
    target = Enum.at(notches, pos).springs_back_to
    target_mid = mid(Enum.at(captured, position_of(notches, target)))
    ranges = effective_ranges(notches, captured, total_travel)

    notches
    |> Enum.zip(ranges)
    |> Enum.with_index()
    |> Enum.any?(fn {{n, r}, p} ->
      r != nil and p != pos and n.index != target and n.springs_back_to != target and
        dir * (mid(r) - target_mid) > 0 and dir * (wall - near_edge(r, dir)) > 0
    end)
  end

  defp near_edge(%{min: lo}, 1), do: lo
  defp near_edge(%{max: hi}, -1), do: hi

  defp position_of(notches, index), do: Enum.find_index(notches, &(&1.index == index))

  defp mid(%{min: lo, max: hi}), do: (lo + hi) / 2

  defp sign(x) when x > 0, do: 1
  defp sign(x) when x < 0, do: -1
  defp sign(_), do: 0
end
