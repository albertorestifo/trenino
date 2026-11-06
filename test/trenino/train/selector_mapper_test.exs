defmodule Trenino.Train.SelectorMapperTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.SelectorMapper

  doctest SelectorMapper

  @positions [
    %{index: 0, input_min: 0.0, input_max: 0.3},
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

    test "keeps a gap even with a tiny dead zone" do
      ranges = SelectorMapper.even_split(12, 0.01)

      assert SelectorMapper.validate_layout(ranges) == :ok
    end

    test "rejects a zero dead zone" do
      assert_raise FunctionClauseError, fn -> SelectorMapper.even_split(2, 0.0) end
    end

    test "widens gaps as the dead zone grows" do
      [a, b] = SelectorMapper.even_split(2, 0.5)

      assert a.input_max == 0.37
      assert b.input_min == 0.63
    end
  end

  describe "validate_layout/1" do
    test "accepts separated ranges in any order" do
      assert SelectorMapper.validate_layout(Enum.reverse(@positions)) == :ok
    end

    test "rejects ranges that share a boundary" do
      assert SelectorMapper.validate_layout([
               %{input_min: 0.0, input_max: 0.5},
               %{input_min: 0.5, input_max: 1.0}
             ]) == {:error, :overlap}
    end

    test "rejects overlapping ranges" do
      assert SelectorMapper.validate_layout([
               %{input_min: 0.0, input_max: 0.6},
               %{input_min: 0.4, input_max: 1.0}
             ]) == {:error, :overlap}
    end

    test "accepts a single range and an empty layout" do
      assert SelectorMapper.validate_layout([%{input_min: 0.0, input_max: 1.0}]) == :ok
      assert SelectorMapper.validate_layout([]) == :ok
    end
  end
end
