defmodule Trenino.Train.Calibration.SpringZonesTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.Calibration.SpringZones

  # Traxx traction: 0 and 2 spring back to 1, 4 and 6 to 5.
  @traxx Enum.map([1, nil, 1, nil, 5, nil, 5, nil], &%{springs_back_to: &1})
         |> Enum.with_index(fn n, i -> Map.put(n, :index, i) end)
  @travel 800
  # Resting positions wiggled at 100, 300, 500 and 700 (±5).
  @resting [
    nil,
    %{min: 95, max: 105},
    nil,
    %{min: 295, max: 305},
    nil,
    %{min: 495, max: 505},
    nil,
    %{min: 695, max: 705}
  ]

  defp put(ranges, pos, range), do: List.replace_at(ranges, pos, range)

  test "resting notches come first, then spring notches from their target outwards" do
    assert SpringZones.step_order(@traxx) == [1, 3, 5, 7, 0, 2, 4, 6]

    two_on_flank =
      Enum.with_index([nil, nil, 4, 4, nil], fn t, i -> %{index: i, springs_back_to: t} end)

    assert SpringZones.step_order(two_on_flank) == [0, 1, 4, 3, 2]
  end

  test "a lever without spring notches keeps its order and its captures" do
    plain = Enum.map(0..2, &%{index: &1, springs_back_to: nil})
    ranges = [%{min: 0, max: 10}, %{min: 40, max: 60}, %{min: 90, max: 100}]
    assert SpringZones.step_order(plain) == [0, 1, 2]
    assert SpringZones.effective_ranges(plain, ranges, 100) == ranges
  end

  test "a target gets the 3% dead zone only on its spring sides" do
    assert SpringZones.dead_zone(@travel) == 24
    ranges = SpringZones.effective_ranges(@traxx, @resting, @travel)
    # 1 has spring notches on both sides; 3 and 7 have none.
    assert Enum.at(ranges, 1) == %{min: 71, max: 129}
    assert Enum.at(ranges, 3) == %{min: 295, max: 305}
    assert Enum.at(ranges, 7) == %{min: 695, max: 705}
    # Spring notches stay unmapped until captured.
    assert Enum.at(ranges, 2) == nil
  end

  test "a spring area runs from the dead-zone edge to the wall point" do
    # Pushed from 1 up to the wall at 200 and released back to 1.
    captured = put(@resting, 2, %{min: 98, max: 200})
    assert SpringZones.check_wall(@traxx, @resting, @travel, 2, %{min: 98, max: 200}) == :ok

    assert Enum.at(SpringZones.effective_ranges(@traxx, captured, @travel), 2) == %{
             min: 129,
             max: 200
           }

    # 0 lies below 1, towards the stop.
    captured = put(captured, 0, %{min: 30, max: 101})

    assert Enum.at(SpringZones.effective_ranges(@traxx, captured, @travel), 0) == %{
             min: 30,
             max: 71
           }
  end

  test "a wall point inside the dead zone or past the next position is refused" do
    assert SpringZones.check_wall(@traxx, @resting, @travel, 2, %{min: 99, max: 133}) ==
             {:error, :inside_dead_zone}

    assert SpringZones.check_wall(@traxx, @resting, @travel, 2, %{min: 99, max: 320}) ==
             {:error, :past_next_position}

    # Past the next position entirely.
    assert SpringZones.check_wall(@traxx, @resting, @travel, 2, %{min: 99, max: 450}) ==
             {:error, :past_next_position}
  end

  test "a spring notch can't be captured before its target or its inner neighbour" do
    assert SpringZones.check_wall(@traxx, put(@resting, 1, nil), @travel, 2, %{min: 99, max: 200}) ==
             {:error, :target_not_mapped}

    two_on_flank =
      Enum.with_index([nil, nil, 4, 4, nil], fn t, i -> %{index: i, springs_back_to: t} end)

    ranges = [%{min: 0, max: 10}, %{min: 100, max: 110}, nil, nil, %{min: 700, max: 710}]

    assert SpringZones.check_wall(two_on_flank, ranges, 1000, 2, %{min: 300, max: 705}) ==
             {:error, :inner_not_mapped}

    # Inner 3 walls at 550; outer 2 starts there.
    ranges = put(ranges, 3, %{min: 550, max: 705})
    assert SpringZones.check_wall(two_on_flank, ranges, 1000, 2, %{min: 400, max: 705}) == :ok
    ranges = put(ranges, 2, %{min: 400, max: 705})
    effective = SpringZones.effective_ranges(two_on_flank, ranges, 1000)
    assert Enum.at(effective, 3) == %{min: 550, max: 670}
    assert Enum.at(effective, 2) == %{min: 400, max: 550}
  end

  test "re-capturing a target moves its spring areas with it" do
    captured = @resting |> put(2, %{min: 98, max: 200}) |> put(1, %{min: 85, max: 95})
    ranges = SpringZones.effective_ranges(@traxx, captured, @travel)
    assert Enum.at(ranges, 1) == %{min: 61, max: 119}
    assert Enum.at(ranges, 2) == %{min: 119, max: 200}
  end

  test "with no other resting capture the wall side comes from the capture" do
    lone = [%{index: 0, springs_back_to: nil}, %{index: 1, springs_back_to: 0}]
    ranges = [%{min: 400, max: 410}, %{min: 300, max: 405}]

    assert SpringZones.effective_ranges(lone, ranges, 800) == [
             %{min: 376, max: 410},
             %{min: 300, max: 376}
           ]
  end
end
