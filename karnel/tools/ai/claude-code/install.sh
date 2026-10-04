#!/usr/bin/env bash
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"
import "@/utils/colors"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
CLAUDE_DATA_DIR="$HOME/.local/share/karnel-data/claude"
CLAUDE_MARKER=".karnel-managed"
CLAUDE_WRAPPER_MARKER="$CLAUDE_DATA_DIR/.karnel-wrapper"
CLAUDE_PROOT_MARKER="$PREFIX/share/karnel-installers/claude-code"

_claude_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"

  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi

  echo "$root"
}

_claude_proot_ubuntu() {
  proot-distro login \
    --shared-tmp \
    ubuntu \
    -- "$@"
}

_get_latest_claude_version() {
  curl -fsSL https://api.github.com/repos/anthropics/claude-code/releases/latest |
    grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

_claude_install_deps_native() {
  loading "Installing glibc and dependencies" _claude_install_deps_native_impl
}

_claude_install_deps_native_impl() {
  if [[ ! -f $PREFIX/etc/apt/sources.list.d/glibc.list ]]; then
    if ! pkg install glibc-repo -y &>>"$LOG_FILE"; then
      log_error "Failed to install glibc-repo"
      return 1
    fi
  fi

  if [[ ! -f $PREFIX/glibc/lib/libc.so.6 ]]; then
    if ! pkg install glibc -y &>>"$LOG_FILE"; then
      log_error "Failed to install glibc"
      return 1
    fi
  fi

  declare -A DEPS=(
    ["clang"]="cc"
    ["curl"]="curl"
    ["tar"]="tar"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if [[ -n "$bin_name" ]] && command -v "$bin_name" &>/dev/null; then
      continue
    fi
    if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
      log_error "Failed to install $pkg_name"
      return 1
    fi
  done

  return 0
}

_download_claude_binary() {
  loading "Downloading Claude Code" _download_claude_binary_impl
}

_download_claude_binary_impl() {
  local latest_version staging_dir tarball download_url
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) log_error "Claude Code Linux asset is unavailable for architecture: $(uname -m)"; return 1 ;;
  esac
  latest_version=$(_get_latest_claude_version)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Claude Code version"
    return 1
  fi

  mkdir -p "$(dirname "$CLAUDE_DATA_DIR")"
  staging_dir=$(mktemp -d "$(dirname "$CLAUDE_DATA_DIR")/.claude.XXXXXX") || return 1
  tarball="claude-linux-arm64.tar.gz"
  download_url="https://github.com/anthropics/claude-code/releases/download/$latest_version/$tarball"

  if ! curl -fsSL "$download_url" -o "$staging_dir/$tarball" &>>"$LOG_FILE"; then
    rm -rf "$staging_dir"
    log_error "Failed to download Claude Code binary"
    return 1
  fi

  if ! verify_github_release_asset anthropics/claude-code "$latest_version" "$tarball" "$staging_dir/$tarball" ||
    ! extract_tarball "$staging_dir/$tarball" "$staging_dir"; then
    rm -rf "$staging_dir"
    return 1
  fi

  if [ ! -f "$staging_dir/claude" ]; then
    rm -rf "$staging_dir"
    log_error "Claude Code binary not found after extraction"
    return 1
  fi

  chmod +x "$staging_dir/claude"
  replace_managed_directory "$staging_dir" "$CLAUDE_DATA_DIR" "$CLAUDE_MARKER"
}

_compile_claude_helper() {
  loading "Compiling helper" _compile_claude_helper_impl
}

_compile_claude_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/claude-code/helper/claude_helper.c"
  if [ ! -f "$HELPER_SRC" ]; then
    log_error "Helper source not found at $HELPER_SRC"
    return 1
  fi

  local staged_wrapper
  staged_wrapper=$(mktemp "$PREFIX/bin/.claude.XXXXXX") || return 1
  if ! cc -O2 -o "$staged_wrapper" "$HELPER_SRC" &>>"$LOG_FILE"; then
    rm -f "$staged_wrapper"
    log_error "Failed to compile claude helper"
    return 1
  fi

  chmod +x "$staged_wrapper"
  mv "$staged_wrapper" "$PREFIX/bin/claude" || return 1
  record_managed_file "$PREFIX/bin/claude" "$CLAUDE_WRAPPER_MARKER"
}

_install_claude_native() {
  _claude_install_deps_native || return 1
  _download_claude_binary || return 1
  _compile_claude_helper || return 1
  log_success "Claude Code installed natively"
  return 0
}

_install_claude_proot() {
  loading "Installing Claude Code (proot-distro)" _install_claude_proot_impl
}

