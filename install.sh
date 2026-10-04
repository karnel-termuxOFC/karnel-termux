#!/usr/bin/env bash

set -e
trap '_cleanup_failed' ERR

readonly P_BORDER='\e[38;5;33m'
readonly P_PRIMARY='\e[38;5;39m'
readonly P_DIM='\e[38;5;244m'
readonly P_OK='\e[38;5;42m'
readonly P_FAIL='\e[1;31m'
readonly P_HL='\e[38;5;213m'
readonly P_NC='\e[0m'

REPO="https://github.com/karnel-termuxOFC/karnel-termux"
BRANCH="main"
RELEASE_REF=""
INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_COMMIT="${KARNEL_RELEASE_COMMIT:-}"
if [[ -z "$RELEASE_COMMIT" && -f "$INSTALL_SCRIPT_DIR/karnel/RELEASE_COMMIT" ]]; then
	read -r RELEASE_COMMIT <"$INSTALL_SCRIPT_DIR/karnel/RELEASE_COMMIT" || RELEASE_COMMIT=""
fi
KARNEL_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data"
KARNEL_REPO="${XDG_DATA_HOME:-$HOME/.local/share}/karnel"
KARNEL_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/karnel"
KARNEL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/karnel"

TOTAL_STEPS=4
CURRENT_STEP=0

_cols() {
	if command -v tput &>/dev/null; then
		tput cols
	else
		echo 80
	fi
}

progress_bar() {
	local current=$1
	local total=$2
	local width=${3:-40}
	local percentage=$((current * 100 / total))
	local filled=$((current * width / total))
	local empty=$((width - filled))

	printf -v bar "%*s" "$filled" ""
	bar="${bar// /█}"
	printf -v space "%*s" "$empty" ""
	space="${space// /░}"

	printf "\r  ${P_BORDER}│${P_NC}${P_OK}%s${P_NC}${P_DIM}%s${P_NC}${P_BORDER}│${P_NC} ${P_PRIMARY}%3d%%${P_NC}" "${bar}" "${space}" "$percentage"
}

log_step() {
	local step="$1"
	local desc="$2"
	CURRENT_STEP=$((CURRENT_STEP + 1))
	printf "\r%*s\r" "$(_cols)" ""
	echo -e "\n  ${P_BORDER}◆${P_NC}  ${P_PRIMARY}${CURRENT_STEP}/${TOTAL_STEPS}${P_NC}  ${desc}"
}

log_ok() {
	echo -e "  ${P_OK}✔${P_NC}  $1"
}

log_fail() {
	echo -e "  ${P_FAIL}✖${P_NC}  $1" >&2
}

log_info() {
	echo -e "  ${P_BORDER}→${P_NC}  $1"
}

_INSTALL_STAGING_ROOT=""
_INSTALL_PREVIOUS_KARNEL_REPO=""
_INSTALL_REPO_ACTIVATED=false
_INSTALL_REPO_HAD_PREVIOUS=false
_INSTALL_KARNEL_SYMLINK_CHANGED=false
_INSTALL_PREVIOUS_KARNEL_SYMLINK=""

_cleanup_failed() {
  set +e
  trap - ERR
  echo -e "\n  ${P_FAIL}✖${P_NC}  Installation failed at step ${CURRENT_STEP}. Cleaning up..."
	if $_INSTALL_KARNEL_SYMLINK_CHANGED; then
		if [[ -n "$_INSTALL_PREVIOUS_KARNEL_SYMLINK" ]]; then
			local rollback_link_dir
			rollback_link_dir=$(mktemp -d "$PREFIX/bin/.karnel-rollback.XXXXXX")
			ln -s "$_INSTALL_PREVIOUS_KARNEL_SYMLINK" "$rollback_link_dir/karnel"
			mv -Tf "$rollback_link_dir/karnel" "$PREFIX/bin/karnel"
			rmdir "$rollback_link_dir"
		else
			rm -f "$PREFIX/bin/karnel"
		fi
	fi
	if $_INSTALL_REPO_ACTIVATED; then
		rm -rf "$KARNEL_REPO"
		if $_INSTALL_REPO_HAD_PREVIOUS && [[ -d "$_INSTALL_PREVIOUS_KARNEL_REPO" ]]; then
			mv "$_INSTALL_PREVIOUS_KARNEL_REPO" "$KARNEL_REPO"
		fi
	fi
	[[ -z "$_INSTALL_STAGING_ROOT" ]] || rm -rf "$_INSTALL_STAGING_ROOT"
	echo -e "  ${P_DIM}Run install.sh again to retry${P_NC}"
	exit 1
}

