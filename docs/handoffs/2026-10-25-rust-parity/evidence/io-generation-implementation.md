# Accepted simulator IO generation fence

## Change

`LiveSimulator` now carries the accepted `Arc<SimulatorClient>` and connection-owner watch into every queued set, get, list, subscribe, and subscription-read request. The owned IO reactor rechecks that the status is connected and the accepted client is the current `Arc` when work leaves the queue. While an HTTP request is pending, a watch update that disconnects or replaces that client cancels the request and returns an error; the completed result is checked again before it is returned. A new client at the same URL is a new generation. The old `Subscriptions::unsubscribe` deliberately remains pinned to its original client and skips this fence so it can clean up after disconnect or replacement. The reactor count, 64-slot queue, three-second deadline, and shutdown mechanism are unchanged.

## RED/GREEN evidence

- The actual-source fake-HTTP queued PATCH tests failed before implementation in both cases: after disconnect and after same-URL new-`Arc` replacement, the writer returned `Ok` and the server received the stale PATCH. Both now return errors without sending HTTP.
- New actual-HTTP tests also hold a GET response while status disconnects and verify the stale read returns an error before that response is released; verify old subscription reads/subscribes fail after disconnect while its DELETE unsubscribe succeeds; and verify an expired queued request is not polled and IO shutdown joins promptly.
- `cargo test -p trenino-runtime --lib --test composition -- --test-threads=1`: **27 lib + 3 composition tests passed**.
- `cargo clippy -p trenino-runtime --lib -- -D warnings`: passed. Scoped `rustfmt --check` and `git diff --check` passed.

The fence cancels local work and stale acknowledgements. An HTTP PATCH already accepted by the remote simulator before connection replacement cannot be undone; callers must not treat its cancelled local result as proof of remote rollback. No real simulator or hardware was used. No commit was created.
