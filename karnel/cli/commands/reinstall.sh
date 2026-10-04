#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/tools"

reinstall_main() {

  if [[ $# -eq 0 ]]; then
    echo
    box "Karnel Reinstall"
    echo
    log_info "Usage: karnel reinstall <target>"
    log_info "Usage: karnel reinstall <target> --tool1 --tool2"
    echo
    log_info "Available targets:"
    echo
    list_item "lang       - Reinstall language packages"
    list_item "db         - Reinstall databases"
    list_item "ai         - Reinstall AI tools"
    list_item "editor     - Reinstall code editor"
    list_item "dev        - Reinstall development tools"
    list_item "npm        - Reinstall Node.js global modules"
    list_item "shell      - Reinstall ZSH + Oh My Zsh"
    list_item "ui         - Reinstall Termux UI"
    list_item "auto       - Reinstall automation tools"
    list_item "games      - Reinstall games"
    list_item "network    - Reinstall network tools"
    list_item "utils      - Reinstall utility scripts"
    list_item "deploy     - Reinstall deploy CLIs (Vercel, Railway, Netlify, Supabase)"
    list_item "voice      - Reinstall voice command"
    list_item "osint      - Reinstall OSINT tools"
    list_item "security   - Reinstall security tools"
    list_item "plugin     - Reinstall plugins"
    list_item "supabase   - Reinstall Supabase CLI"
    echo
    log_info "Reinstall specific tools with flags:"
    echo
    list_item "karnel reinstall ai --qwen-code --ollama"
    list_item "karnel reinstall db --postgresql --sqlite"
    list_item "Run ${D_CYAN}karnel list <target>${NC} to see all available tools"
    echo
    log_warn "This will uninstall and then install the selected components!"
    echo
    return
  fi

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

  if [[ ${#invalid_args[@]} -gt 0 ]]; then
    log_error "Invalid arguments: ${invalid_args[*]}"
    echo
    log_info "To reinstall specific tools, use -- before the name:"
    log_info "  ${D_CYAN}karnel reinstall $module_target --${invalid_args[0]}${NC}"
    echo
    return 1
  fi

  if [[ -z "$module_target" ]]; then
    log_error "No target specified"
    echo "Run 'karnel reinstall' to see available targets"
    return 1
  fi

  if [[ "$module_target" == "plugin" && ${#tool_flags[@]} -gt 0 ]]; then
    if [[ ${#tool_flags[@]} -eq 1 && "${tool_flags[0]}" == "unsafe" ]]; then
      _reinstall_full_module "$module_target" "--unsafe"
    else
      log_error "Usage: karnel reinstall plugin [--unsafe]"
      return 1
    fi
  elif [[ ${#tool_flags[@]} -eq 0 ]]; then
    _reinstall_full_module "$module_target"
  else
    _reinstall_specific_tools "$module_target" "${tool_flags[@]}"
  fi
}

_reinstall_full_module() {
  local target="$1"
  local unsafe_flag="${2:-}"

  case "$target" in
  lang)
    import "@/modules/lang"
    reinstall_lang
    ;;
  db)
    import "@/modules/db"
    reinstall_db
    ;;
  ai)
    import "@/modules/ai"
    reinstall_ai
    ;;
  editor)
    import "@/modules/editor"
    reinstall_editor
    ;;
  dev)
    import "@/modules/dev"
    reinstall_dev
    ;;
  npm)
    import "@/modules/npm"
    reinstall_npm
    ;;
  shell)
    import "@/modules/shell"
    reinstall_shell
    ;;
  ui)
    import "@/modules/ui"
    reinstall_ui
    ;;
  auto)
    import "@/modules/auto"
    reinstall_auto
    ;;
  games)
    import "@/modules/games"
    reinstall_games
    ;;
  deploy)
    import "@/modules/deploy"
    reinstall_deploy
    ;;
  voice)
    import "@/modules/voice"
    reinstall_voice
    ;;
  osint)
    import "@/modules/osint"
    reinstall_osint
    ;;
  network)
    import "@/modules/network"
    reinstall_network
    ;;
  utils)
    import "@/modules/utils"
    reinstall_utils
    ;;
  plugin)
    import "@/modules/plugin"
    reinstall_plugin_module "$unsafe_flag"
    ;;
  security)
    import "@/modules/security"
    reinstall_security
    ;;
  supabase)
    import "@/tools/deploy/supabase/install"
    reinstall_supabase
    ;;
  *)
    log_warn "Unknown reinstall target: $target"
    echo "Run 'karnel reinstall' to see available targets"
    return 1
    ;;
  esac
}

