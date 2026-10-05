#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_psqlformat_dependencies() {
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    log_info "Node.js and npm are already installed"
    return 0
  fi

  log_info "Installing Nodejs and Perl..."
  mkdir -p "$(dirname "$LOG_FILE")"
  if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
    log_error "Failed to install Node.js (required by this tool)"; return 1
  fi
}

_install_psqlformat_npm() {
  loading "Installing PSQL Format" _install_psqlformat_npm_impl
}

_install_psqlformat_npm_impl() {
  if ! karnel_npm install -g psqlformat &>>"$LOG_FILE"; then
    log_error "Failed to install psqlformat"
    return 1
  fi
  _fix_npm_shebang "psqlformat"
  return 0
}

install_psqlformat() {
  if command -v psqlformat &>/dev/null; then
    log_info "PSQL Format is already installed"
    return 2
  fi
  log_info "Installing PSQL Format..."

  _psqlformat_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_psqlformat_npm || return 1
  log_success "PSQL Format installed"
  return 0
}

_uninstall_psqlformat_npm() {
  loading "Uninstalling PSQL Format" _uninstall_psqlformat_npm_impl
}

_uninstall_psqlformat_npm_impl() {
  if ! karnel_npm uninstall -g psqlformat &>>"$LOG_FILE"; then
    log_error "Failed to uninstall PSQL Format"
    return 1
  fi
  return 0
}

uninstall_psqlformat() {
  if ! command -v psqlformat &>/dev/null; then
    log_info "PSQL Format is not installed"
    return 0
  fi
  log_info "Uninstalling PSQL Format..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_psqlformat_npm || return 1
  log_success "PSQL Format uninstalled"
  return 0
}

_update_psqlformat_npm() {
  loading "Updating PSQL Format" _update_psqlformat_npm_impl
}

_update_psqlformat_npm_impl() {
  if ! karnel_npm update -g psqlformat &>>"$LOG_FILE"; then
    log_error "Failed to update PSQL Format"
    return 1
  fi
  _fix_npm_shebang "psqlformat"
  return 0
}

update_psqlformat() {
  _check_update_needed "PSQL Format" "$(_get_installed_npm_version psqlformat)" "$(_get_remote_npm_version psqlformat)" _update_psqlformat_npm
}

reinstall_psqlformat() {
  uninstall_psqlformat || [[ $? -eq 2 ]] || return 1

  install_psqlformat
}
