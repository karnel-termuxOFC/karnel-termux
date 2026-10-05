#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_vercel_dependencies() {
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

_install_vercel_npm() {
  loading "Installing Vercel CLI" _install_vercel_npm_impl
}

_install_vercel_npm_impl() {
  if ! karnel_npm install -g vercel &>>"$LOG_FILE"; then
    log_error "Failed to install Vercel CLI"
    return 1
  fi
  _fix_npm_shebang "vercel"
  return 0
}

install_vercel() {
  if command -v vercel &>/dev/null; then
    log_info "Vercel CLI is already installed"
    return 2
  fi
  log_info "Installing Vercel CLI..."

  _vercel_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_vercel_npm || return 1
  log_success "Vercel CLI installed"
  return 0
}

_uninstall_vercel_npm() {
  loading "Uninstalling Vercel CLI" _uninstall_vercel_npm_impl
}

_uninstall_vercel_npm_impl() {
  if ! karnel_npm uninstall -g vercel &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Vercel CLI"
    return 1
  fi
  return 0
}

uninstall_vercel() {
  if ! command -v vercel &>/dev/null; then
    log_info "Vercel CLI is not installed"
    return 0
  fi
  log_info "Uninstalling Vercel CLI..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_vercel_npm || return 1
  log_success "Vercel CLI uninstalled"
  return 0
}

_update_vercel_npm() {
  loading "Updating Vercel CLI" _update_vercel_npm_impl
}

_update_vercel_npm_impl() {
  if ! karnel_npm update -g vercel &>>"$LOG_FILE"; then
    log_error "Failed to update Vercel CLI"
    return 1
  fi
  _fix_npm_shebang "vercel"
  return 0
}

update_vercel() {
  _check_update_needed "Vercel CLI" "$(_get_installed_npm_version vercel)" "$(_get_remote_npm_version vercel)" _update_vercel_npm
}

reinstall_vercel() {
  uninstall_vercel || [[ $? -eq 2 ]] || return 1

  install_vercel
}
