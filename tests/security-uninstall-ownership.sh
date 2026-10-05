#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

log_info() { :; }
log_success() { :; }
log_error() { :; }

assert_unowned_binary_is_preserved() (
  local tool="$1" installer="$2" uninstall_function="$3"
  export PREFIX="$TEST_ROOT/$tool-prefix"
  mkdir -p "$PREFIX/bin"
  printf '#!/usr/bin/env bash\nexit 99\n' > "$PREFIX/bin/$tool"
  chmod +x "$PREFIX/bin/$tool"
  # shellcheck source=/dev/null
  source "$ROOT_DIR/$installer"
  "$uninstall_function"
  grep -qF 'exit 99' "$PREFIX/bin/$tool"
)

assert_unowned_binary_is_preserved sqlmap karnel/tools/security/sqlmap/install.sh uninstall_sqlmap
assert_unowned_binary_is_preserved amass karnel/tools/security/amass/install.sh uninstall_amass
assert_unowned_binary_is_preserved burpsuite karnel/tools/security/burpsuite/install.sh uninstall_burpsuite
assert_unowned_binary_is_preserved enum4linux karnel/tools/security/enum4linux/install.sh uninstall_enum4linux
assert_unowned_binary_is_preserved ffuf karnel/tools/security/ffuf/install.sh uninstall_ffuf
assert_unowned_binary_is_preserved gobuster karnel/tools/security/gobuster/install.sh uninstall_gobuster
assert_unowned_binary_is_preserved msfconsole karnel/tools/security/metasploit/install.sh uninstall_metasploit
assert_unowned_binary_is_preserved nikto karnel/tools/security/nikto/install.sh uninstall_nikto
assert_unowned_binary_is_preserved subfinder karnel/tools/security/subfinder/install.sh uninstall_subfinder
assert_unowned_binary_is_preserved theharvester karnel/tools/security/theharvester/install.sh uninstall_theharvester
assert_unowned_binary_is_preserved whatweb karnel/tools/security/whatweb/install.sh uninstall_whatweb
assert_unowned_binary_is_preserved zap karnel/tools/security/zap/install.sh uninstall_zap
assert_unowned_binary_is_preserved dnsrecon karnel/tools/security/dnsrecon/install.sh uninstall_dnsrecon
assert_unowned_binary_is_preserved masscan karnel/tools/security/masscan/install.sh uninstall_masscan

assert_checksum_marker_ownership() (
  export PREFIX="$TEST_ROOT/marker-prefix"
  mkdir -p "$PREFIX/bin" "$PREFIX/share/karnel-installers"
  printf 'karnel binary\n' > "$PREFIX/bin/amass"
  sha256sum "$PREFIX/bin/amass" > "$PREFIX/share/karnel-installers/amass"
  # shellcheck source=../karnel/tools/security/amass/install.sh
  source "$ROOT_DIR/karnel/tools/security/amass/install.sh"
  uninstall_amass
  [[ ! -e "$PREFIX/bin/amass" ]]

  printf 'karnel binary\n' > "$PREFIX/bin/amass"
  sha256sum "$PREFIX/bin/amass" > "$PREFIX/share/karnel-installers/amass"
  printf 'user replacement\n' > "$PREFIX/bin/amass"
  uninstall_amass
  grep -qF 'user replacement' "$PREFIX/bin/amass"
)
assert_checksum_marker_ownership

assert_package_backend_uninstalls() (
  local tool="$1" installer="$2" uninstall_function="$3" marker="$4" package="$5"
  export PREFIX="$TEST_ROOT/${tool}-package-prefix"
  mkdir -p "$PREFIX/bin" "$(dirname "$marker")"
  printf 'pkg:%s\n' "$package" >"$marker"
  package_removed=0
  pkg() {
    [[ "$1" == uninstall && "$2" == -y && "$3" == "$package" ]] && package_removed=1
  }
  apt() { return 1; }
  # shellcheck source=/dev/null
  source "$ROOT_DIR/$installer"
  "$uninstall_function"
  [[ $package_removed -eq 1 && ! -e "$marker" ]]
)

