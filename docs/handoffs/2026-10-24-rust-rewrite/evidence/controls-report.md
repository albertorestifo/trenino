# Controls implementation report

Implemented the deterministic controls primitives and a scoped simulator transport/writer in the Rust crates. The slice uses the existing Elixir implementation as the behavior source; it does not claim the full train-control migration is complete.

## Delivered

- `trenino-core::simulator`: validated, wire-shaped `Endpoint` and `SimValue` DTOs. Endpoint text is preserved; blank endpoints and non-finite numbers are rejected at construction/serde boundaries.
- `trenino-core::train`: train identifier normalization/prefix matching, lever mapping (linear/gate, inversion, reversed layout and exact upper boundary), output predicates, display token validation/rendering, and pure button/sequence transitions with ordered effects/cancellation.
- `trenino-core::calibration::analysis`: notch grouping/ordering, snap-threshold merging, gate/linear/hybrid classification, suggested notch ranges/descriptions, and sample `snapped` metadata.
- `trenino-runtime::simulator`: pooled reqwest operations and response envelopes, normal/fast timeout profiles, health state transitions, shared reference-counted subscription leases, typed bounded FIFO writes, generation fences/barriers, and explicit owned worker shutdown/join.
- `trenino-runtime::keyboard`: pure keystroke parsing/action expansion and aliases; this is not an OS keyboard adapter.
- Registered the core/runtime modules and required dependencies. The runtime `rusqlite` backup feature was added at the storage worker's request.

## Verification

- `cargo test -p trenino-core --test controls_parity`: **14 passed**. Covers identifier prefix ambiguity/deduplication, mapper boundaries and reversal, output type/operator semantics, display tokens and lexical precision, analyzer discrete/continuous/hybrid cases, button transition ordering/cancellation, sequence ordering/delays, and simulator DTO validation.
- `cargo clippy -p trenino-core --lib --test controls_parity -- -D warnings`: **passed**.
- `cargo test -p trenino-runtime --test simulator_lifecycle`: **10 passed** on the implemented runtime slice. Covers request auth/path escaping/envelopes and status errors, timeout profiles/rounding, health timing, subscription registry/service ownership, bounded queue admission, in-flight generation transition, cancellation of a write waiter, explicit shutdown/join, and keyboard aliases/action order.
- A later runtime lib/test invocation encountered concurrent storage migration compile errors (reported to its owner and not modified here), and the runtime workspace format command could not resolve that incomplete module. The storage owner has since reported those compile errors fixed, while continuing migration test work. Per the coordinating task, no further runtime builds were run against the changing shared tree; the passing lifecycle result above is from the implemented runtime slice before that storage churn. Owned runtime files were formatted directly with rustfmt, and the core package formatted successfully.

## Explicit limits and remaining plan work

- `GenerationWriter` is a bounded FIFO with one sequential worker. It does **not** implement the legacy per-lever one-in-flight/latest-pending coalescer, nor success-only acknowledgement plus 200/400/800ms retry tokens. Writes are not automatically retried. A generation switch fences queued old writes and awaits any in-flight HTTP request before completing its barrier; cancellation of the caller's write future does not abandon the worker request. `shutdown()` closes admission and awaits the owned worker.
- Runtime connection polling/reconnect supervision is not implemented; `ConnectionState` is a deterministic state machine only. Reqwest's 10s/1s request timeout is a total deadline; queue-admission waiting is separately bounded at 5s/500ms, not a literal Req receive/pool timeout split.
- Train aggregate validation/CRUD/persistence, runtime train detection/activation, lever dispatch/coalescing, simulator endpoint discovery, and live lever/notch calibration sweep/session/wizard flows remain unimplemented.
- Runtime button controller, sequence task supervisor, OS keyboard adapter/held-key ownership, output polling/controller, display hardware controller/reconnect cleanup, and hardware display encoding remain unimplemented. The shipped button/sequence layer only returns pure ordered actions/steps.
- Lua migration remains excluded from this slice as specified by the plan.
- The tests are Rust golden-style cases based on the inspected Elixir rules and existing ExUnit scenarios. No Elixir differential test harness was run in this slice.

