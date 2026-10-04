#!/usr/bin/env bash

KARNEL_VERSION=""
if [[ -n "$KARNEL_PATH" ]] && [[ -f "$KARNEL_PATH/../package.json" ]]; then
  KARNEL_VERSION=$(grep '"version"' "$KARNEL_PATH/../package.json" | head -1 | sed -E 's/.*"version": "([^"]+)".*/\1/')
fi
: "${KARNEL_VERSION:=unknown}"

# -------------------------
# Directorios del usuario
# -------------------------

: "${HOME:?HOME is unset — cannot determine config paths}"

# Karnel-managed commands are installed in $PREFIX/bin. Keep that directory
# ahead of user-local binaries so an obsolete external install cannot shadow
# an update that Karnel just completed, while preserving explicit PATH
# overrides that appear before both directories.
_karnel_prefer_prefix_bin() {
  [[ -n "${PREFIX:-}" ]] || return 0

  local prefix_bin="$PREFIX/bin" local_bin="$HOME/.local/bin"
  local -a entries=() reordered=()
  local prefix_index=-1 local_index=-1 index=0 entry joined="" inserted=0
  IFS=: read -r -a entries <<< "${PATH:-}"
  for entry in "${entries[@]}"; do
    [[ "$entry" == "$prefix_bin" && $prefix_index -lt 0 ]] && prefix_index=$index
    [[ "$entry" == "$local_bin" && $local_index -lt 0 ]] && local_index=$index
    ((index += 1))
  done
  (( prefix_index > local_index && local_index >= 0 )) || return 0

  for entry in "${entries[@]}"; do
    [[ "$entry" == "$prefix_bin" ]] && continue
    if [[ "$entry" == "$local_bin" && $inserted -eq 0 ]]; then
      reordered+=("$prefix_bin")
      inserted=1
    fi
    reordered+=("$entry")
  done
  for entry in "${reordered[@]}"; do
    joined+="${joined:+:}$entry"
  done
  export PATH="$joined"
}
_karnel_prefer_prefix_bin
unset -f _karnel_prefer_prefix_bin

# Respect an explicit override (tests and isolated prefixes rely on it), and
# otherwise fall back to the XDG locations.
# configuración
: "${KARNEL_CONFIG:=${XDG_CONFIG_HOME:-$HOME/.config}/karnel}"

# cache
: "${KARNEL_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"

# datos del usuario
: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"

# -------------------------
# Rutas internas del CLI
# -------------------------

KARNEL_BIN="$KARNEL_PATH/bin"
KARNEL_MODULES="$KARNEL_PATH/modules"
KARNEL_UTILS="$KARNEL_PATH/utils"
KARNEL_CLI="$KARNEL_PATH/cli"
KARNEL_TOOLS="$KARNEL_DATA/tools"
KARNEL_RUN="$KARNEL_CACHE/run"
KARNEL_LOGS="$KARNEL_CACHE/logs"
KARNEL_PLUGINS="$KARNEL_DATA/plugins"

# -------------------------
# Crear directorios
# -------------------------

_karnel_secure_directory() {
  local directory="$1"

  if [[ -L "$directory" ]]; then
    printf 'karnel: refusing symlink directory: %s\n' "$directory" >&2
    return 1
  fi
  mkdir -p -m 700 "$directory" || return 1
  if [[ -L "$directory" ]]; then
    printf 'karnel: refusing symlink directory: %s\n' "$directory" >&2
    return 1
  fi
  chmod 700 "$directory"
}

if [[ "${KARNEL_READ_ONLY:-0}" != "1" ]]; then
  for _karnel_directory in \
    "$KARNEL_CONFIG" \
    "$KARNEL_CACHE" \
    "$KARNEL_DATA" \
    "$KARNEL_TOOLS" \
    "$KARNEL_RUN" \
    "$KARNEL_LOGS"; do
    _karnel_secure_directory "$_karnel_directory" || return 1
  done
  unset _karnel_directory
fi

# -------------------------
# TUI Colors - Ruby & Obsidian
# -------------------------
[[ -f "$KARNEL_UTILS/dialogrc" ]] && export DIALOGRC="$KARNEL_UTILS/dialogrc"
export NEWT_COLORS='
root=,black
window=,black
border=magenta,black
textbox=white,black
button=white,red
actbutton=white,magenta
checkbox=magenta,black
actcheckbox=white,red
label=white,black
listbox=white,black
actlistbox=white,magenta
title=red,black
'
