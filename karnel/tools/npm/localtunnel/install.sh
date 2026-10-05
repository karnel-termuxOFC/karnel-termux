#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_localtunnel_fix_openurl() {
  local openurl_js
  openurl_js="$(npm root -g)/localtunnel/node_modules/openurl/openurl.js"
  if [[ ! -f "$openurl_js" ]]; then
    openurl_js="$(npm root -g)/openurl/openurl.js"
  fi
  if [[ -f "$openurl_js" ]]; then
    sed -i "/default:/i\\
    case 'android':\\
        command = 'termux-open-url';\\
        break;" "$openurl_js"
  fi
}

_localtunnel_dependencies() {
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

_install_localtunnel_npm() {
  loading "Installing Localtunnel" _install_localtunnel_npm_impl
}

_install_localtunnel_npm_impl() {
  if ! karnel_npm install -g localtunnel &>>"$LOG_FILE"; then
    log_error "Failed to install Localtunnel"
    return 1
  fi
  _fix_npm_shebang "lt"
  log_info "Applying localtunnel fix for Android..."
  _localtunnel_fix_openurl &>>"$LOG_FILE"
  return 0
}

install_localtunnel() {
  if command -v lt &>/dev/null; then
    log_info "Localtunnel is already installed"
    return 2
  fi
  log_info "Installing Localtunnel..."

  _localtunnel_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_localtunnel_npm || return 1
  log_success "Localtunnel installed"
  return 0
}

_uninstall_localtunnel_npm() {
  loading "Uninstalling Localtunnel" _uninstall_localtunnel_npm_impl
}

_uninstall_localtunnel_npm_impl() {
  if ! karnel_npm uninstall -g localtunnel &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Localtunnel"
    return 1
  fi
  return 0
}

uninstall_localtunnel() {
  if ! command -v lt &>/dev/null; then
    log_info "Localtunnel is not installed"
    return 0
  fi
  log_info "Uninstalling Localtunnel..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_localtunnel_npm || return 1
  log_success "Localtunnel uninstalled"
  return 0
}

_update_localtunnel_npm() {
  loading "Updating Localtunnel" _update_localtunnel_npm_impl
}

_update_localtunnel_npm_impl() {
  if ! karnel_npm update -g localtunnel &>>"$LOG_FILE"; then
    log_error "Failed to update Localtunnel"
    return 1
  fi
  _fix_npm_shebang "lt"
  return 0
}

update_localtunnel() {
  _check_update_needed "Localtunnel" "$(_get_installed_npm_version localtunnel)" "$(_get_remote_npm_version localtunnel)" _update_localtunnel_npm
}

reinstall_localtunnel() {
  uninstall_localtunnel || [[ $? -eq 2 ]] || return 1

  install_localtunnel
}
