#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

PUTER_PACKAGE="@heyputer/cli"
PUTER_LOG_FILE="$KARNEL_CACHE/install_ai.log"

install_puter() {
  if command -v puter &>/dev/null; then
    log_info "Puter CLI is already installed"
    return 2
  fi

  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by Puter CLI)"
      return 1
    fi
  fi

  log_info "Installing Puter CLI..."
  if ! karnel_npm install -g "$PUTER_PACKAGE" &>>"$PUTER_LOG_FILE"; then
    log_error "Failed to install Puter CLI; see $PUTER_LOG_FILE"
    return 1
  fi
  if ! command -v puter &>/dev/null || ! puter --help &>/dev/null; then
    log_error "Puter CLI did not run after installation; see $PUTER_LOG_FILE"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v puter)" &>/dev/null || true
  log_success "Puter CLI installed"
}

uninstall_puter() {
  if ! command -v puter &>/dev/null; then
    log_info "Puter CLI is not installed"
    return 2
  fi

  log_info "Uninstalling Puter CLI..."
  if ! karnel_npm uninstall -g "$PUTER_PACKAGE" &>>"$PUTER_LOG_FILE"; then
    log_error "Failed to uninstall Puter CLI; see $PUTER_LOG_FILE"
    return 1
  fi
  log_success "Puter CLI uninstalled"
}

update_puter() {
  _check_update_needed "Puter CLI" \
    "$(_get_installed_npm_version "$PUTER_PACKAGE")" \
    "$(_get_remote_npm_version "$PUTER_PACKAGE")" \
    _do_update_puter
}

_do_update_puter() {
  if ! karnel_npm update -g "$PUTER_PACKAGE" &>>"$PUTER_LOG_FILE"; then
    log_error "Failed to update Puter CLI; see $PUTER_LOG_FILE"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v puter)" &>/dev/null || true
  if ! command -v puter &>/dev/null || ! puter --help &>/dev/null; then
    log_error "Puter CLI did not run after update; see $PUTER_LOG_FILE"
    return 1
  fi
}

reinstall_puter() {
  uninstall_puter || [[ $? -eq 2 ]] || return 1
  install_puter
}
