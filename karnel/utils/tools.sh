#!/usr/bin/env bash

# Module-level install markers. `karnel stats` reads them to report which
# modules the user has installed; they are written only after a full-module
# lifecycle action succeeds.
karnel_mark_module_installed() {
  [[ -n "${KARNEL_DATA:-}" ]] || return 0
  local dir="$KARNEL_DATA/$1"
  [[ -d "$dir" && ! -L "$dir" ]] || mkdir -p "$dir" 2>/dev/null || return 0
  (umask 077; : >"$dir/.installed") 2>/dev/null || true
  chmod 600 "$dir/.installed" 2>/dev/null || true
}

# True when the file is an offline placeholder ("stub") written by Karnel when
# a real install is unavailable: a tiny shell script that only prints an error
# and exits. Scanning arbitrary installed binaries for words like "offline"
# false-positives on real CLIs (supercode ships an 11 MB JS bundle containing
# "offline"; python-config carries -Wunreachable-code), so a stub must match
# every property of a Karnel stub: small, shell interpreter, stub message and
# an `exit 1`.
karnel_is_stub_binary() {
  local file="$1" size first interp
  [[ -f "$file" && -x "$file" ]] || return 1
  size="$(wc -c <"$file" 2>/dev/null)" || return 1
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  ((size > 0 && size <= 2048)) || return 1
  IFS= read -r first <"$file" || [[ -n "$first" ]] || return 1
  [[ "$first" == '#!'* ]] || return 1
  interp="${first#\#!}"
  interp="${interp# }"
  interp="${interp%% *}"
  # `#!/usr/bin/env bash` resolves the interpreter through env.
  if [[ "$interp" == */env ]]; then
    interp="${first#\#!}"
    interp="${interp#*env }"
    interp="${interp%% *}"
  fi
  interp="${interp##*/}"
  case "$interp" in
  sh | bash | dash | zsh | ksh | ash) ;;
  *) return 1 ;;
  esac
  grep -qiE 'offline|unreachable|not[[:space:]._-]*available|indispon[ií]vel|inacess[ií]vel' "$file" || return 1
  grep -qE '(^|[^[:alnum:]_])exit[[:space:]]+1([^[:alnum:]_]|$)' "$file" || return 1
  return 0
}

karnel_mark_module_not_installed() {
  [[ -n "${KARNEL_DATA:-}" ]] || return 0
  rm -f "$KARNEL_DATA/$1/.installed" 2>/dev/null || true
}

