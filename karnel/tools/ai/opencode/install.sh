#!/usr/bin/env bash
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"
import "@/utils/colors"
import "@/utils/proot"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
OPENCODE_DATA_DIR="$HOME/.local/share/karnel-data/opencode"

_install_opencode_deps() {
  loading "Installing glibc and dependencies" _install_opencode_deps_impl
}

_install_opencode_deps_impl() {
  install_glibc || return 1
  declare -A DEPS=(
    ["git"]="git"
    ["ripgrep"]="rg"
    ["python"]="python"
    ["clang"]="cc"
    ["jq"]="jq"
    ["nodejs-lts"]="node"
    ["curl"]="curl"
    ["tar"]="tar"
  )
  install_deps DEPS || return 1
  return 0
}

_download_opencode_binary() {
  loading "Downloading OpenCode" _download_opencode_binary_impl
}

_download_opencode_binary_impl() {
  local latest_version
  latest_version=$(github_latest_tag anomalyco/opencode)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest OpenCode version"
    return 1
  fi

  mkdir -p "$OPENCODE_DATA_DIR"
  github_download_and_extract \
    anomalyco/opencode "$latest_version" \
    "opencode-linux-arm64.tar.gz" "$OPENCODE_DATA_DIR" || return 1

  if [ ! -f "$OPENCODE_DATA_DIR/opencode" ]; then
    log_error "OpenCode binary not found after extraction"
    return 1
  fi
  chmod +x "$OPENCODE_DATA_DIR/opencode"
  return 0
}

_compile_opencode_helper() {
  loading "Compiling helper" _compile_opencode_helper_impl
}

_compile_opencode_helper_impl() {
  compile_helper \
    "$KARNEL_PATH/tools/ai/opencode/helper/opencode_helper.c" \
    "$PREFIX/bin/opencode" || return 1
  return 0
}

_install_opencode_native() {
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) log_error "Native OpenCode installation currently supports ARM64 only"; return 1 ;;
  esac
  _install_opencode_deps || return 1
  _download_opencode_binary || return 1
  _compile_opencode_helper || return 1
  log_success "OpenCode installed natively"
  return 0
}

_install_opencode_proot() {
  loading "Installing OpenCode (proot-distro)" _install_opencode_proot_impl
}

_install_opencode_proot_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"
  proot_install_ubuntu ubuntu:24.04

  proot_ubuntu /bin/bash -c \
    'apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates nodejs npm' \
    &>>"$LOG_FILE"

  proot_ubuntu /bin/bash -c '
    export SHELL=/bin/bash
    export TMPDIR=/tmp
    export HOME=/root
    npm install -g opencode-ai@1.18.15
  ' &>>"$LOG_FILE"

  proot_ubuntu /bin/bash -c 'touch /root/.opencode/.karnel-managed' &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(detect_ubuntu_root)"
  if [ -z "$ubuntu_root" ]; then
    log_error "Ubuntu rootfs not found"
    return 1
  fi

  local opencode_bin="$ubuntu_root/root/.opencode/bin/opencode"
  if [ ! -f "$opencode_bin" ]; then
    log_error "OpenCode binary not found after install"
    return 1
  fi

  generate_wrapper \
    "$KARNEL_PATH/tools/ai/opencode/bin/opencode" \
    "$ubuntu_root" "$PREFIX/bin/opencode" || return 1

  if ! grep -q '.opencode/bin' "$ubuntu_root/root/.bashrc" 2>/dev/null; then
    printf '\n# opencode\nexport PATH=/root/.opencode/bin:$PATH\n# end opencode\n' >>"$ubuntu_root/root/.bashrc"
  fi

  return 0
}

install_opencode() {
  if command -v opencode &>/dev/null; then
    log_info "OpenCode is already installed"
    return 2
  fi

  log_info "Select installation method for OpenCode:"
  read_select "Installation method" SELECTED_METHOD \
    "Native (recommended) - Compile with glibc support" \
    "Proot-distro (alternative) - Ubuntu container"

  case "$SELECTED_METHOD" in
  *Native*) _install_opencode_native ;;
  *Proot-distro*) _install_opencode_proot ;;
  esac
}

uninstall_opencode() {
  log_info "Uninstalling OpenCode..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if [ ! -f "$PREFIX/bin/opencode" ]; then
    log_warn "OpenCode is not installed"
    return 1
  fi

  if [ -f "$OPENCODE_DATA_DIR/opencode" ]; then
    rm -f "$PREFIX/bin/opencode"
    rm -rf "$OPENCODE_DATA_DIR"
    log_success "OpenCode (native) uninstalled"
    return 0
  fi

  if proot_ubuntu test -f /root/.opencode/.karnel-managed &>>"$LOG_FILE"; then
    proot_ubuntu /bin/bash -c 'rm -rf /root/.opencode' &>>"$LOG_FILE"
  else
    log_warn "OpenCode data in the Ubuntu container was not installed by Karnel — leaving it untouched"
  fi
  local ubuntu_root
  ubuntu_root="$(detect_ubuntu_root)/root/.bashrc"
  if [ -f "$ubuntu_root" ]; then
    sed -i '/# opencode$/,/# end opencode$/d' "$ubuntu_root"
  fi

  if rm -f "$PREFIX/bin/opencode" &>>"$LOG_FILE"; then
    log_success "OpenCode (proot-distro) uninstalled"
    return 0
  else
    log_error "Failed to uninstall OpenCode"
    return 1
  fi
}

update_opencode() {
  _check_update_needed "OpenCode" "$(_get_installed_version opencode)" "$(_get_remote_github_version anomalyco/opencode)" _do_update_opencode
}

_do_update_opencode() {
  if [ -f "$OPENCODE_DATA_DIR/opencode" ]; then
    _install_opencode_native
    return $?
  fi

  if proot_ubuntu test -f /root/.opencode/.karnel-managed &>>"$LOG_FILE"; then
    proot_ubuntu /bin/bash -c 'rm -rf /root/.opencode' &>>"$LOG_FILE"
  else
    log_warn "Existing OpenCode in the Ubuntu container was not installed by Karnel — aborting update to avoid data loss"
    return 1
  fi
  proot_ubuntu /bin/bash -c '
    export SHELL=/bin/bash
    export TMPDIR=/tmp
    export HOME=/root
    npm install -g opencode-ai@1.18.15
  ' &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(detect_ubuntu_root)"
  if [ -z "$ubuntu_root" ] || [ ! -f "$ubuntu_root/root/.opencode/bin/opencode" ]; then
    log_error "OpenCode binary not found after update"
    return 1
  fi
  return 0
}

reinstall_opencode() {
  uninstall_opencode || [[ $? -eq 2 ]] || return 1

  install_opencode
}
