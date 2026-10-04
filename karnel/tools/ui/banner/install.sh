#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/uninstall"

LOG_FILE="$KARNEL_CACHE/install_ui.log"

KARNEL_BANNER_MARKER="# ===== Karnel Banner ====="
KARNEL_BANNER_END_MARKER="# ===== /Karnel Banner ====="
KARNEL_MOTD_BACKUP="$KARNEL_CACHE/motd.backup"

_backup_motd() {
	if [[ ! -e "$PREFIX/etc/motd" ]]; then
		return 0
	fi

	if [[ -e "$KARNEL_MOTD_BACKUP" ]]; then
		log_info "Termux MOTD already backed up"
		return 0
	fi

	log_info "Backing up Termux MOTD..."
	mv "$PREFIX/etc/motd" "$KARNEL_MOTD_BACKUP"
	log_success "Termux MOTD backed up to $KARNEL_MOTD_BACKUP"
}

_restore_motd() {
	if [[ ! -e "$KARNEL_MOTD_BACKUP" ]]; then
		return 0
	fi

	if [[ -e "$PREFIX/etc/motd" ]]; then
		log_warn "Termux MOTD already exists, skipping restore"
		return 0
	fi

	log_info "Restoring Termux MOTD..."
	mv "$KARNEL_MOTD_BACKUP" "$PREFIX/etc/motd"
	log_success "Termux MOTD restored"
}

# Prefer an existing rc file. When neither exists yet, fall back to the
# config for the shell the user is actually running so the caller never
# receives an empty path (install/uninstall/doctor all rely on this).
_detect_shell_config() {
	if [[ -f "$HOME/.zshrc" ]]; then
		echo "$HOME/.zshrc"
	elif [[ -f "$HOME/.bashrc" ]]; then
		echo "$HOME/.bashrc"
	elif [[ -f "$HOME/.bash_profile" ]]; then
		echo "$HOME/.bash_profile"
	elif [[ "${SHELL##*/}" == "zsh" ]] || { command -v zsh &>/dev/null && [[ ! -f "$HOME/.bashrc" ]]; }; then
		echo "$HOME/.zshrc"
	else
		echo "$HOME/.bashrc"
	fi
}

_install_banner_impl() {
	local shell_config
	shell_config="$(_detect_shell_config)"

	if [[ -z "$shell_config" ]]; then
		log_warn "No shell config file found (.zshrc or .bashrc)"
		return 1
	fi

	if grep -qF "$KARNEL_BANNER_MARKER" "$shell_config" 2>/dev/null; then
		log_info "Karnel Banner already installed"
		return 0
	fi

	local banner_script="$KARNEL_UTILS/banner.sh"
	if [[ ! -f "$banner_script" ]]; then
		log_error "Banner script not found: $banner_script"
		return 1
	fi

	mkdir -p "$(dirname "$LOG_FILE")"

	cat >>"$shell_config" <<EOF

$KARNEL_BANNER_MARKER
source "$banner_script"
if [[ -n "\$ZSH_VERSION" ]]; then
  _karnel_show_banner() {
    precmd_functions=("\${precmd_functions[@]:#_karnel_show_banner}")
    [[ -f "\$_karnel_banner_cache" ]] && cat "\$_karnel_banner_cache"
  }
  precmd_functions+=(_karnel_show_banner)
elif [[ \$- == *i* && -z "\${KARNEL_BANNER_SESSION_SHOWN:-}" ]]; then
  export KARNEL_BANNER_SESSION_SHOWN=1
  render_banner
fi

clear() {
	command clear 2>/dev/null || true
	[[ -f "\$_karnel_banner_cache" ]] && cat "\$_karnel_banner_cache"
}
$KARNEL_BANNER_END_MARKER
EOF

	log_success "Karnel Banner installed"

	_backup_motd

	log_warn "Restart Termux or run: source $shell_config"
	return 0
}

install_banner() {
	if grep -qF "$KARNEL_BANNER_MARKER" "$(_detect_shell_config)" 2>/dev/null; then
		log_info "Karnel Banner already installed"
		return 0
	fi
	log_info "Installing Karnel Banner..."
	mkdir -p "$(dirname "$LOG_FILE")"
	loading "Installing Banner" _install_banner_impl
}

_uninstall_banner_impl() {
	local shell_config
	shell_config="$(_detect_shell_config)"

	if [[ -z "$shell_config" ]]; then
		log_warn "No shell config file found"
		return 1
	fi

	if ! grep -qF "$KARNEL_BANNER_MARKER" "$shell_config" 2>/dev/null; then
		log_warn "Karnel Banner not installed"
		return 0
	fi

  if grep -qF "$KARNEL_BANNER_END_MARKER" "$shell_config" 2>/dev/null; then
    if ! remove_marked_block "$shell_config" "$KARNEL_BANNER_MARKER" "$KARNEL_BANNER_END_MARKER"; then
      log_warn "Keeping malformed Karnel banner configuration"
      return 0
    fi
    log_success "Karnel Banner uninstalled"
  else
    local marker_line
    marker_line="$(grep -nF "$KARNEL_BANNER_MARKER" "$shell_config" | head -1 | cut -d: -f1)"
    if [[ -n "$marker_line" ]]; then
      sed -i "$marker_line,$((marker_line + 1))d" "$shell_config"
      log_warn "Removed legacy banner block; restart the shell to clear remaining legacy functions"
    else
      log_warn "Could not locate banner marker for removal"
      return 1
    fi
  fi

	_restore_motd

	return 0
}

uninstall_banner() {
	if ! grep -qF "$KARNEL_BANNER_MARKER" "$(_detect_shell_config)" 2>/dev/null; then
		log_warn "Karnel Banner not installed"
		return 0
	fi
	log_info "Uninstalling Karnel Banner..."
	loading "Uninstalling Banner" _uninstall_banner_impl
}

_update_banner_impl() {
	uninstall_banner
	install_banner
}

update_banner() {
	log_info "Updating Karnel Banner..."
	loading "Updating Banner" _update_banner_impl
}

reinstall_banner() {
	uninstall_banner || [[ $? -eq 2 ]] || return 1

	install_banner
}
