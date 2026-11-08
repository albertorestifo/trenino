defmodule Trenino.Serial.Protocol.ZeroGauge do
  @moduledoc """
  Re-zeros an X27 gauge (firmware >= 3.3.0).

  Format: [type=0x13][pin:u8]

  The gauge sweeps into its end stop, calls that position 0, then moves back to the latest
  position. Fire-and-forget: the device never replies.
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{pin: integer()}

  defstruct [:pin]

  @impl Message
  def encode(%__MODULE__{pin: pin}) when pin in 0..254, do: {:ok, <<0x13, pin::8-unsigned>>}
  def encode(%__MODULE__{}), do: {:error, :invalid_pin}

  @impl Message
  def decode_body(<<pin::8-unsigned>>), do: {:ok, %__MODULE__{pin: pin}}
  def decode_body(_), do: {:error, :invalid_message}
end
