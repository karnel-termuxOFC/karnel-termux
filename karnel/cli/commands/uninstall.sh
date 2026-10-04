#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/tools"

uninstall_main() {

  if [[ $# -eq 0 ]]; then
    echo
    box "Karnel Uninstall"
    echo
    log_info "Usage: karnel uninstall <target>"
    log_info "Usage: karnel uninstall <target> --tool1 --tool2"
    echo
    log_info "Available targets:"
    echo
    list_item "lang       - Remove language packages"
    list_item "db         - Remove databases"
    list_item "ai         - Remove AI tools"
    list_item "editor     - Remove code editor"
    list_item "dev        - Remove development tools"
    list_item "npm        - Remove Node.js global modules"
    list_item "shell      - Remove ZSH + Oh My Zsh"
    list_item "ui         - Restore Termux UI to default"
    list_item "auto       - Remove automation tools"
    list_item "network    - Remove network tools"
    list_item "utils      - Remove utility scripts"
    list_item "games      - Remove games"
    list_item "deploy     - Remove deploy CLIs (Vercel, Railway, Netlify, Supabase)"
    list_item "voice      - Remove voice command"
    list_item "osint      - Remove OSINT tools"
    list_item "security   - Remove security tools"
    list_item "plugin     - Remove plugins"
    list_item "supabase   - Remove Supabase CLI"
    echo
    log_info "Uninstall specific tools with flags:"
    echo
    list_item "karnel uninstall ai --qwen-code --ollama"
    list_item "karnel uninstall db --postgresql --sqlite"
    list_item "Run ${D_CYAN}karnel list <target>${NC} to see all available tools"
    echo
    log_warn "Warning: This will remove installed packages and configurations!"
    echo
    return
  fi

  # Separate module target from tool flags
  local module_target=""
  local -a tool_flags=()
  local -a invalid_args=()

  for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
      local flag="${arg#--}"
      tool_flags+=("$flag")
    elif [[ -z "$module_target" ]]; then
      module_target="$arg"
    else
      invalid_args+=("$arg")
    fi
  done

  # If there are invalid arguments, show error and abort
  if [[ ${#invalid_args[@]} -gt 0 ]]; then
    log_error "Invalid arguments: ${invalid_args[*]}"
    echo
    log_info "To uninstall specific tools, use -- before the name:"
    log_info "  ${D_CYAN}karnel uninstall $module_target --${invalid_args[0]}${NC}"
    echo
    return 1
  fi

  # If no module target specified, show error
  if [[ -z "$module_target" ]]; then
    log_error "No target specified"
    echo "Run 'karnel uninstall' to see available targets"
    return 1
  fi

  # If no tool flags, uninstall entire module (original behavior)
  if [[ ${#tool_flags[@]} -eq 0 ]]; then
    _uninstall_full_module "$module_target"
  else
    # Uninstall specific tools
    _uninstall_specific_tools "$module_target" "${tool_flags[@]}"
  fi
}

# Uninstall entire module (original behavior)
_uninstall_full_module() {
  local target="$1"

  case "$target" in
  lang)
    import "@/modules/lang"
    uninstall_lang
    ;;
  db)
    import "@/modules/db"
    uninstall_db
    ;;
  ai)
    import "@/modules/ai"
    uninstall_ai
    ;;
  editor)
    import "@/modules/editor"
    uninstall_editor
    ;;
  dev)
    import "@/modules/dev"
    uninstall_dev
    ;;
  npm)
    import "@/modules/npm"
    uninstall_npm
    ;;
  shell)
    import "@/modules/shell"
    uninstall_shell
    ;;
  ui)
    import "@/modules/ui"
    uninstall_ui
    ;;
  auto)
    import "@/modules/auto"
    uninstall_auto
    ;;
  osint)
    import "@/modules/osint"
    uninstall_osint
    ;;
  network)
    import "@/modules/network"
    uninstall_network
    ;;
  utils)
    import "@/modules/utils"
    uninstall_utils
    ;;
  plugin)
    import "@/modules/plugin"
    uninstall_plugin_module
    ;;
  security)
    import "@/modules/security"
    uninstall_security
    ;;
  games)
    import "@/modules/games"
    uninstall_games
    ;;
  supabase)
    import "@/tools/deploy/supabase/install"
    uninstall_supabase
    ;;
  deploy)
    import "@/modules/deploy"
    uninstall_deploy
    ;;
  voice)
    import "@/modules/voice"
    uninstall_voice
    ;;
  *)
    log_warn "Unknown uninstall target: $target"
    echo "Run 'karnel uninstall' to see available targets"
    return 1
    ;;
  esac

  local rc=$?
  if (( rc == 0 || rc == 2 )); then
    karnel_mark_module_not_installed "$target"
    return 0
  fi
  return "$rc"
}

_uninstall_specific_tools() {
  local module="$1"
  shift
  if [[ "$module" == "osint" ]]; then
    import "@/tools/osint/robin/common"
    _robin_print_disclaimer
  fi
  _batch_tool_action "$module" "uninstall" "$@"
}
