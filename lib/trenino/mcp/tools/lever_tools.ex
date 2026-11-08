defmodule Trenino.MCP.Tools.LeverTools do
  @moduledoc """
  MCP tools for setting up lever elements.

  They run the same steps as the Lever Setup Wizard (`Trenino.Train.LeverSetup`):
  find the simulator lever, link it, calibrate it, bind a hardware input. The
  last step, mapping the physical lever's notches, needs the user in the
  wizard; `open_lever_setup` takes them there.
  """

  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Simulator.ControlDetector
  alias Trenino.Simulator.LeverMetadata
  alias Trenino.Simulator.LeverMetadata.Label
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.{Element, LeverConfig, LeverInputBinding, LeverSetup, Notch, NotchDesign}
  alias Trenino.UINavigation

  @tool_names ~w(list_simulator_levers get_lever set_lever_endpoint calibrate_lever
                 bind_lever_input open_lever_setup)

  @element_id %{type: "integer", description: "Lever element ID from list_elements"}

  def tools do
    [
      %{
        name: "list_simulator_levers",
        description:
          "List the levers of the train loaded in the simulator, read without moving them. " <>
            "Each lever has its control_path, its in-game role (for example 'Throttle', " <>
            "'Reverser', 'AutomaticBrake', 'IndependentBrake', 'DynamicBrake'), its notch " <>
            "count and the names the game shows for its positions. Pass 'match' with the " <>
            "element's name to get the best candidates first. Twin-cab trains list each " <>
            "control twice ('_F' front, '_B' rear); use the front cab unless told otherwise.",
        input_schema: %{
          type: "object",
          properties: %{
            match: %{
              type: "string",
              description: "Element name to rank levers by, e.g. 'Throttle' or 'Train brake'"
            }
          }
        }
      },
      %{
        name: "get_lever",
        description:
          "Get a lever element's setup: its simulator control, notches, bound hardware input, " <>
            "and next_step (set_endpoint, calibrate, bind_input, map_notches or done) with " <>
            "the reason. Once calibrated, notch_disk_url opens the train-lever notch disk " <>
            "generator with a disk designed from the notches (gates are detents, Emergency " <>
            "and centre gates hold harder, ranges are smooth); give it to the user to " <>
            "print a matching physical notch disk.",
        input_schema: %{
          type: "object",
          properties: %{element_id: @element_id},
          required: ["element_id"]
        }
      },
      %{
        name: "set_lever_endpoint",
        description:
          "Link a lever element to a simulator lever (a control_path from " <>
            "list_simulator_levers, e.g. 'CurrentDrivableActor/Throttle_F'). Changing the " <>
            "control removes the old notches. Then run calibrate_lever.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: @element_id,
            control_path: %{type: "string", description: "Simulator lever path"}
          },
          required: ["element_id", "control_path"]
        }
      },
      %{
        name: "calibrate_lever",
        description:
          "Sweep the lever's simulator control and save its notches, named from the game. " <>
            "IMPORTANT: this moves the lever in the game and can apply power. Ask the user " <>
            "first, and have the train stopped with the train brake applied. It refuses to " <>
            "start while the train moves and stops if the train speeds up; the lever is put " <>
            "back where it was. Takes up to a minute. Read the returned warnings to the user " <>
            "(for example a range blocked by the reverser, or a spring-loaded position).",
        input_schema: %{
          type: "object",
          properties: %{element_id: @element_id},
          required: ["element_id"]
        }
      },
      %{
        name: "bind_lever_input",
        description:
          "Bind a calibrated analog hardware input to a lever element. Get the input_id from " <>
            "detect_hardware_input (input_type 'analog') rather than asking the user. Input " <>
            "calibration is UI-only.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: @element_id,
            input_id: %{type: "integer", description: "Hardware input ID"}
          },
          required: ["element_id", "input_id"]
        }
      },
      %{
        name: "open_lever_setup",
        description:
          "Open the Lever Setup Wizard in the Trenino window for this lever, at the step it " <>
            "needs next (or the given step). Use it to hand over to the user, usually for " <>
            "map_notches, which needs the user to move their physical lever.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: @element_id,
            step: %{
              type: "string",
              enum: ["select_input", "find_endpoint", "map_notches"],
              description: "Wizard step to open (default: the lever's next step)"
            }
          },
          required: ["element_id"]
        }
      }
    ]
  end

  def execute("list_simulator_levers", args) do
    with_client(fn client ->
      case LeverMetadata.list_levers(client) do
        {:ok, levers} -> {:ok, list_result(levers, Map.get(args, "match"))}
        {:error, reason} -> {:error, "Simulator error: #{inspect(reason)}"}
      end
    end)
  end

  def execute("get_lever", %{"element_id" => element_id}) when is_integer(element_id) do
    lever_result(element_id)
  end

  def execute("set_lever_endpoint", %{"element_id" => element_id, "control_path" => path})
      when is_integer(element_id) and is_binary(path) do
    with_client(fn client ->
      with {:ok, %LeverMetadata{}} <- read_lever(client, path),
           {:ok, _config} <- LeverSetup.set_endpoint(element_id, path) do
        lever_result(element_id)
      else
        {:error, reason} -> {:error, error_message(reason, element_id)}
      end
    end)
  end

  def execute("calibrate_lever", %{"element_id" => element_id}) when is_integer(element_id) do
    with_client(fn client ->
      with {:ok, config} <- fetch_config(element_id),
           path when is_binary(path) <- LeverSetup.control_path(config),
           {:ok, %{analysis: analysis}} <-
             LeverSetup.calibrate(client, element_id, path, analyzer: [require_speed_guard: true]),
           {:ok, result} <- lever_result(element_id) do
        {:ok, Map.merge(result, %{lever_type: analysis.lever_type, warnings: analysis.warnings})}
      else
        nil -> {:error, error_message(:no_endpoint, element_id)}
        {:error, reason} -> {:error, error_message(reason, element_id)}
      end
    end)
  end

  def execute("bind_lever_input", %{"element_id" => element_id, "input_id" => input_id})
      when is_integer(element_id) and is_integer(input_id) do
    case LeverSetup.bind_input(element_id, input_id) do
      {:ok, %LeverInputBinding{}} -> lever_result(element_id)
      {:error, reason} -> {:error, error_message(reason, element_id)}
    end
  end

  def execute("open_lever_setup", %{"element_id" => element_id} = args)
      when is_integer(element_id) do
    with {:ok, %Element{type: :lever} = element} <- TrainContext.get_element(element_id),
         {:ok, next, reason} <- LeverSetup.next_step(element_id),
         {:ok, step} <- link_step(Map.get(args, "step"), next) do
      path = LeverSetup.ui_path(element, step)

      case UINavigation.request(path) do
        :ok ->
          {:ok,
           %{
             window_notified: true,
             ui_path: path,
             step: step,
             next_step: next,
             reason: reason,
             message:
               "The Trenino window was asked to open the lever setup. If the simulator is " <>
                 "not connected it shows an error instead; ask the user what they see."
           }}

        {:error, :no_window} ->
          {:ok,
           %{
             window_notified: false,
             ui_path: path,
             step: step,
             message:
               "No Trenino window is open. Ask the user to open Trenino, go to the train, " <>
                 "and click Configure on the lever."
           }}
      end
    else
      {:ok, %Element{}} -> {:error, error_message(:not_a_lever, element_id)}
      {:error, reason} -> {:error, error_message(reason, element_id)}
    end
  end

  def execute(name, _args) when name in @tool_names,
    do: {:error, "Missing or invalid arguments for #{name}; check the tool's schema."}

  # ---------------------------------------------------------------------------

  @link_steps ~w(select_input find_endpoint map_notches)

  defp link_step(nil, next), do: {:ok, Atom.to_string(LeverSetup.wizard_step(next))}
  defp link_step(step, _next) when step in @link_steps, do: {:ok, step}
  defp link_step(_step, _next), do: {:error, :invalid_step}

  defp list_result(levers, match) when is_binary(match) and match != "" do
    suggestions = ControlDetector.rank_levers(levers, match, 5)

    %{
      levers: Enum.map(levers, &serialize_lever/1),
      best_matches:
        Enum.map(suggestions, fn %{lever: lever, score: score} ->
          %{control_path: lever.control_path, role: lever.role, score: score}
        end)
    }
  end

  defp list_result(levers, _match), do: %{levers: Enum.map(levers, &serialize_lever/1)}

  defp serialize_lever(%LeverMetadata{} = lever) do
    %{
      control_path: lever.control_path,
      role: lever.role,
      notch_count: lever.notch_count,
      input_range: [lever.input_min, lever.input_max],
      output_range: [lever.output_min, lever.output_max],
      current: %{
        input: lever.current_input,
        output: lever.current_output,
        notch_index: lever.current_notch_index
      },
      positions: Enum.map(lever.labels, &serialize_label/1)
    }
  end

  defp serialize_label(%Label{} = label) do
    %{name: label.name, source: label.source, range: [label.min, label.max]}
  end

  defp lever_result(element_id) do
    with {:ok, %Element{type: :lever} = element} <-
           TrainContext.get_element(element_id,
             preload: [lever_config: [:notches, input_binding: [input: :device]]]
           ),
         {:ok, next, reason} <- LeverSetup.next_step(element_id) do
      {:ok,
       %{
         lever: serialize_element(element),
         next_step: next,
         next_step_reason: reason,
         ui_path: LeverSetup.ui_path(element, LeverSetup.wizard_step(next))
       }}
    else
      {:ok, %Element{}} -> {:error, error_message(:not_a_lever, element_id)}
      {:error, reason} -> {:error, error_message(reason, element_id)}
    end
  end

  defp serialize_element(%Element{lever_config: config} = element) do
    %{
      element_id: element.id,
      train_id: element.train_id,
      name: element.name,
      control_path: LeverSetup.control_path(config),
      lever_type: config && config.lever_type,
      calibrated_at: config && config.calibrated_at,
      notches: serialize_notches(config),
      notch_disk_url: notch_disk_url(config, element.name),
      input: serialize_binding(config)
    }
  end

  defp notch_disk_url(%LeverConfig{notches: [_ | _]} = config, name) do
    case NotchDesign.generator_link(config, name) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp notch_disk_url(_config, _name), do: nil

  defp serialize_notches(%LeverConfig{notches: notches}) when is_list(notches) do
    notches
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&serialize_notch/1)
  end

  defp serialize_notches(_), do: []

  defp serialize_notch(%Notch{} = notch) do
    base = %{
      index: notch.index,
      name: notch.description,
      type: notch.type,
      sim_input: [notch.sim_input_min, notch.sim_input_max],
      hardware_mapped: is_number(notch.input_min) and is_number(notch.input_max)
    }

    case notch.type do
      :gate -> Map.put(base, :output, notch.value)
      :linear -> Map.put(base, :output, [notch.min_value, notch.max_value])
    end
  end

  defp serialize_binding(%LeverConfig{input_binding: %LeverInputBinding{input: input}})
       when not is_nil(input) do
    %{input_id: input.id, pin: input.pin, name: input.name, device: input.device.name}
  end

  defp serialize_binding(_), do: nil

  defp read_lever(client, path) do
    case LeverMetadata.read(client, path) do
      {:ok, lever} -> {:ok, lever}
      {:error, _} -> {:error, {:not_a_simulator_lever, path}}
    end
  end

  defp fetch_config(element_id) do
    case TrainContext.get_lever_config(element_id) do
      {:ok, config} -> {:ok, config}
      {:error, :not_found} -> {:error, :no_endpoint}
    end
  end

  defp with_client(fun) do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        fun.(client)

      _ ->
        {:error,
         "Simulator not connected. Ensure Train Sim World is running with External Interface enabled."}
    end
  end

  defp error_message(:not_found, id), do: "Element #{id} not found."
  defp error_message(:not_a_lever, id), do: "Element #{id} is not a lever."

  defp error_message(:no_endpoint, _id),
    do: "The lever is not linked to a simulator control. Call set_lever_endpoint first."

  defp error_message({:not_a_simulator_lever, path}, _id),
    do: "#{path} is not a lever in the loaded train. Use list_simulator_levers."

  defp error_message(:not_analog, _id),
    do: "That input is not analog. Levers need an analog input."

  defp error_message(:not_calibrated, _id),
    do: "That input is not calibrated. Ask the user to calibrate it on the Devices page first."

  defp error_message(:train_not_stopped, _id),
    do: "The train is moving. Ask the user to stop it, then try again."

  defp error_message(:train_moving, _id),
    do:
      "The train started moving, so calibration stopped and the lever was put back. Ask the " <>
        "user to apply the train brake or handbrake, then try again."

  defp error_message(:calibration_running, _id),
    do: "This lever is already being calibrated. Wait for it to finish."

  defp error_message(:insufficient_samples, _id),
    do: "The simulator returned too few readings. Make sure the user is in the cab."

  defp error_message(:invalid_step, _id),
    do: "step must be one of: select_input, find_endpoint, map_notches."

  defp error_message(:speed_unavailable, _id),
    do:
      "The train's speed could not be read, so calibration did not start. Ask the user to " <>
        "calibrate from the Lever Setup Wizard instead (open_lever_setup)."

  defp error_message(:position_unreadable, _id),
    do: "The lever's position could not be read, so calibration did not start. Try again."

  defp error_message(:destination_conflict, _id),
    do: "That input already drives another control. Pick a different input."

  defp error_message(%Ecto.Changeset{} = changeset, _id) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
      |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)

    "Validation failed: " <> errors
  end

  defp error_message(reason, _id), do: "Lever setup failed: #{inspect(reason)}"
end
