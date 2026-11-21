# Shared helpers for the Claude Code hooks in this directory. Sourced, not run.

cd "${CLAUDE_PROJECT_DIR:?}" || exit 0

# Run mix from PATH, or through mise when only mise is installed.
# Returns 127 when neither is available, so hooks can skip quietly.
run_mix() {
  if command -v mix >/dev/null 2>&1; then
    mix "$@"
  elif command -v mise >/dev/null 2>&1; then
    mise exec -- mix "$@"
  else
    return 127
  fi
}

have_mix() {
  command -v mix >/dev/null 2>&1 || command -v mise >/dev/null 2>&1
}
