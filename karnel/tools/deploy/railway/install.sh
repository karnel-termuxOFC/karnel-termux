#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/install"
import "@/utils/version"

LOG_FILE="${KARNEL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/karnel}/install_deploy.log"
RAILWAY_DATA_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/deploy/railway"
_RAILWAY_MARKER="$PREFIX/share/karnel-installers/railway"
_RAILWAY_DATA_MARKER="$RAILWAY_DATA_DIR/.karnel-managed"
_RAILWAY_DATA_MANIFEST="$RAILWAY_DATA_DIR/.karnel-manifest"
_RAILWAY_DATA_INVENTORY="$RAILWAY_DATA_DIR/.karnel-inventory"

_railway_data_inventory() {
  find "$RAILWAY_DATA_DIR" -mindepth 1 \
    ! -name '.karnel-managed' ! -name '.karnel-manifest' ! -name '.karnel-inventory' \
    -printf '%y %P\n' | LC_ALL=C sort
}

_railway_write_data_metadata() {
  mkdir -p "$RAILWAY_DATA_DIR" || return 1
  printf '%s\n' 'Karnel Railway CLI data' >"$_RAILWAY_DATA_MARKER" || return 1
  _railway_data_inventory >"$_RAILWAY_DATA_INVENTORY" || return 1
  find "$RAILWAY_DATA_DIR" -type f \
    ! -name '.karnel-managed' ! -name '.karnel-manifest' ! -name '.karnel-inventory' \
    -exec sha256sum {} + | LC_ALL=C sort >"$_RAILWAY_DATA_MANIFEST"
}

_railway_data_is_karnel_owned() {
  [ -f "$_RAILWAY_DATA_MARKER" ] && [ -f "$_RAILWAY_DATA_MANIFEST" ] && [ -f "$_RAILWAY_DATA_INVENTORY" ] &&
    [ "$(<"$_RAILWAY_DATA_MARKER")" = 'Karnel Railway CLI data' ] &&
    cmp -s "$_RAILWAY_DATA_INVENTORY" <(_railway_data_inventory) &&
    (cd / && sha256sum -c "$_RAILWAY_DATA_MANIFEST" >/dev/null 2>&1)
}

_railway_mark_install() {
  mkdir -p "$(dirname "$_RAILWAY_MARKER")" "$RAILWAY_DATA_DIR" || return 1
  sha256sum "$PREFIX/bin/railway" >"$_RAILWAY_MARKER" || return 1
  _railway_write_data_metadata
}

_railway_command_is_karnel_owned() {
  [ -f "$_RAILWAY_MARKER" ] &&
    [ "$(sha256sum "$PREFIX/bin/railway" 2>/dev/null)" = "$(<"$_RAILWAY_MARKER")" ]
}

_railway_proot_wrapper_owned() {
  [[ -f "$PREFIX/bin/railway" ]] && grep -qF '# Karnel Railway PRoot wrapper' "$PREFIX/bin/railway"
}

