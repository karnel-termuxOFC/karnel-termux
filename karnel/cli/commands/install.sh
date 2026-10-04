#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/tools"

install_main() {

  if [[ $# -eq 0 ]]; then
    echo
    box "Karnel Install"
    echo
    log_info "Usage: karnel install <target>"
    log_info "Usage: karnel install <target> --tool1 --tool2"
    echo
    log_info "Available targets:"
    echo
    list_item "lang       - Language packages (Node.js, Python, Perl, PHP, Rust, C, C++, Go)"
    list_item "db         - Databases (PostgreSQL, MariaDB, SQLite, MongoDB, Redis)"
    list_item "ai         - AI tools (OpenCode, Gentle AI, Claude Code, etc.)"
    list_item "editor     - Code editor (code-server, neovim, nvchad)"
    list_item "dev        - Development tools"
    list_item "npm        - Node.js global modules (npm packages)"
    list_item "osint      - OSINT tools (Robin — Dark Web + LLM)"
    list_item "network    - Network tools (Dark Web OSINT, DedSec Network)"
    list_item "security   - Security tools (Nmap, Hydra, SQLMap, Metasploit, etc.)"
    list_item "utils      - Utility scripts (File Converter, Notes, QR Code, etc.)"
    list_item "shell      - ZSH + Oh My Zsh + plugins"
    list_item "ui         - Termux UI (font, cursor, extra-keys, banner)"
    list_item "auto       - Automation Tools (n8n)"
    list_item "deploy     - Deploy CLIs (Vercel, Railway, Netlify, Supabase)"
    list_item "games      - Games (Buzz, CTF God, Detective, etc.)"
    list_item "voice      - Voice command (speech-to-agent)"
    list_item "plugin     - Install plugins from the official registry"
    list_item "supabase   - Supabase CLI (types, migrate, functions, secrets)"
    echo
    log_info "Install specific tools with flags:"
    echo
    list_item "karnel install ai --qwen-code --ollama"
    list_item "karnel install db --postgresql --sqlite"
    list_item "karnel install dev --gh --fzf --jq"
    list_item "Run ${D_CYAN}karnel list <target>${NC} to see all available tools"
    echo
    return
  fi

  # Separate module target from tool flags
  local module_target=""
  local -a tool_flags=()
  local -a invalid_args=()

  for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
      # Remove -- prefix
      local flag="${arg#--}"
      tool_flags+=("$flag")
    elif [[ -z "$module_target" ]]; then
      module_target="$arg"
    else
      # Extra argument without -- is invalid
      invalid_args+=("$arg")
    fi
  done

  # If there are invalid arguments, show error and abort
  if [[ ${#invalid_args[@]} -gt 0 ]]; then
    log_error "Invalid arguments: ${invalid_args[*]}"
    echo
    log_info "To install specific tools, use -- before the name:"
    log_info "  ${D_CYAN}karnel install $module_target --${invalid_args[0]}${NC}"
    echo
    log_info "Correct example: ${D_CYAN}karnel install ai --opencode --ollama${NC}"
    return 1
  fi

  # If no module target specified, show error
  if [[ -z "$module_target" ]]; then
    log_error "No target specified"
    echo "Run 'karnel install' to see available targets"
    return 1
  fi

  # If no tool flags, install entire module (original behavior)
  if [[ ${#tool_flags[@]} -eq 0 ]]; then
    _install_full_module "$module_target"
  else
    # Install specific tools
    _install_specific_tools "$module_target" "${tool_flags[@]}"
  fi
}

# Install entire module (original behavior)
_install_full_module() {
  local target="$1"

  case "$target" in
  db)
    import "@/modules/db"
    install_db
    ;;
  ai)
    import "@/modules/ai"
    install_ai
    ;;
  editor)
    import "@/modules/editor"
    install_editor
    ;;
  lang)
    import "@/modules/lang"
    install_lang
    ;;
  dev)
    import "@/modules/dev"
    install_dev
    ;;
  npm)
    import "@/modules/npm"
    install_npm
    ;;
  shell)
    import "@/modules/shell"
    install_shell
    ;;
  ui)
    import "@/modules/ui"
    setup_ui
    ;;
  auto)
    import "@/modules/auto"
    install_auto
    ;;
  deploy)
    import "@/modules/deploy"
    install_deploy
    ;;
  voice)
    import "@/modules/voice"
    install_voice
    ;;
  games)
    import "@/modules/games"
    install_games
    ;;
  osint)
    import "@/modules/osint"
    install_osint
    ;;
  network)
    import "@/modules/network"
    install_network
    ;;
  utils)
    import "@/modules/utils"
    install_utils
    ;;
  plugin)
    import "@/modules/plugin"
    install_plugin_module
    ;;
  security)
    import "@/modules/security"
    install_security
    ;;
  supabase)
    import "@/tools/deploy/supabase/install"
    install_supabase
    ;;
  *)
    log_warn "Unknown install target: $target"
    echo "Run 'karnel install' to see available targets"
    return 1
    ;;
  esac

  local rc=$?
  if (( rc == 0 || rc == 2 )); then
    karnel_mark_module_installed "$target"
    return 0
  fi
  return "$rc"
}

