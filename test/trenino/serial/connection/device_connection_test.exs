defmodule Trenino.Serial.Connection.DeviceConnectionTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.SerialTestHelpers

  describe "new/2" do
    test "creates a connection in :connecting state with port and pid" do
      # Arrange
      port = "/dev/tty.test"
      pid = self()

      # Act
      conn = DeviceConnection.new(port, pid)

      # Assert
      assert %DeviceConnection{} = conn
      assert conn.port == port
      assert conn.status == :connecting
      assert conn.pid == pid
      assert conn.device_config_id == nil
      assert conn.device_version == nil
      assert conn.failed_at == nil
    end
  end

  describe "mark_discovering/1" do
    test "transitions from :connecting to :discovering" do
      # Arrange
      conn = SerialTestHelpers.build_connecting_connection()

      # Act
      updated_conn = DeviceConnection.mark_discovering(conn)

      # Assert
      assert updated_conn.status == :discovering
      assert updated_conn.port == conn.port
      assert updated_conn.pid == conn.pid
    end

    test "raises FunctionClauseError when not in :connecting state" do
      # Arrange
      conn = SerialTestHelpers.build_discovering_connection()

      # Act & Assert
      assert_raise FunctionClauseError, fn ->
        DeviceConnection.mark_discovering(conn)
      end
    end
  end

  describe "mark_connected/2" do
    test "transitions from :discovering to :connected with identity response" do
      # Arrange
      conn = SerialTestHelpers.build_discovering_connection()

      identity_response =
        SerialTestHelpers.build_identity_response(version: "2.0.0", config_id: 42)

      # Act
      updated_conn = DeviceConnection.mark_connected(conn, identity_response)

      # Assert
      assert updated_conn.status == :connected
      assert updated_conn.device_version == "2.0.0"
      assert updated_conn.device_config_id == 42
    end

    test "raises FunctionClauseError when not in :discovering state" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()
      identity_response = SerialTestHelpers.build_identity_response()

      # Act & Assert
      assert_raise FunctionClauseError, fn ->
        DeviceConnection.mark_connected(conn, identity_response)
      end
    end
  end

  describe "mark_disconnecting/1" do
    test "transitions from :connecting to :disconnecting" do
      # Arrange
      conn = SerialTestHelpers.build_connecting_connection()

      # Act
      updated_conn = DeviceConnection.mark_disconnecting(conn)

      # Assert
      assert updated_conn.status == :disconnecting
    end

    test "transitions from :discovering to :disconnecting" do
      # Arrange
      conn = SerialTestHelpers.build_discovering_connection()

      # Act
      updated_conn = DeviceConnection.mark_disconnecting(conn)

      # Assert
      assert updated_conn.status == :disconnecting
    end

    test "transitions from :connected to :disconnecting" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act
      updated_conn = DeviceConnection.mark_disconnecting(conn)

      # Assert
      assert updated_conn.status == :disconnecting
    end

    test "is idempotent when already :disconnecting" do
      # Arrange
      conn = SerialTestHelpers.build_disconnecting_connection()
      original_conn = conn

      # Act
      updated_conn = DeviceConnection.mark_disconnecting(conn)

      # Assert
      assert updated_conn == original_conn
      assert updated_conn.status == :disconnecting
    end

    test "is idempotent when already :failed" do
      # Arrange
      conn = SerialTestHelpers.build_failed_connection()
      original_failed_at = conn.failed_at

      # Act
      updated_conn = DeviceConnection.mark_disconnecting(conn)

      # Assert
      assert updated_conn == conn
      assert updated_conn.status == :failed
      assert updated_conn.failed_at == original_failed_at
    end
  end

  describe "mark_failed/1" do
    test "transitions from :disconnecting to :failed with timestamp" do
      # Arrange
      conn = SerialTestHelpers.build_disconnecting_connection()
      before_time = System.monotonic_time(:millisecond)

      # Act
      updated_conn = DeviceConnection.mark_failed(conn)
      after_time = System.monotonic_time(:millisecond)

      # Assert
      assert updated_conn.status == :failed
      assert updated_conn.pid == nil
      assert updated_conn.failed_at != nil
      assert updated_conn.failed_at >= before_time
      assert updated_conn.failed_at <= after_time
    end

    test "is idempotent when already :failed - preserves original timestamp" do
      # Arrange
      original_timestamp = System.monotonic_time(:millisecond) - 5000
      conn = SerialTestHelpers.build_failed_connection(failed_at: original_timestamp)

      # Act
      updated_conn = DeviceConnection.mark_failed(conn)

      # Assert
      assert updated_conn == conn
      assert updated_conn.status == :failed
      assert updated_conn.failed_at == original_timestamp
    end

    test "raises FunctionClauseError when not in :disconnecting or :failed state" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act & Assert
      assert_raise FunctionClauseError, fn ->
        DeviceConnection.mark_failed(conn)
      end
    end
  end

  describe "should_retry?/2" do
    test "returns true when failed and backoff period has elapsed" do
      # Arrange
      backoff_ms = 1000
      failed_at = System.monotonic_time(:millisecond) - (backoff_ms + 100)
      conn = SerialTestHelpers.build_failed_connection(failed_at: failed_at)

      # Act
      result = DeviceConnection.should_retry?(conn, backoff_ms)

      # Assert
      assert result == true
    end

    test "returns false when failed but backoff period has not elapsed" do
      # Arrange
      backoff_ms = 1000
      failed_at = System.monotonic_time(:millisecond) - (backoff_ms - 100)
      conn = SerialTestHelpers.build_failed_connection(failed_at: failed_at)

      # Act
      result = DeviceConnection.should_retry?(conn, backoff_ms)

      # Assert
      assert result == false
    end

    test "returns true when failed exactly at backoff boundary" do
      # Arrange
      backoff_ms = 1000
      failed_at = System.monotonic_time(:millisecond) - backoff_ms
      conn = SerialTestHelpers.build_failed_connection(failed_at: failed_at)

      # Act
      result = DeviceConnection.should_retry?(conn, backoff_ms)

      # Assert
      assert result == true
    end

    test "returns false when connection is :connecting" do
      # Arrange
      conn = SerialTestHelpers.build_connecting_connection()

      # Act
      result = DeviceConnection.should_retry?(conn, 1000)

      # Assert
      assert result == false
    end

    test "returns false when connection is :discovering" do
      # Arrange
      conn = SerialTestHelpers.build_discovering_connection()

      # Act
      result = DeviceConnection.should_retry?(conn, 1000)

      # Assert
      assert result == false
    end

    test "returns false when connection is :connected" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act
      result = DeviceConnection.should_retry?(conn, 1000)

      # Assert
      assert result == false
    end

    test "returns false when connection is :disconnecting" do
      # Arrange
      conn = SerialTestHelpers.build_disconnecting_connection()

      # Act
      result = DeviceConnection.should_retry?(conn, 1000)

      # Assert
      assert result == false
    end
  end

  describe "active?/1" do
    test "returns true for :connecting status" do
      # Arrange
      conn = SerialTestHelpers.build_connecting_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == true
    end

    test "returns true for :discovering status" do
      # Arrange
      conn = SerialTestHelpers.build_discovering_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == true
    end

    test "returns true for :connected status" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == true
    end

    test "returns true for :disconnecting status" do
      # Arrange
      conn = SerialTestHelpers.build_disconnecting_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == true
    end

    test "returns false for :failed status" do
      # Arrange
      conn = SerialTestHelpers.build_failed_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == false
    end

    test "returns false for :uploading status" do
      # Arrange
      conn = SerialTestHelpers.build_uploading_connection()

      # Act & Assert
      assert DeviceConnection.active?(conn) == false
    end
  end

  describe "mark_uploading/1" do
    test "transitions from :connected to :uploading with token" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act
      {updated_conn, token} = DeviceConnection.mark_uploading(conn)

      # Assert
      assert updated_conn.status == :uploading
      assert updated_conn.pid == nil
      assert updated_conn.upload_token == token
      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "generates unique tokens" do
      # Arrange
      conn1 = SerialTestHelpers.build_connected_connection()
      conn2 = SerialTestHelpers.build_connected_connection(port: "/dev/tty.test2")

      # Act
      {_, token1} = DeviceConnection.mark_uploading(conn1)
      {_, token2} = DeviceConnection.mark_uploading(conn2)

      # Assert
      assert token1 != token2
    end

    test "works for any device status" do
      # Arrange - a device in :discovering state
      conn = SerialTestHelpers.build_discovering_connection()

      # Act - should work without raising
      {updated_conn, token} = DeviceConnection.mark_uploading(conn)

      # Assert
      assert updated_conn.status == :uploading
      assert is_binary(token)
      assert updated_conn.upload_token == token
    end
  end

  describe "release_upload/2" do
    test "transitions from :uploading to :failed with valid token" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()
      {uploading_conn, token} = DeviceConnection.mark_uploading(conn)
      before_time = System.monotonic_time(:millisecond)

      # Act
      result = DeviceConnection.release_upload(uploading_conn, token)

      after_time = System.monotonic_time(:millisecond)

      # Assert
      assert {:ok, released_conn} = result
      assert released_conn.status == :failed
      assert released_conn.upload_token == nil
      assert released_conn.failed_at >= before_time
      assert released_conn.failed_at <= after_time
    end

    test "returns error with invalid token" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()
      {uploading_conn, _token} = DeviceConnection.mark_uploading(conn)

      # Act
      result = DeviceConnection.release_upload(uploading_conn, "wrong_token")

      # Assert
      assert {:error, :invalid_token} = result
    end

    test "returns error when not in :uploading state" do
      # Arrange
      conn = SerialTestHelpers.build_connected_connection()

      # Act
      result = DeviceConnection.release_upload(conn, "any_token")

      # Assert
      assert {:error, :invalid_token} = result
    end

    test "returns error when :failed (not :uploading)" do
      # Arrange
      conn = SerialTestHelpers.build_failed_connection()

      # Act
      result = DeviceConnection.release_upload(conn, "any_token")

      # Assert
      assert {:error, :invalid_token} = result
    end
  end

  describe "retry backoff" do
    defp failed(failures, failed_at \\ System.monotonic_time(:millisecond)) do
      %{SerialTestHelpers.build_failed_connection(failed_at: failed_at) | failures: failures}
    end

    test "doubles with each consecutive failure up to one minute" do
      assert Enum.map(1..7, &DeviceConnection.retry_backoff_ms(failed(&1))) ==
               [5_000, 10_000, 20_000, 40_000, 60_000, 60_000, 60_000]
    end

    test "stays capped for a port that has failed many times" do
      assert DeviceConnection.retry_backoff_ms(failed(10_000)) == 60_000
    end

    test "mark_failed counts consecutive failures" do
      conn = SerialTestHelpers.build_failed_connection()
      assert conn.failures == 1

      again =
        conn
        |> then(&DeviceConnection.new(&1.port, self(), &1))
        |> DeviceConnection.mark_disconnecting()
        |> DeviceConnection.mark_failed()

      assert again.failures == 2
    end

    test "new/3 keeps the failure count of the previous attempt" do
      assert DeviceConnection.new("/dev/tty.test", self(), failed(3)).failures == 3
      assert DeviceConnection.new("/dev/tty.test", self(), nil).failures == 0
    end

    test "connecting resets the failure count" do
      identity = SerialTestHelpers.build_identity_response()

      conn =
        DeviceConnection.new("/dev/tty.test", self(), failed(4))
        |> DeviceConnection.mark_discovering()
        |> DeviceConnection.mark_connected(identity)

      assert conn.failures == 0
    end

    test "should_retry?/1 retries a first failure after 5 seconds" do
      now = System.monotonic_time(:millisecond)

      refute DeviceConnection.should_retry?(failed(1, now - 4_000))
      assert DeviceConnection.should_retry?(failed(1, now - 5_000))
      refute DeviceConnection.should_retry?(failed(3, now - 15_000))
      assert DeviceConnection.should_retry?(failed(3, now - 20_000))
    end
  end
end
