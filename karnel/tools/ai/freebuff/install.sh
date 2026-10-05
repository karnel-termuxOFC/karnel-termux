#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"
import "@/utils/compat"

import "@/utils/log"
import "@/utils/install"
import "@/utils/version"

# Freebuff ships its launcher on npm and fetches the real runtime (a Bun
# standalone, ~50 MB) on first use. That runtime is a glibc ELF whose
# PT_INTERP, /lib/ld-linux-aarch64.so.1, Android does not have, so the kernel
# refuses to start it with ENOENT ("bad interpreter"). The fix is to hand it
# to the glibc loader instead - and never to patchelf it, which grows the image
# by a PT_LOAD segment and makes it SIGSEGV.
FREEBUFF_ORIGIN="${FREEBUFF_ORIGIN:-https://codebuff.com}"
FREEBUFF_DATA_DIR="${FREEBUFF_DATA_DIR:-$HOME/.config/manicode}"
# Line 2 of the generated npm entry wrapper, used to recognise our own copy.
FREEBUFF_ENTRY_MARKER="# karnel-freebuff-entry"

install_freebuff() {
  if command -v freebuff &>/dev/null; then
    log_info "Freebuff is already installed"
    _fix_freebuff_runtime || true
    _install_freebuff_entry || true
    return 2
  fi

  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by Freebuff)"
      return 1
    fi
  fi

  log_info "Installing Freebuff..."
  karnel_npm install -g freebuff || {
    log_error "Failed to install Freebuff"
    return 1
  }
  _fix_npm_shebang "freebuff" || return 1
  _fix_freebuff_shebang || return 1
  _fix_freebuff_runtime || return 1
  _install_freebuff_entry || return 1
  log_success "Freebuff installed"
}

_fix_freebuff_shebang() {
  local binary real
  binary="$(command -v freebuff 2>/dev/null)"
  if [[ -z "$binary" || ! -f "$binary" ]]; then
    log_error "Freebuff binary was not found after npm operation"
    return 1
  fi
  real="$(readlink -f -- "$binary" 2>/dev/null || printf '%s' "$binary")"
  [[ -f "$real" ]] || return 0
  # 2 = already runnable, 1 = nothing to resolve; neither is fatal here,
  # _fix_npm_shebang has already normalised the npm shim.
  compat_fix_shebang "$real" || true
  return 0
}

# Prepares the runtime: fetch it when it is missing, wrap it so the glibc
# loader can start it, and replace it when the copy on disk no longer runs.
_fix_freebuff_runtime() {
  local data_bin="$FREEBUFF_DATA_DIR/freebuff"
  if [[ ! -e "$data_bin" ]]; then
    if ! _fetch_freebuff_binary "$data_bin"; then
      log_warn "Freebuff runtime was not fetched (offline?); it will be prepared on the next install"
      return 0
    fi
  fi
  compat_adapt "$data_bin"
  if _freebuff_binary_runs "$data_bin"; then
    return 0
  fi
  log_info "Freebuff runtime does not run; downloading it again"
  if ! _replace_freebuff_binary "$data_bin"; then
    log_error "Freebuff runtime could not be repaired"
    return 1
  fi
  if ! _freebuff_binary_runs "$data_bin"; then
    log_error "Freebuff runtime still does not run after repair"
    return 1
  fi
  return 0
}

_freebuff_binary_runs() {
  local bin="$1" rc=0
  [[ -e "$bin" ]] || return 1
  # The braces redirect the shell itself: bash prints "Segmentation fault" to
  # its own stderr, not to the child's, so `2>/dev/null` on the command alone
  # would still leak the crash of a damaged runtime into the install output.
  { timeout 30 "$bin" --version >/dev/null 2>&1; rc=$?; } 2>/dev/null
  ((rc == 0))
}

_freebuff_target_key() {
  case "$(uname -m)" in
  aarch64 | arm64) printf 'linux-arm64\n' ;;
  x86_64 | amd64) printf 'linux-x64\n' ;;
  *) return 1 ;;
  esac
}

