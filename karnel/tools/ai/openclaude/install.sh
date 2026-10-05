#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_ai.log"

_openclaude_dependencies() {
  loading "Installing dependencies" _openclaude_dependencies_impl
}

_openclaude_dependencies_impl() {
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

_install_openclaude_npm() {
  loading "Installing OpenClaude" _install_openclaude_npm_impl
}

_install_openclaude_npm_impl() {
  export GYP_DEFINES="android_ndk_path=''"
  export ANDROID_API_LEVEL=24

  if ! karnel_npm install -g @gitlawb/openclaude &>>"$LOG_FILE"; then
    log_error "Failed to install OpenClaude"
    return 1
  fi
  _fix_npm_shebang "openclaude"

  return 0
}

install_openclaude() {
  if command -v openclaude &>/dev/null; then
    log_info "OpenClaude is already installed"
    return 2
  fi
  log_info "Installing OpenClaude..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _openclaude_dependencies || return 1
  _install_openclaude_npm || return 1

  log_success "OpenClaude installed"
  return 0
}

uninstall_openclaude() {
  if ! command -v openclaude &>/dev/null; then
    log_info "OpenClaude is not installed"
    return 2
  fi
  log_info "Uninstalling OpenClaude..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing OpenClaude" _uninstall_openclaude_impl || return 1

  log_success "OpenClaude uninstalled"
  return 0
}

_uninstall_openclaude_impl() {
  if ! karnel_npm uninstall -g @gitlawb/openclaude &>>"$LOG_FILE"; then
    log_error "Failed to uninstall OpenClaude"
    return 1
  fi
  return 0
}

update_openclaude() {
  _check_update_needed "OpenClaude" "$(_get_installed_npm_version @gitlawb/openclaude)" "$(_get_remote_npm_version @gitlawb/openclaude)" _update_openclaude_impl
}

_update_openclaude_impl() {
  export GYP_DEFINES="android_ndk_path=''"
  export ANDROID_API_LEVEL=24

  if ! karnel_npm update -g @gitlawb/openclaude &>>"$LOG_FILE"; then
    log_error "Failed to update OpenClaude"
    return 1
  fi
  _fix_npm_shebang "openclaude"
  return 0
}

reinstall_openclaude() {
  uninstall_openclaude || [[ $? -eq 2 ]] || return 1

  install_openclaude
}
