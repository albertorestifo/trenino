# Multiple Train Identifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow each train profile to own multiple equivalent, globally unique identifier prefixes with no primary identifier.

**Architecture:** Replace `trains.identifier` with a normalized `train_identifiers` association and use nested Ecto changesets for atomic profile edits. Detection matches every associated prefix and deduplicates by train ID; LiveView, HTTP, and MCP consumers load the association and expose deterministic string lists.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, SQLite, ExUnit, Phoenix LiveViewTest

**Spec:** `docs/superpowers/specs/2026-09-27-multiple-train-identifiers-design.md`

## Global Constraints

- Every train profile has at least one identifier and no identifier is primary or canonical.
- An exact, trimmed, non-empty identifier belongs to only one train profile.
- Identifier prefix matching remains case-sensitive.
- Multiple matching identifiers from one profile resolve to that profile; matches from different profiles remain ambiguous.
- HTTP and MCP train representations expose only `identifiers: string[]`; the singular field is removed.
- Existing data must migrate without losing the current identifier.

## Review Focus

- Leading and trailing whitespace is removed, while whitespace-only identifiers are rejected; Task 1 pins both cases.
- Reordering identifiers does not change their meaning or lose rows; Task 1 verifies an update with reversed nested parameters.
- A failed conflicting update preserves the profile's previous identifier set; Task 1 verifies transaction rollback.
- Two overlapping prefixes owned by one profile produce one match; Task 2 verifies train-ID deduplication.
- API and MCP arrays are sorted regardless of association load order; Task 4 verifies deterministic output.

---

### Task 1: Normalized Identifier Persistence

**Files:**
- Create: `priv/repo/migrations/20260927000000_create_train_identifiers.exs`
- Create: `lib/trenino/train/train_identifier.ex`
- Create: `test/trenino/repo/migrations/create_train_identifiers_test.exs`
- Create: `test/trenino/train/train_identifier_persistence_test.exs`
- Modify: `lib/trenino/train/train.ex`
- Modify: `lib/trenino_web/live/train_edit_live.ex` (new-profile struct construction only)

**Interfaces:**
- Produces: `Trenino.Train.TrainIdentifier.changeset/2` for one trimmed identifier.
- Produces: `Train.changeset/2` consuming `identifiers: [%{id: integer() | nil, identifier: String.t()}]` nested parameters.
- Produces: `Train.identifier_values/1 :: [String.t()]`, returning loaded identifiers sorted lexically.

- [ ] **Step 1: Write the migration and schema tests**

Add a migration test that starts a temporary SQLite repo, migrates through `20260801000000`, inserts a train with `identifier = "RVM_FSN_DB_BR423"`, runs migration `20260927000000`, and asserts:

```elixir
assert [["RVM_FSN_DB_BR423"]] ==
         query_rows("SELECT identifier FROM train_identifiers WHERE train_id = ?", [train_id])

refute "identifier" in table_columns("trains")
assert_raise RuntimeError, ~r/cannot.*primary identifier/i, fn -> rollback_new_migration() end
```

In `train_identifier_persistence_test.exs`, add assertions for trimming, at least one identifier, duplicate values within a profile, cross-profile uniqueness, reordered updates, and failed-update rollback:

