# Button Mapping Enhancement - Implementation Plan

## Overview

This plan addresses three key improvements to the button mapping system:
1. **Switch Type Handling**: Support for momentary vs latching physical switches
2. **Auto-Detect**: Automatically detect which control the user interacts with in the simulator
3. **Sequences**: Reusable command sequences that can be triggered by buttons

## Current Behavior

- Each button binding sends `on_value` when pressed, `off_value` when released
- Single command per button press
- No distinction between physical switch types

## Proposed Architecture

### Key Concepts

**Physical Hardware Type:**
- **Momentary** - Spring-loaded, returns when released (e.g., doorbell button)
- **Latching** - Stays in position until pressed again (e.g., toggle switch)

**Binding Modes:**
- **Simple** - Send on_value when pressed, off_value when released (current behavior)
- **Momentary** - Repeat on_value at interval while held (for controls like horn)
- **Sequence** - Execute a pre-defined command sequence

**Sequences as Separate Entity:**
- Sequences are defined independently, then referenced by button bindings
- A sequence contains ordered commands with endpoints, values, and delays
- Buttons reference sequences via `on_sequence_id` and optionally `off_sequence_id`

### Behavior Matrix

| Hardware Type | Mode | ON (Press) | OFF (Release) |
|--------------|------|------------|---------------|
| Momentary | Simple | Send on_value | Send off_value |
| Momentary | Momentary | Repeat on_value at interval | Send off_value, stop repeat |
| Momentary | Sequence | Execute on_sequence | Nothing |
| Latching | Simple | Send on_value | Send off_value |
| Latching | Sequence | Execute on_sequence | Execute off_sequence (if set) |

---

## Phase 1: Momentary Mode & Hardware Type

Add momentary mode for controls that need continuous signals (like horn).

### Schema Changes

**ButtonInputBinding** - Add fields:
```elixir
field :mode, Ecto.Enum, values: [:simple, :momentary, :sequence], default: :simple
field :hardware_type, Ecto.Enum, values: [:momentary, :latching], default: :momentary
field :repeat_interval_ms, :integer, default: 100
```

### Migration

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_add_mode_to_button_bindings.exs
def change do
  alter table(:button_input_bindings) do
    add :mode, :string, null: false, default: "simple"
    add :hardware_type, :string, null: false, default: "momentary"
    add :repeat_interval_ms, :integer, null: false, default: 100
  end

  create constraint(:button_input_bindings, :valid_mode,
    check: "mode IN ('simple', 'momentary', 'sequence')")
  create constraint(:button_input_bindings, :valid_hardware_type,
    check: "hardware_type IN ('momentary', 'latching')")
  create constraint(:button_input_bindings, :valid_repeat_interval,
    check: "repeat_interval_ms > 0 AND repeat_interval_ms <= 5000")
end
```

### ButtonController Changes

Add to state:
```elixir
active_buttons: %{element_id => %{
  timer_ref: reference() | nil,
  binding_info: map()
}}
```

New handlers:
- `handle_button_press` for momentary mode: Send on_value, schedule repeat timer
- `handle_button_release` for momentary mode: Cancel timer, send off_value
- `{:momentary_repeat, element_id}` message: Send on_value again, schedule next

### UI Changes

Add to configuration wizard testing step:

```
Hardware Type:
○ Momentary (spring-loaded, returns when released)
● Latching (stays in position until toggled)

Mode:
○ Simple (send once on press/release)
● Momentary (repeat while held, e.g., horn)
○ Sequence (trigger a command sequence)

[If Momentary mode selected:]
Repeat interval: [100] ms
```

### Tests

```elixir
describe "momentary mode" do
  test "sends on_value when pressed"
  test "repeats on_value at interval while held"
  test "sends off_value when released"
  test "stops repeating when released"
  test "honors custom repeat_interval_ms"
  test "cancels timer on train change"
end

describe "hardware types" do
  test "momentary hardware triggers on press, clears on release"
  test "latching hardware triggers on each state change"