## Controls supervisor fix round 1 (2026-10-24)

This section supersedes the earlier test counts above for the reviewed controls slice. All 11 findings in `controls-supervisor-report.md` were addressed with focused regression coverage:

1. **Subscription cancellation and cleanup ownership:** `SubscriptionService` keeps subscribe/release work in its owned actor; a canceled acquire rolls back its provisional lease, pending cleanup IDs remain recorded until each delete succeeds, and callers can explicitly retry cleanup or drain during shutdown. Lifecycle cases cover canceled acquisition, canceled multi-ID cleanup, partial subscribe failure (including an ambiguous created ID), and a failed unsubscribe retried with no subsequent consumer traffic.
2. **Elixir rounding:** shared `round_elixir`/decimal formatting is used by lever mapping, calibration classification/gates, simulator numeric reads and display output. The installed Elixir oracle returned `Float.round(0.015, 2) == 0.01`, `Float.round(-0.015, 2) == -0.01`, `Float.round(2.675, 2) == 2.67`, `Float.round(-2.675, 2) == -2.67`, `Float.round(0.15, 1) == 0.1`, `Float.round(1.235, 2) == 1.24`, and `Float.round(±2.5) == ±3.0`. Golden tests cover these values plus large finite numbers and the analyzer gate threshold that changes at 0.15.
3. **Latching release cancellation:** sequence release emits `CancelActive` before starting an off-sequence; with no off-sequence it cancels and clears active state. Core parity assertions cover both cases.
4. **Invalid-key health:** `InvalidKey` moves health directly to error and schedules the normal health check; transient timeout behavior remains separately tested.
5. **HTTP status before body decoding:** 403 is classified as `InvalidKey` for empty and plain-text bodies. Other non-200 statuses preserve parsed JSON or raw UTF-8 body text, including empty 500 and plain-text 503. HTTP 200 continues through JSON decoding.
6. **Writer admission and generation fencing:** one deadline includes admission-lock contention and channel capacity; five contending callers under a gated request complete within the bound, with one queued slot admitted and four returning `QueueTimeout`. A generation switch fences immediately, waits through the in-flight request barrier, and stale queued writes do not execute; owned shutdown awaits the worker. This remains a bounded FIFO, not a one-in-flight/latest-pending lever coalescer.
7. **Numeric validity:** integer conversions reject values outside `i64` instead of saturating; float reads reject invalid/non-finite rounded results while preserving large finite values. Analyzer derived-width overflow returns `InvalidDerivedResult`; equal `f64::MAX` gate samples remain valid. Tests cover i64 max/overflow, 1e20 integer rejection, 1e307 float acceptance, and analyzer overflow.
8. **Raw display wire type preservation:** the simulator DTO retains integer versus float JSON representation; tests verify integer `12` -> `"12"`, float `12.0` -> `"12.0"`, and exponents `1.0e20`/`1.0e-8` keep Elixir-style mantissa text. Runtime `get_string` tests exercise these values through JSON decoding, not only directly constructed DTOs.
9. **Safe GET transient status retry:** normal reads retry 408/429/500/502/503/504 up to two times, with tests for 503 then success and exhausted 503 retries. Fast reads make one attempt. Mutations remain non-retried.
10. **Operation path confinement:** list/get/set/subscribe reject dot segments; tests cover literal traversal and valid Unicode, question-mark and hash encoding while preserving ordinary TSW paths.
11. **Redirect credential boundary:** reqwest redirects are disabled. A two-local-server regression fixture verifies the custom `DTGCommKey` is not forwarded to a redirect destination. This is an intentional safety correction to inherited behavior.

The Elixir oracle commands were run locally during this fix round (`elixir -e` using `Float.round/1`, `Float.round/2`, `Float.to_string/1`); raw-number formatting was cross-checked for `1.0e20` and `1.0e-8`. No live simulator, hardware, or user database was used.

Verification after formatting the owned core/runtime files:

