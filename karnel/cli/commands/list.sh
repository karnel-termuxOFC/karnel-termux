#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

list_main() {
  local status=0

  if [[ $# -eq 0 ]]; then
    echo
    box "Karnel List"
    echo
    log_info "Usage: karnel list <target>"
    echo
    log_info "Available targets:"
    echo
    list_item "lang       - List language packages"
    list_item "db         - List database packages"
    list_item "ai         - List AI tools"
    list_item "editor     - List code editor components"
    list_item "dev        - List development tools"
    list_item "npm        - List Node.js global modules"
    list_item "shell      - List ZSH plugins"
    list_item "ui         - List Termux UI components"
    list_item "auto       - List automation tools"
    list_item "deploy     - List deploy CLIs (Vercel, Railway, Netlify, Supabase)"
    list_item "games      - List games"
    list_item "network    - List network tools"
    list_item "utils      - List utility scripts"
    list_item "voice      - List voice commands"
    list_item "osint      - List OSINT tools"
    list_item "security   - List security tools"
    list_item "plugin     - List installed plugins"
    echo
    return
  fi

  for arg in "$@"; do
    case "$arg" in
    lang)
      _list_lang
      ;;
    db)
      _list_db
      ;;
    ai)
      _list_ai
      ;;
    editor)
      _list_editor
      ;;
    dev)
      _list_dev
      ;;
    npm)
      _list_npm
      ;;
    shell)
      _list_shell
      ;;
    ui)
      _list_ui
      ;;
    auto)
      _list_auto
      ;;
    deploy)
      _list_deploy
      ;;
    games)
      _list_games
      ;;
    osint)
      _list_osint
      ;;
    network)
      _list_network
      ;;
    utils)
      _list_utils
      ;;
    plugin | plugins)
      import "@/tools/plugins/install"
      echo "Installed Plugins:"
      _list_plugins
      ;;
    security)
      _list_security
      ;;
    voice)
      _list_voice
      ;;
    *)
      log_warn "Unknown list target: $arg"
      echo "Run 'karnel list' to see available targets"
      status=1
      ;;
    esac
  done
  return "$status"
}

# ===== LIST DEPLOY =====
_list_deploy() {
  echo
  box "Deploy CLIs"
  echo
  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "Vercel CLI" "--vercel" "vercel" "$(_check_cmd "vercel")"
  table_row "Railway CLI" "--railway" "railway" "$(_check_cmd "railway")"
  table_row "Netlify CLI" "--netlify" "netlify" "$(_check_cmd "netlify")"
  table_row "Supabase CLI" "--supabase" "supabase" "$(_check_cmd "supabase")"
  table_end
  echo
  list_item "Usage: ${D_CYAN}karnel install deploy${NC} to install all"
  list_item "Usage: ${D_CYAN}karnel install deploy --vercel${NC} for specific"
  list_item "Usage: ${D_CYAN}karnel supabase${NC} for Supabase CLI subcommands"
  echo
}

# ===== LIST LANGUAGE =====
_list_lang() {
  echo
  box "Language Packages"
  echo
  log_info "Available packages and install commands:"
  echo

  table_start "Package" "Install Flag" "Status"
  table_row "Bun" "--bun" "$(_check_cmd "bun")"
  table_row "Node.js LTS" "--nodejs" "$(_check_pkg "nodejs-lts")"
  table_row "Python" "--python" "$(_check_pkg "python")"
  table_row "Perl" "--perl" "$(_check_pkg "perl")"
  table_row "PHP" "--php" "$(_check_pkg "php")"
  table_row "Rust" "--rust" "$(_check_pkg "rust")"
  table_row "C/C++ (clang)" "--clang" "$(_check_pkg "clang")"
  table_row "Go (golang)" "--golang" "$(_check_pkg "golang")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install lang --nodejs --python${NC}"
  log_info "Install all: ${D_CYAN}karnel install lang${NC}"
  echo
}

# ===== LIST DB =====
_list_db() {
  echo
  box "Database Packages"
  echo
  log_info "Available packages and install commands:"
  echo

  table_start "Database" "Install Flag" "Status"
  table_row "PostgreSQL" "--postgresql" "$(_check_pkg "postgresql")"
  table_row "MariaDB" "--mariadb" "$(_check_pkg "mariadb")"
  table_row "SQLite" "--sqlite" "$(_check_pkg "sqlite")"
  table_row "MongoDB" "--mongodb" "$(_check_pkg "mongodb")"
  table_row "Redis" "--redis" "$(_check_pkg "redis")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install db --postgresql --sqlite${NC}"
  log_info "Install all: ${D_CYAN}karnel install db${NC}"
  echo
}

