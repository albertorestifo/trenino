defmodule Trenino.Simulator.ClientTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Trenino.Simulator.Client

  @base_url "http://localhost:31270"
  @api_key "test-api-key"

  setup :verify_on_exit!

  describe "new/2" do
    test "creates a client with the given base_url and api_key" do
      client = Client.new(@base_url, @api_key)

      assert %Client{base_url: @base_url, api_key: @api_key} = client
      assert %Req.Request{} = client.req
    end

    test "configures the Req request with base_url and DTGCommKey header" do
      client = Client.new(@base_url, @api_key)

      assert client.req.options.base_url == @base_url
      assert client.req.headers["dtgcommkey"] == [@api_key]
    end
  end

  describe "with_fast_timeouts/1" do
    test "preserves base_url and api_key" do
      client = Client.new(@base_url, @api_key)
      fast = Client.with_fast_timeouts(client)

      assert fast.base_url == @base_url
      assert fast.api_key == @api_key
    end

    test "sets short timeouts and disables retries" do
      client = Client.new(@base_url, @api_key)
      fast = Client.with_fast_timeouts(client)

      assert fast.req.options.receive_timeout == 1_000
      assert fast.req.options.pool_timeout == 500
      assert fast.req.options.max_retries == 0
      assert fast.req.options.retry == false
    end

    test "can make requests with fast client" do
      client = Client.new(@base_url, @api_key)
      fast = Client.with_fast_timeouts(client)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/info"

        {:ok, %Req.Response{status: 200, body: %{"commands" => ["info"]}}}
      end)

      assert {:ok, %{"commands" => ["info"]}} = Client.info(fast)
    end
  end

  describe "info/1" do
    test "makes a GET request to /info" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/info"
        assert req.headers["dtgcommkey"] == [@api_key]

        {:ok, %Req.Response{status: 200, body: %{"commands" => ["info", "list", "get"]}}}
      end)

      assert {:ok, %{"commands" => ["info", "list", "get"]}} = Client.info(client)
    end
  end

  describe "list/2" do
    test "makes a GET request to /list when no path is given" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/list"

        {:ok, %Req.Response{status: 200, body: %{"nodes" => ["CurrentDrivableActor"]}}}
      end)

      assert {:ok, %{"nodes" => ["CurrentDrivableActor"]}} = Client.list(client)
    end

    test "makes a GET request to /list/<path> when path is given" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/list/CurrentDrivableActor"

        {:ok, %Req.Response{status: 200, body: %{"nodes" => ["Throttle(Lever)", "TrainBrake"]}}}
      end)

      assert {:ok, %{"nodes" => ["Throttle(Lever)", "TrainBrake"]}} =
               Client.list(client, "CurrentDrivableActor")
    end
  end

  describe "get/2" do
    test "makes a GET request to /get/<path>" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/get/CurrentDrivableActor.Function.HUD_GetSpeed"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Speed (ms)" => 4.54}}
         }}
      end)

      assert {:ok, %{"Result" => "Success", "Values" => %{"Speed (ms)" => 4.54}}} =
               Client.get(client, "CurrentDrivableActor.Function.HUD_GetSpeed")
    end

    test "makes a GET request with nested path" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get

        assert opts[:url] ==
                 "/get/CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"ReturnValue" => 4}}
         }}
      end)

      assert {:ok, %{"Result" => "Success", "Values" => %{"ReturnValue" => 4}}} =
               Client.get(
                 client,
                 "CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex"
               )
    end
  end

  describe "set/3" do
    test "makes a PATCH request to /set/<path> with value parameter" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :patch
        assert opts[:url] == "/set/CurrentDrivableActor/Throttle(Lever).InputValue"
        assert opts[:params] == [Value: 0.25]

        {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
      end)

      assert {:ok, %{"Result" => "Success"}} =
               Client.set(client, "CurrentDrivableActor/Throttle(Lever).InputValue", 0.25)
    end

    test "handles boolean values" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :patch
        assert opts[:url] == "/set/VirtualRailDriver.Enabled"
        assert opts[:params] == [Value: true]

        {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
      end)

      assert {:ok, %{"Result" => "Success"}} =
               Client.set(client, "VirtualRailDriver.Enabled", true)
    end
  end

  describe "subscribe/3" do
    test "makes a POST request to /subscription/<path> with subscription id" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :post
        assert opts[:url] == "/subscription/CurrentDrivableActor.Function.HUD_GetSpeed"
        assert opts[:params] == [Subscription: 1]

        {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
      end)

      assert {:ok, %{"Result" => "Success"}} =
               Client.subscribe(client, "CurrentDrivableActor.Function.HUD_GetSpeed", 1)
    end
  end

  describe "get_subscription/2" do
    test "makes a GET request to /subscription with subscription id" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/subscription"
        assert opts[:params] == [Subscription: 1]

        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "RequestedSubscriptionID" => 1,
             "Entries" => [
               %{
                 "Path" => "CurrentDrivableActor.Function.HUD_GetSpeed",
                 "NodeValid" => true,
                 "Values" => %{"Speed (ms)" => 5.97}
               }
             ]
           }
         }}
      end)

      assert {:ok, %{"RequestedSubscriptionID" => 1, "Entries" => entries}} =
               Client.get_subscription(client, 1)

      assert [%{"Path" => "CurrentDrivableActor.Function.HUD_GetSpeed"}] = entries
    end
  end

  describe "unsubscribe/2" do
    test "makes a DELETE request to /subscription with subscription id" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :delete
        assert opts[:url] == "/subscription"
        assert opts[:params] == [Subscription: 1]

        {:ok, %Req.Response{status: 200, body: %{"Result" => "Success"}}}
      end)

      assert {:ok, %{"Result" => "Success"}} = Client.unsubscribe(client, 1)
    end
  end

  describe "list_subscriptions/1" do
    test "makes a GET request to /listsubscriptions" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, opts ->
        assert opts[:method] == :get
        assert opts[:url] == "/listsubscriptions"

        {:ok, %Req.Response{status: 200, body: %{"subscriptions" => [1, 2, 3]}}}
      end)

      assert {:ok, %{"subscriptions" => [1, 2, 3]}} = Client.list_subscriptions(client)
    end
  end

  describe "get_int/2" do
    test "extracts integer value from response" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"FormationLength" => 5}}
         }}
      end)

      assert {:ok, 5} = Client.get_int(client, "CurrentFormation.FormationLength")
    end

    test "truncates float to integer" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => 5.7}}
         }}
      end)

      assert {:ok, 5} = Client.get_int(client, "SomePath")
    end

    test "parses string to integer" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => "42"}}
         }}
      end)

      assert {:ok, 42} = Client.get_int(client, "SomePath")
    end

    test "returns error for empty values map" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{}}
         }}
      end)

      assert {:error, :invalid_value} = Client.get_int(client, "SomePath")
    end

    test "returns error for non-numeric string" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => "not a number"}}
         }}
      end)

      assert {:error, :invalid_value} = Client.get_int(client, "SomePath")
    end

    test "propagates HTTP errors" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok, %Req.Response{status: 500, body: %{"error" => "Internal error"}}}
      end)

      assert {:error, {:http_error, 500, _}} = Client.get_int(client, "SomePath")
    end
  end

  describe "get_float/2" do
    test "extracts float value from response" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Speed (ms)" => 4.54}}
         }}
      end)

      assert {:ok, 4.54} = Client.get_float(client, "CurrentDrivableActor.Function.HUD_GetSpeed")
    end

    test "converts integer to float" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => 5}}
         }}
      end)

      assert {:ok, 5.0} = Client.get_float(client, "SomePath")
    end

    test "parses string to float" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => "3.14"}}
         }}
      end)

      assert {:ok, 3.14} = Client.get_float(client, "SomePath")
    end

    test "returns error for empty values map" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{}}
         }}
      end)

      assert {:error, :invalid_value} = Client.get_float(client, "SomePath")
    end
  end

  describe "get_string/2" do
    test "extracts string value from response" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"ObjectClass" => "BR_Class_66_DB"}}
         }}
      end)

      assert {:ok, "BR_Class_66_DB"} =
               Client.get_string(client, "CurrentFormation/0.ObjectClass")
    end

    test "converts numeric value to string" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"Value" => 123}}
         }}
      end)

      assert {:ok, "123"} = Client.get_string(client, "SomePath")
    end

    test "returns error for empty values map" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{}}
         }}
      end)

      assert {:error, :invalid_value} = Client.get_string(client, "SomePath")
    end
  end

  describe "error handling" do
    test "returns {:error, {:invalid_key, body}} on 403 response" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 403,
           body: %{
             "errorCode" => "dtg.comm.InvalidKey",
             "errorMessage" =>
               "API Key for request doesn't match CommAPIKey.txt in the game config directory."
           }
         }}
      end)

      assert {:error, {:invalid_key, %{"errorCode" => "dtg.comm.InvalidKey"}}} =
               Client.info(client)
    end

    test "returns {:error, {:http_error, status, body}} on other error status codes" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 500,
           body: %{"error" => "Internal server error"}
         }}
      end)

      assert {:error, {:http_error, 500, %{"error" => "Internal server error"}}} =
               Client.info(client)
    end

    test "returns {:error, {:request_failed, reason}} on request failure" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:error, %Mint.TransportError{reason: :econnrefused}}
      end)

      assert {:error, {:request_failed, %Mint.TransportError{reason: :econnrefused}}} =
               Client.info(client)
    end
  end
end
