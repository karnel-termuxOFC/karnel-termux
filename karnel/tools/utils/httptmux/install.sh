#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_utils.log"

_install_httptmux_npm() {
  loading "Installing httptmux via npm" _install_httptmux_npm_impl
}

_install_httptmux_npm_impl() {
  if ! karnel_npm install -g httptmux &>>"$LOG_FILE"; then
    log_error "Failed to install httptmux"
    return 1
  fi
  return 0
}

_uninstall_httptmux_npm() {
  loading "Uninstalling httptmux" _uninstall_httptmux_npm_impl
}

_uninstall_httptmux_npm_impl() {
  if ! karnel_npm uninstall -g httptmux &>>"$LOG_FILE"; then
    log_error "Failed to uninstall httptmux"
    return 1
  fi
  return 0
}

install_httptmux() {
  if command -v httptmux &>/dev/null; then
    log_info "httptmux is already installed"
    return 2
  fi
  log_info "Installing httptmux..."

  mkdir -p "$(dirname "$LOG_FILE")"

  if ! command -v npm &>/dev/null; then
    pkg install nodejs-lts -y &>>"$LOG_FILE"
  fi

  _install_httptmux_npm || return 1
  log_success "httptmux installed"
  return 0
}

uninstall_httptmux() {
  if ! command -v httptmux &>/dev/null; then
    log_info "httptmux is not installed"
    return 2
  fi
  log_info "Uninstalling httptmux..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_httptmux_npm || return 1
  log_success "httptmux uninstalled"
  return 0
}

update_httptmux() {
  _check_update_needed "httptmux" "$(_get_installed_npm_version httptmux)" "$(_get_remote_npm_version httptmux)" _do_update_httptmux
}

_do_update_httptmux() {
  karnel_npm update -g httptmux &>>"$LOG_FILE" || return 1
  return 0
}

reinstall_httptmux() {
  uninstall_httptmux || [[ $? -eq 2 ]] || return 1

  install_httptmux
}
