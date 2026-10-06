#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/compat"

doctor_main() {
  local subcommand="${1:-termux}"
  case "$subcommand" in
    help|--help|-h)
      doctor_help
      ;;
    termux)
      shift
      doctor_termux "$@"
      ;;
    code)
      shift
      doctor_code "$@"
      ;;
    robin)
      shift
      import "@/cli/commands/robin"
      _robin_print_disclaimer
      _robin_doctor "$@"
      ;;
    --quick|-q)
      log_warn "Deprecated: use ${D_CYAN}karnel doctor termux --quick${NC}"
      doctor_termux "$@"
      ;;
    --fix|-f)
      log_warn "Deprecated: use ${D_CYAN}karnel doctor termux --fix${NC}"
      shift
      doctor_termux "--fix" "$@"
      ;;
    *)
      log_error "Unknown doctor subcommand: $subcommand"
      echo
      doctor_help
      return 1
      ;;
  esac
}

doctor_help() {
  echo
  box "◈ KARNEL DOCTOR ◈"
  echo
  log_info "Usage: karnel doctor <subcommand> [options]"
  echo
  log_info "When no subcommand is given, runs termux diagnostics."
  echo
  separator_section "Subcommands"
  echo
  printf "    ${D_CYAN}%-16s${NC} %s\n" "termux" "Diagnose Termux environment (full system check)"
  printf "    ${D_CYAN}%-16s${NC} %s\n" "code" "Analyze project code structure and tools"
  printf "    ${D_CYAN}%-16s${NC} %s\n" "robin" "Diagnose Robin, Tor, dependencies, and local UI"
  echo
  separator_section "Termux Options"
  echo
  printf "    ${D_CYAN}%-16s${NC} %s\n" "--quick, -q" "Skip slow checks"
  printf "    ${D_CYAN}%-16s${NC} %s\n" "--fix, -f" "Auto-apply all fixes without prompt"
  echo
  log_info "Examples:"
  list_item "${D_CYAN}karnel doctor${NC} — Termux diagnostics (default)"
  list_item "${D_CYAN}karnel doctor termux --quick${NC} — Quick diagnostics"
  list_item "${D_CYAN}karnel doctor code${NC} — Analyze current project"
  list_item "${D_CYAN}karnel doctor robin${NC} — Diagnose Robin locally"
  list_item "${D_CYAN}karnel doctor termux --fix${NC} — Diagnose + auto-fix"
  echo
}

