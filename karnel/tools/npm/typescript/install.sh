#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_typescript_dependencies() {
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

_install_typescript_npm() {
  loading "Installing TypeScript" _install_typescript_npm_impl
}

_install_typescript_npm_impl() {
  if ! karnel_npm install -g typescript &>>"$LOG_FILE"; then
    log_error "Failed to install TypeScript"
    return 1
  fi
  _fix_npm_shebang "tsc"
  return 0
}

install_typescript() {
  if command -v tsc &>/dev/null; then
    log_info "TypeScript is already installed"
    return 2
  fi
  log_info "Installing TypeScript..."

  _typescript_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_typescript_npm || return 1
  log_success "TypeScript installed"
  return 0
}

_uninstall_typescript_npm() {
  loading "Uninstalling TypeScript" _uninstall_typescript_npm_impl
}

_uninstall_typescript_npm_impl() {
  if ! karnel_npm uninstall -g typescript &>>"$LOG_FILE"; then
    log_error "Failed to uninstall TypeScript"
    return 1
  fi
  return 0
}

uninstall_typescript() {
  if ! command -v tsc &>/dev/null; then
    log_info "TypeScript is not installed"
    return 0
  fi
  log_info "Uninstalling TypeScript..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_typescript_npm || return 1
  log_success "TypeScript uninstalled"
  return 0
}

_update_typescript_npm() {
  loading "Updating TypeScript" _update_typescript_npm_impl
}

_update_typescript_npm_impl() {
  if ! karnel_npm update -g typescript &>>"$LOG_FILE"; then
    log_error "Failed to update TypeScript"
    return 1
  fi
  _fix_npm_shebang "tsc"
  return 0
}

update_typescript() {
  _check_update_needed "TypeScript" "$(_get_installed_npm_version typescript)" "$(_get_remote_npm_version typescript)" _update_typescript_npm
}

reinstall_typescript() {
  uninstall_typescript || [[ $? -eq 2 ]] || return 1

  install_typescript
}
