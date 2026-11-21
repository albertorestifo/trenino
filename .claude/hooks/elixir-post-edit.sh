#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): format the edited Elixir file, then run its tests.
# Exit 2 feeds stderr back to Claude; exit 0 is silent.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

file=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[[ -n "$file" && -f "$file" ]] || exit 0
case "$file" in *.ex | *.exs | *.heex) ;; *) exit 0 ;; esac

rel=${file#"$CLAUDE_PROJECT_DIR"/}
[[ "$rel" != /* ]] || exit 0 # outside the project
case "$rel" in deps/* | _build/*) exit 0 ;; esac
have_mix || exit 0

if ! out=$(run_mix format "$rel" 2>&1); then
  printf 'mix format %s failed:\n%s\n' "$rel" "$out" | tail -n 40 >&2
  exit 2
fi

# Map the file to its test: test files run themselves, lib/x/y.ex runs test/x/y_test.exs.
case "$rel" in
  test/*_test.exs) test_file=$rel ;;
  lib/*.ex) test_file="test/${rel#lib/}" test_file="${test_file%.ex}_test.exs" ;;
  *) exit 0 ;;
esac
[[ -f "$test_file" ]] || exit 0

if ! out=$(MIX_ENV=test run_mix test "$test_file" 2>&1); then
  printf 'mix test %s failed after editing %s:\n%s\n' "$test_file" "$rel" "$out" | tail -n 80 >&2
  exit 2
fi
exit 0
