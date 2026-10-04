#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

stats_main() {
  separator
  box "◈ KARNEL STATS ◈"
  separator
  echo

  _stats_version
  echo
  _stats_modules
  echo
  _stats_disk
  echo
  _stats_tools
  echo
}

_stats_version() {
  printf "  ${D_CYAN}%-14s${NC} v%s\n" "Version:" "$KARNEL_VERSION"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "KARNEL_PATH:" "$KARNEL_PATH"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Shell:" "${SHELL##*/}"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Node:" "$(_stats_probe node node -v)"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "npm:" "$(_stats_probe npm npm -v)"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Python:" "$(_stats_probe python3 python3 -V)"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Go:" "$(_stats_probe go go version)"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Rust:" "$(_stats_probe rustc rustc --version)"
}

# Runs <bin> <args> only when the binary exists, so a missing toolchain never
# prints an empty value (a failed pipe into awk still exits 0).
_stats_probe() {
  local bin="$1"
  shift
  if ! command -v "$bin" &>/dev/null; then
    echo "not installed"
    return 0
  fi
  local out
  if ! out="$("$@" 2>/dev/null)" || [[ -z "$out" ]]; then
    echo "not installed"
    return 0
  fi
  printf '%s' "$out"
}

_stats_modules() {
  log_info "Installed Modules"
  echo
  local -a modules=(ai auto db deploy dev editor games lang network npm osint plugin security shell ui utils voice)
  local installed=0
  local not_installed=0
  local status marker_count

  for mod in "${modules[@]}"; do
    if _stats_module_installed "$mod"; then
      marker_count="$(_stats_owned_tool_count "$mod")"
      if [[ "$marker_count" -gt 0 ]]; then
        status="${GREEN}installed${NC} (${marker_count} managed)"
      else
        status="${GREEN}installed${NC}"
      fi
      ((installed++))
    else
      status="${D_RED}—${NC}"
      ((not_installed++))
    fi
    printf "    %-12s %b\n" "$mod" "$status"
  done
  echo
  printf "  ${D_CYAN}Total:${NC} %d installed, %d not installed\n" "$installed" "$not_installed"
}

# A module counts as installed when Karnel recorded it during a full-module
# install, when at least one of its tools carries an ownership marker, or when
# the module keeps state under $KARNEL_DATA/<module>.
_stats_module_installed() {
  local mod="$1"
  local -a entries=()

  [[ -f "${KARNEL_DATA:-/nonexistent}/${mod}/.installed" ]] && return 0
  [[ -d "${KARNEL_DATA:-/nonexistent}/ownership/$mod" ]] &&
    { shopt -s nullglob; entries=("${KARNEL_DATA}/ownership/$mod"/*); shopt -u nullglob; ((${#entries[@]} > 0)) && return 0; }

  case "$mod" in
  plugin)
    shopt -s nullglob
    entries=("${KARNEL_PLUGINS:-/nonexistent}"/*)
    shopt -u nullglob
    ((${#entries[@]} > 0)) && return 0
    ;;
  *)
    shopt -s nullglob
    entries=("${KARNEL_DATA:-/nonexistent}/$mod"/*)
    shopt -u nullglob
    ((${#entries[@]} > 0)) && return 0
    ;;
  esac
  return 1
}

_stats_owned_tool_count() {
  local -a entries=()
  [[ -d "${KARNEL_DATA:-/nonexistent}/ownership/$1" ]] || { echo 0; return; }
  shopt -s nullglob
  entries=("${KARNEL_DATA}/ownership/$1"/*)
  shopt -u nullglob
  echo "${#entries[@]}"
}

_stats_disk() {
  log_info "Disk Usage"
  echo
  local karnel_size data_size cache_size config_size

  karnel_size=$(du -sh "$KARNEL_PATH/.." 2>/dev/null | awk '{print $1}')
  data_size=$(du -sh "${KARNEL_DATA:-$HOME/.local/share/karnel-data}" 2>/dev/null | awk '{print $1}')
  cache_size=$(du -sh "$KARNEL_CACHE" 2>/dev/null | awk '{print $1}')
  config_size=$(du -sh "${KARNEL_CONFIG:-$HOME/.config/karnel}" 2>/dev/null | awk '{print $1}')

  printf "  ${D_CYAN}%-14s${NC} %s\n" "Framework:" "${karnel_size:-0}"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Data:" "${data_size:-0}"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Cache:" "${cache_size:-0}"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Config:" "${config_size:-0}"

  local total_storage
  total_storage=$(du -sh "$KARNEL_PATH/.." "${KARNEL_DATA:-$HOME/.local/share/karnel-data}" "$KARNEL_CACHE" 2>/dev/null | tail -1 | awk '{print $1}')
  echo
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Total:" "${total_storage:-unknown}"
}

_stats_tools() {
  log_info "Tool Counts"
  echo
  local -A tool_counts=(
    [ai]=0 [auto]=0 [db]=0 [deploy]=0 [dev]=0 [editor]=0
    [games]=0 [lang]=0 [network]=0 [npm]=0 [osint]=0
    [plugin]=0 [security]=0 [shell]=0 [ui]=0 [utils]=0 [voice]=0
  )

  local total=0
  local modules_with_tools=0
  for mod in "${!tool_counts[@]}"; do
    local tools_dir="$KARNEL_PATH/tools/$mod"
    if [[ -d "$tools_dir" ]]; then
      local count
      count=$(find "$tools_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
      tool_counts[$mod]=$count
      ((total += count))
      ((count > 0)) && ((modules_with_tools++))
    fi
  done

  for mod in ai auto db deploy dev editor games lang network npm osint plugin security shell ui utils voice; do
    local count=${tool_counts[$mod]:-0}
    [[ "$count" -gt 0 ]] && printf "    %-12s %d tools\n" "$mod" "$count"
  done
  echo
  printf "  ${D_CYAN}%-14s${NC} %d tools across %d modules\n" "Total:" "$total" "$modules_with_tools"
}