_install_claude_proot_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"

  if ! command -v proot-distro &>/dev/null; then
    pkg install proot-distro -y &>>"$LOG_FILE"
  fi

  if [ ! -d "$(_claude_detect_ubuntu_root)" ]; then
    proot-distro install ubuntu &>>"$LOG_FILE"
  fi

  _claude_proot_ubuntu /bin/bash -c \
    'apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates nodejs npm' \
    &>>"$LOG_FILE"

  _claude_proot_ubuntu /bin/bash -c '
		export SHELL=/bin/bash
		export TMPDIR=/tmp
		export HOME=/root
		npm install -g @anthropic-ai/claude-code@2.1.226
	' &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(_claude_detect_ubuntu_root)"

  if [ -z "$ubuntu_root" ]; then
    log_error "Ubuntu rootfs not found"
    return 1
  fi

  if ! _claude_proot_ubuntu test -x /root/.local/bin/claude &>>"$LOG_FILE"; then
    log_error "Claude Code binary not found after install"
    return 1
  fi

  local wrapper_src="$KARNEL_PATH/tools/ai/claude-code/bin/claude"
  if [ ! -f "$wrapper_src" ]; then
    log_error "Wrapper template not found at $wrapper_src"
    return 1
  fi
  sed "s|__UBUNTU_ROOTFS__|$ubuntu_root|g" "$wrapper_src" >"$PREFIX/bin/claude"
  chmod +x "$PREFIX/bin/claude"
  record_managed_file "$PREFIX/bin/claude" "$CLAUDE_PROOT_MARKER" || return 1

  if ! grep -q '.local/bin' "$ubuntu_root/root/.bashrc" 2>/dev/null; then
    printf '\n# Karnel claude-code begin\nexport PATH=/root/.local/bin:$PATH\n# Karnel claude-code end\n' >>"$ubuntu_root/root/.bashrc"
  fi

  return 0
}

install_claude_code() {
  if command -v claude &>/dev/null; then
    log_info "Claude Code is already installed"
    return 2
  fi
  if [ -e "$PREFIX/bin/claude" ]; then
    log_error "Refusing to replace an existing Claude Code wrapper not owned by Karnel"
    return 1
  fi

  log_info "Select installation method for Claude Code:"

  read_select "Installation method" SELECTED_METHOD \
    "Native (recommended) - Run with glibc support" \
    "Proot-distro (alternative) - Ubuntu container"

  case "$SELECTED_METHOD" in
  *Native*)
    _install_claude_native
    ;;
  *Proot-distro*)
    _install_claude_proot
    ;;
  esac
}

uninstall_claude_code() {
  log_info "Uninstalling Claude Code..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if [ ! -f "$PREFIX/bin/claude" ]; then
    log_warn "Claude Code is not installed"
    return 1
  fi

  if [ -f "$CLAUDE_DATA_DIR/$CLAUDE_MARKER" ] && managed_file_matches "$PREFIX/bin/claude" "$CLAUDE_WRAPPER_MARKER"; then
    rm -f "$PREFIX/bin/claude"
    rm -rf "$CLAUDE_DATA_DIR"
    log_success "Claude Code (native) uninstalled"
    return 0
  fi

  if ! managed_file_matches "$PREFIX/bin/claude" "$CLAUDE_PROOT_MARKER"; then
    log_error "Refusing to remove a Claude Code installation not owned by Karnel"
    return 1
  fi

  _claude_proot_ubuntu /bin/bash -c \
    'rm -f /root/.local/bin/claude' \
    &>>"$LOG_FILE"

  local ubuntu_bashrc
  ubuntu_bashrc="$(_claude_detect_ubuntu_root)/root/.bashrc"

  if [ -f "$ubuntu_bashrc" ]; then
    sed -i '/# Karnel claude-code begin/,/# Karnel claude-code end/d' "$ubuntu_bashrc"
  fi

  if rm -f "$PREFIX/bin/claude" &>>"$LOG_FILE"; then
    rm -f "$CLAUDE_PROOT_MARKER"
    log_success "Claude Code (proot-distro) uninstalled"
    return 0
  else
    log_error "Failed to uninstall Claude Code"
    return 1
  fi
}

update_claude_code() {
  _check_update_needed "Claude Code" "$(_get_installed_version claude)" "$(_get_remote_github_version anthropics/claude-code)" _do_update_claude_code
}

_do_update_claude_code() {
  if [ -f "$CLAUDE_DATA_DIR/claude" ]; then
    _install_claude_native
    return $?
  fi

  _claude_proot_ubuntu /bin/bash -c '
    export HOME=/root
    npm install -g @anthropic-ai/claude-code@2.1.226
  ' &>>"$LOG_FILE"

  if ! _claude_proot_ubuntu test -x /root/.local/bin/claude &>>"$LOG_FILE"; then
    log_error "Claude Code binary not found after update"
    return 1
  fi

  return 0
}

reinstall_claude_code() {
  if command -v claude &>/dev/null; then
    _do_update_claude_code
  else
    install_claude_code
  fi
}
