#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export PREFIX="$TEST_ROOT/prefix"
export KARNEL_CACHE="$TEST_ROOT/cache"
export HOME="$TEST_ROOT/home"
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
log_warn() { :; }
log_error() { :; }
loading() { shift; "$@"; }
command() {
  if [[ "$1" == "-v" && "$2" == "railway" ]]; then
    return 1
  fi
  builtin command "$@"
}
npm() { return 1; }
pkg() { :; }
proot-distro() { return 0; }
curl() {
  if [[ "$*" == *"releases/latest"* ]]; then
    printf '%s\n' '"tag_name": "v1.0.0"'
    return 0
  fi
  return 1
}

# shellcheck source=../karnel/tools/deploy/railway/install.sh
source "$ROOT_DIR/karnel/tools/deploy/railway/install.sh"

if ! install_railway; then
  printf 'FAIL: Railway did not fall back to Ubuntu Proot\n' >&2
  exit 1
fi
grep -qF '# Karnel Railway PRoot wrapper' "$PREFIX/bin/railway" || {
  printf 'FAIL: Railway Proot wrapper was not created\n' >&2
  exit 1
}

source "$ROOT_DIR/karnel/utils/install.sh"
source "$ROOT_DIR/karnel/tools/deploy/vercel/install.sh"
source "$ROOT_DIR/karnel/tools/deploy/netlify/install.sh"

printf '#!/usr/bin/env bash\n' >"$PREFIX/bin/vercel"
printf '#!/usr/bin/env bash\n' >"$PREFIX/bin/netlify"
chmod +x "$PREFIX/bin/vercel" "$PREFIX/bin/netlify"
mkdir -p "$(dirname "$VERCEL_MARKER")"
: >"$VERCEL_MARKER"
: >"$NETLIFY_MARKER"

if uninstall_vercel; then
  printf 'FAIL: Vercel uninstall accepted an existence-only marker\n' >&2
  exit 1
fi
if uninstall_netlify; then
  printf 'FAIL: Netlify uninstall accepted an existence-only marker\n' >&2
  exit 1
fi
[[ -x "$PREFIX/bin/vercel" && -x "$PREFIX/bin/netlify" ]] || {
  printf 'FAIL: unowned deploy CLIs were removed\n' >&2
  exit 1
}

record_managed_file "$PREFIX/bin/vercel" "$VERCEL_MARKER"
record_managed_file "$PREFIX/bin/netlify" "$NETLIFY_MARKER"
npm() { [[ "$1" == uninstall ]] || return 1; }
uninstall_vercel
uninstall_netlify
[[ ! -e "$VERCEL_MARKER" && ! -e "$NETLIFY_MARKER" ]] || {
  printf 'FAIL: deploy ownership markers were not removed after uninstall\n' >&2
  exit 1
}

printf 'Deploy installer contracts: passed\n'
