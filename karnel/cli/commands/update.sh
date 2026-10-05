#!/usr/bin/env bash

import "@/utils/npm"
import "@/utils/log"
import "@/utils/colors"
import "@/utils/tools"

update_main() {

  if [[ $# -eq 0 ]]; then
    echo
    box "Karnel Update"
    echo
    log_info "Usage: karnel update <target>"
    log_info "Usage: karnel update <target> --tool1 --tool2"
    echo
    log_info "Available targets:"
    echo
    list_item "karnel     - Update only Karnel-Termux framework"
    list_item "lang       - Update language packages (pkg upgrade)"
    list_item "db         - Update databases"
    list_item "ai         - Update AI tools (npm/pip/pkg)"
    list_item "editor     - Update Neovim configuration"
    list_item "dev        - Update development tools"
    list_item "npm        - Update Node.js global modules"
    list_item "shell      - Update ZSH plugins"
    list_item "ui         - Update Termux UI"
    list_item "auto       - Update Automation Tools"
    list_item "network    - Update network tools"
    list_item "utils      - Update utility scripts"
    list_item "games      - Update games"
    list_item "deploy     - Update deploy CLIs (Vercel, Railway, Netlify, Supabase)"
    list_item "supabase   - Update Supabase CLI"
    list_item "voice      - Update voice command"
    list_item "osint      - Update OSINT tools"
    list_item "security   - Update security tools"
    list_item "plugin     - Update plugins"
    echo
    log_info "Update specific tools with flags:"
    echo
    list_item "karnel update ai --qwen-code --ollama"
    list_item "karnel update db --postgresql --sqlite"
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
    log_info "To update specific tools, use -- before the name:"
    log_info "  ${D_CYAN}karnel update $module_target --${invalid_args[0]}${NC}"
    echo
    return 1
  fi

  # If no module target specified, show error
  if [[ -z "$module_target" ]]; then
    log_error "No target specified"
    echo "Run 'karnel update' to see available targets"
    return 1
  fi

  # If no tool flags, update entire module (original behavior)
  if [[ ${#tool_flags[@]} -eq 0 ]]; then
    _update_full_module "$module_target"
  else
    # Update specific tools
    _update_specific_tools "$module_target" "${tool_flags[@]}"
  fi
}

# Update entire module (original behavior)
_update_full_module() {
  local target="$1"

  case "$target" in
  karnel)
    update_karnel
    ;;
  lang)
    import "@/modules/lang"
    update_lang
    ;;
  db)
    import "@/modules/db"
    update_db
    ;;
  ai)
    import "@/modules/ai"
    update_ai
    ;;
  editor)
    import "@/modules/editor"
    update_editor
    ;;
  dev)
    import "@/modules/dev"
    update_dev
    ;;
  npm)
    import "@/modules/npm"
    update_npm
    ;;
  shell)
    import "@/modules/shell"
    update_shell
    ;;
  ui)
    import "@/modules/ui"
    update_ui
    ;;
  auto)
    import "@/modules/auto"
    update_auto
    ;;
  games)
    import "@/modules/games"
    update_games
    ;;
  osint)
    import "@/modules/osint"
    update_osint
    ;;
  network)
    import "@/modules/network"
    update_network
    ;;
  utils)
    import "@/modules/utils"
    update_utils
    ;;
  plugin)
    import "@/modules/plugin"
    update_plugin_module
    ;;
  security)
    import "@/modules/security"
    update_security
    ;;
  supabase)
    import "@/tools/deploy/supabase/install"
    update_supabase
    ;;
  deploy)
    import "@/modules/deploy"
    update_deploy
    ;;
  voice)
    import "@/modules/voice"
    update_voice
    ;;
  *)
    log_warn "Unknown update target: $target"
    echo "Run 'karnel update' to see available targets"
    return 1
    ;;
  esac
}

# Update specific tools within a module
_update_specific_tools() {
  local module="$1"
  shift
  if [[ "$module" == "osint" ]]; then
    import "@/tools/osint/robin/common"
    _robin_print_disclaimer
  fi
  _batch_tool_action "$module" "update" "$@"
}

# Actualizar Karnel-Termux
update_karnel() {
  separator
  box "◈ UPDATING KARNEL-TERMUX ◈"
  separator
  echo

  # The official installer keeps all installation layouts consistent.
  _update_try_curl && { _update_cleanup; return 0; }
  _update_try_git && { _update_cleanup; return 0; }
  _update_try_npm && { _update_cleanup; return 0; }
  _update_try_npm_install && { _update_cleanup; return 0; }
  _update_try_pnpm && { _update_cleanup; return 0; }

  log_error "All update methods failed"
  _update_show_manual

  echo
  return 1
}

