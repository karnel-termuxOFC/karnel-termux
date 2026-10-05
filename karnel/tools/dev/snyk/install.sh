#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_dev.log"

_install_snyk_npm() {
  loading "Installing Snyk via npm" _install_snyk_npm_impl
}

_install_snyk_npm_impl() {
  if ! karnel_npm install -g snyk &>>"$LOG_FILE"; then
    log_error "Failed to install Snyk"
    return 1
  fi
  return 0
}

_uninstall_snyk_npm() {
  loading "Uninstalling Snyk" _uninstall_snyk_npm_impl
}

_uninstall_snyk_npm_impl() {
  if ! karnel_npm uninstall -g snyk &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Snyk"
    return 1
  fi
  return 0
}

install_snyk() {
  if command -v snyk &>/dev/null; then
    log_info "Snyk is already installed"
    return 2
  fi
  log_info "Installing Snyk..."

  mkdir -p "$(dirname "$LOG_FILE")"

  if ! command -v npm &>/dev/null; then
    pkg install nodejs-lts -y &>>"$LOG_FILE"
  fi

  _install_snyk_npm || return 1
  log_success "Snyk installed"
  return 0
}

uninstall_snyk() {
  if ! command -v snyk &>/dev/null; then
    log_info "Snyk is not installed"
    return 2
  fi
  log_info "Uninstalling Snyk..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_snyk_npm || return 1
  log_success "Snyk uninstalled"
  return 0
}

update_snyk() {
  _check_update_needed "Snyk" "$(_get_installed_npm_version snyk)" "$(_get_remote_npm_version snyk)" _do_update_snyk
}

_do_update_snyk() {
  karnel_npm update -g snyk &>>"$LOG_FILE" || return 1
  return 0
}

reinstall_snyk() {
  uninstall_snyk || [[ $? -eq 2 ]] || return 1

  install_snyk
}
