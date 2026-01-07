defmodule Trenino.Serial.Protocol.Message do
  @moduledoc """
  A shared protocol for communicating with the device over serial.
  """

  alias Trenino.Serial.Protocol.{
    ConfigurationError,
    ConfigurationStored,
    Configure,
    Heartbeat,
    IdentityRequest,
    IdentityResponse,
    InputValue,
    SetOutput
  }

  @type t() :: struct()

  @doc """
  Encode the message into a binary.
  Returns `{:ok, binary}` if successful, `{:error, reason}` otherwise.
  """
  @callback encode(t()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Decode the message body (without the type byte) into a message of type `t()`.
  Returns `{:ok, message}` if successful, `{:error, reason}` otherwise.
  """
  @callback decode_body(binary()) :: {:ok, t()} | {:error, any()}

  @doc """
  Decode a binary into the corresponding message struct by examining the first byte.

  Returns `{:ok, message}` if successful, `{:error, reason}` otherwise.
  """
  @spec decode(binary()) :: {:ok, struct()} | {:error, any()}
  def decode(<<0x00, rest::binary>>), do: IdentityRequest.decode_body(rest)
  def decode(<<0x01, rest::binary>>), do: IdentityResponse.decode_body(rest)
  def decode(<<0x02, rest::binary>>), do: Configure.decode_body(rest)
  def decode(<<0x03, rest::binary>>), do: ConfigurationStored.decode_body(rest)
  def decode(<<0x04, rest::binary>>), do: ConfigurationError.decode_body(rest)
  def decode(<<0x05, rest::binary>>), do: InputValue.decode_body(rest)
  def decode(<<0x06, rest::binary>>), do: Heartbeat.decode_body(rest)
  def decode(<<0x07, rest::binary>>), do: SetOutput.decode_body(rest)
  def decode(<<_unknown, _rest::binary>>), do: {:error, :unknown_message_type}
  def decode(<<>>), do: {:error, :insufficient_data}
  def decode(_), do: {:error, :invalid_input}
end
