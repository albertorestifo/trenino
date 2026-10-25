# Simulator, train configuration, and automation user stories

Baseline `188f35e4108733358730e92ebd98f1912af5173a`. These stories reconstruct current behavior from source and read tests; they are **not** results of live acceptance testing. “Acceptance” means observable behavior the existing implementation supports, including recorded limitations. Product improvements are called out as rewrite decisions instead of silently assumed. Detailed fields/algorithms are in [simulator](simulator.md), [profiles and controls](train-profiles-and-controls.md), and [scripting and sequences](scripting-and-sequences.md). UI routes, exact controls and MCP invocation schemas are in their respective references.

Actors: **driver** operates hardware/game; **profile author** configures a train; **script author** writes automation; **operator** diagnoses the local app/connection. The app is single-user; these names describe tasks, not separate authorization roles.

## Simulator connection and discovery

<a id="sim-001"></a>

### SIM-001 — Connect to the game's external interface

- **Actor / intent:** Operator connects Trenino to the configured TSW API.
- **Preconditions:** Game API is enabled according to repository setup guide; settings can supply URL/key; Connection and TaskSupervisor running.
- **Steps:** Save settings or request retry; Connection obtains current key/URL, constructs Client, publishes connecting and asynchronously requests `/info`.
- **Acceptance:** HTTP 200 produces connected with client/info/UTC check time and clears error/failure counter; subscribers receive simulator_status_changed; health checking is scheduled.
- **Failure / alternatives:** Missing key -> needs_config and no newly scheduled retry. 403 -> invalid_key, other failures/task crash -> connection_failed; publish error and retry after 30s. HTTP 200 game-level Result Error still counts as success at client layer. Settings helper tries Windows TSW7 key before TSW6.
- **Evidence:** [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/connection.ex), [Client](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/client.ex), [connection tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/connection_test.exs).

<a id="sim-002"></a>

### SIM-002 — Tolerate a brief health-check failure

- **Actor / intent:** Driver keeps the active configuration during a temporary game stall.
- **Preconditions:** Connected state and healthy client.
- **Steps:** 30s health timer performs fast-timeout `/info`; transient failure increments counter; repeat after 2s.
- **Acceptance:** First two failures preserve connected and do not publish disconnect; success resets counter and returns to 30s checks. Third failure changes to error, publishes and starts 30s reconnect retry. Auth failure changes immediately.
- **Failure / alternatives:** Health operations block their GenServer for request duration. No central timer cancellation protects against duplicate health chains. This tolerance is separate from profile Detection grace period.
- **Evidence:** [connection tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/connection_test.exs), [state tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/connection_state_test.exs).

<a id="sim-003"></a>

### SIM-003 — Reconfigure, manually retry, or disconnect

- **Actor / intent:** Operator changes game address/key or controls connection attempts.
- **Preconditions:** Connection process running (methods except subscribe also safely no-op/fallback when absent).
- **Steps:** Reconfigure schedules connect after 500ms; retry casts connect immediately; disconnect clears current client/info.
- **Acceptance:** Retry uses latest Settings and emits connecting/result; disconnect publishes disconnected. Reconfigure changes state to disconnected internally but does not publish it before next connect.
- **Failure / alternatives:** Existing timers/tasks are not canceled/versioned; old retry or result can reconnect/overwrite newer state. Disconnect is not a permanent “remain offline” policy. Absent get_status returns needs_config.
- **Evidence:** [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/connection.ex), [ConnectionState](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/connection_state.ex).

<a id="sim-004"></a>

### SIM-004 — Read, write and subscribe to arbitrary game endpoints

- **Actor / intent:** Profile author or integration client inspects/controls the game through the reusable HTTP client.
- **Preconditions:** Constructed Client with URL/key and valid node path.
- **Steps:** List root/child paths; get value; set via PATCH query Value; subscribe endpoint(s) using integer group; poll group; unsubscribe/list groups.
- **Acceptance:** DTGCommKey on requests; path encodes parentheses/spaces while preserving slash/dot; raw body returned for HTTP 200; typed readers extract first Values item and float reads round .01. POST has empty body. No implicit unit conversion.
- **Failure / alternatives:** 403/other HTTP/transport errors have distinct tuples; empty/invalid typed value -> invalid_value. Multiple Values are not field-selected. Invalid game Result in 200 is not converted to error; callers must interpret it.
- **Evidence:** [client tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/client_test.exs), [guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/TSW_API_GUIDE.md).

<a id="sim-005"></a>

### SIM-005 — Obtain a name-based control suggestion

