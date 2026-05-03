# Display UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three UI issues in the I2C display configuration: brightness slider, button alignment, and a timed display test.

**Architecture:** All changes are in two LiveView files. The `I2cModuleFormComponent` gets a percentage slider for brightness; `ConfigurationEditLive` gets the alignment fix, an updated brightness display, and a new display test feature with timed `Process.send_after` sequencing.

**Tech Stack:** Elixir/Phoenix LiveView, DaisyUI, `Trenino.Hardware.HT16K33`, `Trenino.Hardware.write_segments/3`

---

## File Map

- Modify: `lib/trenino_web/live/components/i2c_module_form_component.ex` — brightness slider (0–100%), pct↔wire conversion
- Modify: `lib/trenino_web/live/configuration_edit_live.ex` — brightness % in table, button alignment fix, display test column + event handler + handle_info

---

### Task 1: Brightness slider in I2cModuleFormComponent

**Files:**
- Modify: `lib/trenino_web/live/components/i2c_module_form_component.ex`

The stored `brightness` is 0–15. The slider shows 0–100. Conversion:
- display pct: `round(wire * 100 / 15)` — e.g. wire=8 → 53%
- save wire: `round(pct * 15 / 100)` — e.g. pct=53 → 8

- [ ] **Step 1: Add `brightness_pct` assign in `update/2`**

Replace the existing `update/2` clause with one that initialises `brightness_pct`:

```elixir
@impl true
def update(%{i2c_module: mod, device_id: device_id} = _assigns, socket) do
  changeset = I2cModule.changeset(mod || %I2cModule{}, %{})
  wire = (mod && mod.brightness) || 8
  brightness_pct = round(wire * 100 / 15)

  {:ok,
   socket
   |> assign(:i2c_module, mod)
   |> assign(:device_id, device_id)
   |> assign(:form, to_form(changeset))
   |> assign(:brightness_pct, brightness_pct)
   |> assign(
     :i2c_address_input,
     if(mod, do: I2cModule.format_i2c_address(mod.i2c_address), else: "")
   )}
end
```

- [ ] **Step 2: Update `coerce_params/1` to convert `brightness_pct` → `brightness`**

```elixir
defp coerce_params(params) do
  addr_str = Map.get(params, "i2c_address_raw", "")

  addr =
    case I2cModule.parse_i2c_address(addr_str) do
      {:ok, n} -> n
      :error -> nil
    end

  pct =
    case Integer.parse(Map.get(params, "brightness_pct", "53")) do
      {n, ""} -> n
      _ -> 53
    end

  brightness = round(pct * 15 / 100)

  params
  |> Map.put("i2c_address", addr)
  |> Map.put("brightness", brightness)
  |> Map.take(["name", "module_chip", "i2c_address", "brightness", "num_digits"])
  |> Enum.reduce(%{}, fn {k, v}, acc ->
    Map.put(acc, String.to_existing_atom(k), v)
  end)
end
```

- [ ] **Step 3: Update `validate` handler to keep `brightness_pct` in sync**

```elixir
@impl true
def handle_event("validate", %{"i2c_module" => params}, socket) do
  pct =
    case Integer.parse(Map.get(params, "brightness_pct", "53")) do
      {n, ""} -> n
      _ -> 53
    end

  changeset =
    (socket.assigns.i2c_module || %I2cModule{})
    |> I2cModule.changeset(coerce_params(params))
    |> Map.put(:action, :validate)

  {:noreply,
   socket
   |> assign(:form, to_form(changeset))
   |> assign(:brightness_pct, pct)
   |> assign(:i2c_address_input, Map.get(params, "i2c_address_raw", ""))}
end
```

- [ ] **Step 4: Replace the brightness number input with a range slider in `render/1`**

Replace the entire brightness `<div>` (currently inside the `grid grid-cols-2` block):

```heex
<div>
  <label class="label">
    <span class="label-text font-medium">Brightness</span>
    <span class="label-text-alt text-base-content/50">{@brightness_pct}%</span>
  </label>
  <input
    type="range"
    name="i2c_module[brightness_pct]"
    value={@brightness_pct}
    min="0"
    max="100"
    class="range range-sm w-full"
  />
</div>
```

- [ ] **Step 5: Verify with `mix precommit`**

```bash
cd /Users/alberto/repos/arestifo/trenino && mix precommit
```