doctor_termux() {
  local QUICK_MODE=false
  local FIX_MODE=false
  for arg in "$@"; do
    case "$arg" in
      --quick|-q) QUICK_MODE=true ;;
      --fix|-f) FIX_MODE=true ;;
      --help|-h) doctor_help; return ;;
      --*) log_error "Unknown option: $arg"; doctor_help; return 1 ;;
    esac
  done

  echo
  box "◈ KARNEL DOCTOR — TERMUX ◈"
  echo
  if $QUICK_MODE; then
    log_info "Quick mode — running essential system and package checks only"
  fi
  log_info "Diagnosing your Termux and Karnel environment..."
  echo

  local warnings=0
  local errors=0
  local fixed=0
  local -a fix_commands=()
  local -a fix_descriptions=()
  local -a fix_callbacks=()

  # ===== 1. SYSTEM INFO =====
  local arch
  arch=$(uname -m)

  local android_ver
  android_ver=$(getprop ro.build.version.release 2>/dev/null)
  android_ver="${android_ver:-Unknown}"

  local termux_ver="${TERMUX_VERSION:-}"
  if [[ -z "$termux_ver" ]] && command -v termux-info &>/dev/null; then
    termux_ver=$(timeout 5 termux-info 2>/dev/null | grep -i "termux_version" | head -n1 | cut -d'=' -f2 || true)
  fi
  if [[ -z "$termux_ver" ]]; then
    termux_ver=$(dpkg -s termux-tools 2>/dev/null | grep -i version | awk '{print $2}' 2>/dev/null || echo "Unknown")
  fi

  log_success "Android Version: $android_ver"
  log_success "Termux Version: $termux_ver"
  log_success "CPU Architecture: $arch"

  # ===== 2. DISK SPACE & RAM =====
  echo
  separator_section "System Resources"
  echo

  local free_space
  free_space=$(df -h "$HOME" | awk 'NR==2 {print $4}')
  log_success "Available disk space: $free_space"

  local ram_total="Unknown"
  local ram_free="Unknown"
  if [[ -f /proc/meminfo ]]; then
    local total_kb free_kb
    total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_total="$((total_kb / 1024)) MB"
    free_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    ram_free="$((free_kb / 1024)) MB"
    log_success "RAM: Total: $ram_total | Available: $ram_free"

    # Warn if low memory
    local free_mb=$((free_kb / 1024))
    if (( free_mb < 200 )); then
      log_warn "Low available memory (${ram_free}). Some tools may fail."
      ((warnings++))
    fi
  else
    log_warn "Could not read RAM details"
    ((warnings++))
  fi

  # ===== 3. STORAGE & PERMISSIONS =====
  echo
  separator_section "Storage & Permissions"
  echo

  local storage_status="Accessible"
  if ls /sdcard &>/dev/null || [ -d "$HOME/storage" ]; then
    log_success "Shared storage is accessible"
  else
    log_warn "Shared storage is not linked"
    storage_status="Not Linked"
    ((warnings++))
    fix_commands+=("termux-setup-storage")
    fix_descriptions+=("Link shared storage for file access")
    fix_callbacks+=("_fix_storage")
  fi

  if [ -w "$KARNEL_PATH" ]; then
    log_success "Write permission in Karnel path: $KARNEL_PATH"
  else
    log_error "No write permission in Karnel path!"
    ((errors++))
  fi

  local dirs=("$KARNEL_CONFIG" "$KARNEL_CACHE" "$KARNEL_DATA")
  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
      log_success "Directory OK: $(basename "$dir")"
    else
      log_warn "Directory missing or read-only: $(basename "$dir")"
      ((warnings++))
      fix_commands+=("mkdir -p -m 700 \"$dir\" && chmod 700 \"$dir\"")
      fix_descriptions+=("Recreate directory: $(basename "$dir")")
      fix_callbacks+=("_fix_mkdir")
    fi
  done

  # ===== 4. LANGUAGES & CRITICAL TOOLS =====
  echo
  separator_section "Languages & Critical Tools"
  echo

  local -a critical_deps=("git" "rg" "jq" "curl" "tar" "node" "python" "rustc" "go" "clang" "make")
  for dep in "${critical_deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
      local version=""
      case "$dep" in
        git) version=$(git --version | awk '{print $3}') ;;
        node) version=$(node --version) ;;
        python) version=$( (python3 --version 2>/dev/null || python --version 2>/dev/null) | awk '{print $2}' ) ;;
        rustc) version=$(rustc --version | awk '{print $2}') ;;
        go) version=$(go version | awk '{print $3}') ;;
        clang) version=$(clang --version | head -1 | awk '{print $3}') ;;
        *) version="installed" ;;
      esac
      log_success "$dep: $version"
    else
      log_warn "$dep is not installed"
      ((warnings++))
      local pkg_to_install="$dep"
      [[ "$dep" == "rg" ]] && pkg_to_install="ripgrep"
      [[ "$dep" == "rustc" ]] && pkg_to_install="rust"
      [[ "$dep" == "go" ]] && pkg_to_install="golang"
      [[ "$dep" == "python" ]] && pkg_to_install="python"
      fix_commands+=("pkg install -y $pkg_to_install")
      fix_descriptions+=("Install missing: $pkg_to_install")
      fix_callbacks+=("_fix_pkg_install")
    fi
  done

  # ===== 5. PACKAGE MANAGER HEALTH =====
  echo
  separator_section "Package Manager & System Health"
  echo

  local dpkg_audit_out
  dpkg_audit_out=$(dpkg --audit 2>&1)
  local dpkg_rc=$?
  if [[ $dpkg_rc -eq 0 ]] && [[ -z "$dpkg_audit_out" ]]; then
    log_success "dpkg package manager is healthy"
  else
    log_error "dpkg has interrupted installations!"
    ((errors++))
    fix_commands+=("dpkg --configure -a && apt-get -f install -y")
    fix_descriptions+=("Fix broken dpkg/apt state")
    fix_callbacks+=("_fix_dpkg")
  fi

  # Check for held packages
  local held_pkgs
  held_pkgs=$(dpkg --get-selections 2>/dev/null | grep -c "hold" || true)
  if (( held_pkgs > 0 )); then
    log_warn "$held_pkgs package(s) are held back"
    ((warnings++))
  fi

  # Check apt sources
  if [[ -f "$PREFIX/etc/apt/sources.list" ]]; then
    local source_lines
    source_lines=$(wc -l < "$PREFIX/etc/apt/sources.list")
    if (( source_lines == 0 )); then
      log_error "APT sources list is empty!"
      ((errors++))
      fix_commands+=("pkg update -y")
      fix_descriptions+=("Refresh APT sources")
      fix_callbacks+=("_fix_apt_update")
    else
      log_success "APT sources configured ($source_lines entries)"
    fi
  fi

  # Keyring integrity check (Termux-fixer inspired)
  local keyring_dir="$PREFIX/etc/apt/trusted.gpg.d"
  if [[ -d "$keyring_dir" ]]; then
    local key_count
    key_count=$(find "$keyring_dir" -maxdepth 1 -type f \( -name '*.gpg' -o -name '*.asc' \) -print 2>/dev/null | wc -l)
    if (( key_count == 0 )); then
      log_warn "No APT keyring files found in $keyring_dir"
      ((warnings++))
      fix_commands+=("pkg update -y && pkg install -y termux-keyring")
      fix_descriptions+=("Reinstall termux-keyring")
      fix_callbacks+=("_fix_keyring")
    else
      log_success "APT keyring: $key_count key file(s) present"
    fi
  fi

  # System clock sanity check (HTTPS cert validation)
  if command -v date &>/dev/null; then
    local current_year
    current_year=$(date +%Y 2>/dev/null)
    if (( current_year < 2024 )); then
      log_error "System clock is incorrect (year: $current_year) — HTTPS/TLS certs will fail!"
      ((errors++))
    else
      log_success "System clock: $current_year"
    fi
  fi

  # APT cache health check
  local apt_cache_dir="$PREFIX/var/apt/lists"
  if [[ -d "$apt_cache_dir" ]]; then
    local cache_size
    cache_size=$(du -sh "$apt_cache_dir" 2>/dev/null | awk '{print $1}')
    local cache_files
    cache_files=$(find "$apt_cache_dir" -type f 2>/dev/null | wc -l)
    if (( cache_files > 500 )); then
      log_warn "APT lists cache is large: $cache_size ($cache_files files)"
      ((warnings++))
      [[ -n "$apt_cache_dir" ]] && fix_commands+=("rm -rf ${apt_cache_dir:?}/* && pkg update -y")
      fix_descriptions+=("Reset APT lists cache (fixes Hash Sum mismatch)")
      fix_callbacks+=("_fix_apt_cache")
    else
      log_success "APT cache: $cache_size ($cache_files files)"
    fi
  fi

  if $QUICK_MODE; then
    echo
    log_info "Quick mode: skipping extended runtime, AI, shell, process, I/O, and network checks"
    echo
  else

  # ===== 6. NODE.JS / NPM =====
  echo
  separator_section "Node.js & NPM"
  echo

  if command -v node &>/dev/null; then
    local node_ver
    node_ver=$(node --version)
    log_success "Node.js: $node_ver"

    if command -v npm &>/dev/null; then
      local npm_ver
      npm_ver=$(npm --version)
      log_success "NPM: $npm_ver"

      # Check npm global prefix permissions
      local npm_prefix
      npm_prefix=$(npm config get prefix 2>/dev/null)
      if [[ -n "$npm_prefix" ]] && [[ -d "$npm_prefix" ]]; then
        if [[ -w "$npm_prefix" ]]; then
          log_success "NPM global directory is writable"
        else
          log_warn "NPM global directory is not writable: $npm_prefix"
          ((warnings++))
          fix_commands+=("mkdir -p \"\$HOME/.npm-global\" && npm config set prefix \"\$HOME/.npm-global\"")
          fix_descriptions+=("Fix NPM global directory permissions")
          fix_callbacks+=("_fix_npm_prefix")
        fi
      fi

      # Check for npm cache bloat
      local npm_cache_size
      npm_cache_size=$(timeout 15 du -sh "$(npm config get cache 2>/dev/null)" 2>/dev/null | awk '{print $1}')
      if [[ -n "$npm_cache_size" ]]; then
        log_info "NPM cache size: $npm_cache_size"
      fi
    else
      log_warn "NPM is not installed"
      ((warnings++))
      fix_commands+=("pkg install -y nodejs-lts")
      fix_descriptions+=("Install Node.js with NPM")
      fix_callbacks+=("_fix_pkg_install")
    fi
  else
    log_warn "Node.js is not installed"
    ((warnings++))
    fix_commands+=("pkg install -y nodejs-lts")
    fix_descriptions+=("Install Node.js LTS")
    fix_callbacks+=("_fix_pkg_install")
  fi

  # ===== 7. PYTHON =====
  echo
  separator_section "Python Environment"
  echo

  local py_cmd=""
  for py in python3.12 python3.11 python3.10 python3.9 python3 python; do
    if command -v "$py" &>/dev/null; then
      py_cmd="$py"
      break
    fi
  done

  if [[ -n "$py_cmd" ]]; then
    local py_ver
    py_ver=$("$py_cmd" --version 2>&1 | awk '{print $2}')
    log_success "Python: $py_cmd ($py_ver)"

    # Check pip
    if "$py_cmd" -m pip --version &>/dev/null; then
      local pip_ver
      pip_ver=$("$py_cmd" -m pip --version | awk '{print $2}')
      log_success "Pip: $pip_ver"
    else
      log_warn "Pip is not installed for $py_cmd"
      ((warnings++))
      fix_commands+=("$py_cmd -m ensurepip && $py_cmd -m pip install --upgrade pip")
      fix_descriptions+=("Install/upgrade pip for $py_cmd")
      fix_callbacks+=("_fix_pip")
    fi

    # Check venv module
    if "$py_cmd" -m venv --help &>/dev/null; then
      log_success "Python venv module available"
    else
      log_warn "Python venv module not available"
      ((warnings++))
      local venv_pkg="python-venv"
      [[ "$py_cmd" == "python3.11" ]] && venv_pkg="python3.11-venv"
      [[ "$py_cmd" == "python3.10" ]] && venv_pkg="python3.10-venv"
      fix_commands+=("pkg install -y $venv_pkg")
      fix_descriptions+=("Install venv module for $py_cmd")
      fix_callbacks+=("_fix_pkg_install")
    fi
  else
    log_warn "Python is not installed"
    ((warnings++))
    fix_commands+=("pkg install -y python")
    fix_descriptions+=("Install Python")
    fix_callbacks+=("_fix_pkg_install")
  fi

  # ===== 8. POSTGRESQL =====
  echo
  separator_section "PostgreSQL Database"
  echo

  local pg_installed=false
  if command -v pg_ctl &>/dev/null; then
    pg_installed=true
    local pg_ver
    pg_ver=$(postgres --version 2>/dev/null | awk '{print $3}')
    log_success "PostgreSQL installed: $pg_ver"

    # Check if data directory exists
    local pg_data_found=false
    local pg_data_dirs=(
      "$PREFIX/var/lib/postgresql/data"
      "$PREFIX/var/lib/postgresql"
      "$HOME/.termux/postgresql/data"
      "$HOME/.termux/postgresql"
    )
    for dir in "${pg_data_dirs[@]}"; do
      if [[ -d "$dir" ]] && [[ -f "$dir/PG_VERSION" ]]; then
        pg_data_found=true
        log_success "Data directory found: $dir"
        break
      fi
    done

    if [[ "$pg_data_found" == "false" ]]; then
      log_warn "PostgreSQL not initialized (no data directory)"
      ((warnings++))
      fix_commands+=("karnel pg init && karnel pg start")
      fix_descriptions+=("Initialize and start PostgreSQL")
      fix_callbacks+=("_fix_pg_init")
    else
      # Check if running
      if pg_ctl -D "$dir" status &>/dev/null; then
        log_success "PostgreSQL: RUNNING"
      else
        log_warn "PostgreSQL: STOPPED"
        ((warnings++))
        fix_commands+=("karnel pg start")
        fix_descriptions+=("Start PostgreSQL server")
        fix_callbacks+=("_fix_pg_start")
      fi
    fi
  else
    log_warn "PostgreSQL is not installed"
    ((warnings++))
    fix_commands+=("karnel install db --postgresql")
    fix_descriptions+=("Install PostgreSQL")
    fix_callbacks+=("_fix_pg_install")
  fi

  # ===== 9. PYTHON COMPATIBILITY CHECKS =====
  echo
  separator_section "Python Compatibility (Termux patches)"
  echo

  # psutil Android check
  if python3 -c "import psutil; print(psutil.__version__)" &>/dev/null; then
    log_success "psutil: $(python3 -c 'import psutil; print(psutil.__version__)') — Android patch OK"
  else
    log_warn "psutil not installed — needed by hermes-agent and other AI tools"
    ((warnings++))
    fix_commands+=("pip install psutil==7.2.2")
    fix_descriptions+=("Install psutil for Python process monitoring")
    fix_callbacks+=("_fix_psutil")
  fi

  # Python version constraint check (pyproject.toml files)
  local constraint_issues=0
  while IFS= read -r -d '' pyproject; do
    local require_py
    require_py=$(grep -E 'requires-python\s*=' "$pyproject" 2>/dev/null | grep -oP '>=3\.\d+,<3\.\d+')
    if [[ -n "$require_py" ]]; then
      local max_ver
      max_ver=$(echo "$require_py" | grep -oP '<3\.\K\d+')
      if [[ -n "$max_ver" ]] && (( max_ver <= 14 )); then
        log_warn "Constraint in $(basename "$(dirname "$pyproject")"): $require_py may block Python 3.14"
        ((constraint_issues++))
      fi
    fi
  done < <(timeout 10 find "$HOME/.hermes" "$HOME/karnel" -name "pyproject.toml" -maxdepth 3 -print0 2>/dev/null || true)
  if (( constraint_issues == 0 )); then
    log_success "No Python version constraints blocking 3.14"
  fi

  # C extension build capability
  local python_include_output
  local -a python_include_flags=()
  python_include_output=$(python3-config --includes 2>/dev/null || true)
  read -r -a python_include_flags <<< "$python_include_output"
  if [[ ${#python_include_flags[@]} -gt 0 ]] && \
     clang "${python_include_flags[@]}" -shared -fPIC -o /dev/null -x c - <<<'#include <Python.h>' &>/dev/null; then
    log_success "C extensions can be compiled (Python.h + clang OK)"
  else
    log_warn "C extension build may fail — clang or Python headers issue"
    ((warnings++))
    fix_commands+=("pkg install -y clang python-dev")
    fix_descriptions+=("Install C build dependencies for Python extensions")
    fix_callbacks+=("_fix_pkg_install")
  fi

  # uv availability (used by hermes-agent installer)
  if command -v uv &>/dev/null; then
    log_success "uv package manager: available"
  else
    log_info "uv not installed (used by hermes-agent, optional)"
  fi

  # pip check — detect broken dependencies
  local pip_check_output pip_check_rc
  pip_check_output=$(timeout 15 pip check 2>&1) && pip_check_rc=0 || pip_check_rc=$?
  local broken_lines
  broken_lines=$(echo "$pip_check_output" | grep -i "broken\|missing\|conflict\|incompatible" || true)
  if (( pip_check_rc == 0 )) || [[ -z "$broken_lines" ]]; then
    log_success "pip dependencies: consistent"
  else
    log_warn "pip dependency issues detected"
    echo "$pip_check_output" | while IFS= read -r line; do
      list_item "$line"
    done
    ((warnings++))
    local broken_pkgs
    broken_pkgs=$(echo "$broken_lines" | grep -oP '^\S+' | head -3 | tr '\n' ' ')
    if [[ -n "$broken_pkgs" ]]; then
      fix_commands+=("pip install --upgrade --force-reinstall $broken_pkgs")
      fix_descriptions+=("Fix pip dependency conflicts: $broken_pkgs")
      fix_callbacks+=("_fix_pip_check")
    fi
  fi

  # ===== 10. KARNEL FRAMEWORK =====
  echo
  separator_section "Karnel Framework"
  echo

  # Check Karnel version
  local karnel_ver="unknown"
  if [[ -n "${KARNEL_VERSION:-}" ]]; then
    karnel_ver="$KARNEL_VERSION"
  fi
  log_success "Karnel version: $karnel_ver"

  # Check symlinks
  if [[ -L "$PREFIX/bin/karnel" ]]; then
    log_success "CLI symlink: karnel"
  else
    log_warn "CLI symlinks missing"
    ((warnings++))
    fix_commands+=("ln -sf \"$KARNEL_PATH/bin/karnel\" \"$PREFIX/bin/karnel\"")
    fix_descriptions+=("Recreate CLI symlinks")
    fix_callbacks+=("_fix_symlinks")
  fi

  # Check if banner is installed in shell config. Reuse the installer's own
  # detection so doctor and `karnel install ui --banner` can never disagree on
  # which rc file owns the banner.
  import "@/tools/ui/banner/install"
  local shell_config=""
  shell_config="$(_detect_shell_config)"

  if [[ -n "$shell_config" ]]; then
    if grep -qF "# ===== Karnel Banner =====" "$shell_config" 2>/dev/null &&
      ! grep -qF "# ===== /Karnel Banner =====" "$shell_config" 2>/dev/null; then
      # Legacy block: no end marker, so uninstalling it leaves the
      # `render_banner` call orphaned in the shell config.
      log_warn "Partial Karnel banner block in $(basename "$shell_config")"
      ((warnings++))
      fix_commands+=("karnel reinstall ui --banner")
      fix_descriptions+=("Repair legacy Karnel banner block")
      fix_callbacks+=("_fix_banner")
    elif grep -qF "# ===== Karnel Banner =====" "$shell_config" 2>/dev/null; then
      log_success "Banner installed in $(basename "$shell_config")"
    else
      log_warn "Banner not installed in $(basename "$shell_config")"
      ((warnings++))
      fix_commands+=("karnel install ui --banner")
      fix_descriptions+=("Install Karnel banner in shell")
      fix_callbacks+=("_fix_banner")
    fi
  fi

  # ===== 10. AI TOOLS STATUS =====
  echo
  separator_section "AI Tools Installed"
  echo

  local registry_file="$KARNEL_PATH/tools/ai/all.sh"
  local -a ai_cmds=()
  local registry_line registry_entry binaries
  while IFS= read -r registry_line; do
    registry_entry="${registry_line#*\"}"
    registry_entry="${registry_entry%\"*}"
    binaries="${registry_entry##*:}"
    ai_cmds+=("$binaries")
  done < <(grep -E '^[[:space:]]*"[^:]+:[^:]+:[^"]+"' "$registry_file")
  local ai_count=0

  for cmd in "${ai_cmds[@]}"; do
    IFS=, read -r -a binaries <<< "$cmd"
    if command -v "${binaries[0]}" &>/dev/null || { [[ ${#binaries[@]} -gt 1 ]] && command -v "${binaries[1]}" &>/dev/null; }; then
      log_success "$cmd: installed"
      ((ai_count++))
    fi
  done

  if (( ai_count == 0 )); then
    log_warn "No AI tools installed"
    ((warnings++))
    fix_commands+=("karnel install ai")
    fix_descriptions+=("Install all AI tools")
    fix_callbacks+=("_fix_ai_install")
  else
    log_info "$ai_count AI tool(s) installed"
  fi

  # Registry consistency check
  if [[ -f "$registry_file" ]]; then
    local registered_tools=${#ai_cmds[@]}
    local installed_ai
    installed_ai=0
    for cmd in "${ai_cmds[@]}"; do
      IFS=, read -r -a binaries <<< "$cmd"
      if command -v "${binaries[0]}" &>/dev/null || { [[ ${#binaries[@]} -gt 1 ]] && command -v "${binaries[1]}" &>/dev/null; }; then
        ((installed_ai++))
      fi
    done
    log_info "AI registry: $registered_tools tools | Installed: $installed_ai"
  fi

  # Check for discontinued tools still referenced in active installers
  local -a removed_tools=()
  for tool_dir in "$KARNEL_PATH/tools/ai/"*/; do
    local tool_name
    tool_name=$(basename "${tool_dir%/}")
    if [[ ! -f "$tool_dir/install.sh" && ! -f "$tool_dir/all.sh" ]]; then
      removed_tools+=("$tool_name")
    fi
  done
  if [[ ${#removed_tools[@]} -gt 0 ]]; then
    log_warn "Orphaned tool directories (no installer): ${removed_tools[*]}"
    ((warnings++))
  fi

  # ===== SCRIPT KEEPER =====
  echo
  separator_section "Script Keeper — Karnel-managed Script Audit"
  echo

  local script_ok=0 script_warn=0 script_err=0
  local found_symlink_issues=false found_shebang_issues=false
  local found_perm_issues=false found_missing_issues=false found_stale_issues=false

  for module_dir in "$KARNEL_PATH/tools/"*/; do
    local module_name
    module_name=$(basename "${module_dir%/}")
    for tool_dir in "$module_dir"*/; do
      [[ -d "$tool_dir" ]] || continue
      local tool_name
      tool_name=$(basename "${tool_dir%/}")
      local installer="$tool_dir/install.sh"
      [[ -f "$installer" ]] || continue

      local bin_names
      bin_names=$(grep -E '^[[:space:]]*local BIN_NAME=' "$installer" 2>/dev/null | head -1 | sed "s/.*BIN_NAME=\"\?//;s/\"\?$//")
      [[ -z "$bin_names" ]] && bin_names="$tool_name"

      for bin_name in $bin_names; do
        local bin_path="$PREFIX/bin/$bin_name"
        local tool_script="$tool_dir/$bin_name.py"

        if [[ -L "$bin_path" ]]; then
          local target
          target=$(readlink "$bin_path")
          if [[ "$target" == "$tool_script" ]]; then
            log_success "$module_name/$tool_name → $bin_name (OK)"
            ((script_ok++))
          elif [[ ! -f "$tool_script" ]]; then
            log_info "$bin_name: managed outside Karnel python payloads (→ $target)"
          else
            log_warn "$bin_name: symlink target changed (→ $target, expected $tool_script)"
            ((script_warn++)); found_symlink_issues=true
          fi

          if [[ -f "$tool_script" ]] && [[ -f "$bin_path" ]] && head -1 "$bin_path" 2>/dev/null | grep -q "^#!/usr/bin/env"; then
            log_warn "$bin_name: uses #!/usr/bin/env — will fail on Termux"
            ((script_warn++)); found_shebang_issues=true
          fi

          if [[ -f "$tool_script" ]]; then
            local perms
            perms=$(stat -c "%a" "$tool_script" 2>/dev/null)
            if [[ "$perms" != "755" ]] && [[ "$perms" != "555" ]] && [[ "$perms" != "775" ]]; then
              log_warn "$bin_name: script permissions $perms (should be 755)"
              ((script_warn++)); found_perm_issues=true
            fi
          fi
        elif [[ -f "$bin_path" ]]; then
          log_info "$bin_name: standalone binary (not Karnel-managed)"
        else
          log_warn "$module_name/$tool_name: $bin_name not found in PATH"
          ((script_warn++)); found_missing_issues=true
        fi
      done
    done
  done

  for bin_link in "$PREFIX/bin"/*; do
    if [[ -L "$bin_link" ]]; then
      local target
      target=$(readlink "$bin_link")
      if echo "$target" | grep -q "$KARNEL_PATH/tools/" && [[ ! -f "$target" ]]; then
        log_warn "Stale symlink: $(basename "$bin_link") → $target (missing)"
        ((script_warn++)); found_stale_issues=true
      fi
    fi
  done

  if $found_symlink_issues; then
    fix_commands+=("_fix_script_symlinks")
    fix_descriptions+=("Fix all Karnel tool symlinks")
    fix_callbacks+=("_fix_script_symlinks")
  fi
  if $found_shebang_issues; then
    fix_commands+=("_fix_script_shebangs")
    fix_descriptions+=("Fix all Karnel tool shebangs for Termux")
    fix_callbacks+=("_fix_script_shebangs")
  fi
  if $found_perm_issues; then
    fix_commands+=("_fix_script_perms")
    fix_descriptions+=("Fix all Karnel script permissions")
    fix_callbacks+=("_fix_script_perms")
  fi
  if $found_missing_issues; then
    fix_commands+=("_fix_script_missing")
    fix_descriptions+=("Reinstall missing Karnel tools")
    fix_callbacks+=("_fix_script_missing")
  fi
  if $found_stale_issues; then
    fix_commands+=("_fix_script_stale")
    fix_descriptions+=("Remove stale symlinks from PREFIX/bin")
    fix_callbacks+=("_fix_script_stale")
  fi

  if (( script_err == 0 && script_warn == 0 )); then
    log_success "All $script_ok Karnel-managed scripts healthy"
  else
    log_info "Scripts: $script_ok OK, $script_warn warnings, $script_err errors"
  fi

  echo
  separator_section "Binary & Shebang Health"
  echo

  # Interpreters that do not exist on this device. Android has no /usr, so
  # every "#!/usr/bin/env node" the kernel meets answers ENOENT and the shell
  # reports 126, even though node itself is installed. The check is on the
  # interpreter path rather than on the literal "#!/usr/bin/env" prefix, so a
  # shebang pointing at a stale absolute path is caught too.
  local bad_shebangs=0
  bad_shebangs="$(timeout 20 compat_count_broken_shebangs "$PREFIX/bin" 2>/dev/null)"
  bad_shebangs="${bad_shebangs:-0}"
  if [[ "$bad_shebangs" =~ ^[0-9]+$ ]] && ((bad_shebangs > 0)); then
    log_warn "$bad_shebangs binary(s) point at an interpreter that does not exist"
    local sb_file sb_name
    for sb_file in "$PREFIX/bin"/*; do
      [[ -f "$sb_file" && -r "$sb_file" ]] || continue
      IFS= read -r sb_head <"$sb_file" 2>/dev/null || continue
      [[ "$sb_head" == '#!'* ]] || continue
      sb_name="${sb_head#\#!}"
      sb_name="${sb_name# }"
      sb_name="${sb_name%% *}"
      if [[ "$sb_name" == /* && ! -x "$sb_name" ]]; then
        list_item "$(basename "$sb_file") ($sb_name)"
      fi
    done
    ((warnings++))
    fix_commands+=("karnel doctor --fix")
    fix_descriptions+=("Repoint $bad_shebangs shebang(s) at their Termux interpreter")
    fix_callbacks+=("_fix_npm_shebangs")
  else
    log_success "All binaries have valid shebangs"
  fi

  # Check for broken symlinks in PREFIX/bin
  local broken_symlinks=0
  broken_symlinks=$(timeout 10 find "$PREFIX/bin" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)
  if (( broken_symlinks > 0 )); then
    log_warn "$broken_symlinks broken symlink(s) in $PREFIX/bin"
    ((warnings++))
    fix_commands+=("find $PREFIX/bin -type l ! -exec test -e {} \; -delete")
    fix_descriptions+=("Remove broken symlinks from PREFIX/bin")
    fix_callbacks+=("_fix_broken_symlinks")
  else
    log_success "No broken symlinks in $PREFIX/bin"
  fi

  # Detect glibc-dependent binaries (need proot)
  local glibc_bins=0
  local -a glibc_dependent=("kimchi")
  for cmd in "${glibc_dependent[@]}"; do
    local path
    path=$(command -v "$cmd" 2>/dev/null)
    if [[ -n "$path" ]]; then
      if file "$path" 2>/dev/null | grep -qi "ELF\|executable" && \
         ! ldd "$path" &>/dev/null 2>&1; then
        log_info "$cmd: glibc binary (needs proot)"
        if command -v proot-distro &>/dev/null; then
          log_success "  proot-distro available as fallback"
        else
          log_warn "  $cmd needs proot but proot-distro not installed"
          ((warnings++))
        fi
        ((glibc_bins++))
      fi
    fi
  done
  if (( glibc_bins == 0 )); then
    log_success "No glibc-dependent binaries detected"
  fi

  # ===== SHELL CONFIGURATION =====
  echo
  separator_section "Shell Configuration"
  echo

  if [[ -f "$HOME/.zshrc" ]]; then
    log_success "ZSH config: .zshrc exists"

    # Check for syntax errors
    if zsh -n "$HOME/.zshrc" 2>/dev/null; then
      log_success ".zshrc syntax: OK"
    else
      log_error ".zshrc has syntax errors!"
      ((errors++))
      fix_commands+=("cp \"$HOME/.zshrc\" \"$HOME/.zshrc.bak\" && karnel install shell")
      fix_descriptions+=("Backup and reinstall shell config")
      fix_callbacks+=("_fix_shell_syntax")
    fi
  elif [[ -f "$HOME/.bashrc" ]]; then
    log_success "Bash config: .bashrc exists"
  else
    log_warn "No shell config found"
    ((warnings++))
  fi

  # ===== CACHE & BUILD ARTIFACTS =====
  echo
  separator_section "Cache & Build Artifacts"
  echo

  # npm cache
  local npm_cache_dir
  npm_cache_dir=$(npm config get cache 2>/dev/null)
  if [[ -n "$npm_cache_dir" ]] && [[ -d "$npm_cache_dir" ]]; then
    local npm_cache_size
    npm_cache_size=$(du -sh "$npm_cache_dir" 2>/dev/null | awk '{print $1}')
    log_info "npm cache: $npm_cache_size"
    if [[ "$npm_cache_size" =~ [0-9]+G ]]; then
      log_warn "npm cache is large (${npm_cache_size}) — consider cleaning"
      ((warnings++))
      fix_commands+=("npm cache clean --force 2>/dev/null")
      fix_descriptions+=("Clean npm cache")
      fix_callbacks+=("_fix_npm_cache")
    fi
  fi

  # pip cache
  local pip_cache_dir
  pip_cache_dir=$(pip cache dir 2>/dev/null)
  if [[ -n "$pip_cache_dir" ]] && [[ -d "$pip_cache_dir" ]]; then
    local pip_cache_size
    pip_cache_size=$(du -sh "$pip_cache_dir" 2>/dev/null | awk '{print $1}')
    log_info "pip cache: $pip_cache_size"
    if [[ "$pip_cache_size" =~ [0-9]+G ]]; then
      log_warn "pip cache is large (${pip_cache_size})"
      ((warnings++))
      fix_commands+=("pip cache purge 2>/dev/null")
      fix_descriptions+=("Clean pip cache")
      fix_callbacks+=("_fix_pip_cache")
    fi
  fi

  # Python __pycache__ bloat
  local pycache_size
  pycache_size=$(find "$PREFIX/lib/python3.*" -name "__pycache__" -type d -exec du -sk {} + 2>/dev/null | awk '{s+=$1}END{printf "%.0f", s/1024}')
  if [[ -n "$pycache_size" ]] && (( pycache_size > 50 )); then
    log_info "Python __pycache__: ${pycache_size}MB"
    if (( pycache_size > 200 )); then
      log_warn "Large Python cache (${pycache_size}MB) — may slow imports"
      fix_commands+=("find $PREFIX/lib/python3.* -name __pycache__ -exec rm -rf {} + 2>/dev/null")
      fix_descriptions+=("Clean Python __pycache__ directories")
      fix_callbacks+=("_fix_pycache")
    fi
  fi

  # cargo cache (if rust installed)
  if [[ -d "$HOME/.cargo/registry" ]]; then
    local cargo_size
    cargo_size=$(du -sh "$HOME/.cargo/registry" 2>/dev/null | awk '{print $1}')
    log_info "cargo registry: $cargo_size"
  fi

  # karnel cache
  if [[ -d "$KARNEL_CACHE" ]]; then
    local karnel_cache_size
    karnel_cache_size=$(du -sh "$KARNEL_CACHE" 2>/dev/null | awk '{print $1}')
    log_info "karnel cache: $karnel_cache_size"
  fi

  # Zombie/stale build processes
  local stale_builds
  stale_builds=$(pgrep -f "pip.*install\|npm.*install\|cargo.*build" 2>/dev/null | wc -l)
  if (( stale_builds > 0 )); then
    log_warn "$stale_builds build process(es) still running"
    list_item "Run 'kill \$(pgrep -f \"pip.*install\")' to clean up"
  fi

  # ===== PHANTOM PROCESS KILLER =====
  echo
  separator_section "Android Compatibility"
  echo

  if [[ "$android_ver" =~ ^(12|13|14|15|16) ]]; then
    log_warn "Android $android_ver: Phantom Process Killer may kill Termux processes"
    log_info "Fix: Run via ADB:"
    list_item "adb shell device_config put activity_manager max_phantom_processes 2147483647"
    ((warnings++))
  else
    log_success "No phantom killer warnings apply"
  fi

  # ===== PROOT / GLIBC ENVIRONMENT =====
  echo
  separator_section "Proot & glibc Environment"
  echo

  if command -v proot-distro &>/dev/null; then
    log_success "proot-distro: available"
    if proot-distro list 2>&1 | grep -qi ubuntu; then
      log_success "Ubuntu proot container: installed"
    else
      log_info "Ubuntu proot container: not installed (needed by kimchi)"
      fix_commands+=("proot-distro install ubuntu 2>/dev/null")
      fix_descriptions+=("Install Ubuntu proot container for glibc tools")
      fix_callbacks+=("_fix_proot_ubuntu")
    fi
  else
    log_info "proot-distro not installed (optional, needed for kimchi)"
    fix_commands+=("pkg install -y proot-distro")
    fix_descriptions+=("Install proot-distro for glibc compatibility")
    fix_callbacks+=("_fix_pkg_install")
  fi

  if command -v proot &>/dev/null; then
    log_success "proot: available"
  else
    log_info "proot not installed (optional)"
  fi

  # ===== ANDROID COMPATIBILITY LAYER =====
  echo
  separator_section "Android Compatibility Layer"
  echo
  # A foreign (glibc) binary cannot be started by the Android kernel at all;
  # karnel hands it to the loader from the glibc sysroot instead. This block
  # reports which of the three tiers are reachable and how many tools are
  # currently riding them.
  local compat_root compat_wrapped=0 compat_entry compat_fixable
  if compat_glibc_ready; then
    compat_root="$(compat_glibc_root)"
    log_success "glibc sysroot: available ($compat_root)"
  else
    log_info "glibc sysroot: not installed (required to run glibc-only tools)"
    fix_commands+=("pkg install -y glibc-repo glibc")
    fix_descriptions+=("Install the glibc sysroot so foreign binaries can run")
    fix_callbacks+=("_fix_pkg_install")
  fi

  for compat_entry in "$PREFIX/bin"/*; do
    [[ -f "$compat_entry" ]] || continue
    if _compat_is_wrapper "$compat_entry"; then
      compat_wrapped=$((compat_wrapped + 1))
    fi
  done
  if ((compat_wrapped > 0)); then
    log_success "$compat_wrapped tool(s) running through the compatibility wrapper"
  else
    log_info "no tool on PATH currently needs a compatibility wrapper"
  fi

  if compat_proot_available; then
    log_success "proot: available (tier 4 for binaries that hardcode /usr or /etc)"
  elif command -v proot >/dev/null 2>&1; then
    log_info "proot: installed, but the FHS root could not be assembled"
  else
    log_info "proot: not installed (optional; only needed for absolute-path tools)"
  fi

  compat_fixable="$(timeout 20 compat_count_broken_shebangs "$PREFIX/bin" 2>/dev/null)"
  compat_fixable="${compat_fixable:-0}"
  if [[ "$compat_fixable" =~ ^[0-9]+$ ]] && ((compat_fixable > 0)); then
    log_warn "$compat_fixable shebang(s) still point at a missing interpreter"
  else
    log_success "every shebang in $PREFIX/bin resolves"
  fi

  # ===== TERMUX:API =====
  echo
  separator_section "Termux:API"
  echo

  if command -v termux-battery-status &>/dev/null; then
    log_success "Termux:API is installed (termux-battery-status available)"
  elif dpkg -s termux-api 2>/dev/null | grep -q 'Status.*installed'; then
    log_success "Termux:API package installed"
  else
    log_warn "Termux:API not installed (needed for voice commands)"
    ((warnings++))
    fix_commands+=("pkg install -y termux-api")
    fix_descriptions+=("Install Termux:API for voice features")
    fix_callbacks+=("_fix_pkg_install")
  fi

  # ===== 14. GIT CONFIGURATION =====
  echo
  separator_section "Git Configuration"
  echo

  if command -v git &>/dev/null; then
    local git_user git_email
    git_user=$(git config --global user.name 2>/dev/null)
    git_email=$(git config --global user.email 2>/dev/null)
    if [[ -n "$git_user" ]] && [[ -n "$git_email" ]]; then
      log_success "Git user: $git_user <$git_email>"
    else
      log_warn "Git user.name or user.email not configured"
      ((warnings++))
    fi
  fi

  # ===== 15. SSH KEYS =====
  echo
  separator_section "SSH Keys"
  echo

  if [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$HOME/.ssh/id_rsa" ]]; then
    log_success "SSH key found"
  else
    log_warn "No SSH key found (needed for GitHub)"
    ((warnings++))
    fix_commands+=("ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''")
    fix_descriptions+=("Generate SSH key for GitHub")
    fix_callbacks+=("_fix_ssh_key")
  fi

  # ===== 16. NETWORK CONNECTIVITY =====
  echo
  separator_section "Network"
  echo

  # DNS resolution
  local dns_ok=false
  if command -v nslookup &>/dev/null; then
    nslookup github.com &>/dev/null && dns_ok=true
  elif command -v host &>/dev/null; then
    host github.com &>/dev/null && dns_ok=true
  elif command -v curl &>/dev/null; then
    curl -fsSL --max-time 5 https://github.com &>/dev/null && dns_ok=true
  fi
  if $dns_ok; then
    log_success "DNS resolution: OK"
  else
    local dns_warn="DNS resolution check failed"
    if ! command -v nslookup &>/dev/null && ! command -v host &>/dev/null; then
      dns_warn="$dns_warn (install dnsutils or whois for detailed check)"
    fi
    log_warn "$dns_warn"
    ((warnings++))

  fi

  if curl -fsSL --max-time 5 https://github.com &>/dev/null; then
    log_success "HTTPS connectivity: OK"
  else
    log_warn "Network connectivity issue detected"
    ((warnings++))
  fi

  # Termux mirror speed
  local active_mirror=""
  if [[ -f "$PREFIX/etc/apt/sources.list" ]]; then
    active_mirror=$(grep -oP 'https?://[^ ]+' "$PREFIX/etc/apt/sources.list" 2>/dev/null | head -1)
  fi
  if [[ -n "$active_mirror" ]]; then
    local mirror_host
    mirror_host=$(echo "$active_mirror" | awk -F/ '{print $3}')
    local ping_time
    ping_time=$(timeout 5 ping -c 1 -W 3 "$mirror_host" 2>/dev/null | grep -oP 'time=\K[0-9.]+' || echo "slow")
    log_info "Termux mirror: $mirror_host (${ping_time}ms)"
    if [[ "$ping_time" == "slow" ]]; then
      log_warn "Termux mirror is slow — consider switching"
      fix_commands+=("termux-change-repo")
      fix_descriptions+=("Switch to a faster Termux mirror")
      fix_callbacks+=("_fix_mirror")
    fi
  fi

  # ===== 17. OPENSSH =====
  if command -v sshd &>/dev/null; then
    log_success "OpenSSH server available"
  else
    log_info "OpenSSH server not installed (optional)"
  fi

  # ===== 18. DISK SPACE CHECK =====
  echo
  separator_section "Disk Health"
  echo

  local free_space_kb
  free_space_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
  if [[ -n "$free_space_kb" ]]; then
    local free_mb=$((free_space_kb / 1024))
    if (( free_mb < 500 )); then
      log_warn "Low disk space: ${free_mb}MB free. Consider cleaning cache."
      ((warnings++))
      fix_commands+=("rm -rf ~/.cache/karnel/install_*.log 2>/dev/null; pkg clean -y 2>/dev/null")
      fix_descriptions+=("Clean cache and unused packages")
      fix_callbacks+=("_fix_disk_cleanup")
    else
      log_success "Disk space: OK (${free_mb}MB free)"
    fi
  fi

  # ===== 19. KARNEL DATA DIRS =====
  echo
  separator_section "Karnel Data Integrity"
  echo

  local karnel_dirs=("$KARNEL_CONFIG" "$KARNEL_CACHE" "$KARNEL_DATA")
  for dir in "${karnel_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local size
      size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
      log_success "$(basename "$dir"): ${size:-0}"
    else
      log_warn "Missing: $(basename "$dir")"
      ((warnings++))
      fix_commands+=("mkdir -p \"$dir\"")
      fix_descriptions+=("Create missing dir: $(basename "$dir")")
      fix_callbacks+=("_fix_mkdir_single")
    fi
  done

  # ===== ZSH PLUGINS & KARNEL INTEGRATION =====
  echo
  separator_section "Zsh Plugins & Karnel Integration"
  echo

  local zsh_plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
  if [[ -d "$zsh_plugins_dir" ]]; then
    local -a needed_plugins=("history-substring-search" "you-should-use")
    for plugin in "${needed_plugins[@]}"; do
      if [[ -d "$zsh_plugins_dir/$plugin" ]]; then
        log_success "zsh plugin: $plugin"
      else
        log_info "zsh plugin: $plugin not found (optional)"
      fi
    done
  else
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ ! -d "$zsh_custom" ]]; then
      log_info "Oh My Zsh not installed (optional)"
    fi
  fi

  # Check karnel module loading
  if [[ -f "$HOME/.zshrc" ]] && grep -q "karnel" "$HOME/.zshrc" 2>/dev/null; then
    log_success "Karnel integration in .zshrc"
  fi

  # Check url-quote-magic for parse errors (Termux zsh bug)
  local uqm_file="$PREFIX/share/zsh/functions/Zle/url-quote-magic"
  if [[ -f "$uqm_file" ]] && grep -qF "((\${~localschema})" "$uqm_file" 2>/dev/null; then
    log_warn "url-quote-magic: double-paren parse error found (zsh 5.9 bug)"
    log_warn "url-quote-magic has known double-paren syntax error"
    fix_commands+=("true")
    fix_descriptions+=("Patch url-quote-magic double-paren parse error")
    fix_callbacks+=("_fix_url_quote_magic")
  fi

  # ===== GPU / OPENGL INFO =====
  echo
  separator_section "GPU & Hardware Acceleration"
  echo

  if command -v termux-info &>/dev/null; then
    local gpu_info
    gpu_info=$(timeout 10 termux-info 2>/dev/null | grep -i "gpu\|render\|opengl" | head -3)
    if [[ -n "$gpu_info" ]]; then
      log_success "GPU: $(echo "$gpu_info" | tr -s ' ')"
    fi
  fi

  # Check /dev/dri or /dev/ Mali for GPU acceleration
  if [[ -e /dev/dri/renderD128 ]] || [[ -e /dev/mali0 ]]; then
    log_success "GPU render node accessible"
  fi

  # ===== ENCODING & LOCALE =====
  echo
  separator_section "Locale & Encoding"
  echo

  if locale 2>/dev/null | grep -qi "utf8\|utf-8"; then
    log_success "UTF-8 locale: OK"
  else
    log_warn "UTF-8 locale not set — may cause encoding issues"
    ((warnings++))
    fix_commands+=("echo 'export LANG=en_US.UTF-8' >> $HOME/.zshrc")
    fix_descriptions+=("Set UTF-8 locale in shell config")
    fix_callbacks+=("_fix_locale")
  fi


  # ===== BATTERY & POWER MANAGEMENT =====
  echo
  separator_section "Battery & Power Management"
  echo

  if command -v termux-battery-status &>/dev/null; then
    local battery_info
    battery_info=$(timeout 5 termux-battery-status 2>/dev/null || true)
    if [[ -n "$battery_info" ]]; then
      local battery_pct
      battery_pct=$(echo "$battery_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('percentage',0))" 2>/dev/null || echo "?")
      log_success "Battery: ${battery_pct}%"

      # Check if battery is critically low
      if [[ "$battery_pct" =~ ^[0-9]+$ ]] && (( battery_pct < 15 )); then
        log_warn "Battery critically low (${battery_pct}%) — processes may be killed"
        ((warnings++))
      fi

      # Check charging status
      local charging
      charging=$(echo "$battery_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','Unknown'))" 2>/dev/null || echo "?")
      log_info "Charging status: $charging"
    else
      log_info "Battery status unavailable or timed out"
    fi
  else
    log_info "termux-battery-status not available (install termux-api)"
  fi

  # Check battery optimization exemption
  if command -v termux-wake-lock &>/dev/null; then
    log_success "termux-wake-lock available (prevents sleep)"
  else
    log_info "termux-wake-lock not installed (optional, prevents background killing)"
  fi

  # ===== API KEYS VALIDATION =====
  echo
  separator_section "API Keys & Environment"
  echo

  local -a api_keys=("OPENAI_API_KEY" "ANTHROPIC_API_KEY" "GOOGLE_API_KEY" "GEMINI_API_KEY" "OPENROUTER_API_KEY" "DEEPSEEK_API_KEY" "MISTRAL_API_KEY")
  local keys_found=0

  for key in "${api_keys[@]}"; do
    if [[ -n "${!key:-}" ]]; then
      local val="${!key}"
      local masked="${val:0:8}****${val: -4}"
      log_success "$key: $masked"
      ((keys_found++))
    fi
  done

  if [[ $keys_found -eq 0 ]]; then
    log_info "No API keys found in environment"
    log_info "Set keys with: ${D_CYAN}karnel env set${NC}"
  else
    log_info "$keys_found API key(s) configured"
  fi

  # Check for .env files with leaked keys
  local leaked_keys=0
  while IFS= read -r -d '' envfile; do
    if grep -qE '(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9])' "$envfile" 2>/dev/null; then
      log_warn "Potential API key found in: $envfile"
      ((leaked_keys++))
    fi
  done < <(find "$HOME" -maxdepth 3 -name '.env' -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null || true)

  if (( leaked_keys > 0 )); then
    log_warn "$leaked_keys file(s) with potential API keys in tracked directories"
    ((warnings++))
  fi

  # ===== PROCESS HEALTH =====
  echo
  separator_section "Process Health"
  echo

  # Check for zombie processes
  local zombies
  zombies=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {count++} END {print count+0}')
  if (( zombies > 0 )); then
    log_warn "$zombies zombie process(es) detected"
    ((warnings++))
    fix_commands+=("kill -9 \$(ps aux | awk '\\$8 ~ /^Z/ {print \\$2}') 2>/dev/null")
    fix_descriptions+=("Kill zombie processes")
    fix_callbacks+=("_fix_zombies")
  else
    log_success "No zombie processes"
  fi

  # Check for orphaned node/python processes
  local orphan_count=0
  orphan_count=$(pgrep -c -f 'node.*karnel\|python.*karnel' 2>/dev/null || echo 0)
  if [[ "$orphan_count" =~ ^[0-9]+$ ]] && (( orphan_count > 2 )); then
    log_warn "$orphan_count Karnel-related processes running (may be stale)"
    ((warnings++))
  fi

  # ===== STORAGE I/O HEALTH =====
  echo
  separator_section "Storage I/O Health"
  echo

  local io_test_file
  io_test_file="$(mktemp "$KARNEL_CACHE/karnel_io_test.XXXXXX" 2>/dev/null)" || io_test_file="$KARNEL_CACHE/karnel_io_test.$$"
  local io_start io_end io_time
  io_start=$(date +%s%N 2>/dev/null || echo 0)
  dd if=/dev/zero of="$io_test_file" bs=4096 count=100 2>/dev/null
  io_end=$(date +%s%N 2>/dev/null || echo 0)
  rm -f "$io_test_file" 2>/dev/null

  if [[ $io_start -gt 0 ]] && [[ $io_end -gt 0 ]]; then
    io_time=$(( (io_end - io_start) / 1000000 ))
    if (( io_time < 100 )); then
      log_success "Storage I/O: fast (${io_time}ms for 400KB)"
    elif (( io_time < 500 )); then
      log_info "Storage I/O: moderate (${io_time}ms for 400KB)"
    else
      log_warn "Storage I/O: slow (${io_time}ms for 400KB) — may affect performance"
      ((warnings++))
    fi
  fi

  # ===== WIFI / NETWORK QUALITY =====
  echo
  separator_section "Network Quality"
  echo

  if command -v ping &>/dev/null; then
    local ping_result
    ping_result=$(timeout 10 ping -c 3 -W 5 8.8.8.8 2>/dev/null)
    if [[ -n "$ping_result" ]]; then
      local avg_ping
      avg_ping=$(echo "$ping_result" | grep 'avg' | awk -F'/' '{print $5}')
      if [[ -n "$avg_ping" ]]; then
        local ping_int=${avg_ping%.*}
        if (( ping_int < 50 )); then
          log_success "Network latency: excellent (${avg_ping}ms)"
        elif (( ping_int < 150 )); then
          log_info "Network latency: good (${avg_ping}ms)"
        else
          log_warn "Network latency: high (${avg_ping}ms)"
          ((warnings++))
        fi
      fi
    fi
  fi

  # ===== SHELL HISTORY & PRIVACY =====
  echo
  separator_section "Shell Privacy"
  echo

  local histfiles=("$HOME/.zsh_history" "$HOME/.bash_history" "$HOME/.local/share/zsh/history")
  for histfile in "${histfiles[@]}"; do
    if [[ -f "$histfile" ]]; then
      local hist_size
      hist_size=$(du -sh "$histfile" 2>/dev/null | awk '{print $1}')
      local hist_lines
      hist_lines=$(wc -l < "$histfile" 2>/dev/null || echo 0)
      log_info "History: $(basename "$histfile") ($hist_size, $hist_lines lines)"

      # Check for sensitive patterns in recent history
      if grep -qiE '(password=|secret=|token=|api_key=)' "$histfile" 2>/dev/null; then
        log_warn "Potential secrets found in shell history"
        ((warnings++))
        log_info "Run: ${D_CYAN}karnel brain save${NC} to protect sensitive data"
      fi
    fi
  done

  # ===== USB & EXTERNAL STORAGE =====
  echo
  separator_section "USB & External"
  echo

  if [[ -d /storage ]]; then
    local storage_count=0 storage_path storage_name
    for storage_path in /storage/*; do
      [[ -e "$storage_path" ]] || continue
      storage_name=$(basename "$storage_path")
      [[ "$storage_name" == "emulated" || "$storage_name" == "self" ]] && continue
      storage_count=$((storage_count + 1))
    done
    if (( storage_count > 0 )); then
      log_success "External storage: $storage_count volume(s) mounted"
    else
      log_info "No external storage mounted"
    fi
  fi

  # Check USB devices
  if [[ -d /dev/bus/usb ]]; then
    local usb_count
    usb_count=$(find /dev/bus/usb -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | wc -l)
    if (( usb_count > 0 )); then
      log_info "USB: $usb_count bus(es) detected"
    fi
  fi

  fi  # end QUICK_MODE skip

  # ===== GENERATE REPORT =====
  local report_dir="$KARNEL_DATA/doctor_reports"
  mkdir -p "$report_dir" 2>/dev/null || log_warn "Could not create report directory"
  local report_file="$report_dir/doctor_report_latest.md"

  # ===== RESULTS =====
  echo
  separator
  log_success "Diagnostics completed!"

  if [[ $errors -gt 0 ]]; then
    log_error "Found $errors error(s) and $warnings warning(s)."
  elif [[ $warnings -gt 0 ]]; then
    log_warn "Found $warnings warning(s). System is functional but can be optimized."
  else
    log_success "All systems healthy!"
  fi

  # ===== AUTO-FIX =====
  if [[ ${#fix_commands[@]} -gt 0 ]]; then
    echo
    separator_section "Auto-Fix Options"
    echo
    log_info "Detected $(( ${#fix_commands[@]} )) issue(s) that can be automatically fixed:"
    echo
    for ((i=0; i<${#fix_commands[@]}; i++)); do
      printf "    ${D_YELLOW}%2d.${D_NC} %s\n" $((i + 1)) "${fix_descriptions[$i]}"
    done
    echo

    local confirm="y"
    if ! $FIX_MODE; then
      read_confirm "Apply all auto-corrections?" confirm
    fi
    if [[ "$confirm" == "y" ]]; then
      echo
      local -A DESTRUCTIVE_FIXES=(
        [_fix_ai_install]=1
        [_fix_proot_ubuntu]=1
        [_fix_disk_cleanup]=1
        [_fix_broken_symlinks]=1
        [_fix_apt_cache]=1
      )
      for ((i=0; i<${#fix_commands[@]}; i++)); do
        log_info "Fixing: ${fix_descriptions[$i]}..."
        local callback="${fix_callbacks[$i]:-}"
        local success=false
        local apply_this="y"

        # Destructive fixes are never auto-applied in --fix mode. In an
        # interactive --fix session they require an explicit confirmation; in a
        # non-interactive one they are skipped (fail-closed) to avoid wiping
        # caches, reinstalling packages or deleting unrelated software.
        if [[ -n "$callback" && -n "${DESTRUCTIVE_FIXES[$callback]:-}" ]]; then
          if $FIX_MODE; then
            if [[ -t 0 && "${KARNEL_AUTO:-0}" != "1" ]]; then
              read_confirm "DANGEROUS: ${fix_descriptions[$i]}. Apply?" apply_this n
            else
              log_warn "Skipping destructive fix (non-interactive): ${fix_descriptions[$i]}"
              continue
            fi
          fi
        fi

        if [[ "$apply_this" == "y" ]]; then
          if [[ -n "$callback" ]] && type "$callback" &>/dev/null 2>&1; then
            "$callback" && success=true
          fi

          if [[ "$success" == "true" ]]; then
            ((fixed++))
            log_success "Fixed: ${fix_descriptions[$i]}"
          else
            log_warn "Could not fix: ${fix_descriptions[$i]}"
          fi
        fi
      done
      echo
      if (( fixed > 0 )); then
        log_success "Fixed $fixed issue(s)! Run 'karnel doctor' again to verify."
      else
        log_warn "Some fixes could not be applied. Check errors above."
      fi
    fi
  fi

  if cat >"$report_file" <<EOF
# Karnel Doctor Diagnostic Report
Generated: $(date)

## System Info
- **Android**: $android_ver
- **Termux**: $termux_ver
- **Architecture**: $arch
- **Karnel Version**: ${karnel_ver:-skipped}

## Resources
- **Disk Free**: $free_space
- **RAM Total**: $ram_total
- **RAM Free**: $ram_free

## Storage & Permissions
- **Shared Storage**: $storage_status
- **Karnel Write Access**: $([ -w "$KARNEL_PATH" ] && echo "Yes" || echo "No")

## PostgreSQL
- **Installed**: ${pg_installed:-skipped}
- **Data Found**: ${pg_data_found:-skipped}

## AI Tools
- **Count**: ${ai_count:-skipped}

## Summary
- **Errors**: $errors
- **Warnings**: $warnings
- **Fixed**: $fixed
EOF
  then
    list_item "Report saved: ${D_CYAN}$report_file${D_NC}"
  else
    log_warn "Failed to save report"
  fi
  echo
}

import "@/cli/commands/doctor/fixes"
import "@/cli/commands/doctor/code"
