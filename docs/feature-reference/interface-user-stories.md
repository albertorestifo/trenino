# Interface user stories and acceptance evidence

These stories describe the current baseline `188f35e4108733358730e92ebd98f1912af5173a`. Actor is the local operator unless otherwise stated. They are rewrite acceptance inputs, not claims that all paths have end-to-end automated tests. “Source only” explicitly identifies behavior without direct reviewed feature tests. UI detail is in [user interface](user-interface.md); wire schemas in [API/MCP](api-and-mcp.md). Runtime outcomes and domain constraints are expanded in [hardware](hardware.md), [firmware](firmware.md), [simulator](simulator.md), [train controls](train-profiles-and-controls.md), [scripting](scripting-and-sequences.md), [joystick](virtual-joystick.md), and [operations](desktop-and-operations.md).

## Browser stories

<a id="ui-001"></a>

### UI-001 — Make the first-run reporting choice

**Actor/preconditions:** Operator; reporting preference unset. **Steps:** Open any default-session page, arrive at `/consent`, read disclosure and choose Share error reports or No thanks. **Acceptance:** Either explicit choice is stored globally and redirects to `/`; subsequent normal pages render; `/consent` remains reviewable from Settings. **Errors/limits:** No retained intended destination; no incoming API/MCP consent gate; choice is not an account/login. **Evidence:** [gate](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/consent_gate_hook.ex), [page](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/consent_live.ex), [choice tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/consent_live_test.exs), [allow/redirect tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/consent_gate_hook_test.exs).

<a id="ui-002"></a>

### UI-002 — Discover and manage connected hardware from navigation

**Preconditions:** A normal page with nav handlers, reporting choice set. **Steps:** Open device dropdown, scan, observe ports/status/version, disconnect a connected device, follow firmware repair for a supported failure. **Acceptance:** Scan shows disabled Scanning… until scan_complete; live status/count updates, click-away closes; timeout/no-response failures offer Install Firmware with port query. **Errors/limits:** Failed reasons shown per row; initial rendering must remain possible while serial operations are busy. Script editor has missing shared nav actions, documented as a gap. **Evidence:** [nav hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/nav_hook.ex), [components](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/components/nav_components.ex), [scan tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/configuration_list_live_test.exs), [busy serial tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/nav_hook_test.exs).

<a id="ui-003"></a>

### UI-003 — Understand simulator and software update status

**Preconditions:** Normal app layout subscribed. **Steps:** Observe disconnected/needs-config/error, Retry/Open Settings; inspect app/firmware update banner and dismiss or navigate. **Acceptance:** State-specific banner/actions; no simulator banner when connected/connecting or on joystick page; update version and appropriate destination visible; dismiss broadcast clears banner. **Errors/limits:** App update is an external release link, not an in-app installer; firmware checking spinner only in dropdown. **Evidence:** [nav components](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/components/nav_components.ex), [hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/nav_hook.ex), [status tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/configuration_list_live_test.exs), [joystick suppression test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/virtual_joystick_live_test.exs).

<a id="ui-004"></a>

### UI-004 — Create and revisit a hardware profile

**Preconditions:** Normal UI access, database available. **Steps:** Devices→New Configuration, change name/description, return to list and reopen. **Acceptance:** New record is created at mount; changes autosave, first success patches to persisted config ID; list card shows name/description/input count and Active only for matching connected config ID. **Errors/limits:** Invalid/missing config route redirects with error; invalid header fields remain in form; abandoning `/new` does not delete the record. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [list](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_list_live.ex), [route/validation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/configuration_edit_live_test.exs).

<a id="ui-005"></a>

### UI-005 — Add physical analog and button inputs

**Preconditions:** Saved/mounted hardware configuration. **Steps:** Add Input, choose type, name/pin, analog sensitivity or button debounce, submit; rename on blur/delete row. **Acceptance:** Correct conditional fields and persisted row; analog defaults sensitivity 5; physical pins 0–127, sensitivity 1–10, debounce 0–255 required for button; unique pin across input types. **Errors/limits:** Form's HTML pin hint allows 0–254 but domain rejects 128+; debounce placeholder 20 is not an actual default; context failures stay/form-flash as documented. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [required/range/uniqueness tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/configuration_edit_live_test.exs).

<a id="ui-006"></a>

### UI-006 — Apply a profile and watch live input values

