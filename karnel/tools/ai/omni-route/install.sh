#!/usr/bin/env bash
import "@/utils/npm"
import "@/utils/npm-shebang"

import "@/utils/log"
import "@/utils/version"

: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
: "${KARNEL_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"
LOG_FILE="$KARNEL_CACHE/install_ai.log"
OMNI_ROUTE_DATA_DIR="$KARNEL_DATA/omni-route"
OMNI_ROUTE_PKG="$OMNI_ROUTE_DATA_DIR/packages/karnelroute"
OMNI_ROUTE_MARKER=".karnel-managed"
OMNI_ROUTE_LOCAL_BIN="$OMNI_ROUTE_PKG/node_modules/karnelroute/bin/karnelroute.mjs"

_omni_route_data_owned() {
  [[ -f "$OMNI_ROUTE_DATA_DIR/$OMNI_ROUTE_MARKER" ]]
}

_omni_route_ok() {
  command -v omni-route &>/dev/null && omni-route --version &>/dev/null 2>&1
}

_omni_route_wrapper_is_karnel_owned() {
  local wrapper="$1"
  [[ -f "$wrapper" ]] && grep -qF '# Karnel-managed omniRoute wrapper' "$wrapper"
}

_omni_route_verify_ownership() {
  if [[ -e "$OMNI_ROUTE_DATA_DIR" ]] && ! _omni_route_data_owned; then
    log_error "Refusing to replace unowned omniRoute data: $OMNI_ROUTE_DATA_DIR"
    return 1
  fi
}

_omni_route_install_wrapper() {
  local cmd="$1" wrapper="$PREFIX/bin/$1"
  if [[ -e "$wrapper" ]] && ! _omni_route_wrapper_is_karnel_owned "$wrapper"; then
    log_warn "Keeping existing $cmd command not managed by Karnel"
    return 1
  fi
  mkdir -p "$PREFIX/bin" || return 1
  local temporary
  temporary="$(mktemp "$PREFIX/bin/.$cmd.XXXXXX")" || return 1
  cat > "$temporary" <<WRAPPER
#!$PREFIX/bin/env bash
# Karnel-managed omniRoute wrapper
exec node "$OMNI_ROUTE_LOCAL_BIN" "\$@"
WRAPPER
  chmod +x "$temporary" || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$wrapper" || return 1
}

_omni_route_remove_wrapper() {
  local wrapper="$PREFIX/bin/$1"
  _omni_route_wrapper_is_karnel_owned "$wrapper" && rm -f "$wrapper"
}

# Detect Termux / Android (Node reports platform "android" and uname mentions android)
_omni_route_is_android() {
  if [ "$(node -e 'process.stdout.write(process.platform)' 2>/dev/null)" = "android" ]; then
    return 0
  fi
  case "$(uname -s 2>/dev/null) $(uname -o 2>/dev/null)" in
    *android*|*Android*) return 0 ;;
  esac
  return 1
}

# Apply platform-specific fixes so omniRoute actually runs on Termux/Android.
_omni_route_apply_platform_fixes() {
  local pkg_root="$1"
  [ -d "$pkg_root" ] || return 0
  _omni_route_is_android || return 0

  log_info "Termux/Android detected — applying native build fixes for omniRoute..."

  local ng="$PREFIX/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js"
  if [ -x "$ng" ] && command -v cc >/dev/null 2>&1; then
    for mod in better-sqlite3 sqlite-vec; do
      local moddir="$pkg_root/node_modules/$mod"
      [ -d "$moddir" ] || continue
      log_info "Rebuilding native module: $mod (aarch64/Bionic)"
      if ( cd "$moddir" && CC=clang CXX=clang++ GYP_DEFINES="android_ndk_path=$PREFIX" node "$ng" rebuild --release "-Dandroid_ndk_path=$PREFIX" ) >>"$LOG_FILE" 2>&1; then
        log_success "Rebuilt $mod"
      else
        log_warn "Could not rebuild $mod (see $LOG_FILE); omniRoute may fail to open its database"
      fi
    done
  else
    log_warn "Native toolchain (node-gyp/clang) not found; cannot rebuild omniRoute native modules"
  fi

  local ig
  ig=$(find "$pkg_root/node_modules/karnelroute/dist/node_modules/next" -path '*router-utils/instrumentation-globals.external.js' 2>/dev/null | head -1)
  if [ -n "$ig" ] && grep -q "An error occurred while loading instrumentation hook" "$ig"; then
    if perl -0pi -e 's/err\.message = `An error occurred while loading instrumentation hook: \$\{err\.message\}`;\s*\n\s*throw err;/err.message = `An error occurred while loading instrumentation hook: ${err.message}`;\n            console.error("[instrumentation] Non-fatal error in instrumentation hook (server continues):", err && err.message ? err.message : err);/g' "$ig"; then
      log_success "Patched Next.js instrumentation (hook errors are now non-fatal)"
    else
      log_warn "Could not patch Next.js instrumentation at $ig"
    fi
  fi
}

