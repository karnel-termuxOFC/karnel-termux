#!/usr/bin/env bash

# openspec - Spec-Driven Development framework for AI workflow orchestration
# Bridges human intent and AI output with structured technical specs
# Stores specs in /openspec/ directory to guide AI agents
# Official: npm install -g @fission-ai/openspec@latest
import "@/utils/npm"
import "@/utils/log"
import "@/utils/version"
import "@/utils/npm-shebang"

install_openspec() {
  if command -v openspec &>/dev/null; then
    log_info "openspec is already installed"
    return 2
  fi

  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by openspec)"
      return 1
    fi
  fi

  log_info "Installing openspec (Spec-Driven Development framework)..."
  karnel_npm install -g @fission-ai/openspec@latest 2>/dev/null
  local rc=$?
  _fix_npm_shebang "openspec" || true

  if [[ $rc -eq 0 ]] && command -v openspec &>/dev/null; then
    log_success "openspec installed successfully"
    log_info "Run: openspec init to create /openspec/ directory"
    return 0
  else
    log_error "openspec installation failed"
    return 1
  fi
}

uninstall_openspec() {
  if ! command -v openspec &>/dev/null; then
    log_info "openspec is not installed"
    return 2
  fi

  log_info "Uninstalling openspec..."
  karnel_npm uninstall -g @fission-ai/openspec 2>/dev/null
  return $?
}

update_openspec() {
  _check_update_needed "openspec" "$(_get_installed_npm_version @fission-ai/openspec)" "$(_get_remote_npm_version @fission-ai/openspec)" _do_update_openspec
}

_do_update_openspec() {
  karnel_npm update -g @fission-ai/openspec 2>/dev/null
  local _t
  _t=$(readlink -f "$PREFIX/bin/openspec" 2>/dev/null)
  [ -f "$_t" ] && sed -i '1s|^#!/usr/bin/env node|#!/data/data/com.termux/files/usr/bin/env node|' "$_t"
  return $?
}

reinstall_openspec() {
  uninstall_openspec 2>/dev/null
  install_openspec
  return $?
}