_finish_install() {
	if $_INSTALL_REPO_HAD_PREVIOUS && [[ -d "$_INSTALL_PREVIOUS_KARNEL_REPO" ]]; then
		rm -rf "$_INSTALL_PREVIOUS_KARNEL_REPO"
	fi
	[[ -z "$_INSTALL_STAGING_ROOT" ]] || rm -rf "$_INSTALL_STAGING_ROOT"
	_INSTALL_REPO_ACTIVATED=false
	_INSTALL_KARNEL_SYMLINK_CHANGED=false
}

separator() {
	local cols=$(_cols)
	local line=$(printf "%${cols}s")
	echo -e "${P_DIM}${line// /─}${P_NC}"
}

banner() {
	echo
	echo -e "  ${P_BORDER}┌────────────────────────────────────┐${P_NC}"
	echo -e "  ${P_BORDER}│${P_NC}        ${P_PRIMARY}  ◈ KARNEL TERMUX ◈${P_NC}           ${P_BORDER}│${P_NC}"
	echo -e "  ${P_BORDER}│${P_NC} ${P_DIM}Modular Dev Environment for Termux${P_NC} ${P_BORDER}│${P_NC}"
	echo -e "  ${P_BORDER}└────────────────────────────────────┘${P_NC}"
	echo
}

bootstrap_dependencies() {
	local needed_tput=0
	local needed_git=0
	local needed_glow=0
	local needed_gh=0
	local needed_rg=0

	command -v tput &>/dev/null || needed_tput=1
	command -v git &>/dev/null || needed_git=1
	command -v glow &>/dev/null || needed_glow=1
	command -v gh &>/dev/null || needed_gh=1
	command -v rg &>/dev/null || needed_rg=1

	if [[ $needed_tput -eq 1 || $needed_git -eq 1 || $needed_glow -eq 1 || $needed_gh -eq 1 || $needed_rg -eq 1 ]]; then
		banner
	fi

	if [[ $needed_tput -eq 1 ]]; then
		echo -e "  ${P_BORDER}→${P_NC}  Installing ncurses-utils..."
		if ! pkg install -y ncurses-utils &>/dev/null; then
			log_fail "Failed to install ncurses-utils"
			return 1
		fi
		echo -e "  ${P_OK}✔${P_NC}  ncurses installed"
		echo
	fi

	if [[ $needed_git -eq 1 ]]; then
		log_info "Installing git..."
		progress_bar 0 10
		if ! pkg install -y git &>/dev/null; then
			log_fail "Failed to install git"
			return 1
		fi
		progress_bar 10 10
		echo
		log_ok "git installed"
	fi

	if [[ $needed_glow -eq 1 ]]; then
		log_info "Installing glow..."
		progress_bar 0 10
		if ! pkg install -y glow &>/dev/null; then
			log_fail "Failed to install glow"
			return 1
		fi
		progress_bar 10 10
		echo
		log_ok "glow installed"
	fi

	if [[ $needed_gh -eq 1 ]]; then
		log_info "Installing gh (GitHub CLI)..."
		progress_bar 0 10
		if ! pkg install -y gh &>/dev/null; then
			log_fail "Failed to install gh"
			return 1
		fi
		progress_bar 10 10
		echo
		log_ok "gh installed"
	fi

	if [[ $needed_rg -eq 1 ]]; then
		log_info "Installing ripgrep..."
		progress_bar 0 10
		if ! pkg install -y ripgrep &>/dev/null; then
			log_fail "Failed to install ripgrep"
			return 1
		fi
		progress_bar 10 10
		echo
		log_ok "ripgrep installed"
	fi

	if [[ $needed_tput -eq 1 || $needed_git -eq 1 || $needed_glow -eq 1 || $needed_gh -eq 1 || $needed_rg -eq 1 ]]; then
		echo
		clear
	fi
}

install_dependencies() {
	log_step 1 "Verifying dependencies"
	progress_bar 5 10
	progress_bar 10 10
	echo
	log_ok "Dependencies ready (git, ncurses-utils, glow, gh, ripgrep)"
}

setup_directories() {
	log_step 2 "Setting up directories"

	umask 077
	local directory
	for directory in "$KARNEL_DATA" "$KARNEL_CACHE" "$KARNEL_CONFIG"; do
		if [[ -L "$directory" ]]; then
			log_fail "Refusing symlink directory: $directory"
			return 1
		fi
		mkdir -p -m 700 "$directory" || return 1
		chmod 700 "$directory" || return 1
	done
	if [[ -L "$KARNEL_REPO" ]]; then
		log_fail "Refusing symlink directory: $KARNEL_REPO"
		return 1
	fi
	mkdir -p -m 700 "$(dirname "$KARNEL_REPO")" || return 1

	log_info "Repo    $KARNEL_REPO"
	log_info "Data    $KARNEL_DATA"
	log_info "Cache   $KARNEL_CACHE"
	log_info "Config  $KARNEL_CONFIG"
	log_ok "Directories created"
}

