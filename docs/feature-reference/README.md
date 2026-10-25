# Trenino feature and behavior reference

This is a source-grounded description of Trenino's existing Elixir/Phoenix application, intended to support a future implementation in another technology. It covers user workflows, user stories, feature internals, persistent data, protocols, runtime connections, failure paths and current implementation gaps.

**Reviewed source:** `master` commit [`188f35e4108733358730e92ebd98f1912af5173a`](https://github.com/albertorestifo/trenino/tree/188f35e4108733358730e92ebd98f1912af5173a), pulled from origin on **2026-10-25** (already up to date). Source package version: 0.8.0. These documents describe that source snapshot regardless of the branch on which the documents are stored. The code on `codex/rust-rewrite` was not reviewed.

## Reading paths

- Understand the system: [architecture and feature connections](architecture.md), then [data model](data-model.md).
- Reimplement behavior: read the relevant feature document below, its story collection, and [rewrite acceptance contracts](rewrite-contract.md).
- Reproduce integration: [serial bytes/framing](serial-protocol.md), [simulator HTTP contract](simulator.md), [app REST/MCP](api-and-mcp.md), [native joystick protocol](virtual-joystick.md).
- Trace a source file: [file-by-file source index](source-index.md), with review type and feature document for every tracked baseline file.
- Find an acceptance story: [user-story catalogue](user-stories.md).
- Check a stored field: [schema dictionary](schema-dictionary.md), then the feature document for validations and meaning.

## Feature catalogue

| ID | Feature and user outcome | Detailed reference | Stories |
|---|---|---|---|
| F-01 | Save/reuse named hardware configurations | [Hardware](hardware.md) | [HW](hardware-user-stories.md) |
| F-02 | Discover boards, identify firmware/configuration, monitor connection, rescan/retry | [Serial transport](serial-protocol.md) | [HW](hardware-user-stories.md) |
| F-03 | Configure analog inputs, sensitivity, digital buttons/debounce and labels | [Hardware](hardware.md) | [HW](hardware-user-stories.md) |
| F-04 | Create row/column matrices and individually bind virtual buttons | [Hardware](hardware.md) | [HW/UI](hardware-user-stories.md) |
| F-05 | Apply configurations with acknowledgments/errors and monitor raw values | [Hardware](hardware.md), [serial bytes](serial-protocol.md) | [HW](hardware-user-stories.md) |
| F-06 | Calibrate sensor bounds, direction and rollover; detect a physically moved input | [Hardware](hardware.md) | [HW](hardware-user-stories.md) |
| F-07 | Configure/test digital outputs and HT16K33 seven/fourteen-segment displays | [Hardware](hardware.md) | [HW](hardware-user-stories.md) |
| F-08 | Fetch manifest-based firmware releases and device definitions | [Firmware](firmware.md) | [FW](hardware-user-stories.md) |
| F-09 | Filter firmware compatibility, cache downloads, notify connected devices | [Firmware](firmware.md) | [FW](hardware-user-stories.md) |
| F-10 | Flash firmware, release serial ownership, follow bootloader COM changes, retry/cancel, keep history | [Firmware](firmware.md) | [FW/UI](hardware-user-stories.md) |
| F-11 | Configure simulator endpoint/key, discover key automatically, monitor/reconnect | [Simulator](simulator.md), [settings](desktop-and-operations.md) | [SIM/PLAT](train-user-stories.md) |
| F-12 | Browse/read/write simulator API and detect a manipulated control | [Simulator](simulator.md), [explorer UI](user-interface.md) | [SIM](train-user-stories.md) |
| F-13 | Create train profiles with multiple class-prefix identifiers and automatic selection | [Simulator detection](simulator.md), [profiles](train-profiles-and-controls.md) | [TR](train-user-stories.md) |
| F-14 | Create logical lever/button elements and assign hardware inputs | [Train controls](train-profiles-and-controls.md) | [TR](train-user-stories.md) |
| F-15 | Analyze discrete/continuous/hybrid game levers and map physical notch intervals | [Train calibration](train-profiles-and-controls.md) | [TR/SIM](train-user-stories.md) |
| F-16 | Drive game levers with normalized input, inversion, interpolation, write coalescing and retries | [Train runtime](train-profiles-and-controls.md) | [TR](train-user-stories.md) |
| F-17 | Drive button actions in simple, repeated, sequence or keystroke modes | [Buttons](train-profiles-and-controls.md), [key helper](desktop-and-operations.md) | [TR](train-user-stories.md) |
| F-18 | Create and execute ordered reusable endpoint/value sequences | [Sequences](scripting-and-sequences.md) | [AUTO](train-user-stories.md) |
| F-19 | Evaluate simulator conditions to drive real LEDs | [Output bindings](train-profiles-and-controls.md) | [TR](train-user-stories.md) |
| F-20 | Format live simulator values onto physical displays | [Display bindings](train-profiles-and-controls.md), [segment encoding](hardware.md) | [TR/HW](train-user-stories.md) |
| F-21 | Author Lua scripts with simulator endpoint triggers, state, scheduling and host effects | [Scripting](scripting-and-sequences.md), [editor](user-interface.md) | [AUTO](train-user-stories.md) |
| F-22 | Expose independent Windows joystick axes/buttons with calibration/inversion | [Virtual joystick](virtual-joystick.md) | [VJ](platform-user-stories.md) |
| F-23 | Replace conflicting simulator/joystick input destinations atomically | [Joystick transactions](virtual-joystick.md), [train bindings](train-profiles-and-controls.md) | [VJ/TR](platform-user-stories.md) |
| F-24 | Recover/remove joystick device, preserve confirmed state, reset on disconnect/exit | [Joystick lifecycle](virtual-joystick.md) | [VJ](platform-user-stories.md) |
| F-25 | First-run consent, persistent settings and optional error reporting | [Desktop/settings](desktop-and-operations.md), [UI](user-interface.md) | [PLAT/UI](platform-user-stories.md) |
| F-26 | Navigate live status, setup wizards, themes, modals, editors and feedback | [UI reference](user-interface.md) | [UI](interface-user-stories.md) |
| F-27 | Configure via REST and 47 MCP tools over SSE/JSON-RPC | [HTTP/MCP contract](api-and-mcp.md) | [API](interface-user-stories.md) |
| F-28 | Launch packaged backend, migrate data, probe readiness and shut down | [Desktop lifecycle](desktop-and-operations.md) | [PLAT](platform-user-stories.md) |
| F-29 | Notify about newer app versions or install signed stable native updates | [App updates](desktop-and-operations.md) | [PLAT](platform-user-stories.md) |
| F-30 | Install/uninstall Windows prerequisites while preserving shared vJoy state | [Distribution](desktop-and-operations.md) | [PLAT](platform-user-stories.md) |
| F-31 | Persist relationships and migrate historical data safely | [Data model](data-model.md), [schema dictionary](schema-dictionary.md) | [PLAT/TR](platform-user-stories.md) |
| F-32 | Build, test, package, sign and deliver stable/nightly artifacts | [Operations](desktop-and-operations.md) | [PLAT](platform-user-stories.md) |

## How to interpret the documents

Feature descriptions distinguish three kinds of evidence:

1. **Implemented behavior:** read from current source, with exact fields/defaults/algorithms/timers/state transitions where relevant.
2. **Test evidence:** existing tests that exercise or assert that contract. A cited test is not a new test run; fake hardware/game tests do not certify physical interoperability.
3. **Observed gap or historical intent:** a mismatch, missing path, unsupported operation or stale guide. These are explicitly called out so a rewrite does not accidentally turn an aspiration into a compatibility requirement.

Stories describe actors, preconditions, flows, acceptance criteria, failure cases and evidence. Cross-domain overlaps are intentional: UI stories describe interaction, while hardware/train/platform stories describe the underlying contract. The final [verification record](verification.md) records the documentation checks actually executed.

## Scope and provenance

The baseline contains **530 tracked files**. First-party application code, controllers, helpers, migrations and tests were reviewed by domain. Existing guides/plans/assistant instructions are recorded as references; historical reference-only material is outline-catalogued where it is not needed as implementation evidence. Dependency locks and generated schemas were parsed/inventoried; vendor static data and binary/icon assets are classified separately. The file index records these levels explicitly instead of treating assets or old plans as executable features.

Excluded from the baseline: ignored dependencies/build outputs, local SQLite databases, temporary files, existing untracked mechanical/rewrite plans and generated local Windows schema. Arduino firmware source is external to this repository; its required host wire contract is documented, but its internal implementation is not claimed. No code in the sibling tsw_board repository or the destination rewrite branch was inspected for this task.

The reference lives under `docs/feature-reference/`. Source links are pinned to the reviewed commit so they stay valid after source paths change in another branch. Local links between these documents remain relative. Publishing these files to the rewrite branch does not assert parity of that branch's implementation.
