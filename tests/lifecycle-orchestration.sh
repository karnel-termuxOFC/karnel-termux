#!/usr/bin/env bash
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
  if (( errexit_was_on )); then set -e; fi
  if (( rc == 0 )); then
    ((pass += 1))
    printf 'ok - %s\n' "$name"
  else
    ((failed += 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

log_error() { :; }
log_warn() { :; }
log_info() { :; }
log_success() { :; }
import() { :; }

# shellcheck source=../karnel/utils/tools.sh
source "$ROOT_DIR/karnel/utils/tools.sh"

assert_reinstall_stops_after_uninstall_failure() (
  calls=()
  uninstall_demo() { calls+=(uninstall); return 7; }
  install_demo() { calls+=(install); }

  # `|| rc=$?` keeps errexit from aborting before the code under test has
  # returned, and matches how production (no `set -e`) invokes it.
  rc=0
  _run_tool_lifecycle_action fixture reinstall demo || rc=$?
  [[ $rc -eq 7 && "${calls[*]}" == "uninstall" ]]
)
run_test "reinstall stops after uninstall failure" assert_reinstall_stops_after_uninstall_failure

assert_reinstall_proceeds_after_uninstall_skip() (
  calls=()
  uninstall_demo() { calls+=(uninstall); return 2; }
  install_demo() { calls+=(install); }

  rc=0
  _run_tool_lifecycle_action fixture reinstall demo || rc=$?
  # An uninstall that reports "already uninstalled" (rc 2) must not abort the
  # reinstall: the install step still runs so a not-yet-installed tool can be
  # (re)installed.
  [[ $rc -eq 0 && "${calls[*]}" == "uninstall install" ]]
)
run_test "reinstall proceeds to install after uninstall skip" assert_reinstall_proceeds_after_uninstall_skip

assert_registered_handler_guards_specific_flow() (
  calls=()
  uninstall_demo() { calls+=(uninstall); return 1; }
  install_demo() { calls+=(install); }
  reinstall_demo() { calls+=(unsafe-reinstall); }
  _register_safe_reinstall_handlers fixture demo

  rc=0
  reinstall_demo || rc=$?
  [[ $rc -eq 1 && "${calls[*]}" == "uninstall" ]]
)
run_test "registered specific reinstall is guarded" assert_registered_handler_guards_specific_flow

assert_install_marks_only_new_managed_install() (
  export KARNEL_DATA="$TEST_ROOT/install-state"
  install_python() { return 0; }

  _run_tool_lifecycle_action lang install python || return 1
  marker="$KARNEL_DATA/ownership/lang/python"
  [[ -f "$marker" && "$(stat -c %a "$marker")" == 600 ]] || return 1

  rm -f "$marker"
  install_python() { return 2; }
  rc=0
  _run_tool_lifecycle_action lang install python || rc=$?
  [[ $rc -eq 2 && ! -e "$marker" ]]
)
run_test "successful new install creates a private ownership marker" assert_install_marks_only_new_managed_install

assert_unowned_package_actions_are_preserved() (
  export KARNEL_DATA="$TEST_ROOT/legacy-state"
  calls=()
  uninstall_python() { calls+=(uninstall); }
  update_python() { calls+=(update); }
  install_python() { calls+=(install); }

  for action in uninstall update reinstall; do
    rc=0
    _run_tool_lifecycle_action lang "$action" python || rc=$?
    [[ $rc -eq 2 ]] || return 1
  done
  [[ ${#calls[@]} -eq 0 ]]
)
run_test "unowned package actions preserve external and legacy installs" assert_unowned_package_actions_are_preserved

assert_custom_tool_is_not_centrally_blocked() (
  export KARNEL_DATA="$TEST_ROOT/custom-state"
  calls=()
  uninstall_bun() { calls+=(uninstall); }

  _run_tool_lifecycle_action lang uninstall bun
  [[ "${calls[*]}" == uninstall ]]
)
run_test "custom marker-backed tools bypass central ownership" assert_custom_tool_is_not_centrally_blocked

assert_uninstall_removes_marker_only_on_success() (
  export KARNEL_DATA="$TEST_ROOT/uninstall-state"
  marker="$KARNEL_DATA/ownership/db/redis"
  mkdir -p "${marker%/*}"
  : >"$marker"
  uninstall_redis() { return 9; }

  rc=0
  _run_tool_lifecycle_action db uninstall redis || rc=$?
  [[ $rc -eq 9 && -f "$marker" ]] || return 1
  uninstall_redis() { return 0; }
  _run_tool_lifecycle_action db uninstall redis
  [[ ! -e "$marker" ]]
)
run_test "uninstall retains marker on failure and removes it on success" assert_uninstall_removes_marker_only_on_success

assert_reinstall_recreates_marker_after_install() (
  export KARNEL_DATA="$TEST_ROOT/reinstall-state"
  marker="$KARNEL_DATA/ownership/editor/neovim"
  mkdir -p "${marker%/*}"
  : >"$marker"
  calls=()
  uninstall_neovim() { calls+=(uninstall); return 0; }
  install_neovim() { calls+=(install); return 0; }

  _run_tool_lifecycle_action editor reinstall neovim || return 1
  [[ "${calls[*]}" == "uninstall install" && -f "$marker" ]] || return 1

  install_neovim() { calls+=(failed-install); return 8; }
  rc=0
  _run_tool_lifecycle_action editor reinstall neovim || rc=$?
  # On install failure the ownership marker must survive so the tool is not
  # orphaned (a missing marker would make the protected guard refuse future
  # reinstall/uninstall operations on an already-installed tool).
  [[ $rc -eq 8 && -e "$marker" ]]
)
run_test "reinstall sequences handlers and recreates ownership after install" assert_reinstall_recreates_marker_after_install

assert_batch_status_contract() (
  install_ok() { return 0; }
  install_skip() { return 2; }
  install_bad() { return 9; }

  _batch_tool_action fixture install ok skip || return 1
  ! _batch_tool_action fixture install ok bad missing
)
run_test "batch accepts zero/two and rejects failures or missing handlers" assert_batch_status_contract

assert_package_installers_report_existing() (
  import() { :; }
  loading() { shift; "$@"; }
  _fix_npm_shebang() { :; }
  export KARNEL_CACHE="$TEST_ROOT/package-cache"
  local specification file handler binary rc

  for specification in \
    'npm/typescript:install_typescript:tsc' \
    'npm/nestjs:install_nestjs:nest' \
    'npm/prettier:install_prettier:prettier' \
    'npm/live-server:install_live_server:live-server' \
    'npm/localtunnel:install_localtunnel:lt' \
    'npm/vercel:install_vercel:vercel' \
    'npm/markserv:install_markserv:markserv' \
    'npm/psqlformat:install_psqlformat:psqlformat' \
    'npm/ncu:install_ncu:ncu' \
    'npm/ngrok:install_ngrok:ngrok' \
    'auto/n8n:install_n8n:n8n' \
    'editor/neovim:install_neovim:nvim'; do
    IFS=: read -r file handler binary <<<"$specification"
    command() {
      if [[ "$1" == -v && "$2" == "$binary" ]]; then return 0; fi
      builtin command "$@"
    }
    # shellcheck source=/dev/null
    source "$ROOT_DIR/karnel/tools/$file/install.sh"
    rc=0
    "$handler" || rc=$?
    [[ $rc -eq 2 ]] || return 1
  done
)
run_test "package-backed installers return two for existing commands" assert_package_installers_report_existing

assert_security_package_update_runs_manager() (
  calls=()
  pkg() { calls+=("$*"); }
  apt() { return 1; }
  # shellcheck source=../karnel/tools/security/nmap/install.sh
  source "$ROOT_DIR/karnel/tools/security/nmap/install.sh"

  update_nmap
  [[ "${calls[*]}" == "install -y nmap" ]]
)
run_test "security package update invokes package manager" assert_security_package_update_runs_manager

assert_security_backends_are_tracked() (
  export HOME="$TEST_ROOT/home"
  export KARNEL_DATA="$TEST_ROOT/data"
  mkdir -p "$HOME"
  calls=()
  command() {
    if [[ "$1" == "-v" && ( "$2" == "wpscan" || "$2" == "wafw00f" ) ]]; then
      return 1
    fi
    builtin command "$@"
  }
  pkg() { calls+=("pkg:$*"); }
  apt() { return 1; }
  gem() { calls+=("gem:$*"); return 1; }
  pip() { calls+=("pip:$*"); return 1; }
  # shellcheck source=../karnel/tools/security/wpscan/install.sh
  source "$ROOT_DIR/karnel/tools/security/wpscan/install.sh"
  # shellcheck source=../karnel/tools/security/wafw00f/install.sh
  source "$ROOT_DIR/karnel/tools/security/wafw00f/install.sh"

  install_wpscan && install_wafw00f
  [[ "$(<"$_WPSCAN_BACKEND_FILE")" == package ]]
  [[ "$(<"$_WAFW00F_BACKEND_FILE")" == package ]]
  update_wpscan && update_wafw00f
  uninstall_wpscan && uninstall_wafw00f
  [[ ! -e "$_WPSCAN_BACKEND_FILE" && ! -e "$_WAFW00F_BACKEND_FILE" ]]
  [[ "${calls[*]}" != *gem:* && "${calls[*]}" != *pip:* ]]
)
run_test "WPScan and wafw00f reuse tracked package backends" assert_security_backends_are_tracked

printf 'Lifecycle orchestration: %d passed, %d failed\n' "$pass" "$failed"
((failed == 0))
