#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"
import "@/utils/colors"
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



: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
: "${KARNEL_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"
LOG_FILE="$KARNEL_CACHE/install_ai.log"
CLINE_DATA_DIR="$KARNEL_DATA/cline"
CLINE_MARKER=".karnel-managed"
CLINE_WRAPPER_MARKER="$CLINE_DATA_DIR/.karnel-wrapper-cline"

_cline_data_owned() {
  [[ -f "$CLINE_DATA_DIR/$CLINE_MARKER" ]]
}

_cline_wrapper_owned() {
  [[ -f "$CLINE_WRAPPER_MARKER" && -f "$PREFIX/bin/cline" ]] || return 1
  [[ "$(sha256sum "$PREFIX/bin/cline" 2>/dev/null)" == "$(<"$CLINE_WRAPPER_MARKER")" ]]
}

_cline_verify_ownership() {
  if [[ -e "$CLINE_DATA_DIR" ]] && ! _cline_data_owned; then
    log_error "Refusing to replace unowned Cline data: $CLINE_DATA_DIR"
    return 1
  fi
  if [[ -e "$PREFIX/bin/cline" ]] && ! _cline_wrapper_owned; then
    log_error "Refusing to replace unowned command: $PREFIX/bin/cline"
    return 1
  fi
  if command -v cline &>/dev/null && ! _cline_wrapper_owned; then
    log_error "Refusing to shadow the existing cline command: $(command -v cline)"
    return 1
  fi
}

_cline_install_deps() {
  loading "Installing dependencies" _cline_install_deps_impl
}

