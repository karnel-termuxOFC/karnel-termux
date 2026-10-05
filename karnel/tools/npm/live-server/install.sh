#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_live_server_dependencies() {
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

_install_live_server_npm() {
  loading "Installing Live Server" _install_live_server_npm_impl
}

_install_live_server_npm_impl() {
  if ! karnel_npm install -g live-server &>>"$LOG_FILE"; then
    log_error "Failed to install live-server"
    return 1
  fi
  _fix_npm_shebang "live-server"
  return 0
}

install_live_server() {
  if command -v live-server &>/dev/null; then
    log_info "Live Server is already installed"
    return 2
  fi

  log_info "Installing Live Server..."

  _live_server_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_live_server_npm || return 1
  log_success "Live Server installed"
  return 0
}

_uninstall_live_server_npm() {
  loading "Uninstalling Live Server" _uninstall_live_server_npm_impl
}

_uninstall_live_server_npm_impl() {
  if ! karnel_npm uninstall -g live-server &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Live Server"
    return 1
  fi
  return 0
}

uninstall_live_server() {
  if ! command -v live-server &>/dev/null; then
    log_info "Live Server is not installed"
    return 0
  fi
  log_info "Uninstalling Live Server..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_live_server_npm || return 1
  log_success "Live Server uninstalled"
  return 0
}

_update_live_server_npm() {
  loading "Updating Live Server" _update_live_server_npm_impl
}

_update_live_server_npm_impl() {
  if ! karnel_npm update -g live-server &>>"$LOG_FILE"; then
    log_error "Failed to update Live Server"
    return 1
  fi
  _fix_npm_shebang "live-server"
  return 0
}

update_live_server() {
  _check_update_needed "Live Server" "$(_get_installed_npm_version live-server)" "$(_get_remote_npm_version live-server)" _update_live_server_npm
}

reinstall_live_server() {
  uninstall_live_server || [[ $? -eq 2 ]] || return 1

  install_live_server
}
