#!/usr/bin/env bash
# Stop hook: run `mix precommit` before Claude finishes, if the working tree has
# uncommitted Elixir/config changes that have not already passed.
# Exit 2 blocks the stop and feeds stderr back to Claude so it fixes the failures.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

input=$(cat)
stop_hook_active=$(jq -r '.stop_hook_active // false' <<<"$input")

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
changes=$(git status --porcelain --untracked-files=all -- \
  '*.ex' '*.exs' '*.heex' 'mix.lock' 'config/' 'priv/repo/' 2>/dev/null)
[[ -n "$changes" ]] || exit 0
have_mix || exit 0

state_dir="$CLAUDE_PROJECT_DIR/_build/claude-hooks"
mkdir -p "$state_dir"
tree_hash() { { git diff HEAD; git status --porcelain --untracked-files=all; git ls-files -o --exclude-standard -z | xargs -0 cat 2>/dev/null; } | git hash-object --stdin; }

current=$(tree_hash)
[[ "$current" == "$(cat "$state_dir/passed" 2>/dev/null)" ]] && exit 0

# Loop guard: if Claude is stopping again without changing anything since the
# last failure, let it stop rather than blocking forever.
if [[ "$stop_hook_active" == "true" && "$current" == "$(cat "$state_dir/failed" 2>/dev/null)" ]]; then
  jq -n '{systemMessage: "mix precommit is still failing; stopping without a fix."}'
  exit 0
fi

if out=$(run_mix precommit 2>&1); then
  tree_hash >"$state_dir/passed" # precommit may have reformatted files
  rm -f "$state_dir/failed"
  exit 0
fi

tree_hash >"$state_dir/failed"
printf 'mix precommit failed. Fix the problems below before finishing:\n%s\n' "$out" | tail -n 120 >&2
exit 2
