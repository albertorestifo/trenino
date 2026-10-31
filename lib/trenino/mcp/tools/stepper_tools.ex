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
  @config_fields StepperAxis.__schema__(:fields) --
                   [:id, :device_id, :commissioned, :inserted_at, :updated_at]
  @control_fields [
    :id,
    :operation,
    :lease_token,
    :operation_token,
    :position,
    :delta,
    :address,
    :acknowledged
  ]
  @next_steps "Saved only; the device is unchanged and nothing moved. Call apply_stepper_configuration, then re-align the needle by hand and re-assign the reference."
  @after_apply "Apply is asynchronous: poll get_stepper_axis_status until the lifecycle is awaiting_reference, then claim, align by hand and reference."

  def tools do
    [
      tool("list_stepper_axes", ["device_id"], [:device_id]),
      tool("get_stepper_axis_status", ["id"], [:id]),
      tool("create_stepper_axis", ["device_id", "name"], [:device_id | @config_fields]),
      tool("update_stepper_axis", ["id"], [:id | @config_fields]),
      tool("delete_stepper_axis", ["id"], [:id]),
      tool("apply_stepper_configuration", ["device_id"], [:device_id]),
      tool("control_stepper_axis", ["id", "operation"], @control_fields)
    ]
  end

  defp tool(name, required, property_keys) do
    properties = Map.new(property_keys, &{&1, property(&1)})

    %{
      name: name,
      description:
        "Configurable generic stepper axis. Defaults already match an X27.168 six-state motor on shield port 1 / 0x60, so create needs only device_id and name. CRUD never moves and does NOT reach the device: after create/update call apply_stepper_configuration (also never moves), then claim, reference, jog, complete_commissioning. Flipping `reverse` is a single update_stepper_axis; afterwards apply, re-align the needle and re-assign the reference. apply_stepper_configuration is never blocked; when the panel has a display at 0x70 the result carries a `warning` (unplug that display, apply with the shield alone, reconnect, apply again) - relay it to the user. Firmware >=3.1.0. Control requires explicit claim; 60-second lease renews only explicitly. An accepted move or home always finishes: if the lease expires meanwhile, expiry (and its Stop) waits until the axis is stationary, and only renew/stop/release_lease work in between. Status reports `lease` {owner, expires_in_ms, finishing_motion} per axis, or null. A refused claim/resume says who holds the lease and what to do. Every control_stepper_axis operation except claim, renew, release_lease and resume requires an operation_token that is unique per intended action; identical retries (same token and arguments) reuse the first outcome and do not move again, and only successful outcomes are remembered. Stop and release always go through, even past the 100 recorded operations per lease. recommission_address additionally needs `acknowledged: true` (the user confirmed the shield-only registration procedure). Home completion is assumed, never sensed. Release loses reference. ALLCALL 0x70 registration requires shield alone.",
      input_schema: %{type: "object", properties: properties, required: required}
    }
  end

  defp property(key) when key in [:reverse, :commissioned, :acknowledged],
    do: %{type: "boolean"}

  defp property(:operation) do
    %{
      type: "string",
      enum:
        ~w(claim renew release_lease resume recover recommission_address complete_commissioning home reference move_to stop release enable jog)
    }
  end

  defp property(key) when key in [:lease_token, :operation_token], do: %{type: "string"}
  defp property(:address), do: %{type: "integer", minimum: 96, maximum: 119}

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
      {:ok, %{axis: Serialization.axis(axis), next_steps: @next_steps}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("apply_stepper_configuration", %{"device_id" => id}) when is_integer(id) do
    case Hardware.apply_saved_configuration(id) do
      {:ok, config_id} ->
        {:ok,
         %{
           applying: true,
           config_id: config_id,
           warning: Hardware.allcall_warning(id),
           next_steps: @after_apply
         }}

      error ->
        Serialization.result(error)
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
