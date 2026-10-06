#!/usr/bin/env bash
# shellcheck disable=SC2031  # compat.sh is sourced inside setup_compat_env's subshell
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
SYSTEM_HEAD=$(command -v head)

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
  if ((errexit_was_on)); then set -e; fi
  if ((rc == 0)); then
    ((pass += 1))
    printf 'ok - %s\n' "$name"
  else
    ((failed += 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

# Fabricates a Termux-shaped prefix and a glibc sysroot so the layer can be
# exercised without a real glibc. The ELF predicates are then overridden to
# classify the fixtures by file name, which keeps the test portable across
# bionic (Termux) and glibc (CI) hosts; detection itself is covered separately
# by assert_detection_matches_readelf.
setup_compat_env() {
  local bash_bin suffix
  bash_bin="$(command -v bash)"
  # Every assertion runs in its own subshell, so BASHPID keeps one test's
  # wrappers and .karnel-real files out of the next test's fixture set.
  suffix="${BASHPID:-$$}"
  export PREFIX="$TEST_ROOT/prefix-$suffix"
  export KARNEL_GLIBC_ROOT="$TEST_ROOT/sysroot-$suffix"
  export PATH="$PREFIX/bin:$PATH"
  mkdir -p "$PREFIX/bin" "$KARNEL_GLIBC_ROOT/lib"

  {
    printf '%s\n' "#!$bash_bin"
    printf '%s\n' "# fake glibc loader: --library-path <path> <binary> [args...]"
    # shellcheck disable=SC2016  # \$1 must expand when the fake loader runs
    printf '%s\n' '[[ "${1:-}" == "--library-path" ]] && shift 2'
    printf '%s\n' 'exec "$@"'
  } >"$KARNEL_GLIBC_ROOT/lib/ld-linux-aarch64.so.1"
  chmod +x "$KARNEL_GLIBC_ROOT/lib/ld-linux-aarch64.so.1"
  : >"$KARNEL_GLIBC_ROOT/lib/libc.so.6"

  # shellcheck source=../karnel/utils/compat.sh
  source "$ROOT_DIR/karnel/utils/compat.sh"
  log_info() { :; }
  log_error() { :; }
  log_warn() { :; }

  compat_is_elf() { [[ "$(basename -- "$1")" == *fake-elf ]]; }
  compat_is_glibc_elf() { [[ "$(basename -- "$1")" == *glibc-fake-elf ]]; }

  # A "glibc ELF" that is really an executable shell script, so the generated
  # wrapper can be run and observed end to end. It resolves bash itself: this
  # helper is called from scopes that do not see setup_compat_env's locals.
  make_glibc_tool() {
    local path="$1"
    {
      printf '%s\n' "#!$(command -v bash)"
      printf '%s\n' 'printf "ran:%s\n" "$*"'
    } >"$path"
    chmod +x "$path"
  }
}

assert_classify() (
  setup_compat_env
  make_glibc_tool "$PREFIX/bin/alpha.glibc-fake-elf"
  make_glibc_tool "$PREFIX/bin/beta.native-fake-elf"
  printf '%s\n' '#!/bin/sh' 'echo hi' >"$PREFIX/bin/gamma.sh"
  printf '%s\n' 'plain text' >"$PREFIX/bin/delta.txt"

  [[ "$(compat_classify "$PREFIX/bin/alpha.glibc-fake-elf")" == "glibc" ]]
  [[ "$(compat_classify "$PREFIX/bin/beta.native-fake-elf")" == "native" ]]
  [[ "$(compat_classify "$PREFIX/bin/gamma.sh")" == "script" ]]
  [[ "$(compat_classify "$PREFIX/bin/delta.txt")" == "unknown" ]]
  [[ "$(compat_classify "$PREFIX/bin/nope")" == "missing" ]]
)

assert_loader_is_found_in_the_sysroot() (
  setup_compat_env
  compat_glibc_ready
  [[ "$(compat_glibc_loader)" == "$KARNEL_GLIBC_ROOT/lib/ld-linux-aarch64.so.1" ]]
)

assert_wrap_runs_and_is_reversible() (
  setup_compat_env
  local tool="$PREFIX/bin/alpha.glibc-fake-elf"
  make_glibc_tool "$tool"

  compat_wrap "$tool"
  [[ -f "$tool" ]]
  [[ -f "$tool.karnel-real" ]]
  head -n 2 "$tool" | grep -qF "$COMPAT_WRAPPER_MARKER"

  # The wrapper really executes the binary through the loader.
  local out
  out="$("$tool" one two)"
  [[ "$out" == "ran:one two" ]]

  compat_unwrap "$tool"
  [[ ! -f "$tool.karnel-real" ]]
  [[ -f "$tool" ]]
  ! head -n 2 "$tool" | grep -qF "$COMPAT_WRAPPER_MARKER"
)

assert_wrap_is_idempotent() (
  setup_compat_env
  local tool="$PREFIX/bin/alpha.glibc-fake-elf"
  make_glibc_tool "$tool"

  compat_wrap "$tool"
  local first
  first="$("$SYSTEM_HEAD" -n 20 "$tool")"
  # A second wrap must not stack another layer or move the real binary again.
  compat_wrap "$tool"
  [[ "$(head -n 20 "$tool")" == "$first" ]]
  [[ -f "$tool.karnel-real" ]]
  [[ ! -f "$tool.karnel-real.karnel-real" ]]
)

assert_adapt_only_touches_glibc() (
  setup_compat_env
  local glibc_tool="$PREFIX/bin/alpha.glibc-fake-elf"
  local native_tool="$PREFIX/bin/beta.native-fake-elf"
  local script="$PREFIX/bin/gamma"
  make_glibc_tool "$glibc_tool"
  make_glibc_tool "$native_tool"
  printf '%s\n' '#!/bin/sh' 'echo hi' >"$script"
  chmod +x "$script"

  compat_adapt_installed "alpha.glibc-fake-elf"
  compat_adapt_installed "beta.native-fake-elf"
  compat_adapt_installed "gamma"

  head -n 2 "$glibc_tool" | grep -qF "$COMPAT_WRAPPER_MARKER"
  [[ -f "$glibc_tool.karnel-real" ]]
  if head -n 2 "$native_tool" | grep -qF "$COMPAT_WRAPPER_MARKER"; then
    printf '%s\n' "native binary must not be wrapped" >&2
    return 1
  fi
  [[ ! -e "$native_tool.karnel-real" ]]
  if head -n 2 "$script" | grep -qF "$COMPAT_WRAPPER_MARKER"; then
    printf '%s\n' "plain script must not be wrapped" >&2
    return 1
  fi
  # Adapting something that is not on PATH is a no-op, never a failure.
  compat_adapt_installed "definitely-not-installed"
)

assert_describe_names_a_wrapper() (
  setup_compat_env
  local tool="$PREFIX/bin/alpha.glibc-fake-elf"
  make_glibc_tool "$tool"
  [[ "$(compat_describe "$tool")" == "glibc" ]]
  compat_wrap "$tool"
  [[ "$(compat_describe "$tool")" == "glibc (wrapped, runs through the glibc loader)" ]]
  [[ "$(compat_describe "$PREFIX/bin/missing")" == "missing" ]]
)

assert_fix_shebang_rewrites_env_interpreter() (
  setup_compat_env
  local bash_bin target
  bash_bin="$(command -v bash)"
  target="$TEST_ROOT/tool-entry"
  # Android has no /usr/bin/env, so this shebang cannot run here.
  printf '%s\n' '#!/usr/bin/env bash' 'echo hi' >"$target"
  chmod +x "$target"

  compat_fix_shebang "$target"
  [[ "$(head -n 1 "$target")" == "#!$bash_bin" ]]
  # 2 = already runnable, and the file must not be rewritten twice.
  local rc=0
  compat_fix_shebang "$target" || rc=$?
  [[ "$rc" -eq 2 ]]
  [[ "$(head -n 1 "$target")" == "#!$bash_bin" ]]
)

assert_fix_shebang_keeps_interpreter_arguments() (
  setup_compat_env
  local bash_bin target
  bash_bin="$(command -v bash)"
  target="$TEST_ROOT/tool-entry-args"
  printf '%s\n' '#!/usr/bin/env bash -e' 'echo hi' >"$target"
  chmod +x "$target"

  compat_fix_shebang "$target"
  [[ "$(head -n 1 "$target")" == "#!$bash_bin -e" ]]
)

assert_fix_shebang_gives_up_on_unknown_interpreters() (
  setup_compat_env
  local target rc=0
  target="$TEST_ROOT/tool-entry-unknown"
  printf '%s\n' '#!/nonexistent/interp-xyz' 'echo hi' >"$target"
  chmod +x "$target"

  compat_fix_shebang "$target" || rc=$?
  [[ "$rc" -eq 1 ]]
  [[ "$(head -n 1 "$target")" == '#!/nonexistent/interp-xyz' ]]
)

assert_fix_shebangs_counts_only_changes() (
  setup_compat_env
  local dir="$TEST_ROOT/shebangs-${BASHPID:-$$}"
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' 'echo a' >"$dir/a.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo b' >"$dir/b.sh"
  printf '%s\n' 'not a script' >"$dir/c.txt"
  chmod +x "$dir/a.sh" "$dir/b.sh"

  local fixed
  fixed="$(compat_fix_shebangs "$dir")"
  [[ "$fixed" == "2" ]]
  # A second pass changes nothing.
  [[ "$(compat_fix_shebangs "$dir")" == "0" ]]
)

assert_detection_matches_readelf() (
  setup_compat_env
  command -v cc >/dev/null 2>&1 || return 0
  command -v readelf >/dev/null 2>&1 || return 0

  # Undo the fixture stubs: this case checks the real ELF classifier.
  unset -f compat_is_elf compat_is_glibc_elf
  # shellcheck source=../karnel/utils/compat.sh
  source "$ROOT_DIR/karnel/utils/compat.sh"

  local src="$TEST_ROOT/probe.c" bin="$TEST_ROOT/probe" needed
  printf '%s\n' 'int main(void){return 0;}' >"$src"
  if ! cc -o "$bin" "$src" >/dev/null 2>&1; then
    return 0
  fi
  [[ -f "$bin" ]] || return 0
  needed="$(readelf -d "$bin" 2>/dev/null | grep -o 'libc\.so[^]]*' | head -n 1)"
  case "$needed" in
  libc.so.6)
    compat_is_glibc_elf "$bin"
    ;;
  libc.so)
    ! compat_is_glibc_elf "$bin"
    ;;
  *)
    # Neither linkage (static build): it must not be treated as glibc.
    ! compat_is_glibc_elf "$bin"
    ;;
  esac
)