- **Actor / intent:** Profile author reduces endpoint entry when configuring “Throttle” or “Horn”.
- **Preconditions:** Globally connected game with current train and string-shaped Nodes lists compatible with ControlDetector.
- **Steps:** Call suggest_lever/button with element name; list top controls and each control; classify by notch-count/default-pressed endpoint strings; choose highest fuzzy score.
- **Acceptance:** Strict confidence >.3 yields control name/score plus constructed endpoint fields; exact case-insensitive match 1, containment .85/.75, word/Jaro fallback; disconnected/no match returns explicit error.
- **Failure / alternatives:** Per-control malformed/error responses skipped; top-level error propagates; no alias learning/cache; camel-case split is ineffective after lowercasing; map-shaped Nodes used by interaction detector are incompatible with this implementation. Suggestion does not itself save configuration.
- **Evidence:** [ControlDetector](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/control_detector.ex), [historical suggestion guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/control_auto_suggestion.md) (guide's claimed test file is absent).

<a id="sim-006"></a>

### SIM-006 — Identify an endpoint by moving its game control

- **Actor / intent:** Profile author discovers an unknown control without knowing its name.
- **Preconditions:** Client, callback process, map-shaped discovery response with writable InputValue endpoints; no competing group-99 detection session.
- **Steps:** Start session; recurse nodes, subscribe discovered InputValue paths, baseline numeric values; move game control; poll every 150ms.
- **Acceptance:** First numeric baseline delta >.01 produces control_detected with all changed endpoint/name/old/new values, then cleans up subscription/timers. Callback death or explicit stop also ends session. No movement for 30s after setup -> detection_timeout.
- **Failure / alternatives:** No successful subscriptions or baseline/list failure -> detection_error and start error normal; poll failures continue until timeout. Nonnumeric/no-baseline changes ignored; NodeValid not checked. Concurrent sessions share/delete group 99. Does not persist inferred on/off values by itself.
- **Evidence:** [session](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/control_detection_session.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/control_detection_session_test.exs).

<a id="sim-007"></a>

### SIM-007 — Empirically analyze a lever's game ranges

- **Actor / intent:** Profile author discovers discrete, continuous or hybrid simulator behavior for usable notch mapping.
- **Preconditions:** A game control path with settable InputValue and readable output/notch functions; author accepts sweep mutating game controls.
- **Steps:** Read min/max (fallback 0..1), initialize min with five pushes, sweep .02 steps/150ms settle, read set/actual/output/index; group and merge zones; obtain suggested notches; optionally restore requested position.
- **Acceptance:** >=10 samples -> analysis type/zones/notches with simulator input ranges and observed output; true snap boundaries remain separate, continuous groups merge. Negative simulator ranges supported. Train analysis-save copies suggestion input ranges into sim_input fields.
- **Failure / alternatives:** Individual sample failure skips; insufficient samples errors. Restore happens only on successful analysis and restoration failure ignored. Analyzer alone does not bind/map hardware. quick_check uses fixed five 0..1 points, does not restore, returns sample_failed/discrete/continuous/unknown.
- **Evidence:** [analyzer](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/simulator/lever_analyzer.ex), [analysis tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/lever_analyzer/analysis_test.exs), [mocked sweep tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/simulator/lever_analyzer_test.exs).

## Automatic train identity and activation

<a id="auto-001"></a>

### AUTO-001 — Select the driven vehicle rather than freight wagons

- **Actor / intent:** Driver loads a formation and automatically obtains the locomotive profile.
- **Preconditions:** Connected simulator with CurrentFormation metadata; saved prefix may exist.
- **Steps:** Every 5s Detection reads DrivableIndex and that vehicle's ObjectClass; normalize terminal _C/trailing separators; match saved identifiers.
- **Acceptance:** Nonzero drivable index selects that vehicle; either index/class error falls back to formation index 0; no all-wagon common-prefix computation occurs in active path.
- **Failure / alternatives:** If fallback also fails, detection_error broadcasts and prior active profile stays. Empty normalized identifier is not explicitly rejected. No ProviderName fallback exists.
- **Evidence:** [Identifier](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/identifier.ex), [identifier tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/identifier_test.exs).

<a id="auto-002"></a>

### AUTO-002 — Share a profile across equivalent simulator variants

- **Actor / intent:** Profile author gives one train unrelated route prefixes while reusing hardware setup.
- **Preconditions:** Profile with >=1 valid unique identifier.
- **Steps:** Add another identifier; drive either variant; Detection finds any matching prefix.
- **Acceptance:** Every identifier is an equivalent case-sensitive prefix; overlap within same profile deduplicates; one matching profile activates and train_detected/train_changed events update consumers.
- **Failure / alternatives:** Exact identifier owned elsewhere cannot save; case mismatch returns no match. Prefix matching is not delimiter-aware; a broad prefix can match unintended classes. Reorder does not change priority.
- **Evidence:** [matching tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/train_identifier_matching_test.exs), [persistence tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/train_identifier_persistence_test.exs).

<a id="auto-003"></a>

### AUTO-003 — Report ambiguous profiles instead of picking one

- **Actor / intent:** Operator sees why no bindings activated when multiple profiles overlap.
- **Preconditions:** Distinct saved profiles have prefixes matching one detected identifier.
- **Steps:** Detection receives new identity; context returns multiple matches.
- **Acceptance:** train_detected with nil plus multiple_trains_match containing candidate profiles; active train becomes nil, prior active consumers receive train_changed nil. detection_error stores multiple_matches.
- **Failure / alternatives:** Exact/longer prefix does not automatically win. Author edits identifiers and forces sync to recheck unchanged identity; no profile chooser setter exists in reviewed domain API.
- **Evidence:** [Detection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/detection.ex), [ambiguity tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/train_identifier_matching_test.exs).

<a id="auto-004"></a>

### AUTO-004 — Handle an unknown vehicle

- **Actor / intent:** Driver loads an unconfigured vehicle and can create a matching profile.
- **Preconditions:** Successful identity read, no prefix match.
- **Steps:** Detection publishes observed identifier with train nil; author creates matching profile through UI/MCP; request sync.
- **Acceptance:** Previously active profile deactivates; identifier retained for creation/prefill; sync resets identity cache and can activate the new record.
- **Failure / alternatives:** Without sync the same-identifier poll only refreshes timestamps and does not discover newly created/edited rows. The detection domain does not automatically create profiles.
- **Evidence:** [Detection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/detection.ex), [Train context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs).

<a id="auto-005"></a>

### AUTO-005 — Keep a profile through a connection grace period

- **Actor / intent:** Driver avoids losing configuration on a short game API failure.
- **Preconditions:** Active profile, remembered simulator client and successful-contact timestamp.
- **Steps:** Global status becomes nonconnected; normal polls stop; fast client identity probes every 200ms.
- **Acceptance:** Active profile retained until 30s since last successful identity contact; successes prolong grace; reconnect exits grace and immediately checks normal identity. Repeated disconnect events do not restart grace.
- **Failure / alternatives:** Missing remembered client -> immediate deactivate; failed probes after deadline clear profile/identity and emit train_changed nil. Successful grace identity is ignored for selecting another profile. Ordinary writes remain gated by global connected status.
- **Evidence:** [Detection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/detection.ex), [grace tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/detection_test.exs).

<a id="auto-006"></a>

### AUTO-006 — Force refresh after editing a profile

- **Actor / intent:** Profile author applies changed matching/configuration while driving the same vehicle.
- **Preconditions:** Detection running; context edit persisted.
- **Steps:** Call sync to force identifier lookup, then reload appropriate controller for binding/code edits as the caller requires.
- **Acceptance:** During normal/grace context sync uses current/grace client respectively; changed active struct can publish train_changed. Explicit Lever/Button/Output/Display reload and ScriptRunner.reload_scripts obtain persisted data.
- **Failure / alternatives:** CRUD itself generally has no all-controller notification; unknown profile getter errors; script reload resets every enabled script's VM/logs/timers. Sync while disconnected outside grace cannot perform new identity I/O.
- **Evidence:** [Detection sync](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/detection.ex), [Train operations](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [script runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex).

## Profile authoring and deletion

<a id="tr-001"></a>

### TR-001 — Create, find, edit and delete a profile

- **Actor / intent:** Profile author maintains a named train configuration.
- **Preconditions:** Repo available.
- **Steps:** Create name/optional description plus nested identifier(s); list/get; edit name/description/identifier collection; delete when obsolete.
- **Acceptance:** List ordered name, optional association preloads; successful create/update returns record; identifiers trimmed, at least one retained, duplicates rejected. Deletion removes associated elements via DB cascade.
- **Failure / alternatives:** Missing name/last identifier/blank identifier/owned exact prefix -> changeset error preserving persisted record. Getter missing ID -> not_found. No unique name or maximum profile-name validation. Delete does not itself guarantee active controller cleanup until sync/change/reload.
- **Evidence:** [Train schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/train.ex), [identifier schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/train_identifier.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs), [persistence tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/train_identifier_persistence_test.exs).

<a id="tr-002"></a>

### TR-002 — Add or remove a cab element

- **Actor / intent:** Profile author represents a lever or button on the cab.
- **Preconditions:** Saved train profile.
- **Steps:** Create element with name/type, list/get with configuration, delete element.
- **Acceptance:** Only lever/button enums accepted; name/type required; list ordered name with config/notches/bindings/device preloaded; delete removes associated binding via cascade.
- **Failure / alternatives:** Missing/invalid fields -> changeset; missing getter -> not_found. No generic context update_element or uniqueness per name. Type association compatibility is not enforced by these schemas.
- **Evidence:** [Element](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/element.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs), [button cascade tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_input_binding_test.exs).

<a id="tr-003"></a>

### TR-003 — Configure lever endpoints manually or from analysis

- **Actor / intent:** Profile author associates one lever with game endpoints.
- **Preconditions:** Saved lever element; analysis result if using empirical flow.
- **Steps:** Save min/max/value endpoint strings, optional paired notch count/index, optional lever type/inverted; optionally create/update with analysis.
- **Acceptance:** One config per element; required three endpoints; notch functions both present or both absent; analysis save transaction creates/replaces all suggested notches with sim ranges and type.
- **Failure / alternatives:** Invalid pair/required field/FK/duplicate -> error; reanalysis removes old hardware mappings. No endpoint capability checks or automatic control movement on plain save.
- **Evidence:** [LeverConfig](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_config.ex), [Train context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs).

<a id="tr-004"></a>

### TR-004 — Edit gate/linear notches and their coordinate systems

- **Actor / intent:** Profile author tunes observed output and hardware/simulator ranges.
- **Preconditions:** Saved lever config.
- **Steps:** Create/update/delete a notch or replace list; enter gate value or linear output extrema; paired hardware range and simulator range; description.
- **Acceptance:** Gate requires value; linear requires both output bounds; both range pairs optional together and ordered; hardware constrained 0..1; sim negative permitted; floats round .01; unique index per config. Bulk replace assigns list-order indices transactionally.
- **Failure / alternatives:** Partial/out-of-order ranges error and rollback bulk replacement. No overlap/full coverage/positive linear width/output-bound ordering enforced. Equal hardware bounds may be accepted yet unmappable or divide by zero. Runtime reload is separate.
- **Evidence:** [Notch](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/notch.ex), [notch tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/notch_test.exs), [Train save tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs).

<a id="tr-005"></a>

### TR-005 — Bind, disable, enable or unbind a lever input

- **Actor / intent:** Profile author connects a physical analog input to one train lever.
- **Preconditions:** Input and config records exist; operating input needs valid hardware calibration, connected device and mapped notches.
- **Steps:** Bind input (upsert per config), toggle enabled, reload controller; unbind when removing mapping.
- **Acceptance:** One binding per config; defaults enabled; disabled omitted by runtime; same input can be reused across profiles; known input movement follows active profile only.
- **Failure / alternatives:** Missing FK/duplicate/error -> changeset; unbind/get/enable missing -> not_found. Context/schema do not enforce calibration/type. Multiple same-input bindings in one profile collapse to one runtime map entry, not fanout.
- **Evidence:** [binding](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_input_binding.ex), [Train context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [LeverController tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/lever_controller_test.exs).

<a id="tr-006"></a>

### TR-006 — Resolve a train-binding versus vJoy destination conflict

- **Actor / intent:** Profile author moves an input from vJoy into train control intentionally.
- **Preconditions:** Existing virtual joystick mapping for input; new/enabling enabled lever or button binding.
- **Steps:** Save normally and observe destination_conflict; repeat with replace true through caller's replacement flow.
- **Acceptance:** Default leaves mapping/binding state unchanged; replacement atomically deletes vJoy mapping and saves enabled train binding, then reloads running relevant controller and vJoy Manager. Disabled train binding can coexist until enabled.
- **Failure / alternatives:** Changeset failure rolls back mapping deletion; no replacement when enable=false. This scope does not arbitrate multiple train bindings sharing same input.
- **Evidence:** [transaction](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex), [enable conflict tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs), [button replacement test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_controller_test.exs).

## Calibration and driving levers

<a id="tr-007"></a>

### TR-007 — Run legacy automatic notch calibration

- **Actor / intent:** Profile author records game notch characteristics using existing calibration session.
- **Preconditions:** Config with min/max/notch functions, Client, Registry and SessionSupervisor; no same-type same-config session.
- **Steps:** Start; initialize min/max/count; one-notch skips to linear-save, otherwise .025 sweep with reads; observe progress/result; stop if needed.
- **Acceptance:** Gate takes precedence on snap; notch-index transition finalizes prior range; save replaces notches and timestamps calibrated_at; completion process stops; duplicate start -> already_running.
- **Failure / alternatives:** API/save error broadcasts result error and stops; stop missing -> not_found. No position restore. Saved records lack sim_input and hardware ranges, so this legacy result alone is not runnable through modern LeverMapper and can destroy existing mappings.
- **Evidence:** [LeverSession](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/calibration/lever_session.ex), [session tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/calibration/lever_session_test.exs).

<a id="tr-008"></a>

### TR-008 — Map actual physical travel to each notch

- **Actor / intent:** Profile author aligns hardware detents/sweep regions with analyzed game notches.
- **Preconditions:** Bound input calibration and connected port/pin; config with preloaded notches; mapping supervisor/registry.
- **Steps:** Start mapping, position without recording, start capture, wiggle gate/sweep linear, capture min/max, repeat, preview, save.
- **Acceptance:** At least one sample enables capture; calibrated integer extrema track full hardware precision; final save normalizes then persists .01 bounds, auto-detects inversion from hardware/sim center ordering; progress/result PubSub events emitted.
- **Failure / alternatives:** Wrong step/index/no samples/incomplete preview -> error; reset/stop-capture discards current samples; cancel stops without save. No gap/overlap/ten-sample stability enforcement. Complete session stays alive until stopped; save does not itself reload controller. Invalid zero total travel falls back bounds 0.
- **Evidence:** [mapping session](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/calibration/notch_mapping_session.ex), [mapping tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/calibration/notch_mapping_session_test.exs).

<a id="tr-009"></a>

### TR-009 — Distribute and inspect hardware notch coverage

- **Actor / intent:** Profile author uses even ranges as a starting point and checks missing travel.
- **Preconditions:** Existing notches ideally indexed consecutively from zero; caller must account for existing config/element-ID confusion.
- **Steps:** Equal-distribute bounds; validate notch coverage; fill gaps or use physical mapping.
- **Acceptance:** Intended implementation sets index/count .. (index+1)/count and rounds .01; coverage scan reports gaps >.001 in [0,1].
- **Failure / alternatives:** These two functions wrongly pass config ID to getter expecting element ID; divergent IDs may return not_found/wrong config. Overlaps not rejected; unmapped notches ignored; bad indices can raise during distribution. This is documented as an existing defect, not a guaranteed correct workflow.
- **Evidence:** [context implementation](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train.ex).

<a id="tr-010"></a>

### TR-010 — Drive gates, linears and inverted controls

- **Actor / intent:** Driver moves calibrated lever and obtains correct simulator InputValue.
- **Preconditions:** Active profile; connected matching device; enabled binding; valid calibration; hardware and sim ranges on notches.
- **Steps:** Receive raw event; normalize ADC to calibrated travel, divide/round .01; optional inversion; select min-inclusive/max-exclusive notch; send gate center or linear interpolation.
- **Acceptance:** Exact 1.0 permitted on final range; observed output values are descriptive; negative sim setpoints allowed; inverted/reversed layout adjusts within-linear direction.
- **Failure / alternatives:** Gaps/missing ranges/calibration/unknown pin or inactive profile silently skip; overlapping ranges choose first supplied row. No “soft pickup” synchronization with existing game position. No hardware event is generated by merely enabling a binding.
- **Evidence:** [mapper](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_mapper.ex), [mapper tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/lever_mapper_test.exs), [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_controller.ex).

<a id="tr-011"></a>

### TR-011 — Keep lever movement responsive during slow HTTP

- **Actor / intent:** Driver avoids delayed replay of stale jitter.
- **Preconditions:** Active valid mapped lever, TaskSupervisor and simulator connected.
- **Steps:** Send value then more input events while first HTTP write pending.
- **Acceptance:** At most one write per lever in flight; retain only newest target; on first success send newest directly; different levers write independently. Transient failure retains target and retries 200/400/800ms; no new hardware event needed.
- **Failure / alternatives:** Budget exhaust retains target without endless retries; fresh movement/reconnect can restart. Disconnect cancels timers; reconnect resets budget and sends retained latest. Reload/train change/deactivate kills writers/timers; already-applied game write cannot be rolled back.
- **Evidence:** [controller tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/lever_controller_test.exs).

## Buttons, keystrokes, and sequences

<a id="tr-012"></a>

### TR-012 — Create/edit/disable/delete a simple button binding

- **Actor / intent:** Profile author maps a physical or virtual matrix button to game on/off values.
- **Preconditions:** Button element/input records; active connected setup for operation.
- **Steps:** Save endpoint, on/off values, hardware type, enabled; reload; press/release; disable/unbind as needed.
- **Acceptance:** One binding per element; defaults on1/off0/enabled; two-decimal values; raw1 sends on, raw0 sends off, duplicate simple value suppressed; button_state_changed publishes local requested state. Matrix virtual inputs use same path.
- **Failure / alternatives:** Required/FK/destination conflict errors preserve config. Write failure/disconnected simulator still caches simple value and publishes local state, so delivery is not guaranteed/retried. Other raw values ignored. Latching hardware is high/low, not software toggle-on-each-press.
- **Evidence:** [schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_input_binding.ex), [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex), [binding tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_input_binding_test.exs), [simple tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_controller_test.exs).

<a id="tr-013"></a>

### TR-013 — Hold a repeating game button

- **Actor / intent:** Driver holds horn/similar control that needs repeated InputValue.
- **Preconditions:** Enabled mode momentary with endpoint/values; active train.
- **Steps:** Press -> Interacting1 then on value; repeat while active; release -> off value then Interacting0.
- **Acceptance:** Active entry exists until release; stale repeat after release harmless; train change/reload cancels repeat loop.
- **Failure / alternatives:** repeat_interval_ms validation 1..5000 does **not** control runtime rate; immediate self-message loop follows synchronous HTTP latency. Repeated press can start additional chains. Lifecycle cancel/device disconnect does not guarantee off/Interacting0 delivery; no background retry.
- **Evidence:** [controller source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex), [momentary tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_controller_test.exs).

<a id="tr-014"></a>

### TR-014 — Hold a keyboard key or modifier combination

- **Actor / intent:** Driver uses a hardware button for a game action available through keyboard.
- **Preconditions:** Active profile, keystroke binding/string, external executable present, intended receiving app has focus.
- **Steps:** Press calls key_down; release calls key_up with same string (e.g. CTRL+SHIFT+S).
- **Acceptance:** Successful executable exit publishes pressed/released; simulator connection not required for keyboard action itself.
- **Failure / alternatives:** Missing utility/nonzero exit returns error and skips local update; key string validation deferred to utility. Train change/reload/device unplug does not automatically release held keys; controller does not track keystroke active state.
- **Evidence:** [ButtonController](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex), [Keyboard](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/keyboard.ex). No live key injection performed in review.

<a id="tr-015"></a>

### TR-015 — Maintain a reusable ordered command sequence

- **Actor / intent:** Profile author defines cold-start/doors actions once and shares among buttons.
- **Preconditions:** Saved profile.
- **Steps:** Create named sequence; replace commands in ordered list or append/remove; list/get/update name/delete.
- **Acceptance:** Name1..100 unique per train; each command endpoint/value/position required; values .01; delay0..60000 after command; positions assigned list order; get/list preload ascending; failed replacement transaction preserves previous commands. total_duration sums delays only.
- **Failure / alternatives:** Empty sequence allowed; missing/invalid fields error; append concurrency can collide; delete command leaves position gaps. Runtime snapshots need button reload. Context mixing string attrs with inserted atom IDs can error. Deleting referenced sequence behavior depends DB FK documented in data reference.
- **Evidence:** [Sequence](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence.ex), [Command](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence_command.ex), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train_test.exs).

<a id="tr-016"></a>

### TR-016 — Trigger/cancel a sequence from momentary hardware

- **Actor / intent:** Driver holds a startup/action button to run ordered commands.
- **Preconditions:** Sequence mode/on_sequence; momentary hardware; active profile.
- **Steps:** Press spawns worker; each command writes current simulator client then waits delay; release cancels tracked worker.
- **Acceptance:** Nonempty sequence runs in order, cancellation interrupts long delays, completion removes tracking; train deactivation/reload kills tracked worker. No off sequence accepted for momentary hardware.
- **Failure / alternatives:** Failed/disconnected command warns and sequence continues; no rollback/compensation. Nil/empty on sequence skips. Duplicate press without release can leave untracked worker; stale completion keyed only element can remove newer tracking.
- **Evidence:** [ButtonController](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex), [sequence lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_controller_test.exs).

<a id="tr-017"></a>

### TR-017 — Run separate on/off sequences from a latching switch

- **Actor / intent:** Driver toggles on/off operations such as opening/closing doors.
- **Preconditions:** Latching sequence binding with at least one sequence.
- **Steps:** High triggers on list; low first cancels tracked on worker, then spawns optional off list.
- **Acceptance:** Off-only binding valid (high does nothing; low runs off); empty/no off only updates UI; delays after final command also wait before completion.
- **Failure / alternatives:** Release can cancel unfinished on sequence even for latching hardware; no same-profile ownership enforcement for referenced sequence. Worker controller-death monitor stops future work; commands already applied remain.
- **Evidence:** [binding validation tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/button_input_binding_test.exs), [runtime](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_controller.ex).

## Outputs and displays

<a id="tr-018"></a>

### TR-018 — Maintain an LED condition binding

- **Actor / intent:** Profile author maps game status/threshold to a hardware indicator.
- **Preconditions:** Saved hardware output/profile.
- **Steps:** Create name/output/endpoint/operator/thresholds; list/get; update condition/enable; reload; delete when obsolete.
- **Acceptance:** One binding per output per train; LED only; gt/gte/lt/lte require value_a; inclusive between also value_b; true/false operators need no numeric threshold; changed floats .01. Same output reusable across trains.
- **Failure / alternatives:** Missing FK/required/duplicate output -> changeset; threshold ordering not validated. No hysteresis/debounce operator; actual booleans required for eq operators.
- **Evidence:** [OutputBinding](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/output_binding.ex), [schema tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/output_binding_test.exs), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/output_binding_context_test.exs).

<a id="tr-019"></a>

### TR-019 — Mirror game conditions to LEDs while driving

- **Actor / intent:** Driver sees indicator state change with simulator values.
- **Preconditions:** Active profile, connected simulator at binding load, enabled output binding and connected device.
- **Steps:** Group endpoints at1000+; poll200ms; first valid entry/value rounded .01; evaluate; send hardware high/low only on condition change.
- **Acceptance:** gt/gte/lt/lte/between exact semantics; type mismatch false; invalid node/read failure retains state; deactivation/reload lowers old outputs and unsubscribes if connected.
- **Failure / alternatives:** Cache advances even if hardware write/no-port failed; stable value not replayed on device reconnect. Reconnect does not rebuild missing/lost game subscriptions automatically. No hysteresis means threshold noise may flicker. Reviewed “controller tests” copy evaluation helper and do not prove production lifecycle.
- **Evidence:** [OutputController](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/output_controller.ex), [test limitation](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/output_controller_test.exs).

<a id="tr-020"></a>

### TR-020 — Maintain a formatted display binding

- **Actor / intent:** Profile author selects an I2C display and endpoint formatting.
- **Preconditions:** Saved profile and configured I2C module.
- **Steps:** Create module/endpoint/format/optional name/enabled; list/get/edit/delete and reload runtime.
- **Acceptance:** One binding per train/module; name<=100; format1..200; `{value}` or precision0..10 tokens and literal text; no token literal allowed. Invalid value token rejected. Decimal formatting no unit conversion.
- **Failure / alternatives:** Duplicate/FK/invalid precision -> changeset; reserved script_id cannot be set through changeset; legacy invalid numeric precision renders raw. Source numeric rounded .01 before formatting so more decimals do not restore original precision.
- **Evidence:** [DisplayBinding](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/display_binding.ex), [Formatter](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/display_formatter.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/display_formatter_test.exs).

<a id="tr-021"></a>

### TR-021 — Display simulator text and recover after reconnect

- **Actor / intent:** Driver sees speed/pressure and stable text restored when device returns.
- **Preconditions:** Active profile/enabled display binding, supported HT16K33 module; simulator supplies value.
- **Steps:** Group endpoint3000+, poll200ms, require NodeValid, numeric clamp to module minimum, format/encode, initialize brightness then segments; unplug/reconnect or apply updated device configuration.
- **Acceptance:** Text sent only when different from last successful text; failure/no-port not cached and retried; device event invalidates cache/replays brightness; simulator reconnect rebuilds subscriptions; configuration replay uses persisted address/encoding/brightness/minimum, removed modules dropped; deactivate blanks.
- **Failure / alternatives:** Game nonconnected alone leaves display text until deactivation; unsupported chip has no handler. Configuration replay deliberately avoids blanking old addresses. Script display writes can compete with binding.
- **Evidence:** [DisplayController](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/display_controller.ex), [delivery/replay tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/display_controller_test.exs).

## Lua automations

<a id="tr-022"></a>

### TR-022 — Create/edit/toggle/delete a train Lua script

- **Actor / intent:** Script author adds behavior unique to a profile.
- **Preconditions:** Saved profile, runner for active use.
- **Steps:** Persist name/code/triggers/enabled; list/get; edit/toggle/remove; reload scripts.
- **Acceptance:** Name1..100 unique per profile, nonempty code required; triggers string list (empty allowed), JSON storage; runtime loads only enabled active-profile rows. Reload recompiles all and resets state/log/timers.
- **Failure / alternatives:** Syntax/on_change not checked in changeset; invalid syntax persists but stores compile_error with lua nil. No automatic runtime reload from context. Top-level code executes during compile without callback deadline.
- **Evidence:** [Script](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script.ex), [type](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script/triggers_type.ex), [schema/context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_test.exs), [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_context_test.exs).

<a id="tr-023"></a>

### TR-023 — React to a changing simulator trigger

- **Actor / intent:** Script author reacts to speed/status/control changes.
- **Preconditions:** Enabled compiled script, trigger subscription created while game connected.
- **Steps:** Poll200ms; first Values item differs from last; invoke on_change with endpoint source/value/first Values data.
- **Acceptance:** Nonnil initial value triggers; unchanged value skips; state VM survives successful calls; raw numeric precision is retained. Multiple scripts can share endpoint subscription.
- **Failure / alternatives:** NodeValid ignored; other Values fields do not independently trigger; initial nil skips; cache updates before callback, so failure does not retry same unchanged value. Subscription failure is still retained and no reconnect rebuild exists. data is Values map, not whole response.
- **Evidence:** [ScriptRunner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex), [engine tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_engine_test.exs). Runner test does not run GenServer lifecycle.

<a id="tr-024"></a>

### TR-024 — Run manually and build a self-scheduling loop

- **Actor / intent:** Script author starts blink/debounce/state-machine behavior from Run or a trigger.
- **Preconditions:** Script loaded/enabled under active profile, function on_change exists.
- **Steps:** Manual run passes source manual with nil value/data; callback changes state and schedule(ms); timer invokes scheduled event, may schedule again.
- **Acceptance:** One stored timer per script; later schedule replaces earlier; callback state persists; newest100 log entries returned newest first; no-trigger script can run manually and schedule.
- **Failure / alternatives:** Unloaded/disabled/wrong profile ID -> no-op; schedule<=0/invalid args returns usage; fractional positive truncates possibly0; no upper bound. Reload/deactivate cancels timers but queued messages lack generation token and can trigger reloaded record. No auto-run on load.
- **Evidence:** [engine](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_engine.ex), [runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex), [engine tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_engine_test.exs).

<a id="tr-025"></a>

### TR-025 — Use Lua to write simulator values and hardware outputs

- **Actor / intent:** Script author converts speed, flashes LEDs or controls cab endpoints.
- **Preconditions:** Compiled script with trigger/event or saved state; desired hardware/Client available.
- **Steps:** Call api.set, output.set(DB ID,on), display.set(I2C address,text), print; engine captures in order and runner applies after successful callback.
- **Acceptance:** api.set optimistic true, output numbers truncated IDs/Lua truthiness, display address truncated with string text; effects apply in call order; print tabs console. Speed conversion uses event.value because api.get always nil/not available and is ignored by runner.
- **Failure / alternatives:** Missing output/module warnings, disconnected writes skipped/warned, no retry/compensation/console error propagation. Display chooses first matching address across all devices and lacks binding brightness/minimum handling. Scripts/bindings compete for hardware. Effects after earlier success cannot be undone.
- **Evidence:** [engine](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_engine.ex), [runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex), [effect tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_engine_test.exs), [guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/lua-scripting.md).

<a id="tr-026"></a>

### TR-026 — Diagnose Lua failure and protect callback responsiveness

- **Actor / intent:** Script author sees runtime errors while the app continues.
- **Preconditions:** Loaded script; callback invoked.
- **Steps:** Compile error or runtime exception/infinite callback occurs; inspect compile_error/log after run.
- **Acceptance:** Compile failure skips execution; runtime exception appends error with old VM retained; callback >200ms killed and timeout logged; failed callback effects discarded; future changed/manual/scheduled events may run again.
- **Failure / alternatives:** Code at top level is not time-limited; HTTP/DB/serial effect execution lies outside200ms and blocks runner; no explicit memory quota; wrapper relies on Lua library sandbox defaults (io blocked test only). Cleanup cancels subscriptions/timers but does not restore game or turn off script outputs/blank displays.
- **Evidence:** [runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_runner.ex), [engine](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script_engine.ex), [engine error tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_engine_test.exs), [runner test's limited scope](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/train/script_runner_test.exs).

## Rewrite acceptance coverage

The stories intentionally expose different success semantics: lever writes retain/retry latest; button actions cache requested local state even on transport failure; output state can be cached despite undelivered write; display text is cached only after success; Lua host calls return optimism and apply effects later; sequences continue after failed commands. Harmonizing these behaviors is a product decision, not a safe mechanical translation assumption.

Repository guides are supplementary reference. [Train configuration](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/train-configuration.md) still describes 15s/ProviderName detection, fixed momentary repeat and full gap/overlap validation; [lever architecture](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/lever_input_mapping_architecture.md) uses output ranges directly and calls wizard proposed. Current source and the caveats above take precedence for reverse engineering. No story here asserts hardware/game runtime verification.
