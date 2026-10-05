#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
SYSTEM_RM=$(command -v rm)
SYSTEM_CHMOD=$(command -v chmod)
SYSTEM_GREP=$(command -v grep)
SYSTEM_HEAD=$(command -v head)
SYSTEM_SED=$(command -v sed)

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

assert_keelcode_lifecycle() (
  export PREFIX="$TEST_ROOT/prefix"
  export KARNEL_CACHE="$TEST_ROOT/cache"
  export KARNEL_DATA="$TEST_ROOT/data"
  mkdir -p "$KARNEL_CACHE" "$TEST_ROOT/prefix/bin"
  export PATH="$TEST_ROOT/prefix/bin"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  log_error() { :; }
  tail() { :; }
  head() { "$SYSTEM_HEAD" "$@"; }
  sed() { "$SYSTEM_SED" "$@"; }
  grep() { "$SYSTEM_GREP" "$@"; }
  rm() { "$SYSTEM_RM" "$@"; }
  npm() {
    case "$1" in
    install) printf '#!/usr/bin/env bash\n# Karnel KeelCode Termux wrapper\nexit 0\n' >"$TEST_ROOT/prefix/bin/keelcode"; "$SYSTEM_CHMOD" +x "$TEST_ROOT/prefix/bin/keelcode" ;;
    uninstall) "$SYSTEM_RM" -f "$TEST_ROOT/prefix/bin/keelcode" ;;
    update) : ;;
    esac
  }
  # shellcheck source=../karnel/utils/npm-shebang.sh
  source "$ROOT_DIR/karnel/utils/npm-shebang.sh"
  # shellcheck source=../karnel/tools/ai/keelcode/install.sh
  source "$ROOT_DIR/karnel/tools/ai/keelcode/install.sh"
  _keelcode_install_termux_wrapper() { :; }

  # Every step must gate the next one: without `|| return 1` a failed install
  # still ends the test on `! command -v keelcode` (which then succeeds) and
  # reports a false pass.
  install_keelcode || return 1
  command -v keelcode >/dev/null || return 1
  uninstall_keelcode || return 1
  ! command -v keelcode || return 1
  return 0
)
run_test "KeelCode lifecycle" assert_keelcode_lifecycle

assert_banner_bash_startup() (
  export HOME="$TEST_ROOT/banner-home"
  export PREFIX="$TEST_ROOT/banner-prefix"
  export KARNEL_CACHE="$TEST_ROOT/banner-cache"
  export KARNEL_UTILS="$ROOT_DIR/karnel/utils"
  mkdir -p "$HOME" "$PREFIX/etc" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_warn() { :; }
  log_error() { :; }
  loading() { "$2"; }
  source "$ROOT_DIR/karnel/utils/uninstall.sh"
  # shellcheck source=../karnel/tools/ui/banner/install.sh
  source "$ROOT_DIR/karnel/tools/ui/banner/install.sh"
  _backup_motd() { :; }

  : >"$HOME/.bashrc"
  install_banner
  grep -qF 'render_banner' "$HOME/.bashrc"
  grep -qF 'elif [[ $- == *i* && -z "${KARNEL_BANNER_SESSION_SHOWN:-}" ]]; then' "$HOME/.bashrc"
  grep -qF "$KARNEL_BANNER_END_MARKER" "$HOME/.bashrc"
  uninstall_banner
  ! grep -qF "$KARNEL_BANNER_MARKER" "$HOME/.bashrc"
)
run_test "banner Bash startup" assert_banner_bash_startup

