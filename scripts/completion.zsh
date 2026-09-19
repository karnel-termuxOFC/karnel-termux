#compdef karnel

_karnel_add() {
  local values="$1"
  compadd -- ${(s: :)values}
}

_karnel_commands() {
  local -a commands=(
    'agent:Local AI assistant and task agent'
    'backup:Back up catalog metadata and selected configuration'
    'brain:Manage second-brain memories'
    'cleanup:Clean caches, logs, and temporary files'
    'deploy:Run a deployment CLI'
    'doctor:Diagnose the environment or a project'
    'env:Manage shell environment variables'
    'help:Show help'
    'ia:Manage AI sessions, routes, and installation'
    'init:Configure an existing project'
    'install:Install modules and tools'
    'list:List tools in a module'
    'open:Open documentation in a browser'
    'pg:Manage PostgreSQL'
    'plugin:Manage reviewed and local plugins'
    'reinstall:Uninstall and install modules'
    'restore:Restore from a backup'
    'robin:Manage Robin dark-web OSINT'
    'search:Search tools and memories'
    'show:Show tool documentation'
    'start:Start a service'
    'stats:System overview with versions, modules, and tool counts'
    'status:Show a quick system overview'
    'supabase:Manage Supabase CLI remote workflows'
    'uninstall:Remove modules and tools'
    'update:Update modules or the framework'
    'upgrade:Upgrade the Karnel framework'
    'version:Show the version'
    'voice:Capture speech and dispatch an agent'
  )
  _describe 'command' commands
}

_karnel_modules() {
  local -a modules=(
    'ai:AI tools'
    'auto:Automation tools'
    'db:Databases'
    'deploy:Deployment CLIs'
    'dev:Development tools'
    'editor:Code editors'
    'games:Terminal games'
    'lang:Programming languages'
    'network:Network tools'
    'npm:Node.js packages'
    'osint:OSINT tools'
    'plugin:Built-in plugin manager'
    'security:Security tools'
    'shell:Zsh shell plugins'
    'ui:Termux UI components'
    'utils:Utility scripts'
    'voice:Speech-to-agent tools'
  )
  _describe 'module' modules
}

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

  local -a flags=()
  local tool
  for tool in ${(s: :)tools}; do
    flags+=("--$tool")
  done
  compadd -- $flags
}

_karnel() {
  local command="${words[2]}"

  if (( CURRENT == 2 )); then
    _karnel_commands
    compadd -- --auto
    return
  fi

  case "$command" in
    install|uninstall|reinstall)
      if (( CURRENT == 3 )); then _karnel_modules; compadd -- supabase; else _karnel_tool_flags "${words[3]}"; compadd -- --auto; fi
      ;;
    update)
      if (( CURRENT == 3 )); then _karnel_modules; compadd -- supabase karnel; else _karnel_tool_flags "${words[3]}"; compadd -- --auto; fi
      ;;
    show)
      if (( CURRENT == 3 )); then _karnel_modules; compadd -- backup restore; else _karnel_tool_flags "${words[3]}"; fi
      ;;
    list)
      (( CURRENT == 3 )) && _karnel_modules
      ;;
    doctor)
      if (( CURRENT == 3 )); then
        _karnel_add "termux code robin --quick -q --fix -f --help -h"
      else
        case "${words[3]}" in
          termux) _karnel_add "--quick -q --fix -f --help -h" ;;
          code) _karnel_add "--quick -q --standard -s --deep -d --fix --safe-fix --aggressive-fix --json -j --help -h" ;;
          robin) _karnel_add "--network --help -h" ;;
        esac
      fi
      ;;
    robin)
      if (( CURRENT == 3 )); then
        _karnel_add "start stop status config doctor update purge-data help --help -h"
      else
        case "${words[3]}" in
          start) _karnel_add "--accept-responsible-use" ;;
          doctor) _karnel_add "--network" ;;
          purge-data) _karnel_add "--yes" ;;
        esac
      fi
      ;;
    restore)
      if [[ "$PREFIX" == -* ]]; then _karnel_add "--cloud --list -l --help -h"; else _files; fi
      ;;
    plugin)
      if (( CURRENT == 3 )); then
        _karnel_add "install remove uninstall update list ls search create scaffold"
      elif [[ "${words[CURRENT-1]}" == --capability ]]; then
        _karnel_add "network filesystem-read filesystem-write process environment"
      else
        case "${words[3]}" in
          install|update) _karnel_add "--unsafe" ;;
          search) _karnel_add "--command --compatible --capability --help -h" ;;
        esac
      fi
      ;;
    backup) _karnel_add "snapshot list ls info show restore --cron --cloud --help -h" ;;
    brain)
      if (( CURRENT == 3 )); then
        _karnel_add "init save search ask config ai-config ls list edit delete rm reset destroy relate show view dashboard dash stats graph map skill skills sync --help -h"
      elif [[ "${words[3]}" == ask ]]; then
        _karnel_add "--only-memories -m"
      fi
      ;;
    deploy) (( CURRENT == 3 )) && _karnel_add "vercel railway netlify supabase --help -h" ;;
    env) (( CURRENT == 3 )) && _karnel_add "set unset ls list --help -h" ;;
    ia)
      if (( CURRENT == 3 )); then
        _karnel_add "sessions install routes launchers --help -h"
      elif [[ "${words[3]}" == sessions ]]; then
        _karnel_add "--all"
      elif [[ "${words[3]}" == install ]]; then
        local ai_tools="10router qwen-code gemini-cli claude-code mistral-vibe openclaude openclaw ollama codex opencode mimocode engram codegraph pi antigravity-cli minimax-cli gentle-ai gga hermes-agent kimi-code command-code codebuff freebuff kilocode-cli kiro crush cline odysseus kimchi-code omni-route ctx7 openspec supercode-cli puter keelcode copilot-termux qoder ampcode cursor-cli oh-my-pi goose droid cactus cactus-needle hugging-face walkie"
        _karnel_add "$ai_tools"
      fi
      ;;
    init) (( CURRENT == 3 )) && _karnel_add "next nextjs react vite nest nestjs express exp python fastapi go gin rust axum --help -h" ;;
    pg) (( CURRENT == 3 )) && _karnel_add "start stop restart status init create drop backup restore list-backups backups schedule list ls shell psql --help -h" ;;
    start) (( CURRENT == 3 )) && _karnel_add "editor robin" ;;
    supabase) (( CURRENT == 3 )) && _karnel_add "doctor types migrate link remote-start remote remote-status status install uninstall help --help -h" ;;
    voice) _karnel_add "kilo opencode claude-code codex gemini-cli hermes-agent kimi-code mimocode mistral-vibe openclaude pi qwen-code crush kiro text ! --lang --raw --no-clip --help -h" ;;
    open) (( CURRENT == 3 )) && _karnel_add "karnel help lang db ai editor dev npm shell ui auto deploy supabase games cleanup network utils voice plugin security osint robin --help -h" ;;
    *) _default ;;
  esac
}

compdef _karnel karnel
