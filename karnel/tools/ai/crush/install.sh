#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"
import "@/utils/colors"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
CRUSH_VERSION="0.82.0"
CRUSH_MARKER="$PREFIX/share/karnel-installers/crush"

install_crush() {
  if command -v crush &>/dev/null; then
    log_info "Crush is already installed"
    return 2
  fi
  if [ -e "$PREFIX/bin/crush" ]; then
    log_error "Refusing to replace an existing Crush binary not owned by Karnel"
    return 1
  fi

  log_info "Installing Crush..."

  # Try npm first
  if command -v npm &>/dev/null; then
    log_info "Attempting npm install..."
    if karnel_npm install -g @charmland/crush &>>"$LOG_FILE"; then
    _fix_npm_shebang "crush" || return 1
      if command -v crush &>/dev/null; then
        record_managed_file "$(command -v crush)" "$CRUSH_MARKER" || return 1
        log_success "Crush installed via npm"
        return 0
      fi
    fi
    log_warn "npm install failed, trying GitHub release..."
  fi

  # Fallback: download from GitHub releases
  local arch
  arch=$(uname -m)
  case "$arch" in
    aarch64|arm64) ;;
    *) log_error "Crush Android release is unavailable for architecture: $arch"; return 1 ;;
  esac
  local tarball="crush_${CRUSH_VERSION}_Android_arm64.tar.gz"
  local url="https://github.com/charmbracelet/crush/releases/download/v${CRUSH_VERSION}/${tarball}"

  log_info "Downloading Crush v${CRUSH_VERSION} for Android arm64..."

  local tmpdir
  tmpdir=$(mktemp -d "${KARNEL_CACHE:-${TMPDIR:-$HOME/.cache/karnel}}/karnel-crush.XXXXXX" 2>/dev/null) || tmpdir=$(mktemp -d) || return 1
  if curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o "$tmpdir/$tarball" 2>>"$LOG_FILE"; then
    if verify_github_release_asset charmbracelet/crush "v${CRUSH_VERSION}" "$tarball" "$tmpdir/$tarball" &&
      extract_tarball "$tmpdir/$tarball" "$tmpdir"; then
      local bin_path
      bin_path=$(find "$tmpdir" -name "crush" -type f -executable 2>/dev/null | head -1)
      if [[ -n "$bin_path" ]]; then
        cp "$bin_path" "$PREFIX/bin/.crush.new"
        chmod +x "$PREFIX/bin/.crush.new"
        mv "$PREFIX/bin/.crush.new" "$PREFIX/bin/crush"
        record_managed_file "$PREFIX/bin/crush" "$CRUSH_MARKER" || return 1
        rm -rf "$tmpdir"
        if command -v crush &>/dev/null; then
          log_success "Crush installed from GitHub release"
          return 0
        fi
      fi
    fi
  fi

  rm -rf "$tmpdir"
  log_error "Failed to install Crush"
  log_info "Check log: $LOG_FILE"
  return 1
}

uninstall_crush() {
  local crush_bin
  if ! command -v crush &>/dev/null; then
    log_info "Crush is not installed"
    return 0
  fi

  crush_bin=$(command -v crush)
  if ! managed_file_matches "$crush_bin" "$CRUSH_MARKER"; then
    log_error "Refusing to remove a Crush installation not owned by Karnel"
    return 1
  fi
  log_info "Uninstalling Crush..."
  karnel_npm uninstall -g @charmland/crush &>>"$LOG_FILE" || true
  managed_file_matches "$crush_bin" "$CRUSH_MARKER" && rm -f "$crush_bin"
  if [ -e "$crush_bin" ]; then
    log_error "Crush changed during uninstall; preserving the current binary"
    return 1
  fi
  rm -f "$CRUSH_MARKER"
  log_success "Crush uninstalled"
  return 0
}

update_crush() {
  _check_update_needed "Crush" "$(_get_installed_npm_version @charmland/crush)" "$(_get_remote_npm_version @charmland/crush)" _do_update_crush
}

_do_update_crush() {
  local crush_bin
  crush_bin=$(command -v crush 2>/dev/null) || return 1
  if ! managed_file_matches "$crush_bin" "$CRUSH_MARKER"; then
    log_error "Refusing to update a Crush installation not owned by Karnel"
    return 1
  fi
  if ! karnel_npm install -g @charmland/crush &>>"$LOG_FILE" || ! command -v crush &>/dev/null; then
    log_error "Crush update failed; the previous installation was kept by npm"
    return 1
  fi
  record_managed_file "$(command -v crush)" "$CRUSH_MARKER"
}

reinstall_crush() {
  if command -v crush &>/dev/null; then
    _do_update_crush
  else
    install_crush
  fi
}
