#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"
import "@/utils/downloaded-python"

LOG_FILE="$KARNEL_CACHE/install_utils.log"

_qrcode_dependencies() {
  if ! command -v python3 &>/dev/null && ! pkg install python -y &>>"$LOG_FILE"; then
    return 1
  fi
  if ! python3 -c 'import PIL' &>/dev/null && ! pkg install python-pillow -y &>>"$LOG_FILE"; then
    return 1
  fi
  if ! python3 -c 'import qrcode' &>/dev/null && ! python3 -m pip install --no-deps qrcode &>>"$LOG_FILE"; then
    return 1
  fi
  python3 -c 'import qrcode, PIL' &>/dev/null
}

install_qrcode() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/QR%20Code%20Generator.py"
  local TOOL_DIR="$KARNEL_DATA/utils/qrcode"
  local BIN_NAME="qrcode"
  log_info "Installing QR Code Generator..."
  mkdir -p "$(dirname "$LOG_FILE")" "$TOOL_DIR"
  _qrcode_dependencies || { log_error "Failed to install QR Code Generator dependencies"; return 1; }
  _downloaded_python_install "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return $?
  log_success "QR Code Generator installed"
  return 0
}

uninstall_qrcode() {
  local BIN_NAME="qrcode"
  local TOOL_DIR="$KARNEL_DATA/utils/qrcode"
  log_info "Uninstalling QR Code Generator..."
  _downloaded_python_uninstall "$BIN_NAME" "$TOOL_DIR" || return $?
  log_success "QR Code Generator uninstalled"
  return 0
}

update_qrcode() {
  local DOWNLOAD_URL="https://raw.githubusercontent.com/dedsec1121fk/DedSec/87d69293f4b89b8ab114fa644074629e86313182/Scripts/Network%20Tools/QR%20Code%20Generator.py"
  local TOOL_DIR="$KARNEL_DATA/utils/qrcode"
  local BIN_NAME="qrcode"
  log_info "Updating QR Code Generator..."
  _qrcode_dependencies || { log_error "Failed to install QR Code Generator dependencies"; return 1; }
  _downloaded_python_update "$BIN_NAME" "$TOOL_DIR" "$DOWNLOAD_URL" || return 1
  log_success "QR Code Generator updated"
  return 0
}

reinstall_qrcode() {
  uninstall_qrcode || [[ $? -eq 2 ]] || return 1

  install_qrcode
}
