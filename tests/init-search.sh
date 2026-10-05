#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export KARNEL_CACHE="$TEST_ROOT/cache"
mkdir -p "$KARNEL_CACHE"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local needle="$1" file="$2"
  grep -Fq -- "$needle" "$file" || fail "missing '$needle' in $file"
}

assert_search_is_literal() (
  export KARNEL_PATH="$TEST_ROOT/karnel"
  export KARNEL_DATA="$TEST_ROOT/data"
  mkdir -p "$KARNEL_PATH/tools" "$KARNEL_DATA/brain"
  printf '# bracket [ memory\n' >"$KARNEL_DATA/brain/test.md"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  box() { :; }
  separator_section() { :; }
  list_item() { printf '%s\n' "$*"; }
  log_info() { :; }
  D_CYAN= NC=
  # shellcheck source=../karnel/cli/commands/search.sh
  source "$ROOT_DIR/karnel/cli/commands/search.sh"

  output=$(search_main '[')
  [[ "$output" == *test.md* ]] || fail "literal search did not find '['"
)

assert_init_cancelled_before_writes() (
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_warn() { :; }
  read_confirm() { printf -v "$2" '%s' 'n'; }
  # shellcheck source=../karnel/cli/commands/init.sh
  source "$ROOT_DIR/karnel/cli/commands/init.sh"
  configure_react() { fail "init configured after cancellation"; }

  init_main react
)

assert_go_uses_module_name() (
  local project="$TEST_ROOT/go-project"
  mkdir -p "$project"
  cd "$project"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_error() { :; }
  log_success() { :; }
  log_info() { :; }
  separator() { :; }
  box() { :; }
  read_select() {
    if [[ "$1" == *framework* ]]; then
      printf -v "$2" '%s' 'Gin'
    else
      printf -v "$2" '%s' 'None'
    fi
  }
  go() {
    if [[ "${1:-}" == mod && "${2:-}" == init ]]; then
      printf 'module myapi\n' >go.mod
    fi
  }
  # shellcheck source=../karnel/cli/commands/init.sh
  source "$ROOT_DIR/karnel/cli/commands/init.sh"

  configure_go >/dev/null
  assert_contains '"myapi/internal/config"' cmd/api/main.go
  assert_contains '"myapi/internal/handlers"' cmd/api/main.go
)

assert_rust_docker_uses_package_name() (
  local project="$TEST_ROOT/rust-project"
  mkdir -p "$project"
  cd "$project"
  # Load the real npm helper so the wrapper under test actually exists;
  # a no-op import leaves karnel_npm undefined and hides install failures.
  import() {
    if [[ "${1:-}" == "@/utils/npm" ]]; then
      # shellcheck source=../karnel/utils/npm.sh
      source "$ROOT_DIR/karnel/utils/npm.sh"
    fi
  }
  log_error() { :; }
  log_success() { :; }
  log_info() { :; }
  separator() { :; }
  box() { :; }
  read_select() {
    if [[ "$1" == *framework* ]]; then
      printf -v "$2" '%s' 'Axum'
    else
      printf -v "$2" '%s' 'None'
    fi
  }
  cargo() {
    if [[ "${1:-}" == init ]]; then
      printf '[package]\nname = "myapi"\nversion = "0.1.0"\n' >Cargo.toml
    fi
  }
  # shellcheck source=../karnel/cli/commands/init.sh
  source "$ROOT_DIR/karnel/cli/commands/init.sh"

  configure_rust >/dev/null
  assert_contains 'target/release/myapi' Dockerfile
  assert_contains 'CMD ["./myapi"]' Dockerfile
)

assert_search_is_literal
assert_init_cancelled_before_writes
assert_go_uses_module_name
assert_rust_docker_uses_package_name
assert_contains 'clsx tailwind-merge' "$ROOT_DIR/karnel/cli/commands/init.sh"
assert_contains 'rejectUnauthorized: true' "$ROOT_DIR/karnel/cli/commands/init.sh"
if grep -Fq '@/components/ui/button' "$ROOT_DIR/karnel/cli/commands/init.sh" || \
  grep -Fq 'project/internal/' "$ROOT_DIR/karnel/cli/commands/init.sh" || \
  grep -Fq 'ExampleEntity1' "$ROOT_DIR/karnel/cli/commands/init.sh"; then
  fail "init template retains an unresolved generated reference"
fi
printf 'Init and search contracts: 10 passed\n'
