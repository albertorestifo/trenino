defmodule Trenino.Serial.Protocol.SetOutput do
  @moduledoc """
  SetOutput message for controlling digital outputs on the device.

  Protocol v2.0.0 - Format: [type=0x07][pin:u8][value:u8]

  This is a fire-and-forget message (no ACK from device).
  Wire format: 0 = LOW, 1 = HIGH.
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type value :: :low | :high

  @type t() :: %__MODULE__{
          pin: integer(),
          value: value()
        }

  defstruct [:pin, :value]

  @impl Message
  def type(), do: 0x07

  @impl Message
  def encode(%__MODULE__{pin: pin, value: :low}) do
    {:ok, <<0x07, pin::8-unsigned, 0x00>>}
  end

  def encode(%__MODULE__{pin: pin, value: :high}) do
    {:ok, <<0x07, pin::8-unsigned, 0x01>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_value}

  @impl Message
  def decode(<<0x07, pin::8-unsigned, 0x00>>) do
    {:ok, %__MODULE__{pin: pin, value: :low}}
  end

  def decode(<<0x07, pin::8-unsigned, 0x01>>) do
    {:ok, %__MODULE__{pin: pin, value: :high}}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
