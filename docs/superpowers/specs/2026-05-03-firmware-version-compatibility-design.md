# Firmware Version Compatibility — Design

## Problem

The Trenino app currently offers to install any firmware release published to the GitHub repo, regardless of whether the running app version actually supports that firmware's protocol/manifest format. With a breaking firmware change on the horizon, an out-of-date app could happily flash a v2 firmware it does not understand and brick the user's device interaction.

## Goal

Let the app declare which firmware versions it is compatible with, and surface that information clearly in the UI so users understand why a release is unavailable to them.

## Approach

Single source of truth lives in the app: a configurable semver requirement string in `config/config.exs`, evaluated with Elixir's standard `Version` / `Version.Requirement` machinery. Incompatible releases stay visible (so the user can see *why* an update isn't being offered), but install actions are disabled and update notifications skip them.

## Configuration

```elixir
# config/config.exs
config :trenino, :firmware_version_requirement, "~> 1.0"
```

- Parsed once via `Version.parse_requirement!/1`. Invalid syntax raises at boot — this is developer config, fail-fast is correct.
- `nil` (key unset) means *everything is compatible*. Preserves current behavior in dev/test environments that don't set the key.
- The actual requirement shipped with the v1.x line of the app will be tightened to a real range (e.g. `">= 1.0.0 and < 2.0.0"`) before the breaking v2 firmware ships. Picking the exact requirement is out of scope for this design — that's a release-engineering call.

## New module: `Trenino.Firmware.Compatibility`

Small, single-purpose, easy to test in isolation.

```elixir
defmodule Trenino.Firmware.Compatibility do
  alias Trenino.Firmware.FirmwareRelease

  @spec requirement() :: Version.Requirement.t() | nil
  @spec compatible?(FirmwareRelease.t() | String.t()) :: boolean()
end
```

Behavior:

- `requirement/0` reads `Application.get_env(:trenino, :firmware_version_requirement)` and parses on demand. (Cheap; no need for a GenServer-cached value.)
- `compatible?/1` strips a leading `"v"` from the version string, parses with `Version.parse/1`, and runs `Version.match?/2` against the requirement. Returns:
  - `true` if requirement is `nil`
  - `true` if version parses and matches
  - `false` if version is malformed *or* doesn't match (today, malformed versions are silently treated as "needs update", which is unsafe — better to refuse to flash).

## Integration points

### `FirmwareRelease` schema

Add a virtual field:

```elixir
field :compatible, :boolean, virtual: true, default: true
```

Populate via a small helper (`Compatibility.annotate/1` taking a release or list) called by callers that need the flag for UI rendering. We don't auto-populate inside the context functions — keeping the schema's stored vs derived fields explicit.

### `Firmware` context

- `get_latest_release/1` — unchanged. Returns the latest release by `published_at`, regardless of compatibility. Existing callers and tests keep working.
- New: `get_latest_compatible_release/1` — same shape, but returns `{:error, :not_found}` if no compatible release exists. Used by the update-check path.

### `UpdateChecker`

- The `device_needs_update?/2` check additionally requires the candidate version to be compatible. (Or, equivalently, the checker uses `get_latest_compatible_release/1` when deciding what `latest_version` to broadcast.)
- Releases outside the supported range never produce a `:firmware_update_available` notification.

### UI (`firmware_live.ex` and related templates)

For each release row in the firmware list:

- Add an "Incompatible" badge when `release.compatible == false`.
- Disable install buttons for any `FirmwareFile` whose parent release is incompatible.
- Show a tooltip / inline note next to the disabled button:
  > *Requires app update — this firmware is outside the supported range (`<requirement>`).*

The exact requirement string is included in the message so users / support can see what's expected.

## Edge cases

| Case | Behavior |
|---|---|
| `firmware_version_requirement` unset | All releases compatible. |
| Requirement string invalid | App fails to boot. Caught in dev/CI before ship. |
| Release `version` is non-semver (e.g. `"1.2"`) | Treated as incompatible, badge shown. (Today these would silently slip through `version_older_than?`'s "assume update needed" branch.) |
| Pre-release versions (`"2.0.0-rc1"`) | Standard `Version.match?/2` semantics — pre-releases don't match unless the requirement explicitly allows them (`"~> 2.0-rc"`). Documented in the test table. |

## Testing

- `test/trenino/firmware/compatibility_test.exs` — table-driven `compatible?/1` cases:
  - nil requirement + any version → true
  - in-range, out-of-range, exact match
  - leading `v`
  - malformed version → false
  - pre-release behavior
- `test/trenino/firmware/update_checker_test.exs` — extend with:
  - latest release outside range → no `:firmware_update_available` broadcast
  - latest release inside range → notification as today
  - newest release incompatible but an older one is compatible → no notification (we don't downgrade-offer)
- `test/trenino_web/live/firmware_live_test.exs` — assert the "Incompatible" badge renders and the install button is disabled for an out-of-range release.

## Out of scope

- Picking the actual requirement value to ship — that's a release-engineering decision tied to when v2 firmware lands.
- Manifest-side declaration of required app version (option B from brainstorming).
- Auto-updating the app itself in response to a newer-than-supported firmware.