# ===== LIST AI =====
_list_ai() {
  echo
  box "AI Tools"
  echo
  log_info "Available AI tools and install commands:"
  echo

  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "10Router" "--10router" "10router" "$(_check_cmd "10router")"
  table_row "Qwen Code" "--qwen-code" "qwen" "$(_check_cmd "qwen")"
  table_row "Gemini CLI" "--gemini-cli" "gemini" "$(_check_cmd "gemini")"
  table_row "Claude Code" "--claude-code" "claude" "$(_check_cmd "claude")"
  table_row "Mistral Vibe" "--mistral-vibe" "vibe" "$(_check_cmd "vibe")"
  table_row "OpenClaude" "--openclaude" "openclaude" "$(_check_cmd "openclaude")"
  table_row "OpenClaw" "--openclaw" "openclaw" "$(_check_cmd "openclaw")"
  table_row "Ollama" "--ollama" "ollama" "$(_check_pkg "ollama")"
  table_row "Codex CLI" "--codex" "codex" "$(_check_cmd "codex")"
  table_row "OpenCode" "--opencode" "opencode" "$(_check_cmd "opencode")"
  table_row "MiMo Code" "--mimocode" "mimo" "$(_check_cmd "mimo")"
  table_row "Engram" "--engram" "engram" "$(_check_cmd "engram")"
  table_row "CodeGraph" "--codegraph" "codegraph" "$(_check_cmd "codegraph")"
  table_row "Pi Coding Agent" "--pi" "pi" "$(_check_cmd "pi")"
  table_row "Antigravity CLI" "--antigravity-cli" "agy" "$(_check_cmd "agy")"
  table_row "Minimax CLI" "--minimax-cli" "mmx" "$(_check_cmd "mmx")"
  table_row "Gentle AI" "--gentle-ai" "gentle-ai" "$(_check_cmd "gentle-ai")"
  table_row "GGA" "--gga" "gga" "$(_check_cmd "gga")"
  table_row "Hermes Agent" "--hermes-agent" "hermes" "$(_check_cmd "hermes")"
  table_row "Kimi Code" "--kimi-code" "kimi" "$(_check_cmd "kimi")"
  table_row "Command Code" "--command-code" "command-code" "$(_check_cmd "command-code")"
  table_row "Codebuff" "--codebuff" "codebuff" "$(_check_cmd "codebuff")"
  table_row "Freebuff" "--freebuff" "freebuff" "$(_check_cmd "freebuff")"
  table_row "Kilo Code CLI" "--kilocode-cli" "kilocode,kilo" "$(_check_cmd_any "kilocode,kilo")"
  table_row "Kiro CLI" "--kiro" "kiro,kiro-cli" "$(_check_cmd_any "kiro,kiro-cli")"
  table_row "Crush CLI" "--crush" "crush" "$(_check_cmd "crush")"
  table_row "Cline CLI" "--cline" "cline" "$(_check_cmd "cline")"
  table_row "Odysseus" "--odysseus" "odysseus" "$(_check_cmd "odysseus")"
  table_row "Kimchi CLI" "--kimchi-code" "kimchi" "$(_check_cmd "kimchi")"
  table_row "omniRoute" "--omni-route" "omni-route" "$(_check_omni_route)"
  table_row "Context7 Docs" "--ctx7" "ctx7" "$(_check_cmd "ctx7")"
  table_row "OpenSpec SDD Framework" "--openspec" "openspec" "$(_check_cmd "openspec")"
  table_row "Qoder" "--qoder" "qodercli" "$(_check_cmd "qodercli")"
  table_row "AMP Code CLI" "--ampcode" "amp" "$(_check_cmd "amp")"
  table_row "Cursor CLI" "--cursor-cli" "cursor,cursor-agent" "$(_check_cmd_any "cursor,cursor-agent")"
  table_row "Oh-My-Pi" "--oh-my-pi" "omp" "$(_check_cmd "omp")"
  table_row "Goose CLI" "--goose" "goose" "$(_check_cmd "goose")"
  table_row "Factory Droid" "--droid" "droid" "$(_check_cmd "droid")"
  table_row "Cactus" "--cactus" "cactus" "$(_check_cmd "cactus")"
  table_row "Cactus Needle" "--cactus-needle" "needle" "$(_check_cmd "needle")"
  table_row "Walkie Agent" "--walkie" "walkie" "$(_check_cmd "walkie")"
  table_row "Hugging Face" "--hugging-face" "hf" "$(_check_cmd "hf")"
  table_row "Copilot-Termux" "--copilot-termux" "copilot" "$(_check_cmd "copilot")"
  table_row "Supercode CLI" "--supercode-cli" "supercode" "$(_check_cmd "supercode")"
  table_row "Puter CLI" "--puter" "puter" "$(_check_cmd "puter")"
  table_row "KeelCode" "--keelcode" "keelcode" "$(_check_cmd "keelcode")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install ai --opencode --engram${NC}"
  log_info "Install all: ${D_CYAN}karnel install ai${NC}"
  echo
}

