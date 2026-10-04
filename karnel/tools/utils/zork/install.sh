#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_zork.log"
ZORK_DATA_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/zork"
ZORK_MARKER="$ZORK_DATA_DIR/.karnel-installed"

# The host's TLS certificate does not validate, so HTTPS to infocom-if.org
# fails outright. These are fetched over plain HTTP and authenticated by the
# pinned SHA-256 digests instead.
ZORK_URLS=(
  "1|http://www.infocom-if.org/downloads/zork1.zip|645027fb189ba8fd30daecca609e68e2bf2337b76e7b4f925ccf58778f3eac40"
  "2|http://www.infocom-if.org/downloads/zork2.zip|7c360a14ec61d8e8f265e1aa99a13487c5e0f016a752e4b32314405a0e9ffea0"
  "3|http://www.infocom-if.org/downloads/zork3.zip|ef4a3b2bb7d3ae65de54a54520b550f13b3a2e964985550ffd401c8925bd0b10"
)

_install_zork_deps() {
  loading "Installing dependencies" _install_zork_deps_impl
}

_install_zork_deps_impl() {
  if ! command -v frotz &>/dev/null; then
    if ! pkg install frotz -y &>>"$LOG_FILE"; then
      log_error "Failed to install frotz"
      return 1
    fi
  fi
  if ! command -v unzip &>/dev/null; then
    if ! pkg install unzip -y &>>"$LOG_FILE"; then
      log_error "Failed to install unzip"
      return 1
    fi
  fi
  return 0
}

_download_zork_data() {
  loading "Downloading Zork games" _download_zork_data_impl
}

_zork_owned() {
  [[ -f "$ZORK_MARKER" && -f "$PREFIX/bin/zork" ]] || return 1
  [[ "$(sha256sum "$PREFIX/bin/zork" 2>/dev/null)" == "$(<"$ZORK_MARKER")" ]]
}

_download_zork_data_impl() {
  local staging_dir old_dir
  if [[ -e "$ZORK_DATA_DIR" && ! -f "$ZORK_MARKER" ]]; then
    log_error "Refusing to replace unowned Zork data: $ZORK_DATA_DIR"
    return 1
  fi
  mkdir -p "$(dirname "$ZORK_DATA_DIR")"
  staging_dir=$(mktemp -d "$(dirname "$ZORK_DATA_DIR")/.zork.XXXXXX") || return 1

  for entry in "${ZORK_URLS[@]}"; do
    local num="${entry%%|*}"
    local url="${entry#*|}"
    local expected_sha="${url##*|}"
    url="${url%|*}"
    local zip_file="$staging_dir/zork${num}.zip"

    if ! curl -sSfL "$url" -o "$zip_file" 2>>"$LOG_FILE"; then
      rm -rf "$staging_dir"
      log_error "Failed to download Zork ${num}"
      return 1
    fi

    if ! verify_sha256 "$zip_file" "$expected_sha"; then
      rm -rf "$staging_dir"
      log_error "Zork ${num} failed integrity verification"
      return 1
    fi

    if ! safe_extract_zip "$zip_file" "$staging_dir" 2>>"$LOG_FILE"; then
      rm -rf "$staging_dir"; log_error "Failed to extract Zork ${num}"; return 1
    fi

    rm -f "$zip_file"
  done

  for entry in "${ZORK_URLS[@]}"; do
    local num="${entry%%|*}"
    if [ ! -f "$staging_dir/DATA/ZORK${num}.DAT" ]; then
      rm -rf "$staging_dir"
      log_error "Zork ${num} data not found after extraction"
      return 1
    fi
  done

  old_dir="${ZORK_DATA_DIR}.previous.$$"
  if [ -d "$ZORK_DATA_DIR" ] && ! mv "$ZORK_DATA_DIR" "$old_dir"; then
    rm -rf "$staging_dir"
    return 1
  fi
  if ! mv "$staging_dir" "$ZORK_DATA_DIR"; then
    [[ -d "$old_dir" ]] && mv "$old_dir" "$ZORK_DATA_DIR"
    return 1
  fi
  if [[ -f "$PREFIX/bin/zork" ]] && ! sha256sum "$PREFIX/bin/zork" >"$ZORK_MARKER"; then
    log_error "Failed to record Zork command ownership"
    return 1
  fi
  rm -rf "$old_dir"

  return 0
}

_create_zork_wrapper() {
  local wrapper="$PREFIX/bin/zork"
  if [[ -e "$wrapper" ]] && ! _zork_owned; then
    log_error "Refusing to replace unowned Zork command: $wrapper"
    return 1
  fi
  cat > "$wrapper" << 'WRAPPER'
#!/usr/bin/env bash
ZORK_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/zork"
ROM_DIR="$ZORK_DIR/DATA"

if [ ! -d "$ROM_DIR" ]; then
  echo "Zork data not found. Run: karnel install zork"
  exit 1
fi

case "${1:-1}" in
  1|I|i) game="ZORK1.DAT" ;;
  2|II|ii) game="ZORK2.DAT" ;;
  3|III|iii) game="ZORK3.DAT" ;;
  *) echo "Usage: zork [1|2|3] (default: 1)"; exit 1 ;;
esac

shift 2>/dev/null || true
exec frotz "$ROM_DIR/$game" "$@"
WRAPPER
  chmod +x "$wrapper"
  sha256sum "$wrapper" >"$ZORK_MARKER"
}

install_zork() {
  if command -v zork &>/dev/null; then
    log_info "Zork is already installed"
    return 2
  fi
  if [[ -e "$PREFIX/bin/zork" ]] && ! _zork_owned; then
    log_error "Refusing to replace unowned Zork command: $PREFIX/bin/zork"
    return 1
  fi
  log_info "Installing Zork..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _install_zork_deps || return 1
  _download_zork_data || return 1
  _create_zork_wrapper || return 1
  log_success "Zork installed"
  return 0
}

uninstall_zork() {
  if ! _zork_owned; then
    log_info "Zork is not installed by Karnel"
    return 2
  fi
  log_info "Uninstalling Zork..."

  rm -f "$PREFIX/bin/zork" "$ZORK_MARKER"
  rm -rf "$ZORK_DATA_DIR"

  log_success "Zork uninstalled"
  return 0
}

update_zork() {
  log_info "Updating Zork..."
  _download_zork_data || return 1
  log_success "Zork updated"
  return 0
}

reinstall_zork() {
  uninstall_zork || [[ $? -eq 2 ]] || return 1

  install_zork
}