# $PREFIX/bin/npm is a symlink into node_modules; repairing it must edit the
# target's shebang, not replace the link with a detached copy.
assert_fix_shebang_edits_the_target_of_a_symlink() (
  setup_compat_env
  local dir="$PREFIX/pkg/bin" link
  mkdir -p "$dir"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "ran-ok\n"' >"$dir/tool.js"
  chmod +x "$dir/tool.js"
  link="$PREFIX/bin/tool"
  ln -s "../pkg/bin/tool.js" "$link"

  compat_fix_shebang "$link"
  [[ -L "$link" ]]
  [[ "$(readlink "$link")" == "../pkg/bin/tool.js" ]]
  head -n 1 "$dir/tool.js" | grep -qF "#!$(command -v bash)"
  [[ "$("$link")" == "ran-ok" ]]
  # Already runnable now: a second pass must report 2 and change nothing.
  local rc=0
  compat_fix_shebang "$link" || rc=$?
  [[ "$rc" -eq 2 ]]
  [[ -L "$link" ]]
  head -n 1 "$dir/tool.js" | grep -qF "#!$(command -v bash)"
)

# The fake sysroot ships a helper that only exists in its bin/ directory, so a
# tier-2 wrapper cannot run the tool but a tier-3 one can.
assert_escalates_to_the_glibc_userland() (
  setup_compat_env
  local tool="$PREFIX/bin/deploy.glibc-fake-elf"
  make_glibc_tool "$tool"
  {
    printf '%s\n' "#!$(command -v bash)"
    printf '%s\n' 'glibconly "$@"'
  } >"$tool"
  chmod +x "$tool"
  mkdir -p "$KARNEL_GLIBC_ROOT/bin"
  {
    printf '%s\n' "#!$(command -v bash)"
    printf '%s\n' 'printf "userland-ok\n"'
  } >"$KARNEL_GLIBC_ROOT/bin/glibconly"
  chmod +x "$KARNEL_GLIBC_ROOT/bin/glibconly"

  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_LOADER" ]]
  if compat_probe "$tool"; then
    printf '%s\n' "tier 2 should not have run the tool" >&2
    return 1
  fi

  compat_adapt "$tool"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_USERLAND" ]]
  [[ -f "$tool.karnel-real" ]]
  compat_probe "$tool"
)