- `cargo test -p trenino-core --test controls_parity`: **19 passed**.
- `cargo test -p trenino-runtime --test simulator_lifecycle`: **23 passed**.
- `cargo test -p trenino-core --lib`: **3 passed** (includes shared UI contract tests).
- `cargo test -p trenino-runtime --lib`: **2 passed** (includes shared storage migration unit tests).
- `cargo clippy -p trenino-core --lib --test controls_parity -- -D warnings`: **passed**.
- `cargo clippy -p trenino-runtime --lib --test simulator_lifecycle -- -D warnings`: **passed**.

The earlier scope limits still apply: no live train controllers, legacy lever coalescer/latest-pending acknowledgements or retry tokens, runtime connection polling/reconnect owner, button/sequence task supervisor, OS keyboard adapter, output/display lifecycle controller, full CRUD/detection/calibration workflow, or Lua port is delivered here. The bounded writer provides one owned sequential worker and generation fencing only; no automatic mutation retry was added. No claims are made that the Rust fixture set exhaustively ports all legacy ExUnit cases.

## Controls supervisor fix round 2 (2026-10-24)

Addressed the three remaining findings from `controls-fix1-review.md`, with fail-before-fix reproductions and green regressions:

1. **Full-inbox shutdown:** `SubscriptionService::shutdown` now returns `SubscriptionServiceError::QueueTimeout` immediately if the shutdown command cannot be admitted. It does not await an actor that was never asked to terminate. The actor handle remains owned; shutdown admission is allowed while closing, so callers can retry after the bounded inbox drains. If the channel is already closed, shutdown joins the worker that has independently terminated. Existing `PendingCleanup(ids)` diagnostics and explicit cleanup retry behavior remain intact. The new local-server test holds an acquire request, fills the 64-command inbox plus a contending sender, and verifies the first shutdown call returns a retryable QueueTimeout without a second shutdown call. Before the fix, the bounded wait expired while `shutdown()` hung awaiting the idle actor (`Err(Elapsed(()))` in the reproduction).
2. **Elixir float notation:** `SimValue::to_legacy_string` now derives shortest fixed and scientific spellings from the shortest decimal digits and selects the shorter spelling, preferring fixed notation on equal lengths; scientific mantissas always retain the Elixir `.0` convention. The installed Elixir oracle fixtures cover `0.001` fixed, `0.0009999999999999998` and its negative in exponent form, `0.0001` fixed, `1.0e14` exponent, `999999999999999.9` fixed, `1.0e15` exponent, `1.000000000000001e15` fixed, `1.000000000001e15` exponent, and `1.0e16` exponent. This also corrects the helper used by `get_string` and analyzer descriptions.
3. **Exact integer/float output predicates:** integer-to-float casts were replaced with an exact comparison that compares an `i128` against the truncated finite `f64` plus its fractional direction, with explicit handling for NaN and values outside the signed 128-bit range. The Elixir oracle confirms `9007199254740993 > 9007199254740992.0`, the negative counterpart, inclusive `between` across the positive boundary, and an ordinary mixed comparison. Core tests exercise Gt/Lte, Lt/Gte, Between, and ordinary mixed values.

Fail-before-fix evidence: the large-integer Gt regression returned false; the raw-float boundary regression first diverged at `0.0009999999999999998`; and the saturated shutdown regression exceeded its one-second outer deadline. All three regressions pass after the changes.

Round-two verification counts:

- `cargo test -p trenino-core --test controls_parity`: **21 passed**.
- `cargo test -p trenino-runtime --test simulator_lifecycle`: **24 passed**.
- `cargo clippy -p trenino-core --lib --test controls_parity -- -D warnings`: **passed**.
- `cargo clippy -p trenino-runtime --lib --test simulator_lifecycle -- -D warnings`: **passed**.
- `rustfmt --edition 2021 --check` on the five changed core/runtime source and test files: **passed**.
- `git diff --check`: **passed**.

The notation and mixed-comparison expectations were checked directly with the installed Elixir runtime using `Float.to_string/1` and comparison operators. The shutdown fixture used a disposable local server, dummy key, and no hardware, real simulator, or database.