end
```

---

## Phase 1.5: Auto-Detect Control Feature

Instead of manually browsing the API tree, users can interact with the control in the simulator and we detect which endpoint changed.

### How It Works

1. **Discovery**: Query `/list/CurrentDrivableActor` to get all controls
2. **Subscribe**: Create subscription for all `*.InputValue` endpoints
3. **Snapshot**: Record current values of all controls
4. **Listen**: Poll subscription every ~150ms
5. **Detect**: Compare values to find changes (threshold: > 0.01 difference)
6. **Suggest**: Show changed endpoint(s) to user

### API Usage

```elixir
# 1. Discover all controls
{:ok, controls} = Client.list(client, "CurrentDrivableActor")

# 2. Create subscription for all InputValue endpoints
input_endpoints =
  controls
  |> Enum.filter(&String.ends_with?(&1, ".InputValue"))

Enum.each(input_endpoints, fn endpoint ->
  Client.subscribe(client, endpoint, subscription_id: 1)
end)

# 3. Poll subscription (returns all values in one request)
{:ok, %{entries: entries}} = Client.get_subscription(client, 1)

# 4. Compare snapshots to detect changes
changed =
  Enum.filter(entries, fn entry ->
    previous = Map.get(snapshot, entry.path)
    current = get_value(entry)
    previous != nil and abs(current - previous) > 0.01
  end)