# ===== LIST EDITOR =====
_list_editor() {
  echo
  box "Code Editor"
  echo
  log_info "Available components and install commands:"
  echo

  table_start "Component" "Install Flag" "Status"
  table_row "code-server" "--code-server" "$(_check_cmd "code-server")"
  table_row "neovim" "--neovim" "$(_check_cmd "nvim")"
  table_row "nvchad" "--nvchad" "$(_check_nvchad)"
  table_end

  echo
  log_info "Install: ${D_CYAN}karnel install editor --code-server${NC}"
  log_info "Start: ${D_CYAN}karnel start editor${NC}"
  echo
}

# ===== LIST TOOLS =====
_list_dev() {
  echo
  box "Development Tools"
  echo
  log_info "Available tools and install commands:"
  echo

  table_start "Tool" "Install Flag" "Status"
  table_row "GitHub CLI" "--gh" "$(_check_pkg "gh")"
  table_row "Wget" "--wget" "$(_check_pkg "wget")"
  table_row "Curl" "--curl" "$(_check_pkg "curl")"
  table_row "LSD" "--lsd" "$(_check_pkg "lsd")"
  table_row "Bat" "--bat" "$(_check_pkg "bat")"
  table_row "Proot" "--proot" "$(_check_pkg "proot")"
  table_row "Ncurses Utils" "--ncurses" "$(_check_pkg "ncurses-utils")"
  table_row "Tmate" "--tmate" "$(_check_pkg "tmate")"
  table_row "Cloudflared" "--cloudflared" "$(_check_pkg "cloudflared")"
  table_row "Translate Shell" "--translate" "$(_check_pkg "translate-shell")"
  table_row "html2text" "--html2text" "$(_check_pkg "html2text")"
  table_row "jq" "--jq" "$(_check_pkg "jq")"
  table_row "bc" "--bc" "$(_check_pkg "bc")"
  table_row "Tree" "--tree" "$(_check_pkg "tree")"
  table_row "Fzf" "--fzf" "$(_check_pkg "fzf")"
  table_row "ImageMagick" "--imagemagick" "$(_check_pkg "imagemagick")"
  table_row "Shfmt" "--shfmt" "$(_check_pkg "shfmt")"
  table_row "Make" "--make" "$(_check_pkg "make")"
  table_row "Udocker" "--udocker" "$(_check_pkg "udocker")"
  table_row "OpenSSH" "--openssh" "$(_check_pkg "openssh")"
  table_row "Tmux" "--tmux" "$(_check_pkg "tmux")"
  table_row "Snyk" "--snyk" "$(_check_cmd "snyk")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install dev --gh --fzf --jq${NC}"
  log_info "Install all: ${D_CYAN}karnel install dev${NC}"
  echo
}

# ===== LIST GAMES =====
_list_games() {
  echo
  box "Games"
  echo
  log_info "Available games and install commands:"
  echo

  table_start "Game" "Install Flag" "Status"
  table_row "Buzz" "--buzz" "$(_check_cmd "buzz")"
  table_row "CTF God" "--ctfgod" "$(_check_cmd "ctfgod")"
  table_row "Detective" "--detective" "$(_check_cmd "detective")"
  table_row "Pet Friends" "--pet-friends" "$(_check_cmd "pet-friends")"
  table_row "Tamagotchi" "--tamagotchi" "$(_check_cmd "tamagotchi")"
  table_row "Terminal Arcade" "--arcade" "$(_check_cmd "arcade")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install games --buzz --ctfgod${NC}"
  log_info "Install all: ${D_CYAN}karnel install games${NC}"
  echo
}

