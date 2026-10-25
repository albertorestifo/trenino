# Legacy JSON HTTP API review

Read-only Task 7 review of `http_api.rs`, the MCP listener mount, script timestamp accessor, two loopback tests, and the legacy Phoenix API controllers/router. The reported two loopback tests pass. Numeric entity IDs, named JSON envelopes, UTC timestamps for newly written rows, status codes for ordinary not-found/validation/disconnected simulator cases, and sharing the listener/ports/DB are present.

## Verdict

**Spec:** The route surface and ordinary request shapes match the legacy API. **Not ready for full Task 7 acceptance** because the script list hides storage failure and in-flight blocking API work is not included in shutdown acknowledgement. **Quality:** The tests cover CRUD and disconnected simulator behavior, but no injected DB failure, slow in-flight mutation at shutdown, connected simulator pass-through or callback-triggered shutdown.

## Important findings

1. **`GET /api/trains/:id/scripts` returns a false empty success when storage fails.** `http_api.rs:79-81` calls the MCP `ScriptsPort::list_scripts`, which returns a plain `Vec`. The production implementation in `mcp/storage_ports.rs:807-812` converts *every* `db.list_scripts` error to `Vec::default()`. If the DB worker is unavailable or its query fails, this HTTP route returns `200 {"scripts":[]}`; other API reads surface errors. The compatibility endpoint should expose the failure as a 5xx response, not say that persisted scripts disappeared. **Test:** inject a failing script-list repository/DB worker, request the route, and assert a non-200 error envelope. Use a fallible DB read for this API or make the shared port's list operation fallible and update callers.

2. **Server stop can acknowledge while an admitted API mutation still runs.** `http_api.rs:48-54` spawns each storage operation with `spawn_blocking` and only checks the shared admit flag before queuing it. `mcp/server.rs:520-540,555-569` stops the listener and calls `runtime.shutdown_timeout` with a one-second grace, then reports `Stopped`; Tokio can leave a blocking task running beyond that deadline. The desktop registers this stop in the first shutdown phase, then later closes services/DB (`rust_ui.rs:1372-1390,376-406`). A held script create/update may therefore run or finish after listener stop was acknowledged, with no pinned in-flight operation to prevent DB closure. **Test:** hold a fake `ScriptsPort::create_script` for over one second, start POST, call server stop/coordinated shutdown, and require shutdown to wait for that mutation or report an explicit timeout while retaining its owner. Track admitted jobs and cancel/join or drain them before successful stop acknowledgement.

## Additional observations

- `script_timestamps` reads persisted columns and `timestamp` emits the expected `T...Z` format for new UTC rows; the two loopback tests only check the `Z` suffix. A migrated timestamp with a non-UTC offset would be malformed by suffixing `Z`, so parsing/normalizing the actual value would be more robust, but no such retained row was established here.
- The API delegates script mutation to the shared storage ports and relies on the committed revision watcher for runtime reload. The 250 ms delay is expected by the Task 7 design; no separate immediate-reload defect is counted.
