#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"
import "@/utils/install"
import "@/utils/uninstall"

: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
LOG_FILE="$KARNEL_CACHE/install_ai.log"
DROID_DATA_DIR="$KARNEL_DATA/droid"
DROID_MARKER=".karnel-managed"
DROID_WRAPPER_MARKER="$DROID_DATA_DIR/.karnel-wrapper-droid"

_droid_data_owned() {
  [[ -f "$DROID_DATA_DIR/$DROID_MARKER" ]]
}

_droid_wrapper_owned() {
  [[ -f "$DROID_WRAPPER_MARKER" && -f "$PREFIX/bin/droid" ]] || return 1
  [[ "$(sha256sum "$PREFIX/bin/droid" 2>/dev/null)" == "$(<"$DROID_WRAPPER_MARKER")" ]]
}

_droid_verify_ownership() {
  if [[ -e "$DROID_DATA_DIR" ]] && ! _droid_data_owned; then
    log_error "Refusing to replace unowned Droid data: $DROID_DATA_DIR"
    return 1
  fi
  if [[ -e "$PREFIX/bin/droid" ]] && ! _droid_wrapper_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/droid"
    return 1
  fi
  if command -v droid &>/dev/null && ! _droid_wrapper_owned; then
    log_error "Refusing to shadow the existing droid command: $(command -v droid)"
    return 1
  fi
}

_droid_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"
  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi
  echo "$root"
}

_droid_proot_ubuntu() {
  proot-distro login --shared-tmp ubuntu -- "$@"
}

# ===== VERSION DETECTION =====

_get_latest_droid_version() {
  local raw
  raw=$(_spin_capture "Checking Factory" curl -fsSL "https://app.factory.ai/cli" 2>/dev/null)
  echo "$raw" | grep -oE 'VER="[^"]+"' | head -1 | cut -d'"' -f2
}

_get_latest_droid_version_silent() {
  curl -fsSL "https://app.factory.ai/cli" 2>/dev/null |
    grep -oE 'VER="[^"]+"' | head -1 | cut -d'"' -f2
}

# ===== NATIVE INSTALL (glibc) =====

_droid_install_deps_native() {
  loading "Installing glibc and dependencies" _droid_install_deps_native_impl
}

_droid_install_deps_native_impl() {
  if [[ ! -f $PREFIX/etc/apt/sources.list.d/glibc.list ]]; then
    if ! yes | pkg install glibc-repo &>>"$LOG_FILE"; then
      log_error "Failed to install glibc-repo"
      return 1
    fi
  fi
  if [[ ! -f $PREFIX/glibc/lib/libc.so.6 ]]; then
    if ! yes | pkg install glibc &>>"$LOG_FILE"; then
      log_error "Failed to install glibc"
      return 1
    fi
  fi
  declare -A DEPS=(
    ["jq"]="jq"
    ["curl"]="curl"
    ["tar"]="tar"
    ["clang"]="clang"
  )
  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if ! command -v "$bin_name" &>/dev/null; then
      if ! yes | pkg install "$pkg_name" &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done
  return 0
}

_download_droid_binary() {
  loading "Downloading Droid Factory binary" _download_droid_binary_impl
}

_download_droid_binary_impl() {
  local latest_version
  latest_version=$(_get_latest_droid_version_silent)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Droid Factory version"
    return 1
  fi
  mkdir -p "$DROID_DATA_DIR"

  local binary_url="https://downloads.factory.ai/factory-cli/releases/$latest_version/linux/arm64/droid"
  local sha_url="$binary_url.sha256"

  if ! curl -fsSL "$binary_url" -o "$DROID_DATA_DIR/droid" &>>"$LOG_FILE"; then
    log_error "Failed to download Droid Factory binary"
    return 1
  fi

  local expected actual
  expected="$(curl -fsSL "$sha_url" 2>/dev/null | awk '{print $1}')"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    log_error "No published SHA-256 for Droid binary; refusing install"
    rm -f "$DROID_DATA_DIR/droid"
    return 1
  fi
  if command -v sha256sum &>/dev/null; then
    actual="$(sha256sum "$DROID_DATA_DIR/droid" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
      log_error "Checksum verification failed"
      rm -f "$DROID_DATA_DIR/droid"
      return 1
    fi
  else
    log_error "sha256sum unavailable; refusing install"
    rm -f "$DROID_DATA_DIR/droid"
    return 1
  fi

  chmod +x "$DROID_DATA_DIR/droid"
  : >"$DROID_DATA_DIR/$DROID_MARKER"
  echo "$latest_version" >"$DROID_DATA_DIR/version"
  return 0
}