assert_superfile_staged_build() (
  export KARNEL_DATA="$TEST_ROOT/data"
  export KARNEL_CACHE="$TEST_ROOT/cache"
  export PREFIX="$TEST_ROOT/prefix"
  mkdir -p "$KARNEL_CACHE" "$PREFIX/bin"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  git() {
    if [[ "$1" == "-C" ]]; then
      printf '%s\n' 'fe41cef5e9ee5b16e79981540c49f932a3d4d249'
      return
    fi
    local destination="${!#}"
    [[ "$1" == "clone" && "$4" == "--branch" && "$5" == "v1.5.0" ]] || return 1
    mkdir -p "$destination"
  }
  go() {
    local previous="" arg output=""
    for arg in "$@"; do
      if [[ "$previous" == "-o" ]]; then
        output="$arg"
        break
      fi
      previous="$arg"
    done
    printf '#!/usr/bin/env bash\nexit 0\n' >"$output"
    chmod +x "$output"
  }
  pkg() { return 1; }
  # shellcheck source=../karnel/tools/utils/superfile/install.sh
  source "$ROOT_DIR/karnel/tools/utils/superfile/install.sh"

  install_superfile
  [[ -x "$PREFIX/bin/spf" ]]
  [[ -d "$KARNEL_DATA/superfile/.git" || -d "$KARNEL_DATA/superfile" ]]
  update_superfile
  [[ -x "$PREFIX/bin/spf" ]]
  [[ ! -d "$KARNEL_DATA/.superfile.previous.$$" ]]
  uninstall_superfile
  [[ ! -e "$PREFIX/bin/spf" && ! -d "$KARNEL_DATA/superfile" ]]
)
run_test "SuperFile staged build" assert_superfile_staged_build

assert_downloaded_utils_keep_source_payloads() (
  export PREFIX="$TEST_ROOT/downloaded-utils-prefix"
  export KARNEL_CACHE="$TEST_ROOT/downloaded-utils-cache"
  export KARNEL_DATA="$TEST_ROOT/downloaded-utils-data"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  pkg() { :; }
  command() {
    if [[ "$1" == "-v" ]]; then
      case "$2" in
        applaunch|filecheck|fconv|notes|passman|qrcode|splash|treex|websites) return 1 ;;
      esac
    fi
    builtin command "$@"
  }
  curl() {
    local output="" arg previous=""
    for arg in "$@"; do
      [[ "$previous" == "-o" ]] && output="$arg"
      previous="$arg"
    done
    printf '#!/usr/bin/env python3\nprint("runtime payload")\n' >"$output"
  }
  source "$ROOT_DIR/karnel/utils/downloaded-python.sh"

  local tool function_name source_payload source_checksum runtime_payload
  for tool in applaunch filecheck fconv notes passman qrcode splash treex websites; do
    source_payload="$ROOT_DIR/karnel/tools/utils/$tool/$tool.py"
    source_checksum=$(cksum "$source_payload")
    runtime_payload="$KARNEL_DATA/utils/$tool/$tool.py"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/karnel/tools/utils/$tool/install.sh"
    [[ "$tool" != qrcode ]] || _qrcode_dependencies() { :; }
    function_name="install_${tool//-/_}"
    "$function_name"
    [[ -L "$PREFIX/bin/$tool" ]]
    [[ "$(readlink "$PREFIX/bin/$tool")" == "$runtime_payload" ]]
    [[ -f "$runtime_payload" ]]
    [[ "$(<"$runtime_payload")" == "#!$(command -v python3)"$'\n'* ]]
    function_name="update_${tool//-/_}"
    "$function_name"
    [[ "$(<"$runtime_payload")" == "#!$(command -v python3)"$'\n'* ]]
    [[ "$source_checksum" == "$(cksum "$source_payload")" ]]
    function_name="uninstall_${tool//-/_}"
    "$function_name"
    [[ ! -e "$PREFIX/bin/$tool" && ! -e "$KARNEL_DATA/utils/$tool" ]]
    [[ "$source_checksum" == "$(cksum "$source_payload")" ]]
  done
)
run_test "downloaded utilities preserve source payloads" assert_downloaded_utils_keep_source_payloads

