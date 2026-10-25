# Review coverage and provenance

The [source index](../source-index.md) maps all **530 tracked files** in original `master` commit `188f35e4108733358730e92ebd98f1912af5173a` to their feature documentation. The destination rewrite branch is not the source of this reference. No code from that branch was inspected.

## Machine-readable records

| File | Meaning |
|---|---|
| [baseline.json](baseline.json) | Original tracked path list, source commit/date, Git blob IDs and modes |
| [all-files.json](all-files.json) | Exactly one review record per baseline path: owner, feature document, purpose, review type, original Git blob and SHA-256 |
| [hardware-scope.json](hardware-scope.json) / [hardware-review.json](hardware-review.json) | 88 hardware/serial/firmware files and their review results |
| [train-scope.json](train-scope.json) / [train-review.json](train-review.json) | 68 simulator/train/calibration/automation files and their review results |
| [interfaces-scope.json](interfaces-scope.json) / [interfaces-review.json](interfaces-review.json) | 105 UI/API/MCP/assets files and their review results |
| [platform-scope.json](platform-scope.json) / [platform-review.json](platform-review.json) | 269 runtime/desktop/joystick/persistence/operations/support files and review results |
| [verification.json](verification.json) | Final documentation-integrity results; see [verification notes](../verification.md) for scope |

The original scope files are disjoint and their union equals the baseline. Review manifests must match their scopes exactly, without duplicate/unknown paths. `all-files` hashes the committed source blobs, not concurrently modified working files. The generated documentation itself is not part of the original 530-file baseline.

## Review classifications

| Type | What was reviewed |
|---|---|
| source | First-party executable source or runtime/build configuration: behavior and integration contract read and documented |
| migration | All 41 timestamped migrations: SQL/Ecto transformations, constraints, destructive/irreversible behavior |
| test | Existing tests/support: assertions, setup/fakes and what they do or do not exercise; no implication they were rerun |
| reference | Existing product/design/guidance/user documentation relevant to the review, compared with current implementation where used as evidence |
| reference-outline | Historical plans/specs/reports or background guides catalogued by content/outline and provenance; not asserted as implemented behavior, and not a claim of line-by-line semantic review of obsolete plan examples |
| vendor | Third-party browser plugin wrappers reviewed plus bundled CSS/token/icon data inventoried; dormant class/palette entries are not separate app features |
| generated | Generated Tauri ACL/capability schema JSON parsed/inventoried; checked as metadata rather than hand-authored business behavior |
| dependency | Dependency lock contents parsed/scanned for package/version/hash inventory; dependencies' external implementations are outside the app review |
| metadata | Formatting/design/configuration metadata inventoried; effect described in the supporting feature area |
| asset | Branding/icon/static/localization files inventoried; binary files inspected by signature/dimensions/hash where applicable, not treated as source code |

Counts: 234 source, 41 migration, 130 test, 21 reference, 32 reference-outline, 4 vendor, 4 generated, 6 dependency, 2 metadata, 56 asset = 530. These types deliberately distinguish detailed code review from asset/reference inventory. Some support schemas/config files are classified source; not all 234 are user-facing feature modules.

## Snapshot discipline and exclusions

Initial `git pull --ff-only` succeeded and reported already up to date. Existing untracked mechanical and rewrite plans were left alone. During review, unrelated work modified the launcher and joystick system adapter and added a backend-cache helper and command test. Those uncommitted changes were excluded. Source links/hashes continue to identify the committed baseline. This avoids silently mixing two versions of behavior.

Ignored dependencies, build products, local databases/WAL files, caches, temporary scripts, existing untracked files, the sibling `tsw_board` repository, external Arduino firmware implementations, current published release state and live game/driver state are outside this baseline. Their observable integration boundaries are documented where the reviewed host source defines them.

## Audit method

The final integrity check compares each scope against its review, checks the union against baseline, resolves every declared feature document, verifies all 530 blob/hash records against the original Git object database, checks local Markdown paths/anchors, validates pinned source paths against the baseline tree and counts unique story anchors. It also checks the candidate publication tree changes only `docs/feature-reference/`. Source links use the baseline SHA so publishing to a different code branch does not change their meaning.

Coverage is a traceability mechanism, not a mathematical proof that every behavior has a perfect description. Known gaps and source/test limitations are recorded in feature chapters and [rewrite contracts](../rewrite-contract.md). Physical interoperability still requires hardware/game/driver acceptance testing.
