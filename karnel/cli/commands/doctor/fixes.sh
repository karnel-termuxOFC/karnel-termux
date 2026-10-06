#!/usr/bin/env bash
# shellcheck disable=SC1091

import "@/utils/log"
import "@/utils/colors"
import "@/utils/install"
import "@/utils/compat"

_fix_storage() {
  termux-setup-storage 2>/dev/null
  return $?
}

_fix_mkdir() {
  local rc=0
  for dir in "$KARNEL_CONFIG" "$KARNEL_CACHE" "$KARNEL_DATA"; do
    mkdir -p -m 700 "$dir" 2>/dev/null &&
      { [[ -d "$dir" && ! -L "$dir" ]] && chmod 700 "$dir"; } ||
      { rc=1; log_warn "Failed to create $dir"; }
  done
  return $rc
}

_fix_pkg_install() {
  local pkg_to_install=""
  local fix_idx="${3:-$i}"
  case "$1" in
    pkg) pkg_to_install="$2" ;;
    *) pkg_to_install="${fix_commands[$fix_idx]:-}" ;;
  esac
  local pkg_name=""
  if [[ "$pkg_to_install" =~ pkg\ install\ -y\ (.+) ]]; then
    pkg_name="${BASH_REMATCH[1]}"
  fi
  if [[ -n "$pkg_name" ]]; then
    pkg install -y "$pkg_name" 2>/dev/null
    return $?
  fi
  return 1
}

_fix_dpkg() {
  dpkg --configure -a 2>/dev/null
  apt-get -f install -y 2>/dev/null
  return $?
}

_fix_apt_update() {
  pkg update -y 2>/dev/null
  return $?
}

_fix_npm_prefix() {
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" 2>/dev/null
  return $?
}

_fix_pip() {
  local py_cmd=""
  for py in python3.12 python3.11 python3.10 python3.9 python3 python; do
    if command -v "$py" &>/dev/null; then py_cmd="$py"; break; fi
  done
  if [[ -n "$py_cmd" ]]; then
    "$py_cmd" -m ensurepip 2>/dev/null
    "$py_cmd" -m pip install --upgrade pip 2>/dev/null
    return $?
  fi
  return 1
}

_fix_pg_init() {
  source "$KARNEL_PATH/utils/env.sh" 2>/dev/null
  import "@/modules/db" 2>/dev/null
  if type pg_init &>/dev/null; then
    pg_init 2>/dev/null
    pg_start 2>/dev/null
    return $?
  fi
  local pg_data="$HOME/.local/share/postgresql/data"
  mkdir -p "$pg_data" 2>/dev/null
  if command -v initdb &>/dev/null; then
    initdb -D "$pg_data" 2>/dev/null
    pg_ctl -D "$pg_data" -l "$HOME/.cache/karnel/postgresql.log" start 2>/dev/null
    return $?
  fi
  return 1
}

_fix_pg_start() {
  local pg_data=""
  for dir in "$PREFIX/var/lib/postgresql/data" "$PREFIX/var/lib/postgresql" "$HOME/.termux/postgresql/data" "$HOME/.termux/postgresql" "$HOME/.local/share/postgresql/data"; do
    if [[ -d "$dir" ]] && [[ -f "$dir/PG_VERSION" ]]; then
      pg_data="$dir"
      break
    fi
  done
  if [[ -n "$pg_data" ]] && command -v pg_ctl &>/dev/null; then
    pg_ctl -D "$pg_data" -l "$HOME/.cache/karnel/postgresql.log" start 2>/dev/null
    return $?
  fi
  return 1
}

_fix_pg_install() {
  if ! command -v pg_ctl &>/dev/null; then
    pkg install -y postgresql 2>/dev/null || return 1
  fi
  if ! command -v initdb &>/dev/null; then
    return 1
  fi
  local pg_data="$PREFIX/var/lib/postgresql"
  mkdir -p "$pg_data" 2>/dev/null
  if [[ ! -f "$pg_data/PG_VERSION" ]]; then
    initdb -D "$pg_data" 2>/dev/null || return 1
  fi
  return 0
}

