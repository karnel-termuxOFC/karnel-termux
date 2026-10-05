#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_prettier_dependencies() {
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

_install_prettier_npm() {
  loading "Installing Prettier" _install_prettier_npm_impl
}

_install_prettier_npm_impl() {
  if ! karnel_npm install -g prettier &>>"$LOG_FILE"; then
    log_error "Failed to install Prettier"
    return 1
  fi
  _fix_npm_shebang "prettier"
  return 0
}

install_prettier() {
  if command -v prettier &>/dev/null; then
    log_info "Prettier is already installed"
    return 2
  fi
  log_info "Installing Prettier..."

  _prettier_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_prettier_npm || return 1
  log_success "Prettier installed"
  return 0
}

_uninstall_prettier_npm() {
  loading "Uninstalling Prettier" _uninstall_prettier_npm_impl
}

_uninstall_prettier_npm_impl() {
  if ! karnel_npm uninstall -g prettier &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Prettier"
    return 1
  fi
  return 0
}

uninstall_prettier() {
  if ! command -v prettier &>/dev/null; then
    log_info "Prettier is not installed"
    return 0
  fi
  log_info "Uninstalling Prettier..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_prettier_npm || return 1
  log_success "Prettier uninstalled"
  return 0
}

_update_prettier_npm() {
  loading "Updating Prettier" _update_prettier_npm_impl
}

_update_prettier_npm_impl() {
  if ! karnel_npm update -g prettier &>>"$LOG_FILE"; then
    log_error "Failed to update Prettier"
    return 1
  fi
  _fix_npm_shebang "prettier"
  return 0
}

update_prettier() {
  _check_update_needed "Prettier" "$(_get_installed_npm_version prettier)" "$(_get_remote_npm_version prettier)" _update_prettier_npm
}

reinstall_prettier() {
  uninstall_prettier || [[ $? -eq 2 ]] || return 1

  install_prettier
}
