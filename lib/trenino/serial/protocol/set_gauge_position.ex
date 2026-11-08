defmodule Trenino.Serial.Protocol.SetGaugePosition do
  @moduledoc """
  Moves an X27 gauge (firmware >= 3.3.0).

  Format: [type=0x12][pin:u8][position:u16 LE]

  `pin` is the gauge's first configured pin. `position` is in steps from the end stop; the
  firmware clamps it to the gauge's travel. Fire-and-forget: the device never replies and the
  latest position wins.
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{pin: integer(), position: non_neg_integer()}

  defstruct [:pin, :position]

  @impl Message
  def encode(%__MODULE__{pin: pin, position: position})
      when pin in 0..254 and position in 0..0xFFFF do
    {:ok, <<0x12, pin::8-unsigned, position::little-16-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_gauge_position}

  @impl Message
  def decode_body(<<pin::8-unsigned, position::little-16-unsigned>>),
    do: {:ok, %__MODULE__{pin: pin, position: position}}

  def decode_body(_), do: {:error, :invalid_message}
end