```elixir
attrs = %{name: "BR 423", identifiers: [%{identifier: " RVM_FSN_DB_BR423 "}]}
assert {:ok, train} = TrainContext.create_train(attrs)
assert ["RVM_FSN_DB_BR423"] == train |> Repo.preload(:identifiers) |> Train.identifier_values()
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `mix test test/trenino/repo/migrations/create_train_identifiers_test.exs test/trenino/train/train_identifier_persistence_test.exs`

Expected: FAIL because the migration, schema, association, and collection validations do not exist.

- [ ] **Step 3: Implement the irreversible data migration**

Create `Trenino.Repo.Migrations.CreateTrainIdentifiers` with `up/0` that creates the table and `train_id` index, adds the global unique index on `identifier`, copies existing values with explicit UTC timestamps, then removes `trains.identifier`. Implement `down/0` by raising a descriptive error because restoring one value would invent a primary identifier and could discard data.

- [ ] **Step 4: Implement the schemas and nested validation**

Implement `TrainIdentifier.changeset/2` with `cast`, whitespace trimming, `validate_required(:identifier)`, and `unique_constraint(:identifier)`. Change `Train` to `has_many :identifiers, TrainIdentifier, on_replace: :delete`, cast that association with `sort_param: :identifiers_sort` and `drop_param: :identifiers_drop`, reject an empty collection, detect duplicates within the submitted profile, and implement sorted `identifier_values/1`.

Update only the new-profile construction in `TrainEditLive` to seed `%Train{identifiers: [%TrainIdentifier{identifier: identifier}]}` so removing the schema field does not leave an invalid struct literal; the complete form change remains in Task 3.

- [ ] **Step 5: Run the focused tests and commit**

Run: `mix test test/trenino/repo/migrations/create_train_identifiers_test.exs test/trenino/train/train_identifier_persistence_test.exs`

Expected: PASS.

```bash
git add priv/repo/migrations/20260927000000_create_train_identifiers.exs lib/trenino/train/train_identifier.ex lib/trenino/train/train.ex lib/trenino_web/live/train_edit_live.ex test/trenino/repo/migrations/create_train_identifiers_test.exs test/trenino/train/train_identifier_persistence_test.exs
git commit -m "feat: normalize train identifiers"
```

### Task 2: Multi-Identifier Detection

**Files:**
- Modify: `lib/trenino/train.ex`
- Create: `test/trenino/train/train_identifier_matching_test.exs`
- Modify: `test/trenino/train/detection_test.exs`

**Interfaces:**
- Consumes: `Train.identifiers` and `Train.identifier_values/1` from Task 1.
- Produces: unchanged `get_train_by_identifier/1` result contract with matches evaluated across all associated identifiers.

- [ ] **Step 1: Write failing matching tests**

Cover unrelated aliases, suffix prefix matching, case sensitivity, same-profile overlap, and cross-profile ambiguity:

```elixir
assert {:ok, %{id: ^train_id}} =
         TrainContext.get_train_by_identifier("RVM_OTHER_DB_BR423_VARIANT")

assert {:error, :not_found} =
         TrainContext.get_train_by_identifier("rvm_other_db_br423_variant")

assert {:error, {:multiple_matches, matches}} =
         TrainContext.get_train_by_identifier("RVM_DB_BR423_RED_VARIANT")