assert_package_backend_uninstalls amass karnel/tools/security/amass/install.sh uninstall_amass "$TEST_ROOT/amass-package-prefix/share/karnel-installers/amass" amass
assert_package_backend_uninstalls subfinder karnel/tools/security/subfinder/install.sh uninstall_subfinder "$TEST_ROOT/subfinder-package-prefix/share/karnel-installers/subfinder" subfinder
assert_package_backend_uninstalls ffuf karnel/tools/security/ffuf/install.sh uninstall_ffuf "$TEST_ROOT/ffuf-package-prefix/share/karnel-installers/ffuf" ffuf
assert_package_backend_uninstalls gobuster karnel/tools/security/gobuster/install.sh uninstall_gobuster "$TEST_ROOT/gobuster-package-prefix/share/karnel-installers/gobuster" gobuster
assert_package_backend_uninstalls zap karnel/tools/security/zap/install.sh uninstall_zap "$TEST_ROOT/zap-package-prefix/share/karnel-installers/zaproxy" zaproxy
assert_package_backend_uninstalls burpsuite karnel/tools/security/burpsuite/install.sh uninstall_burpsuite "$TEST_ROOT/burpsuite-package-prefix/share/karnel-installers/burpsuite" burpsuite

assert_cursor_and_railway_ownership() (
  export HOME="$TEST_ROOT/owned-home"
  export PREFIX="$TEST_ROOT/owned-prefix"
  export KARNEL_CACHE="$TEST_ROOT/cache"
  export KARNEL_DATA="$HOME/.local/share/karnel-data"
  local railway_data="$KARNEL_DATA/deploy/railway"
  mkdir -p "$KARNEL_DATA/cursor" "$railway_data" "$PREFIX/bin" "$KARNEL_CACHE"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_warn() { :; }

  printf 'external cursor\n' >"$PREFIX/bin/cursor"
  printf 'external cursor-agent\n' >"$PREFIX/bin/cursor-agent"
  printf 'external data\n' >"$KARNEL_DATA/cursor/data"
  source "$ROOT_DIR/karnel/tools/ai/cursor-cli/install.sh"
  uninstall_cursor_cli || [[ $? -eq 2 || $? -eq 1 ]]
  [[ -f "$PREFIX/bin/cursor" && -f "$PREFIX/bin/cursor-agent" ]]
  [[ -f "$KARNEL_DATA/cursor/data" ]]

  rm -rf "$PREFIX/bin" "$KARNEL_DATA/cursor"
  mkdir -p "$PREFIX/bin" "$KARNEL_DATA/cursor"
  printf 'payload\n' >"$KARNEL_DATA/cursor/data"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$KARNEL_DATA/cursor/node"
  chmod +x "$KARNEL_DATA/cursor/node"
  _cursor_write_data_metadata
  _create_cursor_wrapper
  uninstall_cursor_cli
  [[ ! -e "$PREFIX/bin/cursor" && ! -e "$PREFIX/bin/cursor-agent" ]]
  [[ ! -e "$KARNEL_DATA/cursor" ]]

  printf 'external railway\n' >"$PREFIX/bin/railway"
  printf 'external data\n' >"$railway_data/data"
  npm() { return 99; }
  source "$ROOT_DIR/karnel/tools/deploy/railway/install.sh"
  uninstall_railway
  [[ -f "$PREFIX/bin/railway" && -f "$railway_data/data" ]]

  rm -rf "$PREFIX/bin" "$railway_data"
  mkdir -p "$PREFIX/bin" "$railway_data"
  printf 'karnel railway\n' >"$PREFIX/bin/railway"
  printf 'payload\n' >"$railway_data/data"
  _railway_mark_install
  npm() { [[ "$1" == uninstall ]]; rm -f "$PREFIX/bin/railway"; }
  uninstall_railway
  [[ ! -e "$PREFIX/bin/railway" && ! -e "$railway_data" ]]
)
assert_cursor_and_railway_ownership

printf 'Security uninstaller ownership: 22 passed\n'
