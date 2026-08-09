# Task 10 report: documentation

## Documentation delivered

Updated the six Task 10 documents only:

- `README.md` introduces the Windows virtual joystick feature and links to the
  setup guide.
- `docs/getting-started.md` covers bundled-driver setup, mappings, exclusive
  destinations, UAC on enable/disable, `joy.cpl` verification, application
  shutdown behavior, busy-device recovery, cancellation, setup repair, and
  leftover-device cleanup.
- `docs/hardware-setup.md` explains calibration reuse, eight axes, 32 buttons,
  inversion, direct button state, disconnect safe state, and destination rules.
- `docs/architecture.md` records the Manager/Bridge/Configurator/Mapper
  boundaries, transactional routing, persistent Port, JSON Lines protocol, full
  native report, and supervision role. It also updates the MCP tool inventory.
- `docs/development.md` records native build/test commands, the trusted DLL path
  contract, Windows integration-test tag convention, checksum update procedure,
  non-mutating packaging CI, and shared-driver uninstall safeguards.
- `CHANGELOG.md` adds the feature under the existing Unreleased/Added convention.

## Accuracy notes

The user documentation states that closing Trenino while enabled resets the
report and relinquishes the feeder but intentionally leaves the requested device
enumerated. Disabling is the operation that removes it. It does not claim that
the Windows VM checklist or real driver lifecycle validation has run.

The developer documentation distinguishes ordinary hosted CI, which never
installs the driver, from `:windows_vjoy_integration` tests reserved for a
disposable elevated Windows VM.

## Verification

- Markdown whitespace/diff sanity: `git diff --check`.
- Confirmed all required user and developer terms appear in the six documents.
- Confirmed no implementation source was modified by this documentation task.

The broader Task 10 format, native, `mix precommit`, packaging, and Windows VM
verification are controller/release activities outside this documentation-only
assignment. No Windows VM result is claimed here.

## Final verification Fix Round 1

Implemented the feature-related strict Credo cleanup in commit
`a07992b refactor: satisfy virtual joystick quality checks`.

Baseline evidence:

- `mix credo --strict` exited 14 with 21 findings: 7 software-design
  suggestions, 3 readability issues, and 11 refactoring opportunities.
- Findings were confined to the virtual joystick implementation and its
  associated tests, including nested module calls, fixed-arity `apply/3`, deep
  transaction/configurator/test-fake nesting, alias ordering, and the Mix task
  module documentation.

Behavior-preserving changes:

- Extracted mapping and simulator-binding persistence helpers while retaining
  the SQLite `mode: :immediate` transaction boundaries, lock-before-conflict
  checks, rollback behavior, destination replacement ordering, and
  post-commit controller notifications.
- Replaced fixed-arity dynamic calls with direct calls through aliases; Manager
  and controller presence checks remain unchanged.
- Flattened Configurator create/delete/configure control flow without changing
  UAC, status polling, ownership-marker, or error propagation order.
- Extracted the Manager test fake's bridge-result branches, aliased the bridge
  Port adapter, alphabetized aliases, and documented the Mix task.
- Restored three unrelated files that the formatter touched; they are not part
  of this commit.

Verification evidence:

- `mix credo --strict`: exit 0, **found no issues**.
- Focused persistence, exclusivity, Configurator, Bridge, Manager, and LiveView
  suites: **162 passed**.
- `mix compile --warnings-as-errors`: passed.
- Formatting of all eight changed files and `git diff --check`: passed.

## Fix Round 1

- Clarified that virtual joystick driver lifecycle support requires the Windows
  NSIS `.exe`; the MSI does not execute the vJoy install, ownership, or safe
  shared-driver uninstall hooks.
- Split recovery guidance: missing driver state uses **Check installation**;
  incompatible device state uses **Check configuration**.
- Re-ran diff and required-topic sanity checks. No Windows VM result is claimed.
