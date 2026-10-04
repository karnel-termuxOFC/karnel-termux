#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"
import "@/utils/downloaded-python"

LOG_FILE="$KARNEL_CACHE/install_network.log"

install_dedsec_network() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/DedSec%27s%20Network.py"
  local TOOL_DIR="$KARNEL_DATA/network/dedsec-network"
  local BIN_NAME="dedsec-network"
  log_info "Installing DedSec Network Toolkit (scanner + OSINT + pentest)..."
  mkdir -p "$(dirname "$LOG_FILE")"
  if ! command -v python3 &>/dev/null; then pkg install python -y &>>"$LOG_FILE" || return 1; fi

  _downloaded_python_install "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return $?
  log_success "DedSec Network Toolkit installed"
  return 0
}

uninstall_dedsec_network() {
  local BIN_NAME="dedsec-network"
  local TOOL_DIR="$KARNEL_DATA/network/dedsec-network"
  log_info "Uninstalling DedSec Network Toolkit..."
  _downloaded_python_uninstall "$BIN_NAME" "$TOOL_DIR" || return $?
  log_success "DedSec Network Toolkit uninstalled"
  return 0
}

update_dedsec_network() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/DedSec%27s%20Network.py"
  local TOOL_DIR="$KARNEL_DATA/network/dedsec-network"
  local BIN_NAME="dedsec-network"
  log_info "Updating DedSec Network Toolkit..."
  _downloaded_python_update "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return 1
  log_success "DedSec Network Toolkit updated"
  return 0
}

reinstall_dedsec_network() {
  uninstall_dedsec_network || [[ $? -eq 2 ]] || return 1

  install_dedsec_network
}
