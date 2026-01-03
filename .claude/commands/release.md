---
description: Create a new release (major/minor/patch)
argument-hint: [major|minor|patch]
allowed-tools: Bash(git *), Bash(gh *), Bash(gh --version), Bash(mix version *), Read, Edit, Grep, Glob
---

# Release Process

Create a new release by bumping the version ($ARGUMENTS).

## Instructions

### 1. Review Changes Since Last Release

Get all commits since the last release tag:
```
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

Review these commits carefully to understand what changed.

### 2. Review and Improve the Changelog

Read `CHANGELOG.md` and check the `[Unreleased]` section:
- Ensure all significant changes from the commits are documented
- Improve descriptions to be clear and user-friendly
- Group changes properly under Added/Changed/Fixed/Removed
- Fix any typos or unclear wording
- Make it appealing for users to read

If the changelog needs updates, edit it before proceeding.

### 3. Calculate New Version

Based on the current version and the bump type ($ARGUMENTS):
- **major**: Breaking changes (X.0.0)
- **minor**: New features, backwards compatible (0.X.0)
- **patch**: Bug fixes only (0.0.X)

### 4. Update Changelog Header

Change `[Unreleased]` to `[X.Y.Z]` with today's date in format `## [X.Y.Z] - YYYY-MM-DD`

Add a new empty `[Unreleased]` section above it with the standard subsections.

### 5. Bump Version

Run the mix version task with the calculated version number:
```
mix version X.Y.Z
```

This updates mix.exs, tauri.conf.json, Cargo.toml, package.json, and splash.html.

### 6. Commit the Version Bump

```
git add -A
git commit -m "Release vX.Y.Z"
```

### 7. Create and Push the Tag

```
git tag vX.Y.Z
git push origin master
git push origin vX.Y.Z
```

### 8. Create GitHub Release

Use the GitHub CLI to create a release with compelling release notes:

```
gh release create vX.Y.Z --title "vX.Y.Z" --notes "RELEASE_NOTES_HERE"
```

The release notes should:
- Start with a brief, engaging summary of the release (1-2 sentences)
- Highlight the most important/exciting changes (3-5 bullet points max)
- Use clear, user-focused language (not developer jargon)
- End with "See the [full changelog](CHANGELOG.md) for complete details."

Do NOT just copy-paste the entire changelog - curate and highlight what matters most to users.
