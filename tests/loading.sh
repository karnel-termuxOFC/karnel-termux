#!/usr/bin/env bash
# `loading` used to run its command through `"$@" &`, which is a subshell: any
# variable the command assigned vanished before the caller could read it, and
# installers that stage a wrapper that way activated an empty path. The spinner
# is the part that has to be backgrounded, not the work.
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0
failed=0

run_test() {
  local name="$1"
  shift
  local rc=0 errexit_was_on=0
  [[ $- == *e* ]] && errexit_was_on=1
  set +e
  ( set -e; "$@" )
  rc=$?
  if ((errexit_was_on)); then set -e; fi
  if ((rc == 0)); then
    ((pass += 1))
    printf 'ok - %s\n' "$name"
  else
    ((failed += 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

# shellcheck source=../karnel/utils/colors.sh
source "$ROOT_DIR/karnel/utils/colors.sh"
import() { :; }
# shellcheck source=../karnel/utils/log.sh
source "$ROOT_DIR/karnel/utils/log.sh"

setup_loading() {
  export KARNEL_CACHE="$TEST_ROOT/cache-${BASHPID:-$$}"
  mkdir -p "$KARNEL_CACHE"
}

_stage_wrapper() {
  STAGED_WRAPPER="/staged/codebuff"
}

_cwd_mover() {
  cd / || return 1
}

assert_loading_returns_the_command_exit_code() (
  setup_loading
  local rc=0
  loading "probe" bash -c 'exit 0' >/dev/null 2>&1 || rc=$?
  ((rc == 0)) || { printf 'expected 0, got %s\n' "$rc" >&2; return 1; }
  rc=0
  loading "probe" bash -c 'exit 2' >/dev/null 2>&1 || rc=$?
  ((rc == 2)) || { printf 'expected 2, got %s\n' "$rc" >&2; return 1; }
  rc=0
  loading "probe" bash -c 'exit 3' >/dev/null 2>&1 || rc=$?
  ((rc == 3)) || { printf 'expected 3, got %s\n' "$rc" >&2; return 1; }
  return 0
)

assert_loading_keeps_what_the_command_assigned() (
  setup_loading
  unset STAGED_WRAPPER 2>/dev/null || true
  loading "Compiling helper" _stage_wrapper >/dev/null 2>&1 || return 1
  [[ "${STAGED_WRAPPER:-}" == "/staged/codebuff" ]] || {
    printf 'the staged path did not survive: %s\n' "${STAGED_WRAPPER:-<empty>}" >&2
    return 1
  }
  return 0
)

assert_loading_prints_the_command_output() (
  setup_loading
  local out
  out="$(loading "step" printf 'payload from the step\n')"
  [[ "$out" == *"payload from the step"* ]] || {
    printf 'output was not forwarded: %s\n' "$out" >&2
    return 1
  }
  return 0
)

assert_loading_contains_a_change_of_directory() (
  setup_loading
  local here="$PWD"
  loading "step" _cwd_mover >/dev/null 2>&1 || return 1
  [[ "$PWD" == "$here" ]] || {
    printf 'the caller was left in %s\n' "$PWD" >&2
    return 1
  }
  return 0
)

assert_loading_survives_a_failing_command() (
  setup_loading
  local rc=0
  loading "step" bash -c 'echo boom >&2; exit 1' >/dev/null 2>&1 || rc=$?
  ((rc == 1)) || { printf 'expected 1, got %s\n' "$rc" >&2; return 1; }
  loading "step" bash -c 'exit 0' >/dev/null 2>&1 || return 1
  return 0
)

run_test "loading returns the exit code of its command" assert_loading_returns_the_command_exit_code
run_test "loading keeps what its command assigned" assert_loading_keeps_what_the_command_assigned
run_test "loading prints what its command printed" assert_loading_prints_the_command_output
run_test "loading contains a change of directory" assert_loading_contains_a_change_of_directory
run_test "a failing step does not take the caller down" assert_loading_survives_a_failing_command

printf '1..%d\n' "$pass"
if ((failed > 0)); then
  printf 'Loading: %d passed, %d failed\n' "$pass" "$failed" >&2
  exit 1
fi
printf 'Loading: %d passed, %d failed\n' "$pass" "$failed"
