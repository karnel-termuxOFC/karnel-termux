#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

LOG_FILE="$KARNEL_CACHE/install_npm.log"

_nestjs_dependencies() {
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

_install_nestjs_npm() {
  loading "Installing NestJS CLI" _install_nestjs_npm_impl
}

_install_nestjs_npm_impl() {
  if ! karnel_npm install -g @nestjs/cli &>>"$LOG_FILE"; then
    log_error "Failed to install NestJS CLI"
    return 1
  fi
  _fix_npm_shebang "nest"
  return 0
}

install_nestjs() {
  if command -v nest &>/dev/null; then
    log_info "NestJS CLI is already installed"
    return 2
  fi
  log_info "Installing NestJS CLI..."

  _nestjs_dependencies || return 1
  mkdir -p "$(dirname "$LOG_FILE")"

  _install_nestjs_npm || return 1
  log_success "NestJS CLI installed"
  return 0
}

_uninstall_nestjs_npm() {
  loading "Uninstalling NestJS CLI" _uninstall_nestjs_npm_impl
}

_uninstall_nestjs_npm_impl() {
  if ! karnel_npm uninstall -g @nestjs/cli &>>"$LOG_FILE"; then
    log_error "Failed to uninstall NestJS CLI"
    return 1
  fi
  return 0
}

uninstall_nestjs() {
  if ! command -v nest &>/dev/null; then
    log_info "NestJS CLI is not installed"
    return 0
  fi
  log_info "Uninstalling NestJS CLI..."
  mkdir -p "$(dirname "$LOG_FILE")"

  _uninstall_nestjs_npm || return 1
  log_success "NestJS CLI uninstalled"
  return 0
}

_update_nestjs_npm() {
  loading "Updating NestJS CLI" _update_nestjs_npm_impl
}

_update_nestjs_npm_impl() {
  if ! karnel_npm update -g @nestjs/cli &>>"$LOG_FILE"; then
    log_error "Failed to update NestJS CLI"
    return 1
  fi
  _fix_npm_shebang "nest"
  return 0
}

update_nestjs() {
  _check_update_needed "NestJS CLI" "$(_get_installed_npm_version @nestjs/cli)" "$(_get_remote_npm_version @nestjs/cli)" _update_nestjs_npm
}

reinstall_nestjs() {
  uninstall_nestjs || [[ $? -eq 2 ]] || return 1

  install_nestjs
}
