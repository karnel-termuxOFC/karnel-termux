#!/usr/bin/env bash
# shellcheck disable=SC2031  # compat.sh is sourced inside setup_compat_env's subshell
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
SYSTEM_HEAD=$(command -v head)
# The host's real prefix. setup_compat_env swaps PREFIX for a sandbox, and the
# preload test needs a library the running linker actually accepts.
HOST_PREFIX="${PREFIX:-}"

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
  # The snapshot helpers mktemp into TMPDIR; keep that inside the sandbox so a
  # test can never leave a snapshot behind in the system temp directory.
  export TMPDIR="$TEST_ROOT/tmp-$suffix"
  mkdir -p "$PREFIX/bin" "$KARNEL_GLIBC_ROOT/lib" "$TMPDIR"

  {
    printf '%s\n' "#!$bash_bin"
    printf '%s\n' "# fake glibc loader: --library-path <path> <binary> [args...]"
    printf '%s\n' "# Refuse any preload: a wrapper that lets one through is a wrapper that"
    printf '%s\n' "# dies on a real Termux host, where login(1) exports the bionic shim."
    # shellcheck disable=SC2016  # emitted verbatim, expanded by the loader
    printf '%s\n' 'if [[ -n "${LD_PRELOAD:-}" ]]; then'
    # shellcheck disable=SC2016  # emitted verbatim, expanded by the loader
    printf '%s\n' '  printf "leaked LD_PRELOAD: %s\n" "$LD_PRELOAD" >&2'
    # shellcheck disable=SC2016  # emitted verbatim, expanded by the loader
    printf '%s\n' '  exit 127'
    printf '%s\n' 'fi'
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
  # A shebang whose env path does not exist cannot run on any host - the
  # test must not depend on the runner happening to have no /usr/bin/env.
  printf '%s\n' '#!/nonexistent/env bash' 'echo hi' >"$target"
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
  printf '%s\n' '#!/nonexistent/env bash -e' 'echo hi' >"$target"
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
  printf '%s\n' '#!/nonexistent/env bash' 'echo a' >"$dir/a.sh"
  printf '%s\n' '#!/nonexistent/env bash' 'echo b' >"$dir/b.sh"
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
  printf '%s\n' '#!/nonexistent/env bash' 'printf "ran-ok\n"' >"$dir/tool.js"
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

# Every installer reaches the layer through compat_adapt_installed (tools.sh,
# ai/all.sh and install.sh), not through freebuff's compat_adapt call, so the
# ladder has to climb there too or tiers 3 and 4 would exist only for freebuff.
assert_adapt_installed_climbs_the_ladder() (
  setup_compat_env
  local tool="$PREFIX/bin/installed.glibc-fake-elf"
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

  compat_adapt_installed "installed.glibc-fake-elf"
  [[ -f "$tool.karnel-real" ]]
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_USERLAND" ]]
  compat_probe "$tool"
)

# A wrapper already on disk must be re-probed: a tool that stops starting at
# its current tier climbs on the next install or update instead of staying
# broken behind a launcher nobody re-examines.
assert_existing_wrapper_is_reevaluated() (
  setup_compat_env
  local tool="$PREFIX/bin/reeval.glibc-fake-elf"
  make_glibc_tool "$tool"
  compat_adapt_installed "reeval.glibc-fake-elf"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_LOADER" ]]

  # The binary behind the wrapper now needs the glibc userland on PATH.
  {
    printf '%s\n' "#!$(command -v bash)"
    printf '%s\n' 'glibconly "$@"'
  } >"$tool.karnel-real"
  mkdir -p "$KARNEL_GLIBC_ROOT/bin"
  {
    printf '%s\n' "#!$(command -v bash)"
    printf '%s\n' 'printf "userland-ok\n"'
  } >"$KARNEL_GLIBC_ROOT/bin/glibconly"
  chmod +x "$KARNEL_GLIBC_ROOT/bin/glibconly"

  compat_adapt_installed "reeval.glibc-fake-elf"
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_USERLAND" ]]
  compat_probe "$tool"
)

# Climbing the ladder must stay free for everything that already runs. A
# Termux prefix carries hundreds of native binaries; probing each with
# --version on every install would cost more than the layer saves. The second
# half is a positive control so the zero above cannot pass vacuously.
assert_adapt_installed_never_probes_native_tools() (
  setup_compat_env
  local probes=0 glibc_tool="$PREFIX/bin/lean.glibc-fake-elf"
  compat_probe() { probes=$((probes + 1)); return 0; }

  make_glibc_tool "$PREFIX/bin/lean-native-fake-elf"
  printf '%s\n' '#!/bin/sh' 'echo hi' >"$PREFIX/bin/lean.sh"
  printf '%s\n' 'plain text' >"$PREFIX/bin/lean.txt"

  compat_adapt_installed "lean-native-fake-elf"
  compat_adapt_installed "lean.sh"
  compat_adapt_installed "lean.txt"
  compat_adapt_installed "no-such-tool"
  if [[ "$probes" -ne 0 ]]; then
    printf 'native entries were probed %d time(s)\n' "$probes" >&2
    return 1
  fi

  make_glibc_tool "$glibc_tool"
  compat_adapt_installed "lean.glibc-fake-elf"
  if [[ "$probes" -ne 1 ]]; then
    printf 'expected exactly one probe for the wrapped tool, saw %d\n' "$probes" >&2
    return 1
  fi
  [[ "$(compat_wrapper_tier "$glibc_tool")" == "$COMPAT_TIER_LOADER" ]]
)

# login(1) exports LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so. A
# bionic bash loads that happily, but the glibc loader cannot, and answers
# with "error while loading shared libraries: .../libc.so: invalid ELF
# header" - which is what made freebuff fail its runtime probe during
# install. Tier 3 must not answer by preloading the glibc shim instead:
# every bionic child it spawns then fails with "library libc.so.6 not found".
assert_wrapper_never_hands_a_preload_to_the_loader() (
  setup_compat_env
  local tool="$PREFIX/bin/preload.glibc-fake-elf" out tier preload="" cand
  make_glibc_tool "$tool"

  # Pick a preload the running linker accepts, so the assertion exercises the
  # wrapper instead of dying in bash before it is ever reached. Android's
  # linker treats a missing object as fatal, glibc only warns.
  for cand in "$HOST_PREFIX/lib/libtermux-exec-ld-preload.so" "/nonexistent-karnel-preload.so"; do
    [[ -n "$cand" ]] || continue
    if LD_PRELOAD="$cand" bash -c 'exit 0' 2>/dev/null; then
      preload="$cand"
      break
    fi
  done
  if [[ -z "$preload" ]]; then
    printf '%s\n' "no preload this host will tolerate" >&2
    return 1
  fi

  for tier in "$COMPAT_TIER_LOADER" "$COMPAT_TIER_USERLAND"; do
    compat_wrap "$tool" "$tier"
    out="$(LD_PRELOAD="$preload" "$tool" one two)"
    if [[ "$out" != "ran:one two" ]]; then
      printf 'tier %s handed the preload to the loader: %s\n' "$tier" "$out" >&2
      return 1
    fi
    if ! grep -qF 'unset LD_PRELOAD' "$tool"; then
      printf 'tier %s does not clear the preload\n' "$tier" >&2
      return 1
    fi
    if grep -qF 'export LD_PRELOAD' "$tool"; then
      printf 'tier %s exports a preload of its own\n' "$tier" >&2
      return 1
    fi
  done
)

# Installs made by an older karnel still carry a launcher without the preload
# guard. Adapting must rewrite that launcher in place and leave the parked
# original alone, or every already-wrapped tool stays broken forever.
assert_stale_wrapper_is_refreshed() (
  setup_compat_env
  local tool="$PREFIX/bin/stale.glibc-fake-elf"
  make_glibc_tool "$tool"
  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  sed -i '/unset LD_PRELOAD/d' -- "$tool"
  if compat_wrapper_is_current "$tool"; then
    printf '%s\n' "the stripped launcher still claims to be current" >&2
    return 1
  fi

  compat_adapt_installed "stale.glibc-fake-elf"
  compat_wrapper_is_current "$tool" || {
    printf '%s\n' "a stale launcher was not refreshed" >&2
    return 1
  }
  [[ "$(compat_wrapper_tier "$tool")" == "$COMPAT_TIER_LOADER" ]]
  [[ -f "$tool.karnel-real" ]]
  [[ "$("$tool" one)" == "ran:one" ]]
)

# freebuff's node entry re-extracts its runtime in place, which drops a fresh
# ELF over the wrapper and orphans the parked copy. Adaptation must recover
# from that; refusing leaves the tool permanently unrunnable, because every
# later install hits the same refusal.
assert_orphaned_parked_copy_is_replaced() (
  setup_compat_env
  local tool="$PREFIX/bin/orphan.glibc-fake-elf" old
  make_glibc_tool "$tool"
  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  [[ -f "$tool.karnel-real" ]] || return 1

  # Re-extracted identical bytes: the parked copy is redundant, and a 130 MB
  # runtime must not be duplicated just to keep it.
  make_glibc_tool "$tool"
  compat_adapt "$tool"
  compat_wrapper_is_current "$tool" || {
    printf '%s\n' "an identical orphan blocked adaptation" >&2
    return 1
  }
  [[ -f "$tool.karnel-real" && ! -e "$tool.karnel-real.stale" ]]
  [[ "$("$tool" one)" == "ran:one" ]]

  # A genuinely different orphan is worth keeping beside the new copy.
  compat_unwrap "$tool"
  printf '%s\n' '# a runtime karnel never saw' >>"$tool"
  old="$(cksum <"$tool")"
  compat_wrap "$tool" "$COMPAT_TIER_LOADER"
  make_glibc_tool "$tool"
  compat_adapt "$tool"
  compat_wrapper_is_current "$tool" || {
    printf '%s\n' "a different orphan blocked adaptation" >&2
    return 1
  }
  [[ -f "$tool.karnel-real.stale" ]]
  [[ "$(cksum <"$tool.karnel-real.stale")" == "$old" ]]
  [[ "$("$tool" one)" == "ran:one" ]]
)

# The dispatcher brackets every installing command with a PATH snapshot, so a
# binary that appears during the command is adapted even though the installer
# itself never mentions the compatibility layer.
assert_snapshot_adapts_a_new_binary() (
  setup_compat_env
  local snap
  snap="$(compat_path_snapshot)" || return 1
  make_glibc_tool "$PREFIX/bin/fresh.glibc-fake-elf"

  compat_adapt_since "$snap"
  compat_wrapper_is_current "$PREFIX/bin/fresh.glibc-fake-elf" || {
    printf '%s\n' "a binary created during the command was not adapted" >&2
    return 1
  }
  [[ ! -e "$snap" ]]
  [[ "$("$PREFIX/bin/fresh.glibc-fake-elf" one)" == "ran:one" ]]
)

# An installer that replaces a file in place keeps the path but changes the
# size and mtime, which the snapshot records as a new line.
assert_snapshot_adapts_a_rewritten_binary() (
  setup_compat_env
  local tool="$PREFIX/bin/rewrite.glibc-fake-elf" snap
  make_glibc_tool "$tool"
  snap="$(compat_path_snapshot)" || return 1
  printf '%s\n' "#!$(command -v bash)" 'printf "ran2:%s\n" "$*"' >"$tool"
  chmod +x "$tool"

  compat_adapt_since "$snap"
  compat_wrapper_is_current "$tool" || {
    printf '%s\n' "a rewritten binary was not adapted" >&2
    return 1
  }
  [[ "$("$tool" one)" == "ran2:one" ]]
)

# Efficiency: files the command did not touch are never looked at, and a
# native binary or a script that did appear is not wrapped either.
assert_snapshot_touches_only_what_changed() (
  setup_compat_env
  local tool="$PREFIX/bin/keep.glibc-fake-elf" snap
  make_glibc_tool "$tool"
  snap="$(compat_path_snapshot)" || return 1
  make_glibc_tool "$PREFIX/bin/native.native-fake-elf"
  printf '%s\n' '#!/bin/sh' 'echo hi' >"$PREFIX/bin/fresh.sh"
  chmod +x "$PREFIX/bin/fresh.sh"

  compat_adapt_since "$snap"
  [[ ! -e "$tool.karnel-real" ]] || {
    printf '%s\n' "an untouched binary was wrapped" >&2
    return 1
  }
  [[ ! -e "$PREFIX/bin/native.native-fake-elf.karnel-real" ]]
  [[ ! -e "$PREFIX/bin/fresh.sh.karnel-real" ]]
)

# Adaptation runs after the command's own exit code is known, so it must never
# be able to change that code: a missing snapshot, or a directory that
# disappeared while the command ran, still returns 0.
assert_adapt_since_never_fails_a_command() (
  setup_compat_env
  local snap
  compat_adapt_since "$TEST_ROOT/does-not-exist" || return 1
  snap="$(compat_path_snapshot)" || return 1
  rm -rf -- "${PREFIX:?}/bin"
  compat_adapt_since "$snap" || return 1
  return 0
)

# Guards the wiring itself: if a future edit stops bracketing commands, or
# drops the import that makes the helpers exist, these fail.
assert_the_dispatcher_brackets_installing_commands() {
  local file="$ROOT_DIR/karnel/cli/karnel.sh" list cmd
  grep -q 'import "@/utils/compat"' "$file" || {
    printf '%s\n' "karnel.sh does not import the compatibility layer" >&2
    return 1
  }
  grep -q 'compat_path_snapshot' "$file" || {
    printf '%s\n' "the dispatcher no longer snapshots PATH" >&2
    return 1
  }
  grep -q 'compat_adapt_since' "$file" || {
    printf '%s\n' "the dispatcher no longer adapts what changed" >&2
    return 1
  }
  list="$(grep -E '^\s*install \| update \| upgrade \| reinstall \|' "$file" | head -1)"
  [[ -n "$list" ]] || {
    printf '%s\n' "no bracket list found in the dispatcher" >&2
    return 1
  }
  for cmd in install update upgrade reinstall restore plugin supabase deploy voice robin; do
    [[ " $list " == *" $cmd "* ]] || {
      printf '%s\n' "$cmd is not bracketed by a PATH snapshot" >&2
      return 1
    }
  done

  # The AI reinstall fallback installs through _install_fn and returns without
  # passing through _run_ai_tool_action, so it has to adapt itself.
  local ai="$ROOT_DIR/karnel/tools/ai/all.sh"
  # shellcheck disable=SC2016  # the literal $id is what we are looking for
  grep -q '_ai_tool_compat_adapt "\$id"' "$ai" || {
    printf '%s\n' "the AI reinstall fallback does not adapt what it installed" >&2
    return 1
  }
  local after_fallback
  # shellcheck disable=SC2016  # matches the literal call, not its expansion
  after_fallback="$(grep -n '"$install_fn"' "$ai" | tail -1 | cut -d: -f1)"
  [[ -n "$after_fallback" ]] || {
    printf '%s\n' "the AI reinstall fallback no longer calls \$install_fn" >&2
    return 1
  }
  awk -v start="$after_fallback" '
    NR > start && /_ai_tool_compat_adapt "\$id"/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ai" || {
    printf '%s\n' "the AI fallback installs without adapting afterwards" >&2
    return 1
  }
  return 0
}

