#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"
import "@/utils/install"
# Safe, self-contained tar extractor (independent of framework import).
# Rejects path traversal, absolute paths, unsafe symlinks/hardlinks, and
# device/special-file entries. Intentionally has NO unsafe fallback.
_archive_member_is_safe() {
  local member="$1"
  [[ -n "$member" && "$member" != /* && "$member" != *\\* ]] || return 1
  case "/$member/" in
    */../*) return 1 ;;
  esac
}

_archive_link_is_safe() {
  local member="$1" target="$2" part depth=0
  local -a _archive_parts
  [[ -n "$target" && "$target" != /* && "$target" != *\\* ]] || return 1
  IFS=/ read -r -a _archive_parts <<<"$(dirname "$member")/$target"
  for part in "${_archive_parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) ((depth > 0)) || return 1; ((depth -= 1)) ;;
      *) ((depth += 1)) ;;
    esac
  done
}

safe_extract_tar() {
  local archive="$1" outdir="$2" strip_components="${3:-0}"
  local member listing verbose mode line target
  listing=$(tar -tf "$archive" 2>/dev/null) || return 1
  while IFS= read -r member; do
    _archive_member_is_safe "$member" || return 1
  done <<<"$listing"
  verbose=$(tar -tvf "$archive" 2>/dev/null) || return 1
  while IFS= read -r line; do
    mode=${line%% *}
    case "${mode:0:1}" in
      l)
        member=${line%% -> *}; member=${member##* }
        target=${line#* -> }
        _archive_link_is_safe "$member" "$target" || return 1
        ;;
      h)
        member=${line%% link to *}; member=${member##* }
        target=${line#* link to }
        _archive_link_is_safe "$member" "$target" || return 1
        ;;
      b|c|p) return 1 ;;
    esac
  done <<<"$verbose"
  mkdir -p "$outdir" || return 1
  tar -xf "$archive" -C "$outdir" --strip-components="$strip_components" \
    --no-same-owner --no-same-permissions
}



: "${KARNEL_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"
: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
LOG_FILE="$KARNEL_CACHE/install_ai.log"
KIRO_DATA_DIR="$KARNEL_DATA/kiro"
KIRO_MARKER="$KIRO_DATA_DIR/.karnel-binary"
KIRO_METHOD="$KIRO_DATA_DIR/.install-method"

_kiro_owned() {
  local recorded actual
  [[ -f "$PREFIX/bin/kiro-cli" && -L "$PREFIX/bin/kiro" &&
    "$(readlink "$PREFIX/bin/kiro")" == "$PREFIX/bin/kiro-cli" && -f "$KIRO_MARKER" ]] || return 1
  read -r recorded _ <"$KIRO_MARKER" || return 1
  actual=$(sha256sum "$PREFIX/bin/kiro-cli" 2>/dev/null | awk '{print $1}') || return 1
  [[ "$recorded" == "$actual" ]]
}

_kiro_is_usable() {
  local binary
  for binary in kiro kiro-cli; do
    if command -v "$binary" &>/dev/null && "$binary" --version &>/dev/null; then
      return 0
    fi
  done
  return 1
}

# The real binary always lives at $KIRO_DATA_DIR/kiro-cli; $PREFIX/bin/kiro-cli
# is this wrapper, and $PREFIX/bin/kiro is a symlink to it. Passing the runner
# explicitly matters: on a fresh install the wrapper is written before
# $KIRO_METHOD exists, so reading it here would silently drop glibc-runner.
_kiro_create_wrapper() {
  local real_bin="$1" wrapper="$2" use_glibc="${3:-}" runner=""
  [[ -n "$use_glibc" ]] && runner="glibc-runner "
  mkdir -p "$PREFIX/bin" "$KIRO_DATA_DIR" || return 1
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.kiro-cli.XXXXXX")" || return 1
  cat > "$temporary" << WRAPPER
#!$PREFIX/bin/bash
# Karnel-managed Kiro wrapper
# Browser OAuth redirects cannot be answered from a Termux session, so a bare
# "kiro login" defaults to the OAuth device flow (what --use-device-flow is for).
if [ "\$1" = "login" ]; then
  shift
  case " \$* " in
    *" --use-device-flow "*) set -- login "\$@" ;;
    *) set -- login --use-device-flow "\$@" ;;
  esac
fi
exec $runner"$real_bin" "\$@"
WRAPPER
  chmod +x "$temporary" || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$wrapper" || return 1
  return 0
}

# Older installs put the real binary straight at $PREFIX/bin/kiro-cli, which
# left no room to inject --use-device-flow. Move it into the data dir and put a
# wrapper in its place; an install that already has a wrapper is left alone.
_kiro_migrate_to_wrapper() {
  local src="$PREFIX/bin/kiro-cli" dst="$KIRO_DATA_DIR/kiro-cli" method
  [[ -f "$src" ]] || return 0
  head -c 2 "$src" 2>/dev/null | grep -q '#!' && return 0
  [[ -f "$dst" ]] && return 0
  mkdir -p "$KIRO_DATA_DIR" || return 1
  method=$(cat "$KIRO_METHOD" 2>/dev/null)
  mv -f "$src" "$dst" || return 1
  if [[ "$method" == "glibc-runner" ]]; then
    _kiro_create_wrapper "$dst" "$src" 1 || return 1
  else
    _kiro_create_wrapper "$dst" "$src" "" || return 1
  fi
  sha256sum "$src" >"$KIRO_MARKER" || return 1
  hash -r
  return 0
}

install_kiro() (
  local force="${1:-}"
  if _kiro_is_usable; then
    if ! _kiro_owned; then
      log_error "Refusing to replace Kiro not managed by Karnel"
      return 1
    fi
    if [[ "$force" == "force" ]]; then
      log_info "Updating Kiro CLI..."
    else
      _kiro_migrate_to_wrapper || return 1
      log_info "Kiro is already installed"
      return 2
    fi
  elif [[ -e "$PREFIX/bin/kiro" || -L "$PREFIX/bin/kiro" || -e "$PREFIX/bin/kiro-cli" ]] && ! _kiro_owned; then
    log_error "Refusing to replace unowned Kiro command"
    return 1
  fi

  log_info "Installing Kiro CLI..."

  if ! command -v python3 &>/dev/null; then
    if ! yes | pkg install python &>>"$LOG_FILE"; then
      log_error "Failed to install python3 (needed for kiro manifest parsing)"
      return 1
    fi
  fi

  local arch target
  arch=$(uname -m)
  case "$arch" in
    aarch64|arm64) target="aarch64" ;;
    x86_64|amd64) target="x86_64" ;;
    *) log_error "Unsupported architecture: $arch"; return 1 ;;
  esac

  local manifest
  manifest=$(curl -fsSL "https://prod.download.cli.kiro.dev/stable/latest/manifest.json" 2>/dev/null)

  if [[ -z "$manifest" ]]; then
    log_error "Failed to fetch Kiro manifest"
    return 1
  fi

  local version download_path expected
  IFS=$'\t' read -r version download_path expected < <(printf '%s' "$manifest" | python3 -c '
import json, re, sys
target = sys.argv[1]
data = json.load(sys.stdin)
version = data.get("version", "")
if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+(?:[-+][0-9A-Za-z.-]+)?", version):
    raise SystemExit(1)
packages = [p for p in data.get("packages", [])
            if p.get("architecture") == target and p.get("os") == "linux"
            and p.get("fileType") == "tarGz" and p.get("variant") == "headless"]
packages.sort(key=lambda p: "musl" not in p.get("targetTriple", ""))
if not packages:
    raise SystemExit(1)
package = packages[0]
download = package.get("download", "")
checksum = package.get("sha256", "")
if not download.startswith(version + "/") or ".." in download or not re.fullmatch(r"[0-9A-Za-z._/+~-]+", download):
    raise SystemExit(1)
if not re.fullmatch(r"[0-9a-f]{64}", checksum):
    raise SystemExit(1)
print(version, download, checksum, sep="\t")
' "$target" 2>/dev/null)

  if [[ -z "$version" || -z "$download_path" || -z "$expected" ]]; then
    log_error "No compatible package found for $arch"
    return 1
  fi

  local tmpdir archive actual bin_path staged_bin="" staged_link_dir="" use_glibc=""
  tmpdir=$(mktemp -d "$KIRO_DATA_DIR/kiro.XXXXXX") || { mkdir -p "$KIRO_DATA_DIR"; mktemp -d "$KIRO_DATA_DIR/kiro.XXXXXX" || return 1; }
  trap 'rm -rf "$tmpdir"; [[ -z "$staged_bin" ]] || rm -f "$staged_bin"; [[ -z "$staged_link_dir" ]] || rm -rf "$staged_link_dir"' EXIT
  archive="$tmpdir/kiro.tar.gz"
  log_info "Downloading Kiro v$version (this may take a while)..."

  if curl -fsSL --connect-timeout 15 --max-time 300 \
    "https://prod.download.cli.kiro.dev/stable/$download_path" \
    -o "$archive" 2>>"$LOG_FILE"; then
    actual=$(sha256sum "$archive" 2>/dev/null | awk '{print $1}') || actual=""
    if [[ "$actual" != "$expected" ]]; then
      log_error "Kiro checksum verification failed"
      return 1
    fi
    log_success "Checksum verified"

    if safe_extract_tar "$archive" "$tmpdir" 2>>"$LOG_FILE"; then
      bin_path=$(find "$tmpdir" -name "kiro-cli" -type f -executable 2>/dev/null | head -1)
      if [[ -z "$bin_path" ]]; then
        bin_path=$(find "$tmpdir" -name "kiro*" -type f -executable 2>/dev/null | head -1)
      fi
      if [[ -n "$bin_path" ]]; then
        mkdir -p "$PREFIX/bin" "$KIRO_DATA_DIR" || return 1
        staged_bin=$(mktemp "$PREFIX/bin/.kiro-cli.XXXXXX") || return 1
        cp "$bin_path" "$staged_bin" && chmod +x "$staged_bin" || return 1
        if ! "$staged_bin" --version &>/dev/null; then
          log_warn "Kiro binary is a glibc build — installing glibc loader..."
          if [[ ! -f $PREFIX/etc/apt/sources.list.d/glibc.list ]]; then
            yes | pkg install glibc-repo &>>"$LOG_FILE"
          fi
          if [[ ! -f $PREFIX/glibc/lib/libc.so.6 ]]; then
            yes | pkg install glibc &>>"$LOG_FILE"
          fi
          if ! command -v glibc-runner &>/dev/null; then
            yes | pkg install glibc-runner &>>"$LOG_FILE"
          fi
          if command -v glibc-runner &>/dev/null &&
            ! glibc-runner "$staged_bin" --version &>/dev/null; then
            log_warn "Verified Kiro binary cannot execute even via glibc-runner; existing installation was preserved"
            log_info "Try: ${D_CYAN}karnel install ai --kiro${NC} after installing proot-distro"
            return 1
          fi
          use_glibc=1
        fi
        if [[ -z "$use_glibc" ]] && ! "$staged_bin" --version &>/dev/null; then
          log_warn "Verified Kiro binary cannot execute; existing installation was preserved"
          return 1
        fi
        if [[ -n "$use_glibc" ]]; then
          mv -f "$staged_bin" "$KIRO_DATA_DIR/kiro-cli" || return 1
          staged_bin=""
          mkdir -p "$PREFIX/bin" || return 1
          _kiro_create_wrapper "$KIRO_DATA_DIR/kiro-cli" "$PREFIX/bin/kiro-cli" 1 || return 1
          printf 'glibc-runner' >"$KIRO_METHOD"
        else
          mkdir -p "$KIRO_DATA_DIR" || return 1
          mv -f "$staged_bin" "$KIRO_DATA_DIR/kiro-cli" || return 1
          staged_bin=""
          _kiro_create_wrapper "$KIRO_DATA_DIR/kiro-cli" "$PREFIX/bin/kiro-cli" "" || return 1
          printf 'native' >"$KIRO_METHOD"
        fi
        staged_link_dir=$(mktemp -d "$PREFIX/bin/.kiro-link.XXXXXX") || return 1
        ln -s "$PREFIX/bin/kiro-cli" "$staged_link_dir/kiro" || return 1
        mv -f "$staged_link_dir/kiro" "$PREFIX/bin/kiro" || return 1
        rmdir "$staged_link_dir" || return 1
        staged_link_dir=""
        mkdir -p "$KIRO_DATA_DIR" || return 1
        sha256sum "$PREFIX/bin/kiro-cli" >"$KIRO_MARKER" || return 1
        if [[ -n "$use_glibc" ]]; then
          printf 'glibc-runner' >"$KIRO_METHOD"
        else
          printf 'native' >"$KIRO_METHOD"
        fi
        hash -r
        log_success "Kiro v$version installed from verified release"
        return 0
      fi
    fi
  fi

  log_error "Failed to install Kiro"
  log_info "See the official Kiro CLI documentation for manual installation options."
  return 1
)

uninstall_kiro() {
  if [[ ! -e "$PREFIX/bin/kiro" && ! -L "$PREFIX/bin/kiro" && ! -e "$PREFIX/bin/kiro-cli" ]]; then
    log_info "Kiro is not installed"
    return 2
  fi
  if ! _kiro_owned; then
    log_warn "Preserving Kiro not managed by Karnel"
    return 2
  fi

  log_info "Uninstalling Kiro..."
  rm -f "$PREFIX/bin/kiro" "$PREFIX/bin/kiro-cli"
  rm -rf "$KIRO_DATA_DIR"
  log_success "Kiro uninstalled"
  return 0
}

update_kiro() {
  _kiro_owned || { log_error "Kiro is not installed by Karnel"; return 1; }
  _update_kiro_impl
}

_update_kiro_impl() {
  install_kiro force
}

reinstall_kiro() {
  uninstall_kiro || [[ $? -eq 2 ]] || return 1
  install_kiro
}