**Preconditions:** Configuration contains input/matrix; serial device connected. **Steps:** Apply to Device, pick port, wait for device acknowledgment; move analog/press button. **Acceptance:** Applying pending state, completion flash/active port, live raw/calibrated analog and Pressed/Released; offline N/A and unsampled em dash. **Errors/limits:** Empty profile, timeout, device rejection and initiation failures distinguish outcomes; output/display-only profile cannot enter apply through current button gate; global apply notifications are not filtered by this editor. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [apply-message/context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/configuration_edit_live_test.exs), [hardware](hardware.md).

<a id="ui-007"></a>

### UI-007 — Calibrate analog travel

**Preconditions:** Configuration applied, active analog input. **Steps:** Calibrate→minimum Start→collect minimum→Sweep→maximum→Finish. **Acceptance:** Ready/min/sweep/max/analyzing progression; min/max require 10 samples and 3 unique; sweep needs 10 samples; updated calibration appears after save. **Errors/limits:** Disabled Next reflects can_advance; insufficient samples/movement explicit; cancel stops session; start/save failure closes with error. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/calibration_wizard.ex), [session/public-state tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/calibration_wizard_test.exs).

<a id="ui-008"></a>

### UI-008 — Create and validate a matrix, then test its wiring

**Preconditions:** Hardware config; applied connection for testing. **Steps:** Add Matrix, enter comma-separated rows/columns, review virtual-pin preview, save, Test, press each physical button, Reset/Close. **Acceptance:** Reject missing/range/duplicate/overlap pins; row×col virtual buttons; progress and pressed/tested colors; Reset clears tested state. **Errors/limits:** Non-numeric entries silently ignored; test requires active device; tested set is not matrix-scoped and persists across reopen. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [test wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/matrix_test_wizard.ex), [matrix tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/matrix_test_wizard_test.exs).

<a id="ui-009"></a>

### UI-009 — Configure and test physical outputs

**Preconditions:** Hardware config, active port for test. **Steps:** Add Output with pin/name, rename, toggle test on/off, delete. **Acceptance:** Domain-validated output row; active-only test sends high/low and updates button ON/OFF. **Errors/limits:** Displayed toggle is local state, write errors are not surfaced/read back; add shows changeset errors, delete/name failures flash; source-only UI behavior beyond shared context tests. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [hardware](hardware.md).

<a id="ui-010"></a>

### UI-010 — Add an I2C display with retained form settings

**Preconditions:** Hardware editor out of new mode. **Steps:** Add/Edit display, enter address, display type/digits, adjust advanced brightness/minimum/alignment/dot, save. **Acceptance:** HT16K33 4/8-digit model; percent↔0–15 brightness; blank minimum removes clamp; failed validation preserves values and reveals field errors; Escape/Cancel returns focus. **Errors/limits:** Invalid address/name/minimum remain visible; new-mode Add disabled; delete requires browser confirm; active test cycles numeric/letter/blank strings but ignores hardware errors. **Evidence:** [form](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/i2c_module_form_component.ex), [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [display validation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/display_setup_test.exs).

<a id="ui-011"></a>

### UI-011 — Delete an inactive hardware configuration

**Preconditions:** Existing saved profile. **Steps:** Danger Zone→Delete→review confirmation→confirm. **Acceptance:** Inactive profile removed with all associated records and home redirect; active profile is protected in UI and context. **Errors/limits:** configuration_active gives readable refusal; generic deletion failure closes modal with error; input/matrix/output row deletions do not use this confirmation. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/configuration_edit_live.ex), [hardware](hardware.md).

<a id="ui-012"></a>

### UI-012 — Create a train from the detected identity

