defmodule Trenino.Serial.Discovery do
  @moduledoc """
  Handles device discovery protocol over serial UART connections.

  Sends an identity request to a device and waits for a response.
  Retries up to 3 times if unexpected messages are received.

  Returns `{:ok, Device.t()}` if a device responds with valid identity,
  or `{:error, reason}` if discovery fails.
  """

  alias Circuits.UART
  alias Trenino.Serial.Protocol

  require Logger

  # Delay to let the device settle after port opens (Windows needs this)
  # Device may send startup messages before being ready for identity requests
  @settle_delay_ms 200

  @spec discover(pid()) :: {:ok, Protocol.IdentityResponse.t()} | {:error, term()}
  def discover(uart_pid) do
    # Wait for device to settle (Windows serial ports toggle DTR/RTS on open)
    Process.sleep(@settle_delay_ms)

    # Flush any garbage data in the receive buffer
    UART.flush(uart_pid, :receive)

    send_and_wait_for_response(uart_pid, 0)
  end

  defp send_and_wait_for_response(_uart_pid, 5), do: {:error, :no_valid_response}

  defp send_and_wait_for_response(uart_pid, attempt) do
    identity_request = %Protocol.IdentityRequest{request_id: :erlang.unique_integer([:positive])}
    Logger.debug("[Discovery] Attempt #{attempt + 1}: Sending identity request")

    with {:ok, encoded_request} <- Protocol.IdentityRequest.encode(identity_request),
         :ok <- UART.write(uart_pid, encoded_request),
         :ok <- UART.drain(uart_pid) do
      read_response(uart_pid, attempt)
    end
  end

  @spec read_response(pid(), non_neg_integer()) ::
          {:ok, Protocol.IdentityResponse.t()} | {:error, term()}
  defp read_response(uart_pid, attempt) do
    case UART.read(uart_pid, 1_000) do
      {:ok, <<>>} ->
        Logger.debug("[Discovery] Attempt #{attempt + 1}: timeout (no data), will retry")
        send_and_wait_for_response(uart_pid, attempt + 1)

      {:ok, data} ->
        Logger.debug(
          "[Discovery] Attempt #{attempt + 1}: received #{byte_size(data)} bytes: #{inspect(data, limit: 50)}"
        )

        case Protocol.Message.decode(data) do
          {:ok, %Protocol.IdentityResponse{} = response} ->
            Logger.debug("[Discovery] Success: #{inspect(response)}")
            {:ok, response}

          {:ok, other} ->
            Logger.debug("[Discovery] Got unexpected message: #{inspect(other)}, will retry")
            send_and_wait_for_response(uart_pid, attempt + 1)

          {:error, reason} ->
            Logger.debug("[Discovery] Decode failed: #{inspect(reason)}, will retry")
            send_and_wait_for_response(uart_pid, attempt + 1)
        end

      {:error, reason} ->
        Logger.debug("[Discovery] Read error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
