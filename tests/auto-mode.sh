#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

import() { :; }
# shellcheck source=../karnel/utils/log.sh
source "$ROOT_DIR/karnel/utils/log.sh"

# Non-destructive prompts still answer "y" automatically.
KARNEL_AUTO=1
read_confirm "Continue?" answer
[[ "$answer" == y ]] || fail "read_confirm should default to y in auto mode"

# Destructive prompts answer their own default instead of a forced "y".
read_confirm_default "Remove managed data?" n answer || true
[[ "$answer" == n ]] || fail "read_confirm_default must honour its default in auto mode"

read_confirm_default "Update to the new version?" y answer
[[ "$answer" == y ]] || fail "read_confirm_default y should stay affirmative"

# Call sites may pin an explicit safe answer.
read_confirm "Destructive operation" answer n || true
[[ "$answer" == n ]] || fail "explicit auto answer 'n' must win in auto mode"

# --auto must never be able to re-enable a destructive answer by itself.
KARNEL_AUTO=0
unset KARNEL_AUTO
[[ "$(KARNEL_AUTO=1 read_confirm_default "Delete everything?" n answer >/dev/null 2>&1; echo "$answer")" == "n" ]] ||
  fail "auto mode changed the destructive default"

grep -qF 'export KARNEL_AUTO=1' "$ROOT_DIR/karnel/bin/karnel"
grep -qF 'export KARNEL_NONINTERACTIVE=1' "$ROOT_DIR/karnel/bin/karnel"
grep -qF 'if [[ "${KARNEL_AUTO:-0}" == "1" ]]; then' "$ROOT_DIR/karnel/utils/agent_actions.sh"
grep -qF 'local auto_answer="${4:-$2}"' "$ROOT_DIR/karnel/utils/log.sh" ||
  fail "read_confirm_default must derive its auto answer from the default"

printf 'Auto mode contracts: 7 passed\n'
