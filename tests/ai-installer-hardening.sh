#!/usr/bin/env bash
# shellcheck disable=SC2329
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

assert_safe_archive_rejected() (
  export KARNEL_CACHE="$TEST_ROOT/archive-cache"
  LOG_FILE="$KARNEL_CACHE/test.log"
  mkdir -p "$KARNEL_CACHE" "$TEST_ROOT/archive/source" "$TEST_ROOT/archive/out"
  log_error() { :; }
  source "$ROOT_DIR/karnel/utils/install.sh"

  ln -s ../../escaped "$TEST_ROOT/archive/source/link"
  tar -czf "$TEST_ROOT/archive/unsafe.tar.gz" -C "$TEST_ROOT/archive/source" link
  if extract_tarball "$TEST_ROOT/archive/unsafe.tar.gz" "$TEST_ROOT/archive/out"; then
    printf 'FAIL: unsafe archive link was accepted\n' >&2
    return 1
  fi
  [[ ! -e "$TEST_ROOT/escaped" ]]
)

assert_mimocode_fails_before_mutation() (
  export HOME="$TEST_ROOT/mimo-home"
  export PREFIX="$TEST_ROOT/mimo-prefix"
  export KARNEL_CACHE="$TEST_ROOT/mimo-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$HOME/.mimocode" "$PREFIX/bin" "$KARNEL_CACHE"
  printf 'secret\n' >"$HOME/.mimocode/credentials.json"
  printf 'external\n' >"$PREFIX/bin/mimo"
  import() { :; }
  log_error() { :; }
  log_info() { :; }
  log_warn() { :; }
  loading() { shift; "$@"; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/mimocode/install.sh"

  if _install_mimocode_proot_impl; then return 1; fi
  if uninstall_mimocode; then return 1; fi
  [[ "$(<"$HOME/.mimocode/credentials.json")" == secret ]]
  [[ "$(<"$PREFIX/bin/mimo")" == external ]]
)

assert_mimocode_update_preserves_working_install() (
  export HOME="$TEST_ROOT/mimo-update-home"
  export PREFIX="$TEST_ROOT/mimo-update-prefix"
  export KARNEL_CACHE="$TEST_ROOT/mimo-update-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$HOME/.local/share/karnel-data/mimocode" "$PREFIX/bin" "$KARNEL_CACHE"
  printf 'old binary\n' >"$HOME/.local/share/karnel-data/mimocode/mimocode"
  printf 'karnel-managed-v1\n' >"$HOME/.local/share/karnel-data/mimocode/.karnel-managed"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$PREFIX/bin/mimo"
  chmod +x "$PREFIX/bin/mimo"
  sha256sum "$PREFIX/bin/mimo" >"$HOME/.local/share/karnel-data/mimocode/.karnel-wrapper"
  import() { :; }
  log_error() { :; }
  log_info() { :; }
  loading() { shift; "$@"; }
  pkg() { :; }
  _get_latest_mimocode_version() { printf 'v9.9.9\n'; }
  curl() { return 1; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/mimocode/install.sh"
  _mimocode_install_deps() { :; }
  _get_latest_mimocode_version() { printf 'v9.9.9\n'; }

  if _do_update_mimocode; then return 1; fi
  [[ "$(<"$MIMOCODE_DATA_DIR/mimocode")" == 'old binary' ]]
  [[ -x "$PREFIX/bin/mimo" ]]
)

assert_qoder_proot_prerequisite_failure_stops() (
  export HOME="$TEST_ROOT/qoder-home"
  export PREFIX="$TEST_ROOT/qoder-prefix"
  export KARNEL_CACHE="$TEST_ROOT/qoder-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE"
  import() { :; }
  log_error() { :; }
  loading() { shift; "$@"; }
  uname() { printf 'aarch64\n'; }
  command() {
    if [[ "$1" == -v && "$2" == proot-distro ]]; then return 1; fi
    builtin command "$@"
  }
  pkg() { return 1; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/qoder/install.sh"
  if _install_qoder_proot_impl; then return 1; fi
)

assert_native_activation_rolls_back_new_data() (
  export HOME="$TEST_ROOT/native-home"
  export PREFIX="$TEST_ROOT/native-prefix"
  export KARNEL_CACHE="$TEST_ROOT/native-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE"
  import() { :; }
  log_error() { :; }
  log_success() { :; }
  loading() { shift; "$@"; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/qoder/install.sh"
  _qoder_install_deps_native() { :; }
  _stage_qoder_helper() { QODER_STAGED_WRAPPER="$TEST_ROOT/qoder-staged-wrapper"; : >"$QODER_STAGED_WRAPPER"; }
  _download_qoder_binary() { mkdir -p "$QODER_DATA_DIR"; : >"$QODER_DATA_DIR/$QODER_MARKER"; }
  _activate_qoder_wrapper() { return 1; }
  if _install_qoder_native; then return 1; fi
  [[ ! -e "$QODER_DATA_DIR" ]] || return 1

  source "$ROOT_DIR/karnel/tools/ai/codebuff/install.sh"
  _codebuff_install_deps_native() { :; }
  _stage_codebuff_helper() { CODEBUFF_STAGED_WRAPPER="$TEST_ROOT/codebuff-staged-wrapper"; : >"$CODEBUFF_STAGED_WRAPPER"; }
  _download_codebuff_binary() { mkdir -p "$CODEBUFF_DATA_DIR"; : >"$CODEBUFF_DATA_DIR/$CODEBUFF_MARKER"; }
  _activate_codebuff_wrapper() { return 1; }
  if _install_codebuff_native; then return 1; fi
  [[ ! -e "$CODEBUFF_DATA_DIR" ]]
)

assert_native_preflight_preserves_existing_install() (
  export HOME="$TEST_ROOT/native-preflight-home"
  export PREFIX="$TEST_ROOT/native-preflight-prefix"
  export KARNEL_CACHE="$TEST_ROOT/native-preflight-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$PREFIX/bin" "$KARNEL_CACHE"
  import() { :; }
  log_error() { :; }
  loading() { shift; "$@"; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/qoder/install.sh"
  mkdir -p "$QODER_DATA_DIR"
  printf 'known-good payload\n' >"$QODER_DATA_DIR/qodercli"
  : >"$QODER_DATA_DIR/$QODER_MARKER"
  printf 'external wrapper\n' >"$PREFIX/bin/qodercli"
  _qoder_install_deps_native() { :; }
  if _install_qoder_native; then return 1; fi
  [[ "$(<"$QODER_DATA_DIR/qodercli")" == 'known-good payload' ]] || return 1
  [[ "$(<"$PREFIX/bin/qodercli")" == 'external wrapper' ]] || return 1

  source "$ROOT_DIR/karnel/tools/ai/codebuff/install.sh"
  mkdir -p "$CODEBUFF_DATA_DIR"
  printf 'known-good payload\n' >"$CODEBUFF_DATA_DIR/codebuff"
  : >"$CODEBUFF_DATA_DIR/$CODEBUFF_MARKER"
  printf 'external wrapper\n' >"$PREFIX/bin/codebuff"
  _codebuff_install_deps_native() { :; }
  if _install_codebuff_native; then return 1; fi
  [[ "$(<"$CODEBUFF_DATA_DIR/codebuff")" == 'known-good payload' ]] || return 1
  [[ "$(<"$PREFIX/bin/codebuff")" == 'external wrapper' ]]
)

assert_native_activation_restores_existing_data() (
  export HOME="$TEST_ROOT/native-existing-home"
  export PREFIX="$TEST_ROOT/native-existing-prefix"
  export KARNEL_CACHE="$TEST_ROOT/native-existing-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE"
  import() { :; }
  log_error() { :; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/qoder/install.sh"
  mkdir -p "$QODER_DATA_DIR"
  printf 'old qoder\n' >"$QODER_DATA_DIR/qodercli"
  : >"$QODER_DATA_DIR/$QODER_MARKER"
  printf 'old wrapper\n' >"$PREFIX/bin/qodercli"
  sha256sum "$PREFIX/bin/qodercli" >"$QODER_WRAPPER_MARKER"
  qoder_stage=$(mktemp -d "$(dirname "$QODER_DATA_DIR")/.qoder-test.XXXXXX")
  printf 'new qoder\n' >"$qoder_stage/qodercli"
  _activate_qoder_payload "$qoder_stage"
  _restore_qoder_payload
  [[ "$(<"$QODER_DATA_DIR/qodercli")" == 'old qoder' ]] || return 1
  managed_file_matches "$PREFIX/bin/qodercli" "$QODER_WRAPPER_MARKER" || return 1

  source "$ROOT_DIR/karnel/tools/ai/codebuff/install.sh"
  mkdir -p "$CODEBUFF_DATA_DIR"
  printf 'old codebuff\n' >"$CODEBUFF_DATA_DIR/codebuff"
  : >"$CODEBUFF_DATA_DIR/$CODEBUFF_MARKER"
  printf 'old wrapper\n' >"$PREFIX/bin/codebuff"
  sha256sum "$PREFIX/bin/codebuff" >"$CODEBUFF_WRAPPER_MARKER"
  codebuff_stage=$(mktemp -d "$(dirname "$CODEBUFF_DATA_DIR")/.codebuff-test.XXXXXX")
  printf 'new codebuff\n' >"$codebuff_stage/codebuff"
  _activate_codebuff_payload "$codebuff_stage"
  _restore_codebuff_payload
  [[ "$(<"$CODEBUFF_DATA_DIR/codebuff")" == 'old codebuff' ]]
)

assert_qoder_proot_preserves_unowned_wrapper() (
  export HOME="$TEST_ROOT/qoder-proot-home"
  export PREFIX="$TEST_ROOT/qoder-proot-prefix"
  export KARNEL_CACHE="$TEST_ROOT/qoder-proot-cache"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  export QODER_TEST_UBUNTU_ROOT="$TEST_ROOT/qoder-proot-ubuntu"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE" "$QODER_TEST_UBUNTU_ROOT"
  printf 'external wrapper\n' >"$PREFIX/bin/qodercli"
  import() { :; }
  log_error() { :; }
  uname() { printf 'aarch64\n'; }
  command() {
    if [[ "$1" == -v && "$2" == proot-distro ]]; then return 0; fi
    builtin command "$@"
  }
  _qoder_detect_ubuntu_root() { printf '%s\n' "$QODER_TEST_UBUNTU_ROOT"; }
  _qoder_proot_ubuntu() { :; }
  source "$ROOT_DIR/karnel/utils/install.sh"
  source "$ROOT_DIR/karnel/tools/ai/qoder/install.sh"
  _qoder_detect_ubuntu_root() { printf '%s\n' "$QODER_TEST_UBUNTU_ROOT"; }
  _qoder_proot_ubuntu() { :; }
  if _install_qoder_proot_impl; then return 1; fi
  [[ "$(<"$PREFIX/bin/qodercli")" == 'external wrapper' ]]
)

# npm recreates its shim on every global operation and that shim is dead on
# Android, so "already installed" must still prove the entry starts - a
# swallowed entry failure reported success for a command nobody could run.
assert_freebuff_fails_when_the_entry_is_dead() (
  mkdir -p "$TEST_ROOT/fb-dead/bin"
  printf '#!%s\nexit 1\n' "$(command -v bash)" >"$TEST_ROOT/fb-dead/bin/freebuff"
  chmod +x "$TEST_ROOT/fb-dead/bin/freebuff"
  export PATH="$TEST_ROOT/fb-dead/bin:$PATH"
  import() { :; }
  log_info() { :; }
  log_error() { :; }
  log_success() { :; }
  source "$ROOT_DIR/karnel/tools/ai/freebuff/install.sh"
  _fix_freebuff_runtime() { :; }
  _install_freebuff_entry() { :; }
  local rc=0
  install_freebuff || rc=$?
  [[ $rc -eq 1 ]] || return 1
)

assert_freebuff_accepts_a_live_entry() (
  mkdir -p "$TEST_ROOT/fb-live/bin"
  printf '#!%s\nexit 0\n' "$(command -v bash)" >"$TEST_ROOT/fb-live/bin/freebuff"
  chmod +x "$TEST_ROOT/fb-live/bin/freebuff"
  export PATH="$TEST_ROOT/fb-live/bin:$PATH"
  import() { :; }
  log_info() { :; }
  log_error() { :; }
  log_success() { :; }
  source "$ROOT_DIR/karnel/tools/ai/freebuff/install.sh"
  _fix_freebuff_runtime() { :; }
  _install_freebuff_entry() { :; }
  local rc=0
  install_freebuff || rc=$?
  [[ $rc -eq 2 ]] || return 1
)

assert_source_contracts() {
  local tool file
  for tool in claude-code kimchi-code qoder codebuff mimocode goose codegraph; do
    file="$ROOT_DIR/karnel/tools/ai/$tool/install.sh"
    grep -qF 'extract_tarball' "$file"
  done
  for tool in claude-code kimchi-code qoder codebuff ampcode mimocode goose codegraph crush opencode; do
    file="$ROOT_DIR/karnel/tools/ai/$tool/install.sh"
    grep -Eq 'SHA-256|sha256|integrity|verify_github_release_asset|github_download_and_extract' "$file"
  done
  grep -qF 'upstream does not publish a verifiable checksum' "$ROOT_DIR/karnel/tools/ai/cursor-cli/install.sh"
  grep -qF 'MiMo Code Proot installation is unavailable' "$ROOT_DIR/karnel/tools/ai/mimocode/install.sh"
  ! grep -qF 'rm -rf /root/.claude' "$ROOT_DIR/karnel/tools/ai/claude-code/install.sh"
  ! grep -qF 'rm -rf /root/.mimocode' "$ROOT_DIR/karnel/tools/ai/mimocode/install.sh"
  if grep -qF "[kimchi-code]='" "$ROOT_DIR/karnel/tools/ai/all.sh"; then return 1; fi
  grep -qF "[goose]='goose --version'" "$ROOT_DIR/karnel/tools/ai/all.sh"
}

assert_safe_archive_rejected
assert_mimocode_fails_before_mutation
assert_mimocode_update_preserves_working_install
assert_qoder_proot_prerequisite_failure_stops
assert_native_activation_rolls_back_new_data
assert_native_activation_restores_existing_data
assert_native_preflight_preserves_existing_install
assert_qoder_proot_preserves_unowned_wrapper
assert_source_contracts
assert_freebuff_fails_when_the_entry_is_dead
assert_freebuff_accepts_a_live_entry
printf 'AI installer hardening contracts: 11 passed\n'
