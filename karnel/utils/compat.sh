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

# Marker written on line 2 of every generated wrapper.
COMPAT_WRAPPER_MARKER="# karnel-compat-wrapper"

compat_glibc_root() { printf '%s\n' "${KARNEL_GLIBC_ROOT:-$PREFIX/glibc}"; }

compat_glibc_libdir() { printf '%s\n' "$(compat_glibc_root)/lib"; }

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

_compat_write_wrapper() {
  local wrapper="$1" real="$2" loader="$3"
  local libpath bash_bin
  libpath="$(compat_library_path "$real")"
  bash_bin="$(command -v bash 2>/dev/null)" || bash_bin="$PREFIX/bin/bash"
  {
    printf '%s\n' "#!$bash_bin"
    printf '%s\n' "$COMPAT_WRAPPER_MARKER"
    printf '%s\n' "# Runs a glibc ELF through the Termux glibc loader. Android has no"
    printf '%s\n' "# /lib/ld-linux-*.so.1, so the kernel cannot start this binary itself."
    printf 'exec %q --library-path %q %q "$@"\n' "$loader" "$libpath" "$real"
  } >"$wrapper" || return 1
  chmod 755 -- "$wrapper" 2>/dev/null || true
  return 0
}

# Replaces a glibc ELF with a launcher that hands it to the glibc loader.
# The original is kept beside it as <path>.karnel-real, so the change is
# reversible and survives `head`/`file` style checks. Returns 1 when the file
# is not a glibc ELF (nothing to adapt) and 0 when it is already adapted.
compat_wrap() {
  local target="$1" real stored loader
  [[ -e "$target" || -L "$target" ]] || return 1
  real="$(readlink -f -- "$target" 2>/dev/null || printf '%s' "$target")"
  [[ -f "$real" ]] || return 1
  if _compat_is_wrapper "$real"; then
    return 0
  fi
  compat_is_glibc_elf "$real" || return 1
  loader="$(compat_glibc_loader)" || return 1
  stored="$real.karnel-real"
  if [[ -e "$stored" ]]; then
    log_error "compat: refusing to overwrite existing $stored"
    return 1
  fi
  if ! mv -- "$real" "$stored"; then
    log_error "compat: could not move $real aside"
    return 1
  fi
  if ! _compat_write_wrapper "$real" "$stored" "$loader"; then
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

# Adapts whatever a tool has just put on PATH. Wraps a glibc ELF so the
# kernel can start it; leaves native binaries, scripts and text files alone.
# Always returns 0: adaptation is an optimisation, never a reason to fail an
# install or an update.
compat_adapt_installed() {
  local tool="$1" path real
  path="$(command -v -- "$tool" 2>/dev/null)" || return 0
  [[ -n "$path" ]] || return 0
  real="$(readlink -f -- "$path" 2>/dev/null || printf '%s' "$path")"
  [[ -f "$real" && -x "$real" ]] || return 0
  if _compat_is_wrapper "$real"; then
    return 0
  fi
  if compat_is_glibc_elf "$real"; then
    compat_wrap "$real" || true
  fi
  return 0
}

# Human-readable one-liner for doctor output.
compat_describe() {
  local file="$1" kind interp real
  real="$(readlink -f -- "$file" 2>/dev/null || printf '%s' "$file")"
  if _compat_is_wrapper "$real"; then
    printf 'glibc (wrapped, runs through the glibc loader)\n'
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
