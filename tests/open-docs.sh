#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

KARNEL_PATH="$ROOT_DIR/karnel"

import() { :; }
log_error() { :; }
log_warn() { :; }
log_info() { :; }
log_success() { :; }
box() { :; }
separator_section() { :; }
D_CYAN= D_GREEN= D_DIM= NC=
# shellcheck source=../karnel/cli/commands/open.sh
source "$ROOT_DIR/karnel/cli/commands/open.sh"

opened=""
termux-open-url() { opened="$1"; }

open_main cleanup
[[ "$opened" == "https://karneltermux.vercel.app/karnel/cleanup" ]] ||
  fail "cleanup opened '$opened'"

open_main supabase
[[ "$opened" == "https://karneltermux.vercel.app/karnel/supabase" ]] ||
  fail "supabase opened '$opened'"

open_main karnel
[[ "$opened" == "https://karneltermux.vercel.app/" ]] ||
  fail "overview opened '$opened'"

for target in doctor brain pg init env backup cleanup osint security plugin voice; do
  open_main "$target"
  [[ "$opened" == "https://karneltermux.vercel.app/karnel/$target" ]] ||
    fail "$target opened '$opened'"
done

open_main termux
[[ "$opened" == "https://karneltermux.vercel.app/termux" ]] ||
  fail "termux opened '$opened'"

# Alias routes still resolve to the page the docs link to.
open_main robin
[[ "$opened" == "https://karneltermux.vercel.app/karnel/osint" ]] ||
  fail "robin opened '$opened'"

open_main herdr
[[ "$opened" == "https://karneltermux.vercel.app/karnel/utils" ]] ||
  fail "herdr opened '$opened'"

if open_main definitely-not-a-route >/dev/null 2>&1; then
  fail "unknown target should fail"
fi

printf 'Open documentation routes: 19 passed\n'