# Install specific tools within a module
_install_specific_tools() {
  local module="$1"
  shift
  local -a tools=("$@")
  local failed_count=0

  case "$module" in
    db|dev|games|npm|lang|shell|editor|ui|auto|deploy)
      _batch_tool_action "$module" install "${tools[@]}"
      return $?
      ;;
  esac

  case "$module" in
  ai)
    import "@/tools/ai/all"
    local installed_count=0
    local failed_count=0
    local skipped_count=0

    # The registry is authoritative for accepted flags and post-install binaries.
    local -A _tool_binaries=()
    local _entry _id _name _bins
    for _entry in "${AI_TOOLS_REGISTRY[@]}"; do
      IFS=':' read -r _id _name _bins <<< "$_entry"
      _tool_binaries["$_id"]="$_bins"
    done

    for tool in "${tools[@]}"; do
      # Accept the binary/command name (e.g. --agy) or display name as an
      # alias for the canonical install flag (e.g. --antigravity-cli).
      tool="$(_ai_tool_resolve "$tool")"
      local func_name="install_${tool//-/_}"

      if [[ -z "${_tool_binaries[$tool]+registered}" ]]; then
        log_warn "Unknown AI tool: --$tool"
        ((failed_count++))
        continue
      fi

      if declare -f "$func_name" &>/dev/null; then
        "$func_name"
        local func_rc=$?

        case $func_rc in
          0)
            # Post-install validation: command -v for binaries
            local bins="${_tool_binaries[$tool]:-$tool}"
            local found_bin=""
            local _bin
            IFS=',' read -ra _bin_list <<< "$bins"
            for _bin in "${_bin_list[@]}"; do
              if command -v "$_bin" &>/dev/null; then
                # Check if it is a stub
                local _bin_path
                _bin_path=$(command -v "$_bin")
                if [ -f "$_bin_path" ] && [ -x "$_bin_path" ]; then
                  if ! grep -qiE "offline|unreachable|not.available|stub|indisponivel|inacessivel" "$_bin_path" 2>/dev/null || [ "$(head -c 2 "$_bin_path")" != "#!" ]; then
                    found_bin="$_bin"
                    break
                  fi
                fi
              fi
            done
            if [ -n "$found_bin" ]; then
              ((installed_count++))
            else
              log_warn "$tool: binary not found in PATH after installation"
              ((failed_count++))
            fi
            ;;
          2)
            # Already installed (skipped)
            ((skipped_count++))
            ;;
          *)
            ((failed_count++))
            ;;
        esac
      else
        log_warn "Function not found: $func_name"
        ((failed_count++))
      fi
    done

    echo
    if [[ $installed_count -gt 0 ]]; then
      log_success "$installed_count AI tool(s) installed"
    fi
    if [[ $skipped_count -gt 0 ]]; then
      log_info "$skipped_count AI tool(s) already installed"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count tool(s) failed to install"
    fi
    echo
    ;;
  osint)
    import "@/tools/osint/robin/common"
    _robin_print_disclaimer
    _batch_tool_action "osint" "install" "${tools[@]}" || return 1
    ;;
  network)
    _batch_tool_action "network" "install" "${tools[@]}" || return 1
    ;;
  utils)
    _batch_tool_action "utils" "install" "${tools[@]}" || return 1
    ;;
  security)
    _batch_tool_action "security" "install" "${tools[@]}" || return 1
    ;;
  plugin|voice)
    _batch_tool_action "$module" "install" "${tools[@]}"
    return $?
    ;;
  supabase)
    _batch_tool_action "supabase" "install" "${tools[@]}"
    return $?
    ;;
  *)
    log_warn "Unknown install target: $module"
    echo "Run 'karnel install' to see available targets"
    return 1
  ;;
  esac
  (( ${failed_count:-0} == 0 ))
}