_cline_install_deps_impl() {
  declare -A DEPS=(
    ["nodejs-lts"]="node"
    ["glibc-repo"]=""
    ["glibc-runner"]="glibc-runner"
    ["glibc"]=""
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if [ -n "$bin_name" ] && command -v "$bin_name" &>/dev/null; then
      continue
    fi
    if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
      log_error "Failed to install $pkg_name"
      return 1
    fi
  done

  return 0
}

_cline_install_global() {
  loading "Installing Cline CLI via npm" _cline_install_global_impl
}

_cline_install_global_impl() {
  if ! karnel_npm i -g cline &>>"$LOG_FILE"; then
    log_error "Failed to install cline via npm"
    return 1
  fi
  _fix_npm_shebang "cline" || return 1

  local version tarball
  version=$(karnel_npm view cline version 2>/dev/null || echo "3.0.38")
  tarball=$(mktemp "$CLINE_DATA_DIR/cline-XXXXXX.tgz") || { log_error "Failed to create temp dir"; return 1; }
  if ! curl -fsSL \
    "https://registry.npmjs.org/@cline/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz" \
    -o "$tarball" &>>"$LOG_FILE"; then
    rm -f "$tarball"
    log_error "Failed to download cline linux-arm64 binary (version: $version)"
    return 1
  fi

  local expected actual
  expected=$(karnel_npm view "@cline/cli-linux-arm64@$version" dist.integrity 2>/dev/null)
  if [[ -z "$expected" ]]; then
    rm -f "$tarball"
    log_error "Falha ao obter a integridade do binário do Cline no registry npm"
    return 1
  fi
  actual=$(node -e 'const c=require("crypto");const h=c.createHash("sha512");h.update(require("fs").readFileSync(process.argv[1]));process.stdout.write("sha512-"+h.digest("base64"))' "$tarball" 2>/dev/null) || actual=""
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$tarball"
    log_error "Integridade do binário do Cline não confere (esperado $expected)"
    return 1
  fi

  mkdir -p "$CLINE_DATA_DIR"
  : >"$CLINE_DATA_DIR/$CLINE_MARKER"
  if ! safe_extract_tar "$tarball" "$CLINE_DATA_DIR" &>>"$LOG_FILE"; then
    rm -f "$tarball"
    log_error "Failed to extract cline linux-arm64 binary"
    return 1
  fi
  rm -f "$tarball"

  local extracted
  extracted="$CLINE_DATA_DIR/package"
  if [ -d "$extracted" ]; then
    mv "$extracted" "$CLINE_DATA_DIR/cli-linux-arm64" 2>/dev/null || true
  fi

  _cline_create_wrapper || return 1
  return 0
}

_cline_create_wrapper() {
  mkdir -p "$PREFIX/bin" "$CLINE_DATA_DIR" || return 1
  : >"$CLINE_DATA_DIR/$CLINE_MARKER" || return 1
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.cline.XXXXXX")" || return 1
  cat > "$temporary" << GLIBCWRAPPER
#!$PREFIX/bin/env bash
# Cline CLI — roda nativamente no Termux via glibc-runner
# Usa o glibc do termux-user-repository (instalado via apt)
# Sem proot, sem container, sem opencode.
# Instalado pelo Karnel Termux (karnel install ai --cline)

CLINE_BIN="$CLINE_DATA_DIR/cli-linux-arm64/bin/cline"

if [ ! -f "$CLINE_BIN" ]; then
  CLINE_BIN="$PREFIX/lib/node_modules/cline/bin/.cline"
fi

if [ ! -f "$CLINE_BIN" ]; then
  CLINE_BIN="$PREFIX/lib/node_modules/@cline/cli-linux-arm64/bin/cline"
fi

if [ ! -f "$CLINE_BIN" ]; then
  echo "Erro: Cline binary nao encontrado"
  echo "Rode: npm i -g cline"
  exit 1
fi

exec glibc-runner "$CLINE_BIN" "$@"
GLIBCWRAPPER
  chmod 755 "$temporary" || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$PREFIX/bin/cline" || return 1
  sha256sum "$PREFIX/bin/cline" >"$CLINE_WRAPPER_MARKER" || return 1
}

install_cline() {
  if _cline_wrapper_owned && _cline_data_owned; then
    log_info "Cline is already installed"
    return 2
  fi
  _cline_verify_ownership || return 1

  log_info "Installing Cline CLI..."

  mkdir -p "$(dirname "$LOG_FILE")"

  _cline_install_deps || return 1
  _cline_install_global || return 1

  if _cline_wrapper_owned; then
    log_success "Cline CLI installed"
    return 0
  fi

  log_error "Cline CLI installation failed: wrapper not verified"
  return 1
}

uninstall_cline() {
  log_info "Uninstalling Cline CLI..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if ! _cline_data_owned && ! _cline_wrapper_owned; then
    if [ -e "$CLINE_DATA_DIR" ] || [ -e "$PREFIX/bin/cline" ]; then
      _cline_verify_ownership
      return $?
    fi
    log_info "Cline CLI is not installed"
    return 2
  fi

  _cline_verify_ownership || return 1

  _cline_wrapper_owned && rm -f "$PREFIX/bin/cline"
  _cline_data_owned && rm -rf "$CLINE_DATA_DIR"

  karnel_npm uninstall -g cline &>>"$LOG_FILE" || true
  rm -rf "$PREFIX/lib/node_modules/@cline/cli-linux-arm64" &>>"$LOG_FILE" || true
  rm -f "$PREFIX/lib/node_modules/cline/bin/.cline" &>>"$LOG_FILE" || true

  log_success "Cline CLI uninstalled"
  return 0
}

update_cline() {
  _check_update_needed "Cline CLI" "$(_get_installed_npm_version cline)" "$(_get_remote_npm_version cline)" _update_cline_impl
}

_update_cline_impl() {
  if ! karnel_npm update -g cline &>>"$LOG_FILE"; then
    log_error "Failed to update cline"
    return 1
  fi

  _cline_install_global_impl || {
    log_error "Failed to update cline linux-arm64 binary"
    return 1
  }
  return 0
}

reinstall_cline() {
  uninstall_cline || [[ $? -eq 2 ]] || return 1
  install_cline
}