**Preconditions:** Simulator identifies a train, no matching profile. **Steps:** Trains unconfigured banner→Configure, review suggested name/full identifier, add aliases or shorten prefix, Create. **Acceptance:** Explicit save persists profile, syncs detection, redirects; Use current train ID preserves drafts and avoids duplicate identity; list shows all identifiers. **Errors/limits:** Missing identifiers, blank/duplicate identifiers/name show validation; ambiguous runtime match shows all matching profiles and no manual override. **Evidence:** [list](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_list_live.ex), [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [train tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/train_edit_live_test.exs), [current-ID tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/display_setup_test.exs), [ambiguity tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/train_list_live_test.exs).

<a id="ui-013"></a>

### UI-013 — Maintain train profile details and logical controls

**Preconditions:** Existing train. **Steps:** Edit name/description/identifiers and Save; Add Element named Lever/Button, Configure or Delete; inspect readiness. **Acceptance:** Profile form explicit save; logical element list refreshes; connected creation opens correct wizard; badges reflect configured fields; sections anchor to controls/displays/automation. **Errors/limits:** Disconnected configure fails even for key/sequence buttons; bad/missing route IDs redirect; deleting active train is disabled in UI; readiness is a field-presence heuristic. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [element tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/train_edit_live_test.exs), [wizard availability tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/configuration_wizard_component_test.exs).

<a id="ui-014"></a>

### UI-014 — Find an endpoint by browsing or simulator interaction

**Preconditions:** Connected simulator and a wizard requiring an endpoint. **Steps:** Browse sorted root/node tree, search current node, preview RO/RW value, select; alternatively Start Auto-Detect, interact in game, choose matching change. **Acceptance:** Slash-node/dot-leaf paths; preview/current-node search; detected single/multiple change list rounded to 2 decimals; retry/cancel/timeout/error states. **Errors/limits:** Read/list errors displayed or preview silently ignored; selection does not enforce writability; auto-detect countdown forwarding has a parent-flag gap; lever handler ignores general detected result. **Evidence:** [explorer](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/api_explorer_component.ex), [auto-detect](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/auto_detect_component.ex), [parent](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [button result tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/configuration_wizard_component_test.exs). Explorer/auto-detect state presentation is source-only.

<a id="ui-015"></a>

### UI-015 — Bind a physical button to simulator values

**Preconditions:** Logical button, simulator connected, saved button input (physical or matrix). **Steps:** Simulator Control→find endpoint→Detect hardware button→choose simple/momentary and hardware type→manual or detect OFF/ON→Save. **Acceptance:** Auto baseline/change>0.05 and confirm/retry or manual entry to 2 decimals; saved binding and controller reload; button row readiness updates. **Errors/limits:** No input gives setup instruction; hardware detection has no timeout; defaults may be saved without value-confirmation; repeat interval defaults to 100 ms without UI editor; joystick conflict gets generic wizard error. **Evidence:** [button wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/configuration_wizard_component.ex), [parent subscription routing](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [wizard tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/configuration_wizard_component_test.exs).

<a id="ui-016"></a>

### UI-016 — Bind a button to a sequence or keyboard combination

**Preconditions:** Button wizard (requires simulator connection to open); input configured; sequence exists for sequence mode. **Steps:** Choose Trigger Sequence or Keyboard Key; detect hardware, choose press/release sequence or capture key, Save. **Acceptance:** At least one sequence or nonempty captured key plus input enables Save; release sequence shown for latching; key normalized with CTRL/SHIFT/ALT; mode data persisted. **Errors/limits:** Missing sequence warning links back/cancels; modifier-only keys ignored; Meta not captured; no rendered test execution. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/configuration_wizard_component.ex), [key hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/assets/js/app.js), [binding modes tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/button_binding_tools_test.exs) verify domain/tool modes, not browser key events.

<a id="ui-017"></a>

### UI-017 — Set up a calibrated analog lever

**Preconditions:** Logical lever, connected simulator, calibrated analog hardware. **Steps:** Type Analog→select input→standard lever endpoint auto-configure→read calibration requirements→run simulator sweep→map each gate/linear hardware range→Save Mapping. **Acceptance:** Six new/five edit steps; 3 required endpoints; classification/notch result; sample capture/reset/stop/revisit; all captured preview; persistence and controller reload. **Errors/limits:** Missing device/calibration/config/bind/sample/range failures shown; Skip Manual does not implement manual setup; cancel does not roll back analysis/binding writes. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/lever_setup_wizard.ex), [visualizer](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/lever_visualization.ex), [new/edit/navigation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/lever_setup_wizard_test.exs).

<a id="ui-018"></a>

### UI-018 — Reconfigure a lever without silently skipping dependencies

**Preconditions:** Existing partially/fully configured lever. **Steps:** Open, click earlier configured step, change input or endpoint, revisit required calibration/mapping, save. **Acceptance:** Edit mode omits explanation; configured checkmarks and invalidation warnings; input invalidates mapping, endpoint changes invalidate calibration+mapping; reverting original clears relevant invalidation; cannot jump over required redo. **Errors/limits:** Entering calibration reruns it; some dependency tests conditionally skip assertion when fixture inputs absent; source governs full dependency behavior. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/lever_setup_wizard.ex), [dependency tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/lever_setup_wizard_test.exs).