# Nothing works at any tier: the wrapper must drop back to the plain loader
# and adaptation must still report success.
assert_falls_back_to_the_loader_when_no_tier_helps() (
  setup_compat_env
  local tool="$PREFIX/bin/hopeless.glibc-fake-elf"
  make_glibc_tool "$tool"
  {
    printf '%s\n' "#!$(command -v bash)"
    printf '%s\n' 'definitely-not-installed-anywhere "$@"'
  } >"$tool"
  chmod +x "$tool"

  compat_adapt "$tool"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_LOADER" ]]
  [[ -f "$tool.karnel-real" ]]
)

# Re-tiering must only rewrite the launcher; the parked original stays put.
assert_retiering_keeps_the_parked_original() (
  setup_compat_env
  local tool="$PREFIX/bin/retier.glibc-fake-elf" first
  make_glibc_tool "$tool"

  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  [[ -f "$tool.karnel-real" ]]
  first="$(cksum <"$tool.karnel-real")"

  compat_wrap "$tool" "$COMPAT_TIER_USERLAND"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_USERLAND" ]]
  [[ -f "$tool.karnel-real" ]]
  [[ "$first" == "$(cksum <"$tool.karnel-real")" ]]
  # Back again.
  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_LOADER" ]]
  [[ "$first" == "$(cksum <"$tool.karnel-real")" ]]
)

