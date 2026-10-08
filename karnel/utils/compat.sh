#!/usr/bin/env bash

# Android <-> glibc compatibility layer.
#
# Termux runs bionic, has no /usr and cannot start a stock Linux ELF: the
# PT_INTERP recorded in the binary (/lib/ld-linux-aarch64.so.1) does not
# exist, execve() answers ENOENT and the shell reports 127. The glibc-repo
# package ships a full aarch64 glibc under $PREFIX/glibc whose loader is an
# ordinary executable, so the very same binary starts natively when it is
# handed to that loader instead of to the kernel:
#
#   ld-linux-aarch64.so.1 --library-path <sysroot>/lib:<dir of binary> <binary> [args]
#
# That form is preferred over `patchelf --set-interpreter`: patchelf grows Bun
# standalone builds by a PT_LOAD segment and they then SIGSEGV, while the
# loader form leaves the file byte-identical, needs no re-patching on upgrade
# and is reversible. Everything below is idempotent so installers can call it
# after install, after update and from doctor without bookkeeping.
#
# A bare loader is not always enough, so a wrapper can be escalated through
# three tiers and the cheapest one that actually starts the binary wins:
#
#   2  loader        hand the ELF to the glibc loader. No userland, no
#                    proot, no download. Covers most standalone binaries.
#   3  glibc userland  same, plus $PREFIX/glibc/bin (383 glibc tools) in
#                    PATH and the glibc termux-exec preload so that child
#                    processes the tool spawns resolve the same way.
#   4  proot         a synthetic FHS root assembled from the sysroot that
#                    is already installed, bound at /lib, /usr and /etc.
#                    This is what a tool needs when it hardcodes
#                    /usr/share or /etc/... -- and unlike
#                    `proot-distro install ubuntu` it downloads nothing.
#
# compat_adapt probes after wrapping and climbs the ladder; every step is
# reversible through compat_unwrap.

# Marker written on line 2 of every generated wrapper, tier on line 3.
COMPAT_WRAPPER_MARKER="# karnel-compat-wrapper"
COMPAT_WRAPPER_TIER_MARKER="# karnel-compat-tier:"
COMPAT_TIER_LOADER=2
COMPAT_TIER_USERLAND=3
COMPAT_TIER_PROOT=4

compat_glibc_root() { printf '%s\n' "${KARNEL_GLIBC_ROOT:-$PREFIX/glibc}"; }

compat_glibc_libdir() { printf '%s\n' "$(compat_glibc_root)/lib"; }

compat_glibc_bindir() { printf '%s\n' "$(compat_glibc_root)/bin"; }