<a id="ui-019"></a>

### UI-019 — Drive an LED from a simulator condition

**Preconditions:** Saved output, existing train, connected simulator. **Steps:** Add Output Binding→endpoint→output→LED→name/operator/thresholds→Save; edit or delete. **Acceptance:** Boolean/numeric/between preview and conditional fields; two-decimal thresholds; create/update reload OutputController and refresh rows. **Errors/limits:** No output/disconnection explicit; missing required fields disable save, context changeset errors flash; no enabled toggle or readback test in this wizard. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/output_binding_wizard.ex), [parent](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [tool CRUD tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/output_binding_tools_test.exs) cover domain-facing outcomes; wizard source-only.

<a id="ui-020"></a>

### UI-020 — Display a simulator number and edit formatting offline

**Preconditions:** Train and hardware display; simulator needed to create/select endpoint. **Steps:** Add Display Binding→display→simulator value→name/decimal places/custom format→preview→Save; later reopen offline and change formatting. **Acceptance:** Hardware chosen before explorer; 42.5 sample preview, precision 0–10; invalid format disables save; submitted config used; offline edit succeeds. **Errors/limits:** Direct setup links for missing prerequisites; overflow/dot warnings advisory; no live sample or units conversion field. **Evidence:** [wizard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/display_binding_wizard.ex), [integration tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/display_setup_test.exs).

<a id="ui-021"></a>

### UI-021 — Build, edit and test a command sequence

**Preconditions:** Saved train; simulator for endpoint selection and actual test writes. **Steps:** New Sequence/name→Edit→Add/Remove commands→endpoint/value selector→delay→Save→Test. **Acceptance:** Ordered draft replacement, command counts and zero-command test disabled; selector captures one current value or manual entry to 2 decimals, final combined confirm; test dispatches sequential writes/delays. **Errors/limits:** No reorder/rename UI; invalid parsing defaults to 0; errors may silently keep modal; disconnected test skips writes yet shows Testing, no completion report. **Evidence:** [manager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/sequence_manager_component.ex), [selector](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/endpoint_selector_component.ex), [manager tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/sequence_manager_component_test.exs), [selector tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/components/endpoint_selector_component_test.exs).

<a id="ui-022"></a>

### UI-022 — Author and run a Lua script with console feedback

**Preconditions:** Saved train; runner available for execution. **Steps:** Add Script→name/code→add unique trigger paths→Create; toggle enabled/Run; refresh console or consult outputs reference; Save edits. **Acceptance:** Default on_change template; script persisted and runner explicitly reloaded; manual run uses stored ID; log refresh after 300 ms plus manual refresh; output ID table. **Errors/limits:** No unsaved-code execution, IDE syntax highlighting or continuous log subscription; errors stay form/console; missing log service gives empty; mismatched route train/script ownership not checked. **Evidence:** [editor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/script_edit_live.ex), [parent](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/train_edit_live.ex), [script HTTP tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/api/script_controller_test.exs) cover CRUD, not browser editor.

<a id="ui-023"></a>

### UI-023 — Install firmware on an identified port

**Preconditions:** Serial port and a compatible release (fetch if absent). **Steps:** Firmware→Check Updates→Upload release or failed-device port link→pick port/device type→Start→watch progress/history. **Acceptance:** Latest/older release distinction and compatibility disabling; file download if needed, progress and completed duration; latest 10 history entries; correct preselected query port. **Errors/limits:** No ports→scan instruction; incompatibility/missing board/download/start/runtime failure; Cancel Upload supported; backdrop can hide ongoing upload without cancelling. No dedicated page tests reviewed. **Evidence:** [page](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/firmware_live.ex), [firmware](firmware.md).

<a id="ui-024"></a>

### UI-024 — Configure offline virtual joystick mappings

**Preconditions:** Saved hardware inputs; Windows activation not required to edit mappings. **Steps:** Joystick→Add mapping→Axis/Button→compatible input→target/inversion→Save; edit/delete; reveal unused targets. **Acceptance:** Capacity of 8 axes / 32 buttons; hardware locked when editing; live preview only matching port/pin and clear connection/calibration guidance; mappings save offline. **Errors/limits:** No inputs disables save with setup link; duplicate target alert; uncalibrated analog preview unavailable; enabling/disabling blocks all mutations. **Evidence:** [page](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/virtual_joystick_live.ex), [form](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/components/virtual_joystick_mapping_form.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/virtual_joystick_live_test.exs).

<a id="ui-025"></a>

### UI-025 — Move a simulator input to joystick destination explicitly

**Preconditions:** Existing active simulator/API destination for selected input. **Steps:** Save joystick mapping, review replacement dialog, Cancel or Replace binding. **Acceptance:** Cancel preserves old destination; Replace opts into domain replacement; mapping appears; no implicit replacement. **Errors/limits:** Transition to enabling/disabling disables confirmation and handler rejects mutation; duplicate target/domain failure shown. **Evidence:** [page](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/virtual_joystick_live.ex), [replacement tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/virtual_joystick_live_test.exs), [MCP conflict tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/virtual_joystick_tools_test.exs).

<a id="ui-026"></a>

### UI-026 — Activate, deactivate and recover joystick runtime

**Preconditions:** Windows runtime for activation; platform unsupported still shows mappings. **Steps:** Enable/Disable→read elevation notice→Continue or Cancel; follow state-specific recovery. **Acceptance:** Asynchronous Turning on/off, On/Off, setup/cleanup/degraded/error states; UAC-cancel messages; Retry/Remove leftover/Check installation/configuration chosen by reason. **Errors/limits:** No activation toggle unsupported; ignored immediate return means eventual status controls feedback; Windows-without-Manager appears unsupported in UI. **Evidence:** [page](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/virtual_joystick_live.ex), [all-state/elevation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/virtual_joystick_live_test.exs), [runtime](virtual-joystick.md).

<a id="ui-027"></a>

### UI-027 — Save and test simulator settings

**Preconditions:** Settings accessible. **Steps:** Enter HTTP(S) URL, optionally key override, Save and test, observe asynchronous outcome. **Acceptance:** File-discovery status/platform instructions; blank override preserves existing; settings persisted before test; connected/rejected-key/missing-key/generic/no-result feedback distinguished; 15-second pending timeout. **Errors/limits:** Empty/bad URL blocked; prefix-only URL validation; no clear override control. **Evidence:** [settings](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/settings_live.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/live/settings_live_test.exs).

<a id="ui-028"></a>

### UI-028 — Receive an AI-directed hardware detection prompt

**Actor/preconditions:** Operator paired with MCP assistant; normal connected LiveView. **Steps:** Assistant calls detect_hardware_input, operator reads global MCP prompt and interacts once. **Acceptance:** Overlay appears across normal pages and closes after success/timeout; result carries database input ID for later binding. **Errors/limits:** No local cancel; consent screen excluded; parallel calls overwrite state; no detection replay to newly mounted view. **Evidence:** [detection hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/mcp_detection_hook.ex), [tool](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/detection_tools.ex), [detection tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/detection_tools_test.exs).

<a id="ui-029"></a>

### UI-029 — Preserve client theme and understand transient feedback

**Preconditions:** Browser with JS/localStorage. **Steps:** Load saved phx:theme or system preference, navigate/submit, receive info/error, reconnect after interruption. **Acceptance:** Root theme before render and cross-tab storage sync; 300 ms delayed loading bar; info auto-dismiss after 5 seconds+fade, error manually dismissible; reconnect notices. **Errors/limits:** Theme helper is not rendered by current app layout, so a visible theme chooser is not a current normal-page feature; older dialogs lack universal Escape/focus trapping. **Evidence:** [root](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/components/layouts/root.html.heex), [JS](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/assets/js/app.js), [core](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/components/core_components.ex), [layout helper](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/components/layouts.ex); source-only.

## HTTP and MCP client stories

<a id="api-001"></a>

### API-001 — Determine readiness and shut down the desktop backend

**Actor/preconditions:** Desktop wrapper/local HTTP client, server reachable. **Steps:** GET health until 200; on intended application close POST shutdown. **Acceptance:** Ready iff firmware table query succeeds; shutdown acknowledges then stops system after 100 ms. **Errors/limits:** 503 reason migrations_pending/database_unavailable/unknown; no auth/consent on shutdown; no live shutdown invoked for this documentation. **Evidence:** [health controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/health_controller.ex), [health tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/health_controller_test.exs) cover success/content type only.

<a id="api-002"></a>

### API-002 — Read train profiles and output IDs by HTTP

**Actor/preconditions:** Local automation client. **Steps:** GET trains, GET selected train, GET outputs. **Acceptance:** Sorted identifier arrays and documented nested element/output fields; all configured outputs contain device metadata. **Errors/limits:** Missing train 404; noninteger ID may raise; no HTTP mutations and no connected-only output filter. **Evidence:** [train API](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/train_api_controller.ex), [outputs](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/output_api_controller.ex), [train tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/api/train_api_controller_test.exs).

<a id="api-003"></a>

### API-003 — Manage scripts through HTTP

**Actor/preconditions:** Local editor/integration with saved train ID. **Steps:** List/create nested scripts; get/update/delete by script ID. **Acceptance:** Flat body whitelist; 201 on create, 200 on read/update/delete; full code/timestamps in output; explicit runner reload after mutation. **Errors/limits:** Changeset 422/errors, missing 404/error, no parent lookup for list, malformed integer raises; no run/log HTTP endpoint. **Evidence:** [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/script_controller.ex), [CRUD tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/api/script_controller_test.exs).

<a id="api-004"></a>

### API-004 — Proxy simulator browsing/readback over HTTP

**Actor/preconditions:** Local client; connected simulator for success. **Steps:** GET simulator/endpoints with optional path, GET simulator/value with path. **Acceptance:** Upstream data returned unchanged. **Errors/limits:** Missing value path 400, unavailable 503, upstream 502 with inspected reason; no HTTP write endpoint. **Evidence:** [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/simulator_api_controller.ex), source-only controller behavior.

<a id="api-005"></a>

### API-005 — Establish and use an MCP SSE session

**Actor/preconditions:** MCP-capable assistant/client, running Trenino. **Steps:** GET SSE, consume endpoint event, POST initialize and tools/list to supplied session URL, receive message events. **Acceptance:** Protocol 2024-11-05, tools capability/server info, 47 unique tools; POST 202 is transport acceptance and result travels SSE. **Errors/limits:** Missing session 400 / not-found 404; no auth, heartbeat, replay or init-order enforcement. **Evidence:** [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/mcp/mcp_controller.ex), [server](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/server.ex), [controller tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/mcp/mcp_controller_test.exs), [protocol tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/server_test.exs).

<a id="api-006"></a>

### API-006 — Handle protocol and tool errors correctly

**Actor/preconditions:** MCP client with session. **Steps:** Call valid tool, unknown tool, unsupported method or missing call params; parse responses. **Acceptance:** Maps encoded as JSON inside text content; handled tool errors use result.isError; protocol codes-32600/-32601/-32602; joystick structured status errors decoded separately. **Errors/limits:** Most modules do not enforce schemas and can raise on malformed arguments; notifications still receive null-ID responses. **Evidence:** [server](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/server.ex), [registry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tool_registry.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/server_test.exs), [strict joystick tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/virtual_joystick_tools_test.exs).

<a id="api-007"></a>

### API-007 — Explore and manipulate live simulator controls through MCP

**Actor/preconditions:** Assistant; simulator connected and client nonnil. **Steps:** list_simulator_endpoints root/drill nodes, get_simulator_value leaf, set_simulator_value writable leaf. **Acceptance:** Slash nodes/dot leaf naming; upstream result preserved; set really changes game state. **Errors/limits:** Disconnected readable tool error; upstream reason wrapped; tool does not independently enforce writable metadata. **Evidence:** [tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/simulator_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/simulator_tools_test.exs).

<a id="api-008"></a>

### API-008 — Inspect train/element/hardware configuration before binding

**Actor/preconditions:** Assistant with saved IDs. **Steps:** list_trains/get_train; list_elements; list_devices/list_device_inputs/list_hardware_outputs/list_i2c_modules. **Acceptance:** Complete documented serialization distinctions, separate DB IDs/config IDs; get_train includes button/output/sequences but not lever internals/scripts/display bindings. **Errors/limits:** list_devices returns saved configs only despite advertised connected status; missing train readable; child lists may empty. **Evidence:** [train tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/train_tools.ex), [device tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/device_tools.ex), [element tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/element_tools.ex), [train tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/train_tools_test.exs), [device tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/device_tools_test.exs).

<a id="api-009"></a>

### API-009 — Detect a hardware input instead of asking for its ID

**Actor/preconditions:** Assistant+operator; configured input event source. **Steps:** Call detect_hardware_input once with prompt/type, operator interacts, await result before next call. **Acceptance:** Prompt broadcast, baseline-change detection returns input metadata; timeout successful detected false; completion broadcast closes overlay. **Errors/limits:** Undocumented timeout_ms default 60000; unknown filter→any; snapshot inputs/ports, no parallel serialization; no simulator detector MCP tool. **Evidence:** [tool](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/detection_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/detection_tools_test.exs), [hardware](hardware.md).

<a id="api-010"></a>

### API-010 — Create logical controls and button destinations

**Actor/preconditions:** Assistant with train/input IDs. **Steps:** create_element button/lever; create/get/update/delete_button_binding; delete_element when removing control. **Acceptance:** Four button modes and conditional fields; handled mutation reloads controller; element deletion removes associated config; enabled fields respected. **Errors/limits:** Missing binding/element readable; joystick conflict requires removing mapping first; update tool cannot change input_id, no lever-calibration/config tools. **Evidence:** [element tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/element_tools.ex), [button tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/button_binding_tools.ex), [element tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/element_tools_test.exs), [mode/conflict tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/button_binding_tools_test.exs).

<a id="api-011"></a>

### API-011 — Create output and display rules

**Actor/preconditions:** Assistant with saved hardware output/display IDs and train. **Steps:** CRUD output bindings for threshold/boolean, CRUD display bindings for endpoint/format, CRUD I2C modules when required. **Acceptance:** Exact schema enums/results, conditional thresholds; output/display runtime controllers reload on mutations; formatted display references saved module. **Errors/limits:** Missing targets/validation text; top-level I2C option mismatch; display name optional schema versus UI requirement; I2C CRUD and display mutation tests limited. **Evidence:** [output tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/output_binding_tools.ex), [display tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/display_binding_tools.ex), [device tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/device_tools.ex), [output tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/output_binding_tools_test.exs), [display tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/display_binding_tools_test.exs).

<a id="api-012"></a>

### API-012 — Manage ordered command sequences

**Actor/preconditions:** Assistant with train ID. **Steps:** create_sequence ordered commands, list, update name/replace commands, delete. **Acceptance:** Zero-based positions generated, default delay 0, replacement [] clears, deletion clears references. **Errors/limits:** Command failure may leave newly created sequence or prior name update persisted; JSON string compatibility can raise; no run tool. **Evidence:** [tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/sequence_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/sequence_tools_test.exs).

<a id="api-013"></a>

### API-013 — Manage Lua source through MCP

**Actor/preconditions:** Assistant with train/script IDs. **Steps:** list_scripts summaries→get_script full code→create/update/delete. **Acceptance:** Code omitted from list, defaults enabled/no triggers, false preserved, timestamps absent, optional fields only changed when supplied/non-null. **Errors/limits:** Missing/validation errors readable; no explicit runner reload unlike UI/HTTP; no run/log MCP tool; schema description does not prove Lua runtime validity. **Evidence:** [tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/script_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/script_tools_test.exs).

<a id="api-014"></a>

### API-014 — Map and manage joystick through strict MCP tools

**Actor/preconditions:** Assistant; saved hardware inputs, Windows Manager for lifecycle. **Steps:** Strictly typed map axis/button, explicit replace if needed, list/delete, enable/disable/retry/cleanup/checkinstallation, poll status. **Acceptance:** Additional keys rejected; device 1 only, 8 axes / 32 buttons; status/error reason envelopes; lifecycle accepted asynchronously; platform/runtime-unavailable distinction. **Errors/limits:** status error is ordinary MCP success text rather than isError; validation errors array for arguments versus map for Ecto; unsupported/missing Manager do not raise. **Evidence:** [tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/virtual_joystick_tools.ex), [strict validation/conflict/lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/virtual_joystick_tools_test.exs).

## Acceptance interpretation

For a rewrite, retain the actor-visible successful flows and deliberate constraints above; decide explicitly which listed gaps are compatibility requirements versus defects to correct. A test asserting a button label or helper-shaped map is weaker evidence than a real session transition or persisted side effect. No test file in this reference should be taken as evidence of physical firmware flashing, actual simulator endpoint compatibility, browser-native key handling, Windows driver installation or external MCP client compatibility without the corresponding integration verification.
