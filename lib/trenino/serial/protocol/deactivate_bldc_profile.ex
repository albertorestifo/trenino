defmodule Trenino.Serial.Protocol.DeactivateBLDCProfile do
  @moduledoc """
  DeactivateBLDCProfile message sent to device to put a BLDC motor in freewheel mode.

  Protocol format: [type=0x0C][pin:u8]

  This message instructs the firmware to deactivate the current haptic profile
  and put the motor in freewheel (no resistance) mode.
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          pin: integer()
        }

  defstruct [:pin]

  @impl Message
  def encode(%__MODULE__{pin: pin}) when is_integer(pin) and pin >= 0 and pin <= 255 do
    {:ok, <<0x0C, pin::8-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_pin}

  @impl Message
  def decode_body(<<pin::8-unsigned>>) do
    {:ok, %__MODULE__{pin: pin}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
