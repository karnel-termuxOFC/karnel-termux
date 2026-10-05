#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"

install_supercode_cli() {
  if command -v supercode &>/dev/null; then
    log_info "Supercode CLI is already installed"
    return 2
  fi
  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by Supercode CLI)"
      return 1
    fi
  fi

  log_info "Installing Supercode CLI..."
  local output rc
  output="$(karnel_npm install -g supercode-cli 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if (( rc != 0 )); then
    log_error "Failed to install Supercode CLI"
    return 1
  fi
  _fix_npm_shebang "supercode-cli" || return 1
  _fix_supercode_shebang || return 1
  log_success "Supercode CLI installed"
  return 0
}

_fix_supercode_shebang() {
  local binary
  binary="$(command -v supercode 2>/dev/null)"
  if [[ -z "$binary" || ! -f "$binary" ]]; then
    log_error "Supercode CLI binary was not found after npm operation"
    return 1
  fi
  if command -v termux-fix-shebang &>/dev/null; then
    termux-fix-shebang "$binary" &>/dev/null || return 1
  else
    sed -i '1s|#!/usr/bin/env|#!/data/data/com.termux/files/usr/bin/env|' "$binary" || return 1
  fi
}

uninstall_supercode_cli() {
  if ! command -v supercode &>/dev/null; then
    log_info "Supercode CLI is not installed"
    return 2
  fi
  log_info "Uninstalling Supercode CLI..."
  local output rc
  output="$(karnel_npm uninstall -g supercode-cli 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to uninstall Supercode CLI"
    return 1
  fi
  log_success "Supercode CLI uninstalled"
  return 0
}

update_supercode_cli() {
  _check_update_needed "Supercode CLI" \
    "$(_get_installed_npm_version supercode-cli)" \
    "$(_get_remote_npm_version supercode-cli)" \
    _do_update_supercode_cli
}

_do_update_supercode_cli() {
  local output rc
  output="$(karnel_npm update -g supercode-cli 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to update Supercode CLI"
    return 1
  fi
  _fix_supercode_shebang || return 1
  return 0
}

reinstall_supercode_cli() {
  uninstall_supercode_cli || [[ $? -eq 2 ]] || return 1

  install_supercode_cli
}
