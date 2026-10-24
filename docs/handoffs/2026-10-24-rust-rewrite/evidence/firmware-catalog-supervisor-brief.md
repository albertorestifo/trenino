# Firmware catalog review supervision

Use Astra in C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io on codex/rust-rewrite. Read firmware-catalog-brief.md, firmware-catalog-report.md and firmware-catalog-review.diff (8723455..f79f41e). Review core manifest/version compatibility and runtime catalog, pinned selection, cache downloader, scheduler and injected persistence contract. Shared-worker firmware repository, UI/startup integration and actual flashing remain separate documented gates.

Perform your own audit, then trigger two fresh independent gpt-6-sol/high correctness and adversarial children sequentially (fork_turns none), without sharing prior findings. Root coordinates the four slots. No production edits, commits, actual GitHub/firmware downloads, user databases, ports, installers or flashing. Use local fake HTTP and disposable caches for concrete probes; do not repeat reported broad tests blindly.

Binding requirements:
- Preserve actual legacy manifest/registry/compatibility behavior using cited sources and fixtures. Unsupported sam-ba/esptool devices coexist in real manifests; catalog metadata may retain them while supported programmer selection is restricted. No manifest means no static board fallback.
- Match Elixir requirement semantics used by the application, including nil versus configured prerelease behavior, pessimistic bounds, leading-v version handling and malformed policy/version refusal. Check the custom parser's edges with an oracle where useful; unsupported syntax must not silently change meaning.
- Pin selected release/environment/upload configuration, so a registry refresh cannot change a pending choice. Validate exact asset association and preserve separate local EntityId and remote GitHub identity.
- Downloader must bound bytes/concurrency/time, validate paths and URLs, stream to unique partial files, clean up failure/cancellation, publish only complete data and preserve unrelated files. Concurrent requests, existing corrupt cache, offline valid reuse and cancellation must have truthful outcomes. No checksum/authenticity guarantee unsupported by actual metadata.
- Scheduler owns its task and cancellation, uses 5-second startup, 24-hour cadence and 1-hour minimum, preserves persisted check/dismissal semantics, and mutates visible state only after repository commit. Test fake clocks or injected short timing. No default fake-success persistence.
- Firmware notifications remain independent from native application updates. Keep synchronous repository calls off any UI thread when integrated; no second SQLite pool in this slice.

Write firmware-catalog-supervisor-report.md with actionable file/line findings, priority, reproductions and fix requirements, plus spec and quality verdicts. Retain firmware-catalog-correctness-review.md and firmware-catalog-adversarial-review.md. Distinguish missing delivered behavior from explicit later adapters. Return a short result to root.