```

### New Module: ControlDetectionSession

```elixir
# lib/tsw_io/simulator/control_detection_session.ex
defmodule TswIo.Simulator.ControlDetectionSession do
  @moduledoc """
  Manages an auto-detection session for discovering simulator controls.

  Subscribes to all InputValue endpoints, takes snapshots, and detects
  which control(s) the user interacts with in the simulator.
  """

  use GenServer
  require Logger

  alias TswIo.Simulator.Client

  defmodule State do
    @type t :: %__MODULE__{
            client: Client.t(),
            subscription_id: integer(),
            endpoints: [String.t()],
            baseline_values: %{String.t() => float()},
            detected_changes: [detected_change()],
            callback_pid: pid(),
            poll_timer: reference() | nil,
            timeout_timer: reference() | nil
          }

    @type detected_change :: %{
            endpoint: String.t(),
            control_name: String.t(),
            previous_value: float(),
            current_value: float()
          }

    defstruct [
      :client,
      :subscription_id,
      :endpoints,
      :baseline_values,
      :detected_changes,
      :callback_pid,
      :poll_timer,
      :timeout_timer
    ]
  end

  @poll_interval_ms 150
  @detection_threshold 0.01
  @timeout_ms 30_000

  # Client API

  @doc """
  Start a detection session. Returns {:ok, pid} or {:error, reason}.

  The session will:
  1. Discover all InputValue endpoints
  2. Subscribe and take baseline snapshot
  3. Poll for changes every 150ms
  4. Send {:control_detected, changes} to callback_pid when changes detected
  5. Auto-terminate after 30 seconds if no detection
  """
  @spec start(Client.t(), pid()) :: {:ok, pid()} | {:error, term()}
  def start(client, callback_pid) do
    GenServer.start(__MODULE__, {client, callback_pid})
  end

  @doc """
  Stop the detection session and cleanup subscription.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Server Callbacks

  @impl true
  def init({client, callback_pid}) do
    case setup_detection(client) do
      {:ok, endpoints, baseline} ->
        subscription_id = generate_subscription_id()

        state = %State{
          client: client,
          subscription_id: subscription_id,
          endpoints: endpoints,
          baseline_values: baseline,
          detected_changes: [],
          callback_pid: callback_pid
        }

        # Start polling
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        timeout_timer = Process.send_after(self(), :timeout, @timeout_ms)

        {:ok, %{state | poll_timer: poll_timer, timeout_timer: timeout_timer}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:poll, %State{} = state) do
    case poll_for_changes(state) do
      {:changes_detected, changes} ->
        # Notify callback and stop
        send(state.callback_pid, {:control_detected, changes})
        {:stop, :normal, state}

      :no_changes ->
        # Schedule next poll
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        {:noreply, %{state | poll_timer: poll_timer}}

      {:error, _reason} ->
        # Continue polling despite errors
        poll_timer = Process.send_after(self(), :poll, @poll_interval_ms)
        {:noreply, %{state | poll_timer: poll_timer}}
    end
  end

  def handle_info(:timeout, %State{} = state) do
    send(state.callback_pid, {:detection_timeout})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %State{} = state) do
    # Cleanup subscription
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)
    if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)
    Client.delete_subscription(state.client, state.subscription_id)
    :ok
  end

  # Private Functions

  defp setup_detection(client) do
    with {:ok, controls} <- discover_input_endpoints(client),
         {:ok, baseline} <- create_subscription_and_snapshot(client, controls) do
      {:ok, controls, baseline}
    end
  end

  defp discover_input_endpoints(client) do
    case Client.list(client, "CurrentDrivableActor") do
      {:ok, nodes} ->
        # Filter to InputValue endpoints
        input_endpoints =
          nodes
          |> Enum.filter(&is_input_value_endpoint?/1)
          |> Enum.map(&build_full_path/1)

        {:ok, input_endpoints}

      error ->
        error
    end
  end

  defp poll_for_changes(%State{} = state) do
    case Client.get_subscription(state.client, state.subscription_id) do
      {:ok, %{entries: entries}} ->
        changes =
          entries
          |> Enum.filter(fn entry ->
            baseline = Map.get(state.baseline_values, entry.path)
            current = extract_value(entry)

            baseline != nil and current != nil and
              abs(current - baseline) > @detection_threshold
          end)
          |> Enum.map(fn entry ->
            %{
              endpoint: entry.path,
              control_name: extract_control_name(entry.path),
              previous_value: Map.get(state.baseline_values, entry.path),
              current_value: extract_value(entry)
            }
          end)

        if changes != [] do
          {:changes_detected, changes}
        else
          :no_changes
        end

      error ->
        error
    end
  end

  defp extract_control_name(path) do
    # "CurrentDrivableActor/Horn.InputValue" -> "Horn"
    path
    |> String.replace("CurrentDrivableActor/", "")
    |> String.replace(".InputValue", "")
  end

  defp extract_value(%{values: values}) do
    # Values typically have a single key like "InputValue" => 0.5
    values |> Map.values() |> List.first()
  end
end
```

### UI: Auto-Detect Modal

```
┌─────────────────────────────────────────────────────────┐
│ Auto-Detect Control                            [×]      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│         ◌ ← ◌ ← ● ← ◌    Listening...                  │
│                                                         │
│  Interact with the control in Train Sim World.         │
│  Press a button, move a lever, or flip a switch.       │
│                                                         │
│  Make sure you're in the cab of the active train.      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Detected: (waiting for input...)                  │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Timeout in: 28s                                       │
│                                                         │
│                                          [Cancel]      │
└─────────────────────────────────────────────────────────┘

After detection:

┌─────────────────────────────────────────────────────────┐
│ Auto-Detect Control                            [×]      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│         ✓ Control Detected!                            │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Control: Horn                                     │ │
│  │ Endpoint: CurrentDrivableActor/Horn.InputValue    │ │
│  │ Value changed: 0.0 → 1.0                          │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Is this the correct control?                          │
│                                                         │
│  [Detect Another]                    [Use This Control] │
└─────────────────────────────────────────────────────────┘

Multiple controls detected:

┌─────────────────────────────────────────────────────────┐
│ Auto-Detect Control                            [×]      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│         ⚠ Multiple Controls Detected                   │
│                                                         │
│  Select the control you want to use:                   │
│                                                         │
│  ○ Horn                                                │
│    CurrentDrivableActor/Horn.InputValue                │
│    Changed: 0.0 → 1.0                                  │
│                                                         │
│  ○ Throttle(Lever)                                     │
│    CurrentDrivableActor/Throttle(Lever).InputValue     │
│    Changed: 0.0 → 0.15                                 │
│                                                         │
│  [Detect Again]                      [Use Selected]    │
└─────────────────────────────────────────────────────────┘
```

### LiveView Component

```elixir
# lib/tsw_io_web/live/components/auto_detect_component.ex
defmodule TswIoWeb.Components.AutoDetectComponent do
  use TswIoWeb, :live_component

  alias TswIo.Simulator.ControlDetectionSession

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       status: :idle,
       session_pid: nil,
       detected_changes: [],
       selected_index: 0,
       timeout_remaining: 30
     )}
  end

  @impl true
  def handle_event("start_detection", _params, socket) do
    case start_detection_session(socket) do
      {:ok, pid} ->
        # Start countdown timer
        Process.send_after(self(), :tick_countdown, 1000)

        {:noreply,
         assign(socket,
           status: :listening,
           session_pid: pid,
           timeout_remaining: 30
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(status: :error, error_message: inspect(reason))
         |> put_flash(:error, "Failed to start detection: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel", _params, socket) do
    if socket.assigns.session_pid do
      ControlDetectionSession.stop(socket.assigns.session_pid)
    end

    {:noreply, assign(socket, status: :idle, session_pid: nil)}
  end

  def handle_event("select_control", %{"index" => index}, socket) do
    {:noreply, assign(socket, selected_index: String.to_integer(index))}
  end

  def handle_event("use_selected", _params, socket) do
    selected = Enum.at(socket.assigns.detected_changes, socket.assigns.selected_index)

    send(self(), {:auto_detect_selected, selected})

    {:noreply, assign(socket, status: :idle, session_pid: nil)}
  end

  def handle_event("detect_another", _params, socket) do
    # Restart detection
    handle_event("start_detection", %{}, socket)
  end

  @impl true
  def handle_info({:control_detected, changes}, socket) do
    {:noreply,
     assign(socket,
       status: :detected,
       detected_changes: changes,
       session_pid: nil
     )}
  end

  def handle_info({:detection_timeout}, socket) do
    {:noreply,
     assign(socket,
       status: :timeout,
       session_pid: nil
     )}
  end

  def handle_info(:tick_countdown, socket) do
    if socket.assigns.status == :listening do
      remaining = socket.assigns.timeout_remaining - 1

      if remaining > 0 do
        Process.send_after(self(), :tick_countdown, 1000)
        {:noreply, assign(socket, timeout_remaining: remaining)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp start_detection_session(socket) do
    # Get simulator client
    case TswIo.Simulator.Connection.get_client() do
      {:ok, client} ->
        ControlDetectionSession.start(client, self())

      error ->
        error
    end
  end
end
```

### Integration with Configuration Wizard

Add "Auto-Detect" button alongside API browser:

```
┌─────────────────────────────────────────────────────────┐
│ Select Endpoint                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Auto-Detect]  or  [Browse API Tree]                  │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  Selected: CurrentDrivableActor/Horn.InputValue        │
│  (detected via auto-detect)                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Tests

```elixir
describe "ControlDetectionSession" do
  test "discovers all InputValue endpoints"
  test "creates subscription and takes baseline snapshot"
  test "detects single control change"
  test "detects multiple simultaneous changes"
  test "ignores changes below threshold (< 0.01)"
  test "times out after 30 seconds with no detection"
  test "cleans up subscription on stop"
  test "handles simulator disconnect gracefully"
end

describe "Auto-detect UI" do
  test "shows listening state when started"
  test "displays countdown timer"
  test "shows detected control on success"
  test "allows selection when multiple controls detected"
  test "returns to idle on cancel"
  test "shows timeout message after 30 seconds"
end
```

---

## Phase 2: Sequences as Separate Entity

Sequences are their own entity, defined independently and referenced by buttons.

### New Schema: Sequence

```elixir
# lib/tsw_io/train/sequence.ex
defmodule TswIo.Train.Sequence do
  @moduledoc """
  A reusable command sequence that can be triggered by button bindings.

  Sequences belong to a train and contain ordered commands.
  Multiple buttons can reference the same sequence.
  """

  schema "sequences" do
    field :name, :string
    belongs_to :train, TswIo.Train.Train
    has_many :commands, TswIo.Train.SequenceCommand, preload_order: [asc: :position]
    timestamps(type: :utc_datetime)
  end
end
```

### New Schema: SequenceCommand

```elixir
# lib/tsw_io/train/sequence_command.ex
defmodule TswIo.Train.SequenceCommand do
  @moduledoc """
  Individual command within a sequence.

  Commands are executed in order (by position).
  delay_ms specifies the wait time AFTER this command before the next.
  """

  schema "sequence_commands" do
    field :position, :integer          # Order in sequence (0, 1, 2...)
    field :endpoint, :string           # Simulator API path
    field :value, :float               # Value to send (rounded to 2 decimals)
    field :delay_ms, :integer, default: 0  # Delay after this command

    belongs_to :sequence, TswIo.Train.Sequence
    timestamps(type: :utc_datetime)
  end
end
```

### ButtonInputBinding Updates

Add sequence references:
```elixir
# For sequence mode - references to Sequence entities
belongs_to :on_sequence, TswIo.Train.Sequence
belongs_to :off_sequence, TswIo.Train.Sequence  # Only used with latching hardware
```

Validation rules:
- `mode: :sequence` requires `on_sequence_id`
- `off_sequence_id` only valid when `hardware_type: :latching` AND `mode: :sequence`
- `mode: :simple` or `mode: :momentary` requires `endpoint`

### Migrations

```elixir
# Migration 1: Create sequences table
def change do
  create table(:sequences) do
    add :name, :string, null: false
    add :train_id, references(:trains, on_delete: :delete_all), null: false
    timestamps(type: :utc_datetime)
  end

  create index(:sequences, [:train_id])
  create unique_index(:sequences, [:train_id, :name])
end

# Migration 2: Create sequence_commands table
def change do
  create table(:sequence_commands) do
    add :sequence_id, references(:sequences, on_delete: :delete_all), null: false
    add :position, :integer, null: false
    add :endpoint, :string, null: false
    add :value, :float, null: false
    add :delay_ms, :integer, null: false, default: 0
    timestamps(type: :utc_datetime)
  end

  create index(:sequence_commands, [:sequence_id])
  create unique_index(:sequence_commands, [:sequence_id, :position])
end

# Migration 3: Add sequence references to button_input_bindings
def change do
  alter table(:button_input_bindings) do
    add :on_sequence_id, references(:sequences, on_delete: :nilify_all)
    add :off_sequence_id, references(:sequences, on_delete: :nilify_all)
  end

  create index(:button_input_bindings, [:on_sequence_id])
  create index(:button_input_bindings, [:off_sequence_id])
end
```

### ButtonController Changes

Add sequence execution state:
```elixir
active_buttons: %{element_id => %{
  timer_ref: reference() | nil,
  sequence_state: %{
    remaining_commands: [SequenceCommand.t()],
    cancel_ref: reference()
  } | nil,
  binding_info: map()
}}
```

New handlers:
- `handle_button_press` for sequence mode: Start executing `on_sequence`
- `handle_button_release` for sequence mode with latching: Start executing `off_sequence`
- `{:execute_next_command, element_id, cancel_ref}`: Execute command, schedule next

Sequence execution logic:
```elixir
defp execute_sequence(state, element_id, %Sequence{commands: commands}) do
  sorted = Enum.sort_by(commands, & &1.position)

  case sorted do
    [] -> state  # Empty sequence, nothing to do
    [first | rest] ->
      # Execute first command immediately
      send_to_simulator(first.endpoint, first.value)

      # Schedule next if there are more
      cancel_ref = make_ref()
      if rest != [] do
        Process.send_after(self(), {:execute_next_command, element_id, cancel_ref}, first.delay_ms)
      end

      # Track state
      put_in(state.active_buttons[element_id], %{
        sequence_state: %{remaining_commands: rest, cancel_ref: cancel_ref},
        ...
      })
  end
end
```

### Context Functions (Train module)

```elixir
# Sequence CRUD
@spec create_sequence(integer(), map()) :: {:ok, Sequence.t()} | {:error, Changeset.t()}
def create_sequence(train_id, attrs)

@spec update_sequence(Sequence.t(), map()) :: {:ok, Sequence.t()} | {:error, Changeset.t()}
def update_sequence(%Sequence{} = sequence, attrs)

@spec delete_sequence(Sequence.t()) :: {:ok, Sequence.t()} | {:error, Changeset.t()}
def delete_sequence(%Sequence{} = sequence)

@spec get_sequence(integer()) :: {:ok, Sequence.t()} | {:error, :not_found}
def get_sequence(id)

@spec list_sequences(integer()) :: [Sequence.t()]
def list_sequences(train_id)

# SequenceCommand management
@spec set_sequence_commands(Sequence.t(), [map()]) :: {:ok, [SequenceCommand.t()]}
def set_sequence_commands(%Sequence{} = sequence, commands)
# Replaces all commands, auto-assigns positions based on list order
```

### UI: Sequence Management

New section in train configuration for managing sequences:

```
┌─────────────────────────────────────────────────────────┐
│ Sequences                                    [+ New]    │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔄 Door Open Sequence                    [Edit] [×] │ │
│ │    3 commands • ~750ms                              │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔄 Door Close Sequence                   [Edit] [×] │ │
│ │    2 commands • ~500ms                              │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔄 Emergency Stop                        [Edit] [×] │ │
│ │    4 commands • ~200ms                              │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### UI: Sequence Editor

```
┌─────────────────────────────────────────────────────────┐
│ Edit Sequence: Door Open Sequence                       │
├─────────────────────────────────────────────────────────┤
│ Name: [Door Open Sequence                    ]          │
│                                                         │
│ Commands:                                               │
│  1. ┌────────────────────────┬──────┬─────────┬────┐   │
│     │ DoorKey.InputValue     │  1.0 │ 500ms ↓ │ ×  │   │
│     └────────────────────────┴──────┴─────────┴────┘   │
│  2. ┌────────────────────────┬──────┬─────────┬────┐   │
│     │ DoorRotary.InputValue  │  0.5 │ 250ms ↓ │ ×  │   │
│     └────────────────────────┴──────┴─────────┴────┘   │
│  3. ┌────────────────────────┬──────┬─────────┬────┐   │
│     │ DoorOpen.InputValue    │  1.0 │   0ms   │ ×  │   │
│     └────────────────────────┴──────┴─────────┴────┘   │
│                                                         │
│  [+ Add Command]                                        │
│                                                         │
│  Total time: 750ms (+ API latency)                     │
│                                                         │
│  [Test Sequence]                      [Cancel] [Save]   │
└─────────────────────────────────────────────────────────┘
```

### UI: Button Binding with Sequence Mode

When mode is set to "Sequence" in the button configuration wizard:

```
┌─────────────────────────────────────────────────────────┐
│ Mode: ● Sequence                                        │
├─────────────────────────────────────────────────────────┤
│ Hardware Type: ○ Momentary  ● Latching                  │
├─────────────────────────────────────────────────────────┤
│ On Press/ON:                                            │
│ [Door Open Sequence            ▼]  [View] [+ New]       │
│                                                         │
│ On Release/OFF: (latching only)                         │
│ [Door Close Sequence           ▼]  [View] [+ New]       │
│ ☐ None (no action on OFF)                              │
└─────────────────────────────────────────────────────────┘
```

### Tests

```elixir
describe "Sequence schema" do
  test "creates sequence with valid attributes"
  test "requires name"
  test "enforces unique name per train"
  test "cascades delete to commands"
end

describe "SequenceCommand schema" do
  test "creates command with valid attributes"
  test "rounds value to 2 decimal places"
  test "enforces unique position per sequence"
  test "validates delay_ms >= 0"
end

describe "sequence mode in ButtonController" do
  test "executes on_sequence commands in order"
  test "applies delay_ms between commands"
  test "momentary hardware ignores release"
  test "latching hardware executes off_sequence on release"
  test "cancels in-progress sequence on train change"
  test "handles missing sequence gracefully"
  test "handles empty sequence gracefully"
end
```

---

## Phase 3: Polish & Enhancements (Future)

- Sequence templates (pre-built sequences for common operations)
- Duplicate sequence functionality
- Sequence import/export
- Sequence usage indicator (which buttons use this sequence)
- Drag-and-drop command reordering

---

## Edge Case Handling

### Train Change During Active Button
- Cancel all active timers and sequences
- Clear `active_buttons` state
- Implemented in `handle_info({:train_changed, _}, state)`

### Button Released Mid-Sequence
- Cancel remaining commands (don't send)
- Use `cancel_ref` to ignore stale messages
- Optionally execute "release sequence" for cleanup

### Simulator Disconnects
- `send_to_simulator/2` checks connection, returns gracefully on error
- Timers continue but commands fail safely
- No crash or state corruption

### Rapid Press/Release
- Simple mode: Deduped by `last_sent_values`
- Momentary: Timer replaced on each press
- Sequence: Cancel ref ensures old sequences stop

### Binding Reload
- `reload_bindings()` cancels all active buttons first
- Prevents stale timers from firing

---

## File Changes Summary

### Modified Files

1. **`lib/tsw_io/train/button_input_binding.ex`**
   - Add `mode`, `hardware_type`, and `repeat_interval_ms` fields
   - Add `belongs_to :on_sequence` and `belongs_to :off_sequence` associations
   - Update changeset validation for mode-specific requirements

2. **`lib/tsw_io/train/button_controller.ex`**
   - Add `active_buttons` to state
   - Implement mode-specific press/release handlers
   - Add timer management for momentary mode
   - Add sequence execution logic

3. **`lib/tsw_io/train.ex`**
   - Add sequence CRUD functions
   - Update `list_button_bindings_for_train/2` to support `:preload` option

4. **`lib/tsw_io_web/live/components/configuration_wizard_component.ex`**
   - Add hardware type and mode selection UI
   - Add repeat interval input (for momentary)
   - Add sequence selection dropdown (for sequence mode)
   - Add auto-detect button integration

5. **`lib/tsw_io/simulator/client.ex`**
   - Add subscription management functions (subscribe, get_subscription, delete_subscription)

### New Files

1. **`lib/tsw_io/simulator/control_detection_session.ex`** - Auto-detect GenServer
2. **`lib/tsw_io_web/live/components/auto_detect_component.ex`** - Auto-detect UI component
3. **`lib/tsw_io/train/sequence.ex`** - Sequence schema
4. **`lib/tsw_io/train/sequence_command.ex`** - SequenceCommand schema
5. **`lib/tsw_io_web/live/sequences_live.ex`** - Sequence management LiveView
6. **`lib/tsw_io_web/live/components/sequence_editor_component.ex`** - Sequence editor component

7. **`priv/repo/migrations/YYYYMMDDHHMMSS_add_mode_to_button_bindings.exs`**
8. **`priv/repo/migrations/YYYYMMDDHHMMSS_create_sequences.exs`**
9. **`priv/repo/migrations/YYYYMMDDHHMMSS_create_sequence_commands.exs`**
10. **`priv/repo/migrations/YYYYMMDDHHMMSS_add_sequence_refs_to_button_bindings.exs`**

11. **`test/tsw_io/simulator/control_detection_session_test.exs`** - Auto-detect tests
12. **`test/tsw_io/train/sequence_test.exs`** - Sequence schema tests
13. **`test/tsw_io/train/sequence_command_test.exs`** - SequenceCommand schema tests
14. **`test/tsw_io/train/button_controller_modes_test.exs`** - Controller mode tests

---

## Implementation Order

### Step 1: Schema & Migration (Phase 1 - Momentary Mode)
- [ ] Create migration for mode, hardware_type, and repeat_interval_ms
- [ ] Update ButtonInputBinding schema with new fields
- [ ] Update changeset validation
- [ ] Run migration

### Step 2: Controller Logic (Phase 1)
- [ ] Add active_buttons to state
- [ ] Refactor handle_input_update to call mode-specific handlers
- [ ] Implement momentary mode press/release with timer
- [ ] Add cancel logic for train change and reload

### Step 3: Tests (Phase 1)
- [ ] Test simple mode (existing behavior unchanged)
- [ ] Test momentary mode press/release
- [ ] Test momentary repeat behavior
- [ ] Test edge cases (train change, reload, rapid press)

### Step 4: UI (Phase 1)
- [ ] Add hardware type radio buttons to wizard
- [ ] Add mode radio buttons to wizard
- [ ] Add repeat interval input (conditional)
- [ ] Update save logic

### Step 5: Client Subscription Support (Phase 1.5)
- [ ] Add `subscribe/3` function to Simulator.Client
- [ ] Add `get_subscription/2` function to Simulator.Client
- [ ] Add `delete_subscription/2` function to Simulator.Client
- [ ] Test subscription lifecycle

### Step 6: Control Detection Session (Phase 1.5)
- [ ] Create ControlDetectionSession GenServer
- [ ] Implement endpoint discovery (list all InputValue endpoints)
- [ ] Implement subscription creation and baseline snapshot
- [ ] Implement polling and change detection
- [ ] Implement timeout handling
- [ ] Add cleanup on termination

### Step 7: Auto-Detect Tests (Phase 1.5)
- [ ] Test endpoint discovery
- [ ] Test change detection (single control)
- [ ] Test change detection (multiple controls)
- [ ] Test threshold filtering (ignore < 0.01)
- [ ] Test timeout behavior
- [ ] Test cleanup on stop

### Step 8: Auto-Detect UI (Phase 1.5)
- [ ] Create AutoDetectComponent LiveComponent
- [ ] Implement listening state with countdown
- [ ] Implement detection success state
- [ ] Implement multiple controls selection
- [ ] Implement timeout state
- [ ] Integrate with configuration wizard

### Step 9: Schema & Migrations (Phase 2 - Sequences)
- [ ] Create Sequence schema
- [ ] Create SequenceCommand schema
- [ ] Create migrations for new tables
- [ ] Add sequence references to ButtonInputBinding
- [ ] Run migrations

### Step 10: Context Functions (Phase 2)
- [ ] Add sequence CRUD functions to Train context
- [ ] Add set_sequence_commands/2 function
- [ ] Update list_button_bindings_for_train/2 with preload option

### Step 11: Controller Logic (Phase 2)
- [ ] Update binding loader to preload sequences
- [ ] Implement sequence mode press handler
- [ ] Implement latching hardware off_sequence handler
- [ ] Implement execute_next_command message handler

### Step 12: Sequence Tests (Phase 2)
- [ ] Test Sequence and SequenceCommand schemas
- [ ] Test sequence execution order and delays
- [ ] Test momentary vs latching hardware behavior
- [ ] Test sequence cancellation and edge cases

### Step 13: Sequence UI (Phase 2)
- [ ] Create sequence management page
- [ ] Create sequence editor component
- [ ] Add sequence selection to button wizard
- [ ] Add sequence testing functionality

### Step 14: Integration Testing
- [ ] Full flow: auto-detect control, configure button, test
- [ ] Full flow: create sequence, bind to button, execute via hardware
- [ ] Test latching button with on/off sequences
- [ ] Test all edge cases with real simulator

---

## Success Criteria

1. **Auto-Detect**: User can click "Auto-Detect", interact with a control in the sim, and have it automatically identified
2. **Horn Control**: User can configure a momentary button that keeps the horn active while held
3. **Door Sequence**: User can create a "Door Open" sequence and assign it to a button
4. **Latching with Sequences**: User can assign different sequences to ON and OFF positions
5. **Reusability**: Same sequence can be used by multiple buttons
6. **Backward Compatibility**: Existing simple bindings continue to work unchanged
7. **Reliability**: No crashes on rapid input, train changes, or disconnects
8. **UX**: Clear separation between sequence management and button binding, intuitive auto-detect flow
