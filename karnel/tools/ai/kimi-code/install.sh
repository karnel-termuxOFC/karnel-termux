#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_ai.log"

_kimi_code_dependencies() {
  loading "Installing dependencies" _kimi_code_dependencies_impl
}

_kimi_code_dependencies_impl() {
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

_install_kimi_code_npm() {
  loading "Installing Kimi Code" _install_kimi_code_npm_impl
}

_install_kimi_code_npm_impl() {
  if ! karnel_npm install -g @moonshot-ai/kimi-code &>>"$LOG_FILE"; then
    log_error "Failed to install Kimi Code"
    return 1
  fi
  _fix_npm_shebang "kimi"

  return 0
}

install_kimi_code() {
  if command -v kimi &>/dev/null; then
    log_info "Kimi Code is already installed"
    return 2
  fi

  log_info "Installing Kimi Code..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _kimi_code_dependencies || return 1
  _install_kimi_code_npm || return 1

  log_success "Kimi Code installed successfully"
  return 0
}

uninstall_kimi_code() {
  if ! command -v kimi &>/dev/null; then
    log_success "Kimi Code is not installed"
    return 2
  fi

  log_info "Uninstalling Kimi Code..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing Kimi Code" _uninstall_kimi_code_impl || return 1

  log_success "Kimi Code uninstalled successfully"
  return 0
}

_uninstall_kimi_code_impl() {
  if ! karnel_npm uninstall -g @moonshot-ai/kimi-code &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Kimi Code"
    return 1
  fi
  return 0
}

update_kimi_code() {
  _check_update_needed "Kimi Code" "$(_get_installed_npm_version @moonshot-ai/kimi-code)" "$(_get_remote_npm_version @moonshot-ai/kimi-code)" _update_kimi_code_impl
}

_update_kimi_code_impl() {
  if ! karnel_npm update -g @moonshot-ai/kimi-code &>>"$LOG_FILE"; then
    log_error "Failed to update Kimi Code"
    return 1
  fi
  _fix_npm_shebang "kimi"
  return 0
}

reinstall_kimi_code() {
  uninstall_kimi_code || [[ $? -eq 2 ]] || return 1

  install_kimi_code
}
