#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_ngrok_dependencies() {
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

_install_ngrok_npm() {
  loading "Installing Ngrok" _install_ngrok_npm_impl
}

_install_ngrok_npm_impl() {
  if ! karnel_npm install -g ngrok &>>"$LOG_FILE"; then
    log_error "Failed to install ngrok"
    return 1
  fi
  _fix_npm_shebang "ngrok"
  return 0
}

install_ngrok() {
  if command -v ngrok &>/dev/null; then
    log_info "Ngrok is already installed"
    return 2
  fi
  log_info "Installing Ngrok..."

  _ngrok_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_ngrok_npm || return 1
  log_success "Ngrok installed"
  return 0
}

_uninstall_ngrok_npm() {
  loading "Uninstalling Ngrok" _uninstall_ngrok_npm_impl
}

_uninstall_ngrok_npm_impl() {
  if ! karnel_npm uninstall -g ngrok &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Ngrok"
    return 1
  fi
  return 0
}

uninstall_ngrok() {
  if ! command -v ngrok &>/dev/null; then
    log_info "Ngrok is not installed"
    return 0
  fi
  log_info "Uninstalling Ngrok..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_ngrok_npm || return 1
  log_success "Ngrok uninstalled"
  return 0
}

_update_ngrok_npm() {
  loading "Updating Ngrok" _update_ngrok_npm_impl
}

_update_ngrok_npm_impl() {
  if ! karnel_npm update -g ngrok &>>"$LOG_FILE"; then
    log_error "Failed to update Ngrok"
    return 1
  fi
  _fix_npm_shebang "ngrok"
  return 0
}

update_ngrok() {
  _check_update_needed "Ngrok" "$(_get_installed_npm_version ngrok)" "$(_get_remote_npm_version ngrok)" _update_ngrok_npm
}

reinstall_ngrok() {
  uninstall_ngrok || [[ $? -eq 2 ]] || return 1

  install_ngrok
}
