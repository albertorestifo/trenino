defmodule Trenino.Simulator.ControlDetectionSessionTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ControlDetectionSession

  setup :set_mimic_global

  describe "start/2" do
    test "discovers InputValue endpoints from list response" do
      client = build_mock_client()

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [
                   %{"NodeName" => "Horn"},
                   %{"NodeName" => "Throttle(Lever)"}
                 ],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Horn" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          path == "/list/CurrentDrivableActor/Throttle%28Lever%29" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" ->
            case Keyword.get(opts, :method) do
              :get ->
                {:ok,
                 %Req.Response{
                   status: 200,
                   body: %{
                     "Result" => "Success",
                     "Entries" => [
                       %{
                         "Path" => "CurrentDrivableActor/Horn.InputValue",
                         "Values" => %{"InputValue" => 0.0}
                       },
                       %{
                         "Path" => "CurrentDrivableActor/Throttle(Lever).InputValue",
                         "Values" => %{"InputValue" => 0.0}
                       }
                     ]
                   }
                 }}

              :delete ->
                {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

              _ ->
                {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
            end

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      assert {:ok, pid} = ControlDetectionSession.start(client, self())
      assert Process.alive?(pid)

      # Cleanup
      ControlDetectionSession.stop(pid)
    end

    test "sends detection_error when list fails" do
      client = build_mock_client()

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok, %Req.Response{status: 500, body: "Internal Server Error"}}

          path == "/subscription" and Keyword.get(opts, :method) == :delete ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      # GenServer returns {:error, :normal} when init returns {:stop, :normal}
      assert {:error, :normal} = ControlDetectionSession.start(client, self())

      assert_receive {:detection_error, _reason}, 1000
    end
  end

  describe "change detection" do
    test "detects single control change" do
      client = build_mock_client()
      poll_count = :counters.new(1, [:atomics])

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")
        method = Keyword.get(opts, :method, :get)

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [%{"NodeName" => "Horn"}],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Horn" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" and method == :get ->
            count = :counters.get(poll_count, 1)
            :counters.add(poll_count, 1, 1)

            if count == 0 do
              # First poll - baseline
              {:ok,
               %Req.Response{
                 status: 200,
                 body: %{
                   "Result" => "Success",
                   "Entries" => [
                     %{
                       "Path" => "CurrentDrivableActor/Horn.InputValue",
                       "Values" => %{"InputValue" => 0.0}
                     }
                   ]
                 }
               }}
            else
              # Subsequent polls - change detected
              {:ok,
               %Req.Response{
                 status: 200,
                 body: %{
                   "Result" => "Success",
                   "Entries" => [
                     %{
                       "Path" => "CurrentDrivableActor/Horn.InputValue",
                       "Values" => %{"InputValue" => 1.0}
                     }
                   ]
                 }
               }}
            end

          path == "/subscription" and method == :delete ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      {:ok, pid} = ControlDetectionSession.start(client, self())

      assert_receive {:control_detected, changes}, 1000

      assert length(changes) == 1
      [change] = changes
      assert change.endpoint == "CurrentDrivableActor/Horn.InputValue"
      assert change.control_name == "Horn"
      assert change.previous_value == 0.0
      assert change.current_value == 1.0

      # Session should have stopped - wait a bit for cleanup
      Process.sleep(50)
      refute Process.alive?(pid)
    end

    test "detects multiple simultaneous changes" do
      client = build_mock_client()
      poll_count = :counters.new(1, [:atomics])

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")
        method = Keyword.get(opts, :method, :get)

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [
                   %{"NodeName" => "Horn"},
                   %{"NodeName" => "Light"}
                 ],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Horn" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          path == "/list/CurrentDrivableActor/Light" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" and method == :get ->
            count = :counters.get(poll_count, 1)
            :counters.add(poll_count, 1, 1)

            if count == 0 do
              {:ok,
               %Req.Response{
                 status: 200,
                 body: %{
                   "Result" => "Success",
                   "Entries" => [
                     %{
                       "Path" => "CurrentDrivableActor/Horn.InputValue",
                       "Values" => %{"InputValue" => 0.0}
                     },
                     %{
                       "Path" => "CurrentDrivableActor/Light.InputValue",
                       "Values" => %{"InputValue" => 0.0}
                     }
                   ]
                 }
               }}
            else
              {:ok,
               %Req.Response{
                 status: 200,
                 body: %{
                   "Result" => "Success",
                   "Entries" => [
                     %{
                       "Path" => "CurrentDrivableActor/Horn.InputValue",
                       "Values" => %{"InputValue" => 1.0}
                     },
                     %{
                       "Path" => "CurrentDrivableActor/Light.InputValue",
                       "Values" => %{"InputValue" => 0.5}
                     }
                   ]
                 }
               }}
            end

          path == "/subscription" and method == :delete ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      {:ok, _pid} = ControlDetectionSession.start(client, self())

      assert_receive {:control_detected, changes}, 1000
      assert length(changes) == 2
    end

    test "ignores changes below threshold (< 0.01)" do
      client = build_mock_client()
      poll_count = :counters.new(1, [:atomics])

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")
        method = Keyword.get(opts, :method, :get)

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [%{"NodeName" => "Horn"}],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Horn" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" and method == :get ->
            count = :counters.get(poll_count, 1)
            :counters.add(poll_count, 1, 1)

            # Always return tiny change (below threshold)
            value = if count == 0, do: 0.0, else: 0.005

            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Entries" => [
                   %{
                     "Path" => "CurrentDrivableActor/Horn.InputValue",
                     "Values" => %{"InputValue" => value}
                   }
                 ]
               }
             }}

          path == "/subscription" and method == :delete ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      {:ok, pid} = ControlDetectionSession.start(client, self())

      # Should NOT receive detection (wait a bit to make sure)
      refute_receive {:control_detected, _}, 500

      # Session should still be running
      assert Process.alive?(pid)

      ControlDetectionSession.stop(pid)
    end
  end

  describe "cleanup" do
    test "cleans up subscription on stop" do
      client = build_mock_client()
      unsubscribe_count = :counters.new(1, [:atomics])

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")
        method = Keyword.get(opts, :method, :get)

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [%{"NodeName" => "Horn"}],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Horn" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" and method == :get ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Entries" => [
                   %{
                     "Path" => "CurrentDrivableActor/Horn.InputValue",
                     "Values" => %{"InputValue" => 0.0}
                   }
                 ]
               }
             }}

          path == "/subscription" and method == :delete ->
            :counters.add(unsubscribe_count, 1, 1)
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      {:ok, pid} = ControlDetectionSession.start(client, self())
      Process.sleep(100)

      ControlDetectionSession.stop(pid)

      # Give it time to cleanup
      Process.sleep(100)

      # Should have called unsubscribe at least once during stop
      assert :counters.get(unsubscribe_count, 1) >= 1
    end
  end

  describe "extract_control_name" do
    test "extracts control name from nested path" do
      client = build_mock_client()
      poll_count = :counters.new(1, [:atomics])

      stub(Req, :request, fn _req, opts ->
        path = Keyword.get(opts, :url, "")
        method = Keyword.get(opts, :method, :get)

        cond do
          path == "/list/CurrentDrivableActor" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [%{"NodeName" => "Throttle(Lever)"}],
                 "Endpoints" => []
               }
             }}

          path == "/list/CurrentDrivableActor/Throttle%28Lever%29" ->
            {:ok,
             %Req.Response{
               status: 200,
               body: %{
                 "Result" => "Success",
                 "Nodes" => [],
                 "Endpoints" => [%{"Name" => "InputValue", "Writable" => true}]
               }
             }}

          String.starts_with?(path, "/subscription/") ->
            {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}

          path == "/subscription" ->
            case method do
              :get ->
                count = :counters.get(poll_count, 1)
                :counters.add(poll_count, 1, 1)

                value = if count == 0, do: 0.0, else: 0.5

                {:ok,
                 %Req.Response{
                   status: 200,
                   body: %{
                     "Result" => "Success",
                     "Entries" => [
                       %{
                         "Path" => "CurrentDrivableActor/Throttle(Lever).InputValue",
                         "Values" => %{"InputValue" => value}
                       }
                     ]
                   }
                 }}

              _ ->
                {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
            end

          true ->
            {:ok, %Req.Response{status: 404, body: "Not Found"}}
        end
      end)

      {:ok, _pid} = ControlDetectionSession.start(client, self())

      assert_receive {:control_detected, [change]}, 1000
      assert change.control_name == "Throttle(Lever)"
    end
  end

  # Helper to build a mock client
  defp build_mock_client do
    Client.new("http://localhost:31270", "test-api-key")
  end
end