assert_omni_route_preserves_unowned_wrappers() (
  export HOME="$TEST_ROOT/omni-route-home"
  export PREFIX="$TEST_ROOT/omni-route-prefix"
  export KARNEL_CACHE="$TEST_ROOT/omni-route-cache"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$HOME/.karnel/packages/karnelroute/node_modules/karnelroute/bin" "$PREFIX/bin" "$KARNEL_CACHE"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$PREFIX/bin/omni-route"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$PREFIX/bin/karnelroute"
  chmod +x "$PREFIX/bin/omni-route" "$PREFIX/bin/karnelroute"
  printf '#!/usr/bin/env node\n' >"$HOME/.karnel/packages/karnelroute/node_modules/karnelroute/bin/karnelroute.mjs"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_warn() { :; }
  log_error() { :; }
  npm() { return 1; }
  # shellcheck source=../karnel/tools/ai/omni-route/install.sh
  source "$ROOT_DIR/karnel/tools/ai/omni-route/install.sh"

  if install_omni_route; then
    return 1
  fi
  grep -qF 'exit 1' "$PREFIX/bin/omni-route"
  grep -qF 'exit 1' "$PREFIX/bin/karnelroute"
  rm -f "$PREFIX/bin/omni-route" "$PREFIX/bin/karnelroute"
  _omni_route_install_wrapper omni-route
  _omni_route_install_wrapper karnelroute
  uninstall_omni_route
  [[ ! -e "$PREFIX/bin/omni-route" && ! -e "$PREFIX/bin/karnelroute" ]]
)
run_test "omniRoute preserves unowned wrappers" assert_omni_route_preserves_unowned_wrappers

assert_turbopack_stages_and_preserves_unowned_wrappers() (
	  export HOME="$TEST_ROOT/turbopack-home"
  export PREFIX="$TEST_ROOT/turbopack-prefix"
  export KARNEL_CACHE="$TEST_ROOT/turbopack-cache"
  export KARNEL_DATA="$TEST_ROOT/turbopack-data"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  log_warn() { :; }
  loading() { shift; "$@"; }
  read_confirm_default() { REINSTALL=y; }
  # This installer is ARM64-only by design, but the CI runner is x86_64;
  # report the architecture the contract is written for (same stub the other
  # arch-gated installer tests already use).
  uname() { printf 'aarch64\n'; }
  # shellcheck source=../karnel/tools/npm/turbopack/install.sh
  source "$ROOT_DIR/karnel/tools/npm/turbopack/install.sh"
  _install_deps() { :; }
  _download() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$1/bin/node"
    chmod +x "$1/bin/node"
  }
  _strip() { cp "$1/bin/node" "$1/bin/node.stripped"; }
  _patch() { mv "$1/bin/node.stripped" "$1/bin/node"; }

  install_turbopack
  [[ -f "$TURBO_DATA_DIR/.karnel-managed" ]]
  [[ -f "$TURBO_DATA_DIR/.karnel-wrapper-node-glibc" ]]
  [[ -x "$PREFIX/bin/node-glibc" && -x "$PREFIX/bin/next-turbopack" ]]
  printf '#!/usr/bin/env bash\nexit 1\n' >"$PREFIX/bin/node-glibc"
  uninstall_turbopack
  [[ -e "$PREFIX/bin/node-glibc" ]]
  [[ ! -e "$PREFIX/bin/next-turbopack" && ! -e "$TURBO_DATA_DIR" ]]
)
run_test "Turbopack preserves unowned wrappers" assert_turbopack_stages_and_preserves_unowned_wrappers

assert_kilocode_ownership_and_staging() (
  export HOME="$TEST_ROOT/kilocode-home"
  export PREFIX="$TEST_ROOT/kilocode-prefix"
  export KARNEL_CACHE="$TEST_ROOT/kilocode-cache"
  export KARNEL_DATA="$TEST_ROOT/kilocode-data"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_warn() { :; }
  log_error() { :; }
  loading() { shift; "$@"; }
  curl() { : >"${@: -1}"; }
  verify_github_release_asset() { return 0; }
  # safe_extract_tar probes with `tar -tf` and `tar -tvf` before extracting;
  # a stub that only handles the extract form breaks the listing and aborts.
  tar() {
    case "$1" in
      -tf) printf 'kilo\n' ;;
      -tvf) printf 'rwxr-xr-x user/group 1024 2024-01-01 00:00 kilo\n' ;;
      *) printf '#!/usr/bin/env bash\nexit 0\n' >"$4/kilo" ;;
    esac
  }
  cc() { local output="${3}"; printf '#!/usr/bin/env bash\nexit 0\n' >"$output"; }
  # shellcheck source=../karnel/tools/ai/kilocode-cli/install.sh
  source "$ROOT_DIR/karnel/tools/ai/kilocode-cli/install.sh"
  _install_kilocode_deps() { :; }
  _get_latest_kilocode_version() { printf 'v1.0.0\n'; }

  install_kilocode_cli
  [[ -x "$KILOCODE_DATA_DIR/kilo" && -f "$KILOCODE_DATA_DIR/.karnel-managed" ]]
  [[ -f "$KILOCODE_DATA_DIR/.karnel-wrapper-kilocode" && -L "$PREFIX/bin/kilo" ]]
  uninstall_kilocode_cli
  [[ ! -e "$KILOCODE_DATA_DIR" && ! -e "$PREFIX/bin/kilocode" && ! -e "$PREFIX/bin/kilo" ]]

  mkdir -p "$KILOCODE_DATA_DIR"
  : >"$KILOCODE_DATA_DIR/kilo"
  if install_kilocode_cli; then return 1; fi
  [[ -f "$KILOCODE_DATA_DIR/kilo" ]]
  printf 'unowned\n' >"$PREFIX/bin/kilocode"
  printf 'unowned\n' >"$PREFIX/bin/kilo"
  # Unowned data must make uninstall refuse (rc 1) and leave everything alone.
  ! uninstall_kilocode_cli
  [[ -f "$PREFIX/bin/kilocode" && -f "$PREFIX/bin/kilo" && -d "$KILOCODE_DATA_DIR" ]]
)
run_test "Kilo Code ownership and staging" assert_kilocode_ownership_and_staging