Expected: all checks pass, no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/trenino_web/live/components/i2c_module_form_component.ex
git commit -m "feat: replace brightness number input with 0-100% slider"
```

---

### Task 2: Fix button alignment and update brightness display in the I2C modules table

**Files:**
- Modify: `lib/trenino_web/live/configuration_edit_live.ex`

Two changes in `i2c_modules_section`:
1. The `<td class="text-right">` that wraps the edit/delete buttons should use `<div class="flex gap-1">` instead (matching all other tables).
2. The brightness column should display "X%" instead of the raw 0–15 number.

- [ ] **Step 1: Fix brightness display and button alignment in `i2c_modules_section`**

Find the `<tbody>` rows block inside `i2c_modules_section` (around line 1461). Replace the entire `<tr :for=...>` block:

```heex
<tr :for={mod <- @i2c_modules} class="hover:bg-base-200/50">
  <td>{mod.name || "—"}</td>
  <td class="uppercase text-xs">{mod.module_chip}</td>
  <td class="font-mono">{I2cModule.format_i2c_address(mod.i2c_address)}</td>
  <td>{mod.num_digits}</td>
  <td>{round((mod.brightness || 8) * 100 / 15)}%</td>
  <td>
    <div class="flex gap-1">
      <button
        phx-click="open_edit_i2c_modal"
        phx-value-id={mod.id}
        class="btn btn-ghost btn-xs"
      >
        <.icon name="hero-pencil" class="w-3.5 h-3.5" />
      </button>
      <button
        phx-click="delete_i2c_module"
        phx-value-id={mod.id}
        data-confirm="Delete this I2C module?"
        class="btn btn-ghost btn-xs text-error"
      >
        <.icon name="hero-trash" class="w-3.5 h-3.5" />
      </button>
    </div>
  </td>
</tr>
```

- [ ] **Step 2: Verify with `mix precommit`**

```bash
cd /Users/alberto/repos/arestifo/trenino && mix precommit
```

Expected: all checks pass.

- [ ] **Step 3: Commit**

```bash
git add lib/trenino_web/live/configuration_edit_live.ex
git commit -m "fix: brightness as percentage and align I2C module table buttons"
```

---

### Task 3: Display test — timed sequence

**Files:**
- Modify: `lib/trenino_web/live/configuration_edit_live.ex`

Adds a "Test" column to the I2C modules table (only when `active_port` is set), an event handler, and a `handle_info` clause that advances through test steps.

Test sequence (one step per second):
- step 0 (immediate): all-8s (e.g. "8888" / "88888888")
- step 1 (+1s): "1234" / "12345678"
- step 2 (+2s): "ABCD" / "ABCDEFGH"
- step 3 (+3s): blank

The LiveView needs `alias Trenino.Hardware.HT16K33` added to the alias block.

- [ ] **Step 1: Add `HT16K33` alias**

In `configuration_edit_live.ex`, find the alias block near the top. Add `HT16K33` to the existing `Hardware` aliases:

```elixir
alias Trenino.Hardware.{ConfigId, Device, HT16K33, I2cModule, Input, Output}
```

- [ ] **Step 2: Add `active_port` attr and Test column to `i2c_modules_section`**

Update the `i2c_modules_section` component attr declarations (add `active_port`):

```elixir
attr :i2c_modules, :list, required: true
attr :new_mode, :boolean, required: true
attr :active_port, :string, default: nil
```

Add a Test column header in the `<thead>` (after the Brightness `<th>` and before the empty actions `<th>`):

```heex
<th :if={@active_port} class="text-center">Test</th>
```

Add a Test cell in the `<tr :for=...>` row (after the brightness `<td>` and before the actions `<td>`):

```heex
<td :if={@active_port} class="text-center">
  <button
    phx-click="test_display"
    phx-value-id={mod.id}
    class="btn btn-ghost btn-xs text-primary hover:bg-primary/10"
    title="Run test sequence"
  >
    <.icon name="hero-play" class="w-3.5 h-3.5" /> Test
  </button>
</td>
```

The full updated `i2c_modules_section` component after both Task 2 and Task 3 changes applied:

```elixir
attr :i2c_modules, :list, required: true
attr :new_mode, :boolean, required: true
attr :active_port, :string, default: nil

