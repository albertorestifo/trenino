defmodule Trenino.Train.IdentifierTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Trenino.Simulator.Client
  alias Trenino.Train.Identifier

  @base_url "http://localhost:31270"
  @api_key "test-api-key"

  setup :verify_on_exit!

  describe "common_prefix/1" do
    test "returns empty string for empty list" do
      assert Identifier.common_prefix([]) == ""
    end

    test "returns the single string when list has one element" do
      assert Identifier.common_prefix(["BR_Class_66"]) == "BR_Class_66"
    end

    test "finds common prefix of two identical strings" do
      assert Identifier.common_prefix(["BR_Class_66", "BR_Class_66"]) == "BR_Class_66"
    end

    test "finds common prefix of strings with same beginning" do
      assert Identifier.common_prefix(["BR_Class_66_DB", "BR_Class_66_Freightliner"]) ==
               "BR_Class_66"
    end

    test "finds common prefix across multiple strings" do
      strings = [
        "BR_Class_66_DB_Cargo",
        "BR_Class_66_Freightliner",
        "BR_Class_66_GBRF"
      ]

      assert Identifier.common_prefix(strings) == "BR_Class_66"
    end

    test "returns empty string when no common prefix exists" do
      assert Identifier.common_prefix(["ABC", "XYZ"]) == ""
    end

    test "handles strings of different lengths" do
      assert Identifier.common_prefix(["AB", "ABCD", "ABCDEF"]) == "AB"
    end

    test "handles unicode characters" do
      assert Identifier.common_prefix(["Zürich_Train_A", "Zürich_Train_B"]) == "Zürich_Train"
    end

    test "strips trailing non-alphanumeric characters" do
      # Common prefix should not end with underscore or other non-alphanumeric chars
      assert Identifier.common_prefix(["BR_Class_66_DB", "BR_Class_66_Freightliner"]) ==
               "BR_Class_66"
    end

    test "strips multiple trailing non-alphanumeric characters" do
      assert Identifier.common_prefix(["Train__A", "Train__B"]) == "Train"
    end

    test "handles prefix that is entirely alphanumeric" do
      assert Identifier.common_prefix(["ABC123X", "ABC123Y"]) == "ABC123"
    end
  end

  describe "derive_from_formation/1" do
    test "returns identifier from drivable actor ObjectClass" do
      client = Client.new(@base_url, @api_key)

      # Mock drivable index
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation.DrivableIndex"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"DrivableIndex" => 0}}
         }}
      end)

      # Mock object class at drivable index
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation/0.ObjectClass"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"ObjectClass" => "RVM_SBN_OBB_1116_C"}}
         }}
      end)

      assert {:ok, identifier} = Identifier.derive_from_formation(client)
      assert identifier == "RVM_SBN_OBB_1116"
    end

    test "uses correct drivable index when not 0" do
      client = Client.new(@base_url, @api_key)

      # Mock drivable index at position 2
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation.DrivableIndex"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"DrivableIndex" => 2}}
         }}
      end)

      # Mock object class at drivable index 2
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation/2.ObjectClass"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"ObjectClass" => "RVM_FSN_DB_BR430_C"}}
         }}
      end)

      assert {:ok, identifier} = Identifier.derive_from_formation(client)
      assert identifier == "RVM_FSN_DB_BR430"
    end

    test "falls back to index 0 when DrivableIndex request fails" do
      client = Client.new(@base_url, @api_key)

      # Mock failing drivable index request
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation.DrivableIndex"
        {:ok, %Req.Response{status: 500, body: %{"error" => "Internal error"}}}
      end)

      # Should fall back to index 0
      expect(Req, :request, fn _req, opts ->
        assert opts[:url] == "/get/CurrentFormation/0.ObjectClass"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"ObjectClass" => "RVM_Train_Class_C"}}
         }}
      end)

      assert {:ok, identifier} = Identifier.derive_from_formation(client)
      assert identifier == "RVM_Train_Class"
    end

    test "returns error when all requests fail" do
      client = Client.new(@base_url, @api_key)

      # Mock failing drivable index request
      expect(Req, :request, fn _req, _opts ->
        {:ok, %Req.Response{status: 500, body: %{"error" => "Internal error"}}}
      end)

      # Mock failing fallback request
      expect(Req, :request, fn _req, _opts ->
        {:ok, %Req.Response{status: 500, body: %{"error" => "Internal error"}}}
      end)

      assert {:error, {:http_error, 500, _}} = Identifier.derive_from_formation(client)
    end

    test "strips _C suffix and trailing non-alphanumeric from ObjectClass" do
      client = Client.new(@base_url, @api_key)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"Result" => "Success", "Values" => %{"DrivableIndex" => 0}}
         }}
      end)

      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "Result" => "Success",
             "Values" => %{"ObjectClass" => "RVM_PBO_Class142_DMSL_C"}
           }
         }}
      end)

      assert {:ok, identifier} = Identifier.derive_from_formation(client)
      assert identifier == "RVM_PBO_Class142_DMSL"
    end
  end
end