_update_cleanup() {
  rm -f "$KARNEL_CACHE/new_version" "$KARNEL_CACHE/last_version_check"
}

_update_release_commit() {
  local tag="$1" commit=""
  if command -v git &>/dev/null 2>&1; then
    commit=$(git ls-remote "https://github.com/karnel-termuxOFC/karnel-termux.git" "refs/tags/${tag}^{}" 2>/dev/null | awk '{print $1}')
  fi
  if [[ -z "$commit" ]] && command -v curl &>/dev/null 2>&1; then
    commit=$(curl -fsS -m 10 "https://api.github.com/repos/karnel-termuxOFC/karnel-termux/commits/${tag}" 2>/dev/null \
      | grep -m1 '"sha"' | sed -E 's/.*"sha":[[:space:]]*"([0-9a-f]{40})".*/\1/')
  fi
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] && echo "$commit"
}

_update_try_curl() {
  command -v curl &>/dev/null || return 1

  local meta installer sumfile tag
  meta=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-meta.XXXXXX") || return 1
  installer=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-install.XXXXXX") || { rm -f "$meta"; return 1; }
  sumfile=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-sum.XXXXXX") || { rm -f "$meta" "$installer"; return 1; }

  log_info "Trying the official curl installer..."

  if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "https://api.github.com/repos/karnel-termuxOFC/karnel-termux/releases/latest" \
    -o "$meta"; then
    rm -f "$meta" "$installer" "$sumfile"
    return 1
  fi

  tag=$(_update_latest_release_tag "$meta")
  if [[ -z "$tag" || ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "GitHub returned an invalid release tag: ${tag:-none}"
    rm -f "$meta" "$installer" "$sumfile"
    return 1
  fi

  if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "https://github.com/karnel-termuxOFC/karnel-termux/releases/download/$tag/karnel-termux-install.sh.sha256" \
    -o "$sumfile" ||
    ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "https://github.com/karnel-termuxOFC/karnel-termux/releases/download/$tag/karnel-termux-install.sh" \
    -o "$installer"; then
    rm -f "$meta" "$installer" "$sumfile"
    return 1
  fi

  if ! _verify_sha256 "$installer" "$sumfile"; then
    log_error "Checksum verification failed for the curl installer"
    rm -f "$meta" "$installer" "$sumfile"
    return 1
  fi

  rm -f "$meta" "$sumfile"

  # Resolve the release's target commit so the installer's "immutable
  # commit SHA" requirement is satisfied even when the downloaded asset
  # does not have RELEASE_COMMIT baked in.
  local commit
  commit=$(_update_release_commit "$tag")
  if [[ -n "$commit" ]]; then
    if bash "$installer" --ref "$tag" --commit "$commit"; then
      rm -f "$installer"
      log_success "Karnel-Termux updated via curl ($tag)"
      return 0
    fi
  else
    log_error "Could not verify the immutable commit for $tag"
  fi

  rm -f "$installer"
  log_error "Curl update failed"
  return 1
}

_update_latest_release_tag() {
  local meta="$1"
  if command -v node &>/dev/null; then
    node -e '
      let s = "";
      process.stdin.resume();
      process.stdin.on("data", (d) => { s += d; });
      process.stdin.on("end", () => {
        try { process.stdout.write(JSON.parse(s).tag_name || ""); } catch (e) {}
      });
    ' < "$meta"
    return
  fi
  grep -oP '"tag_name":\s*"\K[^"]+' "$meta" 2>/dev/null | head -n 1
}

_verify_sha256() {
  local file="$1" sumfile="$2"
  local expected actual
  local -a checksum_lines

  mapfile -t checksum_lines <"$sumfile" || return 1
  if [[ ${#checksum_lines[@]} -ne 1 ]] || [[ ! "${checksum_lines[0]}" =~ ^([0-9a-f]{64})[[:space:]]+\*?karnel-termux-install\.sh$ ]]; then
    return 1
  fi
  expected="${BASH_REMATCH[1]}"
  if command -v sha256sum &>/dev/null; then
    actual=$(sha256sum "$file" | awk '{ print $1 }')
  elif command -v node &>/dev/null; then
    actual=$(node -e '
      const fs = require("fs");
      const crypto = require("crypto");
      process.stdout.write(crypto.createHash("sha256").update(fs.readFileSync(process.argv[1])).digest("hex"));
    ' "$file")
  else
    return 1
  fi
  [[ "$actual" == "$expected" ]]
}

_update_try_git() {
  [[ -d "$KARNEL_PATH/../.git" ]] || return 1
  loading "Updating via git" _update_karnel_repo
  local rc=$?
  echo
  if [[ $rc -eq 0 ]]; then
    log_success "Karnel-Termux updated via git"
    source "$KARNEL_PATH/utils/env.sh" 2>/dev/null
    local new_ver="$KARNEL_VERSION"
    log_success "Version: v$new_ver"
    return 0
  elif [[ $rc -eq 2 ]]; then
    log_success "Karnel-Termux is already up to date"
    return 0
  fi
  log_error "Git update failed"
  return 1
}

_npm_installed_version() {
  local v pr
  v=$(npm list -g karnel-termux 2>/dev/null | grep -oP 'karnel-termux@\K[0-9.]+')
  if [[ -z "$v" ]]; then
    pr="$(npm root -g 2>/dev/null)/karnel-termux/package.json"
    [[ -f "$pr" ]] && v=$(grep -oP '"version"\s*:\s*"\K[0-9.]+' "$pr")
  fi
  printf '%s' "${v:-unknown}"
}

_update_global_package_is_active() {
  local manager="${1:-npm}" root
  root=$("$manager" root -g 2>/dev/null) || return 1
  [[ "$KARNEL_PATH" == "$root/karnel-termux/karnel" ]]
}

_update_try_npm() {
  command -v npm &>/dev/null || return 1
  if ! _update_global_package_is_active; then
    log_info "Skipping npm update: the active Karnel framework is not npm-managed"
    return 1
  fi
  log_info "Trying npm update..."
  if karnel_npm update -g karnel-termux --ignore-scripts 2>/dev/null; then
    local new_ver
    new_ver=$(_npm_installed_version)
    log_success "Updated to v$new_ver via npm"
    return 0
  fi
  log_info "npm update not available, trying npm install..."
  return 1
}

_update_try_npm_install() {
  command -v npm &>/dev/null || return 1
  if ! _update_global_package_is_active; then
    log_info "Skipping npm install: the active Karnel framework is not npm-managed"
    return 1
  fi
  log_info "Trying npm install..."
  if karnel_npm install -g karnel-termux@latest --ignore-scripts 2>/dev/null; then
    local new_ver
    new_ver=$(_npm_installed_version)
    log_success "Updated to v$new_ver via npm install"
    return 0
  fi
  return 1
}

_update_try_pnpm() {
  command -v pnpm &>/dev/null || return 1
  if ! _update_global_package_is_active pnpm; then
    log_info "Skipping pnpm update: the active Karnel framework is not pnpm-managed"
    return 1
  fi
  log_info "Trying pnpm..."
  if pnpm add -g karnel-termux@latest 2>/dev/null; then
    log_success "Updated via pnpm"
    return 0
  fi
  return 1
}

_update_show_manual() {
  log_info "Update manually with one of these:"
  echo
  echo "  Follow the checksum-verified release procedure in README.md"
  echo "  npm install -g karnel-termux@latest"
  echo "  pnpm add -g karnel-termux@latest"
  echo
}

_update_karnel_repo() {
  local repo_dir="$KARNEL_PATH/.."
  local old_head origin

  origin=$(git -C "$repo_dir" remote get-url origin 2>/dev/null) || return 1
  case "${origin%.git}" in
    https://github.com/karnel-termuxOFC/karnel-termux|https://github.com/israelmarques1024-dotcom/karnel-termux|git@github.com:karnel-termuxOFC/karnel-termux|git@github.com:israelmarques1024-dotcom/karnel-termux) ;;
    *) log_error "Refusing git update from an untrusted origin: $origin"; return 1 ;;
  esac
  if [[ -n "$(git -C "$repo_dir" status --porcelain --untracked-files=all 2>/dev/null)" ]]; then
    log_error "Refusing git update with uncommitted framework changes"
    return 1
  fi

  old_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)

  if ! git -C "$repo_dir" pull --ff-only &>/dev/null; then
    return 1
  fi

  if [[ "$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)" == "$old_head" ]]; then
    return 2
  fi

  git -C "$repo_dir" log --oneline --no-decorate "$old_head..HEAD" 2>/dev/null | while IFS= read -r line; do
    printf "    ${CYAN}▸${NC} %s\n" "$line"
  done

  return 0
}
