#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
AGY_DATA_DIR="$HOME/.local/share/karnel-data/antigravity-cli"
MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_arm64.json"

_antigravity_get_latest_version() {
  curl -fsSL "$MANIFEST_URL" | jq -r .version
}

_antigravity_get_download_url() {
  curl -fsSL "$MANIFEST_URL" | jq -r .url
}

_antigravity_cli_dependencies() {
  loading "Installing glibc and dependencies" _antigravity_cli_dependencies_impl
}

_antigravity_cli_dependencies_impl() {
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
    ["python"]="python"
    ["jq"]="jq"
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

_antigravity_download_binary() {
  loading "Downloading Antigravity CLI binary" _antigravity_download_binary_impl
}

_antigravity_download_binary_impl() {
  local manifest
  manifest=$(curl -fsSL "$MANIFEST_URL") || {
    log_error "Failed to fetch Antigravity CLI manifest"
    return 1
  }
  local latest_version download_url manifest_sha256
  latest_version=$(printf '%s' "$manifest" | jq -r .version)
  download_url=$(printf '%s' "$manifest" | jq -r .url)
  manifest_sha256=$(printf '%s' "$manifest" | jq -r '.sha256 // empty')
  if [ -z "$latest_version" ] || [ -z "$download_url" ]; then
    log_error "Failed to parse Antigravity CLI manifest"
    return 1
  fi

  mkdir -p "$AGY_DATA_DIR"

  local tarball="$AGY_DATA_DIR/agy.tar.gz"

  if ! curl -fsSL -o "$tarball" "$download_url" &>>"$LOG_FILE"; then
    log_error "Failed to download Antigravity CLI binary"
    return 1
  fi

  if [[ "$manifest_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    verify_sha256 "$tarball" "$manifest_sha256" || { rm -f "$tarball"; return 1; }
  else
    log_error "Antigravity CLI manifest does not publish a SHA-256; refusing install"
    rm -f "$tarball"
    return 1
  fi

  if ! safe_extract_tar "$tarball" "$AGY_DATA_DIR"; then
    log_error "Failed to extract Antigravity CLI binary"
    rm -f "$tarball"
    return 1
  fi

  rm -f "$tarball"

  local upstream_bin=""
  if [ -f "$AGY_DATA_DIR/antigravity" ]; then
    upstream_bin="$AGY_DATA_DIR/antigravity"
  elif [ -f "$AGY_DATA_DIR/agy" ]; then
    upstream_bin="$AGY_DATA_DIR/agy"
  else
    log_error "Could not find binary in extracted archive"
    return 1
  fi

  chmod +x "$upstream_bin"
  return 0
}

_antigravity_apply_va39_patches() {
  loading "Applying VA39 memory patches" _antigravity_apply_va39_patches_impl
}

_antigravity_apply_va39_patches_impl() {
  local upstream_bin=""
  if [ -f "$AGY_DATA_DIR/antigravity" ]; then
    upstream_bin="$AGY_DATA_DIR/antigravity"
  elif [ -f "$AGY_DATA_DIR/agy" ]; then
    upstream_bin="$AGY_DATA_DIR/agy"
  else
    log_error "Binary not found for patching"
    return 1
  fi

  python3 - "$upstream_bin" "${AGY_DATA_DIR}/agy.va39" <<'PY'
import sys, shutil, struct, pathlib
src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
shutil.copyfile(src, dst)
data = bytearray(dst.read_bytes())
def get(off): return struct.unpack_from("<I", data, off)[0]
def put(off, word): struct.pack_into("<I", data, off, word)

lo, hi = 0, len(data)
for off in range(lo, hi, 4):
    w = get(off)
    if (w & 0x7F800000) == 0x53000000:
        immr, imms = (w >> 16) & 0x3F, (w >> 10) & 0x3F
        if immr == 42 and imms == 44:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (35 << 16) | (37 << 10))
        elif immr == 22 and imms == 21:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (29 << 16) | (28 << 10))
for off in range(lo, hi - 4, 4):
    if get(off) == 0x92D3800A and get(off + 4) == 0xF2E0000A:
        put(off, 0x9280000A); put(off + 4, 0xD35DFD4A)
for off in range(lo, hi, 4):
    if get(off) == 0xF2E00029: put(off, 0xD3596129)
word_rewrites = {
    0xD2C20009: 0xD2C00409, 0xD2C2000A: 0xD2C0040A, 0xF2C20008: 0xF2DFF408,
    0xF2C20009: 0xF2DFF409, 0xD2C10009: 0xD2C00209, 0xD2C1000A: 0xD2C0020A,
    0xF2C38008: 0xF2DFF708, 0xF2C38009: 0xF2DFF709, 0x92560A6C: 0x925D0A6C,
    0x92560A6A: 0x925D0A6A, 0xD2C3000D: 0xD2C0060D, 0xD2C3000C: 0xD2C0060C,
    0xD2C08008: 0xD2C00108,
}
for off in range(lo, hi, 4):
    w = get(off)
    if w in word_rewrites: put(off, word_rewrites[w])
for off in range(0, len(data) - 12, 4):
    if get(off) == 0xAA1F03E5 and get(off + 4) == 0xAA1F03E6 and get(off + 8) == 0xD28036E0 and (get(off + 12) & 0xFC000000) == 0x94000000:
        put(off + 8, 0xD2800600)
dst.write_bytes(data)
PY

  chmod +x "$AGY_DATA_DIR/agy.va39"
  return 0
}

_antigravity_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"

  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi

  echo "$root"
}

