#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_markserv_dependencies() {
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

_install_markserv_npm() {
  loading "Installing Markserv" _install_markserv_npm_impl
}

_install_markserv_npm_impl() {
  if ! karnel_npm install -g markserv &>>"$LOG_FILE"; then
    log_error "Failed to install markserv"
    return 1
  fi
  _fix_npm_shebang "markserv"
  return 0
}

install_markserv() {
  if command -v markserv &>/dev/null; then
    log_info "Markserv is already installed"
    return 2
  fi
  log_info "Installing Markserv..."

  _markserv_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_markserv_npm || return 1
  log_success "Markserv installed"
  return 0
}

_uninstall_markserv_npm() {
  loading "Uninstalling Markserv" _uninstall_markserv_npm_impl
}

_uninstall_markserv_npm_impl() {
  if ! karnel_npm uninstall -g markserv &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Markserv"
    return 1
  fi
  return 0
}

uninstall_markserv() {
  if ! command -v markserv &>/dev/null; then
    log_info "Markserv is not installed"
    return 0
  fi
  log_info "Uninstalling Markserv..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_markserv_npm || return 1
  log_success "Markserv uninstalled"
  return 0
}

_update_markserv_npm() {
  loading "Updating Markserv" _update_markserv_npm_impl
}

_update_markserv_npm_impl() {
  if ! karnel_npm update -g markserv &>>"$LOG_FILE"; then
    log_error "Failed to update Markserv"
    return 1
  fi
  _fix_npm_shebang "markserv"
  return 0
}

update_markserv() {
  _check_update_needed "Markserv" "$(_get_installed_npm_version markserv)" "$(_get_remote_npm_version markserv)" _update_markserv_npm
}

reinstall_markserv() {
  uninstall_markserv || [[ $? -eq 2 ]] || return 1

  install_markserv
}
