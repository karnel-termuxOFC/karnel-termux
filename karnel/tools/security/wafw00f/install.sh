#!/usr/bin/env bash

_WAFW00F_BACKEND_FILE="${KARNEL_DATA:-$HOME/.local/share/karnel}/security/wafw00f.backend"

_wafw00f_backend() {
  if [[ -f "$_WAFW00F_BACKEND_FILE" ]]; then
    # A redirection-only command ("< file") reads nothing and prints nothing:
    # it only wires fd 0 for a null command. Read the recorded backend out loud.
    IFS= read -r _backend < "$_WAFW00F_BACKEND_FILE" && printf '%s\n' "$_backend"
  elif command -v dpkg &>/dev/null && dpkg -s wafw00f &>/dev/null; then
    printf '%s\n' package
  elif command -v pip &>/dev/null && pip show wafw00f &>/dev/null; then
    printf '%s\n' pip
  fi
}

_record_wafw00f_backend() {
  mkdir -p "$(dirname "$_WAFW00F_BACKEND_FILE")" || return 1
  printf '%s\n' "$1" >"$_WAFW00F_BACKEND_FILE"
}

install_wafw00f() {
  if command -v wafw00f &>/dev/null; then
    log_info "wafw00f já está instalado"
    return 2
  fi
  log_info "Instalando wafw00f..."
  if pkg install -y wafw00f 2>/dev/null || apt install -y wafw00f 2>/dev/null; then
    _record_wafw00f_backend package || return 1
    log_success "wafw00f instalado"
    return 0
  fi
  if pip install wafw00f 2>/dev/null; then
    _record_wafw00f_backend pip || return 1
    log_success "wafw00f instalado"
    return 0
  fi
  log_error "Falha ao instalar wafw00f"
  return 1
}

uninstall_wafw00f() {
  local backend
  [[ -f "$_WAFW00F_BACKEND_FILE" ]] || { log_info "wafw00f não é gerenciado pelo Karnel"; return 2; }
  backend=$(_wafw00f_backend)
  log_info "Removendo wafw00f..."
  case "$backend" in
    package) pkg uninstall -y wafw00f 2>/dev/null || apt remove -y wafw00f 2>/dev/null || return 1 ;;
    pip) pip uninstall -y wafw00f 2>/dev/null || return 1 ;;
    *) log_error "Backend desconhecido para wafw00f"; return 1 ;;
  esac
  rm -f "$_WAFW00F_BACKEND_FILE"
  log_success "wafw00f removido"
}

update_wafw00f() {
  local backend rc
  backend=$(_wafw00f_backend)
  log_info "Atualizando wafw00f..."
  case "$backend" in
    package) pkg install -y wafw00f 2>/dev/null || apt install -y wafw00f 2>/dev/null ;;
    pip) pip install --upgrade wafw00f 2>/dev/null ;;
    *) log_error "Não foi possível determinar o backend do wafw00f"; return 1 ;;
  esac
  rc=$?
  if (( rc == 0 )); then
    log_success "wafw00f atualizado"
    return 0
  fi
  log_error "Falha ao atualizar wafw00f"
  return "$rc"
}

reinstall_wafw00f() {
  uninstall_wafw00f || [[ $? -eq 2 ]] || return 1

  install_wafw00f
}
