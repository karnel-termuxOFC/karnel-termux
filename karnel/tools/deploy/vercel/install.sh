#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

LOG_FILE="${LOG_FILE:-${KARNEL_CACHE:-$HOME/.cache/karnel}/install_deploy.log}"

VERCEL_MARKER="$PREFIX/share/karnel-installers/vercel"

_vercel_is_owned() {
  local binary
  binary=$(command -v vercel) || return 1
  managed_file_matches "$binary" "$VERCEL_MARKER"
}

install_vercel() {
  if command -v vercel &>/dev/null; then
    log_info "Vercel CLI is already installed"
    return 2
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    log_info "Installing Node.js..."
    if ! pkg install -y nodejs-lts &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js"
      return 1
    fi
  fi
  log_info "Installing Vercel CLI..."
  if ! karnel_npm install -g vercel --legacy-peer-deps &>>"$LOG_FILE"; then
    log_error "Failed to install Vercel CLI (see $LOG_FILE)"
    return 1
  fi
  local binary
  binary=$(command -v vercel) || { log_error "Vercel CLI was not found after installation"; return 1; }
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$binary" &>/dev/null
  if ! record_managed_file "$binary" "$VERCEL_MARKER"; then
    log_error "Failed to record Vercel CLI ownership"
    return 1
  fi
  log_success "Vercel CLI installed"
}

uninstall_vercel() {
  if ! _vercel_is_owned; then
    log_warn "Preserving Vercel CLI not managed by Karnel"
    return 2
  fi
  log_info "Uninstalling Vercel CLI..."
  if ! karnel_npm uninstall -g vercel &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Vercel CLI (see $LOG_FILE)"
    return 1
  fi
  rm -f "$VERCEL_MARKER"
  log_success "Vercel CLI uninstalled"
}

update_vercel() {
  _check_update_needed "Vercel CLI" "$(_get_installed_npm_version vercel)" "$(_get_remote_npm_version vercel)" _do_update_vercel
}

_do_update_vercel() {
  if ! _vercel_is_owned; then
    log_warn "Skipping update: Vercel CLI not managed by Karnel"
    return 2
  fi
  if ! karnel_npm update -g vercel --legacy-peer-deps &>>"$LOG_FILE"; then
    log_error "Failed to update Vercel CLI (see $LOG_FILE)"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v vercel)" &>/dev/null
  record_managed_file "$(command -v vercel)" "$VERCEL_MARKER" || return 1
  return 0
}

reinstall_vercel() {
  uninstall_vercel
  local rc=$?
  [[ "$rc" == 0 || "$rc" == 2 ]] || return "$rc"
  install_vercel
}
