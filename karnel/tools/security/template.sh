# shellcheck shell=bash

# Template for security tool installers.
# Copy this file, then replace `tool` in the four function names and in the
# two literal _TOOL/_PKG values inside each handler.
#
# IMPORTANT: every handler declares `local _TOOL`/`local _PKG`. These files are
# all `source`d into one shared shell by `tools/security/all.sh`, so top-level
# assignments would be overwritten by the next installer and every handler
# would end up operating on the wrong package.

install_tool() {
  local _TOOL="tool" _PKG="tool"
  if command -v "$_TOOL" &>/dev/null; then
    log_info "$_TOOL is already installed"
    return 2
  fi
  log_info "Installing $_TOOL..."
  if pkg install -y "$_PKG" 2>/dev/null || apt install -y "$_PKG" 2>/dev/null; then
    if command -v "$_TOOL" &>/dev/null; then
      log_success "$_TOOL installed"
      return 0
    fi
  fi
  log_error "Failed to install $_TOOL"
  return 1
}

uninstall_tool() {
  local _TOOL="tool" _PKG="tool"
  if ! command -v "$_TOOL" &>/dev/null; then
    log_info "$_TOOL is not installed"
    return 2
  fi
  log_info "Removing $_TOOL..."
  if pkg uninstall -y "$_PKG" 2>/dev/null || apt remove -y "$_PKG" 2>/dev/null; then
    log_success "$_TOOL removed"
    return 0
  fi
  log_error "Failed to remove $_TOOL"
  return 1
}

update_tool() {
  local _TOOL="tool" _PKG="tool"
  if ! command -v "$_TOOL" &>/dev/null; then
    log_info "$_TOOL is not installed"
    return 2
  fi
  log_info "Updating $_TOOL..."
  if pkg install -y "$_PKG" 2>/dev/null || apt install -y "$_PKG" 2>/dev/null; then
    log_success "$_TOOL updated"
    return 0
  fi
  log_error "Failed to update $_TOOL"
  return 1
}

reinstall_tool() {
  uninstall_tool || [[ $? -eq 2 ]] || return 1
  install_tool
}
