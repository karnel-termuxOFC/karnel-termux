#!/usr/bin/env bash

install_steghide() {
  local _TOOL="steghide" _PKG="steghide"
  if command -v "$_TOOL" &>/dev/null; then log_info "$_TOOL is already installed"; return 2; fi
  log_info "Installing $_TOOL..."
  if pkg install -y "$_PKG" 2>/dev/null || apt install -y "$_PKG" 2>/dev/null; then
    if command -v "$_TOOL" &>/dev/null; then log_success "$_TOOL installed"; return 0; fi
  fi
  log_error "Failed to install $_TOOL"; return 1
}

uninstall_steghide() {
  local _TOOL="steghide" _PKG="steghide"
  if ! command -v "$_TOOL" &>/dev/null; then log_info "$_TOOL is not installed"; return 2; fi
  log_info "Removing $_TOOL..."
  if pkg uninstall -y "$_PKG" 2>/dev/null || apt remove -y "$_PKG" 2>/dev/null; then
    log_success "$_TOOL removed"; return 0
  fi
  log_error "Failed to remove $_TOOL"; return 1
}

update_steghide() {
  local _TOOL="steghide" _PKG="steghide"
  log_info "Updating $_TOOL..."
  if pkg install -y "$_PKG" 2>/dev/null || apt install -y "$_PKG" 2>/dev/null; then
    log_success "$_TOOL updated"; return 0
  fi
  log_error "Failed to update $_TOOL"; return 1
}

reinstall_steghide() { uninstall_steghide || [[ $? -eq 2 ]] || return 1; install_steghide; }
