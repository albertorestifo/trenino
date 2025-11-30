# Train Context Implementation Plan

## Overview

Create a new Train context for configuring trains from the TSW simulator. Trains are identified by a unique identifier derived from the simulator's ObjectClass values. Each train can have multiple elements (starting with lever type), which are calibrated to map hardware inputs to simulator values.

## Key Design Decisions

- **Mixed notch types**: Each notch within a lever can independently be `:gate` or `:linear`
- **Fully automated calibration**: Start → progress display → auto-save when done
- **Banner prompt**: Non-intrusive banner on train list when unconfigured train detected
- **Top-level navigation**: "Trains" as separate nav item alongside "Devices"
- **Proper relational design**: Notches stored in separate table with foreign key to LeverConfig

---

## Phase 1: Database Schema

### Migration 1: Create trains table

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_trains.exs
create table(:trains) do
  add :name, :string, null: false
  add :description, :string
  add :identifier, :string, null: false  # Common prefix from ObjectClass values

  timestamps(type: :utc_datetime)
end

create unique_index(:trains, [:identifier])
```

### Migration 2: Create train_elements table

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_train_elements.exs
create table(:train_elements) do
  add :train_id, references(:trains, on_delete: :delete_all), null: false
  add :type, :string, null: false  # Ecto.Enum: :lever (extensible for future types)
  add :name, :string, null: false

  timestamps(type: :utc_datetime)
end

create index(:train_elements, [:train_id])
```

### Migration 3: Create train_lever_configs table

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_train_lever_configs.exs
create table(:train_lever_configs) do
  add :element_id, references(:train_elements, on_delete: :delete_all), null: false
  add :min_endpoint, :string, null: false      # API path for min value
  add :max_endpoint, :string, null: false      # API path for max value
  add :value_endpoint, :string, null: false    # API path for current value (read/write)
  add :notch_count_endpoint, :string           # API path for notch count (nullable)
  add :notch_index_endpoint, :string           # API path for current notch (nullable)
  add :calibrated_at, :utc_datetime            # When calibration was performed (nullable)

  timestamps(type: :utc_datetime)
end

create unique_index(:train_lever_configs, [:element_id])
```

### Migration 4: Create train_lever_notches table

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_train_lever_notches.exs
create table(:train_lever_notches) do
  add :lever_config_id, references(:train_lever_configs, on_delete: :delete_all), null: false
  add :index, :integer, null: false            # Notch position (0, 1, 2, ...)
  add :type, :string, null: false              # Ecto.Enum: :gate or :linear
  add :value, :float                           # For gate notches: the fixed value
  add :min_value, :float                       # For linear notches: range start
  add :max_value, :float                       # For linear notches: range end
  add :description, :string                    # Optional user-provided description

  timestamps(type: :utc_datetime)
end

create index(:train_lever_notches, [:lever_config_id])
create unique_index(:train_lever_notches, [:lever_config_id, :index])
```

---

## Phase 2: Schema Modules

### File Structure

```
lib/tsw_io/train/
├── train.ex              # Train schema
├── element.ex            # Element schema (polymorphic base, uses Ecto.Enum for type)
├── lever_config.ex       # Lever-specific configuration
├── notch.ex              # Notch schema (proper relational table)
└── identifier.ex         # Train identifier derivation logic
```

### Key Schema: Element

Uses `Ecto.Enum` for type field:

```elixir
defmodule TswIo.Train.Element do
  schema "train_elements" do
    field :type, Ecto.Enum, values: [:lever]  # Extensible for future types
    field :name, :string

    belongs_to :train, Train
    has_one :lever_config, LeverConfig

    timestamps(type: :utc_datetime)
  end
end
```

### Key Schema: Notch (relational)

Proper relational table with foreign key to LeverConfig:

```elixir
defmodule TswIo.Train.Notch do
  schema "train_lever_notches" do
    field :index, :integer                     # Notch position (0, 1, 2, ...)
    field :type, Ecto.Enum, values: [:gate, :linear]
    field :value, :float                       # For gate notches: the fixed value
    field :min_value, :float                   # For linear notches: range start
    field :max_value, :float                   # For linear notches: range end
    field :description, :string                # Optional user-provided description

    belongs_to :lever_config, LeverConfig

    timestamps(type: :utc_datetime)
  end
end
```

### Key Schema: LeverConfig

Configuration with `has_many` relationship to notches:

```elixir
defmodule TswIo.Train.LeverConfig do
  schema "train_lever_configs" do
    field :min_endpoint, :string
    field :max_endpoint, :string
    field :value_endpoint, :string
    field :notch_count_endpoint, :string
    field :notch_index_endpoint, :string
    field :calibrated_at, :utc_datetime      # Nullable, set when calibrated

    belongs_to :element, Element
    has_many :notches, Notch, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end
end
```

---

## Phase 3: Context Module

### `TswIo.Train` Context API

