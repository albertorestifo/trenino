# Parity audit — Elixir oracle (`lib/trenino/**`) → Rust rewrite (`crates/**`, `tauri/src-tauri`)

Date: 2026-10-25 · Branch: `codex/rust-rewrite` · Scope: READ-ONLY audit, no code changed.

## Method and confidence

Every public function of every Elixir module under `lib/trenino/**` (~65 modules, ~420 public
functions) was enumerated and mapped to its Rust counterpart. Eight subsystem passes were
cross-checked against both sources and both test suites; every status below is backed by opened
code, not by prior agents' reports. Where prior reports were consulted, claims were re-verified —
two widely-cited claims were re-tested against the live Elixir oracle (`elixir -e`):

- **HT16K33 align-right width**: a subsystem review alleged Rust counts graphemes where Elixir
  counts codepoints. **False.** `String.length/1` counts graphemes (verified:
  `String.length("e\u{0301}1") == 2`, charlist length `3`), and both sides then truncate by
  codepoint/scalar (`String.to_charlist |> Enum.take` ≡ `chars().take`). Rust test bytes
  `[0,0,0,0,251,0,0,0]` for `"e\u{0301}1"` match the oracle padding output (`"  é1"`). PARITY —
  the earlier supervisor fix (`hardware-supervisor-report.md` P2 #2) is correctly closed.
- **Sequence-command rounding**: a subsystem review alleged divergence at `0.145` (wrong example —
  both give 0.14 there) but the underlying claim is **true**: `Float.round(0.015, 2) == 0.01`
  while naive `(v*100).round()/100 == 0.02`. `sequences.rs:rounded` uses the naive form;
  `trains.rs:round2` correctly uses `round_elixir` (pinned at `controls_parity.rs:524`). Real,
  undocumented divergence — see GAP P0-4.

Legend: **PARITY** (behavior + tests both sides agree), **DOCUMENTED-DIVERGENCE** (divergence named
in `docs/handoffs/2026-10-24-rust-rewrite/**` — doc cited), **PARTIAL** (counterpart exists;
behavior or test coverage incomplete), **GAP** (no counterpart).

UI track boundary: LiveView pages (`lib/trenino_web/live/**`) → Svelte/Tauri is owned by the
parallel UI tracks; this audit covers the backend command surface they consume
(`tauri/src-tauri/src/rust_ui.rs`, 59+ commands verified present for settings, hardware detail +
child CRUD, calibration, trains/levers/notches, sequences, bindings, scripts, firmware, vJoy).

---

## 1. Serial (framing, protocol, discovery, connection)

Elixir: `lib/trenino/serial/**` · Rust: `crates/trenino-core/src/hardware/protocol/codec.rs`,
`crates/trenino-runtime/src/hardware/{discovery,transport,mod}.rs`.

| Elixir fn/module | Rust counterpart | Test | Status |
|---|---|---|---|
| `framing.ex` `add_framing/2` (COBS + custom trailing zero + `0x00` delimiter) | `codec.rs` `FrameDecoder::encode_frame` | `hardware_protocol.rs::framing_preserves_custom_trailing_zero_and_recovers_after_bad_frame`, `::framing_handles_fragmented_and_254_byte_boundary` ↔ `framing_test.exs` COBS describes | PARITY |
| `framing.ex` `remove_framing/2`/`process_buffer/2` (drop invalid, keep buffer, `:in_frame`) | `codec.rs` `FrameDecoder::push` + `decode_cobs` | `hardware_protocol.rs::framing_handles_coalesced_empty_delimiters_and_malformed_recovery`, `::every_two_chunk_split_decodes_the_same_coalesced_stream` ↔ `framing_test.exs` | PARITY |
| `framing.ex` `flush/2`, `frame_timeout/1` | none (no-op equivalents) | — | PARTIAL (behaviorally equivalent no-ops; nothing to pin) |
| `framing.ex` unbounded buffer | `codec.rs` `MAX_ENCODED_FRAME_BYTES = 523` + resync | `hardware_protocol.rs::oversized_unterminated_frame_is_bounded_and_decoder_resynchronizes` | DOCUMENTED-DIVERGENCE — `hardware-fix1-review.md` (intentional hardening) |
| `protocol/message.ex` `decode/1` id table 0x00–0x08, 0x0D–0x0F, error atoms | `codec.rs` `decode_message` (`UnknownMessageType`/`InsufficientData`/`InvalidMessage`) | `hardware_protocol.rs::message_bytes_match_firmware_contract` ↔ `protocol_test.exs` + per-message `test/trenino/serial/protocol/*_test.exs` | PARITY (Rust decode additionally rejects HT16K33 subtype on decode — firmware asymmetry, encode-side oracle only) |
| All 12 protocol message `encode/1`/`decode_body/1` (`identity_request/response`, `configure`, `configuration_stored/error`, `input_value` LE i16, `heartbeat`, `set_output`, `retry_calibration`, `write_segments` ≤16B, `set_module_brightness` 0–15, `module_error`) | `codec.rs` `Message::*` arms, golden bytes | `hardware_protocol.rs::message_bytes_match_firmware_contract`, `::configure_payloads_roundtrip_and_reserved_types_rejected`, `::configure_builder_has_exact_golden_wire_packets` ↔ per-message Elixir tests | PARITY |
| `discovery.ex` `discover/1` — 3000 ms settle, drain, 5×1000 ms reads | `discovery.rs` `discover*` (`DiscoveryTiming::default` identical constants) | `hardware_runtime.rs::discovery_outer_deadline_bounds_a_port_that_never_stops_sending_noise`, `::runtime_is_inert_until_started_then_discovers_owned_port_and_joins_on_shutdown` ↔ `discovery_test.exs` | PARITY (Rust adds 10 s outer deadline; drain under deadline vs single flush — equivalent intent) |
| `discovery.ex` accepts any `IdentityResponse` | `discovery.rs` requires matching `request_id`, retries stale | `hardware_runtime.rs::discovery_retries_a_stale_identity_and_accepts_only_matching_request_id` | DOCUMENTED-DIVERGENCE — prescribed by `hardware-runtime-brief.md` |
| `discovery.ex` trailing frames after identity (discarded) | `DiscoveryResult{decoder, trailing_messages}` | `hardware_runtime.rs::discovery_returns_coalesced_and_partial_trailing_messages_to_port_owner` | DOCUMENTED-DIVERGENCE — required by `hardware-runtime-correctness-review.md` |
| `connection.ex` `enumerate_ports/0` ignore patterns (Bluetooth/debug/TONE, case-insensitive, sorted) | `transport.rs` `is_ignored_port`/`eligible_ports` | exercised via `hardware_runtime.rs` fake only ↔ `connection_test.exs` "ignored_port?/1" | PARTIAL — same 3 patterns; no per-pattern Rust test |
| `connection.ex` `scan/0` **clears failed ports → bypasses 30 s backoff** (`clear_failed_ports/1`, connection.ex:261-267, 494) | `hardware/mod.rs` `scan_now` sets `next_scan = now` only; failed ports re-enter `retry_after` for 30 s (mod.rs:899) | scan exercised in `hardware_runtime.rs`; no Rust test pins bypass ↔ no direct Elixir test (code + comment pin it) | **PARTIAL — behavioral gap: manual scan cannot bypass backoff** |
| `connection.ex` periodic scan 60 s interval / 1 s initial | `hardware/mod.rs` `SCAN_INTERVAL`/initial 1 s | `hardware_runtime.rs` startup test | PARITY |
| `connection.ex` `@failed_port_backoff_ms 30_000` + `device_connection.ex` `should_retry?/2` | `hardware/mod.rs` `FAILURE_RETRY = 30 s` + `retry_after` map | no Rust unit test pins the value/boundary ↔ `device_connection_test.exs` "should_retry?/2", `connection_test.exs` backoff test | PARTIAL — constant matches, unpinned |
| `device_connection.ex` state machine (`connecting→discovering→connected→uploading→disconnecting→failed`), `mark_*`, idempotent `mark_failed`, `mark_uploading`/`release_upload` tokens | `hardware/mod.rs` `OwnedPortTask` + generations + `PortHandoff{reservation_id}` | `hardware_runtime.rs` runtime/handoff tests; `firmware_upload.rs::manager_rejects_second_upload_while_one_is_running` ↔ `device_connection_test.exs` lifecycle/uploading describes | PARITY (re-architected; token semantics preserved — base64 token → u64 reservation id) |
| `device_connection.ex` `format_error_reason/1` (human-readable port errors) | none (`PortEvent::Failed` carries raw debug strings) | — | **GAP** (UI-facing error strings) |
| `connection.ex` `send_message/2` (`not_connected`/`unknown_port` guards, framed write) | `DiscoveryHandle::send_message` (generation fence, bounded queue, cancel) | `hardware_runtime.rs::blocked_write_applies_bounded_command_backpressure`; `hardware_service.rs` ↔ implicit | PARTIAL — functional parity with stricter fencing; error strings differ |
| `connection.ex` `request_upload_access/1` / `release_upload_access/2` (global single-flight, closes UART, token match, **500 ms delayed rescan** connection.ex:249) | `begin_handoff`/`begin_release_handoff` + `ResourceArbiter` lease; release → **immediate** rescan | `hardware_runtime.rs::handoff_reservation_cannot_be_overwritten…`; `firmware_upload.rs::manager_happy_path…` ↔ `device_connection_test.exs` release_upload | PARITY except rescan delay: **500 ms → immediate, undocumented** |
| `connection.ex` stale discovery-result discard | generation fence + sink wrapper | `hardware_runtime.rs::resolver_replaces_a_port_map_atomically_and_fences_old_generations` ↔ `connection_port_timeout_test.exs` stale-result test | PARITY |
| `connection.ex` `subscribe/0`, `subscribe_messages/1` (PubSub) | `PortEvent` sink → UI bridge | fake-sink tests | PARTIAL (push model replaces topics; no topic-equivalence test) |
| `connection.ex` cleanup machinery — `@cleanup_timeout_ms 5_000`, `@discovery_timeout_ms 10_000`, force-fail, `:DOWN` | `hardware/mod.rs` `CLEANUP_DEADLINE`/`DISCOVERY_TIMEOUT`, worker join/panic | `hardware_runtime.rs::shutdown_timeout_retains_worker…`, `::discovery_coordinator_deadline…`, `::joined_worker_panic_is_reported…` ↔ `connection_port_timeout_test.exs` | PARITY |
| `connection/state.ex` (`get/put/update/delete/tracked?/connected_devices`) | internal port maps in `hardware/mod.rs` | covered indirectly | PARITY (structural) |

## 2. Hardware domain + context

Elixir: `lib/trenino/hardware.ex`, `hardware/**` · Rust: `crates/trenino-core/src/hardware/**`,
`crates/trenino-runtime/src/storage/hardware.rs`, `hardware/{service,sessions,configuration,repository}.rs`.

| Elixir fn/module | Rust counterpart | Test | Status |
|---|---|---|---|
| `ConfigId.generate/0` (unbounded retry, `:rand.uniform(i32_max)`) | `storage/hardware.rs:588` `generate_config_id` — **1024 attempts then error; modulo bias** | `storage_hardware.rs::typed_hardware_mutations_roundtrip_ids_and_bump_once` ↔ `hardware_test.exs` "generate_config_id/0" | PARTIAL — new failure mode + bias, undocumented |
| `ConfigId.valid?/1` (1..=2_147_483_647) | `core/shared.rs` `ConfigId::new` | `foundation.rs::entity_ids_are_decimal_strings_and_config_ids_are_distinct` | PARITY |
| `ConfigId.parse/1` (string→id) | none | — | GAP (UI-facing parse; low impact) |
| `device.ex` `changeset/2` (auto config_id, name required, unique) | `storage/hardware.rs` `create_device`/`update_device` | `storage_hardware.rs` roundtrip ↔ `hardware_test.exs` device describes | PARITY |
| `hardware.ex` `get_device/2`, `get_device_by_config_id/1`, `list_configurations/1` | `get_device`, `get_device_by_config_id`, `all_devices` (`ORDER BY name,id`) | `repository.rs` inline `resolves_persisted_configuration_by_identity_and_confirms_atomically` ↔ `hardware_test.exs` | PARITY |
| `hardware.ex` `confirm_configuration/2` | `repository.rs::confirm_configuration`, gated in `configuration.rs::apply_configuration_with` (ACK + generation) | `hardware_service.rs::service_owns_discovery_routing_configuration_ack_and_disconnect_revocation` ↔ `hardware_test.exs`, `configuration_manager_test.exs` | PARITY (strictly stronger gating) |
| `configuration_manager.ex` `apply_configuration/2` (Configure parts, ConfigurationStored/Error, `:no_inputs`, config timeout) | `configuration.rs::apply_configuration_with`; `ApplyError::{DeviceRejected,Timeout,Persist}` | `hardware_runtime.rs` resolver/apply tests; `hardware_service.rs` ↔ `configuration_manager_test.exs` | PARITY |
| `configuration_manager.ex` `subscribe*`, `get_input_values/1`, `config_id_to_port/1`, `port_to_config_id/1` | `InputValueCache` (`routing.rs`), service snapshot | `hardware_runtime.rs` resolver tests ↔ implicit | PARTIAL (no topic/port-string equivalents; cache semantics pinned) |
| `input.ex` `changeset/2` (pin 0–127 phys / 128–255 virtual; analog sensitivity 1..10; button debounce 0..255; unique device+pin), `virtual?/1` | `core/hardware/mod.rs` `AnalogInput/ButtonInput::validate`; `storage/hardware.rs::validate_input` | `hardware_models.rs::boundaries_and_detection_threshold_match_legacy`; `storage_hardware.rs::input_validation_and_duplicate_conflict…` ↔ `input_test.exs` | PARITY |
| `output.ex` `changeset/2` (pin 0..255, name ≤100, unique) | `storage/hardware.rs::write_output` | `storage_hardware.rs` ↔ `output_test.exs` (incl. 0/255/101 boundaries) | PARITY |
| `i2c_module.ex` `changeset/2`, `parse_i2c_address/1` (dec or `0x`, `0X` rejected, 0..255) | `core/hardware/mod.rs::Module::parse_address` | `hardware_models.rs::i2c_and_display_parameters_keep_legacy_ranges` ↔ `i2c_module_test.exs` (all 8 cases) | PARITY |
| `i2c_module.ex` `format_i2c_address/1` ("112 (0x70)") | none | — ↔ `i2c_module_test.exs` format describe | GAP (display-only) |
| `matrix.ex` `changeset/2`, `num_rows/1`, `num_cols/1`, `virtual_pin/3` (128+r*cols+c) | `core Matrix::virtual_pin`; `storage/hardware.rs::replace_matrix_children` (debounce 50, `R{r}C{c}`) | `hardware_models.rs::builder_rejects_duplicate_physical_pins…`; `storage_hardware.rs::matrix_children_are_ordered_generated_and_replaced_atomically` ↔ `hardware_test.exs` matrix describes | PARITY |
| `input/matrix_pin.ex` `changeset/2` (unique position) | DB unique index only | indirect | PARTIAL (no dedicated Rust test) |
| `ht16k33.ex` `encode_string/2` 14-seg + 7-seg (tables, dot \| 0x80, leading-dot slot, unknown blank, align-right) | `core/ht16k33.rs::encode_string` (unicode_segmentation graphemes) | `hardware_models.rs::segment_encoding_keeps_digit_order_padding_dot_and_unknown_behavior`, `::display_alignment_matches_legacy_for_dots_and_combining_graphemes` ↔ `ht16k33_test.exs` | **PARITY — verified against live oracle (see header; an alleged divergence was disproved)** |
| `ht16k33/params.ex` `changeset/2` (brightness 0–15, num_digits 4/8) | `storage/hardware.rs::validate_module` | `hardware_models.rs::i2c_and_display_parameters_keep_legacy_ranges` ↔ `ht16k33_test.exs` Params describe | PARITY |
| `hardware.ex` input/output/matrix/i2c CRUD + `list_inputs/2` (order pin, virtual excluded), `list_outputs/1`, `list_i2c_modules/1` (order address) | `storage/hardware.rs` CRUD set, same ORDER BYs | `storage_hardware.rs`; `app_services_surface.rs::hardware_detail_and_child_crud_round_trip` ↔ `hardware_test.exs` CRUD describes | PARITY |
| `hardware.ex` `list_all_inputs/1` (**calibrated-only** cross-device) | snapshot returns all inputs (calibration embedded, unfiltered) | `app_services_surface.rs::every_topic_returns_a_snapshot_from_a_seeded_database` ↔ `hardware_test.exs` | PARTIAL — calibrated-only filter not reproduced |
| `hardware.ex` `delete_device/1` (`:configuration_active` guard, cascades) | `DeviceDeletionFence` + service `delete_device` + tombstones | `storage_hardware.rs::cascade_delete_is_transactional_and_has_no_public_unchecked_entrypoint` ↔ `hardware_test.exs` delete describes | PARITY |
| `hardware.ex` `set_output/3`, `write_segments/3` | codec `Message::SetOutput`/`WriteSegments` + `HardwareDispatch` seam | `hardware_protocol.rs` ↔ protocol tests | PARITY (message level; context helpers are dispatch seams) |
| `hardware.ex` `save_calibration/2` (upsert by input_id) | `storage/hardware.rs::save_calibration` | `storage_hardware.rs::calibration_roundtrip_replaces_in_one_revision_and_missing_input_fails` ↔ `hardware_test.exs` | PARITY |
| `hardware.ex` `start_calibration_session/3` → `calibration/session.ex` GenServer (steps `ready→collecting_min→sweeping→collecting_max→analyzing`; gates ≥10 samples ∧ ≥3 unique (min/max), sweep ≥10 no-unique-check; `advance_step`, `cancel`, `subscribe`; PubSub) | `hardware/sessions.rs` `CalibrationSession` (`observe`, `advance`, `advance_and_persist`, terminal latch) — **identical step order and gates verified in source** | `hardware_runtime.rs` 25-test session suite; `storage_hardware.rs` ↔ **no Elixir ExUnit oracle for the session GenServer itself** (only analyzer/calculator tested) | PARTIAL — logic parity source-verified; oracle-side test gap; Rust adds Overflow/Cancel/SourceLost latches (documented in `hardware-runtime-report.md`) |
| `calibration/session_supervisor.ex` | `HardwareSessions` registry (cap 1024, DuplicateId, reap) | `hardware_runtime.rs` owned-session tests | PARTIAL (Rust additions; no oracle behavior) |
| `calibration/analyzer.ex` `analyze_sweep/2` (median-delta inversion; rollover peak > max(med*3,10) ∧ > 0.8·max_hw; <2 → false/false), `calculate_min/2`, `calculate_max/2` | `core/hardware/calibration/mod.rs` `analyze_sweep`/`calculate_min`/`calculate_max` | `hardware_calibration.rs::detects_inversion_and_rollover_and_integer_median`, `::calibration_matches_integer_edges…`, `::invalid_extreme_calibration_data_clamps_safely…` ↔ `analyzer_test.exs`, `calculator_test.exs` | PARITY (integer median truncation matched; empty-input: Rust None vs Elixir raise — edge only) |
| `calibration/calculator.ex` `normalize/2`, `total_travel/1` (4 quadrants, dead-zone `div`, clamp) | `calibration/mod.rs` same fns | `hardware_calibration.rs` (3 tests incl. dead-zone ties) ↔ `calculator_test.exs` | PARITY (Rust adds `max(0)`/i32::MAX clamp hardening) |
| `input_detection_session.ex` (baseline per {port,pin}, button any-change, analog \|Δ\|>50, filter, 60 s timeout, DOWN) | `sessions.rs` `InputDetectionSession` + core `InputDetection` | `hardware_models.rs::detection_supports_button_press_and_release_and_type_filtering`; `hardware_runtime.rs` owned-detection tests ↔ `input_detection_session_test.exs` | PARITY (generation-keyed baselines documented in `hardware-runtime-report.md`) |

## 3. Train domain context

Elixir: `lib/trenino/train.ex` (~70 fns) + 13 schemas + `display_formatter.ex`, `lever_mapper.ex`, `identifier.ex` ·
Rust: `crates/trenino-runtime/src/storage/domain/{trains,bindings,sequences,scripts}.rs`, `crates/trenino-core/src/train/*`, `app.rs` wrappers.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| `list_trains/1` (name order) | `Database::list_trains` (`ORDER BY name,id`) | `domain_trains.rs::list_trains_ordered_by_name` ↔ `train_test.exs` | PARITY |
| `get_train/2`, `get_train_by_identifier/1` (prefix, dedup, `not_found`/`multiple_matches`) | `get_train`, `get_train_by_identifier` → `IdentifierMatch` | `domain_trains.rs` 4 tests ↔ `train_identifier_matching_test.exs` (5 tests) | PARITY |
| `create_train/1`, `update_train/2`, `delete_train/1` (name required, ≥1 identifier, trim, unique identifier, `on_replace: :delete`) | `create_train`/`update_train`/`delete_train` | `domain_trains.rs::create_train_*` (7), `update_train_*`, `delete_train_cascades` ↔ `train_test.exs` | PARITY |
| element CRUD (`list_elements/1` name order, `get_element/2`, `create_element/2`, `delete_element/1`) | `list_train_elements`, `get_train_element`, `create_train_element`, `delete_train_element` | `domain_trains.rs` ↔ `train_test.exs` | PARTIAL — storage accepts whitespace-only name (`draft.name.is_empty()` only); Ecto `validate_required` rejects `" "`; masked only at app layer (`app.rs::validate_name`) |
| lever config CRUD + `create_lever_config_with_analysis/3`, `update_lever_config_with_analysis/3` | `create/update_lever_config(_with_analysis)` + `insert_suggested_notches` | `domain_trains.rs` ↔ `train_test.exs` (analysis path has thin oracle) | PARITY |
| `save_calibration/2` (delete-all+insert, index=list position, calibrated_at) / `save_notches/2` | `save_lever_calibration` / `save_notches` | `domain_trains.rs::save_calibration_sets_calibrated_at_and_indexes`… ↔ `train_test.exs` | PARITY / PARTIAL (no-timestamp distinction unpinned in oracle) |
| notch CRUD + `update_notch_description/2`; notch changeset (gate/linear rules, 0–1 input bounds, sim unbounded, 2-dp rounding of 7 floats, unique (config,index)) | `create_notch`, `update_notch`, `update_notch_description`, `delete_notch`; `validate_notch_fields` (rule-for-rule; `round_elixir`) | `domain_trains.rs::create_notch_validates_and_rounds`… ↔ `notch_test.exs` | PARITY |
| `update_notch_input_ranges/3` (+`inverted` opt; unknown notch rolls back) | `update_notch_input_ranges` | `domain_trains.rs::update_notch_input_ranges_batch_and_inverted`, `::_unknown_notch_rolls_back` | PARTIAL — error shape `{:error,{:not_found,id}}`/`{:update_errors,_}` → `Constraint{"notch N not found"}`; atomicity verified |
| `auto_distribute_input_ranges/1` (step=1/count, 2-dp, empty no-op) | `auto_distribute_input_ranges` | `domain_trains.rs::auto_distribute_evenly_divides_input_range` | PARTIAL — math parity; Elixir latent bug (looks up by element_id via `get_lever_config/1`) fixed silently in Rust — documented only in a code comment |
| `validate_notch_ranges/1` (sort by index, nil filter, ε=0.001, trailing gap) | `validate_notch_ranges` + `find_gaps` | `domain_trains.rs::validate_notch_ranges_detects_gaps` | PARITY (`{:error,:not_found}` → `Ok(None)`) |
| lever binding: `get_binding/1`, `bind_input/2,3`, `unbind_input/1`, `set_binding_enabled/2,3`, `list_bindings_for_train/1` | `bindings.rs` same-named | `domain_bindings.rs::lever_binding_lifecycle`… ↔ `train_test.exs`, `virtual_joystick_test.exs:376` | PARITY |
| vJoy destination exclusivity (`replace?`, `:destination_conflict`, rollback, disabled bypass) — lever + button | `apply_destination_exclusivity` / `vjoy_put_mapping` | `domain_bindings.rs` 4 tests ↔ `train_test.exs` "requires replacement before enabling…" | PARITY |
| `create/update/delete_button_binding`, `set_button_binding_enabled`, `get_button_binding`, `list_button_bindings_for_train`; button changeset (mode rules incl. sequence ≥1 of on/off, off_sequence latching-only, repeat 0<x≤5000, defaults 1.0/0.0/100 ms, unique element_id, 2-dp) | `bindings.rs` (verified rule-for-rule) | `domain_bindings.rs::button_binding_create_defaults_custom_values_and_rounding`, `::button_binding_mode_and_sequence_validation` (matrix), `::button_binding_unique_element_and_shared_input` ↔ `train_test.exs`, `button_input_binding_test.exs` | PARITY |
| output bindings: list (name order)/enabled-list/CRUD; changeset (operator set, value_a/value_b rules, unique (train,output), 2-dp) | `bindings.rs` | `domain_bindings.rs::output_binding_*` ↔ `output_binding_test.exs`, `output_binding_context_test.exs` | PARITY |
| display bindings: list/CRUD; changeset (format 1–200 via `DisplayFormatter.validate_format`, name ≤100, unique (train,i2c), `script_id` never cast) | `bindings.rs::validate_display_binding` | `domain_bindings.rs::display_binding_*` ↔ `display_formatter_test.exs` | PARTIAL — length check counts codepoints not graphemes (diverges only with combining marks; `core/display.rs` itself uses graphemes correctly) |
| sequences: `create_sequence/2` (name 1..=100, unique per train), `get_sequence/1,!`, `list_sequences/1` (name order), `update_sequence/2`, `delete_sequence/1` | `sequences.rs` same-named | `domain_sequences.rs` ↔ `train_test.exs` sequence describes | PARTIAL — Rust trims/rejects whitespace-only names; Ecto `validate_length(min:1)` accepts `" "`; undocumented |
| `set_sequence_commands/2` / `add_sequence_command/2` (positions, atomic, **value `Float.round(_,2)`**) / `delete_sequence_command/1` | `sequences.rs` same-named | `domain_sequences.rs` (5 tests incl. rounding) ↔ `train_test.exs` | **PARTIAL — `sequences.rs:175 rounded()` uses naive `(v*100).round()/100`; diverges from `Float.round/2` on tie-crossing values (`0.015`→0.02 vs oracle 0.01). Every other module uses `round_elixir`** |
| `sequence.ex` `total_duration/1` | none (grep: 0 hits) | — | GAP (pure reduce) |
| scripts: list/enabled/get/CRUD; changeset (name 1..=100, code required, triggers list-of-binaries, unique (train,name)) | `scripts.rs` | `domain_scripts.rs` (10 tests) ↔ `script_test.exs` | PARTIAL — (a) whitespace-name trim divergence (as sequences); (b) `validate_triggers` rejects empty/blank strings — Elixir accepts `[""]` |
| `script/triggers_type.ex` `cast/dump/load` (load: invalid/nil → `[]`) | `Triggers::encode/decode` (golden JSON round-trip) | `domain_scripts.rs::triggers_golden_json_round_trip` ↔ `script_test.exs` + migration docs | PARTIAL — stored non-string array: Elixir `load` returns raw list, Rust returns `[]` (reachable only via out-of-band writes; migration admission rejects) |
| `lever_mapper.ex` `map_input/2` (half-open ranges + exact 1.0 boundary, gates→midpoint, linear interpolation, reversed-layout flip, 2-dp at every step), `find_notch/2`, `reversed_layout?/1`, `calculate_sim_input/3`, `calculate_value/2` | `core/train/lever.rs::map_input` + internals | `controls_parity.rs::lever_mapping_preserves_half_open_ranges_and_the_exact_one_boundary`, `::reversed_layout_inverts_linear_position_after_hardware_inversion`, `::elixir_rounding_controls_mapping_and_analyzer_gate_threshold` ↔ `lever_mapper_test.exs` | PARITY |
| `display_formatter.ex` `validate_format/1`, `format/2` (precision rules, raw-fallback-on-format vs reject-on-validate) | `core/train/display.rs` | inline tests + `controls_parity.rs::display_format_matches_legacy_tokens_and_safe_invalid_precision`, `::display_formatter_preserves_legacy_lexical_precision_rules` ↔ `display_formatter_test.exs` | PARITY |
| `identifier.ex` `derive_from_formation/1`, `common_prefix/1`, `extract_train_name/1` (+ `normalize_object_class`) | `core/train/identifier.rs` + `simulator/services/train_detection.rs::derive_identifier` | `controls_parity.rs` 4 tests (oracle doctests + cases) ↔ `identifier_test.exs` | PARITY |
| `train.ex` `identifier_values/1`, `train_identifier.ex`/`element.ex`/`lever_config.ex`/`lever_input_binding.ex` changesets | covered by domain validation above | — | PARITY (structural) |
| `list_button_elements/1` | none (grep: 0 hits in crates/ + tauri) | — ↔ `train_test.exs` "list_button_elements/1" (3 tests) | **GAP** |
| `list_all_i2c_modules/0` (delegate) | no named fn; `HardwareSnapshot.i2c_modules` carries all modules | `app_services_surface.rs` snapshot test | PARTIAL (data available; no calibrated/named surface — display path uses snapshot) |

## 4. Runtime train controllers, scripts, sequences, calibration sessions

Elixir: `lib/trenino/train/{lever_controller,button_controller,output_controller,display_controller,script_runner,script_engine,detection}.ex`, `calibration/{lever_session,notch_mapping_session,session_supervisor}.ex` ·
Rust: `crates/trenino-runtime/src/train/**`, `simulator/services/{calibration,train_detection}.rs`.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| lever controller: coalescing (`enqueue_value/3`), `finish_write/3`, `cancel_pending/1`, normalization (2-dp, travel guard) | `train/lever_controller.rs` (`enqueue_value`, `finish_write`, `cancel_pending`, `apply_input` w/ `round_elixir`) | `control_dispatch.rs` (cites `lever_controller_test.exs:92-130,132-160,162-171,173-182,184-199,201-212,214-224,226-245,247-268,296-315,317-328` — line citations verified) | PARITY |
| retry ladder `[200,400,800]` ms, tokens, reconnect-fresh-budget, disconnect parking | `RETRY_DELAYS` const + same mechanics | `control_dispatch.rs` (cited lines verified) ↔ `lever_controller_test.exs` | PARITY (constants verified equal) |
| write timeout model (Req receive 10 s / pool 1 s) | total deadline 10 s + queue-admission 5 s/500 ms | client-level tests | DOCUMENTED-DIVERGENCE — `controls-report.md` |
| button controller: simple dedup (`last_sent_values`), momentary Interacting ordering + request-paced repeat (no interval — quirk preserved), `derive_interacting_endpoint/1`, sequence mode (ordered+delays, failure continues, momentary-cancel, latching off-sequence, nil/empty skip, repress cancel) | `train/button_controller.rs` + `core/train/buttons.rs::transition` | `control_dispatch.rs` (cites `button_controller_test.exs:379-463,466-527,529-651,587-604,653-684,686-716,718-753,755-786,788-828` — verified) ↔ `button_controller_test.exs` | PARITY |
| latching release cancels active sequence first (`button_controller.ex:492-494`) | `buttons.rs:155-169` — cancellation emitted for momentary only; latching w/ empty off-sequence emits no cancel | probed in `controls-supervisor-report.md` P2 #3; current tests cover non-empty paths | PARTIAL — supervisor finding; verify fixed state before closing (test `sequence_latching_release_starts_off_sequence` covers non-empty off-seq only) |
| momentary with `endpoint: nil` | `unwrap_or_default()` → sends to `""` path (client rejects) vs Elixir explicit `nil` branch | none | PARTIAL (micro-edge, unpinned both sides) |
| sequence executor (`execute_sequence_commands/3`, monitor, stale `sequence_complete` ignore) | **two executors**: `train/sequence.rs::SequenceExecutor` (tested) AND `button_controller.rs::spawn_sequence` (wired) | `output_display.rs` 7 sequence tests ↔ `button_controller_test.exs:788-828` | PARTIAL — `SequenceExecutor` is unwired duplicate; button path is live |
| output controller: 200 ms poll, sub IDs 1000+, one sub per endpoint, dedup, predicate+fallback-false, NodeValid/empty/fetch-error untouched, no reconnect reaction | `train/output_controller.rs` + `core/output.rs::evaluate_output`/`subscription_reading` | `output_display.rs` (7+ tests) ↔ `output_controller_test.exs` "evaluate_condition/2" matrix | PARITY (endpoint order lexicographic vs Elixir small-map term order — documented inline) |
| display controller: 200 ms poll, IDs 3000+, brightness-first, success-only cache, reconnect reload, devices_updated replay, clamp-to-min, blank on cleanup | `train/display_controller.rs` | `output_display.rs` (7+ tests) ↔ `display_controller_test.exs` | PARITY |
| detection: `@poll_interval_ms 5_000`, grace 30 s / 200 ms polls, sync clears identifier, deactivate broadcast, ambiguity | `simulator/services/train_detection.rs` | `simulator_detection.rs` (8 tests) ↔ `detection_test.exs` (`detection.ex:29` verified) | PARITY |
| activation/service (release-before-activate, manual sync after CRUD) | `train/service.rs` | `train_sessions.rs` (7 tests) ↔ controller reload tests | PARITY |
| `script_engine.ex` `new/1`/`execute/2` (sandbox, effects, truthiness, 200 ms timeout, rollback) | `script/engine.rs` `ScriptVm::compile/execute` (dual-VM rollback) | `script_engine_corpus.rs` (84+ tests) ↔ `script_engine_test.exs`, `script_context_test.exs` | PARITY + DOCUMENTED-DIVERGENCE — bounds (memory/instruction/effect), error text, `math.random` determinism, etc. enumerated in `script-corpus.md` §5 |
| `script_runner.ex` trigger half (`matching_scripts`) | `script/triggers.rs::matching_scripts` | `script_engine_corpus.rs:801-862` (4 tests) ↔ `script_context_test.exs` | PARITY |
| `script_runner.ex` runtime half (200 ms polling, change-only firing, 100-entry log ring, schedule timers, effect application, `run_script/1`, `get_script_log/1`) | **none** (engine+triggers have no caller outside tests) | — ↔ `script_runner_test.exs` | **GAP — DOCUMENTED-DIVERGENCE (deferral): `script-corpus.md` §6; scripts cannot run in the Rust app today** |
| `calibration/lever_session.ex` (step 0.025, tol 0.001, delay 5 ms, gate precedence, single-notch, finalize-at-max, progress, save) | `simulator/services/calibration.rs` (`start_lever_calibration`, `run_calibration`) | `simulator_detection.rs::lever_calibration_*` (4 tests) ↔ `lever_session_test.exs` | PARITY |
| `notch_mapping_session.ex` state machine (ready→mapping_notch→preview→saving; `capture_range` errors `:no_samples`/`:no_range_detected`, single-point ok; `reset_samples`, start/stop_capturing, `go_to_notch` bounds, `go_to_preview`, `save_mapping` 4-dp + inversion first-wins, `cancel`, `subscribe`) | `calibration.rs` `NotchMappingMonitor` + fns | `simulator_detection.rs::notch_mapping_walks_captures_preview_and_saves`, `::notch_mapping_rejects_invalid_transitions_and_foreign_pins`, `::notch_mapping_auto_detects_inversion`, `::notch_mapping_checkpoints_persist_and_resume_after_cancel` ↔ `notch_mapping_session_test.exs` | PARITY except `start_mapping` below |
| `start_mapping/1` — always notch 0 | `StartMapping` → first **uncaptured** notch (resume) | checkpoint test | DOCUMENTED-DIVERGENCE — checkpoint/resume extension (`remaining-work.md` item 5; code comment). Fresh sessions behave identically |
| `session_supervisor.ex` (`:already_running`, `stop_*`, `session_running?`) | `ResourceArbiter` lease (duplicate start → `ResourceError`) | `notch_mapping_releases_lease_on_cancel_and_drop` | PARTIAL — exclusion preserved; no `:already_running`-named contract, no `session_running?` helper |

## 5. Simulator client + connection + analysis

Elixir: `lib/trenino/simulator/**` · Rust: `crates/trenino-runtime/src/simulator/**`.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| `client.ex` `new/2` (`DTGCommKey` header, pool 5 s, receive 10 s, retry transient ×2, delay 100·attempt) | `client.rs::SimulatorClient::new` (same profile) | `simulator_lifecycle.rs::simulator_client_escapes_path_authenticates_and_preserves_response_envelope` ↔ `client_test.exs` | PARITY |
| `with_fast_timeouts/1` (1 s / 500 ms / 0 retries) | `TimeoutProfile::Fast` | `::simulator_client_preserves_fast_profile…` ↔ `client_test.exs` | PARITY |
| `info/1`, `list/2`, `get/2`, `set/3`, `subscribe/3`, `get_subscription/2`, `unsubscribe/2`, `list_subscriptions/1` (verbs/paths/query) | `client.rs` identical verbs/paths | `::simulator_client_escapes_path…` ↔ `client_test.exs` | PARITY |
| `encode_path/1` percent-encoding set | `client.rs::encode_path` (equivalent unreserved set) | `::simulator_path_encoding_preserves_valid_delimiters_and_unicode` | PARITY |
| — | `operation_path` dot-segment confinement | `::simulator_paths_reject_dot_segments…` | DOCUMENTED-DIVERGENCE — `controls-report.md` #10 |
| — | redirects disabled (key non-forwarding) | same test | DOCUMENTED-DIVERGENCE — `controls-report.md` #11 |
| retry `:transient` (all methods) | safe-reads only | `::normal_safe_reads_retry_transient_statuses_but_fast_reads_do_not` | DOCUMENTED-DIVERGENCE — `controls-report.md` #9 |
| error shapes (`{:invalid_key, body}` etc.) | `SimulatorError` enum (403 body dropped) | `::simulator_client_classifies_non_json_statuses_before_decoding_the_body` | PARITY (403-body drop is the only micro-delta; untested both sides) |
| `get_int/1` (trunc, strict parse) / `get_float/1` (`Float.round 2`) / `get_string/1` (int/float lexeme preservation) | `client.rs` + `SimValue::to_legacy_string` | `::simulator_client_uses_elixir_ties_rejects_overflow_and_never_saturates_integers`, `::simulator_string_reads_preserve_integer_float_and_exponent_lexemes`; `controls_parity.rs::display_raw_token_preserves_json_integer_float_and_exponent_text` | PARITY (rounding oracle-executed per `controls-report.md` #2; notation fix per `controls-fix2-review.md`) |
| `connection_state.ex` `mark_*`, `record_health_failure` (3-failure threshold) | `connection.rs::ConnectionState` (pure decision fns) | `::connection_lifecycle_uses_thirty_second_health_and_two_second_transient_retry_before_error`, `::invalid_key_is_a_permanent_health_failure` ↔ `connection_state_test.exs`, `connection_test.exs` health tolerance | PARITY |
| `connection.ex` GenServer runtime (30 s health, 2 s fast, 30 s retry, 1 s initial delay, `get_status`, `subscribe`, `retry_connection`, `reconfigure`, `disconnect`, broadcasts) | **no runtime owner** — state machine only | — ↔ `connection_test.exs` | **GAP — DOCUMENTED-DIVERGENCE (scope omission)**: `controls-report.md` ("runtime connection polling/reconnect supervision is not implemented"), `remaining-work.md` item 5 |
| `lever_analyzer.ex` `analyze/3` (sweep 0.02, settle 150 ms, snap 0.03, int-tol 0.05, push 5×30 ms, min 10), `quick_check/3` (5 pts, 100 ms), `analyze_samples/2` (15/20/0.15 ladder) | `services/lever_analysis.rs` + `core/calibration/analysis.rs` — constants and ladder identical | `simulator_detection.rs::lever_analysis_*` (4), `controls_parity.rs::analyzer_*` (3) ↔ `lever_analyzer_test.exs`, `lever_analyzer/analysis_test.exs` | PARITY |
| `control_detector.ex` `suggest_lever/1`, `suggest_button/1` (confidence ladder 1.0/0.85/0.75/word-blend/Jaro, 0.3 gate, tie-keeps-first) | `services/explorer.rs::suggest_*`, `confidence`, `jaro_distance` | `simulator_detection.rs::suggestions_use_the_confidence_ladder_and_gate_low_confidence`, `::exploration_fuzzy_primitives_match_elixir` | PARITY — note: **Elixir side itself has no test file** (oracle gap) |
| `control_detection_session.ex` (150 ms poll, 0.01 threshold, 30 s timeout, sub id 99, pre-clear, terminate-unsubscribe, `extract_control_name`, recursive InputValue discovery) | `services/control_detection.rs` (same constants/order; adds `ambiguous` flag) | `simulator_detection.rs::control_detection_*` (6 tests) ↔ `control_detection_session_test.exs` | PARITY (`ambiguous` additive, documented) |
| — (no Elixir registry) | `subscriptions.rs` lease registry + `writer.rs` generation-fenced writer | `simulator_lifecycle.rs` (7 tests) | DOCUMENTED-DIVERGENCE — architecture, `controls-report.md` |

## 6. Firmware

Elixir: `lib/trenino/firmware.ex`, `firmware/**`, `app_version.ex`(+checker) · Rust: `core/firmware/*`, `runtime/firmware/*`, `storage/domain/firmware_records.rs`, `tauri/src-tauri/src/{updater,update_flow}.rs`.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| `compatibility.ex` `requirement/0`, `compatible?/1` | `core/firmware/compatibility.rs` (operator-per-bound prerelease policy) | `firmware_compatibility.rs` (4 tests, executed-Elixir oracle matrix) ↔ `compatibility_test.exs` | PARITY (former F3/F4/R3/R4 closed) |
| `downloader.ex` manifest validation / `normalize_mcu` / supported programmers | `core/firmware/manifest.rs` | `firmware_compatibility.rs::manifest_validates_release_json_and_normalizes_mcu` ↔ `downloader_test.exs`, `device_registry_test.exs` | PARTIAL — Rust stricter (unsafe env/filename rejection has no Elixir oracle) |
| `downloader.ex` `fetch_github_releases/0` (URL, accept/user-agent headers, **optional `:github_token`**) | `catalog.rs::refresh` + `http.rs` (redirect-checked, 5 hops, 16 MiB cap) | `firmware_catalog.rs` refresh tests ↔ `downloader_test.exs`, `release_manifest_integration_test.exs` | PARTIAL — **`github_token` auth header has no Rust counterpart (grep-verified: no `authorization`/token in `firmware/*`)** |
| `firmware.ex` `get_latest_release/1`, `get_latest_compatible_release/1`, `get_firmware_file_for_board/2` | `catalog.rs::latest_compatible`, `select`, `available_devices` | `firmware_catalog.rs:324-359` (select/available_devices) ↔ `firmware_test.exs` | PARTIAL — **`latest_compatible` and `select`'s `Incompatible` branch untested** |
| `firmware.ex` release/file CRUD + `upsert_release/1` | `firmware_records.rs` full set | `domain_firmware_records.rs` (10 tests) ↔ `firmware_test.exs`, `firmware_release_test.exs`, `firmware_file_test.exs` | PARITY |
| `file_path.ex` cache rules (`~/.trenino/firmware_cache` vs `priv/`, `v{version}_{env|board}.hex`, `downloaded?/1`, `list_downloaded/0`) | `downloads.rs::cache_directory/cache_path` (asset-bound names per R1/R2), `legacy_cache_path` + policy | `firmware_catalog.rs` downloader tests (6) ↔ `file_path` behavior in `downloader_test.exs` | PARITY + DOCUMENTED-DIVERGENCE — legacy cache verification policy (`firmware-catalog-*-review.md`; former F1/F2 closed) |
| `downloader.ex` `check_for_updates/0`, `download_firmware/1` | `catalog.rs::refresh` → `downloads.rs::download` (locks, size checks, atomic receipts) | `firmware_catalog.rs` (concurrency/truncation/empty/status tests) | PARITY (Rust stronger: dedupe/locking — former review findings closed) |
| `avrdude.ex` `executable_path/0` (sidecar→priv→PATH), `available?/0`, `version/0`, `conf_path/0` | `upload.rs::UploadTooling` — absolute existing path only, no search | `firmware_upload.rs::missing_or_relative_avrdude_path_fails_closed` ↔ `avrdude_test.exs` | DOCUMENTED-DIVERGENCE — module-header only, **not in handoff docs** |
| `uploader.ex` `build_args/3`, `avrdude_hex_path/1` | `upload.rs::build_args` (verbatim) | `firmware_upload.rs::avrdude_invocation_arguments_match_build_args` ↔ `upload_flow_test.exs` | PARITY |
| `uploader.ex` `@error_patterns`, `parse_error_output/1`, `error_message/1` (order-sensitive AND) | `upload.rs::parse_error_output` + `friendly_message` | `::parses_avrdude_error_transcripts_like_the_oracle`, `::friendly_messages_match_the_oracle` ↔ `uploader_test.exs` | PARITY |
| `uploader.ex` `retryable_baud_rates/2` (`arduino` → [57600,115200]) | `upload.rs::retryable_baud_rates` | `::retryable_baud_rates_match_the_oracle` | PARITY |
| `uploader.ex` retry flows (port-not-found 2 s single retry w/ first output; baud exhaustion; wrong-board/permission immediate) | `run_device_upload` branches (cancelable) | `::port_not_found_retries_once_then_reports_first_output`, `::old_bootloader_nano_retries_at_alternate_baud`, `::exhausted_baud_retries_report_first_output`, `::wrong_board_type_fails_immediately`, `::permission_denied_fails_immediately_without_retry` ↔ `upload_flow_test.exs` | PARITY |
| `uploader.ex` 1200 bps touch + bootloader port poll (100/300 ms, 5 s, max-of-multiple, original-reuse, timeout atom) | `maybe_trigger_bootloader` + `TouchOutcome` | 5 `firmware_upload.rs` bootloader tests ↔ `upload_flow_test.exs` | PARITY |
| `avrdude_runner.ex` `run/3` (merged streams, 120 s timeout notice, progress regex) | `run_avrdude`, `parse_progress_fragment`, bounded 1 MiB buffer | `::collect_timeout_appends_notice_and_classifies_as_timeout`, `::progress_lines_map_to_operation_messages`, `::avrdude_output_capture_is_bounded` ↔ `avrdude_test.exs`, `uploader_test.exs` | PARITY (bounded output = only delta, documented in module doc) |
| `upload_history.ex` start/complete/fail/cancel changesets (durations, cancel no-error) + `firmware.ex` `list_upload_history/1` (desc, limit 50) | `firmware_records.rs` + `UploadHistoryPort` | `domain_firmware_records.rs::upload_history_*` (4 tests) ↔ `upload_history_test.exs`, `firmware_test.exs` | PARITY |
| `upload_manager.ex` single-flight, `@upload_timeout_ms 120_000`, timeout cancel + failure, crash → failed history, release-before-history | `upload.rs::UploadManager` (watchdog, finalize ordering, Drop reap) | `firmware_upload.rs` manager suite (7 tests) ↔ `upload_manager_test.exs` | PARITY |
| `update_checker.ex` scheduling (5 s startup, 24 h cadence, 1 h min-interval, force bypass, in-flight skip, keep 100) | `updates.rs` `SchedulerConfig`/`SchedulerTask` | `firmware_catalog.rs:790-845`; `domain_firmware_records.rs::update_checks_append_order_and_prune_to_latest_hundred` ↔ `update_checker_test.exs` | PARITY |
| `update_checker.ex` notice/dismiss (broadcast once, auto-dismiss, transient in-memory dismiss) | `updates.rs::notice/dismiss` — **persisted** dismissal key `"{version}:{ids}"` | `firmware_catalog.rs:791-871` ↔ `update_checker_test.exs` | DOCUMENTED-DIVERGENCE — persistence semantics differ (Rust stronger; former F-finding closed) |
| `board_config.ex` static 6-board table + `detect_board_type/1` filename rule | **none** — manifest-driven `UploadConfig` | manifest test ↔ `board_config_test.exs` | GAP (intentional architecture change per `firmware-catalog-supervisor-report.md`; remediation must keep manifests authoritative or port the table) |
| `device_registry.ex` `reload_from_manifest/2`, backfill, `list_available_devices/1`, `select_options/1` | `catalog.rs::refresh→upsert_catalog`, `available_devices` | refresh tests ↔ `device_registry_test.exs` | PARTIAL |
| `device_registry.ex` `detect_device_from_filename/1` (regex `trenino-([^.]+)…`) + startup GitHub backfill | **none** (grep-verified) | — ↔ `device_registry_test.exs` | GAP (belongs to unwired startup adapter, `remaining-work.md` item 7/10) |
| `app_version.ex` + `app_version/update_checker.ex` (GitHub latest, 5 s/24 h, banner) | `tauri/src-tauri/src/updater.rs` + `update_flow.rs` (native updater: verify→shutdown→install) | `update_flow.rs` inline tests (5) ↔ **no Elixir test file exists** | PARITY (oracle-absent; mechanism replaced by design — native updater owns app updates per UI contract) |
| device staleness comparator (naive 3-int split; unparseable ⇒ needs update) | full semver prerelease ordering; unparseable ⇒ outdated | notice tests | PARTIAL — agrees in common cases; exotic prerelease strings can differ; untested |

## 7. Virtual joystick + keyboard

Elixir: `lib/trenino/virtual_joystick{.ex,/**}`, `lib/trenino/keyboard.ex` · Rust: `crates/trenino-runtime/src/vjoy/**`, `src/keyboard.rs`.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| context `get_configuration/0` (singleton, defaults, device_index "must be 1") | `store.rs::ensure_configuration` (INSERT OR IGNORE) | `vjoy_manager.rs::configuration_singleton_created_with_defaults` ↔ `virtual_joystick_test.exs` | PARITY + DOCUMENTED-DIVERGENCE — device_index widened 1→16 (`storage-migration-correctness-review.md`, per user ruling in `progress.md`) |
| `confirm_enabled/1` | `store.rs::vjoy_confirm_enabled` (+ Tauri enable/disable) | manager enable/disable tests ↔ context tests | PARITY |
| `subscribe/0` | topic revisions (`vjoy_topic_metadata`) | store/manager tests | PARTIAL (structural) |
| `list_mappings/0`, `get_mapping/1`, `put_mapping/3` (update-in-place, exclusivity + `replace?` txn, invalid replacement keeps bindings, caller `input_id` dropped), `delete_mapping/1` | `store.rs::vjoy_*` — ordering `device_index,target_type,axis,button`, conflicts `"axis\|button has already been taken"` | `vjoy_manager.rs` mapping suite (8 tests) ↔ `virtual_joystick_test.exs` mapping describes | PARITY |
| mapping changeset (analog→axis/button→button, button 1..=32, 8-axis enum, unique input/target) | `store.rs::validate_draft` | `::mapping_kind_mismatch_rejected`, `::mapping_domains_rejected` ↔ context tests | PARITY |
| `manager.ex` status machine incl. `:degraded`; `status/1`, `status_details/1` | `VjoyStatus` — **no `degraded`** (no bridge) | `::unsupported_platform_never_touches_the_adapter`, `::startup_reconciliation_not_requested` ↔ `manager_test.exs` startup table | PARTIAL — state removal argued in code moduledoc but contradicts `progress.md` line 30 ("preserve unsupported/degraded/cleanup"); not in handoff docs |
| `reconcile_startup/1` table | `new()` + reconcile fns | startup tests ↔ `manager_test.exs` | PARITY |
| `enable/1` (async Task + bridge-ready handshake → persist) / `disable/1` (reset-then-delete, persist off) | `enable()` sync acquire+neutralize → persist / `disable()` neutralize-before-release → persist | `::enable_acquires_only_selected_devices_and_persists_after_success`, `::disable_neutralizes_before_release_and_persists_off` ↔ `manager_test.exs` | PARITY (sync-vs-async + no handshake: architectural, documented in moduledoc) |
| transition guard `:transition_in_progress` | `allows_transition()` → `InvalidState("transition_in_progress")` | inside quarantine/selection tests | PARITY |
| `retry/1` (needs_setup→create; degraded/error→bridge restart, resets attempts) | `retry()` (NeedsSetup\|Error, clears quarantine) | `::missing_device_reaches_needs_setup_and_retry_recovers` ↔ `manager_test.exs` retry tests | PARTIAL (degraded path N/A) |
| retry backoff `[250,500,1000,2000,4000]` + exhaustion→error | **none** | — ↔ `manager_test.exs` "bridge exit degrades then retries with bounded backoff" | **GAP** |
| bad-handshake → `:invalid_axis_range` handling | **none** (no bridge) | — ↔ `manager_test.exs` bridge-failure cases | GAP |
| `device_removed` → degraded + stale-bridge clear | **none** | — ↔ `manager_test.exs` "device removal clears the stale bridge…" | GAP |
| bridge exit post-activation → degraded + retry | acquire-failure rollback/quarantine only | — ↔ `manager_test.exs` "bridge exit degrades…" | GAP |
| `remove_leftover/1` | **none** (set_selection reconcile only) | — ↔ `manager_test.exs` "remove leftover retries deletion…" | GAP |
| `repair/1` | **none** | — ↔ `manager_test.exs` "repair only rechecks…" | GAP |
| `reload_runtime_mappings/1` + per-port subscription | **none** (persistence only) | — ↔ `manager_test.exs` "loads mappings, subscribes once…" | GAP |
| **input feed**: `handle_info({:input_value_updated,…})`, `send_mapping/3`, cache-while-off, publish-on-activate, per-port safe values on disconnect | **none** (grep-verified: no `input_value`/`set_axis` dispatch in runtime vjoy) | — ↔ `manager_test.exs` "caches input while off…", "disconnect sends safe values only…" | **GAP — the live actuation path does not exist** |
| `mapper.ex` `axis_value/4` (normalize→travel, invert `1-n`, `min+norm·(max-min)`, `:invalid_range`, `:uncalibrated`) | **no composed counterpart** (primitives `normalize`/`total_travel` exist in core, pinned) | — ↔ `mapper_test.exs` (8 tests: midpoint 16384, clamp, inversion, reversed bounds, uncalibrated, custom range, invalid) | **GAP** |
| safe neutral on disconnect `round((min+max)/2)` = **16384** | `adapter.rs::neutral_axis_value` = **16383** (widened midpoint) | `adapter.rs::neutral_axis_value_uses_widened_midpoint` ↔ `mapper_test.exs` midpoint | DOCUMENTED-DIVERGENCE in code doc only — **not in handoff docs**; value differs by 1 from oracle |
| `bridge.ex` + `port_adapter.ex` (sidecar process, request/response ids, timeouts, exit handling) | in-process `VjoyAdapter` (vendored crate; `windows.rs`) | adapter/manager tests ↔ `bridge_test.exs` | DOCUMENTED-DIVERGENCE — architecture per vjoy-crate ruling (`progress.md`); tested at adapter level |
| `configurator.ex` status/create/delete command lines, `wait_for` polling 100 ms/10 s | in-process descriptor gate `REQUIRED_DESCRIPTOR` (8 axes/32 buttons) | `::incompatible_descriptor_refused_before_acquisition` ↔ `configurator_test.exs` create/delete/poll tests | PARTIAL — capability parity; no driver create/delete, no polling |
| `system_adapter.ex` UAC elevation (`1223` → `:uac_cancelled`), elevation script | **none** | — ↔ `configurator_test.exs` "maps Windows UAC cancellation" | GAP |
| `system_adapter.ex` `trusted_file?/2,3` (containment, symlink/reparse probes, exit 10/11), trusted locations | **none** (single hardcoded DLL path) | — ↔ `configurator_test.exs` trusted-path tests, `installed_helpers_test.exs` | **GAP — `packaging-merge-review.md` explicitly requires porting trust/reparse checks incl. vJoyInstall.dll** |
| ownership registry marker (`HKCU\Software\Trenino\VJoyDevice1CreatedByTrenino`, `normalize_marker_exit/2`) | **none** (in-process `acquired` set only) | — ↔ `configurator_test.exs` marker tests | GAP — cross-restart leftover detection (`NeedsCleanup`) impossible |
| status deadline budget, timed-out process terminate/reap | **none** | — ↔ `configurator_test.exs` deadline/reap tests | GAP |
| `platform.ex` `windows?/0` | `cfg(windows)` adapter selection | `::unsupported_platform_never_touches_the_adapter` | PARITY |
| `keyboard.ex` `key_down/1`, `key_up/1`, `tap/1`, `available?/0`, `executable_path/0` (3-tier probe) | `keyboard.rs::KeyboardService` (press/release/tap via sidecar CLI; fail-closed absolute path) | `keyboard_ownership.rs::process_adapter_invokes_exact_sidecar_cli`, `::process_adapter_reports_command_failure_with_output`, `::process_adapter_is_fail_closed_on_untrusted_paths` ↔ **no Elixir test file exists** | PARTIAL — exec/error-shape parity; path probing dropped (Rust doc comment only, not in handoffs) |
| keystroke parsing (in Elixir: sidecar, not `keyboard.ex`) | `keyboard.rs::parse_keystroke`/`key_actions` | `::parser_keeps_sidecar_aliases`, `::action_order_matches_sidecar` | PARITY with sidecar semantics (no repo oracle) |
| — (held keys lived in button runtime, stateless keyboard.ex) | `HoldOwner` refcount model (press/release/owner_gone/shutdown) | `keyboard_ownership.rs` (10 tests) | NEW SURFACE — no handoff documentation of the ownership model |

## 8. MCP server + tools, settings, paths, app lifecycle

Elixir: `lib/trenino/mcp/**`, `settings.ex`(+`setting`,`simulator`), `paths.ex`, `application.ex`, `release.ex`, `repo.ex` ·
Rust: `runtime/mcp/**`, `settings.rs`, `paths.rs`, `app.rs`, `lifecycle.rs`, `tauri/src-tauri/src/rust_ui.rs`.

| Elixir fn | Rust counterpart | Test | Status |
|---|---|---|---|
| `server.ex` `handle_message/1` — initialize (protocolVersion `2024-11-05`, capabilities, serverInfo), notifications/initialized, ping, tools/list shape, tools/call content/isError, `-32602` missing-params text, `-32601` unknown method, `-32600` invalid | `mcp/server.rs::handle_message` — identical arms, texts, codes | `mcp_server.rs` (11 protocol tests) ↔ `server_test.exs` (all) | PARITY (`serverInfo.version`: Mix version vs `CARGO_PKG_VERSION` — sync risk at release) |
| `MCPController` SSE endpoint (headers, `endpoint` event, 16-byte base64url session ids) | `server.rs::sse_endpoint` (Host-header URL construction) | `mcp_server.rs::sse_sends_endpoint_event_and_delivers_messages` ↔ `mcp_controller_test.exs` | PARTIAL — URL construction mechanism differs (Phoenix `url/2` vs Host header) |
| `POST /mcp/messages` (202 accepted; 400 `"session_id parameter required"`; 404 `"Session not found"`; errors over SSE) | `messages_endpoint` identical texts/statuses | `mcp_server.rs::tools_list_and_call_flow_over_http`, `::error_responses_travel_over_sse`, `::messages_endpoint_status_errors` ↔ `mcp_controller_test.exs` | PARITY (malformed-JSON 400: Elixir raises pre-controller, Rust explicit — code-comment documented) |
| — (no auth) | optional `Authorization: Bearer` API-key gate | `::auth_is_open_without_a_configured_key`, `::auth_rejects_missing_or_wrong_bearer_tokens` | DOCUMENTED-DIVERGENCE — Rust-only addition (`server.rs` header) |
| — (Phoenix owns lifecycle) | `McpServer::{start,stop,status}` — busy port → `Degraded`, never fatal | `::busy_port_is_degraded_not_fatal_and_retryable`, `::stop_ends_sse_streams…`, `::server_participates_in_ordered_shutdown` | DOCUMENTED-DIVERGENCE — `remaining-work.md` item 9 |
| `tool_registry.ex` `list_tools/0` (47 tools, `@tool_modules` order), `call_tool/2` (`"Unknown tool: X"`) | `tools.rs::list_tools/call_tool` — **47/47 names identical (set-diff verified), same section order** | `mcp_server.rs::tools_list_returns_exact_tool_set_and_count` ↔ `tool_registry_test.exs` "returns all 47 tools" | PARITY |
| all 11 tool modules: CRUD payloads, changeset-error rendering `"Validation failed: …"`, destination-conflict text, trains/elements/devices/output/button/display/sequence/script/simulator/detection/vjoy schemas (strict `additionalProperties:false`, `"must be the integer 1"`, etc.) | `tools.rs` sections + `storage_ports.rs` | `mcp_server.rs` per-tool suites + `mcp_storage_wiring.rs` over-HTTP suites ↔ `test/trenino/mcp/tools/*_test.exs` (11 files) | PARITY (simulator live browsing + interactive detection use injectable ports — wiring gap documented in `storage_ports.rs` header) |
| missing required tool argument (Elixir: FunctionClauseError → request dies) | `"Missing required argument: k"` isError | `::vjoy_argument_validation_rejects_without_raising` (vjoy only) | DOCUMENTED-DIVERGENCE — code-header only; other 10 sections' missing-arg path untested |
| controller reload side-effects after tool mutations | not ported (DB-only) | comment-only | DOCUMENTED-DIVERGENCE — `storage_ports.rs` "controllers-wave gap" |
| `settings.ex` `error_reporting?/0`, `error_reporting_set?/0`, `set_error_reporting/2`, `simulator_url/0` (default `http://localhost:31270`), `set_simulator_url/2`, `api_key/0` (DB→file), `set_api_key/2`, `sentry_before_send/2` | `settings.rs::Settings` (**test-only surface** — used by `foundation.rs`/`app_services.rs` tests, not wired) and `app.rs` wired methods; same DB keys/defaults/consent semantics; key file `Documents/My Games/{TSW7,TSW6}/…/CommAPIkey.txt` precedence | `foundation.rs::settings_consent_is_unset_until_explicit_choice_and_api_key_is_redacted`; `app_services.rs` (3 tests) ↔ `settings_test.exs`, `settings/simulator_test.exs` | PARITY + PARTIAL edges — `app.rs::set_simulator_url` adds validation Elixir never does; api-key error taxonomy differs (`:not_windows` etc. → generic); empty-string key filtered; `Settings::public_snapshot.values` placeholder field; **two coexisting settings stacks, one unwired** |
| `settings/simulator.ex` `read_from_file/1`, `windows?/0` | `settings.rs::resolve_api_key_file` + `rust_ui.rs::simulator_key_file` (`TRENINO_TSW_API_KEY_FILE` override — Rust-only) | `app_services.rs::configured_api_key_path…` ↔ `settings/simulator_test.exs` | PARTIAL (taxonomy/extension deltas above) |
| `paths.ex` `data_dir/0` (macOS/Windows/Linux fallbacks incl. empty-XDG), `database_path/0`, mkdir | `paths.rs::resolve` — all fallback rules match | `foundation.rs::data_paths_are_injectable_and_database_override_takes_precedence` ↔ `paths_test.exs` | PARTIAL — adds `DATABASE_PATH` env override; drops eager `mkdir_p` (creation at `open_full`, db parent only) |
| `application.ex` `start/2` (supervision tree, env-gated children, `config_change/3`) | `app.rs::open_full` + `lifecycle.rs::ShutdownCoordinator` + `rust_ui.rs::wire_runtime_services` | `app_services.rs`, `app_services_surface.rs` (ordered shutdown, quiesce) ↔ n/a (no oracle for Rust process model) | DOCUMENTED-DIVERGENCE — architectural replacement; legacy-Ecto refusal actionable |
| `release.ex` `migrate/0`, `rollback/2` | none (Rust never migrates Ecto DBs in place) | `app_services.rs::selecting_a_legacy_ecto_database_fails_actionably…` | DOCUMENTED-DIVERGENCE — intentional (`remaining-work.md`, `foundation-report.md`) |
| `repo.ex` | `storage/mod.rs::Database` (single worker) | `storage_admission.rs`, `storage_migration.rs` | PARITY (structural) |
| `app_version/*` | see §6 updater rows | — | PARITY (oracle-absent) |

---

# Prioritized GAP / divergence list (remediation drivers)

Statuses and file/symbol pointers are exact; each names the Elixir test that pins the missing
behavior (or notes the oracle absence).

## P0 — core user-visible behavior missing or silently wrong

1. **vJoy live actuation path does not exist.** No `input_value` feed, no composed
   `Mapper.axis_value/4` (core primitives exist but are not composed), no cache-while-off /
   publish-on-activate, no per-port safe values on disconnect.
   Oracle: `test/trenino/virtual_joystick/manager_test.exs` ("caches input while off and publishes
   it after activation", "disconnect sends safe values only for controls from the disconnected
   port") and `test/trenino/virtual_joystick/mapper_test.exs` (all 8 tests, midpoint `16384`,
   clamp, inversion, `:uncalibrated`, `:invalid_range`).
   Rust: `crates/trenino-runtime/src/vjoy/manager.rs` (no dispatch), missing composition over
   `crates/trenino-core/src/hardware/calibration/mod.rs::normalize/total_travel`.
   `remaining-work.md` item 6 acknowledges; must be built for parity.
2. **ScriptRunner runtime half is absent** — scripts cannot run: no 200 ms subscription polling,
   change-only firing, 100-entry log ring, schedule timers, effect application
   (api.set→simulator, output_set→hardware, display_set→I2C), `run_script/1`/`get_script_log/1`.
   Oracle: `test/trenino/train/script_runner_test.exs`. Rust: only `script/engine.rs` +
   `script/triggers.rs` exist with no caller outside tests. Documented deferral
   (`script-corpus.md` §6) — but there is no stub-free partial, so parity is unmet.
3. **Simulator connection runtime owner absent** — no polling/health loop, no
   `retry_connection`/`reconfigure`/`disconnect`/`subscribe` API, no broadcasts; only the pure
   `ConnectionState` machine is ported. Oracle: `test/trenino/simulator/connection_test.exs`
   (health tolerance, retry). Rust: `crates/trenino-runtime/src/simulator/connection.rs` (pure),
   no owner. Documented scope omission (`controls-report.md`, `remaining-work.md` item 5).
4. **Sequence-command value rounding silently diverges**: `crates/trenino-runtime/src/storage/domain/sequences.rs:175`
   `fn rounded` uses `(value*100.0).round()/100.0`; oracle `Float.round/2` disagrees on
   tie-crossing values (`0.015` → oracle 0.01, Rust 0.02 — brute-forced against live Elixir).
   `trains.rs:284 round2` already uses `round_elixir`; sequences.rs is the lone outlier.
   Oracle: `test/trenino/train_test.exs` "rounds float values to 2 decimal places" (sequence
   commands). Fix + add a tie-case assertion to `domain_sequences.rs::set_sequence_commands_rounds_values`.

## P1 — functional/security parity losses

5. **Manual hardware scan cannot bypass failure backoff**: Elixir `lib/trenino/serial/connection.ex:261-267`
   `handle_cast(:scan)` clears failed ports (comment: "manual scan bypasses backoff"); Rust
   `crates/trenino-runtime/src/hardware/mod.rs` `scan_now` only accelerates the timer, and the
   scan pass re-inserts `retry_after = now + 30 s` (mod.rs:899). Users must wait 30 s after a
   failed port even when clicking "scan now". No doc covers this.
6. **vJoy trusted-path/elevation stack dropped**: `configurator/system_adapter.ex`
   `trusted_file?/3` (containment/symlink/reparse probes), UAC elevation + `1223` handling,
   ownership registry marker (`mark_device_owned/1`, `normalize_marker_exit/2`), process
   terminate/reap — all have **no Rust counterpart** (single hardcoded DLL path in
   `vjoy/windows.rs`). Oracles: `configurator_test.exs` (trusted-path, UAC, marker, deadline,
   reap tests), `installed_helpers_test.exs`. `packaging-merge-review.md` explicitly requires
   porting trust/reparse checks incl. vJoyInstall.dll — currently unmet. Also loses
   cross-restart `NeedsCleanup` detection.
7. **vJoy runtime-loss recovery missing**: retry backoff `[250,500,1000,2000,4000]` +
   exhaustion, bad-handshake handling, `device_removed`, bridge-exit degraded recovery,
   `remove_leftover/1`, `repair/1`, `reload_runtime_mappings/1`, and the `:degraded` status.
   Oracles: `manager_test.exs` ("bridge exit degrades then retries with bounded backoff",
   "retry exhaustion reaches error", "remove leftover retries deletion…", "exposes status
   reasons and repair…", "device removal clears the stale bridge…"). Rust: `vjoy/manager.rs`
   (acquire/release only). Note `progress.md` line 30 says preserve degraded/cleanup — the
   removal is undocumented.
8. **Keyboard/vJoy path probing replaced with fail-closed absolute paths**:
   Elixir `keyboard.ex::executable_path/0` 3-tier probe and `avrdude.ex::executable_path/0`
   (sidecar→priv→PATH) vs Rust `ProcessKeystrokeAdapter::new` / `UploadTooling` absolute-only.
   Dev-mode ergonomics regress; documented only in module headers, not handoffs.
9. **MCP missing-argument leniency** (10 of 11 tool sections untested for the
   `"Missing required argument"` path; divergence itself only documented in `tools.rs:1-11`
   code header). Oracle: Elixir raises (request dies) — Rust returns isError. Add tests or
   document in handoff.
10. **Firmware catalog: `github_token` auth unsupported** (`downloader.ex::github_headers/0`
    vs no `authorization` anywhere in `crates/trenino-runtime/src/firmware/*`) and
    `FirmwareCatalog::latest_compatible` + `select`'s `Incompatible` branch untested
    (oracle: `firmware_test.exs::get_latest_compatible_release/1`).
11. **Neutral axis value 16383 vs oracle 16384** (`adapter.rs:129` vs
    `manager.ex:527 round((min+max)/2)`): deliberate overflow-safe choice, pinned by Rust test,
    but the value differs from the oracle midpoint pinned in `mapper_test.exs`; documented only
    in code. Decide: match oracle or record in handoffs.
12. **Unwired duplicate sequence executor**: `crates/trenino-runtime/src/train/sequence.rs`
    `SequenceExecutor` (fully tested in `output_display.rs`) is not referenced by the app;
    `button_controller.rs::spawn_sequence` is the live path. Wire one, delete the other.
13. **Dead/test-only surfaces**: `crates/trenino-runtime/src/settings.rs::Settings` is used only
    by tests (wired path is `app.rs`); `Settings::public_snapshot.values` is a placeholder.

## P2 — small gaps and unpinned constants

14. `DeviceConnection.format_error_reason/1` — no Rust counterpart (GAP; UI error strings).
15. `list_button_elements/1` — no counterpart (oracle: `train_test.exs` 3 tests). GAP.
16. `Sequence.total_duration/1` — no counterpart (no oracle test; pure reduce). GAP.
17. `ConfigId.parse/1`, `I2cModule.format_i2c_address/1` — no counterparts (display/parse
    helpers). GAP.
18. `DeviceRegistry.detect_device_from_filename/1` + startup GitHub backfill — no counterpart
    (oracle: `device_registry_test.exs`); belongs with the unwired startup adapter.
19. `BoardConfig` static table + `detect_board_type/1` — replaced by manifests (oracle:
    `board_config_test.exs`); intentional but keep manifests authoritative. GAP-by-design.
20. Whitespace-name validation inconsistencies: Rust trims/rejects whitespace-only
    sequence/script names (Ecto `validate_length(min:1)` accepts `" "`) while train/element
    storage accepts whitespace-only (Ecto `validate_required` rejects) — inverted vs oracle at
    storage layer. Align per-schema with Ecto semantics or document.
21. Script trigger strings: Rust `scripts.rs::validate_triggers` rejects `""`/blank — Elixir
    accepts (`script_test.exs`). Undocumented.
22. Post-upload rescan: Elixir 500 ms delay (`connection.ex:249`) vs Rust immediate — minor,
    undocumented.
23. `generate_config_id` 1024-attempt bound + modulo bias vs unbounded oracle
    (`config_id.ex::generate/0`) — new failure mode, undocumented.
24. Unpinned Rust constants: 30 s `FAILURE_RETRY` boundary (`device_connection_test.exs`
    "should_retry?/2"), per-pattern `is_ignored_port` tests, `HardwareSessions` cap-1024.
25. Display-binding name length counts codepoints (should use graphemes like `core/display.rs`).
26. Micro-divergences untested on either side: 403 body dropped in `SimulatorError::InvalidKey`;
    momentary `endpoint: nil` → empty-path send (`button_controller.rs:594,676`);
    `serverInfo.version` source sync; api-key empty-string filtering; `TriggersType.load`
    non-string-array fallback; `latching release with empty off-sequence` cancellation
    (supervisor finding — confirm closed).
27. Elixir-oracle gaps (flagged, nothing to fix in Rust): no Elixir tests exist for
    `control_detector.ex`, `keyboard.ex`, `app_version.ex`, the hardware calibration `Session`
    GenServer, or client 403/5xx mapping.

## Verified as safe (false alarms closed)

- HT16K33 grapheme alignment — **PARITY** (live-oracle verified; `hardware_models.rs` test bytes
  are the true Elixir output). An earlier subsystem review's codepoint claim was wrong.
- 47/47 MCP tool names and ordering identical (set-diff verified).
- Lever retry ladder 200/400/800 ms, health 30 s/2 s/threshold 3, detection 5 s/30 s/200 ms,
  sweep 0.02/150 ms/0.03, calibration 0.025/0.001/5 ms, upload 120 s, update-check 5 s/24 h/1 h —
  all constants equal on both sides.
- `Float.round` semantics preserved via `round_elixir` everywhere except sequences.rs (P0-4).
- Destination-exclusivity, button-binding mode matrix, notch validation, identifier matching,
  output predicates, display formatting, COBS/protocol golden bytes: pinned on both sides.

## Coverage summary

~420 Elixir public functions across 65 modules mapped: ~60% PARITY, ~25% PARTIAL, ~10% GAP
(concentrated in vJoy runtime, script runner, simulator connection owner, configurator/elevation
stack), ~5% DOCUMENTED-DIVERGENCE (bounds, hardening, architecture). Every GAP/PARTIAL row above
names exact files/symbols and the pinning Elixir test. Rust test suites examined:
`crates/trenino-core/tests/*` (6 files) and `crates/trenino-runtime/tests/*` (28 files); Elixir
suites: `test/trenino/**` (87 files). Spot-checks of oracle-line citations in
`control_dispatch.rs` found no fabricated citations.
