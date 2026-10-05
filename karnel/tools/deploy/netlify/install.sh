#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

LOG_FILE="${LOG_FILE:-${KARNEL_CACHE:-$HOME/.cache/karnel}/install_deploy.log}"

NETLIFY_VERSION="27.1.1"
NETLIFY_MARKER="$PREFIX/share/karnel-installers/netlify"

_netlify_is_owned() {
  local binary
  binary=$(command -v netlify) || return 1
  managed_file_matches "$binary" "$NETLIFY_MARKER"
}

_netlify_node_supported() {
  local version required
  version="$(node --version 2>/dev/null | sed 's/^v//')"
  [[ -n "$version" ]] || return 1
  required="$(karnel_npm view "netlify-cli@$NETLIFY_VERSION" engines.node 2>/dev/null | tr -d "'" | sed 's/[<>=~^ ]//g')"
  required="${required:-18.0.0}"
  [[ "$(printf '%s\n%s\n' "$required" "$version" | sort -V | head -1)" == "$required" ]]
}

install_netlify() {
  if command -v netlify &>/dev/null && netlify --version &>/dev/null; then
    log_info "Netlify CLI is already installed"
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
  if ! _netlify_node_supported; then
    log_error "Netlify CLI requires Node.js (see: npm view netlify-cli@$NETLIFY_VERSION engines.node); update Node.js and retry."
    return 1
  fi
  log_info "Installing Netlify CLI..."
  if ! karnel_npm install -g "netlify-cli@$NETLIFY_VERSION" --legacy-peer-deps &>>"$LOG_FILE"; then
    log_error "Failed to install Netlify CLI (see $LOG_FILE)"
    return 1
  fi
  local binary
  binary=$(command -v netlify) || { log_error "Netlify CLI was not found after installation"; return 1; }
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$binary" &>/dev/null
  if ! netlify --version &>/dev/null; then
    log_error "Netlify CLI did not start after installation"
    return 1
  fi
  if ! record_managed_file "$binary" "$NETLIFY_MARKER"; then
    log_error "Failed to record Netlify CLI ownership"
    return 1
  fi
  log_success "Netlify CLI installed"
}

uninstall_netlify() {
  if ! _netlify_is_owned; then
    log_warn "Preserving Netlify CLI not managed by Karnel"
    return 2
  fi
  log_info "Uninstalling Netlify CLI..."
  if ! karnel_npm uninstall -g netlify-cli &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Netlify CLI (see $LOG_FILE)"
    return 1
  fi
  rm -f "$NETLIFY_MARKER"
  log_success "Netlify CLI uninstalled"
}

update_netlify() {
  _check_update_needed "Netlify CLI" "$(_get_installed_npm_version netlify-cli)" "$(_get_remote_npm_version netlify-cli)" _do_update_netlify
}

_do_update_netlify() {
  if ! _netlify_is_owned; then
    log_warn "Skipping update: Netlify CLI not managed by Karnel"
    return 2
  fi
  if ! karnel_npm update -g netlify-cli --legacy-peer-deps &>>"$LOG_FILE"; then
    log_error "Failed to update Netlify CLI (see $LOG_FILE)"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v netlify)" &>/dev/null
  record_managed_file "$(command -v netlify)" "$NETLIFY_MARKER" || return 1
  return 0
}

reinstall_netlify() {
  uninstall_netlify
  local rc=$?
  [[ "$rc" == 0 || "$rc" == 2 ]] || return "$rc"
  install_netlify
}
