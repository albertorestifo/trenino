---
description: Create a new release (major/minor/patch)
argument-hint: [major|minor|patch]
allowed-tools: Bash(git *), Bash(gh *), Bash(mix version *), Bash(mix precommit), Bash(mix hex.audit), Bash(cargo test *), Read, Edit, Grep, Glob
---

# Release

Create a release by applying a $ARGUMENTS version bump. Stop if any verification step fails.

1. **Review changes.** Read `git log $(git describe --tags --abbrev=0)..HEAD --oneline`.

2. **Update the changelog.** Make sure `[Unreleased]` in `CHANGELOG.md` covers every significant change in user-friendly language. Rename it to `## [X.Y.Z] - YYYY-MM-DD` and add a new empty `[Unreleased]` section above it.

3. **Bump the version.** Run `mix version X.Y.Z`. It updates `mix.exs`, `tauri/src-tauri/tauri.conf.json`, `tauri/src-tauri/Cargo.toml`, `tauri/src-tauri/Cargo.lock`, `tauri/package.json` and `tauri/src-tauri/splash.html`.

4. **Verify.** Run each of these:
   ```
   mix precommit
   cargo test --manifest-path tauri/virtual_joystick/Cargo.toml
   mix hex.audit
   ```

5. **Commit.** Stage only the release files, plus any formatting changes from `mix precommit` that belong to the release:
   ```
   git add CHANGELOG.md mix.exs tauri/package.json tauri/src-tauri/tauri.conf.json tauri/src-tauri/Cargo.toml tauri/src-tauri/Cargo.lock tauri/src-tauri/splash.html
   git commit -m "Release vX.Y.Z"
   ```

6. **Tag and push.**
   ```
   git tag vX.Y.Z
   git push origin master
   git push origin vX.Y.Z
   ```

7. **Create the GitHub release.** This is what starts the desktop build: `release.yml` runs on `release: created`, not on the tag, and checks the tag against the source versions.
   ```
   gh release create vX.Y.Z --title "vX.Y.Z" --notes "RELEASE_NOTES_HERE"
   ```
   Write the notes for users: a 1-2 sentence summary, 3-5 highlights, then `See the [full changelog](https://github.com/albertorestifo/trenino/blob/vX.Y.Z/CHANGELOG.md) for complete details.`