# Prints the path of a usable glibc dynamic loader, if one is installed.
compat_glibc_loader() {
  local libdir candidate
  libdir="$(compat_glibc_libdir)"
  [[ -d "$libdir" ]] || return 1
  for candidate in "$libdir"/ld-*.so*; do
    [[ -f "$candidate" && -x "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

compat_glibc_ready() {
  compat_glibc_loader >/dev/null || return 1
  [[ -e "$(compat_glibc_libdir)/libc.so.6" ]]
}

# Installs the glibc sysroot on demand. Safe to call repeatedly.
compat_glibc_ensure() {
  compat_glibc_ready && return 0
  if ! command -v pkg >/dev/null 2>&1; then
    log_error "pkg is required to install the glibc compatibility layer"
    return 1
  fi
  if [[ ! -f "$PREFIX/etc/apt/sources.list.d/glibc.list" ]]; then
    if ! yes | pkg install glibc-repo &>>"${LOG_FILE:-/dev/null}"; then
      log_error "Failed to install glibc-repo"
      return 1
    fi
  fi
  if [[ ! -e "$(compat_glibc_libdir)/libc.so.6" ]]; then
    if ! yes | pkg install glibc &>>"${LOG_FILE:-/dev/null}"; then
      log_error "Failed to install glibc"
      return 1
    fi
  fi
  if ! compat_glibc_ready; then
    log_error "glibc sysroot is still missing after installation"
    return 1
  fi
  return 0
}

compat_is_elf() {
  local file="$1" magic
  [[ -f "$file" && -r "$file" ]] || return 1
  magic="$(head -c 4 -- "$file" 2>/dev/null)" || return 1
  [[ "$magic" == $'\x7fELF' ]]
}

# Prints the PT_INTERP of an ELF, or nothing when it is statically linked.
# readelf (binutils) rejects a bare `--`, so the path is normalised instead.
compat_elf_interp() {
  local file="$1" real
  command -v readelf >/dev/null 2>&1 || return 1
  real="$(readlink -f -- "$file" 2>/dev/null || printf '%s' "$file")"
  readelf -l "$real" 2>/dev/null |
    awk '/Requesting program interpreter/ { gsub(/\].*/, "", $NF); print $NF; exit }'
}

# glibc binaries link libc.so.6; bionic links libc.so. A fully static ELF has
# neither and runs anywhere, so it is not classified as glibc.
compat_is_glibc_elf() {
  local file="$1" real
  compat_is_elf "$file" || return 1
  command -v readelf >/dev/null 2>&1 || return 1
  real="$(readlink -f -- "$file" 2>/dev/null || printf '%s' "$file")"
  readelf -d "$real" 2>/dev/null | grep -q 'Shared library: \[libc\.so\.6\]'
}

# native | glibc | script | missing | unknown
compat_classify() {
  local file="$1" first
  [[ -e "$file" ]] || { printf 'missing\n'; return 0; }
  if compat_is_elf "$file"; then
    if compat_is_glibc_elf "$file"; then
      printf 'glibc\n'
    else
      printf 'native\n'
    fi
    return 0
  fi
  if [[ -f "$file" && -r "$file" ]]; then
    IFS= read -r first <"$file" || true
    if [[ "$first" == '#!'* ]]; then
      printf 'script\n'
      return 0
    fi
  fi
  printf 'unknown\n'
}

# Search path handed to the loader: the glibc sysroot first (proven to work),
# then the binary's own directory so bundled shared objects still resolve. The
# directory is skipped when it ships its own libc.so.6, which would be a bionic
# libc and would take the glibc loader down with it.
compat_library_path() {
  local real="$1" sysroot dir out
  sysroot="$(compat_glibc_libdir)"
  dir="$(dirname -- "$real")"
  out="$sysroot"
  if [[ "$dir" != "$sysroot" && ! -e "$dir/libc.so.6" ]]; then
    out="$out:$dir"
  fi
  printf '%s\n' "$out"
}

# Runs a tool through whichever layer can actually execute it. Used by the
# generated wrappers and by doctor probes; never mutates the file.
compat_exec() {
  local file="$1"
  shift
  local kind real loader
  kind="$(compat_classify "$file")"
  case "$kind" in
  missing)
    log_error "compat: $file does not exist"
    return 127
    ;;
  glibc)
    loader="$(compat_glibc_loader)" || {
      log_error "compat: no glibc loader; run 'pkg install glibc-repo glibc'"
      return 127
    }
    real="$(readlink -f -- "$file" 2>/dev/null || printf '%s' "$file")"
    exec "$loader" --library-path "$(compat_library_path "$real")" "$real" "$@"
    ;;
  *)
    exec "$file" "$@"
    ;;
  esac
}

_compat_is_wrapper() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  head -n 2 -- "$file" 2>/dev/null | grep -qF "$COMPAT_WRAPPER_MARKER"
}

# The tier recorded on line 3 of a wrapper, or 0 when it predates tiers.
compat_wrapper_tier() {
  local file="$1" line
  _compat_is_wrapper "$file" || { printf '0\n'; return 1; }
  line="$(sed -n '3p' -- "$file" 2>/dev/null || true)"
  case "$line" in
  "$COMPAT_WRAPPER_TIER_MARKER"*)
    line="${line#*:}"
    # ${line#*:} keeps the space after the colon; strip it or the caller
    # compares " 2" against 2 and the tiers never match.
    line="${line#"${line%%[![:space:]]*}"}"
    printf '%s\n' "$line"
    ;;
  *)
    printf '2\n'
    ;;
  esac
}