# Tools that keep their own granular ledger (per-binary, per-workspace or
# per-package markers) must stay out of the central ledger. A second,
# tool-wide marker would let `karnel uninstall` claim installs Karnel never
# tracked and would defeat their per-file checks.
_tool_has_self_managed_ownership() {
  case "$1/$2" in
    # AI tools are dispatched through _run_ai_tool_action and manage their own
    # data directories; deploy CLIs record which files they installed.
    ai/* | deploy/*)
      return 0
      ;;
    lang/bun | npm/turbopack | editor/nvchad | utils/herdr | utils/superfile | utils/zork)
      return 0
      ;;
    security/amass | security/burpsuite | security/dnsrecon | security/enum4linux | security/ffuf | security/gobuster | security/masscan | security/metasploit | security/nikto | security/sqlmap | security/subfinder | security/theharvester | security/whatweb | security/zap)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Every other tool shipped under tools/<module>/<tool>/ is tracked by the
# central ownership ledger, so uninstall/update refuse to touch installs that
# Karnel never recorded. Modules are matched by name (not by probing the
# filesystem) so the lifecycle helpers stay testable without a checkout and so
# a newly added tool is covered the moment it lands in a module registry.
_tool_uses_central_ownership() {
  _tool_has_self_managed_ownership "$1" "$2" && return 1

  case "$1" in
    auto | db | dev | editor | games | lang | network | npm | osint | security | shell | ui | utils)
      [[ -n "$2" ]] || return 1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
_tool_ownership_marker() {
  if [[ -z "${KARNEL_DATA:-}" ]]; then
    # tests/ and partial sources may load this file without utils/log.sh;
    # report the problem ourselves instead of dying on a missing function.
    if declare -F log_error >/dev/null 2>&1; then
      log_error "KARNEL_DATA is required for tool ownership state"
    else
      printf 'KARNEL_DATA is required for tool ownership state\n' >&2
    fi
    return 1
  fi
  printf '%s/ownership/%s/%s\n' "$KARNEL_DATA" "$1" "$2"
}

_mark_tool_owned() {
  local marker
  marker=$(_tool_ownership_marker "$1" "$2") || return 1
  mkdir -p "${marker%/*}" || return 1
  (umask 077; : >"$marker") || return 1
  chmod 600 "$marker"
}

_run_tool_lifecycle_action() {
  local module="$1"
  local action="$2"
  local tool="$3"
  local normalized="${tool//-/_}"
  local handler="${action}_${normalized}"
  local marker=""
  local protected=0
  local rc

  if _tool_uses_central_ownership "$module" "$tool"; then
    protected=1
    marker=$(_tool_ownership_marker "$module" "$tool") || return 1
  fi

  if (( protected )) && [[ "$action" != "install" && ! -f "$marker" ]]; then
    log_warn "Preserving unowned or legacy $module tool: $tool"
    return 2
  fi

  if [[ "$action" == "reinstall" ]]; then
    local uninstall_handler="uninstall_${normalized}"
    local install_handler="install_${normalized}"
    if ! declare -f "$uninstall_handler" &>/dev/null || ! declare -f "$install_handler" &>/dev/null; then
      log_error "Missing reinstall handlers for $tool"
      return 1
    fi
    "$uninstall_handler"
    rc=$?
    (( rc == 0 || rc == 2 )) || return "$rc"
    "$install_handler"
    rc=$?
    if (( rc == 0 && protected )); then
      _mark_tool_owned "$module" "$tool" || return 1
    fi
    if (( rc == 0 )); then
      _tool_compat_adapt "$tool"
    fi
    return "$rc"
  fi

  if ! declare -f "$handler" &>/dev/null; then
    log_error "Missing $action handler for $tool: $handler"
    return 1
  fi
  "$handler"
  rc=$?
  if (( rc == 0 && protected )); then
    if [[ "$action" == "install" ]]; then
      _mark_tool_owned "$module" "$tool" || return 1
    elif [[ "$action" == "uninstall" ]]; then
      rm -f "$marker" || return 1
    fi
  fi
  if (( rc == 0 )) && [[ "$action" == "install" || "$action" == "update" ]]; then
    _tool_compat_adapt "$tool"
  fi
  return "$rc"
}

# Runs the Android compatibility layer over a tool that was just installed or
# updated, when the layer has been imported. glibc-only binaries cannot be
# exec'd on Android (their PT_INTERP does not exist) until they are wrapped.
_tool_compat_adapt() {
  declare -f compat_adapt_installed >/dev/null 2>&1 || return 0
  compat_adapt_installed "$1" || true
  return 0
}

_register_safe_reinstall_handlers() {
  local module="$1"
  shift
  local tool normalized
  for tool in "$@"; do
    normalized="${tool//-/_}"
    # Reject any tool/module name containing shell metacharacters before eval,
    # otherwise a crafted tool directory name could inject code into the
    # generated reinstall handler.
    case "$module/$tool/$normalized" in
      *[!A-Za-z0-9_/-]*) log_error "Refusing to register unsafe tool name: $module/$tool"; continue ;;
    esac
    eval "reinstall_${normalized}() { _run_tool_lifecycle_action '$module' reinstall '$tool'; }"
  done
}

# Modules without a per-tool registry (tools/<module>/all.sh) cannot go through
# the generic batch path: bootstrap would fail on the missing file. Route them
# explicitly so the user gets an actionable message instead of an import error.
_route_registryless_tools() {
  local module="$1"
  local action="$2"
  shift 2
  local -a tools=("$@")
  local tool urc rc=0

  case "$module" in
  plugin)
    import "@/cli/commands/plugin"
    for tool in "${tools[@]}"; do
      case "$action" in
      install)
        install_plugin "$tool" || rc=1
        ;;
      update)
        _plugin_update_main "$tool" || rc=1
        ;;
      uninstall)
        uninstall_plugin "$tool" || rc=1
        ;;
      reinstall)
        uninstall_plugin "$tool"
        urc=$?
        (( urc == 0 || urc == 2 )) || { rc=1; continue; }
        install_plugin "$tool" || rc=1
        ;;
      esac
    done
    ;;
  voice)
    log_error "voice has no individual tools; run 'karnel $action voice'"
    rc=1
    ;;
  supabase)
    log_error "supabase has no individual tools; run 'karnel $action deploy --supabase'"
    rc=1
    ;;
  *)
    log_error "Unknown $action target: $module"
    echo "Run 'karnel $action' to see available targets"
    rc=1
    ;;
  esac
  return "$rc"
}

_batch_tool_action() {
  local module="$1"
  local action="$2"
  shift 2
  local -a tools=("$@")
  local success_count=0
  local failed_count=0
  local skipped_count=0

  # An explicit uninstall should actually remove owned data, even when no TTY
  # is attached (piped/non-interactive). Ownership is still guarded upstream.
  [[ "$action" == "uninstall" ]] && export KARNEL_REMOVE_DEFAULT=y

  # Without a registry the import would abort the whole command. Only route to
  # the registryless handler when the requested tools have no lifecycle
  # functions at all — a module whose handlers are already loaded (tests, or a
  # tool set defined by an earlier import) must keep the normal per-tool flow.
  if [[ ! -f "${KARNEL_PATH:-}/tools/$module/all.sh" ]]; then
    local handler_defined=0
    local candidate
    for candidate in "${tools[@]}"; do
      if declare -f "${action}_${candidate//-/_}" &>/dev/null; then
        handler_defined=1
        break
      fi
    done
    if (( ! handler_defined )); then
      _route_registryless_tools "$module" "$action" "${tools[@]}"
      return $?
    fi
  else
    import "@/tools/$module/all"
  fi

  for tool in "${tools[@]}"; do
    local normalized="${tool//-/_}"
    if [[ "$module" == "ai" ]] && declare -f _run_ai_tool_action &>/dev/null; then
      _run_ai_tool_action "$action" "$tool"
      case $? in
        0) ((success_count++));;
        2) ((skipped_count++));;
        *) ((failed_count++));;
      esac
    else
      if [[ "$action" == "reinstall" ]]; then
        if ! declare -f "uninstall_${normalized}" &>/dev/null || ! declare -f "install_${normalized}" &>/dev/null; then
          log_warn "Unknown $module tool: $tool"
          ((failed_count++))
          continue
        fi
      elif ! declare -f "${action}_${normalized}" &>/dev/null; then
        log_warn "Unknown $module tool: $tool"
        ((failed_count++))
        continue
      fi
      _run_tool_lifecycle_action "$module" "$action" "$tool"
      case $? in
        0) ((success_count++));;
        2) ((skipped_count++));;
        *) ((failed_count++));;
      esac
    fi
  done

  echo
  if [[ $success_count -gt 0 ]]; then
    log_success "$success_count tool(s) ${action}ed"
  fi
  if [[ $failed_count -gt 0 ]]; then
    log_warn "$failed_count tool(s) failed to ${action}"
  fi
  if [[ $skipped_count -gt 0 ]]; then
    log_info "$skipped_count tool(s) already in the requested state"
  fi

  (( failed_count == 0 ))
}
