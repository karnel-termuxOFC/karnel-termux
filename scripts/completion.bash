#!/usr/bin/env bash

_karnel_tool_flags() {
  local module="$1"
  local ai_tools="10router qwen-code gemini-cli claude-code mistral-vibe openclaude openclaw ollama codex opencode mimocode engram codegraph pi antigravity-cli minimax-cli gentle-ai gga hermes-agent kimi-code command-code codebuff freebuff kilocode-cli kiro crush cline odysseus kimchi-code omni-route ctx7 openspec supercode-cli puter keelcode copilot-termux qoder ampcode cursor-cli oh-my-pi goose droid cactus cactus-needle hugging-face walkie"
  local tools=""

  case "$module" in
    ai) tools="$ai_tools" ;;
    auto) tools="n8n" ;;
    db) tools="postgresql mariadb sqlite mongodb redis" ;;
    deploy) tools="vercel railway netlify supabase" ;;
    dev) tools="gh wget curl lsd bat proot ncurses tmate openssh tmux cloudflared translate html2text jq bc tree fzf imagemagick shfmt make udocker snyk" ;;
    editor) tools="code-server neovim nvchad" ;;
    games) tools="buzz ctfgod detective pet-friends tamagotchi arcade" ;;
    lang) tools="bun nodejs python perl php rust clang golang" ;;
    network) tools="dark dedsec-network" ;;
    npm) tools="typescript nestjs prettier live-server localtunnel vercel markserv psqlformat ncu ngrok turbopack" ;;
    osint) tools="robin" ;;
    security) tools="aircrack-ng amass binwalk burpsuite dirb dnsrecon enum4linux exiftool ffuf foremost gobuster hashcat hydra john masscan metasploit netcat nikto nmap smbclient sqlmap steghide subfinder tcpdump theharvester wafw00f whatweb whois wpscan zap" ;;
    shell) tools="powerlevel10k zsh-defer zsh-autosuggestions zsh-syntax-highlighting history-substring zsh-completions fzf-tab you-should-use zsh-autopair better-npm" ;;
    ui) tools="font extra-keys cursor banner" ;;
    utils) tools="fconv filecheck websites notes treex passman applaunch splash httptmux zork qrcode superfile herdr" ;;
  esac

  local flags=""
  local tool
  for tool in $tools; do
    flags+=" --$tool"
  done
  printf '%s\n' "$flags"
}

_karnel_completions() {
  local cur prev words cword
  _init_completion || return

  local commands="agent backup brain cleanup deploy doctor env help ia init install list open pg plugin reinstall restore robin search show start stats status supabase uninstall update upgrade version voice"
  local modules="ai auto db deploy dev editor games lang network npm osint plugin security shell ui utils voice"
  local install_targets="$modules supabase"
  local update_targets="$modules supabase karnel"
  local show_targets="$modules backup restore"
  local open_targets="karnel help lang db ai editor dev npm shell ui auto deploy supabase games cleanup network utils voice plugin security osint robin"
  local ai_tools="10router qwen-code gemini-cli claude-code mistral-vibe openclaude openclaw ollama codex opencode mimocode engram codegraph pi antigravity-cli minimax-cli gentle-ai gga hermes-agent kimi-code command-code codebuff freebuff kilocode-cli kiro crush cline odysseus kimchi-code omni-route ctx7 openspec supercode-cli puter keelcode copilot-termux qoder ampcode cursor-cli oh-my-pi goose droid cactus cactus-needle hugging-face walkie"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands --auto --help --version" -- "$cur"))
    return
  fi

  case "${words[1]}" in
    install|uninstall|reinstall)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$install_targets" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$(_karnel_tool_flags "${words[2]}") --auto" -- "$cur"))
      fi
      ;;
    update)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$update_targets" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$(_karnel_tool_flags "${words[2]}") --auto" -- "$cur"))
      fi
      ;;
    show)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$show_targets" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$(_karnel_tool_flags "${words[2]}")" -- "$cur"))
      fi
      ;;
    list)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$modules" -- "$cur"))
      ;;
    doctor)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "termux code robin --quick -q --fix -f --help -h" -- "$cur"))
      else
        case "${words[2]}" in
          termux) COMPREPLY=($(compgen -W "--quick -q --fix -f --help -h" -- "$cur")) ;;
          code) COMPREPLY=($(compgen -W "--quick -q --standard -s --deep -d --fix --safe-fix --aggressive-fix --json -j --help -h" -- "$cur")) ;;
          robin) COMPREPLY=($(compgen -W "--network --help -h" -- "$cur")) ;;
        esac
      fi
      ;;
    robin)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "start stop status config doctor update purge-data help --help -h" -- "$cur"))
      else
        case "${words[2]}" in
          start) COMPREPLY=($(compgen -W "--accept-responsible-use" -- "$cur")) ;;
          doctor) COMPREPLY=($(compgen -W "--network" -- "$cur")) ;;
          purge-data) COMPREPLY=($(compgen -W "--yes" -- "$cur")) ;;
        esac
      fi
      ;;
    restore)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--cloud --list -l --help -h" -- "$cur"))
      else
        COMPREPLY=($(compgen -f -- "$cur"))
      fi
      ;;
    plugin)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "install remove uninstall update list ls search create scaffold" -- "$cur"))
      elif [[ "$prev" == "--capability" ]]; then
        COMPREPLY=($(compgen -W "network filesystem-read filesystem-write process environment" -- "$cur"))
      else
        case "${words[2]}" in
          install|update) COMPREPLY=($(compgen -W "--unsafe" -- "$cur")) ;;
          search) COMPREPLY=($(compgen -W "--command --compatible --capability --help -h" -- "$cur")) ;;
        esac
      fi
      ;;
    backup)
      COMPREPLY=($(compgen -W "snapshot list ls info show restore --cron --cloud --help -h" -- "$cur"))
      ;;
    brain)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "init save search ask config ai-config ls list edit delete rm reset destroy relate show view dashboard dash stats graph map skill skills sync --help -h" -- "$cur"))
      elif [[ "${words[2]}" == "ask" ]]; then
        COMPREPLY=($(compgen -W "--only-memories -m" -- "$cur"))
      fi
      ;;
    deploy)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "vercel railway netlify supabase --help -h" -- "$cur"))
      ;;
    env)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "set unset ls list --help -h" -- "$cur"))
      ;;
    ia)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "sessions install routes launchers --help -h" -- "$cur"))
      elif [[ "${words[2]}" == "sessions" ]]; then
        COMPREPLY=($(compgen -W "--all" -- "$cur"))
      elif [[ "${words[2]}" == "install" ]]; then
        COMPREPLY=($(compgen -W "$ai_tools" -- "$cur"))
      fi
      ;;
    init)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "next nextjs react vite nest nestjs express exp python fastapi go gin rust axum --help -h" -- "$cur"))
      ;;
    pg)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "start stop restart status init create drop backup restore list-backups backups schedule list ls shell psql --help -h" -- "$cur"))
      ;;
    start)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "editor robin" -- "$cur"))
      ;;
    supabase)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "doctor types migrate link remote-start remote remote-status status install uninstall help --help -h" -- "$cur"))
      ;;
    voice)
      COMPREPLY=($(compgen -W "kilo opencode claude-code codex gemini-cli hermes-agent kimi-code mimocode mistral-vibe openclaude pi qwen-code crush kiro text ! --lang --raw --no-clip --help -h" -- "$cur"))
      ;;
    open)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$open_targets --help -h" -- "$cur"))
      ;;
  esac
}

complete -F _karnel_completions karnel
