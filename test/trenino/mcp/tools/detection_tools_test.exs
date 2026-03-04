defmodule Trenino.MCP.Tools.DetectionToolsTest do
  use Trenino.DataCase, async: false
  use Mimic

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.DetectionTools
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState

  @input_values_topic "hardware:input_values"
  @test_port "test_port"

  defp broadcast_input(pin, value) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@input_values_topic}:#{@test_port}",
      {:input_value_updated, @test_port, pin, value}
    )
  end

  describe "tools/0" do
    test "returns both tool definitions" do
      tools = DetectionTools.tools()
      assert length(tools) == 2

      names = Enum.map(tools, & &1.name)
      assert "detect_hardware_input" in names
      assert "detect_simulator_endpoint" in names
    end

    test "detect_hardware_input has required fields" do
      tool = Enum.find(DetectionTools.tools(), &(&1.name == "detect_hardware_input"))

      assert tool.description =~ "hardware input"
      assert tool.input_schema.properties.prompt
      assert "prompt" in tool.input_schema.required
    end

    test "detect_simulator_endpoint has required fields" do
      tool = Enum.find(DetectionTools.tools(), &(&1.name == "detect_simulator_endpoint"))

      assert tool.description =~ "simulator"
      assert tool.input_schema.properties.prompt
      assert "prompt" in tool.input_schema.required
    end
  end

  describe "detect_hardware_input" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, button} = Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 50})

      %{device: device, button: button}
    end

    test "detects a button input", %{button: button} do
      task =
        Task.async(fn ->
          DetectionTools.execute("detect_hardware_input", %{
            "prompt" => "Press any button",
            "timeout_ms" => 2_000
          })
        end)

      # Give the detection session time to subscribe
      Process.sleep(50)

      # Establish baseline then trigger change
      broadcast_input(button.pin, 0)
      broadcast_input(button.pin, 1)

      assert {:ok, result} = Task.await(task, 3_000)
      assert result.detected == true
      assert result.input.input_id == button.id
      assert result.input.input_type == :button
      assert result.input.pin == button.pin
    end

    test "filters by input_type when specified", %{device: device, button: button} do
      {:ok, analog} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_hardware_input", %{
            "prompt" => "Press a button",
            "input_type" => "button",
            "timeout_ms" => 1_000
          })
        end)

      Process.sleep(50)

      # Analog input should be ignored when filtering for buttons
      broadcast_input(analog.pin, 0)
      broadcast_input(analog.pin, 1023)

      # Button press should be detected
      broadcast_input(button.pin, 0)
      broadcast_input(button.pin, 1)

      assert {:ok, result} = Task.await(task, 2_000)
      assert result.detected == true
      assert result.input.input_type == :button
    end

    test "returns timeout result when no input is detected" do
      assert {:ok, result} =
               DetectionTools.execute("detect_hardware_input", %{
                 "prompt" => "Press any button",
                 "timeout_ms" => 100
               })

      assert result.detected == false
      assert result.reason == "timeout"
    end

    test "broadcasts detection_request to mcp:detection topic" do
      Phoenix.PubSub.subscribe(Trenino.PubSub, "mcp:detection")

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_hardware_input", %{
            "prompt" => "Press any button",
            "timeout_ms" => 200
          })
        end)

      assert_receive {:detection_request, %{type: :hardware, prompt: "Press any button", id: id}},
                     500

      assert is_binary(id)

      Task.await(task, 1_000)
    end

    test "broadcasts detection_complete after detection" do
      Phoenix.PubSub.subscribe(Trenino.PubSub, "mcp:detection")

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_hardware_input", %{
            "prompt" => "Press any button",
            "timeout_ms" => 200
          })
        end)

      assert_receive {:detection_request, %{id: id}}, 500
      Task.await(task, 1_000)

      assert_receive {:detection_complete, ^id}, 500
    end

    test "defaults to :any input type when input_type not specified", %{device: device} do
      {:ok, analog} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_hardware_input", %{
            "prompt" => "Move any control",
            "timeout_ms" => 2_000
          })
        end)

      Process.sleep(50)

      broadcast_input(analog.pin, 500)
      broadcast_input(analog.pin, 600)

      assert {:ok, result} = Task.await(task, 3_000)
      assert result.detected == true
      assert result.input.input_type == :analog
    end
  end

  describe "detect_simulator_endpoint" do
    test "returns not connected when simulator is disconnected" do
      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :disconnected, client: nil}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move a control"
               })

      assert result.detected == false
      assert result.reason =~ "not connected"
    end

    test "returns not connected when simulator is in needs_config state" do
      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :needs_config, client: nil}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move a control"
               })

      assert result.detected == false
      assert result.reason =~ "not connected"
    end

    test "returns not connected when status is connected but client is nil" do
      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: nil}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move a control"
               })

      assert result.detected == false
      assert result.reason =~ "not connected"
    end

    test "broadcasts detection_request with type :simulator when connected" do
      alias Trenino.Simulator.Client
      alias Trenino.Simulator.ControlDetectionSession

      client = Client.new("http://localhost:1234", "test-key")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(ControlDetectionSession, :start, fn _client, callback_pid ->
        send(callback_pid, {:detection_timeout})
        {:ok, spawn(fn -> :ok end)}
      end)

      Phoenix.PubSub.subscribe(Trenino.PubSub, "mcp:detection")

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_simulator_endpoint", %{
            "prompt" => "Move the throttle"
          })
        end)

      assert_receive {:detection_request, %{type: :simulator, prompt: "Move the throttle", id: id}},
                     500

      assert is_binary(id)
      Task.await(task, 2_000)
    end

    test "returns detection result with control info on success" do
      alias Trenino.Simulator.Client
      alias Trenino.Simulator.ControlDetectionSession

      client = Client.new("http://localhost:1234", "test-key")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      changes = [
        %{
          endpoint: "CurrentDrivableActor/Throttle.InputValue",
          control_name: "Throttle",
          previous_value: 0.0,
          current_value: -0.20000000298023224
        },
        %{
          endpoint: "CurrentDrivableActor/Brake.InputValue",
          control_name: "Brake",
          previous_value: 1.0,
          current_value: 0.5
        }
      ]

      stub(ControlDetectionSession, :start, fn _client, callback_pid ->
        send(callback_pid, {:control_detected, changes})
        {:ok, spawn(fn -> :ok end)}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move the throttle"
               })

      assert result.detected == true
      assert result.endpoint == "CurrentDrivableActor/Throttle.InputValue"
      assert result.control_name == "Throttle"
      assert result.previous_value == 0.0
      # Float should be rounded to 2 decimal places
      assert result.current_value == -0.20
      assert length(result.all_changes) == 2
    end

    test "returns timeout result when no control is detected" do
      alias Trenino.Simulator.Client
      alias Trenino.Simulator.ControlDetectionSession

      client = Client.new("http://localhost:1234", "test-key")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(ControlDetectionSession, :start, fn _client, callback_pid ->
        send(callback_pid, {:detection_timeout})
        {:ok, spawn(fn -> :ok end)}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move a control"
               })

      assert result.detected == false
      assert result.reason == "timeout"
    end

    test "returns error result on detection error" do
      alias Trenino.Simulator.Client
      alias Trenino.Simulator.ControlDetectionSession

      client = Client.new("http://localhost:1234", "test-key")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(ControlDetectionSession, :start, fn _client, callback_pid ->
        send(callback_pid, {:detection_error, :connection_lost})
        {:ok, spawn(fn -> :ok end)}
      end)

      assert {:ok, result} =
               DetectionTools.execute("detect_simulator_endpoint", %{
                 "prompt" => "Move a control"
               })

      assert result.detected == false
      assert result.reason =~ "error"
    end

    test "broadcasts detection_complete after successful detection" do
      alias Trenino.Simulator.Client
      alias Trenino.Simulator.ControlDetectionSession

      client = Client.new("http://localhost:1234", "test-key")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      changes = [
        %{
          endpoint: "CurrentDrivableActor/Horn.InputValue",
          control_name: "Horn",
          previous_value: 0.0,
          current_value: 1.0
        }
      ]

      stub(ControlDetectionSession, :start, fn _client, callback_pid ->
        send(callback_pid, {:control_detected, changes})
        {:ok, spawn(fn -> :ok end)}
      end)

      Phoenix.PubSub.subscribe(Trenino.PubSub, "mcp:detection")

      task =
        Task.async(fn ->
          DetectionTools.execute("detect_simulator_endpoint", %{
            "prompt" => "Honk the horn"
          })
        end)

      assert_receive {:detection_request, %{id: id}}, 500
      Task.await(task, 2_000)

      assert_receive {:detection_complete, ^id}, 500
    end
  end
end
