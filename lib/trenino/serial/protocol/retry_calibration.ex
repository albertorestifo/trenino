defmodule Trenino.Serial.Protocol.RetryCalibration do
  @moduledoc """
  RetryCalibration message sent to device to retry calibration after a failure.

  Protocol format: [type=0x08][pin:u8]

  This message instructs the firmware to retry the calibration process for a specific pin.
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          pin: integer()
        }

  defstruct [:pin]

  @impl Message
  def encode(%__MODULE__{pin: pin}) when is_integer(pin) and pin >= 0 and pin <= 255 do
    {:ok, <<0x08, pin::8-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_pin}

  @impl Message
  def decode_body(<<pin::8-unsigned>>) do
    {:ok, %__MODULE__{pin: pin}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
