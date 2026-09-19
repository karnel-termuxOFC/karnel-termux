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
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Node:" "$(node -v 2>/dev/null || echo 'not installed')"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "npm:" "$(npm -v 2>/dev/null || echo 'not installed')"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Python:" "$(python3 -V 2>/dev/null | awk '{print $2}' || echo 'not installed')"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Go:" "$(go version 2>/dev/null | awk '{print $3}' || echo 'not installed')"
  printf "  ${D_CYAN}%-14s${NC} %s\n" "Rust:" "$(rustc --version 2>/dev/null | awk '{print $2}' || echo 'not installed')"
}

_stats_modules() {
  log_info "Installed Modules"
  echo
  local -a modules=(ai auto db deploy dev editor games lang network npm osint plugin security shell ui utils voice)
  local installed=0
  local not_installed=0
  local status

  for mod in "${modules[@]}"; do
    local marker="${KARNEL_DATA:-$HOME/.local/share/karnel-data}/${mod}/.installed"
    if [[ -f "$marker" ]]; then
      status="${GREEN}installed${NC}"
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
  for mod in "${!tool_counts[@]}"; do
    local tools_dir="$KARNEL_PATH/tools/$mod"
    if [[ -d "$tools_dir" ]]; then
      local count
      count=$(find "$tools_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
      tool_counts[$mod]=$count
      ((total += count))
    fi
  done

  for mod in ai auto db deploy dev editor games lang network npm osint plugin security shell ui utils voice; do
    local count=${tool_counts[$mod]:-0}
    [[ "$count" -gt 0 ]] && printf "    %-12s %d tools\n" "$mod" "$count"
  done
  echo
  printf "  ${D_CYAN}%-14s${NC} %d tools across %d modules\n" "Total:" "$total" "${#tool_counts[@]}"
}