_antigravity_proot_ubuntu() {
  proot-distro login \
    --shared-tmp \
    ubuntu \
    -- "$@"
}

_antigravity_compile_helper() {
  loading "Compiling helper" _antigravity_compile_helper_impl
}

_antigravity_compile_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/antigravity-cli/helper/agy_helper.c"
  if [ ! -f "$HELPER_SRC" ]; then
    log_error "Helper source not found at $HELPER_SRC"
    return 1
  fi

  if ! cc -O2 -o "$PREFIX/bin/agy" "$HELPER_SRC" &>>"$LOG_FILE"; then
    log_error "Failed to compile agy helper"
    return 1
  fi

  chmod +x "$PREFIX/bin/agy"
  return 0
}

_install_antigravity_proot() {
  loading "Installing Antigravity CLI (proot-distro)" _install_antigravity_proot_impl
}

_install_antigravity_proot_impl() {
  # Upstream publishes no verifiable proot artifact. Refuse here, before an
  # Ubuntu rootfs is provisioned, instead of installing a container we cannot
  # populate and then failing halfway through.
  log_error "Antigravity CLI Proot install is unavailable: upstream has no verifiable artifact; use native mode"
  return 1
}

install_antigravity_cli() {
  if command -v agy &>/dev/null; then
    log_info "Antigravity CLI is already installed"
    return 2
  fi

  # Only methods that can succeed are offered: upstream ships no verifiable
  # proot artifact, so a second entry here would be a prompt that always fails.
  _antigravity_cli_dependencies || return 1
  _antigravity_download_binary || return 1
  _antigravity_apply_va39_patches || return 1
  _antigravity_compile_helper || return 1
  log_success "Antigravity CLI installed"
  return 0
}

uninstall_antigravity_cli() {
  log_info "Uninstalling Antigravity CLI..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if [ ! -f "$PREFIX/bin/agy" ]; then
    log_warn "Antigravity CLI is not installed"
    return 1
  fi

  if [ -f "$AGY_DATA_DIR/agy.va39" ]; then
    rm -f "$PREFIX/bin/agy"
    rm -rf "$AGY_DATA_DIR"
    log_success "Antigravity CLI (native) uninstalled"
    return 0
  fi

  _antigravity_proot_ubuntu /bin/bash -c \
    'rm -f /root/.local/bin/agy /root/.local/bin/agy.va39 && rm -rf /root/.agy' \
    &>>"$LOG_FILE"

  local ubuntu_bashrc
  ubuntu_bashrc="$(_antigravity_detect_ubuntu_root)/root/.bashrc"

  if [ -f "$ubuntu_bashrc" ]; then
    sed -i '/# antigravity-cli/d; /export PATH=\/root\/.local\/bin/d' "$ubuntu_bashrc"
  fi

  if rm -f "$PREFIX/bin/agy" &>>"$LOG_FILE"; then
    log_success "Antigravity CLI (proot-distro) uninstalled"
    return 0
  else
    log_error "Failed to uninstall Antigravity CLI"
    return 1
  fi
}

update_antigravity_cli() {
  _check_update_needed "Antigravity CLI" "$(_get_installed_version agy)" "$(_get_remote_github_version antigravity-cli/antigravity-cli)" _update_antigravity_cli_impl
}

_update_antigravity_cli_impl() {
  if [ -f "$AGY_DATA_DIR/agy.va39" ]; then
    _antigravity_download_binary || return 1
    _antigravity_apply_va39_patches || return 1
    log_success "Antigravity CLI (native) updated"
    return 0
  fi

  # Karnel cannot create proot installs, so anything found here is state it
  # does not own; refuse rather than report a misleading update path.
  log_error "Antigravity CLI Proot update is unavailable: upstream has no verifiable artifact"
  return 1
}

reinstall_antigravity_cli() {
  uninstall_antigravity_cli || [[ $? -eq 2 ]] || return 1

  install_antigravity_cli
}