_compile_droid_helper() {
  loading "Compiling droid helper" _compile_droid_helper_impl
}

_compile_droid_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/droid/helper/droid_helper.c"
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.droid.XXXXXX")" || return 1
  if ! clang -O2 -o "$temporary" "$HELPER_SRC" &>>"$LOG_FILE"; then
    rm -f "$temporary"
    log_error "Failed to compile droid helper"
    return 1
  fi
  chmod +x "$temporary"
  mv -f "$temporary" "$PREFIX/bin/droid" || return 1
  sha256sum "$PREFIX/bin/droid" >"$DROID_WRAPPER_MARKER"
  return 0
}

_install_droid_native() {
  _droid_install_deps_native || return 1
  _download_droid_binary || return 1
  _compile_droid_helper || return 1
  printf 'native' >"$DROID_DATA_DIR/.install-method"
  log_success "Droid installed natively"
  return 0
}

# ===== GLIBC + PROOT INSTALL =====

_droid_install_proot_pkg() {
  if ! command -v proot &>/dev/null; then
    if ! yes | pkg install proot &>>"$LOG_FILE"; then
      log_error "Failed to install proot"
      return 1
    fi
  fi
  return 0
}

_droid_create_proot_wrapper() {
  local wrapper_src="$KARNEL_PATH/tools/ai/droid/bin/droid.proot"
  if [ ! -f "$wrapper_src" ]; then
    log_error "Wrapper template not found at $wrapper_src"
    return 1
  fi
  sed "s|__DATA_DIR__|$DROID_DATA_DIR|g" "$wrapper_src" >"$PREFIX/bin/droid"
  chmod +x "$PREFIX/bin/droid"
  sha256sum "$PREFIX/bin/droid" >"$DROID_WRAPPER_MARKER"
  return 0
}

_install_droid_proot_glibc() {
  _droid_install_deps_native || return 1
  loading "Installing proot" _droid_install_proot_pkg || return 1
  _download_droid_binary || return 1
  loading "Creating proot wrapper" _droid_create_proot_wrapper || return 1
  printf 'proot-glibc' >"$DROID_DATA_DIR/.install-method"
  log_success "Droid installed with glibc + proot"
  return 0
}

# ===== PROOT-DISTRO INSTALL =====

_droid_install_proot_distro() {
  if ! command -v proot-distro &>/dev/null; then
    if ! yes | pkg install proot-distro &>>"$LOG_FILE"; then
      log_error "Failed to install proot-distro"
      return 1
    fi
  fi
  return 0
}

_droid_install_ubuntu() {
  if [ ! -d "$(_droid_detect_ubuntu_root)" ]; then
    if ! proot-distro install ubuntu:24.04 &>>"$LOG_FILE"; then
      log_error "Failed to install Ubuntu container"
      return 1
    fi
  fi
  return 0
}

_droid_ubuntu_deps() {
  _droid_proot_ubuntu /bin/bash -c \
    'apt-get update && apt-get upgrade -y && apt-get install -y curl ca-certificates' \
    &>>"$LOG_FILE"
}