defp i2c_modules_section(assigns) do
  ~H"""
  <div>
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-base font-semibold">I2C Modules</h3>
      <button
        type="button"
        phx-click="open_add_i2c_modal"
        class="btn btn-outline btn-sm"
        disabled={@new_mode}
      >
        <.icon name="hero-plus" class="w-4 h-4" /> Add Module
      </button>
    </div>

    <.empty_collection_state
      :if={Enum.empty?(@i2c_modules)}
      icon="hero-cpu-chip"
      message="No I2C modules configured"
      submessage="Add a display module to show simulator values"
    />

    <div :if={not Enum.empty?(@i2c_modules)} class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th>Name</th>
            <th>Chip</th>
            <th>Address</th>
            <th>Digits</th>
            <th>Brightness</th>
            <th :if={@active_port} class="text-center">Test</th>
            <th class="w-20"></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={mod <- @i2c_modules} class="hover:bg-base-200/50">
            <td>{mod.name || "—"}</td>
            <td class="uppercase text-xs">{mod.module_chip}</td>
            <td class="font-mono">{I2cModule.format_i2c_address(mod.i2c_address)}</td>
            <td>{mod.num_digits}</td>
            <td>{round((mod.brightness || 8) * 100 / 15)}%</td>
            <td :if={@active_port} class="text-center">
              <button
                phx-click="test_display"
                phx-value-id={mod.id}
                class="btn btn-ghost btn-xs text-primary hover:bg-primary/10"
                title="Run test sequence"
              >
                <.icon name="hero-play" class="w-3.5 h-3.5" /> Test
              </button>
            </td>
            <td>
              <div class="flex gap-1">
                <button
                  phx-click="open_edit_i2c_modal"
                  phx-value-id={mod.id}
                  class="btn btn-ghost btn-xs"
                >
                  <.icon name="hero-pencil" class="w-3.5 h-3.5" />
                </button>
                <button
                  phx-click="delete_i2c_module"
                  phx-value-id={mod.id}
                  data-confirm="Delete this I2C module?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="hero-trash" class="w-3.5 h-3.5" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  """
end
```

- [ ] **Step 3: Pass `active_port` when calling `i2c_modules_section`**

Find the call site in the `render/1` function (around line 936) and add `active_port`:

```heex
<div class="bg-base-200/50 rounded-xl p-6 mt-6">
  <.i2c_modules_section
    i2c_modules={@i2c_modules}
    new_mode={@new_mode}
    active_port={@active_port}
  />
</div>
```

- [ ] **Step 4: Add the `test_display` event handler**

Add this `handle_event` clause alongside the other I2C module events (after `handle_event("delete_i2c_module", ...)`):

```elixir
@impl true
def handle_event("test_display", %{"id" => id_str}, socket) do
  mod = Enum.find(socket.assigns.i2c_modules, &(&1.id == String.to_integer(id_str)))

  if mod && socket.assigns.active_port do
    port = socket.assigns.active_port
    texts = display_test_texts(mod.num_digits)
    first = List.first(texts)
    bytes = HT16K33.encode_string(first, mod.num_digits)
    Hardware.write_segments(port, mod.i2c_address, bytes)

    texts
    |> Enum.with_index(1)
    |> Enum.each(fn {_text, step} ->
      Process.send_after(self(), {:display_test_step, mod.id, step}, step * 1000)
    end)
  end

  {:noreply, socket}
end
```

- [ ] **Step 5: Add the `handle_info` clause for display test steps**

Add alongside the other `handle_info` clauses (before the catch-all `handle_info(_msg, socket)`):

```elixir
@impl true
def handle_info({:display_test_step, mod_id, step}, socket) do
  mod = Enum.find(socket.assigns.i2c_modules, &(&1.id == mod_id))

  if mod && socket.assigns.active_port do
    texts = display_test_texts(mod.num_digits)

    case Enum.at(texts, step) do
      nil ->
        :ok

      text ->
        bytes = HT16K33.encode_string(text, mod.num_digits)
        Hardware.write_segments(socket.assigns.active_port, mod.i2c_address, bytes)
    end
  end

  {:noreply, socket}
end
```

- [ ] **Step 6: Add the `display_test_texts/1` private helper**

Add near the other private helpers at the bottom of `configuration_edit_live.ex`:

```elixir
defp display_test_texts(4), do: ["8888", "1234", "ABCD", "    "]
defp display_test_texts(8), do: ["88888888", "12345678", "ABCDEFGH", "        "]
defp display_test_texts(_), do: ["8888", "1234", "ABCD", "    "]
```

- [ ] **Step 7: Verify with `mix precommit`**

```bash
cd /Users/alberto/repos/arestifo/trenino && mix precommit
```

Expected: all checks pass, no Credo warnings.

- [ ] **Step 8: Commit**

```bash
git add lib/trenino_web/live/configuration_edit_live.ex
git commit -m "feat: add timed display test sequence to I2C modules table"
```
