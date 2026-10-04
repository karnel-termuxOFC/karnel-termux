#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
AMP_DATA_DIR="$HOME/.local/share/karnel-data/ampcode"
AMP_MARKER=".karnel-managed"
AMP_WRAPPER_MARKER="$AMP_DATA_DIR/.karnel-wrapper"

_amp_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"
  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi
  echo "$root"
}

_amp_proot_ubuntu() {
  proot-distro login --shared-tmp ubuntu -- "$@"
}

_get_latest_amp_version_raw() {
  local raw
  raw=$(curl -fsSL "https://registry.npmjs.org/@ampcode/cli-linux-arm64/latest" 2>/dev/null)
  echo "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version',''))" 2>/dev/null
}

_get_latest_amp_version() {
  local raw
  raw=$(_spin_capture "Checking npm" _get_latest_amp_version_raw)
  _parse_version "$raw"
}

_get_latest_amp_version_silent() {
  local raw
  raw=$(curl -fsSL "https://registry.npmjs.org/@ampcode/cli-linux-arm64/latest" 2>/dev/null)
  echo "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version',''))" 2>/dev/null
}

_get_latest_amp_integrity() {
  curl -fsSL "https://registry.npmjs.org/@ampcode/cli-linux-arm64/latest" 2>/dev/null |
    python3 -c "import json,sys; print(json.load(sys.stdin).get('dist',{}).get('integrity',''))" 2>/dev/null
}

_amp_install_deps_native() {
  loading "Installing glibc and dependencies" _amp_install_deps_native_impl
}

_amp_install_deps_native_impl() {
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
    ["curl"]="curl"
    ["tar"]="tar"
    ["python"]="python"
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

_download_amp_binary() {
  loading "Downloading AMP Code CLI" _download_amp_binary_impl
}

_download_amp_binary_impl() {
  local latest_version expected actual staging_dir tarball download_url
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) log_error "AMP Code Linux ARM64 package is unavailable for architecture: $(uname -m)"; return 1 ;;
  esac
  latest_version=$(_get_latest_amp_version_silent)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest AMP Code CLI version"
    return 1
  fi
  mkdir -p "$(dirname "$AMP_DATA_DIR")"
  staging_dir=$(mktemp -d "$(dirname "$AMP_DATA_DIR")/.ampcode.XXXXXX") || return 1
  tarball="cli-linux-arm64-$latest_version.tgz"
  download_url="https://registry.npmjs.org/@ampcode%2fcli-linux-arm64/-/cli-linux-arm64-$latest_version.tgz"
  if ! curl -fsSL "$download_url" -o "$staging_dir/$tarball" &>>"$LOG_FILE"; then
    rm -rf "$staging_dir"
    log_error "Failed to download AMP Code CLI binary"
    return 1
  fi
  expected=$(_get_latest_amp_integrity)
  actual=$(python3 -c 'import base64,hashlib,sys; print("sha512-" + base64.b64encode(hashlib.sha512(open(sys.argv[1], "rb").read()).digest()).decode())' "$staging_dir/$tarball" 2>>"$LOG_FILE") || { rm -rf "$staging_dir"; return 1; }
  if [[ "$expected" != sha512-* || "$actual" != "$expected" ]] ||
    ! extract_tarball "$staging_dir/$tarball" "$staging_dir"; then
    rm -rf "$staging_dir"
    log_error "AMP Code package failed npm registry integrity validation"
    return 1
  fi
  if [ -f "$staging_dir/package/amp" ]; then
    mv "$staging_dir/package/amp" "$staging_dir/amp"
  elif [ -f "$staging_dir/package/bin/amp.exe" ]; then
    mv "$staging_dir/package/bin/amp.exe" "$staging_dir/amp"
  elif [ -f "$staging_dir/package/amp.exe" ]; then
    mv "$staging_dir/package/amp.exe" "$staging_dir/amp"
  fi
  rm -rf "$staging_dir/package"
  if [ ! -f "$staging_dir/amp" ]; then
    rm -rf "$staging_dir"
    log_error "AMP Code CLI binary not found after extraction"
    return 1
  fi
  chmod +x "$staging_dir/amp"
  replace_managed_directory "$staging_dir" "$AMP_DATA_DIR" "$AMP_MARKER"
}