_droid_ubuntu_install_bin() {
  local latest_version
  latest_version=$(_get_latest_droid_version_silent)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Droid Factory version"
    return 1
  fi

  local binary_url="https://downloads.factory.ai/factory-cli/releases/$latest_version/linux/arm64/droid"

  local expected
  expected=$(curl -fsSL "$binary_url.sha256" 2>/dev/null | awk '{print $1}') || expected=""
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    log_error "No published SHA-256 for Droid; refusing install (integrity cannot be verified)"
    return 1
  fi
  _droid_proot_ubuntu /bin/bash -c '
    d=$(mktemp -d) &&
    curl -fsSL "$1" -o "$d/droid" &&
    { [ -z "$2" ] || [ "$(sha256sum "$d/droid" | awk "{print \$1}")" = "$2" ]; } &&
    mkdir -p /usr/local/bin &&
    mv "$d/droid" /usr/local/bin/droid &&
    chmod +x /usr/local/bin/droid &&
    rm -rf "$d"
  ' bash "$binary_url" "$expected" &>>"$LOG_FILE"

  local droid_bin="$(_droid_detect_ubuntu_root)/usr/local/bin/droid"
  if [ ! -f "$droid_bin" ]; then
    log_error "Droid Factory binary not found after install"
    return 1
  fi
  return 0
}

_droid_create_ubuntu_wrapper() {
  local ubuntu_root
  ubuntu_root="$(_droid_detect_ubuntu_root)"
  if [ -z "$ubuntu_root" ]; then
    log_error "Ubuntu rootfs not found"
    return 1
  fi

  local wrapper_src="$KARNEL_PATH/tools/ai/droid/bin/droid"
  if [ ! -f "$wrapper_src" ]; then
    log_error "Wrapper template not found at $wrapper_src"
    return 1
  fi
  sed "s|__UBUNTU_ROOTFS__|$ubuntu_root|g" "$wrapper_src" >"$PREFIX/bin/droid"
  chmod +x "$PREFIX/bin/droid"
  sha256sum "$PREFIX/bin/droid" >"$DROID_WRAPPER_MARKER"
  return 0
}

_install_droid_proot() {
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Installing proot-distro" _droid_install_proot_distro || return 1
  loading "Installing Ubuntu container" _droid_install_ubuntu || return 1
  loading "Installing dependencies (Ubuntu)" _droid_ubuntu_deps || return 1
  loading "Downloading Droid Factory (Ubuntu)" _droid_ubuntu_install_bin || return 1
  loading "Creating wrapper" _droid_create_ubuntu_wrapper || return 1

  mkdir -p "$DROID_DATA_DIR"
  : >"$DROID_DATA_DIR/$DROID_MARKER"
  printf 'proot' >"$DROID_DATA_DIR/.install-method"
  log_success "Droid installed (proot-distro)"
  return 0
}

# ===== MAIN INSTALL =====

install_droid() {
  if [ -f "$DROID_DATA_DIR/.install-method" ]; then
    _update_droid_impl
    return $?
  fi
  _droid_verify_ownership || return 1

  # The download below creates the data directory before anything marks it as
  # ours, so a failed run left an unowned tree that every later install refused
  # to touch and droid could never be installed again. Remember what was
  # already there and take back only what this run created.
  local data_preexisting=0
  [[ -e "$DROID_DATA_DIR" ]] && data_preexisting=1

  if command -v droid &>/dev/null; then
    if _droid_wrapper_owned; then
      log_info "Droid is already installed"
      return 2
    fi
    _droid_verify_ownership || return 1
  fi

  log_info "Select installation method for Droid:"

  local SELECTED_METHOD
  read_select "Installation method" SELECTED_METHOD \
    "glibc (recommended)" \
    "glibc + proot (bad system call)" \
    "proot-distro (ubuntu container)"

  case "$SELECTED_METHOD" in
  *"glibc + proot"*)
    _install_droid_proot_glibc
    ;;
  *"glibc (recommended)"*)
    _install_droid_native
    ;;
  *proot-distro*)
    _install_droid_proot
    ;;
  esac

  if command -v droid &>/dev/null; then
    log_success "Droid installed"
    log_info "Run: ${D_CYAN}droid login${NC} to authenticate"
    log_info "Then: ${D_CYAN}droid${NC} to start"
    return 0
  fi

  if ((data_preexisting == 0)) && [[ -e "$DROID_DATA_DIR" ]] && ! _droid_data_owned; then
    rm -rf "$DROID_DATA_DIR"
  fi
  log_error "Droid installation failed"
  return 1
}

