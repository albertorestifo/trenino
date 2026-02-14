defmodule Trenino.Serial.Protocol.LoadBLDCProfileTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.LoadBLDCProfile

  describe "encode/1 - basic structure" do
    test "encodes message with single detent and no ranges" do
      detent = %{
        position: 50,
        engagement: 100,
        hold: 150,
        exit: 80,
        spring_back: 200
      }

      message = %LoadBLDCProfile{
        pin: 5,
        detents: [detent],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type (0x0B) + pin (5) + num_detents (1) + num_ranges (0)
      # + detent data: position(50), engagement(100), hold(150), exit(80), spring_back(200)
      assert encoded ==
               <<0x0B, 0x05, 0x01, 0x00, 50, 100, 150, 80, 200>>
    end

    test "encodes message with multiple detents" do
      detent1 = %{
        position: 0,
        engagement: 50,
        hold: 75,
        exit: 40,
        spring_back: 100
      }

      detent2 = %{
        position: 100,
        engagement: 60,
        hold: 85,
        exit: 50,
        spring_back: 120
      }

      message = %LoadBLDCProfile{
        pin: 10,
        detents: [detent1, detent2],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type + pin + num_detents (2) + num_ranges (0) + detent1 data + detent2 data
      assert encoded ==
               <<0x0B, 0x0A, 0x02, 0x00, 0, 50, 75, 40, 100, 100, 60, 85, 50, 120>>
    end

    test "encodes message with single range" do
      detent1 = %{position: 0, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      detent2 = %{position: 50, engagement: 60, hold: 85, exit: 50, spring_back: 120}

      range = %{
        start_detent: 0,
        end_detent: 1,
        damping: 128
      }

      message = %LoadBLDCProfile{
        pin: 7,
        detents: [detent1, detent2],
        ranges: [range]
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type + pin + num_detents (2) + num_ranges (1)
      # + detent1 data + detent2 data
      # + range data: start(0), end(1), damping(128)
      assert encoded ==
               <<0x0B, 0x07, 0x02, 0x01, 0, 50, 75, 40, 100, 50, 60, 85, 50, 120, 0, 1, 128>>
    end

    test "encodes message with multiple ranges" do
      detent1 = %{position: 0, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      detent2 = %{position: 50, engagement: 60, hold: 85, exit: 50, spring_back: 120}
      detent3 = %{position: 100, engagement: 70, hold: 95, exit: 60, spring_back: 140}

      range1 = %{start_detent: 0, end_detent: 1, damping: 100}
      range2 = %{start_detent: 1, end_detent: 2, damping: 150}

      message = %LoadBLDCProfile{
        pin: 3,
        detents: [detent1, detent2, detent3],
        ranges: [range1, range2]
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type + pin + num_detents (3) + num_ranges (2)
      # + 3 detents (5 bytes each = 15 bytes)
      # + 2 ranges (3 bytes each = 6 bytes)
      assert encoded ==
               <<0x0B, 0x03, 0x03, 0x02, 0, 50, 75, 40, 100, 50, 60, 85, 50, 120, 100, 70, 95, 60,
                 140, 0, 1, 100, 1, 2, 150>>
    end

    test "encodes message with no detents and no ranges" do
      message = %LoadBLDCProfile{
        pin: 1,
        detents: [],
        ranges: []
      }

      {:ok, encoded} = LoadBLDCProfile.encode(message)

      # Type + pin + num_detents (0) + num_ranges (0)
      assert encoded == <<0x0B, 0x01, 0x00, 0x00>>
    end
  end

  describe "encode/1 - validation" do
    test "returns error for invalid pin (negative)" do
      message = %LoadBLDCProfile{pin: -1, detents: [], ranges: []}
      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid pin (too large)" do
      message = %LoadBLDCProfile{pin: 256, detents: [], ranges: []}
      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for nil pin" do
      message = %LoadBLDCProfile{pin: nil, detents: [], ranges: []}
      assert {:error, :invalid_pin} = LoadBLDCProfile.encode(message)
    end

    test "returns error for too many detents (> 255)" do
      detents =
        for i <- 0..255, do: %{position: i, engagement: 50, hold: 75, exit: 40, spring_back: 100}

      message = %LoadBLDCProfile{pin: 5, detents: detents, ranges: []}
      assert {:error, :too_many_detents} = LoadBLDCProfile.encode(message)
    end

    test "returns error for too many ranges (> 255)" do
      detents = [%{position: 0, engagement: 50, hold: 75, exit: 40, spring_back: 100}]
      ranges = for i <- 0..255, do: %{start_detent: 0, end_detent: 0, damping: i}
      message = %LoadBLDCProfile{pin: 5, detents: detents, ranges: ranges}
      assert {:error, :too_many_ranges} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent position (negative)" do
      detent = %{position: -1, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: []}
      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent position (> 100)" do
      detent = %{position: 101, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: []}
      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent engagement (negative)" do
      detent = %{position: 50, engagement: -1, hold: 75, exit: 40, spring_back: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: []}
      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid detent engagement (> 255)" do
      detent = %{position: 50, engagement: 256, hold: 75, exit: 40, spring_back: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: []}
      assert {:error, :invalid_detent} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range start_detent (negative)" do
      detent = %{position: 50, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      range = %{start_detent: -1, end_detent: 0, damping: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: [range]}
      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range start_detent (> 255)" do
      detent = %{position: 50, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      range = %{start_detent: 256, end_detent: 0, damping: 100}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: [range]}
      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range damping (negative)" do
      detent = %{position: 50, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      range = %{start_detent: 0, end_detent: 0, damping: -1}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: [range]}
      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end

    test "returns error for invalid range damping (> 255)" do
      detent = %{position: 50, engagement: 50, hold: 75, exit: 40, spring_back: 100}
      range = %{start_detent: 0, end_detent: 0, damping: 256}
      message = %LoadBLDCProfile{pin: 5, detents: [detent], ranges: [range]}
      assert {:error, :invalid_range} = LoadBLDCProfile.encode(message)
    end
  end

  describe "decode_body/1" do
    test "decodes message with single detent and no ranges" do
      body = <<0x05, 0x01, 0x00, 50, 100, 150, 80, 200>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 5
      assert [_] = decoded.detents
      assert decoded.ranges == []

      [detent] = decoded.detents
      assert detent.position == 50
      assert detent.engagement == 100
      assert detent.hold == 150
      assert detent.exit == 80
      assert detent.spring_back == 200
    end

    test "decodes message with multiple detents" do
      body = <<0x0A, 0x02, 0x00, 0, 50, 75, 40, 100, 100, 60, 85, 50, 120>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 10
      assert [_, _] = decoded.detents
      assert decoded.ranges == []

      [detent1, detent2] = decoded.detents
      assert detent1.position == 0
      assert detent1.engagement == 50
      assert detent2.position == 100
      assert detent2.engagement == 60
    end

    test "decodes message with detents and ranges" do
      body = <<0x07, 0x02, 0x01, 0, 50, 75, 40, 100, 50, 60, 85, 50, 120, 0, 1, 128>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 7
      assert length(decoded.detents) == 2
      assert length(decoded.ranges) == 1

      [range] = decoded.ranges
      assert range.start_detent == 0
      assert range.end_detent == 1
      assert range.damping == 128
    end

    test "decodes message with no detents and no ranges" do
      body = <<0x01, 0x00, 0x00>>
      {:ok, decoded} = LoadBLDCProfile.decode_body(body)

      assert decoded.pin == 1
      assert decoded.detents == []
      assert decoded.ranges == []
    end

    test "returns error for incomplete header" do
      assert LoadBLDCProfile.decode_body(<<0x05, 0x01>>) == {:error, :invalid_message}
    end

    test "returns error for incomplete detent data" do
      # Says 1 detent but only provides 4 bytes instead of 5
      body = <<0x05, 0x01, 0x00, 50, 100, 150, 80>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end

    test "returns error for incomplete range data" do
      # Says 1 range but only provides 2 bytes instead of 3
      body = <<0x05, 0x00, 0x01, 0, 1>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end

    test "returns error for extra bytes" do
      body = <<0x05, 0x00, 0x00, 0xFF>>
      assert LoadBLDCProfile.decode_body(body) == {:error, :invalid_message}
    end
  end
end
