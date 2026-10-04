#!/usr/bin/env bash
# Regression guard: every tool directory must be reachable through
# `karnel list <target>`, and the target/help/TUI metadata must cover
# every module. This is the check that keeps list.sh from drifting away
# from the installer tree again.
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KARNEL_BIN="$ROOT_DIR/karnel/bin/karnel"
TOOLS_DIR="$ROOT_DIR/karnel/tools"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/xdg/config"
export XDG_CACHE_HOME="$TEST_ROOT/xdg/cache"
export XDG_DATA_HOME="$TEST_ROOT/xdg/data"
export XDG_STATE_HOME="$TEST_ROOT/xdg/state"
export XDG_RUNTIME_DIR="$TEST_ROOT/xdg/runtime"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" \
  "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

pass=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
ok() { pass=$((pass + 1)); }

# Render a list target and return only the Install Flag column.
list_flags() {
  bash "$KARNEL_BIN" list "$1" 2>/dev/null |
    sed 's/\x1b\[[0-9;]*m//g' |
    sed -nE 's/.*│ *(--[A-Za-z0-9._-]+).*/\1/p' |
    sort -u
}

mapfile -t module_dirs < <(find "$TOOLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

total_tools=0
targets_checked=0

for module_dir in "${module_dirs[@]}"; do
  module=${module_dir##*/}
  target="$module"
  [[ "$module" == plugins ]] && target=plugin

  mapfile -t tool_dirs < <(find "$module_dir" -mindepth 1 -maxdepth 1 -type d | sort)
  tools=()
  for dir in "${tool_dirs[@]}"; do
    [[ -f "$dir/install.sh" ]] && tools+=("${dir##*/}")
  done

  if ! output=$(bash "$KARNEL_BIN" list "$target" 2>/dev/null); then
    fail "karnel list $target exited non-zero"
  fi
  ok

  mapfile -t flags < <(printf '%s\n' "$output" |
    sed 's/\x1b\[[0-9;]*m//g' |
    sed -nE 's/.*│ *(--[A-Za-z0-9._-]+).*/\1/p' |
    sed 's/^--//' | sort -u)

  declare -A listed=()
  for flag in "${flags[@]}"; do
    [[ -n "$flag" ]] && listed["$flag"]=1
  done

  for tool in "${tools[@]}"; do
    [[ -n "${listed[$tool]+set}" ]] || {
      fail "karnel list $target does not show $module/$tool"
    }
    ok
  done
  for flag in "${!listed[@]}"; do
    [[ -f "$module_dir/$flag/install.sh" ]] || {
      fail "karnel list $target shows unknown tool $flag"
    }
    ok
  done
  unset listed

  total_tools=$((total_tools + ${#tools[@]}))
  targets_checked=$((targets_checked + 1))
done

# The registryless module keeps its directory name as an alias.
if ! bash "$KARNEL_BIN" list plugins >/dev/null 2>&1; then
  fail "karnel list plugins alias exited non-zero"
fi
ok

# `karnel list` (no args) must document every target.
help_output=$(bash "$KARNEL_BIN" list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
for module_dir in "${module_dirs[@]}"; do
  module=${module_dir##*/}
  target="$module"
  [[ "$module" == plugins ]] && target=plugin
  printf '%s\n' "$help_output" | grep -qE "[[:space:]]${target}[[:space:]]+-" ||
    fail "karnel list help omits target: $target"
  ok
done

# Unknown targets must stay rejected.
if bash "$KARNEL_BIN" list definitely-not-a-module >/dev/null 2>&1; then
  fail "karnel list accepted an unknown target"
fi
ok

# TUI labels must derive their counts from the installer tree — a hardcoded
# count (e.g. "AI Tools (43)") silently goes stale.
if grep -qE '"[A-Za-z][A-Za-z0-9 &-]*\([0-9]+\)"' "$ROOT_DIR/karnel/cli/karnel.sh"; then
  fail "karnel/cli/karnel.sh contains a hardcoded tool count in a menu label"
fi
ok

printf 'List coverage: %d targets, %d tools listed and matched\n' \
  "$targets_checked" "$total_tools"