_freebuff_package_json() {
  local bin candidate
  if bin="$(command -v freebuff 2>/dev/null)" && [[ -n "$bin" ]]; then
    bin="$(readlink -f -- "$bin" 2>/dev/null || printf '%s' "$bin")"
    candidate="$(dirname -- "$bin")/package.json"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  candidate="$(karnel_npm root -g 2>/dev/null | tail -n 1)/freebuff/package.json"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

# Downloads and checksum-verifies the published runtime, then moves it into
# place. The archive digest comes from the npm package's own binaryChecksums
# map, so a substituted download is rejected before anything is executed.
_fetch_freebuff_binary() {
  local dest="$1"
  local pkg_json version key expected url archive stage
  pkg_json="$(_freebuff_package_json)" || {
    log_error "freebuff package metadata not found"
    return 1
  }
  version="$(node -p "require('$pkg_json').version" 2>/dev/null)"
  [[ -n "$version" ]] || {
    log_error "Could not read the freebuff version"
    return 1
  }
  key="$(_freebuff_target_key)" || {
    log_error "Freebuff has no runtime for $(uname -m)"
    return 1
  }
  expected="$(node -p "(require('$pkg_json').binaryChecksums||{})['$key']||''" 2>/dev/null)"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || {
    log_error "No published checksum for freebuff $key"
    return 1
  }
  url="$FREEBUFF_ORIGIN/api/releases/download/$version/freebuff-$key.tar.gz"
  archive="$(mktemp "${TMPDIR:-$PREFIX/tmp}/freebuff.XXXXXX")" || return 1
  if ! curl --fail --silent --show-error --location --retry 3 "$url" \
    -o "$archive" &>>"$LOG_FILE"; then
    rm -f -- "$archive"
    log_error "Failed to download the Freebuff runtime"
    return 1
  fi
  if ! verify_sha256 "$archive" "$expected"; then
    rm -f -- "$archive"
    return 1
  fi
  stage="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/freebuff-stage.XXXXXX")" || {
    rm -f -- "$archive"
    return 1
  }
  if ! safe_extract_tar "$archive" "$stage"; then
    rm -rf -- "$stage" "$archive"
    return 1
  fi
  rm -f -- "$archive"
  if [[ ! -f "$stage/freebuff" ]]; then
    rm -rf -- "$stage"
    log_error "Freebuff runtime missing from the archive"
    return 1
  fi
  chmod 755 -- "$stage/freebuff" || {
    rm -rf -- "$stage"
    return 1
  }
  if [[ -e "$dest" || -L "$dest" ]]; then
    rm -f -- "$dest" "$dest.karnel-real" || {
      rm -rf -- "$stage"
      return 1
    }
  fi
  mv -f -- "$stage/freebuff" "$dest" || {
    rm -rf -- "$stage"
    return 1
  }
  rm -rf -- "$stage"
  return 0
}

# Swaps a runtime that no longer runs for a freshly verified copy.
_replace_freebuff_binary() {
  local data_bin="$1"
  local staging
  staging="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/freebuff-repair.XXXXXX")" || return 1
  if ! _fetch_freebuff_binary "$staging/freebuff"; then
    rm -rf -- "$staging"
    return 1
  fi
  rm -f -- "$data_bin" "$data_bin.karnel-real" || {
    rm -rf -- "$staging"
    return 1
  }
  mv -f -- "$staging/freebuff" "$data_bin" || {
    rm -rf -- "$staging"
    return 1
  }
  rm -rf -- "$staging"
  compat_adapt "$data_bin"
  return 0
}

# npm links $PREFIX/bin/freebuff to a launcher that derives its release
# target from `process.platform`, which Node reports as "android" here - so it
# refuses every download with `Unsupported platform: android arm64` before the
# runtime is ever spawned. The launcher already honours FREEBUFF_BINARY_TARGET,
# so the entry is replaced by a wrapper that exports the supported key; no
# launcher code is patched and the real entry point keeps working.
_install_freebuff_entry() {
  local entry="$PREFIX/bin/freebuff" key real tmp
  key="$(_freebuff_target_key)" || {
    log_error "Freebuff has no runtime for $(uname -m)"
    return 1
  }
  if [[ -L "$entry" ]]; then
    real="$(readlink -f -- "$entry")"
  elif [[ -f "$entry" ]] && head -n 4 -- "$entry" | grep -qF "$FREEBUFF_ENTRY_MARKER"; then
    real="$(sed -n 's/^# real: //p' -- "$entry" | head -n 1)"
  else
    real="$(karnel_npm root -g 2>/dev/null | tail -n 1)/freebuff/index.js"
  fi
  if [[ -z "$real" || ! -f "$real" ]]; then
    log_error "The freebuff launcher was not found"
    return 1
  fi
  tmp="$entry.tmp.$$"
  {
    printf '%s\n' "#!$PREFIX/bin/bash"
    printf '%s\n' "$FREEBUFF_ENTRY_MARKER"
    printf '%s\n' "# real: $real"
    printf '%s\n' "# Node reports process.platform \"android\" on Termux, so the launcher"
    printf '%s\n' "# resolves its release target to android-arm64 and no build is published"
    printf '%s\n' "# for it. The launcher honours this override, so no code is patched."
    printf 'export FREEBUFF_BINARY_TARGET=%q\n' "$key"
    printf 'exec %q %q "$@"\n' "$PREFIX/bin/node" "$real"
  } >"$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  chmod 755 -- "$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  mv -f -- "$tmp" "$entry" || {
    rm -f -- "$tmp"
    return 1
  }
  return 0
}

uninstall_freebuff() {
  if ! command -v freebuff &>/dev/null; then
    log_info "Freebuff is not installed"
    return 2
  fi

  log_info "Uninstalling Freebuff..."
  karnel_npm uninstall -g freebuff || {
    log_error "Failed to uninstall Freebuff"
    return 1
  }
  log_success "Freebuff uninstalled"
}

update_freebuff() {
  _check_update_needed "Freebuff" \
    "$(_get_installed_npm_version freebuff)" \
    "$(_get_remote_npm_version freebuff)" \
    _do_update_freebuff
}

_do_update_freebuff() {
  karnel_npm update -g freebuff || {
    log_error "Failed to update Freebuff"
    return 1
  }
  _fix_freebuff_shebang
  _fix_freebuff_runtime
  _install_freebuff_entry
}

reinstall_freebuff() {
  uninstall_freebuff || [[ $? -eq 2 ]] || return 1

  install_freebuff
}
