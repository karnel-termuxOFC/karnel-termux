#!/usr/bin/env bash

_WPSCAN_BACKEND_FILE="${KARNEL_DATA:-$HOME/.local/share/karnel}/security/wpscan.backend"

_wpscan_backend() {
  if [[ -f "$_WPSCAN_BACKEND_FILE" ]]; then
    # A redirection-only command ("< file") reads nothing and prints nothing:
    # it only wires fd 0 for a null command. Read the recorded backend out loud.
    IFS= read -r _backend < "$_WPSCAN_BACKEND_FILE" && printf '%s\n' "$_backend"
  elif command -v dpkg &>/dev/null && dpkg -s wpscan &>/dev/null; then
    printf '%s\n' package
  elif command -v gem &>/dev/null && gem list -i wpscan &>/dev/null; then
    printf '%s\n' gem
  fi
}

_record_wpscan_backend() {
  mkdir -p "$(dirname "$_WPSCAN_BACKEND_FILE")" || return 1
  printf '%s\n' "$1" >"$_WPSCAN_BACKEND_FILE"
}

install_wpscan() {
  if command -v wpscan &>/dev/null; then
    log_info "wpscan já está instalado"
    return 2
  fi
  log_info "Instalando wpscan..."
  if pkg install -y wpscan 2>/dev/null || apt install -y wpscan 2>/dev/null; then
    _record_wpscan_backend package || return 1
    log_success "wpscan instalado"
    return 0
  fi
  if gem install wpscan 2>/dev/null; then
    _record_wpscan_backend gem || return 1
    log_success "wpscan instalado"
    return 0
  fi
  log_error "Falha ao instalar wpscan"
  return 1
}

uninstall_wpscan() {
  local backend
  [[ -f "$_WPSCAN_BACKEND_FILE" ]] || { log_info "wpscan não é gerenciado pelo Karnel"; return 2; }
  backend=$(_wpscan_backend)
  log_info "Removendo wpscan..."
  case "$backend" in
    package) pkg uninstall -y wpscan 2>/dev/null || apt remove -y wpscan 2>/dev/null || return 1 ;;
    gem) gem uninstall wpscan 2>/dev/null || return 1 ;;
    *) log_error "Backend desconhecido para wpscan"; return 1 ;;
  esac
  rm -f "$_WPSCAN_BACKEND_FILE"
  log_success "wpscan removido"
}

update_wpscan() {
  local backend rc
  backend=$(_wpscan_backend)
  log_info "Atualizando wpscan..."
  case "$backend" in
    package) pkg install -y wpscan 2>/dev/null || apt install -y wpscan 2>/dev/null ;;
    gem) gem update wpscan 2>/dev/null ;;
    *) log_error "Não foi possível determinar o backend do wpscan"; return 1 ;;
  esac
  rc=$?
  if (( rc == 0 )); then
    log_success "wpscan atualizado"
    return 0
  fi
  log_error "Falha ao atualizar wpscan"
  return "$rc"
}

reinstall_wpscan() {
  uninstall_wpscan || [[ $? -eq 2 ]] || return 1

  install_wpscan
}
