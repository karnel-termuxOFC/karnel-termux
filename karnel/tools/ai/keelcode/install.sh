#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"
import "@/utils/install"
# Safe, self-contained tar extractor (independent of framework import).
# Rejects path traversal, absolute paths, unsafe symlinks/hardlinks, and
# device/special-file entries. Intentionally has NO unsafe fallback.
_archive_member_is_safe() {
  local member="$1"
  [[ -n "$member" && "$member" != /* && "$member" != *\\* ]] || return 1
  case "/$member/" in
    */../*) return 1 ;;
  esac
}

_archive_link_is_safe() {
  local member="$1" target="$2" part depth=0
  local -a _archive_parts
  [[ -n "$target" && "$target" != /* && "$target" != *\\* ]] || return 1
  IFS=/ read -r -a _archive_parts <<<"$(dirname "$member")/$target"
  for part in "${_archive_parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) ((depth > 0)) || return 1; ((depth -= 1)) ;;
      *) ((depth += 1)) ;;
    esac
  done
}

safe_extract_tar() {
  local archive="$1" outdir="$2" strip_components="${3:-0}"
  local member listing verbose mode line target
  listing=$(tar -tf "$archive" 2>/dev/null) || return 1
  while IFS= read -r member; do
    _archive_member_is_safe "$member" || return 1
  done <<<"$listing"
  verbose=$(tar -tvf "$archive" 2>/dev/null) || return 1
  while IFS= read -r line; do
    mode=${line%% *}
    case "${mode:0:1}" in
      l)
        member=${line%% -> *}; member=${member##* }
        target=${line#* -> }
        _archive_link_is_safe "$member" "$target" || return 1
        ;;
      h)
        member=${line%% link to *}; member=${member##* }
        target=${line#* link to }
        _archive_link_is_safe "$member" "$target" || return 1
        ;;
      b|c|p) return 1 ;;
    esac
  done <<<"$verbose"
  mkdir -p "$outdir" || return 1
  tar -xf "$archive" -C "$outdir" --strip-components="$strip_components" \
    --no-same-owner --no-same-permissions
}



KEELCODE_PACKAGE="@keelcode-ai/keelcode"
: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
: "${KARNEL_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"
LOG_FILE="$KARNEL_CACHE/install_ai.log"
KEELCODE_DATA_DIR="$KARNEL_DATA/keelcode"
KEELCODE_MARKER=".karnel-managed"
KEELCODE_WRAPPER_MARKER="Karnel KeelCode Termux wrapper"

_keelcode_data_owned() {
  [[ -f "$KEELCODE_DATA_DIR/$KEELCODE_MARKER" ]]
}

_keelcode_wrapper_owned() {
  [[ -f "$PREFIX/bin/keelcode" ]] || return 1
  grep -qF "$KEELCODE_WRAPPER_MARKER" "$PREFIX/bin/keelcode" 2>/dev/null
}

_keelcode_verify_ownership() {
  if [[ -e "$KEELCODE_DATA_DIR" ]] && ! _keelcode_data_owned; then
    log_error "Refusing to replace unowned KeelCode data: $KEELCODE_DATA_DIR"
    return 1
  fi
  if [[ -e "$PREFIX/bin/keelcode" ]] && ! _keelcode_wrapper_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/keelcode"
    return 1
  fi
  if command -v keelcode &>/dev/null && ! _keelcode_wrapper_owned; then
    log_error "Refusing to shadow the existing keelcode command: $(command -v keelcode)"
    return 1
  fi
}

# Integrity of the *platform* release, not of `latest`. The npm package
# publishes each binary as its own version tag (0.2.0-linux-arm64, ...), so
# asking /latest returns the base launcher's digest and the comparison always
# fails against the arm64 tarball we actually download.
_keelcode_get_integrity() {
  local version="$1"
  curl -fsSL "https://registry.npmjs.org/@keelcode-ai/keelcode/${version}-linux-arm64" 2>/dev/null |
    python3 -c "import json,sys; print(json.load(sys.stdin).get('dist',{}).get('integrity',''))" 2>/dev/null
}

_keelcode_install_termux_wrapper() {
  local version staging archive native_dir wrapper expected actual
  version="$(karnel_npm view "$KEELCODE_PACKAGE" version 2>/dev/null)" || return 1
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1

  command -v grun &>/dev/null || pkg install glibc-runner -y || return 1
  mkdir -p "$KARNEL_DATA" "$PREFIX/bin" "$(dirname "$LOG_FILE")"
  staging="$(mktemp -d "$KARNEL_DATA/.keelcode.XXXXXX")" || return 1
  archive="$staging/keelcode.tgz"

  if ! curl --fail --silent --show-error --location \
    "https://registry.npmjs.org/@keelcode-ai/keelcode/-/keelcode-${version}-linux-arm64.tgz" \
    -o "$archive"; then
    rm -rf "$staging"
    log_error "Failed to download the official KeelCode linux-arm64 binary"
    return 1
  fi

  expected=$(_keelcode_get_integrity "$version")
  if [[ "$expected" =~ ^sha512-[A-Za-z0-9+/=]+$ ]]; then
    actual=$(python3 -c 'import base64,hashlib,sys; print("sha512-" + base64.b64encode(hashlib.sha512(open(sys.argv[1], "rb").read()).digest()).decode())' "$archive" 2>/dev/null)
    if [ -z "$actual" ] || [ "$actual" != "$expected" ]; then
      rm -rf "$staging"
      log_error "KeelCode package failed npm registry integrity validation"
      return 1
    fi
  else
    rm -rf "$staging"
    log_error "KeelCode integrity unavailable from npm registry; refusing install"
    return 1
  fi

  if ! safe_extract_tar "$archive" "$staging" ||
    [[ ! -x "$staging/package/bin/keelcode" || ! -x "$staging/package/bin/rg" ]]; then
    rm -rf "$staging"
    log_error "Failed to extract the official KeelCode linux-arm64 binary"
    return 1
  fi

  native_dir="$KEELCODE_DATA_DIR/native"
  local previous="$KEELCODE_DATA_DIR/native.previous.$$"
  if [ -d "$native_dir" ]; then
    mv "$native_dir" "$previous" 2>/dev/null || true
  fi
  mkdir -p "$KEELCODE_DATA_DIR"
  mv "$staging/package" "$native_dir" || {
    [ -d "$previous" ] && mv "$previous" "$native_dir" 2>/dev/null || true
    rm -rf "$staging"
    return 1
  }
  rm -rf "$staging"
  : >"$KEELCODE_DATA_DIR/$KEELCODE_MARKER"

  wrapper="$PREFIX/bin/keelcode"
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.keelcode.XXXXXX")" || return 1
  cat >"$temporary" <<EOF
#!$PREFIX/bin/bash
# $KEELCODE_WRAPPER_MARKER
export KEELCODE_RG_PATH="$native_dir/bin/rg"
exec grun "$native_dir/bin/keelcode" "\$@"
EOF
  chmod 755 "$temporary"
  if ! "$temporary" --version >/dev/null 2>&1; then
    rm -f "$temporary"
    [ -d "$previous" ] && rm -rf "$native_dir" && mv "$previous" "$native_dir" 2>/dev/null || true
    log_error "KeelCode binary failed validation after install"
    return 1
  fi
  mv -f "$temporary" "$wrapper"
  [ -d "$previous" ] && rm -rf "$previous"
  return 0
}

install_keelcode() {
  if command -v keelcode &>/dev/null && keelcode --version >/dev/null 2>&1 && _keelcode_wrapper_owned; then
    log_info "KeelCode is already installed"
    return 2
  fi
  _keelcode_verify_ownership || return 1

  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by KeelCode)"
      return 1
    fi
  fi

  log_info "Installing KeelCode..."
  local output rc
  output="$(karnel_npm install -g "$KEELCODE_PACKAGE" --force 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if (( rc != 0 )); then
    log_error "Failed to install KeelCode"
    return 1
  fi
  _fix_npm_shebang "keelcode" || return 1
  if ! command -v keelcode &>/dev/null; then
    log_error "KeelCode binary was not found after npm installation"
    return 1
  fi

  _keelcode_install_termux_wrapper || return 1
  log_success "KeelCode installed"
}

uninstall_keelcode() {
  if ! _keelcode_data_owned && ! _keelcode_wrapper_owned; then
    if [ -e "$KEELCODE_DATA_DIR" ] || [ -e "$PREFIX/bin/keelcode" ]; then
      _keelcode_verify_ownership
      return $?
    fi
    log_info "KeelCode is not installed"
    return 2
  fi

  log_info "Uninstalling KeelCode..."
  _keelcode_verify_ownership || return 1

  if _keelcode_wrapper_owned; then
    rm -f "$PREFIX/bin/keelcode"
  fi
  if _keelcode_data_owned; then
    rm -rf "$KEELCODE_DATA_DIR"
  fi

  local output rc
  output="$(karnel_npm uninstall -g "$KEELCODE_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_warn "npm uninstall of $KEELCODE_PACKAGE reported a failure (may already be gone)"
  fi
  log_success "KeelCode uninstalled"
}

update_keelcode() {
  _check_update_needed "KeelCode" \
    "$(_get_installed_npm_version "$KEELCODE_PACKAGE")" \
    "$(_get_remote_npm_version "$KEELCODE_PACKAGE")" \
    _do_update_keelcode
}

_do_update_keelcode() {
  local output rc
  output="$(karnel_npm update -g "$KEELCODE_PACKAGE" --force 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to update KeelCode"
    return 1
  fi
  _keelcode_install_termux_wrapper || {
    log_error "Failed to update KeelCode linux-arm64 binary"
    return 1
  }
}

reinstall_keelcode() {
  uninstall_keelcode || [[ $? -eq 2 ]] || return 1
  install_keelcode
}