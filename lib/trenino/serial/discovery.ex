defmodule Trenino.Serial.Discovery do
  @moduledoc """
  Handles device discovery protocol over serial UART connections.

  Sends an identity request to a device and waits up to one second for an
  identity response. Configured firmware starts streaming input values and
  heartbeats as soon as it boots, so any other frame received while waiting
  is skipped without using up an attempt. Only a full second with no
  identity response counts as a failed attempt. Discovery gives up after
  5 such attempts.

  Returns `{:ok, IdentityResponse.t()}` if a device responds with valid
  identity, or `{:error, reason}` if discovery fails.
  """

  alias Circuits.UART
  alias Trenino.Serial.Protocol

  require Logger

  # Delay to let the device settle after port opens.
  # Arduino Mega with stock stk500v2 bootloader can take up to 3 seconds.
  # DTR toggles on open, resetting the board into the bootloader.
  @default_settle_delay_ms 3_000

  @max_attempts 5
  @attempt_timeout_ms 1_000

  @spec discover(pid()) :: {:ok, Protocol.IdentityResponse.t()} | {:error, term()}
  def discover(uart_pid) do
    # Wait for device to settle (Windows serial ports toggle DTR/RTS on open)
    Process.sleep(settle_delay_ms())

    # Flush any garbage data in the receive buffer
    UART.flush(uart_pid, :receive)

    send_and_wait_for_response(uart_pid, 0)
  end

  defp settle_delay_ms do
    Application.get_env(:trenino, :serial_discovery_settle_ms, @default_settle_delay_ms)
  end

  defp send_and_wait_for_response(_uart_pid, @max_attempts), do: {:error, :no_valid_response}

  defp send_and_wait_for_response(uart_pid, attempt) do
    identity_request = %Protocol.IdentityRequest{request_id: :erlang.unique_integer([:positive])}
    Logger.debug("[Discovery] Attempt #{attempt + 1}: Sending identity request")

    deadline = System.monotonic_time(:millisecond) + @attempt_timeout_ms

    with {:ok, encoded_request} <- Protocol.IdentityRequest.encode(identity_request),
         :ok <- UART.write(uart_pid, encoded_request),
         :ok <- UART.drain(uart_pid) do
      case await_identity(uart_pid, attempt, deadline) do
        {:ok, response} ->
          {:ok, response}

        :timeout ->
          Logger.debug("[Discovery] Attempt #{attempt + 1}: no identity response, will retry")
          send_and_wait_for_response(uart_pid, attempt + 1)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Reads frames until an identity response arrives or the attempt's deadline
  # passes. Other frames (input values, heartbeats, bootloader noise) are skipped.
  @spec await_identity(pid(), non_neg_integer(), integer()) ::
          {:ok, Protocol.IdentityResponse.t()} | :timeout | {:error, term()}
  defp await_identity(uart_pid, attempt, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      :timeout
    else
      uart_pid
      |> UART.read(remaining)
      |> handle_read(uart_pid, attempt, deadline)
    end
  end

  defp handle_read({:ok, <<>>}, _uart_pid, _attempt, _deadline), do: :timeout

  defp handle_read({:ok, data}, uart_pid, attempt, deadline) do
    case Protocol.Message.decode(data) do
      {:ok, %Protocol.IdentityResponse{} = response} ->
        Logger.debug("[Discovery] Success: #{inspect(response)}")
        {:ok, response}

      {:ok, other} ->
        Logger.debug(
          "[Discovery] Attempt #{attempt + 1}: skipping #{inspect(other.__struct__)} while waiting for identity"
        )

        await_identity(uart_pid, attempt, deadline)

      {:error, reason} ->
        Logger.debug(
          "[Discovery] Attempt #{attempt + 1}: skipping undecodable frame #{inspect(data, limit: 50)} (#{inspect(reason)})"
        )

        await_identity(uart_pid, attempt, deadline)
    end
  end

  defp handle_read({:error, reason}, _uart_pid, attempt, _deadline) do
    Logger.debug("[Discovery] Attempt #{attempt + 1}: read error: #{inspect(reason)}")
    {:error, reason}
  end
end
