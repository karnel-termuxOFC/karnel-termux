#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_auto.log"

_n8n_dependencies() {
  declare -A DEPS=(
    ["nodejs-lts"]="node"
    ["python"]="python"
    ["sqlite"]="sqlite"
    ["build-essential"]=""
    ["binutils"]=""
    ["make"]="make"
    ["clang"]="cc"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if [[ -n "$bin_name" ]] && command -v "$bin_name" &>/dev/null; then
      continue
    fi
    if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
      log_error "Failed to install $pkg_name"
      return 1
    fi
  done

  log_success "n8n dependencies installed"
  return 0
}

_install_n8n_impl() {
  _n8n_dependencies || return 1

  mkdir -p "$(dirname "$LOG_FILE")"
  export GYP_DEFINES="android_ndk_path=''"
  export ANDROID_API_LEVEL=24

  if karnel_npm install -g n8n &>>"$LOG_FILE"; then
    log_success "n8n installed"
    return 0
  else
    log_error "Failed to install n8n"
    return 1
  fi
}

install_n8n() {
  if command -v n8n &>/dev/null; then
    log_info "n8n is already installed"
    return 2
  fi
  log_info "Installing n8n..."
  loading "Installing n8n" _install_n8n_impl
}

_uninstall_n8n_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"

  if karnel_npm uninstall -g n8n &>>"$LOG_FILE"; then
    log_success "n8n uninstalled"
    return 0
  else
    log_error "Failed to uninstall n8n"
    return 1
  fi
}

uninstall_n8n() {
  if ! command -v n8n &>/dev/null; then
    log_info "n8n is not installed"
    return 0
  fi
  log_info "Uninstalling n8n..."
  loading "Uninstalling n8n" _uninstall_n8n_impl
}

_update_n8n_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"
  export GYP_DEFINES="android_ndk_path=''"
  export ANDROID_API_LEVEL=24

  if karnel_npm update -g n8n &>>"$LOG_FILE"; then
    log_success "n8n updated"
    return 0
  else
    log_error "Failed to update n8n"
    return 1
  fi
}

update_n8n() {
  _check_update_needed "n8n" "$(_get_installed_npm_version n8n)" "$(_get_remote_npm_version n8n)" _update_n8n_impl
}

reinstall_n8n() {
  uninstall_n8n || [[ $? -eq 2 ]] || return 1

  install_n8n
}
