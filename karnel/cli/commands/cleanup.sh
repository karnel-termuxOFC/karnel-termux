#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

cleanup_main() {
  for arg in "$@"; do
    case "$arg" in
      --help|-h) echo; echo "Usage: karnel cleanup"; echo; echo "  Cleans npm, pip, pkg caches and temp files."; echo; return ;;
    esac
  done

  echo
  box "Karnel Cleanup"
  echo

  local total_freed=0

  # npm cache
  if command -v npm &>/dev/null; then
    local npm_cache_dir
    npm_cache_dir=$(npm config get cache 2>/dev/null)
    if [[ -d "$npm_cache_dir" ]]; then
      local npm_size
      npm_size=$(timeout 10 du -sh "$npm_cache_dir" 2>/dev/null | awk '{print $1}')
      log_info "npm cache: ${npm_size} → cleaning..."
      timeout 60 npm cache clean --force 2>/dev/null && log_success "npm cache cleaned" || log_warn "npm cache clean timed out (large cache, skipping)"
    fi
  fi

  # pip cache
  if command -v pip &>/dev/null; then
    local pip_size
    pip_size=$(du -sh "$HOME/.cache/pip" 2>/dev/null | awk '{print $1}')
    if [[ -n "$pip_size" ]]; then
      log_info "pip cache: ${pip_size} → cleaning..."
      pip cache purge 2>/dev/null && log_success "pip cache cleaned" && ((total_freed++))
    fi
  fi

  # karnel install logs
  local log_count
  log_count=$(find "$KARNEL_CACHE" -name 'install_*.log' 2>/dev/null | wc -l)
  if (( log_count > 0 )); then
    log_info "Removing $log_count install log(s)..."
    rm -f "$KARNEL_CACHE"/install_*.log 2>/dev/null && log_success "Logs removed"
  fi

  # __pycache__ dirs
  local pycache_size
  pycache_size=$(find "$PREFIX/lib/"python3* -name "__pycache__" -type d 2>/dev/null | head -n 1)
  if [[ -n "$pycache_size" ]] && compgen -G "$PREFIX/lib/python3.*" >/dev/null 2>&1; then
    log_info "Python __pycache__: cleaning..."
    find "$PREFIX/lib/"python3* -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
    log_success "Python cache cleaned"
    ((total_freed++))
  fi

  # pkg clean
  if command -v pkg &>/dev/null; then
    log_info "Cleaning pkg cache..."
    pkg clean -y 2>/dev/null && log_success "pkg cache cleaned"
  fi

  # karnel banner cache (regenerate)
  # The cache is keyed by terminal width (banner_cache.<cols>).
  rm -f "$KARNEL_CACHE"/banner_cache* 2>/dev/null
  rm -f "$KARNEL_CACHE/.last_tip_index" 2>/dev/null

  echo
  log_success "Cleanup completed!"
  echo
}
