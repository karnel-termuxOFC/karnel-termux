#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"
import "@/utils/colors"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
MIMOCODE_DATA_DIR="$HOME/.local/share/karnel-data/mimocode"
MIMOCODE_VERSION="v0.1.0"
MIMOCODE_MARKER=".karnel-managed"
MIMOCODE_WRAPPER_MARKER="$MIMOCODE_DATA_DIR/.karnel-wrapper"

_get_latest_mimocode_version() {
  curl -fsSL https://api.github.com/repos/XiaomiMiMo/MiMo-Code/releases/latest |
    grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

_mimocode_install_deps() {
  loading "Installing glibc and dependencies" _mimocode_install_deps_impl
}

_mimocode_install_deps_impl() {
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
    if ! command -v "$bin_name" &>/dev/null; then
      if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done

  return 0
}

_download_mimocode_binary() {
  loading "Downloading mimocode binary" _download_mimocode_binary_impl
}

_download_mimocode_binary_impl() {
  local latest_version staging_dir tarball download_url
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) log_error "MiMo Code Linux ARM64 asset is unavailable for architecture: $(uname -m)"; return 1 ;;
  esac
  latest_version=$(_get_latest_mimocode_version)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest mimocode version, falling back to $MIMOCODE_VERSION"
    latest_version="$MIMOCODE_VERSION"
  fi

  mkdir -p "$(dirname "$MIMOCODE_DATA_DIR")"
  staging_dir=$(mktemp -d "$(dirname "$MIMOCODE_DATA_DIR")/.mimocode.XXXXXX") || return 1
  tarball="mimocode-linux-arm64.tar.gz"
  download_url="https://github.com/XiaomiMiMo/MiMo-Code/releases/download/$latest_version/$tarball"

  if ! curl -fsSL "$download_url" -o "$staging_dir/$tarball" &>>"$LOG_FILE"; then
    rm -rf "$staging_dir"
    log_error "Failed to download mimocode binary"
    return 1
  fi

  if ! verify_github_release_asset XiaomiMiMo/MiMo-Code "$latest_version" "$tarball" "$staging_dir/$tarball" ||
    ! extract_tarball "$staging_dir/$tarball" "$staging_dir"; then
    rm -rf "$staging_dir"
    return 1
  fi

  if [ ! -f "$staging_dir/mimo" ]; then
    rm -rf "$staging_dir"
    log_error "mimocode binary not found after extraction"
    return 1
  fi

  mv "$staging_dir/mimo" "$staging_dir/mimocode"
  chmod +x "$staging_dir/mimocode"
  replace_managed_directory "$staging_dir" "$MIMOCODE_DATA_DIR" "$MIMOCODE_MARKER"
}

_compile_mimocode_helper() {
  loading "Compiling helper" _compile_mimocode_helper_impl
}

_compile_mimocode_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/mimocode/helper/mimocode_helper.c"
  if [ ! -f "$HELPER_SRC" ]; then
    log_error "Helper source not found at $HELPER_SRC"
    return 1
  fi

  local staged_wrapper
  staged_wrapper=$(mktemp "$PREFIX/bin/.mimo.XXXXXX") || return 1
  if ! cc -O2 -o "$staged_wrapper" "$HELPER_SRC" &>>"$LOG_FILE"; then
    rm -f "$staged_wrapper"
    log_error "Failed to compile mimocode helper"
    return 1
  fi

  chmod +x "$staged_wrapper"
  mv "$staged_wrapper" "$PREFIX/bin/mimo" || return 1
  record_managed_file "$PREFIX/bin/mimo" "$MIMOCODE_WRAPPER_MARKER"
}

_mimocode_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"

  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi

  echo "$root"
}

_mimocode_proot_ubuntu() {
  proot-distro login \
    --shared-tmp \
    ubuntu \
    -- "$@"
}

_install_mimocode_native() {
  _mimocode_install_deps || return 1
  _download_mimocode_binary || return 1
  _compile_mimocode_helper || return 1
  log_success "mimocode installed natively"
  return 0
}

_install_mimocode_proot() {
  loading "Installing mimocode (proot-distro)" _install_mimocode_proot_impl
}

_install_mimocode_proot_impl() {
  log_error "MiMo Code Proot installation is unavailable: upstream publishes no supported Proot contract"
  return 1
}

install_mimocode() {
  if command -v mimo &>/dev/null; then
    log_info "mimocode is already installed"
    return 2
  fi
  if [ -e "$PREFIX/bin/mimo" ]; then
    log_error "Refusing to replace an existing mimocode wrapper not owned by Karnel"
    return 1
  fi

  # Only methods that can succeed are offered: upstream publishes no proot
  # contract, so a second entry here would be a prompt that always fails.
  _install_mimocode_native
}

uninstall_mimocode() {
  log_info "Uninstalling mimocode..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if [ ! -f "$PREFIX/bin/mimo" ]; then
    log_warn "mimocode is not installed"
    return 1
  fi

  if [ -f "$MIMOCODE_DATA_DIR/$MIMOCODE_MARKER" ] && managed_file_matches "$PREFIX/bin/mimo" "$MIMOCODE_WRAPPER_MARKER"; then
    rm -f "$PREFIX/bin/mimo"
    rm -rf "$MIMOCODE_DATA_DIR"
    log_success "mimocode (native) uninstalled"
    return 0
  fi

  log_error "Refusing to remove a mimocode installation not owned by Karnel"
  return 1
}

update_mimocode() {
  _check_update_needed "mimocode" "$(_get_installed_version mimo)" "$(_get_remote_github_version XiaomiMiMo/MiMo-Code)" _do_update_mimocode
}

_do_update_mimocode() {
  if [ -f "$MIMOCODE_DATA_DIR/mimocode" ]; then
    _install_mimocode_native
    return $?
  fi

  log_error "MiMo Code update is unavailable for installations not owned by Karnel"
  return 1
}

reinstall_mimocode() {
  if command -v mimo &>/dev/null; then
    _do_update_mimocode
  else
    install_mimocode
  fi
}