# ===== LIST NODE =====
_list_npm() {
  echo
  box "Node.js Global Modules"
  echo
  log_info "Available modules and install commands:"
  echo

  table_start "Module" "Install Flag" "Command" "Status"
  table_row "TypeScript" "--typescript" "tsc" "$(_check_cmd "tsc")"
  table_row "NestJS CLI" "--nestjs" "nest" "$(_check_cmd "nest")"
  table_row "Prettier" "--prettier" "prettier" "$(_check_cmd "prettier")"
  table_row "Live Server" "--live-server" "live-server" "$(_check_cmd "live-server")"
  table_row "Localtunnel" "--localtunnel" "lt" "$(_check_cmd "lt")"
  table_row "Vercel CLI" "--vercel" "vercel" "$(_check_cmd "vercel")"
  table_row "Markserv" "--markserv" "markserv" "$(_check_cmd "markserv")"
  table_row "PSQL Format" "--psqlformat" "psqlformat" "$(_check_cmd "psqlformat")"
  table_row "NPM Check Updates" "--ncu" "ncu" "$(_check_cmd "ncu")"
  table_row "Ngrok" "--ngrok" "ngrok" "$(_check_cmd "ngrok")"
  table_row "Turbopack" "--turbopack" "turbo" "$(_check_cmd "turbo")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install npm --typescript --prettier${NC}"
  log_info "Install all: ${D_CYAN}karnel install npm${NC}"
  echo
}

# ===== LIST SHELL =====
_list_shell() {
  echo
  box "ZSH Shell Plugins"
  echo
  log_info "Available plugins and install commands:"
  echo

  table_start "Plugin" "Install Flag" "Status"
  table_row "powerlevel10k" "--powerlevel10k" "$(_check_plugin "powerlevel10k")"
  table_row "zsh-defer" "--zsh-defer" "$(_check_plugin "zsh-defer")"
  table_row "zsh-autosuggestions" "--zsh-autosuggestions" "$(_check_plugin "zsh-autosuggestions")"
  table_row "zsh-syntax-highlighting" "--zsh-syntax-highlighting" "$(_check_plugin "zsh-syntax-highlighting")"
  table_row "zsh-history-substring-search" "--history-substring" "$(_check_plugin "zsh-history-substring-search")"
  table_row "zsh-completions" "--zsh-completions" "$(_check_plugin "zsh-completions")"
  table_row "fzf-tab" "--fzf-tab" "$(_check_plugin "fzf-tab")"
  table_row "zsh-you-should-use" "--you-should-use" "$(_check_plugin "zsh-you-should-use")"
  table_row "zsh-autopair" "--zsh-autopair" "$(_check_plugin "zsh-autopair")"
  table_row "zsh-better-npm-completion" "--better-npm" "$(_check_plugin "zsh-better-npm-completion")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install shell --powerlevel10k --fzf-tab${NC}"
  log_info "Install all: ${D_CYAN}karnel install shell${NC}"
  echo
}

# ===== LIST UI =====
_list_ui() {
  echo
  box "Termux UI Components"
  echo
  log_info "Available components and install commands:"
  echo

  table_start "Component" "Install Flag" "Status"
  table_row "Meslo Nerd Font" "--font" "$(_check_font)"
  table_row "Extra Keys" "--extra-keys" "$(_check_extra_keys)"
  table_row "Cursor Color" "--cursor" "$(_check_cursor)"
  table_row "Startup Banner" "--banner" "$(_grep_config "$HOME/.zshrc" "# ===== Karnel Banner =====" "$HOME/.bashrc")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install ui --font --extra-keys${NC}"
  log_info "Install all: ${D_CYAN}karnel install ui${NC}"
  echo
}

# ===== LIST AUTOMATION =====
_list_auto() {
  echo
  box "Automation Tools"
  echo
  log_info "Available tools and install commands:"
  echo

  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "n8n" "--n8n" "n8n" "$(_check_cmd "n8n")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install auto --n8n${NC}"
  log_info "Install all: ${D_CYAN}karnel install auto${NC}"
  echo
}

