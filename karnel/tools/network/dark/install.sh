#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"
import "@/utils/downloaded-python"

LOG_FILE="$KARNEL_CACHE/install_network.log"

install_dark() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/Dark.py"
  local TOOL_DIR="$KARNEL_DATA/network/dark"
  local BIN_NAME="dark"
  log_info "Installing Dark Web OSINT (Tor crawler + scraper)..."
  mkdir -p "$(dirname "$LOG_FILE")"
  if ! command -v python3 &>/dev/null; then pkg install python -y &>>"$LOG_FILE" || return 1; fi
  if ! command -v tor &>/dev/null; then pkg install tor -y &>>"$LOG_FILE" || return 1; fi

  _downloaded_python_install "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return $?
  log_success "Dark Web OSINT installed"
  return 0
}

uninstall_dark() {
  local BIN_NAME="dark"
  local TOOL_DIR="$KARNEL_DATA/network/dark"
  log_info "Uninstalling Dark Web OSINT..."
  _downloaded_python_uninstall "$BIN_NAME" "$TOOL_DIR" || return $?
  log_success "Dark Web OSINT uninstalled"
  return 0
}

update_dark() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/Dark.py"
  local TOOL_DIR="$KARNEL_DATA/network/dark"
  local BIN_NAME="dark"
  log_info "Updating Dark Web OSINT..."
  _downloaded_python_update "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return 1
  log_success "Dark Web OSINT updated"
  return 0
}

reinstall_dark() {
  uninstall_dark || [[ $? -eq 2 ]] || return 1

  install_dark
}