```elixir
# Train CRUD
list_trains(opts \\ [])
get_train(id, opts \\ [])
get_train_by_identifier(identifier)
create_train(attrs)
update_train(train, attrs)
delete_train(train)

# Element CRUD
list_elements(train_id)
get_element(id, opts \\ [])
create_element(train_id, attrs)
delete_element(element)

# Lever Config (includes calibration data)
get_lever_config(element_id)
create_lever_config(element_id, attrs)
update_lever_config(config, attrs)
save_calibration(lever_config, notches)  # Sets calibrated_at and notches

# Detection delegation
defdelegate subscribe(), to: TswIo.Train.Detection
defdelegate get_active_train(), to: TswIo.Train.Detection
defdelegate get_current_identifier(), to: TswIo.Train.Detection
defdelegate sync(), to: TswIo.Train.Detection
```

---

## Phase 4: Train Detection GenServer

### `TswIo.Train.Detection`

**Purpose**: Monitor simulator for train changes, derive identifier, match to configs.

**State**:
```elixir
%State{
  active_train: Train.t() | nil,
  current_identifier: String.t() | nil,
  last_check: DateTime.t() | nil,
  polling_enabled: boolean()
}
```

**Identifier Derivation** (from `TswIo.Train.Identifier`):
1. GET `CurrentFormation.FormationLength` → length
2. For each index 0..length-1: GET `CurrentFormation/{index}.ObjectClass`
3. Find common string prefix among all ObjectClass values
4. That prefix is the train identifier

**PubSub Events** (topic: `"train:detection"`):
- `{:train_detected, %{identifier: String.t(), train: Train.t() | nil}}`
- `{:train_changed, Train.t() | nil}`
- `{:detection_error, term()}`

**Polling**: Every 15 seconds when simulator connected.

---

## Phase 5: Lever Calibration Session

### `TswIo.Train.Calibration.LeverSession`

**Purpose**: Automated calibration process for levers.

**Algorithm** (as specified by user):
1. Start at min value (0.0)
2. Increment value by 0.01
3. After each increment, read current value and notch index
4. Detect notch type:
   - If we set 0.01 and read back 0.0 → `:gate` notch
   - If we set 0.01 and read back 0.01 → `:linear` notch
5. When notch index changes → record previous notch, start new one
6. Continue until max value reached
7. Save calibration data to LeverConfig

**State**:
```elixir
%State{
  lever_config: LeverConfig.t(),
  step: :initializing | :calibrating | :saving | :complete | :error,
  current_value: float(),
  current_notch_index: integer(),
  notches: [%{type: atom(), ...}],
  error: term() | nil
}
```

**PubSub Events** (topic: `"train:calibration:{lever_config_id}"`):
- `{:calibration_progress, state}` - Progress updates during calibration
- `{:calibration_result, {:ok, LeverConfig.t()} | {:error, reason}}` - Final result

### `TswIo.Train.Calibration.SessionSupervisor`

DynamicSupervisor for spawning calibration sessions.

---

## Phase 6: LiveView Routes

Add to existing `live_session :default`:

```elixir
live "/trains", TrainListLive
live "/trains/:train_id", TrainEditLive
```

---

## Phase 7: TrainListLive

**File**: `lib/tsw_io_web/live/train_list_live.ex`

**Features**:
- List all train configurations
- Highlight active train (matching current identifier)
- Banner prompt when unconfigured train detected
- Link to create new train

**Assigns**:
- `trains` - List of all trains
- `current_identifier` - From Detection (or nil)
- `active_train` - Matched train (or nil)

**Banner Logic**:
```
IF current_identifier != nil AND active_train == nil:
  Show: "Train detected: {identifier}. [Configure]"
```

---

## Phase 8: TrainEditLive

**File**: `lib/tsw_io_web/live/train_edit_live.ex`

**Features**:
- Edit train name/description (inline like ConfigurationEditLive)
- Display train identifier (read-only)
- List elements with type badges
- Add element modal
- Delete element
- Lever settings modal (for configuring API endpoints)
- Start calibration wizard
- Delete train modal

**Modals**:
1. **Add Element Modal**: Name, type dropdown, add button
2. **Lever Settings Modal**: API endpoint fields with browse buttons
3. **API Explorer Modal**: Searchable tree of API paths
4. **Calibration Progress Modal**: Progress display during calibration
5. **Delete Train Modal**: Confirmation with active check

---

## Phase 9: API Explorer Modal

**Purpose**: Browse TSW API paths and select endpoints for lever configuration.

**Features**:
- Hierarchical navigation using `Client.list(path)`
- Breadcrumb navigation
- Fuzzy search filter
- Show read-only vs writable status
- Preview current values
- Select button to confirm path

**Implementation**:
- Uses `TswIo.Simulator.Client.list/2` for node discovery
- Uses `TswIo.Simulator.Client.get/2` for value preview
- State tracks: current_path, nodes, search_term, selected_field

---

## Phase 10: Navigation Updates

### NavComponents

Add "Trains" as top-level nav item:
```heex
<.link navigate={~p"/trains"} class="btn btn-ghost">
  Trains
</.link>
```

Position: After "Devices" button, before "Simulator" dropdown.

### NavHook

Add to `on_mount`:
1. Subscribe to `TswIo.Train.subscribe()`
2. Assign `nav_current_identifier` and `nav_active_train`

Handle events:
- `{:train_detected, ...}` → update assigns
- `{:train_changed, ...}` → update assigns

