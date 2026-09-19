#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

: "${KARNEL_VERSION:=unknown}"

karnel_main() {
  local cmd="${1:-}"
  case "$cmd" in
    install|uninstall|update|upgrade|reinstall|cleanup|plugin|backup|restore)
      if [[ "${KARNEL_LIFECYCLE_LOCK_HELD:-0}" != 1 ]]; then
        (
          local lifecycle_lock="$KARNEL_RUN/lifecycle.lock"
          if ! _karnel_acquire_lock "$lifecycle_lock"; then
            log_error "Another Karnel mutable operation is already running"
            exit 75
          fi
          KARNEL_LIFECYCLE_LOCK_HELD=1
          trap '_karnel_release_lock "$lifecycle_lock" 2>/dev/null || true' EXIT
          _karnel_dispatch "$@"
        )
        return $?
      fi
      ;;
  esac
  _karnel_dispatch "$@"
}

_karnel_dispatch() {
  local cmd="${1:-}"
  shift || true

  # si no se pasa comando
  if [[ -z "$cmd" ]]; then
    if [[ -t 0 ]]; then
      karnel_tui
    else
      karnel_help
    fi
    return
  fi

  # special cases: --version, --help
  if [[ "$cmd" == "--version" ]]; then
    import "@/cli/commands/version"
    version_main
    return
  fi

  if [[ "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    karnel_help
    return
  fi

  # reject any command name that is not a plain identifier (path-traversal guard)
  if [[ "$cmd" != */* && "$cmd" != *".."* && "$cmd" != .* && "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    :
  else
    log_error "Command not found: $cmd"
    echo
    karnel_help
    return 1
  fi

  local command_file="$KARNEL_PATH/cli/commands/$cmd.sh"

  if [[ -f "$command_file" ]]; then
    import "@/cli/commands/$cmd"
    "${cmd}_main" "$@"
    return $?
  fi

  import "@/tools/plugins/install"
  _plugin_dispatch "$cmd" "$@"
  local plugin_status=$?
  if [[ "${PLUGIN_DISPATCH_FOUND:-0}" == "1" ]]; then
    return "$plugin_status"
  fi

  log_error "Command not found: $cmd"
  echo
  karnel_help
  return 1
}

karnel_help() {
  echo
  box "◈ KARNEL v${KARNEL_VERSION} ◈"
  echo
	log_info "Usage: karnel <command> [options]"
	log_info "Global option: --auto  Run supported confirmations and selections without prompts"
  echo
  separator_section "Available Commands"
  echo
  printf "    ${D_CYAN}%-18s${NC} %s\n" "--version" "Show current version"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "agent [ask,run,config,status]" "Local AI assistant & task agent"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "backup [--cron,--cloud,snapshot,list]" "Backup selected Termux configs + package metadata"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "brain [subcommand]" "Second brain (run 'karnel brain --help' for commands)"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "cleanup" "Clean caches, logs, and temp files"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "deploy [vercel,railway,netlify,supabase]" "Deploy projects to Vercel, Railway, Netlify, Supabase"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "doctor [termux,code,robin]" "Run diagnostics"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "env [set,unset,list]" "Manage environment variables"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "help" "Show this help screen"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "ia [sessions,routes,install]" "AI agent manager"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "init [next,react,nest,express,python,go,rust]" "Scaffold projects"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "install <module> [--tool...]" "Install modules and specific tools"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "list [module]" "List available tools in a module"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "open [module]" "Open docs in browser for a module"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "pg <command>" "PostgreSQL manager (run 'karnel pg --help' for commands)"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "plugin [install,update,list,search,remove,create]" "Plugin manager"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "reinstall <module>" "Uninstall + install a module"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "restore [--list,--cloud,<file>]" "Restore Termux from a backup"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "robin [start,stop,status,config,doctor,update,purge-data]" "Dark Web OSINT tool (Tor + LLM)"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "search <query>" "Search across all tools and memories"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "show <module> [--tool]" "Show README/docs for a tool"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "start [editor,robin]" "Start services (code-server, etc.)"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "stats" "System overview: modules, tools, disk usage"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "status" "Quick system overview"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "supabase [doctor,types,migrate,link,remote,remote-status,install,uninstall]" "Supabase CLI (types, migrate, functions, secrets)"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "uninstall <module>" "Remove installed modules"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "update [module]" "Update modules or framework"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "upgrade" "Upgrade Karnel framework itself"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "version" "Show current version"
  printf "    ${D_CYAN}%-18s${NC} %s\n" "voice [agent]" "Speech-to-agent via microphone (run 'karnel voice --help' for agents)"
  echo
  separator_section "Quick Start"
  echo
  list_item "Run: ${D_CYAN}karnel${NC} to see available commands"
  list_item "Run: ${D_CYAN}karnel open karnel${NC} for official documentation"
  list_item "Run: ${D_CYAN}karnel install <module>${NC} to install modules"
  list_item "Run: ${D_CYAN}karnel backup${NC} to save selected configs without private keys or .env files"
  list_item "Run: ${D_CYAN}karnel restore${NC} for a verified transactional restore"
  list_item "Run: ${D_CYAN}karnel brain init${NC} to start your second brain"
  echo
  separator_section "Install / Update / Reinstall / Uninstall Targets"
  echo
  log_info "Use with: karnel install|update|reinstall|uninstall <target> [--tool...]"
  echo
  printf "    ${D_GREEN}%-10s${NC} %s\n" "ai" "43 AI tools (OpenCode, Cactus, Hugging Face, Claude, Ollama, Goose, etc.)"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "auto" "Automation (n8n)"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "db" "PostgreSQL, MariaDB, SQLite, MongoDB, Redis"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "deploy" "Vercel, Railway, Netlify, Supabase CLIs"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "dev" "gh, wget, curl, fzf, bat, lsd, proot, tmux, openssh, cloudflared, jq, tree, imagemagick, shfmt, make, udocker, snyk, translate, html2text, bc, ncurses, tmate"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "utils" "Fconv, Filecheck, Websites, Notes, Treex, Passman, Applaunch, Splash, Httptmux, Zork, QR Code, SuperFile"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "editor" "code-server, neovim, nvchad"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "games" "Buzz, CTF God, Detective, Pet Friends, Tamagotchi, Arcade"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "lang" "Bun, Node.js, Python, Perl, PHP, Rust, Clang, Go"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "npm" "typescript, nestjs, prettier, live-server, localtunnel, vercel, markserv, psqlformat, ncu, ngrok, turbopack"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "network" "Dark Web OSINT, DedSec Network"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "osint" "Robin — Dark Web + LLM OSINT"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "security" "Nmap, Hydra, Metasploit, SQLMap, Gobuster, etc."
  printf "    ${D_GREEN}%-10s${NC} %s\n" "shell" "ZSH + Oh My Zsh + 10 plugins (autosuggest, syntax-highlight, etc.)"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "ui" "Font (Meslo Nerd), Cursor (green), Extra-keys, Banner"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "voice" "Speech-to-agent via microphone"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "plugin" "Plugin manager — install plugins from GitHub"
  printf "    ${D_GREEN}%-10s${NC} %s\n" "supabase" "Supabase CLI (via deploy module)"
  echo
  separator_section "List / Show / Open"
  echo
  log_info "Browse available tools:"
  echo
  list_item "${D_CYAN}karnel list <module>${NC} — List all tools in a module"
  list_item "${D_CYAN}karnel show <module> [--tool]${NC} — Show tool documentation"
  list_item "${D_CYAN}karnel open <module>${NC} — Open docs in browser"
  echo
  separator_section "Help"
  echo
  list_item "Run ${D_CYAN}karnel <command>${NC} for command-specific help"
  list_item "Example: ${D_CYAN}karnel pg${NC}, ${D_CYAN}karnel init${NC}"
  list_item "Docs: ${D_CYAN}karnel open karnel${NC} — israel marques 🇧🇷 (12y)"
  echo
}

# =====================
# TUI Functions (dialog/whiptail)
# =====================

karnel_tui() {
  local TUI_BIN=""
  if command -v dialog &>/dev/null; then
    TUI_BIN="dialog"
  elif command -v whiptail &>/dev/null; then
    TUI_BIN="whiptail"
  fi

  if [[ -z "$TUI_BIN" ]] || [[ ! -t 0 ]] || [[ ! -w /dev/tty ]]; then
    karnel_fallback_tui
    return
  fi

  _tui_main_menu
}

_dialog_menu() {
  local title="$1"
  local prompt="$2"
  shift 2
  local options=("$@")
  local choice
  local menu_height=20
  local menu_width=65
  local list_height=$(( ${#options[@]} / 2 ))
  if (( list_height > 18 )); then list_height=18; fi
  if (( list_height < 6 )); then list_height=6; fi
  if [[ "$TUI_BIN" == "dialog" ]]; then
    choice=$(dialog --clear --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --menu "$prompt" $menu_height $menu_width $list_height "${options[@]}" 2>&1 >/dev/tty)
  else
    choice=$(whiptail --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --menu "$prompt" $menu_height $menu_width $list_height "${options[@]}" 2>&1 >/dev/tty)
  fi
  local exit_status=$?
  echo "$choice"
  return $exit_status
}

_dialog_checklist() {
  local title="$1"
  local prompt="$2"
  shift 2
  local options=("$@")
  local selections
  local list_height=$(( ${#options[@]} / 3 ))
  if (( list_height > 18 )); then list_height=18; fi
  if (( list_height < 6 )); then list_height=6; fi
  if [[ "$TUI_BIN" == "dialog" ]]; then
    selections=$(dialog --clear --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --checklist "$prompt" 24 70 $list_height "${options[@]}" 2>&1 >/dev/tty)
  else
    selections=$(whiptail --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --checklist "$prompt" 24 70 $list_height "${options[@]}" 2>&1 >/dev/tty)
  fi
  local exit_status=$?
  echo "$selections"
  return $exit_status
}

_dialog_input() {
  local title="$1"
  local prompt="$2"
  local init_val="$3"
  local text
  if [[ "$TUI_BIN" == "dialog" ]]; then
    text=$(dialog --clear --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --inputbox "$prompt" 10 60 "$init_val" 2>&1 >/dev/tty)
  else
    text=$(whiptail --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --inputbox "$prompt" 10 60 "$init_val" 2>&1 >/dev/tty)
  fi
  local exit_status=$?
  echo "$text"
  return $exit_status
}

_dialog_yesno() {
  local title="$1"
  local prompt="$2"
  if [[ "$TUI_BIN" == "dialog" ]]; then
    dialog --clear --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --yesno "$prompt" 10 60 >/dev/tty 2>&1
  else
    whiptail --backtitle "Karnel v$KARNEL_VERSION" --title "$title" --yesno "$prompt" 10 60 >/dev/tty 2>&1
  fi
  return $?
}

_tui_main_menu() {
  while true; do
    local choice
    choice=$(_dialog_menu "Main Menu" "Select an action to perform:" \
      "install" "Install Packages/Modules" \
      "list" "List Available Tools" \
      "agent" "Local AI Assistant & Task Agent" \
      "backup" "Backup & Restore" \
      "brain" "Second Brain Manager" \
      "plugin" "Plugin Manager" \
      "env" "Environment Variables Manager" \
      "pg" "PostgreSQL Database Manager" \
      "init" "Project Initializer" \
      "deploy" "Deploy Projects" \
      "voice" "Speech-to-Agent Help" \
      "ia" "AI Agent Manager Help" \
      "robin" "Dark Web OSINT Help" \
      "supabase" "Supabase CLI Help" \
      "doctor" "Run Diagnostics (termux/code)" \
      "search" "Search Tools & Memories" \
      "show" "Show Documentation Help" \
      "cleanup" "Clean caches and temp files" \
      "status" "Quick System Overview" \
      "upgrade" "Upgrade Karnel Framework" \
      "update" "Update Help" \
      "reinstall" "Reinstall Help" \
      "uninstall" "Remove Help" \
      "help" "Show Help Documentation" \
      "exit" "Exit")
    
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$choice" == "exit" ]] || [[ -z "$choice" ]]; then
      clear
      source "$KARNEL_PATH/utils/banner.sh"
      render_banner
      break
    fi

    case "$choice" in
      install) _tui_install_menu ;;
      list) _tui_list_menu ;;
      agent)
        clear
        karnel_main "agent"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      backup) _tui_backup_menu ;;
      brain) _tui_brain_menu ;;
      plugin) _tui_plugin_menu ;;
      env) _tui_env_menu ;;
      pg) _tui_pg_menu ;;
      init) _tui_init_menu ;;
      deploy) _tui_deploy_menu ;;
      voice)
        clear
        karnel_main "voice"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      ia)
        clear
        karnel_main "ia"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      robin)
        clear
        karnel_main "robin"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      supabase)
        clear
        karnel_main "supabase"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      doctor)
        clear
        karnel_main "doctor"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      search)
        clear
        karnel_main "search"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      show)
        clear
        karnel_main "show"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      cleanup)
        clear
        karnel_main "cleanup"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      status)
        clear
        karnel_main "status"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      upgrade)
        clear
        karnel_main "upgrade"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      update)
        clear
        karnel_main "update"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      reinstall)
        clear
        karnel_main "reinstall"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      uninstall)
        clear
        karnel_main "uninstall"
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
      help)
        clear
        karnel_help
        echo
        read -r -p "Press Enter to return to menu..." temp
        ;;
    esac
  done
}

_tui_list_menu() {
  local modules="ai db lang dev editor npm shell ui auto deploy games network utils osint voice plugin security"
  local choice
  choice=$(_dialog_menu "List Tools" "Select a module to list:" \
    "ai" "AI Tools (43)" \
    "db" "Databases" \
    "lang" "Programming Languages" \
    "editor" "Code Editors" \
    "dev" "Development Tools" \
    "npm" "NPM Packages" \
    "shell" "Shell Plugins" \
    "ui" "Termux Interface" \
    "auto" "Automation" \
    "deploy" "Deploy CLIs" \
    "games" "Games" \
    "network" "Network Tools" \
    "utils" "Utilities" \
    "osint" "OSINT Tools" \
      "voice" "Voice Commands" \
      "plugin" "Plugin System" \
    "security" "Security Tools" \
    "back" "Back to Main Menu")
  local es=$?
  if [[ $es -ne 0 || "$choice" == "back" || -z "$choice" ]]; then
    return
  fi
  if [[ -n "$choice" ]]; then
    clear
    karnel_main "list" "$choice"
    echo
    read -r -p "Press Enter to return to menu..." temp
  fi
}

_tui_backup_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "Backup & Restore" "Select an operation:" \
      "backup" "Create new backup" \
      "cloud" "Backup + upload to cloud" \
      "snapshot" "Create named snapshot" \
      "list" "List all backups" \
      "restore" "Restore latest backup" \
      "restore_file" "Restore specific file" \
      "cron" "Schedule daily backup" \
      "back" "Back to Main Menu")
    local es=$?
    if [[ $es -ne 0 || "$sub_choice" == "back" || -z "$sub_choice" ]]; then
      break
    fi
    case "$sub_choice" in
      backup)
        clear
        karnel_main "backup"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      cloud)
        clear
        karnel_main "backup" "--cloud"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      snapshot)
        local snap_name
        snap_name=$(_dialog_input "Snapshot" "Snapshot name (e.g. before-update):") || true
        if [[ -n "$snap_name" ]]; then
          clear
          karnel_main "backup" "snapshot" "$snap_name"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      list)
        clear
        karnel_main "backup" "list"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      restore)
        clear
        karnel_main "restore"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      restore_file)
        clear
        karnel_main "restore" "--list"
        local restore_file
        restore_file=$(_dialog_input "Restore" "Enter backup filename:") || true
        if [[ -n "$restore_file" ]]; then
          karnel_main "restore" "$restore_file"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      cron)
        clear
        karnel_main "backup" "--cron"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
    esac
  done
}

_tui_plugin_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "Plugin Manager" "Select an operation:" \
       "install" "Install plugin from GitHub" \
       "search" "Search available plugins" \
       "list" "List installed plugins" \
       "update" "Update approved plugin" \
       "remove" "Remove installed plugin" \
      "create" "Scaffold new plugin" \
      "back" "Back to Main Menu")
    local es=$?
    if [[ $es -ne 0 || "$sub_choice" == "back" || -z "$sub_choice" ]]; then
      break
    fi
    case "$sub_choice" in
      install)
        local repo
        repo=$(_dialog_input "Install Plugin" "GitHub repo (user/repo):") || true
        if [[ -n "$repo" ]]; then
          clear
          karnel_main "plugin" "install" "$repo"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      search)
        clear
        karnel_main "plugin" "search"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      list)
        clear
        karnel_main "plugin" "list"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      update)
        local uname
        uname=$(_dialog_input "Update Plugin" "Approved plugin name:") || true
        if [[ -n "$uname" ]]; then
          clear
          karnel_main "plugin" "update" "$uname"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      remove)
        local pname
        pname=$(_dialog_input "Remove Plugin" "Plugin name:") || true
        if [[ -n "$pname" ]]; then
          clear
          karnel_main "plugin" "remove" "$pname"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      create)
        local cname
        cname=$(_dialog_input "Create Plugin" "Plugin name:") || true
        if [[ -n "$cname" ]]; then
          clear
          karnel_main "plugin" "create" "$cname"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
    esac
  done
}

_tui_deploy_menu() {
  local choice
  choice=$(_dialog_menu "Deploy" "Select platform:" \
    "vercel" "Deploy to Vercel" \
    "railway" "Deploy to Railway" \
    "netlify" "Deploy to Netlify" \
    "supabase" "Supabase CLI (remote commands)" \
    "back" "Back to Main Menu")
  local es=$?
  if [[ $es -ne 0 || "$choice" == "back" || -z "$choice" ]]; then
    return
  fi
  if [[ -n "$choice" ]]; then
    clear
    karnel_main "deploy" "$choice"
    echo
    read -r -p "Press Enter to return to menu..." temp
  fi
}

_tui_brain_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "Second Brain Manager" "Select a brain operation:" \
      "ask" "Ask a question (AI integrated)" \
      "save" "Save a new memory" \
      "search" "Search existing memories" \
      "list" "List all memories" \
      "init" "Initialize Brain" \
      "graph" "View memory graph" \
      "edit" "Edit a memory" \
      "delete" "Delete a memory" \
      "show" "View a memory and its relations" \
      "skill" "Create an AI skill from memories" \
      "relate" "Link two memories" \
      "sync" "Sync memories" \
      "reset" "Reset / Destroy Brain" \
      "back" "Back to Main Menu")
      
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$sub_choice" == "back" ]] || [[ -z "$sub_choice" ]]; then
      break
    fi
    
    case "$sub_choice" in
      ask)
        local question
        question=$(_dialog_input "Brain Ask" "Enter your question for the brain:") || true
        if [[ -n "$question" ]]; then
          clear
          karnel_main "brain" "ask" "$question"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      save|edit|delete|show|skill|relate)
        clear
        karnel_main "brain" "$sub_choice"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      search)
        local query
        query=$(_dialog_input "Search Memories" "Enter search query:")
        if [[ -n "$query" ]]; then
          clear
          karnel_main "brain" "search" "$query"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      list)
        clear
        karnel_main "brain" "list"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      init)
        clear
        karnel_main "brain" "init"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      graph)
        clear
        karnel_main "brain" "graph"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      sync)
        clear
        karnel_main "brain" "sync"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      reset)
        if _dialog_yesno "Reset Brain" "WARNING: This will delete ALL stored memories. Are you sure?"; then
          clear
          karnel_main "brain" "reset"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
    esac
  done
}

_tui_env_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "Environment Variables Manager" "Select an operation:" \
      "set" "Set/Update a variable" \
      "unset" "Remove a variable" \
      "list" "List all user variables" \
      "back" "Back to Main Menu")
      
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$sub_choice" == "back" ]] || [[ -z "$sub_choice" ]]; then
      break
    fi
    
    case "$sub_choice" in
      set)
        clear
        karnel_main "env" "set"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      unset)
        clear
        karnel_main "env" "unset"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      list)
        clear
        karnel_main "env" "ls"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
    esac
  done
}

_tui_install_menu() {
  while true; do
    local target
    target=$(_dialog_menu "Install Modules" "Select target module to install:" \
      "ai" "AI Tools (OpenCode, Claude, Ollama, etc.)" \
      "auto" "Automation Tools (n8n)" \
      "db" "Databases (PostgreSQL, MariaDB, SQLite, MongoDB, Redis)" \
      "deploy" "Deploy CLIs (Vercel, Railway, Netlify, Supabase)" \
      "dev" "Development Tools (GitHub CLI, fzf, bat, etc.)" \
      "editor" "Code Editor (code-server)" \
      "games" "Games (Buzz, CTF God, Detective, etc.)" \
      "lang" "Programming Languages (Node, Python, Go, Rust, etc.)" \
      "npm" "Node.js Global npm Packages" \
      "osint" "OSINT Tools (Robin — Dark Web + LLM)" \
      "network" "Network Tools (Dark Web, DedSec Network)" \
      "security" "Security Tools (Nmap, Hydra, SQLMap, etc.)" \
      "utils" "Utility Scripts (Fconv, Notes, QR Code)" \
      "shell" "ZSH + Oh My Zsh + Plugins" \
      "ui" "Termux UI (font, cursor, extra-keys, banner)" \
      "plugin" "Plugins from the official registry" \
      "supabase" "Supabase CLI" \
      "voice" "Speech-to-Agent via microphone" \
      "back" "Back to Main Menu")
      
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$target" == "back" ]] || [[ -z "$target" ]]; then
      break
    fi
    
    case "$target" in
      ai|db|lang|dev|utils|network|shell|ui)
        _tui_install_checklist "$target"
        ;;
      *)
        if _dialog_yesno "Install Module" "Do you want to install module '$target' completely?"; then
          clear
          karnel_main "install" "$target"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
    esac
  done
}

_tui_install_checklist() {
  local target="$1"
  local -a opts=()
  
  case "$target" in
    lang)
      opts=(
        "bun" "Bun (JS Runtime)" OFF
        "nodejs" "Node.js LTS" OFF
        "python" "Python" OFF
        "perl" "Perl" OFF
        "php" "PHP" OFF
        "rust" "Rust" OFF
        "clang" "C/C++ (clang)" OFF
        "golang" "Go (golang)" OFF
      )
      ;;
    db)
      opts=(
        "postgresql" "PostgreSQL" OFF
        "mariadb" "MariaDB" OFF
        "sqlite" "SQLite" OFF
        "mongodb" "MongoDB" OFF
        "redis" "Redis" OFF
      )
      ;;
    ai)
      import "@/tools/ai/all"
      opts=()
      local entry id name binaries
      for entry in "${AI_TOOLS_REGISTRY[@]}"; do
        IFS=':' read -r id name binaries <<< "$entry"
        opts+=("$id" "$name" OFF)
      done
      ;;
    dev)
      opts=(
        "gh" "GitHub CLI" OFF
        "wget" "Wget" OFF
        "curl" "Curl" OFF
        "fzf" "Fzf" OFF
        "jq" "Jq" OFF
        "lsd" "LSD (modern ls)" OFF
        "bat" "Bat (modern cat)" OFF
        "proot" "Proot" OFF
        "ncurses" "Ncurses Utils" OFF
        "tmate" "Tmate" OFF
        "cloudflared" "Cloudflared" OFF
        "translate" "Translate Shell" OFF
        "html2text" "html2text" OFF
        "bc" "Bc (calculator)" OFF
        "tree" "Tree" OFF
        "imagemagick" "ImageMagick" OFF
        "shfmt" "Shfmt" OFF
        "make" "Make" OFF
        "udocker" "Udocker" OFF
        "tmux" "Tmux" OFF
        "openssh" "OpenSSH" OFF
        "snyk" "Snyk" OFF
      )
      ;;
    shell)
      opts=(
        "powerlevel10k" "Powerlevel10k" OFF
        "zsh-defer" "Zsh Defer" OFF
        "zsh-autosuggestions" "Zsh Autosuggestions" OFF
        "zsh-syntax-highlighting" "Zsh Syntax Highlighting" OFF
        "history-substring" "History Substring Search" OFF
        "zsh-completions" "Zsh Completions" OFF
        "fzf-tab" "Fzf Tab" OFF
        "you-should-use" "You Should Use" OFF
        "zsh-autopair" "Zsh Autopair" OFF
        "better-npm" "Better NPM" OFF
      )
      ;;
    ui)
      opts=(
        "font" "Meslo Nerd Font" OFF
        "cursor" "Green cursor" OFF
        "extra-keys" "Custom Termux keys" OFF
        "banner" "Startup banner" OFF
      )
      ;;
    utils)
      opts=(
        "fconv" "File Converter" OFF
        "filecheck" "File Checker" OFF
        "websites" "Websites Creator" OFF
        "notes" "Smart Notes" OFF
        "treex" "Tree Explorer" OFF
        "passman" "Password Master" OFF
        "applaunch" "App Launcher" OFF
        "splash" "Loading Screen" OFF
        "httptmux" "HTTP API Client" OFF
        "zork" "Zork Adventure Games" OFF
        "qrcode" "QR Code Generator" OFF
        "superfile" "SuperFile" OFF
      )
      ;;
    network)
      opts=(
        "dark" "Dark Web OSINT" OFF
        "dedsec-network" "DedSec Network Toolkit" OFF
      )
      ;;
  esac
  
  local selections
  selections=$(_dialog_checklist "Install $target Tools" "Select tools to install (Space to select):" "${opts[@]}")
  local exit_status=$?
  
  if [[ $exit_status -eq 0 ]] && [[ -n "$selections" ]]; then
    local -a clean_selections=()
    for item in $selections; do
      local cleaned="${item//\"/}"
      cleaned="${cleaned//\'/}"
      if [[ -n "$cleaned" ]]; then
        clean_selections+=("--$cleaned")
      fi
    done
    
    if [[ ${#clean_selections[@]} -gt 0 ]]; then
      clear
      log_info "Running: karnel install $target ${clean_selections[*]}"
      karnel_main "install" "$target" "${clean_selections[@]}"
      echo
      read -r -p "Press Enter to return..." temp
    fi
  fi
}

_tui_pg_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "PostgreSQL Database Manager" "Select a pg operation:" \
      "status" "Check server status" \
      "start" "Start PostgreSQL server" \
      "stop" "Stop PostgreSQL server" \
      "restart" "Restart PostgreSQL server" \
      "init" "Initialize PostgreSQL database" \
      "list" "List all databases" \
      "create" "Create a new database" \
      "drop" "Drop a database" \
      "backup" "Backup a database" \
      "restore" "Restore a database from backup" \
      "list-backups" "List database backups" \
      "schedule" "Schedule automatic backups" \
      "shell" "Open psql shell" \
      "back" "Back to Main Menu")
      
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$sub_choice" == "back" ]] || [[ -z "$sub_choice" ]]; then
      break
    fi
    
    case "$sub_choice" in
      status|start|stop|restart|init|list|list-backups|schedule)
        clear
        karnel_main "pg" "$sub_choice"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      create)
        local db_name
        db_name=$(_dialog_input "Create Database" "Enter database name to create:") || true
        if [[ -n "$db_name" ]]; then
          clear
          karnel_main "pg" "create" "$db_name"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      drop)
        local db_name
        db_name=$(_dialog_input "Drop Database" "Enter database name to drop:") || true
        if [[ -n "$db_name" ]]; then
          if _dialog_yesno "Drop Database" "WARNING: This will permanently delete database '$db_name'. Are you sure?"; then
            clear
            karnel_main "pg" "drop" "$db_name"
            echo
            read -r -p "Press Enter to return..." temp
          fi
        fi
        ;;
      backup)
        local db_name
        if db_name=$(_dialog_input "Backup Database" "Enter database name to backup (leave empty for interactive):"); then
          clear
          karnel_main "pg" "backup" "$db_name"
          echo
          read -r -p "Press Enter to return..." temp
        fi
        ;;
      restore)
        clear
        karnel_main "pg" "restore"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
      shell)
        clear
        karnel_main "pg" "shell"
        echo
        read -r -p "Press Enter to return..." temp
        ;;
    esac
  done
}

_tui_init_menu() {
  while true; do
    local sub_choice
    sub_choice=$(_dialog_menu "Project Initializer" "Select a template to configure current directory:" \
      "next" "Next.js Project (Node.js)" \
      "react" "React + Vite Project (Node.js)" \
      "nest" "NestJS Project (Node.js)" \
      "express" "Express.js API (Node.js)" \
      "python" "Python FastAPI Project" \
      "go" "Go Gin/Fiber Project" \
      "rust" "Rust Axum/Actix Web Project" \
      "back" "Back to Main Menu")
      
    local exit_status=$?
    if [[ $exit_status -ne 0 ]] || [[ "$sub_choice" == "back" ]] || [[ -z "$sub_choice" ]]; then
      break
    fi
    
    clear
    karnel_main "init" "$sub_choice"
    echo
    read -r -p "Press Enter to return..." temp
  done
}

karnel_fallback_tui() {
  clear
  source "$KARNEL_PATH/utils/banner.sh"
  render_banner
  while true; do
    echo
    box "◈ KARNEL TUI MENU ◈"
    echo
    log_info "Select an option to run:"
    echo
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 1 "Second Brain Manager (brain)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 2 "Environment Variables Manager (env)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 3 "Install Packages/Modules (install)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 4 "Local AI Assistant & Task Agent (agent)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 5 "PostgreSQL Database Manager (pg)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 6 "Project Initializer (init)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 7 "Speech-to-Agent (voice)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 8 "AI Agent Manager (ia)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 9 "Run Diagnostics (doctor)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 10 "Update Karnel (update)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 11 "Help & Documentation (help)"
    printf "    ${D_GREEN}%2d.${D_NC} %s\n" 12 "Exit"
    echo
    
    local choice
    read -r -p "  Enter choice (1-12): " choice
    
    case "$choice" in
      1) karnel_main "brain" ;;
      2) karnel_main "env" ;;
      3) karnel_main "install" ;;
      4) karnel_main "agent" ;;
      5) karnel_main "pg" ;;
      6) karnel_main "init" ;;
      7) karnel_main "voice" ;;
      8) karnel_main "ia" ;;
      9) karnel_main "doctor" ;;
      10) karnel_main "update" "karnel" ;;
      11) karnel_help ;;
      12|q|exit) break ;;
      *) log_warn "Invalid option. Please try again." ;;
    esac
    echo
    read -r -p "  Press Enter to return to menu..." temp
    clear
    source "$KARNEL_PATH/utils/banner.sh"
    render_banner
  done
}
