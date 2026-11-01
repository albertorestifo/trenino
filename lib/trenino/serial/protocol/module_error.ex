defmodule Trenino.Serial.Protocol.ModuleError do
  @moduledoc "ModuleError (0x0F) — Device → Host. Codes: 0 init failed, 1 communication lost, 2 recovered, 3 supply reference lost."

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{i2c_address: integer(), error_code: integer()}
  defstruct [:i2c_address, :error_code]

  @doc "The meaning of an error code, or `nil` for an unknown code."
  @spec status(integer()) ::
          :init_failed | :communication_lost | :recovered | :reference_lost | nil
  def status(0), do: :init_failed
  def status(1), do: :communication_lost
  def status(2), do: :recovered
  def status(3), do: :reference_lost
  def status(_), do: nil

  @doc "Log wording for an error code."
  @spec describe(integer()) :: String.t()
  def describe(code) do
    case status(code) do
      :init_failed -> "failed init"
      :communication_lost -> "lost communication"
      :recovered -> "recovered"
      :reference_lost -> "lost its supply reference"
      nil -> "reported an unknown error"
    end
  end

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, error_code: code})
      when is_integer(addr) and is_integer(code) do
    {:ok, <<0x0F, addr::8-unsigned, code::8-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_fields}

  @impl Message
  def decode_body(<<addr::8-unsigned, code::8-unsigned>>) do
    {:ok, %__MODULE__{i2c_address: addr, error_code: code}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