_reinstall_specific_tools() {
  local module="$1"
  shift
  local -a tools=("$@")
  local failed_count=0

  case "$module" in
  ai)
    _batch_tool_action "ai" "reinstall" "${tools[@]}" || return 1
    ;;
  db)
    import "@/tools/db/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      postgresql)
        reinstall_postgresql
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      mariadb)
        reinstall_mariadb
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      sqlite)
        reinstall_sqlite
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      mongodb)
        reinstall_mongodb
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      redis)
        reinstall_redis
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown database: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count database(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count database(s) failed to reinstall"
    fi
    echo
    ;;
  dev)
    import "@/tools/dev/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      gh)
        reinstall_gh
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      wget)
        reinstall_wget
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      curl)
        reinstall_curl
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      lsd)
        reinstall_lsd
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      bat)
        reinstall_bat
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      proot)
        reinstall_proot
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      ncurses)
        reinstall_ncurses
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      tmate)
        reinstall_tmate
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      tmux)
        reinstall_tmux
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      openssh)
        reinstall_openssh
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      cloudflared)
        reinstall_cloudflared
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      translate)
        reinstall_translate
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      html2text)
        reinstall_html2text
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      jq)
        reinstall_jq
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      bc)
        reinstall_bc
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      tree)
        reinstall_tree
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      fzf)
        reinstall_fzf
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      imagemagick)
        reinstall_imagemagick
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      shfmt)
        reinstall_shfmt
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      make)
        reinstall_make
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      udocker)
        reinstall_udocker
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      snyk)
        reinstall_snyk
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
        *)
          log_warn "Unknown tool: --$tool"
          ((failed_count++))
          ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count tool(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count tool(s) failed to reinstall"
    fi
    echo
    ;;
  games)
    import "@/tools/games/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      buzz)
        reinstall_buzz
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      ctfgod)
        reinstall_ctfgod
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      detective)
        reinstall_detective
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      pet-friends)
        reinstall_pet_friends
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      tamagotchi)
        reinstall_tamagotchi
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      arcade)
        reinstall_arcade
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown game: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count game(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count game(s) failed to reinstall"
    fi
    echo
    ;;
  npm)
    import "@/tools/npm/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      typescript)
        reinstall_typescript
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      nestjs)
        reinstall_nestjs
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      prettier)
        reinstall_prettier
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      live-server)
        reinstall_live_server
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      localtunnel)
        reinstall_localtunnel
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      vercel)
        reinstall_vercel
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      markserv)
        reinstall_markserv
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      psqlformat)
        reinstall_psqlformat
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      ncu)
        reinstall_ncu
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      ngrok)
        reinstall_ngrok
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      turbopack)
        reinstall_turbopack
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown node module: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count Node.js module(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count module(s) failed to reinstall"
    fi
    echo
    ;;
  lang)
    import "@/tools/lang/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      bun)
        reinstall_bun
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      nodejs)
        reinstall_nodejs
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      python)
        reinstall_python
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      perl)
        reinstall_perl
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      php)
        reinstall_php
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      rust)
        reinstall_rust
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      clang)
        reinstall_clang
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      golang)
        reinstall_golang
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown language: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count language(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count language(s) failed to reinstall"
    fi
    echo
    ;;
  shell)
    import "@/tools/shell/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      powerlevel10k)
        reinstall_powerlevel10k
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      zsh-defer)
        reinstall_zsh_defer
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      zsh-autosuggestions)
        reinstall_zsh_autosuggestions
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      zsh-syntax-highlighting)
        reinstall_zsh_syntax_highlighting
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      history-substring)
        reinstall_history_substring
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      zsh-completions)
        reinstall_zsh_completions
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      fzf-tab)
        reinstall_fzf_tab
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      you-should-use)
        reinstall_you_should_use
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      zsh-autopair)
        reinstall_zsh_autopair
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      better-npm)
        reinstall_better_npm
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown plugin: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count plugin(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count plugin(s) failed to reinstall"
    fi
    echo
    ;;
  editor)
    import "@/tools/editor/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      code-server)
        reinstall_code_server
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      neovim)
        reinstall_neovim
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      nvchad)
        reinstall_nvchad
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown editor component: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count editor component(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count component(s) failed to reinstall"
    fi
    echo
    ;;
  ui)
    import "@/tools/ui/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      font)
        reinstall_font
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      extra-keys)
        reinstall_extra_keys
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      cursor)
        reinstall_cursor
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      banner)
        reinstall_banner
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown UI component: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count UI component(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count component(s) failed to reinstall"
    fi
    echo
    ;;
  auto)
    import "@/tools/auto/all"
    local reinstalled_count=0
    local failed_count=0

    for tool in "${tools[@]}"; do
      case "$tool" in
      n8n)
        reinstall_n8n
        case $? in 0) ((reinstalled_count++));; 1) ((failed_count++));; esac
        ;;
      *)
        log_warn "Unknown automation tool: --$tool"
        ((failed_count++))
        ;;
      esac
    done

    echo
    if [[ $reinstalled_count -gt 0 ]]; then
      log_success "$reinstalled_count automation tool(s) reinstalled"
    fi
    if [[ $failed_count -gt 0 ]]; then
      log_warn "$failed_count tool(s) failed to reinstall"
    fi
    echo
    ;;
  osint)
    import "@/tools/osint/robin/common"
    _robin_print_disclaimer
    _batch_tool_action "osint" "reinstall" "${tools[@]}" || return 1
    ;;
  network)
    _batch_tool_action "network" "reinstall" "${tools[@]}" || return 1
    ;;
  utils)
    _batch_tool_action "utils" "reinstall" "${tools[@]}" || return 1
    ;;
  security|deploy|plugin|voice|supabase)
    _batch_tool_action "$module" "reinstall" "${tools[@]}" || return 1
    ;;
  *)
    log_warn "Unknown reinstall target: $module"
    echo "Run 'karnel reinstall' to see available targets"
    return 1
    ;;
  esac
  (( ${failed_count:-0} == 0 ))
}