clone_repo() {
	log_step 3 "Cloning repository"

	local script_dir="$INSTALL_SCRIPT_DIR"
	local is_dev_install=0

	if [[ "$script_dir" != "$KARNEL_REPO" ]] && git -C "$script_dir" rev-parse --is-inside-work-tree &>/dev/null; then
		is_dev_install=1
	fi

	if [[ $is_dev_install -eq 1 ]]; then
		if [[ -n "$RELEASE_REF" ]]; then
			log_fail "A release ref cannot be installed from a development checkout"
			return 1
		fi
		KARNEL_REPO="$script_dir"
		log_info "Developer installation detected"
		log_ok "Using local repository"
	else
		local existing_repo=0
		if [[ -e "$KARNEL_REPO" ]]; then
			if ! git -C "$KARNEL_REPO" rev-parse --is-inside-work-tree &>/dev/null; then
				log_fail "Refusing to replace pre-existing non-repository: $KARNEL_REPO"
				return 1
			fi
			existing_repo=1
		fi

		if [[ $existing_repo -eq 1 ]]; then
		local origin_url
		origin_url="$(git -C "$KARNEL_REPO" remote get-url origin 2>/dev/null)"
		if [[ "${origin_url%.git}" != "${REPO%.git}" ]]; then
			log_fail "Existing Karnel repository has an unexpected origin"
			return 1
		fi
		local worktree_status
		if ! worktree_status=$(git -C "$KARNEL_REPO" status --porcelain --untracked-files=all); then
			log_fail "Failed to inspect existing Karnel repository"
			return 1
		fi
		if [[ -n "$worktree_status" ]]; then
			log_fail "Refusing to update a dirty Karnel repository"
			return 1
		fi
		fi

		_INSTALL_STAGING_ROOT=$(mktemp -d "$(dirname "$KARNEL_REPO")/.karnel-staging.XXXXXX")
		local candidate_repo="$_INSTALL_STAGING_ROOT/repo"
		progress_bar 0 10
		git clone --depth=1 --branch "$BRANCH" "$REPO" "$candidate_repo" &>/dev/null &
		local pid=$!
		local dots=0
		while kill -0 "$pid" 2>/dev/null; do
			dots=$(( (dots + 1) % 4 ))
			printf "\r  Cloning%s    " "$(printf '%*s' "$dots" '' | tr ' ' '.')"
			sleep 0.5
		done
		if ! wait "$pid"; then
			log_fail "Failed to clone repository"
			return 1
		fi
		if [[ -n "$RELEASE_COMMIT" ]]; then
			if ! git -C "$candidate_repo" fetch --depth=1 origin "$RELEASE_COMMIT" &>/dev/null; then
				log_fail "Failed to fetch release commit $RELEASE_COMMIT"
				return 1
			fi
			if ! git -C "$candidate_repo" checkout --quiet --detach "$RELEASE_COMMIT" &>/dev/null; then
				log_fail "Failed to checkout release commit $RELEASE_COMMIT"
				return 1
			fi
			local candidate_commit
			candidate_commit=$(git -C "$candidate_repo" rev-parse HEAD 2>/dev/null) || return 1
			if [[ "$candidate_commit" != "$RELEASE_COMMIT" ]]; then
				log_fail "Release commit mismatch"
				log_info "Expected $RELEASE_COMMIT, got $candidate_commit"
				return 1
			fi
		elif [[ -n "$RELEASE_REF" ]]; then
			local candidate_commit
			candidate_commit=$(git -C "$candidate_repo" rev-parse HEAD 2>/dev/null) || return 1
			if [[ "$candidate_commit" != "$RELEASE_COMMIT" ]]; then
				log_fail "Release commit mismatch for $RELEASE_REF"
				log_info "Expected $RELEASE_COMMIT, got $candidate_commit"
				return 1
			fi
		fi

		if [[ $existing_repo -eq 1 ]]; then
			_INSTALL_PREVIOUS_KARNEL_REPO=$(mktemp -d "$(dirname "$KARNEL_REPO")/.karnel-previous.XXXXXX")
			rmdir "$_INSTALL_PREVIOUS_KARNEL_REPO"
			mv "$KARNEL_REPO" "$_INSTALL_PREVIOUS_KARNEL_REPO"
			_INSTALL_REPO_HAD_PREVIOUS=true
		fi
		if ! mv "$candidate_repo" "$KARNEL_REPO"; then
			if $_INSTALL_REPO_HAD_PREVIOUS; then
				mv "$_INSTALL_PREVIOUS_KARNEL_REPO" "$KARNEL_REPO"
				_INSTALL_REPO_HAD_PREVIOUS=false
			fi
			log_fail "Failed to activate repository"
			return 1
		fi
		_INSTALL_REPO_ACTIVATED=true
		progress_bar 10 10
		echo
		if [[ $existing_repo -eq 1 ]]; then
			log_ok "Repository updated"
		else
			log_ok "Repository cloned"
		fi
	fi

	export KARNEL_REPO

	# Install shell completions
	if [ -f "$KARNEL_REPO/scripts/completion.bash" ]; then
		mkdir -p "$PREFIX/share/bash-completion/completions" 2>/dev/null || true
		cp "$KARNEL_REPO/scripts/completion.bash" "$PREFIX/share/bash-completion/completions/karnel" 2>/dev/null || log_info "Failed to install bash completion (non-fatal)"
	fi
	if [ -f "$KARNEL_REPO/scripts/completion.zsh" ]; then
		cp "$KARNEL_REPO/scripts/completion.zsh" "$PREFIX/share/zsh/site-functions/_karnel" 2>/dev/null || true
	fi
}