_omni_route_wrap_and_fix() {
  for cmd in karnelroute omni-route; do
    _omni_route_install_wrapper "$cmd" || true
  done
  _omni_route_apply_platform_fixes "$OMNI_ROUTE_PKG"
  mkdir -p "$OMNI_ROUTE_DATA_DIR"
  : >"$OMNI_ROUTE_DATA_DIR/$OMNI_ROUTE_MARKER"
}

install_omni_route() {
  if _omni_route_ok; then
    log_info "omniRoute already installed ($(omni-route --version 2>&1 | tail -1))"
    _omni_route_apply_platform_fixes "$OMNI_ROUTE_PKG"
    return 2
  fi

  _omni_route_verify_ownership || return 1

  if [ -f "$OMNI_ROUTE_LOCAL_BIN" ]; then
    sed -i '1s|^#!/usr/bin/env node|#!'"$PREFIX"'/bin/node|' "$OMNI_ROUTE_LOCAL_BIN" 2>/dev/null
    _omni_route_wrap_and_fix
    if _omni_route_ok; then
      log_success "omniRoute restored from local install"
      return 0
    fi
  fi

  if ! command -v npm &>/dev/null; then
    if ! pkg install nodejs-lts -y &>>"$LOG_FILE"; then
      log_error "Failed to install Node.js (required by omniRoute)"
      return 1
    fi
  fi

  log_info "Installing omniRoute (this may take a while)..."
  if command -v npm >/dev/null 2>&1 && karnel_npm i karnelroute --prefix "$OMNI_ROUTE_PKG" 2>>"$LOG_FILE"; then
  _fix_npm_shebang "omni-route" || return 1
    sed -i '1s|^#!/usr/bin/env node|#!'"$PREFIX"'/bin/node|' "$OMNI_ROUTE_LOCAL_BIN" 2>/dev/null
    _omni_route_wrap_and_fix
    if _omni_route_ok; then
      log_success "omniRoute installed"
      return 0
    fi
  fi

  log_error "Failed to install omniRoute; see $LOG_FILE for npm output"
  return 1
}

uninstall_omni_route() {
  if [[ ! -e "$PREFIX/bin/omni-route" && ! -e "$PREFIX/bin/karnelroute" && ! -e "$OMNI_ROUTE_DATA_DIR" ]]; then
    log_info "omniRoute is not installed"
    return 2
  fi

  _omni_route_verify_ownership || return 1

  log_info "Uninstalling omniRoute..."
  if _omni_route_data_owned; then
    rm -rf "$OMNI_ROUTE_DATA_DIR"
  fi
  _omni_route_remove_wrapper karnelroute
  _omni_route_remove_wrapper omni-route
  log_success "omniRoute uninstalled"
  return 0
}

_omni_route_installed_version() {
  local v
  v=$(npm ls karnelroute --prefix "$OMNI_ROUTE_PKG" --depth=0 2>/dev/null | grep 'karnelroute@' | sed 's/.*@//')
  echo "$v"
}

update_omni_route() {
  _check_update_needed "omniRoute" "$(_omni_route_installed_version)" "$(_get_remote_npm_version karnelroute)" _do_update_omni_route
}

_do_update_omni_route() {
  if ! _omni_route_ok; then
    install_omni_route
    return $?
  fi

  if karnel_npm i karnelroute@latest --prefix "$OMNI_ROUTE_PKG" 2>>"$LOG_FILE"; then
    sed -i '1s|^#!/usr/bin/env node|#!'"$PREFIX"'/bin/node|' "$OMNI_ROUTE_LOCAL_BIN" 2>/dev/null
    _omni_route_wrap_and_fix
    if _omni_route_ok; then
      return 0
    fi
    log_error "omniRoute update completed but the command does not run; see $LOG_FILE"
    return 1
  else
    log_error "Failed to update omniRoute"
    return 1
  fi
}

reinstall_omni_route() {
  uninstall_omni_route || [[ $? -eq 2 ]] || return 1
  install_omni_route
}