defmodule Trenino.MCP.Tools.StepperTools do
  @moduledoc "Stepper configuration and explicit, bounded commissioning tools."
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Hardware.StepperManager
  alias Trenino.MCP.Tools.GaugeSerialization, as: Serialization

  @operations %{
    "recommission_address" => :recommission_address,
    "recover" => :recover,
    "complete_commissioning" => :complete_commissioning,
    "home" => :home,
    "reference" => :reference,
    "move_to" => :move_to,
    "stop" => :stop,
    "release" => :release,
    "enable" => :enable,
    "jog" => :jog
  }
  def tools do
    [
      tool("list_stepper_axes", ["device_id"]),
      tool("get_stepper_axis_status", ["id"]),
      tool("create_stepper_axis", ["device_id", "name"]),
      tool("update_stepper_axis", ["id"]),
      tool("delete_stepper_axis", ["id"]),
      tool("control_stepper_axis", ["id", "operation"])
    ]
  end

  defp tool(name, required) do
    fields =
      Map.new(StepperAxis.__schema__(:fields), fn key -> {key, property(key)} end)

    properties =
      Map.merge(fields, %{
        device_id: %{type: "integer"},
        id: %{type: "integer"},
        operation: %{
          type: "string",
          enum:
            ~w(claim renew release_lease resume recover recommission_address complete_commissioning home reference move_to stop release enable jog)
        },
        lease_token: %{type: "string"},
        operation_token: %{type: "string"},
        position: %{type: "integer"},
        delta: %{type: "integer"},
        address: %{type: "integer", minimum: 96, maximum: 119},
        acknowledged: %{type: "boolean"}
      })

    %{
      name: name,
      description:
        "Configurable generic stepper axis. CRUD never moves. Firmware >=3.1.0. Control requires explicit claim; 60-second lease renews only explicitly. Mutations require unique operation_token; identical retries reuse admission, not motion. Home completion is assumed, never sensed. Release loses reference. ALLCALL 0x70 registration requires shield alone.",
      input_schema: %{type: "object", properties: properties, required: required}
    }
  end

  defp property(key) when key in [:reverse, :commissioned], do: %{type: "boolean"}

  defp property(key)
       when key in [
              :name,
              :driver,
              :mode,
              :idle_behavior,
              :host_loss_behavior,
              :reference_strategy,
              :startup_reference
            ],
       do: %{type: "string"}

  defp property(_), do: %{type: "integer"}

  def execute("list_stepper_axes", %{"device_id" => id}) when is_integer(id),
    do: {:ok, %{axes: Enum.map(Hardware.list_stepper_axes(id), &Serialization.axis/1)}}

  def execute("get_stepper_axis_status", %{"id" => id}) when is_integer(id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         do: {:ok, Serialization.status(StepperManager.snapshot(axis.device_id))}
  end

  def execute("create_stepper_axis", %{"device_id" => id} = args) when is_integer(id) do
    case Hardware.create_stepper_axis(id, Map.drop(args, ["id", "device_id"])) do
      {:ok, axis} -> {:ok, %{axis: Serialization.axis(axis)}}
      error -> Serialization.result(error)
    end
  end

  def execute("update_stepper_axis", %{"id" => id} = args) when is_integer(id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         {:ok, axis} <- Hardware.update_stepper_axis(axis, Map.drop(args, ["id", "device_id"])) do
      {:ok, %{axis: Serialization.axis(axis)}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("delete_stepper_axis", %{"id" => id}) when is_integer(id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         {:ok, _} <- Hardware.delete_stepper_axis(axis),
         do: {:ok, %{deleted: true}}
  end

  def execute("control_stepper_axis", %{"id" => id, "operation" => op} = args)
      when is_integer(id) do
    control(id, op, args) |> Serialization.result()
  end

  def execute(_, _), do: {:error, "Missing or invalid parameters"}
  defp control(id, "claim", _), do: StepperManager.claim_mcp_manual(id)
  defp control(id, "renew", args), do: StepperManager.renew_mcp_manual(id, args["lease_token"])

  defp control(id, "release_lease", args),
    do: StepperManager.release_manual(id, args["lease_token"])

  defp control(id, "resume", _), do: StepperManager.resume(id)

  defp control(id, op, args) do
    params =
      args
      |> Map.take(["position", "delta", "address", "acknowledged"])
      |> Map.new(fn {key, value} ->
        {%{
           "position" => :position,
           "delta" => :delta,
           "address" => :address,
           "acknowledged" => :acknowledged
         }[key], value}
      end)

    case @operations[op] do
      nil ->
        {:error, :invalid_operation}

      operation ->
        case StepperManager.command_once(
               id,
               operation,
               params,
               args["lease_token"],
               args["operation_token"]
             ) do
          {:ok, request} ->
            {:ok, axis} = Hardware.get_stepper_axis(id)

            {:ok,
             %{
               accepted: true,
               pending_request_id: if(is_integer(request), do: request, else: nil),
               outcome: if(is_atom(request), do: request, else: :pending),
               status: Serialization.status(StepperManager.snapshot(axis.device_id))
             }}

          error ->
            error
        end
    end
  end
end