# ===== LIST OSINT =====
_list_osint() {
  import "@/tools/osint/robin/common"
  echo
  box "OSINT Tools"
  echo
  log_info "Available OSINT tools and install commands:"
  echo

  table_start "Tool" "Install Flag" "Status"
  table_row "Robin — Dark Web OSINT" "--robin" "$(_check_robin)"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install osint --robin${NC}"
  log_info "Install all: ${D_CYAN}karnel install osint${NC}"
  log_info "Start: ${D_CYAN}karnel robin start${NC}"
  echo
}

# ===== LIST NETWORK =====
_list_network() {
  echo
  box "Network Tools"
  echo
  log_info "Available network tools and install commands:"
  echo

  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "Dark Web OSINT" "--dark" "dark" "$(_check_cmd "dark")"
  table_row "DedSec Network Toolkit" "--dedsec-network" "dedsec-network" "$(_check_cmd "dedsec-network")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install network --dark --dedsec-network${NC}"
  log_info "Install all: ${D_CYAN}karnel install network${NC}"
  echo
}

# ===== LIST UTILS =====
_list_utils() {
  echo
  box "Utility Scripts"
  echo
  log_info "Available utility scripts and install commands:"
  echo

  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "File Converter" "--fconv" "fconv" "$(_check_cmd "fconv")"
  table_row "File Checker" "--filecheck" "filecheck" "$(_check_cmd "filecheck")"
  table_row "Websites Creator" "--websites" "websites" "$(_check_cmd "websites")"
  table_row "Smart Notes" "--notes" "notes" "$(_check_cmd "notes")"
  table_row "Tree Explorer" "--treex" "treex" "$(_check_cmd "treex")"
  table_row "Password Master" "--passman" "passman" "$(_check_cmd "passman")"
  table_row "App Launcher" "--applaunch" "applaunch" "$(_check_cmd "applaunch")"
  table_row "Loading Screen" "--splash" "splash" "$(_check_cmd "splash")"
  table_row "httptmux (API client)" "--httptmux" "httptmux" "$(_check_cmd "httptmux")"
  table_row "Zork (text adventure)" "--zork" "zork" "$(_check_cmd "zork")"
  table_row "QR Code Generator" "--qrcode" "qrcode" "$(_check_cmd "qrcode")"
  table_row "SuperFile" "--superfile" "spf" "$(_check_cmd "spf")"
  table_row "Herdr (AI assistant)" "--herdr" "herdr" "$(_check_cmd "herdr")"
  table_end

  echo
  log_info "Install specific: ${D_CYAN}karnel install utils --fconv --notes${NC}"
  log_info "Install all: ${D_CYAN}karnel install utils${NC}"
  echo
}

# ===== HELPER FUNCTIONS =====

# Check if command exists
_check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