---

## Phase 11: Supervision Tree

Add to `lib/tsw_io/application.ex`:

```elixir
children = [
  # ... existing ...
  TswIo.Train.Detection,
  TswIo.Train.Calibration.SessionSupervisor,
]
```

---

## Phase 12: Notch Visualization Component

### `TswIoWeb.LeverComponents`

**File**: `lib/tsw_io_web/components/lever_components.ex`

**Purpose**: Visual representation of lever notches with clear type differentiation.

**Design**:
- Two-view approach: Compact badges for overview + detailed cards for full information
- Color coding: Primary (blue) for gates, Info (cyan) for linear ranges
- Description support: Optional user-provided descriptions shown in expanded view
- Range visualization: Linear notches get a proportional bar showing their range

**Components**:
```elixir
# Main component
<.lever_notches notches={@notches} />

# Shows:
# 1. Compact timeline with numbered badges: [1] [2] [3]
# 2. Detailed cards for each notch with:
#    - Type badge (Gate/Linear)
#    - Value(s) display
#    - Description if provided
#    - Range bar for linear notches
```

**Notch Card Structure**:
```heex
<div class="card bg-base-100 border border-base-300">
  <div class="card-body p-4">
    <div class="flex items-start justify-between">
      <h4 class="font-semibold">Notch {index}: {title}</h4>
      <span class={notch_type_badge(@notch.type)} />
    </div>

    <!-- Value display -->
    <div class="mt-3 p-2 bg-base-200 rounded text-sm font-mono">
      <!-- Gate: single value -->
      <!-- Linear: min/max values -->
    </div>

    <!-- Description if provided -->
    <div :if={@notch.description} class="mt-3">
      <p class="text-sm">{@notch.description}</p>
    </div>

    <!-- Range bar for linear notches -->
    <div :if={@notch.type == :linear} class="mt-3">
      <.range_bar min_value={@notch.min_value} max_value={@notch.max_value} />
    </div>
  </div>
</div>
```

---

## Implementation Order

1. **Database & Schemas** (Phase 1-2)
   - Create 4 migrations (trains, train_elements, train_lever_configs, train_lever_notches)
   - Create schema modules (Train, Element, LeverConfig, Notch, Identifier)
   - Run migrations

2. **Context & Detection** (Phase 3-4)
   - Create Train context
   - Create Identifier module
   - Create Detection GenServer
   - Add to supervision tree

3. **Basic LiveViews** (Phase 6-8 partial)
   - Create TrainListLive (basic list)
   - Create TrainEditLive (basic form)
   - Add routes
   - Update navigation

4. **Element Management** (Phase 8)
   - Add element modal
   - Lever settings modal
   - Element deletion

5. **API Explorer** (Phase 9)
   - Create modal component
   - Implement path browsing
   - Wire up to lever settings

6. **Calibration** (Phase 5, Phase 8, Phase 12)
   - Create LeverSession GenServer
   - Create SessionSupervisor
   - Create LeverComponents for notch visualization
   - Add calibration progress modal
   - Wire up start/progress/result flow

7. **Detection Integration** (Phase 7, Phase 10)
   - Add banner prompt for unconfigured trains
   - Update NavHook for train detection
   - Active train highlighting

8. **Polish**
   - Error handling
   - Loading states
   - Run `mix precommit`

---

## Critical Files Reference

**Patterns to follow**:
- `lib/tsw_io/hardware.ex` - Context structure
- `lib/tsw_io/hardware/configuration_manager.ex` - GenServer with PubSub
- `lib/tsw_io/simulator/client.ex` - API client usage
- `lib/tsw_io/simulator/connection.ex` - Connection state management
- `lib/tsw_io_web/live/configuration_edit_live.ex` - Modal patterns, forms
- `lib/tsw_io_web/live/configuration_list_live.ex` - List view with active highlighting

**New files to create**:
- `lib/tsw_io/train/train.ex` - Train schema
- `lib/tsw_io/train/element.ex` - Element schema with Ecto.Enum type
- `lib/tsw_io/train/lever_config.ex` - LeverConfig schema with has_many notches
- `lib/tsw_io/train/notch.ex` - Notch schema (relational table with description)
- `lib/tsw_io/train/identifier.ex` - Train identifier derivation
- `lib/tsw_io/train/detection.ex` - Detection GenServer
- `lib/tsw_io/train/calibration/lever_session.ex` - Calibration session
- `lib/tsw_io/train/calibration/session_supervisor.ex` - Dynamic supervisor
- `lib/tsw_io/train.ex` - Train context module
- `lib/tsw_io_web/live/train_list_live.ex` - Train list LiveView
- `lib/tsw_io_web/live/train_edit_live.ex` - Train edit LiveView
- `lib/tsw_io_web/components/lever_components.ex` - Notch visualization

**Files to modify**:
- `lib/tsw_io/application.ex` - Add new supervisors
- `lib/tsw_io_web/router.ex` - Add train routes
- `lib/tsw_io_web/live/nav_hook.ex` - Train detection state
- `lib/tsw_io_web/components/nav_components.ex` - Add Trains nav item