# A wrapper written by an older karnel is still a wrapper, but it may hand
# LD_PRELOAD straight to the glibc loader and die in a login shell. Returns 0
# only when the launcher carries every invariant the current code emits.
compat_wrapper_is_current() {
  local file="$1"
  _compat_is_wrapper "$file" || return 1
  grep -qF 'unset LD_PRELOAD' -- "$file" 2>/dev/null || return 1
  if grep -qF 'export LD_PRELOAD' -- "$file" 2>/dev/null; then
    return 1
  fi
  return 0
}

# Builds (once) a synthetic filesystem root out of the glibc sysroot that is
# already on the device. proot then maps /lib, /usr and /etc onto it, which is
# everything a binary that hardcodes those paths needs -- for a few kilobytes
# of symlinks instead of the hundreds of megabytes of a distro image.
compat_proot_root() {
  local root glibc lib
  [[ -n "${KARNEL_DATA:-}" || -n "${KARNEL_COMPAT_ROOT:-}" ]] || return 1
  root="${KARNEL_COMPAT_ROOT:-$KARNEL_DATA/compat-root}"
  glibc="$(compat_glibc_root)"
  lib="$(compat_glibc_libdir)"
  [[ -d "$lib" && -d "$glibc" ]] || return 1
  if [[ ! -f "$root/.ready" ]]; then
    # Plain directories, not symlinks: every one of them is a bind target and
    # proot needs the mount point to exist before it can cover it.
    mkdir -p -- "$root/lib" "$root/lib64" "$root/usr/lib" "$root/usr/bin" \
      "$root/usr/share" "$root/etc" "$root/tmp" "$root/home" "$root/proc" \
      "$root/dev" || return 1
    # Overlay the sysroot onto every path a stock Linux ELF is likely to open.
    # proot resolves these as binds, so the host directories stay
    # authoritative and nothing is copied.
    printf '%s\n' "$glibc" >"$root/.ready" || return 1
  fi
  printf '%s\n' "$root"
}

compat_proot_available() {
  command -v proot >/dev/null 2>&1 || return 1
  compat_proot_root >/dev/null || return 1
  return 0
}

# 0 when the binary starts, 1 when it demonstrably does not.
# A timeout counts as success: the process was created, it simply did not
# exit, which is exactly what an interactive tool does with --version.
compat_probe() {
  local wrapper="$1" out rc
  [[ -x "$wrapper" ]] || return 1
  out="$(timeout "${COMPAT_PROBE_TIMEOUT:-15}" "$wrapper" --version 2>&1)"
  rc=$?
  if ((rc == 124)); then
    return 0
  fi
  if ((rc == 125 || rc == 126 || rc == 127 || rc >= 128)); then
    return 1
  fi
  if printf '%s' "$out" | grep -qiE \
    'bad interpreter|error while loading shared libraries|cannot execute binary|exec format error'; then
    return 1
  fi
  return 0
}

