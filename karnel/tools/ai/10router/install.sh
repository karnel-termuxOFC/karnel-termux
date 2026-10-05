#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
TENROUTER_PACKAGE="@techysy/10router"

_10router_dependencies() {
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    return 0
  fi
  pkg install nodejs-lts -y &>>"$LOG_FILE"
}

_install_10router_impl() {
  if ! karnel_npm install -g "$TENROUTER_PACKAGE" &>>"$LOG_FILE"; then
    log_error "Failed to install 10Router"
    return 1
  fi
  _fix_npm_shebang "10router" || return 1
  command -v 10router &>/dev/null
}

install_10router() {
  if command -v 10router &>/dev/null; then
    _fix_npm_shebang "10router" || return 1
    log_info "10Router is already installed"
    return 2
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  _10router_dependencies || { log_error "Failed to install Node.js"; return 1; }
  loading "Installing 10Router" _install_10router_impl || return 1
  log_success "10Router installed"
}

_uninstall_10router_impl() {
  karnel_npm uninstall -g "$TENROUTER_PACKAGE" &>>"$LOG_FILE"
}

uninstall_10router() {
  if ! command -v 10router &>/dev/null; then
    log_info "10Router is not installed"
    return 2
  fi
  loading "Removing 10Router" _uninstall_10router_impl || { log_error "Failed to uninstall 10Router"; return 1; }
  log_success "10Router uninstalled"
}

_update_10router_impl() {
  if ! karnel_npm update -g "$TENROUTER_PACKAGE" &>>"$LOG_FILE"; then
    log_error "Failed to update 10Router"
    return 1
  fi
  _fix_npm_shebang "10router"
}

update_10router() {
  _check_update_needed "10Router" "$(_get_installed_npm_version "$TENROUTER_PACKAGE")" "$(_get_remote_npm_version "$TENROUTER_PACKAGE")" _update_10router_impl
}

reinstall_10router() {
  uninstall_10router || [[ $? -eq 2 ]] || return 1
  install_10router
}