assert_odysseus_ownership() (
  export HOME="$TEST_ROOT/odysseus-home"
  export PREFIX="$TEST_ROOT/odysseus-prefix"
  export KARNEL_CACHE="$TEST_ROOT/odysseus-cache"
  export PATH="$PREFIX/bin:$PATH"
  export ODYSSEUS_TEST_UBUNTU_ROOT="$TEST_ROOT/odysseus-ubuntu"
  local ubuntu_root="$ODYSSEUS_TEST_UBUNTU_ROOT"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE" "$ubuntu_root/root/odysseus"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_warn() { :; }
  log_error() { :; }
  loading() { shift; "$@"; }
  # shellcheck source=../karnel/tools/ai/odysseus/install.sh
  source "$ROOT_DIR/karnel/tools/ai/odysseus/install.sh"
  _odysseus_detect_ubuntu_root() { printf '%s\n' "$ODYSSEUS_TEST_UBUNTU_ROOT"; }
  _odysseus_dependencies() { return 1; }

  if install_odysseus; then return 1; fi
  [[ -d "$ubuntu_root/root/odysseus" ]]
  : >"$ubuntu_root/root/odysseus/.karnel-managed"
  mkdir -p "$ODYSSEUS_DATA_DIR"
  printf 'managed\n' >"$PREFIX/bin/odysseus"
  sha256sum "$PREFIX/bin/odysseus" >"$ODYSSEUS_DATA_DIR/.karnel-wrapper-odysseus"
  : >"$ODYSSEUS_DATA_DIR/.karnel-managed"
  uninstall_odysseus
  [[ ! -e "$PREFIX/bin/odysseus" && ! -e "$ODYSSEUS_DATA_DIR" && ! -e "$ubuntu_root/root/odysseus" ]]

  mkdir -p "$ODYSSEUS_DATA_DIR" "$ubuntu_root/root/odysseus"
  printf 'unowned\n' >"$PREFIX/bin/odysseus"
  # Unowned data must make uninstall refuse (rc 1) and leave everything alone.
  ! uninstall_odysseus
  [[ -f "$PREFIX/bin/odysseus" && -d "$ODYSSEUS_DATA_DIR" && -d "$ubuntu_root/root/odysseus" ]]
)
run_test "Odysseus ownership" assert_odysseus_ownership

assert_voice_termux_api_marker_lifecycle() (
  export HOME="$TEST_ROOT/voice-home"
  export PREFIX="$TEST_ROOT/voice-prefix"
  export KARNEL_CACHE="$TEST_ROOT/voice-cache"
  export KARNEL_DATA="$TEST_ROOT/voice-data"
  mkdir -p "$HOME" "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_warn() { :; }
  log_error() { :; }
  loading() { shift; "$@"; }
  pkg() { return 0; }
  source "$ROOT_DIR/karnel/modules/voice.sh"
  _install_voice_deps
  [[ -f "$VOICE_MARKER" ]] || return 1
  source "$ROOT_DIR/karnel/tools/voice/uninstall.sh"
  command() {
    if [[ "$1" == -v && "$2" == termux-api ]]; then return 0; fi
    builtin command "$@"
  }
  _uninstall_voice_tool
  [[ ! -e "$VOICE_MARKER" ]] || return 1

  reinstall_calls=()
  _uninstall_voice_wrapper() { reinstall_calls+=(uninstall); }
  _install_voice_deps() { reinstall_calls+=(dependencies); }
  _install_voice_shell() { reinstall_calls+=(shell); }
  _reinstall_voice_wrapper
  [[ "${reinstall_calls[*]}" == "uninstall dependencies shell" ]]
)
run_test "voice Termux:API marker lifecycle" assert_voice_termux_api_marker_lifecycle