_compat_write_wrapper() {
  local wrapper="$1" real="$2" loader="$3" tier="${4:-$COMPAT_TIER_LOADER}"
  local libpath bash_bin root="" proot_bin=""
  libpath="$(compat_library_path "$real")"
  bash_bin="$(command -v bash 2>/dev/null)" || bash_bin="$PREFIX/bin/bash"
  # Resolve every tier-4 dependency before the redirect opens, otherwise a
  # refusal below would leave a half-written file behind at $wrapper.
  if [[ "$tier" == "$COMPAT_TIER_PROOT" ]]; then
    root="$(compat_proot_root)" || return 1
    proot_bin="$(command -v proot 2>/dev/null)" || return 1
  fi
  {
    printf '%s\n' "#!$bash_bin"
    printf '%s\n' "$COMPAT_WRAPPER_MARKER"
    printf '%s\n' "$COMPAT_WRAPPER_TIER_MARKER $tier"
    # login(1) exports LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so,
    # a bionic object. glibc's ld.so cannot load it and dies with
    # "libc.so: invalid ELF header" on every start. The glibc termux-exec
    # shim is equally unusable: every bionic child this tool spawns then
    # fails with "library libc.so.6 not found". So no preload survives.
    printf '%s\n' "unset LD_PRELOAD"
    case "$tier" in
    "$COMPAT_TIER_USERLAND")
      # The $root/$PATH below must reach the wrapper verbatim.
      # shellcheck disable=SC2016
      printf '%s\n' "# Tier 3: the glibc loader plus the glibc userland, so the child"
      printf '%s\n' "# processes this tool spawns find the same coreutils."
      # Everything below is emitted literally and expanded by the wrapper at
      # runtime, where "root" is the assignment written on the previous line.
      printf 'root=%q\n' "$(compat_glibc_root)"
      # shellcheck disable=SC2016  # expands in the wrapper
      printf 'export PATH="$root/bin:$PATH"\n'
      printf 'exec %q --library-path %q %q "$@"\n' "$loader" "$libpath" "$real"
      ;;
    "$COMPAT_TIER_PROOT")
      printf '%s\n' "# Tier 4: a synthetic FHS root built from the installed glibc sysroot,"
      printf '%s\n' "# for binaries that open /usr/... or /etc/... by absolute path."
      printf 'exec %q -r %q \\
  -b %q:/lib -b %q:/lib64 -b %q:/usr/lib -b %q:/usr/bin \\
  -b %q:/usr/share -b %q:/etc -b %q -b /dev -b /proc \\
  %q "$@"\n' \
        "$proot_bin" "$root" \
        "$(compat_glibc_libdir)" "$(compat_glibc_libdir)" "$(compat_glibc_libdir)" \
        "$(compat_glibc_bindir)" "$(compat_glibc_root)/share" "$(compat_glibc_root)/etc" \
        "$PREFIX" "$real"
      ;;
    *)
      printf '%s\n' "# Tier 2: runs a glibc ELF through the Termux glibc loader. Android has"
      printf '%s\n' "# no /lib/ld-linux-*.so.1, so the kernel cannot start this binary itself."
      printf 'exec %q --library-path %q %q "$@"\n' "$loader" "$libpath" "$real"
      ;;
    esac
  } >"$wrapper" || return 1
  chmod 755 -- "$wrapper" 2>/dev/null || true
  return 0
}

