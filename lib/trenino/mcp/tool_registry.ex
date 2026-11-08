defmodule Trenino.MCP.ToolRegistry do
  @moduledoc """
  Collects all MCP tool definitions and dispatches tool calls.

  Each tool module exports a `tools/0` function returning a list of tool
  definitions, and an `execute/2` function that handles a specific tool call.
  """

  alias Trenino.Beta

  alias Trenino.MCP.Tools.{
    ButtonBindingTools,
    DetectionTools,
    DeviceTools,
    DialCalibrationTools,
    DisplayBindingTools,
    ElementTools,
    GaugeBindingTools,
    GaugeRuntimeTools,
    OutputBindingTools,
    ScriptTools,
    SelectorTools,
    SequenceTools,
    SimulatorTools,
    StepperTools,
    TrainTools,
    VirtualJoystickTools
  }

  @tool_modules [
    SimulatorTools,
    TrainTools,
    ElementTools,
    DeviceTools,
    OutputBindingTools,
    ButtonBindingTools,
    SelectorTools,
    SequenceTools,
    ScriptTools,
    DetectionTools,
    DisplayBindingTools,
    VirtualJoystickTools,
    StepperTools,
    GaugeBindingTools,
    GaugeRuntimeTools,
    DialCalibrationTools
  ]

  # Tool modules hidden unless their beta feature is enabled (see Trenino.Beta)
  @beta_tool_modules %{
    StepperTools => :gauges,
    GaugeBindingTools => :gauges,
    GaugeRuntimeTools => :gauges,
    DialCalibrationTools => :gauges,
    SelectorTools => :selectors
  }

  @type tool_def :: %{
          name: String.t(),
          description: String.t(),
          input_schema: map()
        }

  @spec list_tools() :: [tool_def()]
  def list_tools do
    Enum.flat_map(tool_modules(), & &1.tools())
  end

  @spec call_tool(String.t(), map()) :: {:ok, term()} | {:error, String.t()}
  def call_tool(name, arguments) do
    case find_tool_module(name) do
      {:ok, module} -> module.execute(name, arguments)
      :error -> {:error, "Unknown tool: #{name}"}
    end
  end

  defp tool_modules do
    Enum.filter(@tool_modules, fn module ->
      case Map.fetch(@beta_tool_modules, module) do
        {:ok, feature} -> Beta.enabled?(feature)
        :error -> true
      end
    end)
  end

  defp find_tool_module(name) do
    Enum.find_value(tool_modules(), :error, fn module ->
      tool_names = Enum.map(module.tools(), & &1.name)

      if name in tool_names do
        {:ok, module}
      end
    end)
  end
end
