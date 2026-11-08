defmodule Trenino.MCP.Tools.LeverToolsTest do
  use Trenino.DataCase, async: true

  import Trenino.VirtualJoystickFixtures

  alias Trenino.MCP.ToolRegistry
  alias Trenino.MCP.Tools.LeverTools
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.UINavigation

  @reverser "CurrentDrivableActor/ToolsReverser"

  # A fake 3-position reverser: Reverse (0.0), Neutral (0.5), Forward (1.0)
  setup do
    {:ok, lever} = Agent.start_link(fn -> 0.5 end)
    client = Client.new("http://localhost:31270", "key")
    stub(Connection, :get_status, fn -> %ConnectionState{status: :connected, client: client} end)
    stub(Req, :request, fn _req, opts -> fake_simulator(lever, opts) end)

    {:ok, train} =
      TrainContext.create_train(%{
        name: "Lever Train",
        identifiers: [%{identifier: "lever_tools"}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Reverser", type: :lever})

    %{train: train, element: element, lever: lever}
  end

  defp fake_simulator(lever, opts) do
    case {opts[:method], URI.decode(opts[:url])} do
      {:patch, _url} ->
        Agent.update(lever, fn _ -> Keyword.fetch!(opts[:params], :Value) end)
        reply(%{"Result" => "Success"})

      {:get, "/list/CurrentDrivableActor"} ->
        reply(%{"Nodes" => [%{"Name" => "ToolsReverser"}, %{"Name" => "Horn"}]})

      {:get, "/get/" <> path} ->
        get(path, Agent.get(lever, & &1))
    end
  end

  defp get(path, input) do
    {actual, output, index} =
      cond do
        input < 0.25 -> {0.0, -1.0, 0}
        input < 0.75 -> {0.5, 0.0, 1}
        true -> {1.0, 1.0, 2}
      end

    case String.split(path, ".", parts: 2) do
      ["CurrentDrivableActor/ToolsReverser", endpoint] ->
        reverser(endpoint, actual, output, index)

      ["CurrentDrivableActor", "Function.HUD_GetSpeed"] ->
        value(0.0)

      _ ->
        reply(%{"Result" => "Error"})
    end
  end

  defp reverser(endpoint, actual, output, index) do
    responses = %{
      "Function.GetNotchCount" => value(3),
      "Property.InputIdentifier" => values(%{"identifier" => "Reverser"}),
      "Function.GetMinimumInputValue" => value(0.0),
      "Function.GetMaximumInputValue" => value(1.0),
      "Function.GetMinimumOutputValue" => value(-1.0),
      "Function.GetMaximumOutputValue" => value(1.0),
      "Property.DisplayInfo" => values(%{"namedValues" => labels()}),
      "Function.GetCurrentOutputValue" => value(output),
      "Function.GetCurrentNotchIndex" => value(index),
      "InputValue" => value(actual)
    }

    Map.get(responses, endpoint, value(0.0))
  end

  defp labels do
    for {name, center} <- [{"Reverse", -1}, {"Neutral", 0}, {"Forward", 1}] do
      %{
        "valueSource" => "Output",
        "valueRange" => %{"min" => center - 0.5, "max" => center + 0.5},
        "displayName" => name
      }
    end
  end

  defp value(v), do: values(%{"ReturnValue" => v})
  defp values(v), do: reply(%{"Result" => "Success", "Values" => v})
  defp reply(body), do: {:ok, %Req.Response{status: 200, body: body}}

  defp run(tool, args), do: LeverTools.execute(tool, args)

  defp calibrated(element) do
    {:ok, _} =
      run("set_lever_endpoint", %{"element_id" => element.id, "control_path" => @reverser})

    {:ok, result} = run("calibrate_lever", %{"element_id" => element.id})
    result
  end

  test "registers its tools" do
    names = Enum.map(ToolRegistry.list_tools(), & &1.name)

    for name <- ~w(list_simulator_levers get_lever set_lever_endpoint calibrate_lever
                   bind_lever_input open_lever_setup) do
      assert name in names
    end
  end

  describe "list_simulator_levers" do
    test "lists levers with their role and positions, best match first" do
      assert {:ok, %{levers: [lever], best_matches: [match]}} =
               run("list_simulator_levers", %{"match" => "Direction"})

      assert lever.control_path == @reverser
      assert lever.role == "Reverser"
      assert Enum.map(lever.positions, & &1.name) == ["Reverse", "Neutral", "Forward"]
      assert match.control_path == @reverser
    end

    test "needs the simulator" do
      stub(Connection, :get_status, fn -> %ConnectionState{status: :disconnected} end)
      assert {:error, "Simulator not connected" <> _} = run("list_simulator_levers", %{})
    end
  end

  describe "a lever set up step by step" do
    test "endpoint, calibration, input, then the user maps notches", %{element: element} do
      assert {:ok, %{next_step: :set_endpoint}} = run("get_lever", %{"element_id" => element.id})

      assert {:ok, %{next_step: :calibrate, lever: %{control_path: @reverser}}} =
               run("set_lever_endpoint", %{
                 "element_id" => element.id,
                 "control_path" => @reverser
               })

      result = run("calibrate_lever", %{"element_id" => element.id}) |> elem(1)

      assert result.next_step == :bind_input
      assert result.lever_type == :discrete
      assert result.warnings == []

      assert Enum.map(result.lever.notches, &{&1.name, &1.output, &1.sim_input}) == [
               {"Reverse", -1.0, [0.0, 0.0]},
               {"Neutral", 0.0, [0.5, 0.5]},
               {"Forward", 1.0, [1.0, 1.0]}
             ]

      # Neutral is the zero centre, so it holds harder
      assert result.lever.notch_disk_url =~ "train-lever-generator/?positions=3&deep=2&smooth="

      input = analog_input_fixture()

      assert {:ok, %{next_step: :map_notches, ui_path: path}} =
               run("bind_lever_input", %{"element_id" => element.id, "input_id" => input.id})

      assert path =~ "lever=#{element.id}"
      assert path =~ "step=map_notches"
    end

    test "calibration restores the lever", %{element: element, lever: lever} do
      calibrated(element)
      assert Agent.get(lever, & &1) == 0.5
    end
  end

  describe "calibrate_lever" do
    test "calibrates while the train moves and restores the lever", %{
      element: element,
      lever: lever
    } do
      {:ok, _} =
        run("set_lever_endpoint", %{"element_id" => element.id, "control_path" => @reverser})

      stub(Req, :request, fn _req, opts ->
        if opts[:url] =~ "HUD_GetSpeed",
          do: value(5.0),
          else: fake_simulator(lever, opts)
      end)

      assert {:ok, result} = run("calibrate_lever", %{"element_id" => element.id})
      assert result.lever_type == :discrete
      assert Agent.get(lever, & &1) == 0.5
    end

    test "needs an endpoint first", %{element: element} do
      assert {:error, message} = run("calibrate_lever", %{"element_id" => element.id})
      assert message =~ "set_lever_endpoint"
    end

    test "keeps the hardware notch mapping when the notches are unchanged", %{element: element} do
      calibrated(element)
      {:ok, config} = TrainContext.get_lever_config(element.id)

      updates =
        config.notches
        |> Enum.sort_by(& &1.index)
        |> Enum.with_index()
        |> Enum.map(fn {notch, i} ->
          %{id: notch.id, input_min: i * 0.3, input_max: i * 0.3 + 0.2}
        end)

      {:ok, _} = TrainContext.update_notch_input_ranges(config.id, updates)

      {:ok, _} =
        run("bind_lever_input", %{
          "element_id" => element.id,
          "input_id" => analog_input_fixture().id
        })

      assert %{next_step: :done} = calibrated(element)
    end
  end

  describe "set_lever_endpoint" do
    test "rejects a path that is not a lever", %{element: element} do
      assert {:error, message} =
               run("set_lever_endpoint", %{
                 "element_id" => element.id,
                 "control_path" => "CurrentDrivableActor/Horn"
               })

      assert message =~ "not a lever in the loaded train"
    end

    test "rejects an element that is not a lever", %{train: train} do
      {:ok, button} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      assert {:error, "Element " <> _} =
               run("set_lever_endpoint", %{"element_id" => button.id, "control_path" => @reverser})
    end
  end

  describe "bind_lever_input" do
    setup %{element: element} do
      {:ok, _} =
        run("set_lever_endpoint", %{"element_id" => element.id, "control_path" => @reverser})

      :ok
    end

    test "rejects a button input", %{element: element} do
      input = button_input_fixture()

      assert {:error, "That input is not analog" <> _} =
               run("bind_lever_input", %{"element_id" => element.id, "input_id" => input.id})
    end

    test "rejects an uncalibrated input", %{element: element} do
      {:ok, input} =
        Trenino.Hardware.create_input(device_fixture().id, %{
          pin: 7,
          input_type: :analog,
          sensitivity: 5
        })

      assert {:error, "That input is not calibrated" <> _} =
               run("bind_lever_input", %{"element_id" => element.id, "input_id" => input.id})
    end
  end

  describe "open_lever_setup" do
    test "rejects a step that cannot be linked", %{element: element} do
      assert {:error, "step must be one of" <> _} =
               run("open_lever_setup", %{"element_id" => element.id, "step" => "run_calibration"})
    end

    test "says so when no window is open", %{element: element} do
      assert {:ok, %{window_notified: false, message: message}} =
               run("open_lever_setup", %{"element_id" => element.id})

      assert message =~ "No Trenino window is open"
    end

    test "navigates an open window to the lever's next step", %{element: element, train: train} do
      test_pid = self()

      spawn_link(fn ->
        UINavigation.subscribe()
        send(test_pid, :subscribed)

        receive do
          {:ui_navigate, path, from, ref} ->
            UINavigation.ack(from, ref)
            send(test_pid, {:navigated, path})
        end
      end)

      assert_receive :subscribed

      assert {:ok, %{window_notified: true, step: "find_endpoint"}} =
               run("open_lever_setup", %{"element_id" => element.id})

      assert_receive {:navigated, path}
      assert path == "/trains/#{train.id}?lever=#{element.id}&step=find_endpoint"
    end
  end
end
