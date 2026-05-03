defmodule Trenino.Hardware.HT16K33Test do
  use ExUnit.Case, async: true
  import Bitwise

  alias Trenino.Hardware.HT16K33
  alias Trenino.Hardware.HT16K33.Params

  defp params_14seg(num_digits \\ 4),
    do: %Params{
      display_type: :fourteen_segment,
      has_dot: false,
      num_digits: num_digits,
      brightness: 8,
      align_right: false,
      min_value: 0.0
    }

  defp params_7seg(num_digits \\ 4, has_dot \\ false),
    do: %Params{
      display_type: :seven_segment,
      has_dot: has_dot,
      num_digits: num_digits,
      brightness: 8,
      align_right: false,
      min_value: 0.0
    }

  describe "encode_string/2 – 14-segment" do
    test "digit 1 encodes correctly (no extra segment)" do
      <<low, high, _rest::binary>> = HT16K33.encode_string("1", params_14seg())
      assert low == 0x06
      assert high == 0x00
    end

    test "digit 3 encodes correctly (has middle bar)" do
      <<low, high, _rest::binary>> = HT16K33.encode_string("3", params_14seg())
      assert low == 0xCF
      assert high == 0x00
    end

    test "returns exactly num_digits * 2 bytes" do
      assert byte_size(HT16K33.encode_string("12", params_14seg(4))) == 8
      assert byte_size(HT16K33.encode_string("12345678", params_14seg(8))) == 16
    end

    test "pads short string with blanks" do
      result = HT16K33.encode_string("1", params_14seg(4))
      assert byte_size(result) == 8
      <<_char::binary-2, rest::binary>> = result
      assert rest == :binary.copy(<<0, 0>>, 3)
    end

    test "truncates string longer than num_digits" do
      result = HT16K33.encode_string("12345", params_14seg(4))
      assert byte_size(result) == 8
    end

    test "unknown character renders as blank" do
      <<low, high, _rest::binary>> = HT16K33.encode_string("~", params_14seg())
      assert low == 0x00
      assert high == 0x00
    end

    test "right-aligns short string when align_right is true" do
      params = %Params{
        display_type: :fourteen_segment,
        has_dot: false,
        num_digits: 4,
        brightness: 8,
        align_right: true,
        min_value: 0.0
      }
      result = HT16K33.encode_string("4", params)
      # First 3 pairs should be blank (spaces), last pair is "4"
      assert byte_size(result) == 8
      <<b0, b1, b2, b3, b4, b5, b6, b7>> = result
      assert {b0, b1} == {0x00, 0x00}
      assert {b2, b3} == {0x00, 0x00}
      assert {b4, b5} == {0x00, 0x00}
      assert {b6, b7} == {0xE6, 0x00}
    end

    test "left-aligns short string when align_right is false" do
      params = %Params{
        display_type: :fourteen_segment,
        has_dot: false,
        num_digits: 4,
        brightness: 8,
        align_right: false,
        min_value: 0.0
      }
      result = HT16K33.encode_string("4", params)
      <<b0, b1, _rest::binary>> = result
      assert {b0, b1} == {0xE6, 0x00}
    end
  end

  describe "encode_string/2 – 7-segment" do
    test "digit 1 encodes to 0x06" do
      <<byte, _rest::binary>> = HT16K33.encode_string("1", params_7seg())
      assert byte == 0x06
    end

    test "digit 3 encodes to 0x4F" do
      <<byte, _rest::binary>> = HT16K33.encode_string("3", params_7seg())
      assert byte == 0x4F
    end

    test "returns exactly num_digits bytes" do
      assert byte_size(HT16K33.encode_string("12", params_7seg(4))) == 4
      assert byte_size(HT16K33.encode_string("12345678", params_7seg(8))) == 8
    end

    test "dot merges into preceding digit when has_dot is true" do
      result = HT16K33.encode_string("1.2", params_7seg(4, true))
      assert byte_size(result) == 4
      <<b0, b1, _rest::binary>> = result
      assert b0 == (0x06 ||| 0x80)
      assert b1 == 0x5B
    end

    test "dot is skipped when has_dot is false" do
      result = HT16K33.encode_string("1.2", params_7seg(4, false))
      <<b0, b1, _rest::binary>> = result
      assert b0 == 0x06
      assert b1 == 0x5B
    end

    test "leading dot with has_dot true is blank with DP bit or plain blank" do
      result = HT16K33.encode_string(".1", params_7seg(4, true))
      <<b0, _rest::binary>> = result
      assert b0 in [0x00, 0x80]
    end

    test "right-aligns short string when align_right is true" do
      params = %Params{
        display_type: :seven_segment,
        has_dot: false,
        num_digits: 4,
        brightness: 8,
        align_right: true,
        min_value: 0.0
      }
      result = HT16K33.encode_string("4", params)
      assert byte_size(result) == 4
      <<b0, b1, b2, b3>> = result
      assert b0 == 0x00
      assert b1 == 0x00
      assert b2 == 0x00
      assert b3 == 0x66
    end

    test "right-aligns correctly when has_dot is true and text contains a dot" do
      params = %Params{
        display_type: :seven_segment,
        has_dot: true,
        num_digits: 4,
        brightness: 8,
        align_right: true,
        min_value: 0.0
      }
      # "1.2" occupies 2 display slots, so 2 leading spaces expected → " ", " ", "1.", "2"
      result = HT16K33.encode_string("1.2", params)
      assert byte_size(result) == 4
      <<b0, b1, b2, b3>> = result
      assert b0 == 0x00
      assert b1 == 0x00
      assert b2 == (0x06 ||| 0x80)
      assert b3 == 0x5B
    end
  end

  describe "Params changeset" do
    test "valid 14-segment params" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false
        })

      assert cs.valid?
    end

    test "valid 7-segment params" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: 8,
          num_digits: 4,
          display_type: :seven_segment,
          has_dot: true
        })

      assert cs.valid?
    end

    test "rejects brightness below 0" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: -1,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false
        })

      assert errors_on(cs).brightness != []
    end

    test "rejects brightness above 15" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: 16,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false
        })

      assert errors_on(cs).brightness != []
    end

    test "rejects num_digits not in [4, 8]" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: 8,
          num_digits: 6,
          display_type: :fourteen_segment,
          has_dot: false
        })

      assert errors_on(cs).num_digits != []
    end

    test "rejects invalid display_type" do
      cs =
        Params.changeset(%Params{}, %{
          brightness: 8,
          num_digits: 4,
          display_type: :unknown,
          has_dot: false
        })

      assert errors_on(cs).display_type != []
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
