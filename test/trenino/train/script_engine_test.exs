defmodule Trenino.Train.ScriptEngineTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.ScriptEngine

  describe "new/1" do
    test "creates VM with valid Lua code" do
      assert {:ok, _lua} = ScriptEngine.new("function on_change(event) end")
    end

    test "returns error for invalid Lua syntax" do
      assert {:error, _reason} = ScriptEngine.new("function on_change(event")
    end
  end

  describe "execute/2" do
    test "calls on_change with event" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          print(event.source)
        end
        """)

      assert {:ok, _lua, effects} = ScriptEngine.execute(lua, %{"source" => "test", "value" => 1.0})
      assert {:log, "test"} in effects
    end

    test "collects output.set side effects" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          output.set(3, true)
          output.set(7, false)
        end
        """)

      assert {:ok, _lua, effects} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:output_set, 3, true} in effects
      assert {:output_set, 7, false} in effects
    end

    test "collects schedule side effects" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          schedule(500)
        end
        """)

      assert {:ok, _lua, effects} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:schedule, 500} in effects
    end

    test "collects api.get side effects" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          api.get("SomeEndpoint")
        end
        """)

      assert {:ok, _lua, effects} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:api_get, "SomeEndpoint"} in effects
    end

    test "collects api.set side effects" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          api.set("SomeEndpoint", 0.5)
        end
        """)

      assert {:ok, _lua, effects} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:api_set, "SomeEndpoint", 0.5} in effects
    end

    test "state persists between invocations" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          if state.counter == nil then
            state.counter = 0
          end
          state.counter = state.counter + 1
          print(state.counter)
        end
        """)

      {:ok, lua, effects1} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:log, "1.0"} in effects1 or {:log, "1"} in effects1

      {:ok, _lua, effects2} = ScriptEngine.execute(lua, %{"source" => "test"})
      assert {:log, "2.0"} in effects2 or {:log, "2"} in effects2
    end

    test "returns error for runtime exceptions" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          error("intentional error")
        end
        """)

      assert {:error, _reason} = ScriptEngine.execute(lua, %{"source" => "test"})
    end

    test "sandboxed - no io access" do
      {:ok, lua} =
        ScriptEngine.new("""
        function on_change(event)
          io.write("should fail")
        end
        """)

      assert {:error, _reason} = ScriptEngine.execute(lua, %{"source" => "test"})
    end
  end
end
