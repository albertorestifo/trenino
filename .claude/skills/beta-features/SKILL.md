---
name: beta-features
description: Use when putting a Trenino feature behind a beta flag, taking one out of beta, or writing tests for a beta flag's off state.
---

# Beta features

Unfinished features are gated by `Trenino.Beta` (`lib/trenino/beta.ex`). The flags are listed in `@features` there. They are always on in dev and test (`config :trenino, :beta_features, :all`), and in releases they follow the "Enable beta features" toggle on the Settings page.

## Putting a feature behind beta

1. Add the flag to `@features` and to `@type feature` in `lib/trenino/beta.ex`, with a one-line comment saying what it covers.
2. Add a `beta_<feature>` assign in `TreninoWeb.NavHook.on_mount/4`, and gate LiveView entry points with it: `:if={@beta_<feature>}` on sections, `++ if(@beta_<feature>, do: [...], else: [])` on nav items and option lists. Outside LiveViews, call `Beta.enabled?(:<feature>)`.
3. Gate the feature's MCP tool modules by adding them to `@beta_tool_modules` in `lib/trenino/mcp/tool_registry.ex`. The hard-coded tool counts stay the same, because tests run with every flag on. Update the off-state count in `test/trenino/beta_test.exs` instead.
4. Gate entry points only: UI sections, menu options and MCP tools. Never gate contexts, schemas, GenServers or supervision children. Data that is already saved keeps working while the flag is off, and the screens for existing records stay reachable.
5. Add off-state tests to `test/trenino_web/live/beta_features_test.exs` or `test/trenino/beta_test.exs`. These tests switch the global mode with `Application.put_env(:trenino, :beta_features, :setting)`, so they are `async: false` and restore the previous value in `on_exit`.
6. Mention the feature in the Settings toggle's description, mark it "(beta)" in the README, and add a CHANGELOG entry.

## Taking a feature out of beta

Remove it from `@features`, delete every `beta_<feature>` and `Beta.enabled?(:<feature>)` match plus its `@beta_tool_modules` entries and off-state tests, then update the Settings description, README and CHANGELOG.