# Replaces a glibc ELF with a launcher that hands it to the glibc loader.
# The original is kept beside it as <path>.karnel-real, so the change is
# reversible and survives `head`/`file` style checks. Returns 1 when the file
# is not a glibc ELF (nothing to adapt) and 0 when it is already adapted.
compat_wrap() {
  local target="$1" tier="${2:-$COMPAT_TIER_LOADER}"
  local real stored loader current
  [[ -e "$target" || -L "$target" ]] || return 1
  real="$(readlink -f -- "$target" 2>/dev/null || printf '%s' "$target")"
  [[ -f "$real" ]] || return 1
  if _compat_is_wrapper "$real"; then
    current="$(compat_wrapper_tier "$real")"
    if [[ "$current" == "$tier" ]] && compat_wrapper_is_current "$real"; then
      return 0
    fi
    # Re-tier an existing wrapper, or refresh one written by an older karnel:
    # the original is already parked next to it, so only the launcher changes.
    stored="$real.karnel-real"
    [[ -e "$stored" ]] || return 1
    loader="$(compat_glibc_loader)" || loader="/lib/ld-linux-aarch64.so.1"
    _compat_write_wrapper "$real" "$stored" "$loader" "$tier" || return 1
    if [[ "$current" == "$tier" ]]; then
      log_info "compat: $real wrapper refreshed"
    else
      log_info "compat: $real retiered to level $tier"
    fi
    return 0
  fi
  compat_is_glibc_elf "$real" || return 1
  loader="$(compat_glibc_loader)" || return 1
  stored="$real.karnel-real"
  if [[ -e "$stored" ]]; then
    # The file on disk is a real ELF, not our wrapper, while a parked copy is
    # already sitting beside it: something outside karnel replaced the
    # launcher (freebuff's node entry re-extracts its runtime in place) and
    # orphaned the copy. The file on disk is authoritative now, so the parked
    # copy is stale. A refusal here would leave the tool permanently
    # unrunnable, so the copy is dropped when it is the same bytes and kept
    # as .karnel-real.stale otherwise - a 130 MB runtime must not be copied
    # just to prove a point.
    if cmp -s -- "$stored" "$real" 2>/dev/null; then
      rm -f -- "$stored" || return 1
      log_warn "compat: dropped a stale parked copy for $real"
    elif ! mv -f -- "$stored" "$stored.stale" 2>/dev/null; then
      log_error "compat: could not move the stale parked copy for $real"
      return 1
    else
      log_warn "compat: replaced a stale parked copy for $real"
    fi
  fi
  if ! mv -- "$real" "$stored"; then
    log_error "compat: could not move $real aside"
    return 1
  fi
  if ! _compat_write_wrapper "$real" "$stored" "$loader" "$tier"; then
    mv -- "$stored" "$real" 2>/dev/null || true
    log_error "compat: could not write wrapper for $real"
    return 1
  fi
  log_info "compat: $real now runs through the glibc loader"
  return 0
}

compat_unwrap() {
  local target="$1" real stored
  real="$(readlink -f -- "$target" 2>/dev/null || printf '%s' "$target")"
  _compat_is_wrapper "$real" || return 1
  stored="$real.karnel-real"
  [[ -e "$stored" ]] || return 1
  rm -f -- "$real" || return 1
  mv -- "$stored" "$real" || return 1
  log_info "compat: restored $real"
  return 0
}

# One-shot adaptation used after every install: wraps glibc binaries, leaves
# native binaries, scripts and text files untouched, and never fails an
# install over a tool that does not need adapting.
compat_adapt() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  compat_wrap "$target" || return 0
  compat_escalate "$target"
  return 0
}

# Probes a wrapped binary and climbs to the cheapest tier that starts it.
# Tier 2 is the default because it is free and needs nothing installed; tier 3
# only adds environment, tier 4 needs proot. Falls back to the best tier that
# was reachable so the caller always ends with the least capable wrapper that
# still has a chance. Never returns non-zero: adaptation must not fail an
# install.
compat_escalate() {
  local target="$1" real tier="$COMPAT_TIER_LOADER"
  real="$(readlink -f -- "$target" 2>/dev/null || printf '%s' "$target")"
  _compat_is_wrapper "$real" || return 0

  # Refresh a launcher written by an older karnel before probing it: the probe
  # has to exercise the wrapper we are about to ship, not the stale one.
  compat_wrapper_is_current "$real" ||
    compat_wrap "$real" "$(compat_wrapper_tier "$real")" || true

  compat_probe "$real" && return 0

  if compat_wrap "$real" "$COMPAT_TIER_USERLAND" && compat_probe "$real"; then
    log_info "compat: $real needs the glibc userland"
    return 0
  fi

  if compat_proot_available && compat_wrap "$real" "$COMPAT_TIER_PROOT" && compat_probe "$real"; then
    log_info "compat: $real needs an FHS root, running it under proot"
    return 0
  fi

  # Nothing higher worked; drop back to the plain loader so the tool is at
  # least in its original, reversible state.
  compat_wrap "$real" "$COMPAT_TIER_LOADER" || true
  log_warn "compat: $real does not start at any tier"
  return 0
}