run_test "escalates a loader-only wrapper to the glibc userland" assert_escalates_to_the_glibc_userland
run_test "adapt_installed climbs the ladder on the installer path" assert_adapt_installed_climbs_the_ladder
run_test "an existing wrapper is re-evaluated on the next install" assert_existing_wrapper_is_reevaluated
run_test "adapt_installed never probes native, script or text entries" assert_adapt_installed_never_probes_native_tools
run_test "no wrapper hands a preload to the glibc loader" assert_wrapper_never_hands_a_preload_to_the_loader
run_test "a launcher from an older karnel is refreshed in place" assert_stale_wrapper_is_refreshed
run_test "an orphaned parked copy does not block adaptation" assert_orphaned_parked_copy_is_replaced
run_test "a binary created during a command is adapted afterwards" assert_snapshot_adapts_a_new_binary
run_test "a binary rewritten in place is adapted afterwards" assert_snapshot_adapts_a_rewritten_binary
run_test "only the entries a command actually changed are adapted" assert_snapshot_touches_only_what_changed
run_test "adaptation can never change a command's exit code" assert_adapt_since_never_fails_a_command
run_test "the dispatcher brackets every installing command" assert_the_dispatcher_brackets_installing_commands
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
run_test "fix_shebang rewrites an unrunnable env interpreter" assert_fix_shebang_rewrites_env_interpreter
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