# The synthetic FHS root is assembled once out of the installed sysroot.
assert_proot_root_is_built_once() (
  setup_compat_env
  local root rc=0
  export KARNEL_DATA="$TEST_ROOT/kdata"
  root="$(compat_proot_root)" || rc=$?
  [[ "$rc" -eq 0 ]]
  [[ -d "$root/lib" && -d "$root/usr/lib" && -d "$root/usr/share" && -d "$root/etc" ]]
  [[ -f "$root/.ready" ]]
  [[ "$(compat_proot_root)" == "$root" ]]
)

# A tier-4 wrapper must never be written without a usable root behind it:
# `proot -r ''` fails on every invocation and looks like a broken tool.
assert_proot_tier_is_refused_without_a_root() (
  setup_compat_env
  local out="$TEST_ROOT/no-root.sh" rc=0
  unset KARNEL_DATA KARNEL_COMPAT_ROOT
  _compat_write_wrapper "$out" /somewhere/tool /some/ld.so "$COMPAT_TIER_PROOT" || rc=$?
  [[ "$rc" -ne 0 ]]
  [[ ! -e "$out" ]]
)

run_test "escalates a loader-only wrapper to the glibc userland" assert_escalates_to_the_glibc_userland
run_test "adaptation falls back to the loader when no tier helps" assert_falls_back_to_the_loader_when_no_tier_helps
run_test "re-tiering keeps the parked original byte-identical" assert_retiering_keeps_the_parked_original
run_test "the synthetic proot root is built once and reused" assert_proot_root_is_built_once
run_test "the proot tier is refused when no root can be built" assert_proot_tier_is_refused_without_a_root
run_test "fix_shebang repairs a symlinked entry without replacing the link" assert_fix_shebang_edits_the_target_of_a_symlink
run_test "classify separates glibc, native, script, unknown and missing" assert_classify
run_test "the glibc loader is resolved from the sysroot" assert_loader_is_found_in_the_sysroot
run_test "wrap runs the binary through the loader and unwraps cleanly" assert_wrap_runs_and_is_reversible
run_test "wrap is idempotent and never stacks wrappers" assert_wrap_is_idempotent
run_test "adapt only rewrites glibc binaries on PATH" assert_adapt_only_touches_glibc
run_test "describe names a wrapped binary" assert_describe_names_a_wrapper
run_test "fix_shebang rewrites an unrunnable /usr/bin/env interpreter" assert_fix_shebang_rewrites_env_interpreter
run_test "fix_shebang keeps interpreter arguments" assert_fix_shebang_keeps_interpreter_arguments
run_test "fix_shebang leaves unknown interpreters alone" assert_fix_shebang_gives_up_on_unknown_interpreters
run_test "fix_shebangs counts changed files, not inspected ones" assert_fix_shebangs_counts_only_changes
run_test "glibc detection agrees with readelf" assert_detection_matches_readelf

printf '1..%d\n' "$pass"
if ((failed > 0)); then
  printf 'Android compatibility: %d passed, %d failed\n' "$pass" "$failed" >&2
  exit 1
fi
printf 'Android compatibility: %d passed, %d failed\n' "$pass" "$failed"
