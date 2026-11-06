defmodule Trenino.Train.SelectorMapperTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.SelectorMapper

  doctest SelectorMapper

  @positions [
    %{index: 0, input_min: +0.0, input_max: 0.3},
    %{index: 1, input_min: 0.37, input_max: 0.63},
    %{index: 2, input_min: 0.7, input_max: 1.0}
  ]

  describe "find_position/2" do
    test "matches a value inside a range" do
      assert %{index: 1} = SelectorMapper.find_position(@positions, 0.5)
    end

    test "matches both ends of a range inclusively" do
      assert %{index: 0} = SelectorMapper.find_position(@positions, 0.0)
      assert %{index: 0} = SelectorMapper.find_position(@positions, 0.3)
      assert %{index: 1} = SelectorMapper.find_position(@positions, 0.37)
      assert %{index: 2} = SelectorMapper.find_position(@positions, 1.0)
    end

    test "returns nil inside a dead zone" do
      assert SelectorMapper.find_position(@positions, 0.31) == nil
      assert SelectorMapper.find_position(@positions, 0.65) == nil
    end

    test "does not depend on list order" do
      assert %{index: 2} = SelectorMapper.find_position(Enum.reverse(@positions), 0.8)
    end

    test "accepts integer values" do
      assert %{index: 0} = SelectorMapper.find_position(@positions, 0)
      assert %{index: 2} = SelectorMapper.find_position(@positions, 1)
    end

    test "returns nil for an empty layout" do
      assert SelectorMapper.find_position([], 0.5) == nil
    end
  end

  describe "even_split/2" do
    for count <- 2..12 do
      test "splits into #{count} non-overlapping positions covering both ends" do
        ranges = SelectorMapper.even_split(unquote(count))

        assert length(ranges) == unquote(count)
        assert Enum.map(ranges, & &1.index) == Enum.to_list(0..(unquote(count) - 1))
        assert hd(ranges).input_min == 0.0
        assert List.last(ranges).input_max == 1.0
        assert SelectorMapper.validate_layout(ranges) == :ok

        for %{input_min: min, input_max: max} <- ranges do
          assert min < max
          assert Float.round(min, 2) == min
          assert Float.round(max, 2) == max
        end
      end
    end

    test "produces valid layouts for every count and allowed dead zone" do
      for count <- 1..12, dead_zone <- [0.05, 0.1, 0.2, 0.3, 0.5] do
        ranges = SelectorMapper.even_split(count, dead_zone)

        assert SelectorMapper.validate_layout(ranges) == :ok,
               "count=#{count} dead_zone=#{dead_zone}: #{inspect(ranges)}"

        for %{input_min: min, input_max: max} <- ranges do
          assert min < max, "count=#{count} dead_zone=#{dead_zone}: #{inspect(ranges)}"
        end

        for [a, b] <- Enum.chunk_every(ranges, 2, 1, :discard) do
          assert Float.round(b.input_min - a.input_max, 2) >= 0.02
        end
      end
    end

    test "keeps the minimum gap with the smallest dead zone" do
      [a, b | _] = SelectorMapper.even_split(12, 0.05)

      assert Float.round(b.input_min - a.input_max, 2) >= 0.02
    end

    test "rejects dead zones outside the allowed range" do
      assert_raise FunctionClauseError, fn -> SelectorMapper.even_split(2, 0.0) end
      assert_raise FunctionClauseError, fn -> SelectorMapper.even_split(2, 0.01) end
      assert_raise FunctionClauseError, fn -> SelectorMapper.even_split(2, 0.9) end
    end

    test "widens gaps as the dead zone grows" do
      [a, b] = SelectorMapper.even_split(2, 0.5)

      assert a.input_max == 0.37
      assert b.input_min == 0.63
    end
  end

  describe "ranges_from_detents/2" do
    test "meets halfway between detents with a dead zone" do
      assert {:ok,
              [
                %{index: 0, input_min: +0.0, input_max: 0.26},
                %{index: 1, input_min: 0.34, input_max: 0.66},
                %{index: 2, input_min: 0.74, input_max: 1.0}
              ]} = SelectorMapper.ranges_from_detents([0.1, 0.5, 0.9])
    end

    test "follows uneven detent spacing" do
      {:ok, [a, b, c]} = SelectorMapper.ranges_from_detents([0.05, 0.2, 0.9])

      # Boundaries sit halfway: 0.125 and 0.55
      assert a.input_max < 0.125 and b.input_min > 0.125
      assert b.input_max < 0.55 and c.input_min > 0.55
    end

    test "works for a pot wired in reverse" do
      assert {:ok, [first, _middle, last]} = SelectorMapper.ranges_from_detents([0.9, 0.5, 0.1])

      assert %{index: 0, input_min: 0.74, input_max: 1.0} = first
      assert %{index: 2, input_min: +0.0, input_max: 0.26} = last
    end

    test "keeps each detent inside its own range" do
      detents = [0.0, 0.07, 0.31, 0.62, 0.69, 1.0]
      {:ok, ranges} = SelectorMapper.ranges_from_detents(detents)

      for {detent, range} <- Enum.zip(detents, ranges) do
        assert detent >= range.input_min and detent <= range.input_max
      end

      assert SelectorMapper.validate_layout(ranges) == :ok
    end

    test "always produces a valid layout for spaced detents" do
      for count <- 2..12, dead_zone <- [0.05, 0.2, 0.5] do
        detents = for i <- 0..(count - 1), do: Float.round(i / (count - 1), 2)
        {:ok, ranges} = SelectorMapper.ranges_from_detents(detents, dead_zone)

        assert SelectorMapper.validate_layout(ranges) == :ok
        assert Enum.all?(ranges, &(&1.input_min <= &1.input_max))
      end
    end

    test "rejects detents closer than 0.06" do
      assert SelectorMapper.ranges_from_detents([0.1, 0.15, 0.9]) == {:error, :too_close}
      assert SelectorMapper.ranges_from_detents([0.5, 0.5]) == {:error, :too_close}
    end
  end

  describe "validate_layout/1" do
    test "accepts separated ranges in any order" do
      assert SelectorMapper.validate_layout(Enum.reverse(@positions)) == :ok
    end

    test "rejects ranges that share a boundary" do
      assert SelectorMapper.validate_layout([
               %{input_min: +0.0, input_max: 0.5},
               %{input_min: 0.5, input_max: 1.0}
             ]) == {:error, :overlap}
    end

    test "requires a gap of at least 0.02" do
      assert SelectorMapper.validate_layout([
               %{input_min: +0.0, input_max: 0.3},
               %{input_min: 0.31, input_max: 1.0}
             ]) == {:error, :overlap}

      assert SelectorMapper.validate_layout([
               %{input_min: +0.0, input_max: 0.3},
               %{input_min: 0.32, input_max: 1.0}
             ]) == :ok
    end

    test "rejects overlapping ranges" do
      assert SelectorMapper.validate_layout([
               %{input_min: +0.0, input_max: 0.6},
               %{input_min: 0.4, input_max: 1.0}
             ]) == {:error, :overlap}
    end

    test "accepts a single range and an empty layout" do
      assert SelectorMapper.validate_layout([%{input_min: +0.0, input_max: 1.0}]) == :ok
      assert SelectorMapper.validate_layout([]) == :ok
    end
  end
end
