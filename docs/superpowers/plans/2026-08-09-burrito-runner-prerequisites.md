# Standardized Burrito Runner Prerequisites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every GitHub Actions Burrito build one shared, pinned, verified setup for Zig and xz.

**Architecture:** A repository-local composite action owns prerequisite installation and verification. CI, nightly, and release call that action, while an ExUnit static test prevents workflows from bypassing it or reintroducing standalone Zig setup.

**Tech Stack:** GitHub Actions composite actions, YAML, PowerShell, Bash, Elixir/ExUnit.

## Global Constraints

- Pin Zig to exactly `0.15.2` in one place.
- Install XZ Utils `5.8.3` from the official Tukaani Windows archive on Windows, verify SHA-256 `8d0048ee51177b11ef1613959c2a268c951f4e7f6fb3706e681e00e34bb6d5e3`, and verify xz on every runner.
- Preserve existing workflow matrices, release commands, caches, secrets, artifacts, Tauri packaging, and vJoy behavior.
- Do not install or mutate the vJoy driver on GitHub-hosted runners.

---

### Task 1: Add a failing workflow-wiring regression test

**Files:**
- Create: `test/ci/burrito_prerequisites_test.exs`
- Inspect: `.github/workflows/ci.yml`
- Inspect: `.github/workflows/nightly.yml`
- Inspect: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: repository workflow files at `.github/workflows/{ci,nightly,release}.yml`
- Produces: an ExUnit contract requiring `uses: ./.github/actions/setup-burrito` in every Burrito workflow and forbidding direct `uses: mlugg/setup-zig` wiring there

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Trenino.CI.BurritoPrerequisitesTest do
  use ExUnit.Case, async: true

  @workflows ~w(ci nightly release)

  test "all Burrito workflows use the shared prerequisite action" do
    for workflow <- @workflows do
      contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "#{workflow}.yml"]))

      assert contents =~ "uses: ./.github/actions/setup-burrito",
             "#{workflow}.yml must use the shared Burrito prerequisite action"

      refute contents =~ "uses: mlugg/setup-zig",
             "#{workflow}.yml must not configure Zig outside the shared action"
    end
  end
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `mix test test/ci/burrito_prerequisites_test.exs`

Expected: FAIL because `ci.yml` has no shared action call and nightly/release still use `mlugg/setup-zig@v2` directly.

- [ ] **Step 3: Commit the regression test**

```bash
git add test/ci/burrito_prerequisites_test.exs
git commit -m "test: require shared Burrito prerequisite setup"
```

### Task 2: Create the shared prerequisite action and migrate workflows

**Files:**
- Create: `.github/actions/setup-burrito/action.yml`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/nightly.yml`
- Modify: `.github/workflows/release.yml`
- Test: `test/ci/burrito_prerequisites_test.exs`

**Interfaces:**
- Consumes: GitHub runner OS, the official Tukaani XZ Utils release archive on Windows, `mlugg/setup-zig@v2`
- Produces: executable `zig` 0.15.2 and `xz` available on `PATH` before Burrito runs

- [ ] **Step 1: Add the composite action**

Create `.github/actions/setup-burrito/action.yml` with this behavior:

```yaml
name: Setup Burrito prerequisites
description: Install and verify the pinned tools required by Burrito

runs:
  using: composite
  steps:
    - name: Install xz on Windows
      if: runner.os == 'Windows'
      shell: pwsh
      run: |
        $version = '5.8.3'
        $expectedSha256 = '8d0048ee51177b11ef1613959c2a268c951f4e7f6fb3706e681e00e34bb6d5e3'
        $archive = Join-Path $env:RUNNER_TEMP "xz-$version-windows.zip"
        $destination = Join-Path $env:RUNNER_TEMP "xz-$version-windows"
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/tukaani-project/xz/releases/download/v$version/xz-$version-windows.zip" -OutFile $archive
        $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
        if ($actualSha256 -ne $expectedSha256) { throw "XZ archive SHA-256 mismatch: expected $expectedSha256, got $actualSha256" }
        Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
        $xzDirectory = Join-Path $destination 'bin_x86-64'
        if (-not (Test-Path -LiteralPath (Join-Path $xzDirectory 'xz.exe') -PathType Leaf)) { throw 'XZ archive did not contain bin_x86-64/xz.exe' }
        $xzDirectory | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

    - name: Setup Zig
      uses: mlugg/setup-zig@v2
      with:
        version: 0.15.2

    - name: Verify Burrito prerequisites
      shell: bash
      run: |
        set -euo pipefail
        command -v zig
        zig version
        command -v xz
        xz --version
```

- [ ] **Step 2: Migrate CI**

In `.github/workflows/ci.yml`, add the following step after Elixir setup and before Rust/dependency/build work in `windows-package`:

```yaml
      - name: Set up Burrito prerequisites
        uses: ./.github/actions/setup-burrito
```

- [ ] **Step 3: Migrate nightly and release**

In the `build-elixir` job of `.github/workflows/nightly.yml` and `.github/workflows/release.yml`, replace the standalone `Setup Zig` step with:

```yaml
      - name: Set up Burrito prerequisites
        uses: ./.github/actions/setup-burrito
```

Keep the existing Windows `7zip` installation and Linux workaround unchanged.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `mix test test/ci/burrito_prerequisites_test.exs`

Expected: 1 test, 0 failures.

- [ ] **Step 5: Validate action/workflow syntax and repository checks**

Run:

```bash
npx --yes action-validator .github/actions/setup-burrito/action.yml
npx --yes action-validator .github/workflows/ci.yml
npx --yes action-validator .github/workflows/nightly.yml
npx --yes action-validator .github/workflows/release.yml
mix test
git diff --check
```

Expected: all commands exit 0; ExUnit reports no failures.

- [ ] **Step 6: Commit the implementation**

```bash
git add .github/actions/setup-burrito/action.yml .github/workflows/ci.yml .github/workflows/nightly.yml .github/workflows/release.yml
git commit -m "ci: standardize Burrito prerequisites"
```

### Task 3: Verify on GitHub-hosted runners

**Files:**
- No new files

**Interfaces:**
- Consumes: commits on `master`, GitHub-hosted Windows and Linux runners
- Produces: successful CI packaging evidence and a clean open-PR inventory

- [ ] **Step 1: Push the committed master branch**

Run: `git push origin master`

Expected: push succeeds without force.

- [ ] **Step 2: Monitor the resulting CI run**

Run: `gh run list --workflow CI --branch master --limit 1` and monitor the returned run with `gh run watch <run-id> --exit-status`.

Expected: `Build and Test` and `Windows package (no driver mutation)` both complete successfully. The Windows logs must show Zig and xz version verification before Burrito packaging, packaged-resource inspection, and installer artifact upload.

- [ ] **Step 3: Confirm no pull requests remain open**

Run: `gh pr list --state open --limit 100 --json number,title,url`

Expected: `[]`.
