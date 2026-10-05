#!/usr/bin/env bash

# =============================================================================
# Karnel AI Tools Orchestrator
# =============================================================================
# Este arquivo importa TODOS os scripts de instalação individuais de ferramentas
# AI e expõe funções de lote: install_all, uninstall_all, update_all, reinstall_all
# =============================================================================

import "@/utils/log"
import "@/utils/colors"
import "@/utils/tools"

# KARNEL_CACHE e PREFIX são definidos via env.sh
# Exportados aqui apenas como fallback para scripts que carregam all.sh diretamente
: "${KARNEL_CACHE:=$HOME/.cache/karnel}"
: "${PREFIX:=/data/data/com.termux/files/usr}"

# ---- Progress helpers (replicados do log.sh para consistência) ----

# ---- AI TOOLS REGISTRY ----
# Fonte única da verdade para todas as ferramentas AI.
# Cada registro contém:
#   id          = identificador único (usado em --flags, nomes de função)
#   name        = nome de exibição
#   binary      = nome(s) do(s) binário(s) para validação pós-instalação
#   install_fn  = nome da função install (gerado automaticamente)
#   uninstall_fn = nome da função uninstall (gerado automaticamente)
#   update_fn   = nome da função update (gerado automaticamente)

AI_TOOLS_REGISTRY=(
  "10router:10Router:10router"
  "qwen-code:Qwen Code:qwen"
  "gemini-cli:Gemini CLI:gemini"
  "claude-code:Claude Code:claude"
  "mistral-vibe:Mistral Vibe:vibe"
  "openclaude:OpenClaude:openclaude"
  "openclaw:OpenClaw:openclaw"
  "ollama:Ollama:ollama"
  "codex:Codex CLI:codex"
  "opencode:OpenCode:opencode"
  "mimocode:MiMo Code:mimo"
  "engram:Engram:engram"
  "codegraph:CodeGraph:codegraph"
  "pi:Pi Coding Agent:pi"
  "antigravity-cli:Antigravity CLI:agy"
  "minimax-cli:Minimax CLI:mmx"
  "gentle-ai:Gentle AI:gentle-ai"
  "gga:GGA:gga"
  "hermes-agent:Hermes Agent:hermes"
  "kimi-code:Kimi Code:kimi"
  "command-code:Command Code:command-code"
  "codebuff:Codebuff:codebuff"
  "freebuff:Freebuff:freebuff"
  "kilocode-cli:Kilo Code CLI:kilocode,kilo"
  "kiro:Kiro CLI:kiro,kiro-cli"
  "crush:Crush CLI:crush"
  "cline:Cline CLI:cline"
  "odysseus:Odysseus:odysseus"
  "kimchi-code:Kimchi CLI:kimchi"
  "omni-route:omniRoute:omni-route"
  "ctx7:Context7 Documentation Provider:ctx7"
  "openspec:OpenSpec SDD Framework:openspec"
  "supercode-cli:Supercode CLI:supercode"
  "puter:Puter CLI:puter"
  "keelcode:KeelCode:keelcode"
  "copilot-termux:Copilot-Termux:copilot"
  "qoder:Qoder:qodercli"
  "ampcode:AMP Code CLI:amp"
  "cursor-cli:Cursor CLI:cursor,cursor-agent"
  "oh-my-pi:Oh-My-Pi:omp"
  "goose:Goose CLI:goose"
  "droid:Factory Droid:droid"
  "cactus:Cactus:cactus"
  "cactus-needle:Cactus Needle:needle"
  "walkie:Walkie Agent:walkie"
  "hugging-face:Hugging Face:hf"
)

# Only tools with a documented, non-interactive version contract are executed.
declare -gA AI_TOOL_PROBES=(
  [claude-code]='claude --version'
  [qoder]='qodercli --version'
  [codebuff]='codebuff --version'
  [ampcode]='amp --version'
  [mimocode]='mimo --version'
  [goose]='goose --version'
  [codegraph]='codegraph --version'
  [crush]='crush --version'
)

