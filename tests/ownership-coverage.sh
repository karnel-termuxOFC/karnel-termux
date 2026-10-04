#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pass=0
failed=0

run_test() {
  local name="$1"
  shift
  if "$@"; then
    ((pass += 1))
    printf 'ok - %s\n' "$name"
  else
    ((failed += 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

log_error() { :; }
log_warn() { :; }
import() { :; }

# shellcheck source=../karnel/utils/tools.sh
source "$ROOT_DIR/karnel/utils/tools.sh"

# Every tool must be classified exactly once: either centrally owned or
# explicitly self-managed. An unclassified tool silently loses its uninstall
# guard; an overlapping one risks double bookkeeping.
assert_every_tool_is_classified_once() (
  local dir module tool owned self_managed
  for dir in "$ROOT_DIR"/karnel/tools/*/*/; do
    [[ -f "$dir/install.sh" ]] || continue
    module="$(basename "$(dirname "$dir")")"
    tool="$(basename "$dir")"
    owned=0
    self_managed=0
    _tool_uses_central_ownership "$module" "$tool" && owned=1
    _tool_has_self_managed_ownership "$module" "$tool" && self_managed=1
    if (( owned && self_managed )); then
      printf 'FAIL: %s/%s is both centrally owned and self-managed\n' "$module" "$tool" >&2
      exit 1
    fi
    if (( ! owned && ! self_managed )); then
      printf 'FAIL: %s/%s has no ownership classification\n' "$module" "$tool" >&2
      exit 1
    fi
  done
)
run_test "every tool is classified exactly once" assert_every_tool_is_classified_once

# Regression guard for the original gap: ownership used to cover only 61 of
# the 166 tools, so most modules had no uninstall guard at all.
assert_central_ownership_covers_most_tools() (
  local total=0 owned=0 dir module tool
  for dir in "$ROOT_DIR"/karnel/tools/*/*/; do
    [[ -f "$dir/install.sh" ]] || continue
    module="$(basename "$(dirname "$dir")")"
    tool="$(basename "$dir")"
    ((total += 1))
    _tool_uses_central_ownership "$module" "$tool" && ((owned += 1))
  done
  if (( total < 160 )); then
    printf 'FAIL: expected at least 160 tools, found %d\n' "$total" >&2
    exit 1
  fi
  if (( owned * 2 < total )); then
    printf 'FAIL: only %d of %d tools are centrally owned\n' "$owned" "$total" >&2
    exit 1
  fi
  printf '# centrally owned: %d/%d tools\n' "$owned" "$total"
)
run_test "central ownership covers at least half of all tools" assert_central_ownership_covers_most_tools

# AI tools and deploy CLIs must never be claimed by the central ledger.
assert_self_managed_modules_stay_outside() (
  _tool_uses_central_ownership ai opencode && exit 1
  _tool_uses_central_ownership ai freebuff && exit 1
  _tool_uses_central_ownership deploy vercel && exit 1
  _tool_uses_central_ownership lang bun && exit 1
  _tool_uses_central_ownership utils herdr && exit 1
  _tool_uses_central_ownership security metasploit && exit 1
  exit 0
)
run_test "self-managed tools are excluded from central ownership" assert_self_managed_modules_stay_outside

# Modules that used to be missing entirely from the ownership list.
assert_newly_covered_modules() (
  _tool_uses_central_ownership shell powerlevel10k || exit 1
  _tool_uses_central_ownership ui banner || exit 1
  _tool_uses_central_ownership games buzz || exit 1
  _tool_uses_central_ownership network dark || exit 1
  _tool_uses_central_ownership utils notes || exit 1
  _tool_uses_central_ownership osint robin || exit 1
  _tool_uses_central_ownership security wpscan || exit 1
  exit 0
)
run_test "shell/ui/games/network/utils/osint/security are covered" assert_newly_covered_modules

# Unknown or pseudo modules stay unprotected so generic fixtures keep working.
assert_unknown_modules_are_not_owned() (
  _tool_uses_central_ownership fixture demo && exit 1
  _tool_uses_central_ownership plugin demo && exit 1
  _tool_uses_central_ownership voice demo && exit 1
  exit 0
)
run_test "unknown and pseudo modules are not centrally owned" assert_unknown_modules_are_not_owned

printf 'Ownership coverage: %d passed, %d failed\n' "$pass" "$failed"
((failed == 0))
