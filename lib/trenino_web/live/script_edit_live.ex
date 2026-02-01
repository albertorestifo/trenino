defmodule TreninoWeb.ScriptEditLive do
  @moduledoc """
  LiveView for editing Lua scripts attached to train configurations.

  Provides a code editor with monospace textarea, trigger management,
  hardware outputs reference, and a console showing script log output.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Script
  alias Trenino.Train.ScriptRunner

  @default_code """
  function on_change(event)
    -- event.source: trigger endpoint path, "scheduled", or "manual"
    -- event.value: current value of the trigger
    -- event.data: full data table from subscription
    print("triggered by: " .. tostring(event.source))
  end\
  """

  @impl true
  def mount(%{"train_id" => train_id_str, "script_id" => script_id_str}, _session, socket) do
    train_id = String.to_integer(train_id_str)
    script_id = String.to_integer(script_id_str)

    with {:ok, train} <- TrainContext.get_train(train_id),
         {:ok, script} <- TrainContext.get_script(script_id) do
      changeset = Script.changeset(script, %{})

      {:ok,
       socket
       |> assign(:train, train)
       |> assign(:script, script)
       |> assign(:new_mode, false)
       |> assign(:page_title, "Edit Script - #{script.name}")
       |> assign(:form, to_form(changeset))
       |> assign(:triggers, script.triggers)
       |> assign(:new_trigger, "")
       |> assign(:console_log, load_script_log(script.id))
       |> assign(:outputs, load_outputs())
       |> assign(:show_outputs, false)}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Not found")
         |> redirect(to: ~p"/trains")}
    end
  end

  @impl true
  def mount(%{"train_id" => train_id_str}, _session, socket) do
    train_id = String.to_integer(train_id_str)

    case TrainContext.get_train(train_id) do
      {:ok, train} ->
        script = %Script{train_id: train_id, code: String.trim(@default_code)}
        changeset = Script.changeset(script, %{})

        {:ok,
         socket
         |> assign(:train, train)
         |> assign(:script, script)
         |> assign(:new_mode, true)
         |> assign(:page_title, "New Script")
         |> assign(:form, to_form(changeset))
         |> assign(:triggers, [])
         |> assign(:new_trigger, "")
         |> assign(:console_log, [])
         |> assign(:outputs, load_outputs())
         |> assign(:show_outputs, false)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Train not found")
         |> redirect(to: ~p"/trains")}
    end
  end

  # Form validation
  @impl true
  def handle_event("validate", %{"script" => params}, socket) do
    params = Map.put(params, "triggers", socket.assigns.triggers)

    changeset =
      socket.assigns.script
      |> Script.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Save script
  @impl true
  def handle_event("save", %{"script" => params}, socket) do
    params = Map.put(params, "triggers", socket.assigns.triggers)
    save_script(socket, params)
  end

  # Trigger management
  @impl true
  def handle_event("update_new_trigger", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_trigger, value)}
  end

  @impl true
  def handle_event("add_trigger", _params, socket) do
    trigger = String.trim(socket.assigns.new_trigger)

    if trigger != "" and trigger not in socket.assigns.triggers do
      triggers = socket.assigns.triggers ++ [trigger]
      {:noreply, socket |> assign(:triggers, triggers) |> assign(:new_trigger, "")}
    else
      {:noreply, assign(socket, :new_trigger, "")}
    end
  end

  @impl true
  def handle_event("remove_trigger", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    triggers = List.delete_at(socket.assigns.triggers, index)
    {:noreply, assign(socket, :triggers, triggers)}
  end

  # Toggle enabled
  @impl true
  def handle_event("toggle_enabled", _params, socket) do
    if socket.assigns.new_mode do
      {:noreply, socket}
    else
      script = socket.assigns.script
      new_enabled = !script.enabled

      case TrainContext.update_script(script, %{enabled: new_enabled}) do
        {:ok, updated} ->
          ScriptRunner.reload_scripts()

          {:noreply,
           socket
           |> assign(:script, updated)
           |> put_flash(:info, if(new_enabled, do: "Script enabled", else: "Script disabled"))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update script")}
      end
    end
  end

  # Run script manually
  @impl true
  def handle_event("run_now", _params, socket) do
    if socket.assigns.new_mode do
      {:noreply, put_flash(socket, :error, "Save the script first")}
    else
      ScriptRunner.run_script(socket.assigns.script.id)
      Process.send_after(self(), :refresh_log, 300)
      {:noreply, put_flash(socket, :info, "Script triggered")}
    end
  end

  # Refresh console log
  @impl true
  def handle_event("refresh_log", _params, socket) do
    {:noreply, assign(socket, :console_log, load_log(socket))}
  end

  # Toggle outputs reference panel
  @impl true
  def handle_event("toggle_outputs", _params, socket) do
    {:noreply, assign(socket, :show_outputs, !socket.assigns.show_outputs)}
  end

  @impl true
  def handle_info(:refresh_log, socket) do
    {:noreply, assign(socket, :console_log, load_log(socket))}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Private helpers

  defp save_script(socket, params) do
    if socket.assigns.new_mode do
      case TrainContext.create_script(socket.assigns.train.id, atomize_params(params)) do
        {:ok, script} ->
          ScriptRunner.reload_scripts()

          {:noreply,
           socket
           |> put_flash(:info, "Script created")
           |> push_navigate(to: ~p"/trains/#{socket.assigns.train.id}/scripts/#{script.id}")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:form, to_form(Map.put(changeset, :action, :validate)))
           |> put_flash(:error, "Failed to create script")}
      end
    else
      case TrainContext.update_script(socket.assigns.script, atomize_params(params)) do
        {:ok, updated} ->
          ScriptRunner.reload_scripts()
          changeset = Script.changeset(updated, %{})

          {:noreply,
           socket
           |> assign(:script, updated)
           |> assign(:form, to_form(changeset))
           |> put_flash(:info, "Script saved")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:form, to_form(Map.put(changeset, :action, :validate)))
           |> put_flash(:error, "Failed to save script")}
      end
    end
  end

  defp atomize_params(params) do
    params
    |> Map.take(["name", "enabled", "code", "triggers"])
    |> Enum.reduce(%{}, fn
      {"name", v}, acc -> Map.put(acc, :name, v)
      {"enabled", v}, acc -> Map.put(acc, :enabled, v)
      {"code", v}, acc -> Map.put(acc, :code, v)
      {"triggers", v}, acc -> Map.put(acc, :triggers, v)
      _, acc -> acc
    end)
  end

  defp load_outputs do
    Hardware.list_configurations(preload: [:outputs])
    |> Enum.flat_map(fn device ->
      Enum.map(device.outputs, fn output ->
        %{id: output.id, name: output.name, pin: output.pin, device_name: device.name}
      end)
    end)
  end

  defp load_log(socket) do
    if socket.assigns.new_mode, do: [], else: load_script_log(socket.assigns.script.id)
  end

  defp load_script_log(script_id) do
    ScriptRunner.get_script_log(script_id)
  rescue
    _ -> []
  catch
    :exit, _ -> []
  end

  # Template

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Trains", path: ~p"/trains"},
      %{label: @train.name, path: ~p"/trains/#{@train.id}"},
      %{label: if(@new_mode, do: "New Script", else: @script.name)}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-4xl mx-auto">
        <.form for={@form} id="script-form" phx-change="validate" phx-submit="save">
          <%!-- Header bar: name, actions --%>
          <div class="flex items-center gap-3 mb-6">
            <div class="flex-1">
              <.input
                field={@form[:name]}
                type="text"
                placeholder="Script name"
                class="input input-bordered w-full text-lg font-semibold"
              />
            </div>

            <div :if={not @new_mode} class="flex items-center gap-2">
              <label class="label cursor-pointer gap-2">
                <span class={[
                  "text-sm font-medium",
                  if(@script.enabled, do: "text-success", else: "text-base-content/50")
                ]}>
                  {if @script.enabled, do: "Enabled", else: "Disabled"}
                </span>
                <input
                  type="checkbox"
                  class="toggle toggle-sm toggle-success"
                  checked={@script.enabled}
                  phx-click="toggle_enabled"
                />
              </label>
            </div>

            <button
              :if={not @new_mode}
              type="button"
              phx-click="run_now"
              class="btn btn-outline btn-sm"
              title="Run script manually"
            >
              <.icon name="hero-play" class="w-4 h-4" /> Run
            </button>

            <button type="submit" class="btn btn-primary btn-sm">
              <.icon name="hero-check" class="w-4 h-4" />
              {if @new_mode, do: "Create", else: "Save"}
            </button>

            <.link navigate={~p"/trains/#{@train.id}"} class="btn btn-ghost btn-sm">
              Back
            </.link>
          </div>

          <%!-- Code editor --%>
          <div class="bg-base-200/50 rounded-xl p-4 mb-4">
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-sm font-semibold text-base-content/70">Lua Code</h3>
            </div>
            <.input
              field={@form[:code]}
              type="textarea"
              rows="18"
              spellcheck="false"
              phx-debounce="blur"
              class="w-full font-mono text-sm leading-relaxed p-4 rounded-lg bg-base-300 text-base-content border border-base-content/10 focus:border-primary/50 focus:outline-none resize-y min-h-[200px]"
            />
          </div>
        </.form>

        <%!-- Triggers --%>
        <div class="bg-base-200/50 rounded-xl p-4 mb-4">
          <h3 class="text-sm font-semibold text-base-content/70 mb-3">
            Triggers
            <span class="text-xs font-normal text-base-content/40 ml-1">
              Simulator endpoints that fire on_change when their value changes
            </span>
          </h3>

          <div class="flex flex-wrap gap-2 mb-3">
            <div
              :for={{trigger, index} <- Enum.with_index(@triggers)}
              class="flex items-center gap-1 bg-base-300 rounded-lg px-3 py-1.5"
            >
              <span class="font-mono text-xs">{trigger}</span>
              <button
                type="button"
                phx-click="remove_trigger"
                phx-value-index={index}
                class="text-base-content/40 hover:text-error ml-1"
                title="Remove trigger"
              >
                <.icon name="hero-x-mark" class="w-3 h-3" />
              </button>
            </div>

            <div
              :if={Enum.empty?(@triggers)}
              class="text-sm text-base-content/40 py-1"
            >
              No triggers added. Script will only run when triggered manually.
            </div>
          </div>

          <form phx-submit="add_trigger" class="flex gap-2">
            <input
              type="text"
              name="value"
              value={@new_trigger}
              phx-change="update_new_trigger"
              placeholder="e.g. CurrentDrivableActor/Throttle.InputValue"
              class={[
                "flex-1 input input-bordered input-sm font-mono text-xs",
                "bg-base-100"
              ]}
            />
            <button type="submit" class="btn btn-outline btn-sm">
              <.icon name="hero-plus" class="w-3 h-3" /> Add
            </button>
          </form>
        </div>

        <%!-- Console --%>
        <div :if={not @new_mode} class="bg-base-200/50 rounded-xl p-4 mb-4">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-semibold text-base-content/70">Console</h3>
            <button type="button" phx-click="refresh_log" class="btn btn-ghost btn-xs">
              <.icon name="hero-arrow-path" class="w-3 h-3" /> Refresh
            </button>
          </div>

          <div
            id="script-console"
            class={[
              "font-mono text-xs leading-relaxed p-3 rounded-lg",
              "bg-base-300 text-base-content/80",
              "h-40 overflow-y-auto"
            ]}
          >
            <%= if Enum.empty?(@console_log) do %>
              <span class="text-base-content/30">
                No log output yet. Run the script to see output.
              </span>
            <% else %>
              <div
                :for={line <- Enum.reverse(@console_log)}
                class={[
                  "py-0.5",
                  String.starts_with?(line, "[error]") && "text-error"
                ]}
              >
                {line}
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Outputs reference (collapsible) --%>
        <div class="bg-base-200/50 rounded-xl p-4 mb-4">
          <button
            type="button"
            phx-click="toggle_outputs"
            class="flex items-center justify-between w-full"
          >
            <h3 class="text-sm font-semibold text-base-content/70">
              Hardware Outputs Reference
              <span class="text-xs font-normal text-base-content/40 ml-1">
                Use output.set(id, true/false) in your script
              </span>
            </h3>
            <.icon
              name={if @show_outputs, do: "hero-chevron-up", else: "hero-chevron-down"}
              class="w-4 h-4 text-base-content/40"
            />
          </button>

          <div :if={@show_outputs} class="mt-3">
            <%= if Enum.empty?(@outputs) do %>
              <p class="text-sm text-base-content/40">No hardware outputs configured.</p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-xs bg-base-100 rounded-lg">
                  <thead>
                    <tr class="bg-base-200 text-xs">
                      <th>ID</th>
                      <th>Name</th>
                      <th>Pin</th>
                      <th>Device</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={output <- @outputs} class="text-xs">
                      <td class="font-mono">{output.id}</td>
                      <td>{output.name || "-"}</td>
                      <td class="font-mono">{output.pin}</td>
                      <td class="text-base-content/60">{output.device_name}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </main>
    """
  end
end