# Rewrites an unrunnable shebang onto a Termux interpreter. Android has no
# /usr/bin/env, so `#!/usr/bin/env node` dies with "bad interpreter" even
# though node itself is installed.
# Returns 0 when the file was changed, 2 when it already ran, 1 when no
# interpreter could be resolved.
compat_fix_shebang() {
  local file="$1" link="$1" first line interp prog args resolved new real
  [[ -f "$file" && -r "$file" ]] || return 2
  # Edit the target of a symlink, never the link itself: `sed -i` unlinks and
  # re-creates its argument, so running it on $PREFIX/bin/npm would replace
  # that symlink with a detached copy of npm-cli.js whose relative
  # require('../lib/cli.js') then resolves from $PREFIX/bin instead of
  # node_modules/npm. The target is what carries the shebang anyway.
  if real="$(readlink -f -- "$file" 2>/dev/null)" && [[ -n "$real" && -f "$real" ]]; then
    file="$real"
  fi
  [[ -f "$file" && -r "$file" ]] || return 2
  IFS= read -r first <"$file" || true
  [[ "$first" == '#!'* ]] || return 2
  line="${first#\#!}"
  line="${line# }"
  interp="${line%% *}"
  args="${line#"$interp"}"
  args="${args# }"
  if [[ "$interp" == */env ]]; then
    prog="${args%% *}"
    args="${args#"$prog"}"
    args="${args# }"
  else
    prog="$interp"
  fi
  [[ -n "$prog" ]] || return 0
  if [[ "$interp" == /* && -x "$interp" ]]; then
    return 2
  fi
  resolved="$(command -v -- "$prog" 2>/dev/null || true)"
  if [[ -z "$resolved" && "$prog" == */* ]]; then
    resolved="$(command -v -- "${prog##*/}" 2>/dev/null || true)"
  fi
  [[ -n "$resolved" && -x "$resolved" ]] || return 1
  [[ "$resolved" == "$interp" ]] && return 2
  new="#!$resolved"
  [[ -n "$args" ]] && new="$new $args"
  new="${new//\\/\\\\}"
  new="${new//&/\\&}"
  new="${new//|/\\|}"
  sed -i "1s|.*|$new|" -- "$file" || return 1
  log_info "compat: fixed shebang of $link -> $new"
  return 0
}

# Counts entries directly inside a directory whose interpreter path does not
# exist, which is the condition the kernel rejects with "bad interpreter" and
# exit 126. Read-only: nothing is opened for writing.
compat_count_broken_shebangs() {
  local dir="${1:-$PREFIX/bin}" file first interp total=0
  [[ -d "$dir" ]] || { printf '0\n'; return 0; }
  for file in "$dir"/*; do
    [[ -f "$file" && -r "$file" ]] || continue
    IFS= read -r first <"$file" 2>/dev/null || continue
    [[ "$first" == '#!'* ]] || continue
    interp="${first#\#!}"
    interp="${interp# }"
    interp="${interp%% *}"
    [[ "$interp" == /* ]] || continue
    [[ -x "$interp" ]] || total=$((total + 1))
  done
  printf '%s\n' "$total"
}

# Repairs every shebang below a directory that cannot run on Android.
# Prints the number of files actually changed.
compat_fix_shebangs() {
  local root="$1" file rc fixed=0
  [[ -d "$root" ]] || { printf '0\n'; return 0; }
  while IFS= read -r -d '' file; do
    rc=0
    compat_fix_shebang "$file" || rc=$?
    if ((rc == 0)); then
      fixed=$((fixed + 1))
    fi
  done < <(find "$root" -type f -size -2M -exec grep -IlZ '^#!' {} + 2>/dev/null)
  printf '%s\n' "$fixed"
}

# Adapts one resolved path. Wraps a glibc ELF so the kernel can start it;
# leaves native binaries, scripts and text files alone. Always returns 0:
# adaptation is an optimisation, never a reason to fail an install.
_compat_adapt_path() {
  local path="$1" real
  [[ -n "$path" ]] || return 0
  real="$(readlink -f -- "$path" 2>/dev/null || printf '%s' "$path")"
  [[ -f "$real" && -x "$real" ]] || return 0
  if _compat_is_wrapper "$real"; then
    # Already wrapped: re-probe it, so a binary that later stops starting at
    # this tier climbs instead of being handed to the user as-is. Escalation
    # is what every installer reaches through this function; only freebuff
    # calls compat_adapt() directly, so without this the glibc userland and
    # proot tiers would stay unreachable for the rest of the catalog.
    compat_escalate "$real" || true
    return 0
  fi
  if compat_is_glibc_elf "$real"; then
    compat_wrap "$real" || true
    compat_escalate "$real" || true
  fi
  return 0
}

# Adapts whatever a tool has just put on PATH.
compat_adapt_installed() {
  local tool="$1" path
  path="$(command -v -- "$tool" 2>/dev/null)" || return 0
  [[ -n "$path" ]] || return 0
  _compat_adapt_path "$path"
}

# Records every direct entry of the writable parts of PATH as
# "path|size|mtime", printed to a temporary file. Taken before a command runs
# so the layer can afterwards adapt exactly what that command touched.
#
# Sweeping the whole prefix instead would need readelf on every ELF, which
# measures 60+ seconds over a Termux bin directory of 800 entries; diffing a
# snapshot adapts only the handful of files that actually changed. It also
# means no installer has to declare its binary names: a tool that installs a
# command its registry does not mention is still covered, and a file restored
# from an archive with its original mtime is caught by being a new path.
compat_path_snapshot() {
  local dir tmp
  tmp="$(mktemp "${TMPDIR:-${KARNEL_CACHE:-/tmp}}/karnel-compat-snap.XXXXXX" 2>/dev/null)" || return 1
  local IFS=':'
  for dir in $PATH; do
    [[ -n "$dir" && -d "$dir" && -w "$dir" ]] || continue
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -printf '%p|%s|%T@\n' 2>/dev/null || true
  done | sort >"$tmp" || true
  printf '%s\n' "$tmp"
}

# Adapts every PATH entry that appeared or changed since a snapshot, then
# removes both files. Returns 0 unconditionally.
compat_adapt_since() {
  local snap="$1" tmp dir path
  [[ -f "$snap" ]] || return 0
  tmp="$(mktemp "${TMPDIR:-${KARNEL_CACHE:-/tmp}}/karnel-compat-now.XXXXXX" 2>/dev/null)" || {
    rm -f -- "$snap"
    return 0
  }
  local IFS=':'
  for dir in $PATH; do
    [[ -n "$dir" && -d "$dir" && -w "$dir" ]] || continue
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -printf '%p|%s|%T@\n' 2>/dev/null || true
  done | sort >"$tmp" || true
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    _compat_adapt_path "$path" || true
  done < <(comm -13 -- "$snap" "$tmp" 2>/dev/null | cut -d'|' -f1)
  rm -f -- "$snap" "$tmp"
  return 0
}

# Human-readable one-liner for doctor output.
compat_describe() {
  local file="$1" kind interp real
  real="$(readlink -f -- "$file" 2>/dev/null || printf '%s' "$file")"
  if _compat_is_wrapper "$real"; then
    case "$(compat_wrapper_tier "$real")" in
    "$COMPAT_TIER_USERLAND") printf 'glibc (wrapped, loader + glibc userland)\n' ;;
    "$COMPAT_TIER_PROOT")    printf 'glibc (wrapped, proot FHS root)\n' ;;
    *)                       printf 'glibc (wrapped, runs through the glibc loader)\n' ;;
    esac
    return 0
  fi
  kind="$(compat_classify "$file")"
  case "$kind" in
  glibc)
    if interp="$(compat_elf_interp "$file")" && [[ -n "$interp" && ! -e "$interp" ]]; then
      printf 'glibc (cannot run: missing interpreter %s)\n' "$interp"
    else
      printf 'glibc\n'
    fi
    ;;
  native | script | missing | unknown)
    printf '%s\n' "$kind"
    ;;
  esac
}
