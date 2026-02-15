defmodule Trenino.Serial.Protocol.LoadBLDCProfileTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.LoadBLDCProfile

  describe "encode/1 - basic structure" do
    test "encodes message with single detent and no ranges" do
      detent = %{position: 50, detent_strength: 150}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type (0x0B) + pin (5) + num_detents (1) + num_ranges (0) + snap_point (70) + endstop_strength (200)
      # + detent data: position(50), detent_strength(150)
      assert encoded ==
               <<0x0B, 0x05, 0x01, 0x00, 70, 200, 50, 150>>
    end

    test "encodes message with multiple detents" do
      detent1 = %{position: 0, detent_strength: 75}
      detent2 = %{position: 100, detent_strength: 85}

      message = %LoadBLDCProfile{
        pin: 10,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent1, detent2],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Header (6 bytes) + detent1 (2 bytes) + detent2 (2 bytes)
      assert encoded ==
               <<0x0B, 0x0A, 0x02, 0x00, 70, 200, 0, 75, 100, 85>>
    end

    test "encodes message with single range" do
      detent1 = %{position: 0, detent_strength: 75}
      detent2 = %{position: 50, detent_strength: 85}
      range = %{start_detent: 0, end_detent: 1, damping: 128}

      message = %LoadBLDCProfile{
        pin: 7,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent1, detent2],
        ranges: [range]
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Header (6 bytes) + detent1 (2) + detent2 (2) + range (3)
      assert encoded ==
               <<0x0B, 0x07, 0x02, 0x01, 70, 200, 0, 75, 50, 85, 0, 1, 128>>
    end

    test "encodes message with multiple ranges" do
      detent1 = %{position: 0, detent_strength: 75}
      detent2 = %{position: 50, detent_strength: 85}
      detent3 = %{position: 100, detent_strength: 95}

      range1 = %{start_detent: 0, end_detent: 1, damping: 100}
      range2 = %{start_detent: 1, end_detent: 2, damping: 150}

      message = %LoadBLDCProfile{
        pin: 3,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent1, detent2, detent3],
        ranges: [range1, range2]
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Header (6 bytes) + 3 detents (2 bytes each = 6 bytes) + 2 ranges (3 bytes each = 6 bytes)
      assert encoded ==
               <<0x0B, 0x03, 0x03, 0x02, 70, 200, 0, 75, 50, 85, 100, 95, 0, 1, 100, 1, 2, 150>>
    end

    test "encodes message with no detents and no ranges" do
      message = %LoadBLDCProfile{
        pin: 1,
        snap_point: 70,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Header only (6 bytes)
      assert encoded == <<0x0B, 0x01, 0x00, 0x00, 70, 200>>
    end
  end

  describe "encode/1 - validation" do
    test "returns error for invalid pin (negative)" do
      message = %LoadBLDCProfile{
        pin: -1,
        snap_point: 70,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid pin (too large)" do
      message = %LoadBLDCProfile{
        pin: 256,
        snap_point: 70,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for nil pin" do
      message = %LoadBLDCProfile{
        pin: nil,
        snap_point: 70,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid snap_point (too low)" do
      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 49,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_profile_params} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid snap_point (too high)" do
      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 151,
        endstop_strength: 200,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_profile_params} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid endstop_strength (negative)" do
      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: -1,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_profile_params} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid endstop_strength (too large)" do
      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 256,
        detents: [],
        ranges: []
      }

      assert {:error, :invalid_profile_params} = LoadBLDCProfile.encode(message)
    end

    test "returns error for too many detents (> 255)" do
      detents = for i <- 0..255, do: %{position: rem(i, 101), detent_strength: 50}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: detents,
        ranges: []
      }

      assert {:error, :too_many_detents} = LoadBLDCProfile.encode(message)
    end

    test "returns error for too many ranges (> 255)" do
      detents = [%{position: 0, detent_strength: 50}]
      ranges = for i <- 0..255, do: %{start_detent: 0, end_detent: 0, damping: rem(i, 256)}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: detents,
        ranges: ranges
      }

      assert {:error, :too_many_ranges} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent position (negative)" do
      detent = %{position: -1, detent_strength: 50}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: []
      }

      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent position (> 100)" do
      detent = %{position: 101, detent_strength: 50}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: []
      }

      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent_strength (negative)" do
      detent = %{position: 50, detent_strength: -1}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: []
      }

      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent_strength (> 255)" do
      detent = %{position: 50, detent_strength: 256}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: []
      }

      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range start_detent (negative)" do
      detent = %{position: 50, detent_strength: 50}
      range = %{start_detent: -1, end_detent: 0, damping: 100}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: [range]
      }

      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range start_detent (> 255)" do
      detent = %{position: 50, detent_strength: 50}
      range = %{start_detent: 256, end_detent: 0, damping: 100}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: [range]
      }

      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range damping (negative)" do
      detent = %{position: 50, detent_strength: 50}
      range = %{start_detent: 0, end_detent: 0, damping: -1}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: [range]
      }

      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range damping (> 255)" do
      detent = %{position: 50, detent_strength: 50}
      range = %{start_detent: 0, end_detent: 0, damping: 256}

      message = %LoadBLDCProfile{
        pin: 5,
        snap_point: 70,
        endstop_strength: 200,
        detents: [detent],
        ranges: [range]
      }

      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end
  end

  describe "decode_body/1" do
    test "decodes message with single detent and no ranges" do
      # pin(5) + num_detents(1) + num_ranges(0) + snap_point(70) + endstop_strength(200)
      # + detent: position(50), detent_strength(150)
      body = <<0x05, 0x01, 0x00, 70, 200, 50, 150>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 5
      assert decoded.snap_point == 70
      assert decoded.endstop_strength == 200
      assert [_] = decoded.detents
      assert decoded.ranges == []

      [detent] = decoded.detents
      assert detent.position == 50
      assert detent.detent_strength == 150
    end

    test "decodes message with multiple detents" do
      body = <<0x0A, 0x02, 0x00, 70, 200, 0, 75, 100, 85>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 10
      assert decoded.snap_point == 70
      assert decoded.endstop_strength == 200
      assert [_, _] = decoded.detents
      assert decoded.ranges == []

      [detent1, detent2] = decoded.detents
      assert detent1.position == 0
      assert detent1.detent_strength == 75
      assert detent2.position == 100
      assert detent2.detent_strength == 85
    end

    test "decodes message with detents and ranges" do
      body = <<0x07, 0x02, 0x01, 70, 200, 0, 75, 50, 85, 0, 1, 128>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 7
      assert decoded.snap_point == 70
      assert decoded.endstop_strength == 200
      assert length(decoded.detents) == 2
      assert length(decoded.ranges) == 1

      [range] = decoded.ranges
      assert range.start_detent == 0
      assert range.end_detent == 1
      assert range.damping == 128
    end

    test "decodes message with no detents and no ranges" do
      # pin(1) + num_detents(0) + num_ranges(0) + snap_point(70) + endstop_strength(200)
      body = <<0x01, 0x00, 0x00, 70, 200>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 1
      assert decoded.snap_point == 70
      assert decoded.endstop_strength == 200
      assert decoded.detents == []
      assert decoded.ranges == []
    end

    test "returns error for incomplete header" do
      assert LoadBLDCProfile.decode_body(<<0x05, 0x01>>) == {:error, :invalid_message}
    end

    test "returns error for incomplete detent data" do
      # Says 1 detent but only provides 1 byte instead of 2
      body = <<0x05, 0x01, 0x00, 70, 200, 50>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end

    test "returns error for incomplete range data" do
      # Says 1 range but only provides 2 bytes instead of 3
      body = <<0x05, 0x00, 0x01, 70, 200, 0, 1>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end

    test "returns error for extra bytes" do
      body = <<0x05, 0x00, 0x00, 70, 200, 0xFF>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end
  end
end