_check_omni_route() {
  if command -v omni-route &>/dev/null && omni-route --version &>/dev/null 2>&1; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

_check_nvchad() {
  if [[ -d "$KARNEL_DATA/nvchad-termux/.git" && -d "$HOME/.config/nvim" ]]; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

# Check if any of the comma-separated commands exists
_check_cmd_any() {
  local bin_list="$1"
  local bin
  IFS=',' read -ra bins <<< "$bin_list"
  for bin in "${bins[@]}"; do
    if command -v "$bin" &>/dev/null; then
      echo -e "${D_GREEN}installed${NC}"
      return 0
    fi
  done
  echo -e "${D_RED}not installed${NC}"
}

# Check if package is installed via pkg
_check_pkg() {
  local pkg="$1"
  if dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

_check_robin() {
  if _robin_is_installed; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

_check_font() {
  local font_source
  font_source="$(dirname "$KARNEL_PATH")/assets/fonts/font.ttf"
  if [[ -f "$font_source" ]] && cmp -s "$font_source" "$HOME/.termux/font.ttf"; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

_check_cursor() {
  if grep -qF '# Karnel cursor begin' "$HOME/.termux/colors.properties" 2>/dev/null &&
    grep -qF '# Karnel cursor end' "$HOME/.termux/colors.properties" 2>/dev/null; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

  # Check if extra-keys are configured by karnel
_check_extra_keys() {
  if grep -qF "# Karnel extra-keys begin" "$HOME/.termux/termux.properties" 2>/dev/null &&
    grep -qF "extra-keys = " "$HOME/.termux/termux.properties" 2>/dev/null; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

# Check if ZSH plugin exists
_check_plugin() {
  local plugin="$1"
  if [[ -d "$HOME/.zsh-plugins/$plugin" ]]; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

# Check if pattern exists in config file (with fallback)
_grep_config() {
  local primary="$1"
  local pattern="$2"
  local fallback="$3"

  if [[ -f "$primary" ]] && grep -qF "$pattern" "$primary" 2>/dev/null; then
    echo -e "${D_GREEN}installed${NC}"
  elif [[ -n "$fallback" && -f "$fallback" ]] && grep -qF "$pattern" "$fallback" 2>/dev/null; then
    echo -e "${D_GREEN}installed${NC}"
  else
    echo -e "${D_RED}not installed${NC}"
  fi
}

# ===== LIST SECURITY =====
_list_security() {
  echo
  box "Security Tools"
  echo
  log_info "Available security tools:"
  echo
  table_start "Tool" "Install Flag" "Command" "Status"
  table_row "Nmap" "--nmap" "nmap" "$(_check_cmd "nmap")"
  table_row "Hydra" "--hydra" "hydra" "$(_check_cmd "hydra")"
  table_row "Nikto" "--nikto" "nikto" "$(_check_cmd "nikto")"
  table_row "SQLMap" "--sqlmap" "sqlmap" "$(_check_cmd "sqlmap")"
  table_row "Gobuster" "--gobuster" "gobuster" "$(_check_cmd "gobuster")"
  table_row "Dirb" "--dirb" "dirb" "$(_check_cmd "dirb")"
  table_row "WPScan" "--wpscan" "wpscan" "$(_check_cmd "wpscan")"
  table_row "John the Ripper" "--john" "john" "$(_check_cmd "john")"
  table_row "Aircrack-ng" "--aircrack-ng" "aircrack-ng" "$(_check_cmd "aircrack-ng")"
  table_row "Metasploit" "--metasploit" "msfconsole" "$(_check_cmd "msfconsole")"
  table_row "Burp Suite" "--burpsuite" "burpsuite" "$(_check_cmd "burpsuite")"
  table_row "OWASP ZAP" "--zap" "zap" "$(_check_cmd "zap")"
  table_row "Enum4linux" "--enum4linux" "enum4linux" "$(_check_cmd "enum4linux")"
  table_row "SMB client" "--smbclient" "smbclient" "$(_check_cmd "smbclient")"
  table_row "FFUF" "--ffuf" "ffuf" "$(_check_cmd "ffuf")"
  table_row "WhatWeb" "--whatweb" "whatweb" "$(_check_cmd "whatweb")"
  table_row "WAFW00F" "--wafw00f" "wafw00f" "$(_check_cmd "wafw00f")"
  table_row "DNSRecon" "--dnsrecon" "dnsrecon" "$(_check_cmd "dnsrecon")"
  table_row "theHarvester" "--theharvester" "theHarvester" "$(_check_cmd "theHarvester")"
  table_row "Subfinder" "--subfinder" "subfinder" "$(_check_cmd "subfinder")"
  table_row "Amass" "--amass" "amass" "$(_check_cmd "amass")"
  table_row "Masscan" "--masscan" "masscan" "$(_check_cmd "masscan")"
  table_row "Netcat" "--netcat" "nc" "$(_check_cmd "nc")"
  table_row "Tcpdump" "--tcpdump" "tcpdump" "$(_check_cmd "tcpdump")"
  table_row "Whois" "--whois" "whois" "$(_check_cmd "whois")"
  table_row "Hashcat" "--hashcat" "hashcat" "$(_check_cmd "hashcat")"
  table_row "Binwalk" "--binwalk" "binwalk" "$(_check_cmd "binwalk")"
  table_row "Foremost" "--foremost" "foremost" "$(_check_cmd "foremost")"
  table_row "Steghide" "--steghide" "steghide" "$(_check_cmd "steghide")"
  table_row "ExifTool" "--exiftool" "exiftool" "$(_check_cmd "exiftool")"
  table_end
  echo
  log_info "Install all: ${D_CYAN}karnel install security${NC}"
  echo
}

# ===== LIST VOICE =====
_list_voice() {
  echo
  box "Voice Command"
  echo
  table_start "Component" "Install Flag" "Status"
  table_row "Voice Command" "voice" "built-in"
  table_end
  echo
  list_item "Usage: ${D_CYAN}karnel install voice${NC}"
  echo
}