_fix_symlinks() {
  ln -sf "$KARNEL_PATH/bin/karnel" "$PREFIX/bin/karnel" 2>/dev/null
  [[ -L "$PREFIX/bin/karnel" ]]
}

_fix_banner() {
  # Always go through the canonical installer: it writes the full block with
  # start *and* end markers (plus the zsh precmd hook), which is what the
  # uninstall path expects. Hand-rolled blocks used to leave `render_banner`
  # orphaned in .zshrc after an uninstall.
  import "@/tools/ui/banner/install"
  install_banner
}

_fix_ai_install() {
  log_info "Installing AI tools (this may take a while)..."
  source "$KARNEL_PATH/utils/env.sh" 2>/dev/null
  import "@/modules/ai" 2>/dev/null
  if type install_ai &>/dev/null; then
    install_ai 2>/dev/null
    return $?
  fi
  return 1
}

_fix_shell_syntax() {
  local config=""
  if [[ -f "$HOME/.zshrc" ]]; then
    config="$HOME/.zshrc"
    if ! command -v zsh &>/dev/null; then
      log_warn "zsh not installed — cannot validate .zshrc syntax"
      return 1
    fi
  elif [[ -f "$HOME/.bashrc" ]]; then
    config="$HOME/.bashrc"
  else
    return 1
  fi
  local bak="${config}.bak.$(date +%s)"
  cp "$config" "$bak" 2>/dev/null || return 1
  sed -i '/^# syntax error/d' "$config" 2>/dev/null
  local validator="bash"
  [[ "$config" == *.zshrc ]] && validator="zsh"
  if "$validator" -n "$config" 2>/dev/null; then
    return 0
  fi
  cp "$bak" "$config" 2>/dev/null
  return 1
}

_fix_ssh_key() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N '' 2>/dev/null
  return $?
}

_fix_disk_cleanup() {
  rm -rf ~/.cache/karnel/install_*.log 2>/dev/null
  if command -v pkg &>/dev/null; then
    pkg clean -y 2>/dev/null
  fi
  return $?
}

