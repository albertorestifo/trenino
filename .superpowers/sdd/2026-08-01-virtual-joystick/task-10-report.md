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

## Fix Round 1

- Clarified that virtual joystick driver lifecycle support requires the Windows
  NSIS `.exe`; the MSI does not execute the vJoy install, ownership, or safe
  shared-driver uninstall hooks.
- Split recovery guidance: missing driver state uses **Check installation**;
  incompatible device state uses **Check configuration**.
- Re-ran diff and required-topic sanity checks. No Windows VM result is claimed.
