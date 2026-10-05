#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_ai.log"

_minimax_cli_dependencies() {
  loading "Installing dependencies" _minimax_cli_dependencies_impl
}

_minimax_cli_dependencies_impl() {
  declare -A DEPS=(
    ["nodejs-lts"]="node"
    ["git"]="git"
    ["ripgrep"]="rg"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if ! command -v "$bin_name" &>/dev/null; then
      if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done

  return 0
}

_install_minimax_cli_npm() {
  loading "Installing MiniMax CLI" _install_minimax_cli_npm_impl
}

_install_minimax_cli_npm_impl() {
  if ! karnel_npm install -g mmx-cli &>>"$LOG_FILE"; then
    log_error "Failed to install MiniMax CLI"
    return 1
  fi
  _fix_npm_shebang "mmx"

  return 0
}

install_minimax_cli() {
  if command -v mmx &>/dev/null; then
    log_info "MiniMax CLI is already installed"
    return 2
  fi

  log_info "Installing MiniMax CLI..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _minimax_cli_dependencies || return 1
  _install_minimax_cli_npm || return 1

  log_success "MiniMax CLI installed successfully"
  return 0
}

uninstall_minimax_cli() {
  if ! command -v mmx &>/dev/null; then
    log_success "MiniMax CLI is not installed"
    return 2
  fi

  log_info "Uninstalling MiniMax CLI..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing MiniMax CLI" _uninstall_minimax_cli_impl || return 1

  log_success "MiniMax CLI uninstalled successfully"
  return 0
}

_uninstall_minimax_cli_impl() {
  if ! karnel_npm uninstall -g mmx-cli &>>"$LOG_FILE"; then
    log_error "Failed to uninstall MiniMax CLI"
    return 1
  fi
  return 0
}

update_minimax_cli() {
  _check_update_needed "MiniMax CLI" "$(_get_installed_npm_version mmx-cli)" "$(_get_remote_npm_version mmx-cli)" _update_minimax_cli_impl
}

_update_minimax_cli_impl() {
  if ! karnel_npm update -g mmx-cli &>>"$LOG_FILE"; then
    log_error "Failed to update MiniMax CLI"
    return 1
  fi
  _fix_npm_shebang "mmx"
  return 0
}

reinstall_minimax_cli() {
  uninstall_minimax_cli || [[ $? -eq 2 ]] || return 1

  install_minimax_cli
}
