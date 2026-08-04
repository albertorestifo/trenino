defmodule TreninoWeb.VirtualJoystickLive do
  @moduledoc false
  use TreninoWeb, :live_view

  import TreninoWeb.Live.Components.VirtualJoystickMappingForm

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection
  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.Platform
  alias Trenino.VirtualJoystick.Mapper

  @axes [
    {:x, "X"},
    {:y, "Y"},
    {:z, "Z"},
    {:rx, "Rx"},
    {:ry, "Ry"},
    {:rz, "Rz"},
    {:slider_1, "Slider 1"},
    {:slider_2, "Slider 2"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    details =
      if Platform.windows?() and Process.whereis(VirtualJoystick.Manager),
        do: VirtualJoystick.status_details(),
        else: %{status: :unsupported, reason: nil}

    if connected?(socket) and Platform.windows?(), do: VirtualJoystick.subscribe()

    {:ok,
     socket
     |> assign(:status, details.status)
     |> assign(:status_reason, details.reason)
     |> assign(:axes, @axes)
     |> assign(:mappings, VirtualJoystick.list_mappings())
     |> assign(
       :inputs,
       Hardware.list_all_inputs(include_uncalibrated: true, include_virtual_buttons: true)
     )
     |> assign(:mapping_kind, nil)
     |> assign(:editing_mapping, nil)
     |> assign(:preview, nil)
     |> assign(:preview_source, nil)
     |> assign(:confirm_transition, false)
     |> assign(:pending_replacement, nil)
     |> assign(:mapping_error, nil)}
  end

  @impl true
  def handle_info({:virtual_joystick_status_changed, status}, socket),
    do: {:noreply, assign(socket, :status, status)}

  def handle_info({:virtual_joystick_status_details_changed, details}, socket),
    do: {:noreply, assign(socket, status: details.status, status_reason: details.reason)}

  def handle_info({:input_value_updated, port, pin, raw}, socket) when is_number(raw) do
    case socket.assigns.preview_source do
      %{port: expected_port, input: %{pin: ^pin} = input}
      when not is_nil(expected_port) and expected_port == port ->
        {:noreply, assign(socket, :preview, preview_value(input, raw))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:virtual_joystick_destination_conflict, input_id, attrs}, socket) do
    {:noreply, assign(socket, :pending_replacement, {input_id, attrs})}
  end

  def handle_info({:devices_updated, devices}, socket) do
    subscribe_connected_ports(devices)

    {:noreply,
     socket
     |> assign(:nav_devices, devices)
     |> refresh_preview_port(devices)}
  end

  def handle_info({:simulator_status_changed, status}, socket),
    do: {:noreply, assign(socket, :nav_simulator_status, status)}

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("show-transition-confirmation", _, socket),
    do: {:noreply, assign(socket, :confirm_transition, true)}

  def handle_event("cancel-transition", _, socket),
    do: {:noreply, assign(socket, :confirm_transition, false)}

  def handle_event("confirm-transition", _, socket) do
    action =
      if socket.assigns.status == :active,
        do: &VirtualJoystick.disable/0,
        else: &VirtualJoystick.enable/0

    _ = action.()
    {:noreply, assign(socket, :confirm_transition, false)}
  end

  def handle_event("recover", _, socket) do
    _ =
      cond do
        socket.assigns.status == :needs_cleanup ->
          VirtualJoystick.remove_leftover()

        socket.assigns.status == :error and
            socket.assigns.status_reason in [:driver_missing, :incompatible] ->
          VirtualJoystick.repair()

        true ->
          VirtualJoystick.retry()
      end

    {:noreply, socket}
  end

  def handle_event(event, _, %{assigns: %{status: status}} = socket)
      when event in [
             "add-axis",
             "add-button",
             "edit-mapping",
             "delete-mapping",
             "save-mapping",
             "confirm-replacement"
           ] and
             status in [:enabling, :disabling],
      do: {:noreply, socket}

  def handle_event("add-axis", _, socket), do: {:noreply, open_form(socket, :axis, nil)}
  def handle_event("add-button", _, socket), do: {:noreply, open_form(socket, :button, nil)}
  def handle_event("cancel-mapping", _, socket), do: {:noreply, close_form(socket)}

  def handle_event("cancel-replacement", _, socket),
    do: {:noreply, assign(socket, :pending_replacement, nil)}

  def handle_event("edit-mapping", %{"id" => id}, socket) do
    mapping = Enum.find(socket.assigns.mappings, &(&1.id == String.to_integer(id)))
    {:noreply, open_form(socket, mapping.target_type, mapping)}
  end

  def handle_event("select-mapping-input", %{"mapping" => %{"input_id" => id}}, socket) do
    {:noreply, select_preview_source(socket, String.to_integer(id))}
  end

  def handle_event("cancel-dialog", %{"key" => "Escape"}, socket) do
    {:noreply,
     socket
     |> assign(:confirm_transition, false)
     |> assign(:pending_replacement, nil)
     |> close_form()}
  end

  def handle_event("delete-mapping", %{"id" => id}, socket) do
    {:ok, _} = VirtualJoystick.delete_mapping(String.to_integer(id))
    VirtualJoystick.reload_mappings()
    {:noreply, socket |> assign(:mappings, VirtualJoystick.list_mappings()) |> close_form()}
  end

  def handle_event("save-mapping", %{"mapping" => params}, socket) do
    input_id = String.to_integer(params["input_id"])
    attrs = mapping_attrs(params)

    case VirtualJoystick.put_mapping(input_id, attrs) do
      {:ok, _} ->
        VirtualJoystick.reload_mappings()
        {:noreply, socket |> assign(:mappings, VirtualJoystick.list_mappings()) |> close_form()}

      {:error, :destination_conflict} ->
        {:noreply, assign(socket, :pending_replacement, {input_id, attrs})}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, assign(socket, :mapping_error, "That joystick target is already assigned.")}

      {:error, reason} ->
        {:noreply,
         assign(socket, :mapping_error, "Mapping could not be saved: #{inspect(reason)}")}
    end
  end

  def handle_event(
        "confirm-replacement",
        _,
        %{assigns: %{pending_replacement: {input_id, attrs}}} = socket
      ) do
    case VirtualJoystick.put_mapping(input_id, attrs, replace?: true) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:mappings, VirtualJoystick.list_mappings())
         |> assign(:pending_replacement, nil)
         |> close_form()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:pending_replacement, nil)
         |> assign(:mapping_error, "Mapping could not be saved: #{inspect(reason)}")}
    end
  end

  def handle_event("nav_toggle_dropdown", _, socket),
    do: {:noreply, assign(socket, :nav_dropdown_open, !socket.assigns.nav_dropdown_open)}

  def handle_event("nav_close_dropdown", _, socket),
    do: {:noreply, assign(socket, :nav_dropdown_open, false)}

  def handle_event("nav_scan_devices", _, socket),
    do:
      (
        Connection.scan()
        {:noreply, assign(socket, :nav_scanning, true)}
      )

  def handle_event("nav_disconnect_device", %{"port" => port}, socket),
    do:
      (
        Connection.disconnect(port)
        {:noreply, socket}
      )

  def handle_event("nav_retry_simulator", _, socket),
    do:
      (
        Trenino.Simulator.retry_connection()
        {:noreply, socket}
      )

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :status_ui, status_ui(assigns.status, assigns.status_reason))
    assigns = assign(assigns, :transitioning, assigns.status in [:enabling, :disabling])

    ~H"""
    <main class="flex-1 p-4 sm:p-8">
      <div class="mx-auto max-w-2xl">
        <header class="mb-8">
          <h1 class="text-2xl font-semibold">Virtual joystick</h1>
          <p class="mt-2 max-w-prose text-sm text-base-content/70">
            Send selected hardware controls to games as one standard Windows joystick.
          </p>
        </header>

        <section class="rounded-xl border border-base-300 bg-base-200/50 p-5">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p class="text-xs uppercase tracking-wide text-base-content/60">Status</p>
              <p
                data-testid="virtual-joystick-status"
                aria-live="polite"
                class="mt-1 text-lg font-semibold"
              >
                {@status_ui.label}
              </p>
              <p class="mt-1 text-sm text-base-content/70">{@status_ui.help}</p>
            </div>
            <button
              data-testid="virtual-joystick-toggle"
              phx-click="show-transition-confirmation"
              disabled={is_nil(@status_ui.toggle)}
              class="btn btn-primary"
            >
              {@status_ui.toggle || @status_ui.label}
            </button>
          </div>
          <button
            :if={@status_ui.recovery}
            data-testid="virtual-joystick-recovery"
            phx-click="recover"
            class="btn btn-outline mt-4"
          >{@status_ui.recovery}</button>
        </section>

        <p :if={@mapping_error} role="alert" class="alert alert-error mt-5">{@mapping_error}</p>

        <section class="mt-8">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold">Axes</h2><button
              data-testid="add-axis-mapping"
              phx-click="add-axis"
              disabled={@transitioning}
              class="btn btn-sm btn-outline"
            >Add axis</button>
          </div>
          <div class="mt-3 divide-y divide-base-300 rounded-xl border border-base-300">
            <div
              :for={{axis, label} <- @axes}
              data-testid={"axis-mapping-#{axis}"}
              class="flex min-h-12 items-center justify-between gap-3 px-4 py-3"
            >
              <span class="font-medium">{label}</span><.mapping_value
                mapping={find_axis(@mappings, axis)}
                transitioning={@transitioning}
              />
            </div>
          </div>
        </section>

        <section class="mt-8">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold">Buttons</h2><button
              data-testid="add-button-mapping"
              phx-click="add-button"
              disabled={@transitioning}
              class="btn btn-sm btn-outline"
            >Add button</button>
          </div>
          <div class="mt-3 grid grid-cols-1 gap-px overflow-hidden rounded-xl border border-base-300 bg-base-300 sm:grid-cols-2">
            <div
              :for={number <- 1..32}
              data-testid="button-target-option"
              class="flex min-h-11 items-center justify-between bg-base-100 px-4 py-2"
            >
              <span>Button {number}</span><.mapping_value
                mapping={find_button(@mappings, number)}
                transitioning={@transitioning}
              />
            </div>
          </div>
        </section>
      </div>

      <.mapping_form
        :if={@mapping_kind}
        kind={@mapping_kind}
        inputs={compatible_inputs(@inputs, @mapping_kind)}
        mapping={@editing_mapping}
        preview={@preview}
        selected_input_id={selected_input_id(@preview_source)}
        transitioning={@transitioning}
      />

      <div
        :if={@confirm_transition}
        class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="transition-title"
        phx-window-keydown="cancel-dialog"
        phx-key="Escape"
        phx-mounted={JS.push_focus() |> JS.focus_first()}
        phx-remove={JS.pop_focus()}
      >
        <.focus_wrap
          id="transition-dialog-focus"
          class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl"
        >
          <h2 id="transition-title" tabindex="-1" class="text-lg font-semibold">
            {if @status == :active, do: "Disable virtual joystick?", else: "Enable virtual joystick?"}
          </h2><p class="mt-3 text-sm">
            Windows will request administrator permission to change the virtual joystick device.
          </p><div class="mt-6 flex justify-end gap-2">
            <button
              data-testid="cancel-transition"
              phx-click="cancel-transition"
              class="btn btn-ghost"
            >Cancel</button><button phx-click="confirm-transition" class="btn btn-primary">Continue</button>
          </div>
        </.focus_wrap>
      </div>

      <div
        :if={@pending_replacement}
        class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="replacement-title"
        phx-window-keydown="cancel-dialog"
        phx-key="Escape"
        phx-mounted={JS.push_focus() |> JS.focus_first()}
        phx-remove={JS.pop_focus()}
      >
        <.focus_wrap
          id="replacement-dialog-focus"
          class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl"
        >
          <h2 id="replacement-title" tabindex="-1" class="text-lg font-semibold">
            Replace existing binding?
          </h2><p class="mt-3 text-sm">
            This input already controls a simulator or API binding. Replacing it will move the input to the virtual joystick.
          </p><div class="mt-6 flex justify-end gap-2">
            <button
              data-testid="cancel-replacement"
              phx-click="cancel-replacement"
              class="btn btn-ghost"
            >Cancel</button><button
              data-testid="confirm-replacement"
              phx-click="confirm-replacement"
              disabled={@transitioning}
              class="btn btn-primary"
            >Replace binding</button>
          </div>
        </.focus_wrap>
      </div>
    </main>
    """
  end

  attr :mapping, :any, required: true
  attr :transitioning, :boolean, default: false

  defp mapping_value(assigns) do
    ~H"""
    <span :if={is_nil(@mapping)} class="text-sm text-base-content/50">Not assigned</span>
    <span :if={@mapping} class="flex items-center gap-2 text-sm"><span>{@mapping.input.name ||
      "Pin #{@mapping.input.pin}"}{if @mapping.inverted, do: " · Inverted"}</span><button
      id={"edit-mapping-#{@mapping.id}"}
      data-testid={"edit-mapping-#{@mapping.id}"}
      phx-click="edit-mapping"
      phx-value-id={@mapping.id}
      disabled={@transitioning}
      class="btn btn-ghost btn-xs"
    >Edit</button><button
      id={"delete-mapping-#{@mapping.id}"}
      data-testid={"delete-mapping-#{@mapping.id}"}
      phx-click="delete-mapping"
      phx-value-id={@mapping.id}
      disabled={@transitioning}
      class="btn btn-ghost btn-xs"
    >Delete</button></span>
    """
  end

  defp open_form(socket, kind, mapping) do
    subscribe_connected_ports(Connection.list_devices())

    inputs = compatible_inputs(socket.assigns.inputs, kind)

    selected =
      if mapping, do: mapping.input_id, else: inputs |> List.first() |> then(&(&1 && &1.id))

    socket
    |> assign(:mapping_kind, kind)
    |> assign(:editing_mapping, mapping)
    |> assign(:preview, nil)
    |> assign(:mapping_error, nil)
    |> select_preview_source(selected)
  end

  defp close_form(socket),
    do:
      socket
      |> assign(:mapping_kind, nil)
      |> assign(:editing_mapping, nil)
      |> assign(:preview, nil)
      |> assign(:preview_source, nil)

  defp compatible_inputs(inputs, :axis), do: Enum.filter(inputs, &(&1.input_type == :analog))
  defp compatible_inputs(inputs, :button), do: Enum.filter(inputs, &(&1.input_type == :button))

  defp find_axis(mappings, axis),
    do: Enum.find(mappings, &(&1.target_type == :axis and &1.axis == axis))

  defp find_button(mappings, button),
    do: Enum.find(mappings, &(&1.target_type == :button and &1.button == button))

  defp mapping_attrs(%{"target_type" => "axis"} = params),
    do: %{
      target_type: :axis,
      axis: String.to_existing_atom(params["axis"]),
      inverted: params["inverted"] == "true"
    }

  defp mapping_attrs(%{"target_type" => "button"} = params),
    do: %{target_type: :button, button: String.to_integer(params["button"]), inverted: false}

  defp status_ui(:unsupported, _reason),
    do: %{
      label: "Unavailable",
      help: "Virtual joystick mode requires Windows 10 or 11.",
      toggle: nil,
      recovery: nil
    }

  defp status_ui(:off, :uac_cancelled),
    do: %{
      label: "Off",
      help: "Permission was cancelled. Virtual joystick remains off. No change was made.",
      toggle: "Enable",
      recovery: nil
    }

  defp status_ui(:off, _reason),
    do: %{
      label: "Off",
      help: "No virtual joystick device is installed.",
      toggle: "Enable",
      recovery: nil
    }

  defp status_ui(:enabling, :uac_cancelled),
    do: %{
      label: "Turning on",
      help: "Permission was cancelled. No change was made.",
      toggle: nil,
      recovery: nil
    }

  defp status_ui(:enabling, _reason),
    do: %{
      label: "Turning on",
      help: "You can cancel the Windows prompt. No change will be made.",
      toggle: nil,
      recovery: nil
    }

  defp status_ui(:active, _reason),
    do: %{
      label: "On",
      help: "Mapped controls are being sent to joystick device 1.",
      toggle: "Disable",
      recovery: nil
    }

  defp status_ui(:disabling, _reason),
    do: %{
      label: "Turning off",
      help: "Removing the virtual joystick device.",
      toggle: nil,
      recovery: nil
    }

  defp status_ui(:needs_setup, :uac_cancelled),
    do: %{
      label: "Setup needed",
      help: "Permission was cancelled. No change was made.",
      toggle: nil,
      recovery: "Retry"
    }

  defp status_ui(:needs_setup, _reason),
    do: %{
      label: "Setup needed",
      help: "Windows did not finish creating the device.",
      toggle: nil,
      recovery: "Retry"
    }

  defp status_ui(:needs_cleanup, _reason),
    do: %{
      label: "Cleanup needed",
      help: "A leftover device must be removed.",
      toggle: nil,
      recovery: "Remove leftover device"
    }

  defp status_ui(:degraded, :uac_cancelled),
    do: %{
      label: "Connection interrupted",
      help: "Permission was cancelled. Restoring the virtual joystick without changing Windows.",
      toggle: nil,
      recovery: "Retry"
    }

  defp status_ui(:degraded, _reason),
    do: %{
      label: "Connection interrupted",
      help: "Trying to reconnect to the virtual joystick.",
      toggle: nil,
      recovery: "Retry"
    }

  defp status_ui(:error, :driver_missing),
    do: %{
      label: "Needs attention",
      help: "The vJoy driver is missing. Repair the Trenino installation, then check again.",
      toggle: nil,
      recovery: "Check installation"
    }

  defp status_ui(:error, :incompatible),
    do: %{
      label: "Needs attention",
      help:
        "Device 1 has incompatible controls. Correct its vJoy configuration, then check again.",
      toggle: nil,
      recovery: "Check configuration"
    }

  defp status_ui(:error, _reason),
    do: %{
      label: "Needs attention",
      help: "The virtual joystick could not be started.",
      toggle: nil,
      recovery: "Retry"
    }

  defp select_preview_source(socket, nil), do: assign(socket, :preview_source, nil)

  defp select_preview_source(socket, input_id) do
    input = Enum.find(socket.assigns.inputs, &(&1.id == input_id))
    port = input && port_for_input(input)
    assign(socket, preview_source: input && %{input: input, port: port}, preview: nil)
  end

  defp port_for_input(input) do
    port_for_input(input, Connection.list_devices())
  end

  defp port_for_input(input, devices) do
    Enum.find_value(devices, fn device ->
      if device.status == :connected and device.device_config_id == input.device.config_id,
        do: device.port
    end)
  end

  defp subscribe_connected_ports(devices) do
    Enum.each(devices, fn device ->
      if device.status == :connected, do: ConfigurationManager.subscribe_input_values(device.port)
    end)
  end

  defp refresh_preview_port(%{assigns: %{preview_source: nil}} = socket, _devices), do: socket

  defp refresh_preview_port(socket, devices) do
    input = socket.assigns.preview_source.input

    assign(socket,
      preview_source: %{input: input, port: port_for_input(input, devices)},
      preview: nil
    )
  end

  defp preview_value(%{input_type: :analog, calibration: calibration}, raw) do
    case Mapper.axis_value(raw, calibration, false, {0, 100}) do
      {:ok, percent} -> "#{percent}%"
      _ -> "Unavailable"
    end
  end

  defp preview_value(%{input_type: :button}, raw),
    do: if(raw == 0, do: "Released", else: "Pressed")

  defp selected_input_id(nil), do: nil
  defp selected_input_id(%{input: input}), do: input.id
end
