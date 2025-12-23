defmodule TswIoWeb.ApiExplorerComponent do
  @moduledoc """
  LiveComponent for browsing the TSW simulator API.

  Provides hierarchical navigation through the simulator's API tree,
  allowing users to browse, search, preview values, and select paths.

  ## Usage

      <.live_component
        module={TswIoWeb.ApiExplorerComponent}
        id="api-explorer"
        field={:min_endpoint}
        client={@simulator_client}
      />

  ## Events sent to parent

  - `{:api_explorer_select, field, path}` - When user selects a path
  - `{:api_explorer_close}` - When user closes the explorer
  - `{:api_explorer_auto_configure, endpoints}` - When user clicks "Configure All Endpoints" on a detected lever
  - `{:api_explorer_individual_selection}` - When user clicks "Choose Individual Endpoints"
  - `{:api_explorer_button_detected, detection}` - When user clicks "Use This Endpoint" on a detected button
  """

  use TswIoWeb, :live_component

  alias TswIo.Simulator.Client

  @impl true
  def update(%{client: %Client{} = client, field: field} = assigns, socket) do
    # Mode determines detection behavior: :lever, :button, or nil (auto-detect both)
    mode = Map.get(assigns, :mode)
    # Embedded mode means this component is inside another modal and shouldn't render its own wrapper
    embedded = Map.get(assigns, :embedded, false)

    socket =
      socket
      |> assign(:field, field)
      |> assign(:client, client)
      |> assign(:detection_mode, mode)
      |> assign(:embedded, embedded)

    # Initialize on first mount
    socket =
      if socket.assigns[:initialized] do
        socket
      else
        initialize_explorer(socket)
      end

    {:ok, socket}
  end

  def update(assigns, socket) do
    # Handle updates without client (shouldn't happen, but be safe)
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("navigate", %{"node" => node, "type" => "endpoint"}, socket) do
    # Endpoints are leaf nodes - preview their value directly using dot notation
    %{client: client, path: path} = socket.assigns

    full_path = build_full_path(path, node, :endpoint)

    case Client.get(client, full_path) do
      {:ok, response} ->
        {:noreply,
         socket
         |> assign(:preview, %{path: full_path, value: response})}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:error, "Failed to read endpoint: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("navigate", %{"node" => node, "type" => "node"}, socket) do
    # Nodes are containers - navigate into them
    %{client: client, path: path} = socket.assigns

    new_path = path ++ [node]
    full_path = Enum.join(new_path, "/")

    # Set loading state
    socket = assign(socket, :loading, true)
    socket = assign(socket, :error, nil)

    # Fetch child nodes
    case Client.list(client, full_path) do
      {:ok, response} ->
        # Extract both Nodes and Endpoints from response
        nodes = Map.get(response, "Nodes", [])
        endpoints = Map.get(response, "Endpoints", [])

        # Build items with type information for display
        node_items = build_node_items(nodes)
        endpoint_items = build_endpoint_items(endpoints)

        all_items = Enum.sort_by(node_items ++ endpoint_items, & &1.name)

        if all_items == [] do
          # No children - this is a leaf node, show its value
          case Client.get(client, full_path) do
            {:ok, value_response} ->
              {:noreply,
               socket
               |> assign(:path, new_path)
               |> assign(:items, [])
               |> assign(:filtered_items, [])
               |> assign(:search, "")
               |> assign(:loading, false)
               |> assign(:preview, %{path: full_path, value: value_response})}

            {:error, _reason} ->
              {:noreply,
               socket
               |> assign(:path, new_path)
               |> assign(:items, [])
               |> assign(:filtered_items, [])
               |> assign(:search, "")
               |> assign(:loading, false)
               |> assign(:preview, nil)}
          end
        else
          # Check if this node has standard lever or button endpoints
          # Detection is filtered by mode if set
          detection_mode = socket.assigns[:detection_mode]
          lever_detection = detect_lever_endpoints(endpoint_items, full_path, detection_mode)

          button_detection =
            detect_button_endpoints(
              endpoint_items,
              full_path,
              detection_mode,
              socket.assigns.client
            )

          {:noreply,
           socket
           |> assign(:path, new_path)
           |> assign(:items, all_items)
           |> assign(:filtered_items, all_items)
           |> assign(:search, "")
           |> assign(:loading, false)
           |> assign(:preview, nil)
           |> assign(:lever_detection, lever_detection)
           |> assign(:button_detection, button_detection)}
        end

      {:error, _reason} ->
        # This might be a leaf node (something that looks like a node but has no children)
        # Try to get its value as a fallback
        case Client.get(client, full_path) do
          {:ok, response} ->
            {:noreply,
             socket
             |> assign(:loading, false)
             |> assign(:preview, %{path: full_path, value: response})}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:loading, false)
             |> assign(:error, "Failed to access: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("go_back", %{"index" => index_str}, socket) do
    %{client: client} = socket.assigns

    index = String.to_integer(index_str)
    new_path = Enum.take(socket.assigns.path, index)

    # Set loading state
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:preview, nil)

    # Fetch nodes at this path
    result =
      if new_path == [] do
        Client.list(client)
      else
        Client.list(client, Enum.join(new_path, "/"))
      end

    case result do
      {:ok, response} ->
        # Extract both Nodes and Endpoints
        nodes = Map.get(response, "Nodes", [])
        endpoints = Map.get(response, "Endpoints", [])

        node_items = build_node_items(nodes)
        endpoint_items = build_endpoint_items(endpoints)

        all_items = Enum.sort_by(node_items ++ endpoint_items, & &1.name)

        # Detect lever and button endpoints at this path
        full_path = Enum.join(new_path, "/")
        detection_mode = socket.assigns[:detection_mode]
        lever_detection = detect_lever_endpoints(endpoint_items, full_path, detection_mode)

        button_detection =
          detect_button_endpoints(
            endpoint_items,
            full_path,
            detection_mode,
            socket.assigns.client
          )

        {:noreply,
         socket
         |> assign(:path, new_path)
         |> assign(:items, all_items)
         |> assign(:filtered_items, all_items)
         |> assign(:search, "")
         |> assign(:loading, false)
         |> assign(:lever_detection, lever_detection)
         |> assign(:button_detection, button_detection)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Failed to navigate: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("search", %{"value" => search}, socket) do
    filtered = filter_items(socket.assigns.items, search)

    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:filtered_items, filtered)}
  end

  @impl true
  def handle_event("preview", %{"node" => node, "type" => type}, socket) do
    %{client: client, path: path} = socket.assigns

    item_type = String.to_existing_atom(type)
    full_path = build_full_path(path, node, item_type)

    case Client.get(client, full_path) do
      {:ok, response} ->
        {:noreply, assign(socket, :preview, %{path: full_path, value: response})}

      {:error, _reason} ->
        # Not a readable endpoint, just ignore
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select", %{"path" => path}, socket) do
    send(self(), {:api_explorer_select, socket.assigns.field, path})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), {:api_explorer_close})
    {:noreply, socket}
  end

  @impl true
  def handle_event("auto_configure", _params, socket) do
    # Send all the detected lever endpoints to the parent
    detection = socket.assigns.lever_detection

    endpoints = %{
      min_endpoint: detection.min_endpoint,
      max_endpoint: detection.max_endpoint,
      value_endpoint: detection.value_endpoint,
      notch_count_endpoint: detection.notch_count_endpoint,
      notch_index_endpoint: detection.notch_index_endpoint
    }

    send(self(), {:api_explorer_auto_configure, endpoints})
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_individual_selection", _params, socket) do
    # Notify parent that user wants to select endpoints individually
    send(self(), {:api_explorer_individual_selection})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_button_endpoint", _params, socket) do
    # Send the detected button endpoint to the parent
    detection = socket.assigns.button_detection
    send(self(), {:api_explorer_button_detected, detection})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    full_path = Enum.join(assigns.path, "/")
    assigns = assign(assigns, :full_path, full_path)

    ~H"""
    <div class={if @embedded, do: "flex-1 flex flex-col overflow-hidden", else: "fixed inset-0 z-[60] flex items-center justify-center p-4"}>
      <div :if={!@embedded} class="absolute inset-0 bg-black/50" phx-click="close" phx-target={@myself} />
      <div class={unless @embedded, do: "relative bg-base-100 rounded-xl shadow-xl w-full max-w-2xl max-h-[85vh] flex flex-col", else: "flex-1 flex flex-col overflow-hidden"}>
        <div class="p-4 border-b border-base-300">
          <div :if={!@embedded} class="flex items-center justify-between mb-3">
            <div>
              <h2 class="text-lg font-semibold">Browse Simulator API</h2>
              <p class="text-sm text-base-content/60">Selecting: {format_field_name(@field)}</p>
            </div>
            <button
              type="button"
              phx-click="close"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div class="flex items-center gap-2 text-sm">
            <button
              type="button"
              phx-click="go_back"
              phx-value-index="0"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
            >
              <.icon name="hero-home" class="w-4 h-4" />
            </button>
            <span :for={{segment, index} <- Enum.with_index(@path)} class="flex items-center">
              <span class="text-base-content/40">/</span>
              <button
                type="button"
                phx-click="go_back"
                phx-value-index={index + 1}
                phx-target={@myself}
                class="btn btn-ghost btn-xs"
              >
                {segment}
              </button>
            </span>
          </div>

          <div class="mt-3">
            <input
              type="text"
              id={"api-explorer-search-#{@full_path}"}
              name="search"
              placeholder="Search nodes..."
              value={@search}
              phx-keyup="search"
              phx-target={@myself}
              phx-debounce="150"
              class="input input-bordered input-sm w-full"
            />
          </div>
        </div>

        <div
          :if={@lever_detection}
          class="mx-4 mt-4 p-4 bg-primary/10 border border-primary/30 rounded-lg"
        >
          <div class="flex items-start gap-3">
            <.icon name="hero-sparkles" class="w-5 h-5 text-primary flex-shrink-0 mt-0.5" />
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-sm">
                Lever Control Detected
                <span
                  :if={@lever_detection.has_notches}
                  class="text-xs font-normal text-base-content/60 ml-1"
                >
                  (with notches)
                </span>
              </h3>
              <p class="text-xs text-base-content/70 mt-1">
                This node has standard lever endpoints. Auto-configure all fields?
              </p>
              <div class="mt-2 text-xs text-base-content/60 space-y-0.5">
                <div class="flex items-center gap-1.5">
                  <.icon name="hero-check" class="w-3 h-3 text-success" />
                  <span>Min/Max Value</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <.icon name="hero-check" class="w-3 h-3 text-success" />
                  <span>Current Value (InputValue)</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <.icon
                    name={if @lever_detection.has_notches, do: "hero-check", else: "hero-minus"}
                    class={
                      if @lever_detection.has_notches,
                        do: "w-3 h-3 text-success",
                        else: "w-3 h-3 text-base-content/40"
                    }
                  />
                  <span class={unless @lever_detection.has_notches, do: "text-base-content/40"}>
                    Notch Count & Index
                  </span>
                </div>
              </div>
              <div class="flex flex-wrap gap-2 mt-3">
                <button
                  type="button"
                  phx-click="auto_configure"
                  phx-target={@myself}
                  class="btn btn-primary btn-sm"
                >
                  <.icon name="hero-bolt" class="w-4 h-4" /> Configure All Endpoints
                </button>
                <button
                  type="button"
                  phx-click="start_individual_selection"
                  phx-target={@myself}
                  class="btn btn-ghost btn-sm"
                >
                  <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
                  Choose Individual Endpoints
                </button>
              </div>
            </div>
          </div>
        </div>

        <div
          :if={@button_detection}
          class="mx-4 mt-4 p-4 bg-success/10 border border-success/30 rounded-lg"
        >
          <div class="flex items-start gap-3">
            <.icon name="hero-hand-raised" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-sm">Button Endpoint Found</h3>
              <p class="text-xs text-base-content/70 mt-1 font-mono">
                {@button_detection.endpoint}
              </p>
              <div :if={@button_detection.has_min_max} class="mt-2 text-xs text-base-content/60">
                <span class="font-medium">Suggested values:</span>
                ON = {@button_detection.suggested_on}, OFF = {@button_detection.suggested_off}
              </div>
              <button
                type="button"
                phx-click="select_button_endpoint"
                phx-target={@myself}
                class="btn btn-success btn-sm mt-3"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Use This Endpoint
              </button>
            </div>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto p-4">
          <div :if={@error} class="alert alert-error mb-4">
            <.icon name="hero-exclamation-circle" class="w-5 h-5" />
            <span>{@error}</span>
          </div>

          <div :if={@loading} class="flex justify-center py-8">
            <span class="loading loading-spinner loading-lg" />
          </div>

          <div
            :if={not @loading and Enum.empty?(@filtered_items)}
            class="text-center py-8 text-base-content/50"
          >
            <.icon name="hero-folder-open" class="w-12 h-12 mx-auto mb-2 opacity-30" />
            <p class="text-sm">No items found</p>
          </div>

          <div :if={not @loading and not Enum.empty?(@filtered_items)} class="space-y-1">
            <div :for={item <- @filtered_items} class="group">
              <div class={[
                "flex items-center gap-2 p-2 rounded-lg hover:bg-base-200 transition-colors",
                item.type == :endpoint && "bg-base-200/30"
              ]}>
                <button
                  type="button"
                  phx-click="navigate"
                  phx-value-node={item.name}
                  phx-value-type={item.type}
                  phx-target={@myself}
                  class="flex-1 flex items-center gap-2 text-left"
                >
                  <.icon
                    name={item_icon(item)}
                    class={
                      if item.type == :endpoint,
                        do: "w-4 h-4 text-primary",
                        else: "w-4 h-4 text-base-content/50"
                    }
                  />
                  <span class="font-mono text-sm truncate">{item.name}</span>
                  <span
                    :if={item.type == :endpoint}
                    class={[
                      "text-xs px-1.5 py-0.5 rounded",
                      item.writable && "bg-success/20 text-success",
                      not item.writable && "bg-base-300 text-base-content/50"
                    ]}
                  >
                    {if item.writable, do: "RW", else: "RO"}
                  </span>
                </button>
                <button
                  type="button"
                  phx-click="preview"
                  phx-value-node={item.name}
                  phx-value-type={item.type}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Preview value"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                </button>
                <button
                  type="button"
                  phx-click="select"
                  phx-value-path={item_path(@full_path, item)}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs text-primary opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Select this path"
                >
                  <.icon name="hero-check" class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div :if={@preview} class="border-t border-base-300 p-4 bg-base-200/50">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-semibold">Preview</h3>
            <span class="font-mono text-xs text-base-content/60">{@preview.path}</span>
          </div>
          <pre class="bg-base-300 rounded-lg p-3 text-xs font-mono overflow-x-auto max-h-32">{format_preview(@preview.value)}</pre>
          <div class="mt-3 flex justify-end">
            <button
              type="button"
              phx-click="select"
              phx-value-path={@preview.path}
              phx-target={@myself}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-check" class="w-4 h-4" /> Select This Path
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp initialize_explorer(socket) do
    case Client.list(socket.assigns.client) do
      {:ok, response} ->
        # Extract both Nodes and Endpoints
        nodes = Map.get(response, "Nodes", [])
        endpoints = Map.get(response, "Endpoints", [])

        node_items = build_node_items(nodes)
        endpoint_items = build_endpoint_items(endpoints)

        all_items = Enum.sort_by(node_items ++ endpoint_items, & &1.name)

        socket
        |> assign(:path, [])
        |> assign(:items, all_items)
        |> assign(:filtered_items, all_items)
        |> assign(:search, "")
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> assign(:preview, nil)
        |> assign(:lever_detection, nil)
        |> assign(:button_detection, nil)
        |> assign(:initialized, true)

      {:error, reason} ->
        socket
        |> assign(:path, [])
        |> assign(:items, [])
        |> assign(:filtered_items, [])
        |> assign(:search, "")
        |> assign(:loading, false)
        |> assign(:error, "Failed to load API nodes: #{inspect(reason)}")
        |> assign(:preview, nil)
        |> assign(:lever_detection, nil)
        |> assign(:button_detection, nil)
        |> assign(:initialized, true)
    end
  end

  # Builds item maps for nodes (folders/containers)
  defp build_node_items(nodes) when is_list(nodes) do
    Enum.map(nodes, fn node ->
      name = Map.get(node, "NodeName") || Map.get(node, "Name", "")
      %{name: name, type: :node, writable: false}
    end)
  end

  defp build_node_items(_), do: []

  # Builds item maps for endpoints (properties)
  defp build_endpoint_items(endpoints) when is_list(endpoints) do
    Enum.map(endpoints, fn endpoint ->
      %{
        name: Map.get(endpoint, "Name", ""),
        type: :endpoint,
        writable: Map.get(endpoint, "Writable", false)
      }
    end)
  end

  defp build_endpoint_items(_), do: []

  # Builds the full API path for an item
  # Nodes use slash notation: CurrentDrivableActor/Throttle(Lever)
  # Endpoints use dot notation: CurrentDrivableActor/Throttle(Lever).InputValue
  defp build_full_path([], name, _type), do: name

  defp build_full_path(path, name, :endpoint) do
    Enum.join(path, "/") <> "." <> name
  end

  defp build_full_path(path, name, :node) do
    Enum.join(path, "/") <> "/" <> name
  end

  # Filter items by search term
  defp filter_items(items, ""), do: items

  defp filter_items(items, search) do
    search_lower = String.downcase(search)

    Enum.filter(items, fn item ->
      String.contains?(String.downcase(item.name), search_lower)
    end)
  end

  # Returns icon based on item type
  defp item_icon(%{type: :endpoint}), do: "hero-adjustments-horizontal"

  defp item_icon(%{type: :node, name: name}) do
    cond do
      String.contains?(name, "(") -> "hero-cube"
      true -> "hero-folder"
    end
  end

  # Returns the full path for an item, using dot notation for endpoints
  defp item_path(base_path, %{name: name, type: :endpoint}) do
    if base_path == "" do
      name
    else
      "#{base_path}.#{name}"
    end
  end

  defp item_path(base_path, %{name: name, type: :node}) do
    if base_path == "" do
      name
    else
      "#{base_path}/#{name}"
    end
  end

  defp format_preview(value) when is_map(value) do
    Jason.encode!(value, pretty: true)
  end

  defp format_preview(value), do: inspect(value, pretty: true)

  # Format field name for display
  defp format_field_name(:min_endpoint), do: "Minimum Value Endpoint"
  defp format_field_name(:max_endpoint), do: "Maximum Value Endpoint"
  defp format_field_name(:value_endpoint), do: "Current Value Endpoint"
  defp format_field_name(:notch_count_endpoint), do: "Notch Count Endpoint"
  defp format_field_name(:notch_index_endpoint), do: "Notch Index Endpoint"

  defp format_field_name(field),
    do: field |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  # Button endpoint detection
  # When in :button mode, any node with a writable InputValue endpoint is a valid button
  # We also fetch min/max values if available to suggest on/off values
  defp detect_button_endpoints(_endpoint_items, _node_path, :lever, _client), do: nil

  defp detect_button_endpoints(endpoint_items, node_path, _mode, client) do
    endpoint_names = MapSet.new(endpoint_items, & &1.name)

    has_input_value =
      Enum.any?(endpoint_items, fn ep -> ep.name == "InputValue" and ep.writable end)

    if has_input_value do
      # Try to get min/max values to suggest on/off values
      has_min = MapSet.member?(endpoint_names, "Function.GetMinimumInputValue")
      has_max = MapSet.member?(endpoint_names, "Function.GetMaximumInputValue")

      {suggested_off, suggested_on} =
        if has_min and has_max do
          min_val = fetch_endpoint_value(client, "#{node_path}.Function.GetMinimumInputValue")
          max_val = fetch_endpoint_value(client, "#{node_path}.Function.GetMaximumInputValue")
          {min_val, max_val}
        else
          {0.0, 1.0}
        end

      %{
        node_path: node_path,
        endpoint: "#{node_path}.InputValue",
        suggested_on: suggested_on,
        suggested_off: suggested_off,
        has_min_max: has_min and has_max
      }
    else
      nil
    end
  end

  defp fetch_endpoint_value(client, path) do
    case Client.get(client, path) do
      {:ok, value} when is_number(value) -> Float.round(value / 1, 2)
      {:ok, %{"value" => value}} when is_number(value) -> Float.round(value / 1, 2)
      _ -> nil
    end
  end

  # Lever endpoint detection
  # Standard TSW lever controls have these endpoints:
  # Required: Function.GetMinimumInputValue, Function.GetMaximumInputValue, InputValue (writable)
  # Optional: Function.GetNotchCount, Function.GetCurrentNotchIndex
  # Only detected when mode is :lever or nil (auto-detect)
  defp detect_lever_endpoints(_endpoint_items, _node_path, :button), do: nil

  defp detect_lever_endpoints(endpoint_items, node_path, _mode) do
    endpoint_names = MapSet.new(endpoint_items, & &1.name)

    has_min = MapSet.member?(endpoint_names, "Function.GetMinimumInputValue")
    has_max = MapSet.member?(endpoint_names, "Function.GetMaximumInputValue")

    has_input_value =
      Enum.any?(endpoint_items, fn ep -> ep.name == "InputValue" and ep.writable end)

    has_notch_count = MapSet.member?(endpoint_names, "Function.GetNotchCount")
    has_notch_index = MapSet.member?(endpoint_names, "Function.GetCurrentNotchIndex")

    # Must have all 3 required endpoints
    if has_min and has_max and has_input_value do
      %{
        node_path: node_path,
        min_endpoint: "#{node_path}.Function.GetMinimumInputValue",
        max_endpoint: "#{node_path}.Function.GetMaximumInputValue",
        value_endpoint: "#{node_path}.InputValue",
        notch_count_endpoint: if(has_notch_count, do: "#{node_path}.Function.GetNotchCount"),
        notch_index_endpoint:
          if(has_notch_index, do: "#{node_path}.Function.GetCurrentNotchIndex"),
        has_notches: has_notch_count and has_notch_index
      }
    else
      nil
    end
  end
end
