#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"

install_freebuff() {
  if command -v freebuff &>/dev/null; then
    log_info "Freebuff is already installed"
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
  log_success "Freebuff installed"
}

_fix_freebuff_shebang() {
  local binary
  binary="$(command -v freebuff 2>/dev/null)"
  if [[ -z "$binary" || ! -f "$binary" ]]; then
    log_error "Freebuff binary was not found after npm operation"
    return 1
  fi
  if command -v termux-fix-shebang &>/dev/null; then
    termux-fix-shebang "$binary" &>/dev/null || return 1
  else
    sed -i '1s|#!/usr/bin/env|#!/data/data/com.termux/files/usr/bin/env|' "$binary" || return 1
  fi
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
}

reinstall_freebuff() {
  uninstall_freebuff || [[ $? -eq 2 ]] || return 1

  install_freebuff
}