_fix_mkdir_single() {
  local rc=0
  for dir in "$KARNEL_CONFIG" "$KARNEL_CACHE" "$KARNEL_DATA"; do
    [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || { rc=1; log_warn "Failed to create $dir"; }
  done
  return $rc
}

# ===== NEW FIX CALLBACKS =====

_fix_psutil() {
  local tmp="$PREFIX/tmp/psutil_patch"
  mkdir -p "$tmp"
  pip download psutil==7.2.2 --no-binary :all: --no-deps -d "$tmp" 2>/dev/null || return 1
  safe_extract_tar "$tmp/psutil-7.2.2.tar.gz" "$tmp" || return 1
  if grep -q 'LINUX = sys.platform.startswith("linux")' "$tmp/psutil-7.2.2/psutil/_common.py" 2>/dev/null; then
    sed -i 's/LINUX = sys.platform.startswith("linux")/LINUX = sys.platform.startswith(("linux", "android"))/' "$tmp/psutil-7.2.2/psutil/_common.py"
  else
    log_warn "psutil patch target not found, skipping"
  fi
  pip install "$tmp/psutil-7.2.2" 2>/dev/null
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

_fix_pip_check() {
  local -a broken_pkgs=()
  while IFS= read -r line; do
    broken_pkgs+=("$line")
  done < <(pip check 2>&1 | grep -oP '^\S+' | head -3)
  if [[ ${#broken_pkgs[@]} -gt 0 ]]; then
    pip install --upgrade --force-reinstall "${broken_pkgs[@]}" 2>/dev/null
  fi
  return 0
}

_fix_npm_shebangs() {
  # Delegates to the compatibility layer instead of sed-ing $PREFIX/bin
  # itself: most of those entries are symlinks into node_modules, and
  # `sed -i` unlinks its argument, which would replace npm's symlink with a
  # detached copy whose relative require() resolves from the wrong directory.
  # compat_fix_shebang edits the target and copes with any interpreter, not
  # just node/bash/python3.
  compat_fix_shebangs "$PREFIX/bin" >/dev/null 2>&1
  return 0
}

_fix_broken_symlinks() {
  local link target
  for link in "$PREFIX/bin"/*; do
    [[ -L "$link" ]] || continue
    [[ -e "$link" ]] && continue
    target="$(readlink -f "$link" 2>/dev/null || true)"
    # Only remove broken symlinks that point into Karnel-managed locations so we
    # never delete unrelated third-party software from the user's environment.
    if [[ "$target" == "$KARNEL_PATH"/* || "$target" == "$KARNEL_DATA"/* ||
          "$target" == "$PREFIX/lib/node_modules"/* || "$target" == "$PREFIX/lib"/* ]]; then
      rm -f "$link" 2>/dev/null || true
    fi
  done
  return 0
}

_fix_npm_cache() {
  npm cache clean --force 2>/dev/null
  return $?
}

_fix_pip_cache() {
  pip cache purge 2>/dev/null
  return $?
}

_fix_pycache() {
  local python_dir
  for python_dir in "$PREFIX"/lib/python3.*; do
    [[ -d "$python_dir" ]] || continue
    find "$python_dir" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
  done
  return 0
}

_fix_proot_ubuntu() {
  if command -v proot-distro &>/dev/null; then
    proot-distro install ubuntu 2>/dev/null
    return $?
  fi
  return 1
}

_fix_mirror() {
  if command -v termux-change-repo &>/dev/null; then
    termux-change-repo 2>/dev/null
    return $?
  fi
  return 1
}

_fix_locale() {
  local config="$HOME/.zshrc"
  if [[ ! -f "$config" ]] && [[ -f "$HOME/.bashrc" ]]; then
    config="$HOME/.bashrc"
  fi
  grep -qxF 'export LANG=en_US.UTF-8' "$config" 2>/dev/null || echo 'export LANG=en_US.UTF-8' >> "$config" 2>/dev/null
}


_fix_zombies() {
  local zombies
  zombies=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {print $2}')
  if [[ -n "$zombies" ]]; then
    log_warn "Zombie processes (PID: $zombies) cannot be killed — the parent process must reap them"
    log_info "Run 'ps aux | grep Z' to see zombie parent PIDs"
  fi
  return 0
}

_fix_url_quote_magic() {
  local uqm_file="$PREFIX/share/zsh/functions/Zle/url-quote-magic"
  if [[ ! -f "$uqm_file" ]]; then
    return 1
  fi
  # Fix double-paren case patterns: (( -> ( for localschema and otherschema
  sed -i \
    -e 's/((${~localschema})/(${~localschema})/g' \
    -e 's/((${~otherschema})/(${~otherschema})/g' \
    "$uqm_file" 2>/dev/null
  return $?
}

# ===== SCRIPT KEEPER FIX CALLBACKS =====

_fix_script_symlinks() {
  local fixed=0 module_dir tool_dir
  while IFS= read -r -d '' module_dir; do
    while IFS= read -r -d '' tool_dir; do
      local installer="$tool_dir/install.sh"
      [[ -f "$installer" ]] || continue
      local tool_name
      tool_name=$(basename "$tool_dir")
      local bin_names
      bin_names=$(grep -E '^[[:space:]]*local BIN_NAME=' "$installer" 2>/dev/null | head -1 | sed "s/.*BIN_NAME=\"\?//;s/\"\?$//")
      [[ -z "$bin_names" ]] && bin_names="$tool_name"
      for bin_name in $bin_names; do
        local expected="$tool_dir/$bin_name.py"
        [[ -f "$expected" ]] || continue
        local link="$PREFIX/bin/$bin_name"
        if [[ -L "$link" ]]; then
          local target
          target=$(readlink "$link")
          if [[ "$target" != "$expected" ]]; then
            ln -sf "$expected" "$link" 2>/dev/null && ((fixed++))
          fi
        fi
      done
    done < <(find "$module_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  done < <(find "$KARNEL_PATH/tools/" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  [[ $fixed -gt 0 ]] && log_success "Fixed $fixed symlink(s)"
  return 0
}

_fix_script_shebangs() {
  local fixed=0 f
  while IFS= read -r -d '' f; do
    local shebang
    shebang=$(head -1 "$f" 2>/dev/null | tr -d '\0')
    case "$shebang" in
      "#!/usr/bin/env node")
        sed -i "1s|^.*$|#!$PREFIX/bin/node|" "$f" && ((fixed++)) ;;
      "#!/usr/bin/env bash"|"#!/usr/bin/env sh")
        sed -i "1s|^.*$|#!$PREFIX/bin/bash|" "$f" && ((fixed++)) ;;
      "#!/usr/bin/env python3"|"#!/usr/bin/env python")
        sed -i "1s|^.*$|#!$PREFIX/bin/python3|" "$f" && ((fixed++)) ;;
    esac
  done < <(find "$PREFIX/bin" -maxdepth 1 -type f -print0 2>/dev/null || true)
  [[ $fixed -gt 0 ]] && log_success "Fixed $fixed shebang(s)"
  return 0
}

_fix_script_perms() {
  local fixed=0 script module_dir tool_dir
  while IFS= read -r -d '' module_dir; do
    while IFS= read -r -d '' tool_dir; do
      while IFS= read -r -d '' script; do
        [[ -x "$script" ]] || { chmod +x "$script" 2>/dev/null && ((fixed++)); }
      done < <(find "$tool_dir" -maxdepth 1 -type f \( -name '*.py' -o -name '*.sh' \) -print0 2>/dev/null || true)
    done < <(find "$module_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  done < <(find "$KARNEL_PATH/tools/" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  [[ $fixed -gt 0 ]] && log_success "Fixed $fixed script permission(s)"
  return 0
}

_fix_script_missing() {
  local fixed=0 total=0 module_dir tool_dir
  while IFS= read -r -d '' module_dir; do
    while IFS= read -r -d '' tool_dir; do
      local installer="$tool_dir/install.sh"
      [[ -f "$installer" ]] || continue
      local tool_name
      tool_name=$(basename "$tool_dir")
      local module_name
      module_name=$(basename "$module_dir")
      local bin_names
      bin_names=$(grep -E '^[[:space:]]*local BIN_NAME=' "$installer" 2>/dev/null | head -1 | sed "s/.*BIN_NAME=\"\?//;s/\"\?$//")
      [[ -z "$bin_names" ]] && bin_names="$tool_name"
      for bin_name in $bin_names; do
        ((total++))
        if ! command -v "$bin_name" &>/dev/null; then
          karnel install "$module_name" "--$tool_name" &>/dev/null && ((fixed++))
        fi
      done    done < <(find "$module_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  done < <(find "$KARNEL_PATH/tools/" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  [[ $fixed -gt 0 ]] && log_success "Reinstalled $fixed/$total missing tool(s)"
  return 0
}

_fix_script_stale() {
  local removed=0 bin_link
  while IFS= read -r -d '' bin_link; do
    if [[ -L "$bin_link" ]]; then
      local target
      target=$(readlink "$bin_link")
      if echo "$target" | grep -q "$KARNEL_PATH/tools/" && [[ ! -f "$target" ]]; then
        rm -f "$bin_link" 2>/dev/null && ((removed++))
      fi
    fi
  done < <(find "$PREFIX/bin" -maxdepth 1 -print0 2>/dev/null || true)
  [[ $removed -gt 0 ]] && log_success "Removed $removed stale symlink(s)"
  return 0
}

_fix_keyring() {
  pkg update -y &>/dev/null && pkg install -y termux-keyring &>/dev/null
}

_fix_apt_cache() {
  rm -rf "${PREFIX:?}/var/apt/lists"/* 2>/dev/null
  pkg update -y &>/dev/null
}