create_symlink() {
	log_step 4 "Creating symlinks"

	[[ -z "$PREFIX" ]] && { log_fail "PREFIX is not set. Are you running in Termux?"; return 1; }

	if [[ ( -e "$PREFIX/bin/karnel" || -L "$PREFIX/bin/karnel" ) && ! -L "$PREFIX/bin/karnel" ]]; then
		log_fail "Refusing to replace existing non-symlink: $PREFIX/bin/karnel"
		return 1
	fi
	if [[ -L "$PREFIX/bin/karnel" ]]; then
		_INSTALL_PREVIOUS_KARNEL_SYMLINK="$(readlink "$PREFIX/bin/karnel")"
	fi
	local link_staging
	link_staging=$(mktemp -d "$PREFIX/bin/.karnel-link.XXXXXX")
	ln -s "$KARNEL_REPO/karnel/bin/karnel" "$link_staging/karnel"
	mv -Tf "$link_staging/karnel" "$PREFIX/bin/karnel"
	rmdir "$link_staging"
	_INSTALL_KARNEL_SYMLINK_CHANGED=true

	if [[ -L "$PREFIX/bin/karnel" ]]; then
		log_ok "Symlink created: karnel → ${KARNEL_REPO}/karnel/bin/karnel"
	else
		log_fail "Failed to create symlink"
		return 1
	fi
}

show_final_message() {
	echo
	separator
	echo -e "  ${P_OK}◆${P_NC}  ${P_PRIMARY}Karnel Installed${P_NC}"
	separator
	echo
	echo -e "  ${P_DIM}Author:${P_NC}  ${P_HL}israel marques${P_NC}"
	echo
	echo -e "  ${P_DIM}Run${P_NC}  ${P_HL}karnel${P_NC}  ${P_DIM}to get started${P_NC}"
	echo
	echo -e "  ${P_DIM}Install modules:${P_NC}"
	echo
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install lang" "Programming languages"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install db" "Databases"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install ai" "AI tools"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install editor" "Code editor"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install dev" "Dev tools"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install npm" "Node.js tools"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install shell" "ZSH shell"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install ui" "Termux UI"
	printf "    ${P_PRIMARY}%-20s${P_NC} ${P_DIM}%s${P_NC}\n" "karnel install auto" "n8n"
	echo
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--ref)
				[[ $# -ge 2 && "$2" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
					echo -e "\n  ${P_FAIL}✖${P_NC}  Invalid or missing release ref" >&2
					return 1
				}
				BRANCH="$2"
				RELEASE_REF="$2"
				shift 2
				;;
			--commit)
				[[ $# -ge 2 && "$2" =~ ^[0-9a-f]{40}$ ]] || {
					echo -e "\n  ${P_FAIL}✖${P_NC}  Invalid or missing release commit" >&2
					return 1
				}
				RELEASE_COMMIT="$2"
				shift 2
				;;
			*)
				echo -e "\n  ${P_FAIL}✖${P_NC}  Usage: install.sh [--ref vX.Y.Z --commit SHA]" >&2
				return 1
				;;
		esac
	done
	if [[ -n "$RELEASE_REF" && ! "$RELEASE_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
		echo -e "\n  ${P_FAIL}✖${P_NC}  Release installation requires an immutable commit SHA" >&2
		return 1
	fi

  if [[ -z "${PREFIX:-}" ]]; then
    echo -e "\n  ${P_FAIL}✖${P_NC}  PREFIX is not set. Are you running in Termux?"
    echo -e "  ${P_DIM}This installer requires Termux environment.${P_NC}"
    echo -e "  ${P_DIM}Install Termux from GitHub or F-Droid first.${P_NC}"
    exit 1
  fi
  bootstrap_dependencies
  banner
  install_dependencies
  setup_directories
  clone_repo
  create_symlink
  _finish_install
  show_final_message
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
