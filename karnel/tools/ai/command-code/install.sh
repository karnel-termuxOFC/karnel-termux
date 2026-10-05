#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
COMMAND_CODE_DATA_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/command-code"

_command_code_wrapper_owned() {
  local marker="$COMMAND_CODE_DATA_DIR/.karnel-wrapper-command-code"
  [[ -f "$marker" && -f "$PREFIX/bin/command-code" ]] || return 1
  [[ "$(sha256sum "$PREFIX/bin/command-code" 2>/dev/null)" == "$(<"$marker")" ]]
}

_command_code_alias_owned() {
  [[ -L "$PREFIX/bin/cmdc" && "$(readlink "$PREFIX/bin/cmdc")" == "$PREFIX/bin/command-code" ]]
}

_command_code_verify_ownership() {
  if [[ -e "$COMMAND_CODE_DATA_DIR" && ! -f "$COMMAND_CODE_DATA_DIR/.karnel-managed" ]]; then
    log_error "Refusing to replace unowned data directory: $COMMAND_CODE_DATA_DIR"
    return 1
  fi
  if [[ -e "$PREFIX/bin/command-code" ]] && ! _command_code_wrapper_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/command-code"
    return 1
  fi
  if [[ -e "$PREFIX/bin/cmdc" || -L "$PREFIX/bin/cmdc" ]] && ! _command_code_alias_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/cmdc"
    return 1
  fi
}

_command_code_dependencies() {
  loading "Installing dependencies" _command_code_dependencies_impl
}

_command_code_dependencies_impl() {
  declare -A DEPS=(
    ["nodejs-lts"]="node"
    ["git"]="git"
    ["ripgrep"]="rg"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if ! command -v "$bin_name" &>/dev/null; then
      if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done

  return 0
}

_install_command_code_npm() {
  loading "Installing command-code via npm" _install_command_code_npm_impl
}

_install_command_code_npm_impl() {
  mkdir -p "$COMMAND_CODE_DATA_DIR"

  if ! (cd "$COMMAND_CODE_DATA_DIR" && npm init -y &>>"$LOG_FILE"); then
    log_error "Failed to initialize npm project"
    return 1
  fi

  if ! (cd "$COMMAND_CODE_DATA_DIR" && karnel_npm install command-code@latest &>>"$LOG_FILE"); then
    log_error "Failed to install command-code package"
    return 1
  fi
  _fix_npm_shebang "command-code" || return 1

  return 0
}

_install_command_code_wrappers() {
  loading "Creating command-code and cmdc wrappers" _install_command_code_wrappers_impl
}

_command_code_installed_version() {
  if [ -f "$COMMAND_CODE_DATA_DIR/node_modules/command-code/package.json" ]; then
    grep '"version"' "$COMMAND_CODE_DATA_DIR/node_modules/command-code/package.json" | head -1 | sed -E 's/.*"version": "([^"]+)".*/\1/'
  fi
}

_install_command_code_wrappers_impl() {
  if [[ -e "$PREFIX/bin/command-code" ]] && ! _command_code_wrapper_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/command-code"
    return 1
  fi
  if [[ -e "$PREFIX/bin/cmdc" || -L "$PREFIX/bin/cmdc" ]] && ! _command_code_alias_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/cmdc"
    return 1
  fi

  local wrapper_content='#!'"$PREFIX"'/bin/bash

exec node '"$COMMAND_CODE_DATA_DIR"'/node_modules/command-code/dist/index.mjs "$@"'

  local temporary
  temporary=$(mktemp "$PREFIX/bin/.command-code.XXXXXX") || return 1
  printf '%s\n' "$wrapper_content" >"$temporary" || { rm -f "$temporary"; return 1; }
  chmod +x "$temporary" || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$PREFIX/bin/command-code" || return 1

  ln -sf "$PREFIX/bin/command-code" "$PREFIX/bin/cmdc"
	sha256sum "$PREFIX/bin/command-code" >"$COMMAND_CODE_DATA_DIR/.karnel-wrapper-command-code" || return 1
	: >"$COMMAND_CODE_DATA_DIR/.karnel-managed"

  return 0
}

install_command_code() {
  if command -v command-code &>/dev/null; then
    log_info "Command Code is already installed"
    return 2
  fi

  log_info "Installing Command Code..."

  mkdir -p "$(dirname "$LOG_FILE")"

	_command_code_verify_ownership || return 1
  _command_code_dependencies || return 1
  _install_command_code_npm || return 1
  _install_command_code_wrappers || return 1

  log_success "Command Code installed successfully"
  return 0
}

uninstall_command_code() {
  if ! command -v command-code &>/dev/null; then
    log_info "Command Code is not installed"
    return 2
  fi
  log_info "Uninstalling Command Code..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing Command Code files" _uninstall_command_code_impl || return 1

  log_success "Command Code uninstalled"
  return 0
}

_uninstall_command_code_impl() {
  _command_code_alias_owned && rm -f "$PREFIX/bin/cmdc"
  _command_code_wrapper_owned && rm -f "$PREFIX/bin/command-code"
  [[ -f "$COMMAND_CODE_DATA_DIR/.karnel-managed" ]] && rm -rf "$COMMAND_CODE_DATA_DIR"
  return 0
}

update_command_code() {
  _check_update_needed "Command Code" "$(_command_code_installed_version)" "$(_get_remote_npm_version command-code)" _update_command_code_impl
}

_update_command_code_impl() {
	_command_code_verify_ownership || return 1
  if (cd "$COMMAND_CODE_DATA_DIR" && karnel_npm update command-code &>>"$LOG_FILE"); then
    return 0
  else
    log_error "Failed to update Command Code"
    return 1
  fi
}

reinstall_command_code() {
  uninstall_command_code || [[ $? -eq 2 ]] || return 1

  install_command_code
}