# ===== METHOD DETECTION =====

_droid_install_method() {
  if [ -f "$DROID_DATA_DIR/.install-method" ]; then
    cat "$DROID_DATA_DIR/.install-method"
  elif _droid_data_owned && _droid_wrapper_owned && [ -f "$DROID_DATA_DIR/droid" ]; then
    echo "native"
  elif [ -n "$(_droid_detect_ubuntu_root)" ] && [ -f "$(_droid_detect_ubuntu_root)/usr/local/bin/droid" ] && _droid_wrapper_owned; then
    echo "proot"
  else
    echo ""
  fi
}

# ===== UNINSTALL =====

_uninstall_droid_native_impl() {
  rm -f "$PREFIX/bin/droid"
  rm -rf "$DROID_DATA_DIR"
}

_uninstall_droid_proot_impl() {
  _droid_proot_ubuntu /bin/bash -c 'rm -f /usr/local/bin/droid' &>>"$LOG_FILE"
  rm -f "$PREFIX/bin/droid"
  return 0
}

uninstall_droid() {
  mkdir -p "$(dirname "$LOG_FILE")"

  local method
  method="$(_droid_install_method)"
  if [ -z "$method" ]; then
    if [ -e "$DROID_DATA_DIR" ] || [ -e "$PREFIX/bin/droid" ]; then
      _droid_verify_ownership
      return $?
    fi
    log_info "Droid is not installed"
    return 2
  fi

  _droid_verify_ownership || return 1
  confirm_remove_paths "Droid" "$HOME/.factory"

  case "$method" in
  proot-glibc | native)
    loading "Uninstalling Droid ($method)" _uninstall_droid_native_impl
    ;;
  proot)
    loading "Uninstalling Droid (proot-distro)" _uninstall_droid_proot_impl
    ;;
  esac
  log_success "Droid uninstalled"
  return 0
}

# ===== UPDATE =====

_update_droid_native_impl() {
  rm -f "$PREFIX/bin/droid"
  rm -rf "$DROID_DATA_DIR"
  _install_droid_native
}

_update_droid_proot_impl() {
  local latest_version
  latest_version=$(_get_latest_droid_version_silent)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Droid Factory version"
    return 1
  fi

  local binary_url="https://downloads.factory.ai/factory-cli/releases/$latest_version/linux/arm64/droid"

  local expected
  expected=$(curl -fsSL "$binary_url.sha256" 2>/dev/null | awk '{print $1}') || expected=""
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    log_error "No published SHA-256 for Droid; refusing install (integrity cannot be verified)"
    return 1
  fi
  _droid_proot_ubuntu /bin/bash -c '
    rm -f /usr/local/bin/droid &&
    d=$(mktemp -d) &&
    curl -fsSL "$1" -o "$d/droid" &&
    { [ -z "$2" ] || [ "$(sha256sum "$d/droid" | awk "{print \$1}")" = "$2" ]; } &&
    mv "$d/droid" /usr/local/bin/droid &&
    chmod +x /usr/local/bin/droid &&
    rm -rf "$d"
  ' bash "$binary_url" "$expected" &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(_droid_detect_ubuntu_root)"
  if [ ! -f "$ubuntu_root/usr/local/bin/droid" ]; then
    log_error "Droid Factory binary not found after update"
    return 1
  fi
  log_success "Droid (proot-distro) updated"
  return 0
}

_update_droid_impl() {
  local method
  method="$(_droid_install_method)"
  case "$method" in
  proot-glibc)
    _install_droid_proot_glibc
    return $?
    ;;
  native)
    _update_droid_native_impl
    return $?
    ;;
  proot)
    loading "Updating Droid (proot-distro)" _update_droid_proot_impl
    return $?
    ;;
  esac
  log_warn "Could not detect Droid installation method"
  return 1
}

update_droid() {
  _check_update_needed "Droid" "$(_get_installed_version droid)" "$(_get_latest_droid_version)" _update_droid_impl
}

# ===== REINSTALL =====

reinstall_droid() {
  uninstall_droid || [[ $? -eq 2 ]] || return 1

  install_droid
}