_compile_amp_helper() {
  loading "Compiling helper" _compile_amp_helper_impl
}

_compile_amp_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/ampcode/helper/amp_helper.c"
  if [ ! -f "$HELPER_SRC" ]; then
    log_error "Helper source not found at $HELPER_SRC"
    return 1
  fi
  local staged_wrapper
  staged_wrapper=$(mktemp "$PREFIX/bin/.amp.XXXXXX") || return 1
  if ! clang -O2 -o "$staged_wrapper" "$HELPER_SRC" &>>"$LOG_FILE"; then
    rm -f "$staged_wrapper"
    log_error "Failed to compile amp helper"
    return 1
  fi
  chmod +x "$staged_wrapper"
  mv "$staged_wrapper" "$PREFIX/bin/amp" || return 1
  record_managed_file "$PREFIX/bin/amp" "$AMP_WRAPPER_MARKER"
}

_install_amp_native() {
  _amp_install_deps_native || return 1
  _download_amp_binary || return 1
  _compile_amp_helper || return 1
  log_success "AMP Code CLI installed natively"
  return 0
}

_install_amp_proot() {
  loading "Installing AMP Code CLI (proot-distro)" _install_amp_proot_impl
}

_install_amp_proot_impl() {
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) log_error "AMP Code Linux ARM64 package is unavailable for architecture: $(uname -m)"; return 1 ;;
  esac
  log_error "AMP Code Proot install is disabled; use native mode with npm registry integrity verification"
  return 1
}

install_ampcode() {
  if command -v amp &>/dev/null; then
    log_info "AMP Code CLI is already installed"
    return 2
  fi
  if [ -e "$PREFIX/bin/amp" ]; then
    log_error "Refusing to replace an existing AMP Code wrapper not owned by Karnel"
    return 1
  fi
  # Only methods that can succeed are offered: AMP Code ships no proot build,
  # so a second entry here would be a prompt that always fails.
  _install_amp_native
}

uninstall_ampcode() {
  mkdir -p "$(dirname "$LOG_FILE")"
  if [ ! -f "$PREFIX/bin/amp" ]; then
    log_warn "AMP Code CLI is not installed"
    return 2
  fi
  loading "Uninstalling AMP Code CLI" _uninstall_ampcode_impl || return 1
}

_uninstall_ampcode_impl() {
  if [ -f "$AMP_DATA_DIR/$AMP_MARKER" ] && managed_file_matches "$PREFIX/bin/amp" "$AMP_WRAPPER_MARKER"; then
    rm -f "$PREFIX/bin/amp"
    rm -rf "$AMP_DATA_DIR"
    log_success "AMP Code CLI (native) uninstalled"
    return 0
  fi
  log_error "Refusing to remove an AMP Code installation not owned by Karnel"
  return 1
}

_update_ampcode() {
  _update_ampcode_impl
}

_update_ampcode_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"
  if [ -f "$AMP_DATA_DIR/amp" ]; then
    _install_amp_native
    return $?
  fi
  loading "Updating AMP Code CLI (proot-distro)" _update_amp_proot_impl
}

update_ampcode() {
  _check_update_needed "AMP Code CLI" "$(_get_installed_version amp)" "$(_get_latest_amp_version)" _update_ampcode
}

_update_amp_proot_impl() {
  log_error "AMP Code Proot update is disabled; use native mode with npm registry integrity verification"
  return 1
}

reinstall_ampcode() {
  if command -v amp &>/dev/null; then
    _update_ampcode_impl
  else
    install_ampcode
  fi
}