# ---- IMPORTAR TODOS OS SCRIPTS INDIVIDUAIS ----
# Cada tool/***/install.sh define install_*, uninstall_*, update_*, reinstall_*
_import_all_ai_tools() {
  local tools_dir="$KARNEL_PATH/tools/ai"
  for entry in "$tools_dir"/*/install.sh; do
    if [[ -f "$entry" ]]; then
      source "$entry"
    fi
  done
}
_import_all_ai_tools
unset -f _import_all_ai_tools

# ---- HELPERS DE VALIDAÇÃO PÓS-INSTALAÇÃO ----

# Verifica se pelo menos um dos binários existe no PATH
_validate_tool_installed() {
  local binaries="$1"
  local tool_name="$2"
  local tool_id="${3:-}"
  IFS=',' read -ra bins <<< "$binaries"
  for bin in "${bins[@]}"; do
    if command -v "$bin" &>/dev/null; then
      # Verificação extra: se for um stub (shell script que só mostra erro), considera falha
      local bin_path
      bin_path=$(command -v "$bin")
      if karnel_is_stub_binary "$bin_path"; then
        log_warn "$tool_name: instalado como stub offline (instalação real indisponível)"
        return 2
      fi
      local probe="${AI_TOOL_PROBES[$tool_id]:-}"
      if [[ -n "$probe" ]]; then
        local probe_bin=${probe%% *}
        local probe_arg=${probe#* }
        if ! "$probe_bin" "$probe_arg" </dev/null >/dev/null 2>&1; then
          log_warn "$tool_name: non-interactive post-install probe failed"
          return 1
        fi
      fi
      return 0
    fi
  done
  return 1
}

# ---- FUNÇÕES DE LOTE ----

# Runs the Android compatibility layer over the binaries an AI tool puts on
# PATH. glibc-only binaries cannot be exec'd here - their PT_INTERP points at
# /lib/ld-linux-*.so.1, which Android does not have - until compat wraps them.
_ai_tool_compat_adapt() {
  local id="$1" entry entry_id name bins
  local -a bin_list=()
  declare -f compat_adapt_installed >/dev/null 2>&1 || return 0
  for entry in "${AI_TOOLS_REGISTRY[@]}"; do
    IFS=':' read -r entry_id name bins <<<"$entry"
    [[ "$entry_id" == "$id" ]] || continue
    IFS=',' read -ra bin_list <<<"$bins"
    for entry_id in "${bin_list[@]}"; do
      compat_adapt_installed "$entry_id" || true
    done
    break
  done
  return 0
}

_ai_tool_registered() {
  local wanted="$1"
  local entry id
  for entry in "${AI_TOOLS_REGISTRY[@]}"; do
    id="${entry%%:*}"
    [[ "$id" == "$wanted" ]] && return 0
  done
  return 1
}

# Resolve a user token (install flag, binary name, or display name,
# case-insensitive) to the canonical registry id. Echoes the id and
# returns 0 when a match is found, otherwise echoes the token unchanged
# and returns 1.
_ai_tool_resolve() {
  local token="$1" entry id name bins
  for entry in "${AI_TOOLS_REGISTRY[@]}"; do
    IFS=':' read -r id name bins <<< "$entry"
    [[ "$id" == "$token" ]] && { echo "$id"; return 0; }
    [[ "$name" == "$token" ]] && { echo "$id"; return 0; }
    [[ "${name,,}" == "${token,,}" ]] && { echo "$id"; return 0; }
    local IFS=',' b
    for b in $bins; do
      [[ "$b" == "$token" ]] && { echo "$id"; return 0; }
    done
  done
  echo "$token"
  return 1
}

_run_ai_tool_action() {
  local action="$1"
  local id="$2"

  # Accept the binary/command name (e.g. --agy) or display name as aliases
  # for the canonical install flag (e.g. --antigravity-cli).
  id="$(_ai_tool_resolve "$id")"

  local func_name="${action}_${id//-/_}"

  # A specific --<tool> was requested: skip nested interactive menus and
  # auto-select the recommended installation method.
  export KARNEL_NONINTERACTIVE=1

  _ai_tool_registered "$id" || return 127

  if [[ "$action" != "reinstall" ]]; then
    declare -f "$func_name" &>/dev/null || return 127
    local rc=0
    "$func_name" || rc=$?
    if (( rc == 0 || rc == 2 )) && [[ "$action" == "install" || "$action" == "update" ]]; then
      _ai_tool_compat_adapt "$id"
    fi
    return "$rc"
  fi

  if declare -f "$func_name" &>/dev/null; then
    local rc=0
    "$func_name" || rc=$?
    if (( rc == 0 )); then
      _ai_tool_compat_adapt "$id"
    fi
    return "$rc"
  fi

  local uninstall_fn="uninstall_${id//-/_}"
  local install_fn="install_${id//-/_}"
  declare -f "$uninstall_fn" &>/dev/null && declare -f "$install_fn" &>/dev/null || return 127

  "$uninstall_fn"
  local uninstall_rc=$?
  if [[ $uninstall_rc -ne 0 && $uninstall_rc -ne 2 ]]; then
    return "$uninstall_rc"
  fi
  "$install_fn"
}

_all_ai_tools_action() {
  local action="$1"        # install, uninstall, update, reinstall
  local action_label="$2"  # Instalando, Removendo, Atualizando, Reinstalando
  local total=${#AI_TOOLS_REGISTRY[@]}
  local current=0
  local success_count=0
  local failed_count=0
  local skipped_count=0

  progress_start "$total" "${action_label} ferramentas IA..."

  for entry in "${AI_TOOLS_REGISTRY[@]}"; do
    IFS=':' read -r id name binaries <<< "$entry"
    ((current++))

    _run_ai_tool_action "$action" "$id"
    local rc=$?

    case $rc in
        0)
          # Pós-validação apenas para install
          if [[ "$action" == "install" ]]; then
            _validate_tool_installed "$binaries" "$name" "$id"
            local validate_rc=$?
            if [[ $validate_rc -eq 0 ]]; then
              ((success_count++))
            elif [[ $validate_rc -eq 2 ]]; then
              # Stub instalado - conta como sucesso parcial
              ((success_count++))
            else
              log_warn "$name: binário não encontrado no PATH após instalação"
              ((failed_count++))
            fi
          else
            ((success_count++))
          fi
          ;;
        1)
          ((failed_count++))
          ;;
        2)
          ((skipped_count++))
          ;;
        *)
          log_warn "$name: ${action}_${id//-/_} returned status $rc"
          ((failed_count++))
          ;;
    esac

    progress_update "$current" "$total"
  done

  progress_done "$total"

  echo
  if [[ $success_count -gt 0 ]]; then
    log_success "$success_count ferramenta(s) ${action_label,,} com sucesso"
  fi
  if [[ $skipped_count -gt 0 ]]; then
    log_info "$skipped_count ferramenta(s) já estavam no estado desejado"
  fi
  if [[ $failed_count -gt 0 ]]; then
    log_warn "$failed_count ferramenta(s) falharam ao ${action_label,,}"
  fi
  echo

  return $failed_count
}

install_all_ai_tools() {
  log_info "Instalando todas as ferramentas AI..."
  _all_ai_tools_action "install" "Instalando"
}

uninstall_all_ai_tools() {
  log_info "Removendo todas as ferramentas AI..."
  _all_ai_tools_action "uninstall" "Removendo"
}

update_all_ai_tools() {
  log_info "Atualizando todas as ferramentas AI..."
  _all_ai_tools_action "update" "Atualizando"
}

reinstall_all_ai_tools() {
  log_info "Reinstalando todas as ferramentas AI..."
  _all_ai_tools_action "reinstall" "Reinstalando"
}
