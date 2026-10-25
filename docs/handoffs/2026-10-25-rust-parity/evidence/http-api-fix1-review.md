# Legacy HTTP API fix 1 rereview — 2026-10-25

## Verdict

**The two reported HTTP defects are addressed; an admission race found during this rereview was fixed before handoff.** This is a source rereview of `http_api.rs`, `mcp/jobs.rs`, `mcp/server.rs`, and the targeted tests. I did not rerun the reported HTTP, MCP, and MCP storage test results.

| Original finding | Result | Evidence |
| --- | --- | --- |
| Script list converts database failure into empty success | **Addressed** | `http_api.rs:81-91` reads `Database::list_scripts` as a `Result` and returns 500 on failure; `tests/http_api.rs:45-52` drops the table and verifies the response. Other MCP list callers retain their legacy port shape. |
| Server stop acknowledges an admitted blocking mutation | **Addressed for an already running server** | `http_api.rs:41-46` and `mcp/server.rs:324-327` move `JobGuard` into the blocking closure, so an abandoned HTTP future does not hide its work. `JobDrain::admit/close/drain` serialize admission with the count (`mcp/jobs.rs:10-30`). `McpServer::stop` closes admission, retains `RunningServer` on timeout, and only takes/joins it after drain (`mcp/server.rs:526-541`). The held create test retries stop after release (`tests/http_api.rs:69-85`). |

### Additional finding, fixed during rereview — degraded-server retry could reopen admission after shutdown

- At the initial review snapshot, `McpServer::start` could call `jobs.reopen()` and set `admit=true` after `stop_admission` closed both, if startup/retry raced shutdown.
- Root added a sticky `quiescing` fence checked under the `running` lock before bind/reopen (`mcp/server.rs:460-470`) and made `stop_admission` take the same lock before setting the fence and closing admission (`:576-583`). A targeted stopped-admission listener regression was added at `tests/http_api.rs:91`. This closes the reviewed race; root is running the scoped suites for the follow-up change.

## Drain boundary checked

Parsing/validation before `work()` does not mutate storage. Both JSON API work and MCP message dispatch acquire a guard before queuing `spawn_blocking`; the guard is dropped only after the blocking closure ends. `stop()` leaves the listener handle available for retry when `drain` reaches its one-second budget. The new test validates this with a held script creation, though it does not exercise the degraded-start race above.
