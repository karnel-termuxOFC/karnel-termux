#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"

_mistral_vibe_dependencies() {
  loading "Installing dependencies" _mistral_vibe_dependencies_impl
}

_mistral_vibe_dependencies_impl() {
  declare -A DEPS=(
    ["python"]="python"
    ["clang"]="cc"
    ["make"]="make"
    ["rust"]="rust"
    ["libffi"]=""
    ["openssl"]=""
    ["pkg-config"]="pkg-config"
    ["git"]="git"
    ["ripgrep"]="rg"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if [[ -n "$bin_name" ]] && command -v "$bin_name" &>/dev/null; then
      continue
    fi
    if [[ -z "$bin_name" ]] && dpkg -s "$pkg_name" &>/dev/null; then
      continue
    fi
    if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
      log_error "Failed to install $pkg_name"
      return 1
    fi
  done

  pip install --upgrade pip setuptools wheel &>>"$LOG_FILE"
  return 0
}

_install_mistral_vibe_pip() {
  loading "Installing Mistral Vibe" _install_mistral_vibe_pip_impl
}

_install_mistral_vibe_pip_impl() {
  export ANDROID_API_LEVEL=24
  export GYP_DEFINES="android_ndk_path=''"

  # Building cffi, cryptography, tree-sitter and friends from source takes far
  # longer than a phone has patience for and is not needed: PyPI already ships
  # wheels for every one of them that this install pulls in.
  if ! pip install --prefer-binary mistral-vibe &>>"$LOG_FILE"; then
    log_error "Failed to install Mistral Vibe"
    return 1
  fi

  return 0
}

install_mistral_vibe() {
  if command -v vibe &>/dev/null; then
    log_info "Mistral Vibe is already installed"
    return 2
  fi

  log_info "Installing Mistral Vibe..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _mistral_vibe_dependencies || return 1
  _install_mistral_vibe_pip || return 1

  log_success "Mistral Vibe installed"
  return 0
}

uninstall_mistral_vibe() {
  if ! command -v vibe &>/dev/null; then
    log_info "Mistral Vibe is not installed"
    return 2
  fi
  log_info "Uninstalling Mistral Vibe..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing Mistral Vibe" _uninstall_mistral_vibe_impl || return 1

  log_success "Mistral Vibe uninstalled"
  return 0
}

_uninstall_mistral_vibe_impl() {
  if ! pip uninstall mistral-vibe -y &>>"$LOG_FILE"; then
    log_error "Failed to uninstall Mistral Vibe"
    return 1
  fi
  return 0
}

update_mistral_vibe() {
  _check_update_needed "Mistral Vibe" "$(_get_installed_version vibe)" "$(_get_remote_pip_version mistral-vibe)" _update_mistral_vibe_impl
}

_update_mistral_vibe_impl() {
  export ANDROID_API_LEVEL=24
  export GYP_DEFINES="android_ndk_path=''"

  if ! pip install --upgrade mistral-vibe &>>"$LOG_FILE"; then
    log_error "Failed to update Mistral Vibe"
    return 1
  fi
  return 0
}

reinstall_mistral_vibe() {
  uninstall_mistral_vibe || [[ $? -eq 2 ]] || return 1

  install_mistral_vibe
}
