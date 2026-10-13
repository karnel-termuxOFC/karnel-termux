#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"

# The npm package is only a launcher: it refuses to run until it has fetched
# its own Copilot binary into ~/.copilot-termux/current, which `setup` does.
_copilot_termux_is_ready() {
  [ -d "${HOME}/.copilot-termux/current" ] &&
    command -v copilot &>/dev/null &&
    copilot --help &>/dev/null
}

_copilot_termux_setup() {
  loading "Fetching the Copilot binary" _copilot_termux_setup_impl
}

_copilot_termux_setup_impl() {
  if ! copilot-termux setup &>>"$LOG_FILE"; then
    log_error "Failed to fetch the Copilot binary; see $LOG_FILE"
    return 1
  fi
}

install_copilot_termux() {
  # An entry on PATH that cannot run is not an installation; without this the
  # launcher npm left behind is reported as installed forever.
  if _copilot_termux_is_ready; then
    log_info "Copilot-Termux is already installed"
    return 2
  fi

  log_info "Installing Copilot-Termux..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if ! command -v npm &>/dev/null; then
    log_error "npm is required. Install Node.js first: karnel install lang --nodejs"
    return 1
  fi

  if ! karnel_npm install -g @bash0816/copilot-termux &>>"$LOG_FILE"; then
    log_error "Failed to install Copilot-Termux via npm"
    return 1
  fi
  _fix_npm_shebang "copilot-termux" || return 1

  hash -r 2>/dev/null || true

  if ! command -v copilot &>/dev/null; then
    log_error "Copilot-Termux installed but binary not on PATH"
    log_info "Try: hash -r; copilot --help"
    return 1
  fi

  if ! _copilot_termux_is_ready; then
    _copilot_termux_setup || return 1
  fi
  if ! _copilot_termux_is_ready; then
    log_error "Copilot-Termux did not start after setup; see $LOG_FILE"
    return 1
  fi

  log_success "Copilot-Termux installed"
  log_info "Run: copilot -p \"your question\""
  return 0
}

uninstall_copilot_termux() {
  if ! command -v copilot &>/dev/null; then
    log_info "Copilot-Termux is not installed"
    return 2
  fi

  log_info "Uninstalling Copilot-Termux..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if karnel_npm uninstall -g @bash0816/copilot-termux &>>"$LOG_FILE"; then
    # The fetched binary is the bulk of this install and nothing else removes
    # it; leaving it behind keeps 180 MB of a tool that is no longer there.
    rm -rf "${HOME}/.copilot-termux"
    log_success "Copilot-Termux uninstalled"
    return 0
  else
    log_error "Failed to uninstall Copilot-Termux"
    return 1
  fi
}

update_copilot_termux() {
  _check_update_needed "Copilot-Termux" \
    "$(_get_installed_npm_version @bash0816/copilot-termux)" \
    "$(_get_remote_npm_version @bash0816/copilot-termux)" \
    _do_update_copilot_termux
}

_do_update_copilot_termux() {
  log_info "Updating Copilot-Termux..."

  if karnel_npm update -g @bash0816/copilot-termux &>>"$LOG_FILE"; then
    if ! _copilot_termux_is_ready; then
      _copilot_termux_setup || return 1
    fi
    log_success "Copilot-Termux updated"
    return 0
  else
    log_error "Failed to update Copilot-Termux"
    return 1
  fi
}

reinstall_copilot_termux() {
  uninstall_copilot_termux || [[ $? -eq 2 ]] || return 1

  install_copilot_termux
}