_railway_install_proot() {
  if ! command -v proot-distro >/dev/null 2>&1; then
    pkg install -y proot-distro &>>"$LOG_FILE" || return 1
  fi
  if [[ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" && ! -d "$PREFIX/var/lib/proot-distro/containers/ubuntu/rootfs" ]]; then
    proot-distro install ubuntu &>>"$LOG_FILE" || return 1
  fi
  proot-distro login ubuntu -- bash -lc 'export PATH=/usr/bin:/bin; apt-get -o Dir::Etc::sourcelist="sources.list" -o Dir::Etc::sourceparts="-" update && DEBIAN_FRONTEND=noninteractive apt-get -o Dir::Etc::sourcelist="sources.list" -o Dir::Etc::sourceparts="-" install -y nodejs ca-certificates && corepack npm install -g --allow-scripts=@railway/cli @railway/cli@5.35.1' &>>"$LOG_FILE" || return 1
  proot-distro login ubuntu -- /usr/bin/railway --version &>>"$LOG_FILE" || return 1

  if [[ -e "$PREFIX/bin/railway" || -L "$PREFIX/bin/railway" ]]; then
    if _railway_proot_wrapper_owned; then
      :
    elif [[ -L "$PREFIX/bin/railway" && ! -e "$PREFIX/bin/railway" ]]; then
      rm -f "$PREFIX/bin/railway"
    else
      log_error "Refusing to replace unowned railway command: $PREFIX/bin/railway"
      return 1
    fi
  fi

  mkdir -p "$RAILWAY_DATA_DIR" "$PREFIX/bin" || return 1
  chmod 700 "$RAILWAY_DATA_DIR"
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.railway.XXXXXX")" || return 1
  cat >"$temporary" <<WRAPPER
#!$PREFIX/bin/bash
# Karnel Railway PRoot wrapper
exec proot-distro login --termux-home ubuntu -- /usr/bin/railway "\$@"
WRAPPER
  chmod 755 "$temporary"
  mv -f "$temporary" "$PREFIX/bin/railway" || { rm -f "$temporary"; return 1; }
  : >"$RAILWAY_DATA_DIR/.karnel-proot"
}

_install_railway_manual() {
  loading "Downloading Railway CLI for ARM64" _install_railway_manual_impl
}

_install_railway_manual_impl() {
  if [[ -e "$RAILWAY_DATA_DIR" ]] && ! _railway_data_is_karnel_owned; then
    log_error "Refusing to replace unowned Railway data: $RAILWAY_DATA_DIR"
    return 1
  fi
  if [[ -e "$PREFIX/bin/railway" || -L "$PREFIX/bin/railway" ]] && ! _railway_command_is_karnel_owned; then
    log_error "Refusing to replace unowned railway command: $PREFIX/bin/railway"
    return 1
  fi
  mkdir -p "$RAILWAY_DATA_DIR" "$PREFIX/bin"

  local latest_version
  latest_version=$(curl -fsSL --connect-timeout 10 "https://api.github.com/repos/railwayapp/cli/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  
  if [ -z "$latest_version" ]; then
    log_warn "Cannot fetch latest Railway version from GitHub API"
    return 1
  fi

  local version="${latest_version#v}"

  local tarball_url="https://github.com/railwayapp/cli/releases/download/${latest_version}/railway-${version}-aarch64-linux.tar.gz"
  local binary_name="railway"

  log_info "Downloading Railway ${version} for ARM64 Linux..."
  if ! curl -fsSL --connect-timeout 15 "$tarball_url" -o "$RAILWAY_DATA_DIR/railway.tar.gz" 2>>"$LOG_FILE"; then
    log_warn "ARM64 binary not available. Railway CLI does not provide ARM Linux builds."
    log_info "Use 'npx @railway/cli' instead."
    rmdir "$RAILWAY_DATA_DIR" 2>/dev/null || true
    return 2
  fi

  local expected
  expected=$(github_release_asset_sha256 railwayapp/cli "$latest_version" "railway-${version}-aarch64-linux.tar.gz") || expected=""
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    log_error "No published SHA-256 for Railway CLI; refusing install"
    rm -f "$RAILWAY_DATA_DIR/railway.tar.gz"
    return 1
  fi
  verify_sha256 "$RAILWAY_DATA_DIR/railway.tar.gz" "$expected" || {
    rm -f "$RAILWAY_DATA_DIR/railway.tar.gz"
    return 1
  }

  safe_extract_tar "$RAILWAY_DATA_DIR/railway.tar.gz" "$RAILWAY_DATA_DIR" || {
    rm -f "$RAILWAY_DATA_DIR/railway.tar.gz"
    return 1
  }
  rm -f "$RAILWAY_DATA_DIR/railway.tar.gz"

  local found_bin
  found_bin=$(find "$RAILWAY_DATA_DIR" -name "railway" -type f 2>/dev/null | head -1)
  if [ -z "$found_bin" ]; then
    return 1
  fi

  chmod +x "$found_bin"
  ln -sf "$found_bin" "$PREFIX/bin/railway" 2>/dev/null
  _railway_mark_install || return 1

  return 0
}

install_railway() {
  if command -v railway &>/dev/null; then
    if railway --version &>/dev/null; then
      log_info "Railway CLI is already installed"
      return 2
    fi
    if _railway_proot_wrapper_owned || [ -f "$_RAILWAY_MARKER" ]; then
      rm -f "$PREFIX/bin/railway"
    else
      log_error "Existing railway command is not usable or managed by Karnel"
      return 1
    fi
  fi

  log_info "Installing Railway CLI..."

  mkdir -p "$(dirname "$LOG_FILE")" "$RAILWAY_DATA_DIR"

  if karnel_npm install -g @railway/cli --legacy-peer-deps &>>"$LOG_FILE"; then
    command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v railway 2>/dev/null)" &>/dev/null
    _railway_mark_install || return 1
    log_success "Railway CLI installed via npm"
    return 0
  fi

  log_warn "Native Railway CLI is unavailable on Termux Android; using Ubuntu Proot."
  if _railway_install_proot; then
    log_success "Railway CLI installed through Ubuntu Proot"
    return 0
  fi

  log_error "Railway CLI installation failed in Ubuntu Proot."
  return 1
}

uninstall_railway() {
  log_info "Uninstalling Railway CLI..."
  if _railway_proot_wrapper_owned; then
    proot-distro login ubuntu -- npm uninstall -g @railway/cli &>>"$LOG_FILE" || true
    rm -f "$PREFIX/bin/railway"
    [[ -f "$RAILWAY_DATA_DIR/.karnel-proot" ]] && rm -rf "$RAILWAY_DATA_DIR"
    log_success "Railway CLI uninstalled"
    return 0
  fi
  if _railway_command_is_karnel_owned; then
    karnel_npm uninstall -g @railway/cli &>>"$LOG_FILE" || true
    rm -f "$_RAILWAY_MARKER"
  else
    log_warn "Keeping existing railway command not managed by Karnel"
  fi
  _railway_data_is_karnel_owned && rm -rf "$RAILWAY_DATA_DIR" 2>/dev/null
  log_success "Railway CLI uninstalled"
  return 0
}

update_railway() {
  if _railway_proot_wrapper_owned; then
    log_info "Railway was installed via Ubuntu PRoot; updating inside the container..."
    if proot-distro login ubuntu -- npm update -g @railway/cli &>>"$LOG_FILE"; then
      log_success "Railway CLI updated through Ubuntu Proot"
      return 0
    fi
    log_warn "Railway CLI update failed inside Ubuntu Proot"
    return 1
  fi
  _check_update_needed "Railway CLI" "$(_get_installed_npm_version @railway/cli)" "$(_get_remote_npm_version @railway/cli)" _do_update_railway
}

_do_update_railway() {
  karnel_npm update -g @railway/cli --legacy-peer-deps &>>"$LOG_FILE" || {
    log_warn "npm update failed"
    return 1
  }
  _railway_mark_install || return 1
  return 0
}

reinstall_railway() {
  uninstall_railway || [[ $? -eq 2 ]] || return 1

  install_railway
}