assert_downloaded_games_and_network_installers() (
  export PREFIX="$TEST_ROOT/downloaded-python-prefix"
  export KARNEL_CACHE="$TEST_ROOT/downloaded-python-cache"
  export KARNEL_DATA="$TEST_ROOT/downloaded-python-data"
  export KARNEL_PATH="$ROOT_DIR/karnel"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  pkg() { :; }
  curl_failure=0
  curl() {
    local output="" previous="" arg
    (( curl_failure == 0 )) || return 1
    for arg in "$@"; do
      [[ "$previous" == "-o" ]] && output="$arg"
      previous="$arg"
    done
    printf '#!/usr/bin/env python3\nprint("runtime payload")\n' >"$output"
  }
  # shellcheck source=../karnel/utils/downloaded-python.sh
  source "$ROOT_DIR/karnel/utils/downloaded-python.sh"

  local tool installer install_function update_function uninstall_function runtime_payload source_payload
  local -a specs=(
    'buzz:karnel/tools/games/buzz/install.sh'
    'arcade:karnel/tools/games/arcade/install.sh'
    'ctfgod:karnel/tools/games/ctfgod/install.sh'
    'detective:karnel/tools/games/detective/install.sh'
    'pet-friends:karnel/tools/games/pet-friends/install.sh'
    'tamagotchi:karnel/tools/games/tamagotchi/install.sh'
    'dark:karnel/tools/network/dark/install.sh'
    'dedsec-network:karnel/tools/network/dedsec-network/install.sh'
  )
  local spec
  for spec in "${specs[@]}"; do
    tool=${spec%%:*}
    installer=${spec#*:}
    install_function="install_${tool//-/_}"
    update_function="update_${tool//-/_}"
    uninstall_function="uninstall_${tool//-/_}"
    runtime_payload="$KARNEL_DATA/${installer#karnel/tools/}"
    runtime_payload="${runtime_payload%/install.sh}/$tool.py"
    source_payload="$KARNEL_PATH/tools/${installer#karnel/tools/}"
    source_payload="${source_payload%/install.sh}/$tool.py"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/$installer"

    printf 'external wrapper\n' >"$PREFIX/bin/$tool"
    if "$install_function"; then return 1; fi
    grep -qF 'external wrapper' "$PREFIX/bin/$tool"
    rm -f "$PREFIX/bin/$tool"

    "$install_function"
    [[ -L "$PREFIX/bin/$tool" && "$(readlink "$PREFIX/bin/$tool")" == "$runtime_payload" ]]
    [[ -f "$runtime_payload" && ! -e "$source_payload" ]]
    local payload_before
    payload_before=$(<"$runtime_payload")
    curl_failure=1
    if "$update_function"; then return 1; fi
    [[ "$payload_before" == "$(<"$runtime_payload")" ]]
    curl_failure=0
    "$uninstall_function"
    [[ ! -e "$PREFIX/bin/$tool" && ! -e "${runtime_payload%/*}" ]]

    "$install_function"
    rm -f "$PREFIX/bin/$tool"
    printf 'external wrapper\n' >"$PREFIX/bin/$tool"
    "$uninstall_function" || [[ $? -eq 2 ]]
    [[ -f "$PREFIX/bin/$tool" && -f "$runtime_payload" ]]
    rm -rf "$PREFIX/bin/$tool" "${runtime_payload%/*}"
  done
)
run_test "downloaded games and network installers" assert_downloaded_games_and_network_installers

printf 'Tool installer contracts: %d passed, %d failed\n' "$pass" "$failed"
(( failed == 0 ))
