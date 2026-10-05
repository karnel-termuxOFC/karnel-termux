#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_ncu_dependencies() {
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    log_info "Node.js and npm are already installed"
    return 0
  fi

  log_info "Installing Nodejs..."
  mkdir -p "$(dirname "$LOG_FILE")"
  if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
    log_error "Failed to install Node.js (required by this tool)"; return 1
  fi
}

_install_ncu_npm() {
  loading "Installing NPM Check Updates" _install_ncu_npm_impl
}

_install_ncu_npm_impl() {
  if ! karnel_npm install -g npm-check-updates &>>"$LOG_FILE"; then
    log_error "Failed to install npm-check-updates"
    return 1
  fi
  _fix_npm_shebang "ncu"
  return 0
}

install_ncu() {
  if command -v ncu &>/dev/null; then
    log_info "NPM Check Updates is already installed"
    return 2
  fi
  log_info "Installing NPM Check Updates..."

  _ncu_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_ncu_npm || return 1
  log_success "NPM Check Updates installed"
  return 0
}

_uninstall_ncu_npm() {
  loading "Uninstalling NPM Check Updates" _uninstall_ncu_npm_impl
}

_uninstall_ncu_npm_impl() {
  if ! karnel_npm uninstall -g npm-check-updates &>>"$LOG_FILE"; then
    log_error "Failed to uninstall NPM Check Updates"
    return 1
  fi
  return 0
}

uninstall_ncu() {
  if ! command -v ncu &>/dev/null; then
    log_info "NPM Check Updates is not installed"
    return 0
  fi
  log_info "Uninstalling NPM Check Updates..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_ncu_npm || return 1
  log_success "NPM Check Updates uninstalled"
  return 0
}

_update_ncu_npm() {
  loading "Updating NPM Check Updates" _update_ncu_npm_impl
}

_update_ncu_npm_impl() {
  if ! karnel_npm update -g npm-check-updates &>>"$LOG_FILE"; then
    log_error "Failed to update NPM Check Updates"
    return 1
  fi
  _fix_npm_shebang "ncu"
  return 0
}

update_ncu() {
  _check_update_needed "npm-check-updates" "$(_get_installed_npm_version npm-check-updates)" "$(_get_remote_npm_version npm-check-updates)" _update_ncu_npm
}

reinstall_ncu() {
  uninstall_ncu || [[ $? -eq 2 ]] || return 1

  install_ncu
}