assert Enum.sort(Enum.map(matches, & &1.id)) == Enum.sort([first.id, second.id])
```

The same-profile overlap fixture owns both `RVM_DB_BR423` and `RVM_DB_BR423_RED` and must return that profile once.

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `mix test test/trenino/train/train_identifier_matching_test.exs test/trenino/train/detection_test.exs`

Expected: FAIL because lookup still reads a singular train field.

- [ ] **Step 3: Implement association-based matching**

Update `get_train_by_identifier/1` to preload identifier rows, select trains for which any stored value is a prefix of the detected value, deduplicate by train ID, and retain the existing element/lever-config preload and return tuples. Update the function documentation with the multi-route BR423 example.

- [ ] **Step 4: Run detection tests and commit**

Run: `mix test test/trenino/train/train_identifier_matching_test.exs test/trenino/train/detection_test.exs`

Expected: PASS.

```bash
git add lib/trenino/train.ex test/trenino/train/train_identifier_matching_test.exs test/trenino/train/detection_test.exs
git commit -m "feat: match all train profile identifiers"
```

### Task 3: Dynamic Identifier Editor and Train List

**Files:**
- Modify: `lib/trenino_web/live/train_edit_live.ex`
- Modify: `lib/trenino_web/live/train_list_live.ex`
- Modify: `lib/trenino_web/components/shared_components.ex`
- Modify: `test/trenino_web/live/train_edit_live_test.exs`
- Modify: `test/trenino_web/live/train_list_live_test.exs`

**Interfaces:**
- Consumes: nested `identifiers`, `identifiers_sort`, and `identifiers_drop` parameters supported by `Train.changeset/2`.
- Consumes: `Train.identifier_values/1` for display.
- Produces: repeatable form inputs named `train[identifiers][N][identifier]` with add/remove controls.

- [ ] **Step 1: Write failing LiveView tests**

Test that a detected identifier seeds the first nested input, a blank form has one empty input, two identifiers can be created, one can be removed on edit, the last cannot be removed and saved, and a conflicting identifier renders its validation error. Assert persisted values through `Train.identifier_values/1` after preloading.

Add train-list assertions that every identifier is visible and the ambiguity banner lists all identifiers for each matching profile.

- [ ] **Step 2: Run the LiveView tests to verify they fail**

Run: `mix test test/trenino_web/live/train_edit_live_test.exs test/trenino_web/live/train_list_live_test.exs`

Expected: FAIL because the views still use `train.identifier`.

- [ ] **Step 3: Implement the repeatable nested form**

Seed new profiles with `%TrainIdentifier{identifier: params["identifier"] || ""}` and preload `:identifiers` for existing profiles. Replace the singular input with `<.inputs_for>` rows, hidden `identifiers_sort` inputs, remove buttons posting `identifiers_drop`, and an add button posting `identifiers_sort=new`; retain field-level child errors and explain that every value is an equivalent prefix.

- [ ] **Step 4: Update train-list presentation**

Preload identifiers with elements, display the sorted values without implying a primary, and update ambiguity copy and the shared-component documentation example to use an identifier collection.

- [ ] **Step 5: Run the LiveView tests and commit**

Run: `mix test test/trenino_web/live/train_edit_live_test.exs test/trenino_web/live/train_list_live_test.exs`

Expected: PASS.

```bash
git add lib/trenino_web/live/train_edit_live.ex lib/trenino_web/live/train_list_live.ex lib/trenino_web/components/shared_components.ex test/trenino_web/live/train_edit_live_test.exs test/trenino_web/live/train_list_live_test.exs
git commit -m "feat: edit multiple train identifiers"
```

### Task 4: Breaking HTTP and MCP Contract

**Files:**
- Modify: `lib/trenino_web/controllers/api/train_api_controller.ex`
- Modify: `lib/trenino/mcp/tools/train_tools.ex`
- Create: `test/trenino_web/controllers/api/train_api_controller_test.exs`
- Modify: `test/trenino/mcp/tools/train_tools_test.exs`

**Interfaces:**
- Consumes: `Train.identifier_values/1` and explicit `:identifiers` preloads.
- Produces: train maps containing `identifiers: [String.t()]` and no `identifier` key.

- [ ] **Step 1: Write failing HTTP and MCP contract tests**

For both list and show/get operations, create identifiers in reverse lexical order and assert:

```elixir
assert result.identifiers == ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]
refute Map.has_key?(result, :identifier)
```

Use decoded string keys for controller JSON assertions. Keep the existing element, binding, sequence, and not-found assertions.

- [ ] **Step 2: Run the contract tests to verify they fail**

Run: `mix test test/trenino_web/controllers/api/train_api_controller_test.exs test/trenino/mcp/tools/train_tools_test.exs`

Expected: FAIL because serializers still emit the singular field.

- [ ] **Step 3: Implement array-only serialization**

Preload identifiers in each list/show query, replace `identifier` with sorted `identifiers` arrays, and update MCP tool descriptions to describe the new response. Do not emit a compatibility singular key.

- [ ] **Step 4: Run the contract tests and commit**

Run: `mix test test/trenino_web/controllers/api/train_api_controller_test.exs test/trenino/mcp/tools/train_tools_test.exs`

Expected: PASS.

```bash
git add lib/trenino_web/controllers/api/train_api_controller.ex lib/trenino/mcp/tools/train_tools.ex test/trenino_web/controllers/api/train_api_controller_test.exs test/trenino/mcp/tools/train_tools_test.exs
git commit -m "feat: expose train identifier arrays"
```

### Task 5: Caller Migration, Documentation, and Full Verification

**Files:**
- Modify: all remaining `test/**/*.exs` fixtures that create train profiles with singular `identifier` attributes
- Modify: `docs/train-configuration.md`
- Modify: `docs/architecture.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nested creation shape `identifiers: [%{identifier: value}]` from Task 1.
- Produces: a repository with no remaining train-profile reads or writes of singular `identifier`.

- [ ] **Step 1: Migrate remaining callers**

Use `rg -n 'identifier:|\.identifier\b' lib test` to inspect every result. Convert train creation/update fixtures to `identifiers: [%{identifier: value}]`, update assertions to preload and use `Train.identifier_values/1`, and leave unrelated hardware, firmware, simulator-state, and Tauri application identifiers unchanged.

- [ ] **Step 2: Verify no singular train-profile access remains**

Run: `rg -n 'train\.identifier|t\.identifier|result\.identifier|train\[identifier\]' lib test docs`

Expected: no train-profile access; any remaining result must be demonstrated to refer to the detected simulator identifier or a different domain concept.

- [ ] **Step 3: Update user and architecture documentation**

Document repeatable equivalent prefixes and the `RVM_FSN_DB_BR423`/`RVM_OTHER_DB_BR423` example in `docs/train-configuration.md`, update the train schema relationship in `docs/architecture.md`, and add the feature plus breaking HTTP/MCP contract to `CHANGELOG.md` under Unreleased.

- [ ] **Step 4: Format and run the complete test suite**

Run: `mix format`

Run: `mix test`

Expected: all tests pass with zero failures.

- [ ] **Step 5: Run project quality checks**

Run: `mix precommit`

Expected: compilation has no warnings, formatting is unchanged, Credo passes strictly, and all tests pass.

- [ ] **Step 6: Commit the completed migration**

```bash
git add test docs/train-configuration.md docs/architecture.md CHANGELOG.md
git commit -m "docs: document multiple train identifiers"
```

