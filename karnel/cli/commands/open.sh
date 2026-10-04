#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

OPEN_DOCS="https://karneltermux.vercel.app"

# Resolves a documented target to its site URL, or prints nothing when the
# target has no page. Covers every route the site actually publishes plus the
# aliases users are most likely to type; anything else falls back to the
# module registry so new modules keep working without touching this file.
_open_url_for() {
	local target="$1"
	case "$target" in
	# Aliases kept for backwards compatibility with older docs/README hints.
	herdr) target="utils" ;;
	robin) target="osint" ;;
	esac

	# Commands that are not modules but still have a documentation page.
	case "$target" in
	doctor | brain | pg | init | env | backup | show | cleanup | supabase | linux | plugin | voice | security | osint)
		printf '%s/karnel/%s' "$OPEN_DOCS" "$target"
		return 0
		;;
	termux)
		printf '%s/termux' "$OPEN_DOCS"
		return 0
		;;
	termux-api | api)
		printf '%s/termux/api' "$OPEN_DOCS"
		return 0
		;;
	terms)
		printf '%s/terms' "$OPEN_DOCS"
		return 0
		;;
	esac

	# Modules are published one-to-one under /karnel/<module>.
	if [[ -f "${KARNEL_PATH:-}/modules/$target.sh" ]]; then
		printf '%s/karnel/%s' "$OPEN_DOCS" "$target"
		return 0
	fi
	return 1
}

open_main() {
	if [[ $# -eq 0 ]]; then
		open_help
		return
	fi

	local target="$1"
	local url=""

	case "$target" in
	karnel | help)
		url="$OPEN_DOCS/"
		;;
	--help | -h)
		open_help
		return
		;;
	*)
		url="$(_open_url_for "$target")"
		if [[ -z "$url" ]]; then
			log_error "Unknown target: $target"
			echo
			open_help
			return 1
		fi
		;;
	esac

	if command -v termux-open-url &>/dev/null; then
		termux-open-url "$url" 2>/dev/null && {
			log_success "Opening: ${D_CYAN}$url${NC}"
			return 0
		}
		log_warn "Failed to open URL, printing to terminal instead"
		echo
		echo "  ${D_CYAN}$url${NC}"
		echo
	elif command -v termux-open &>/dev/null; then
		termux-open "$url" 2>/dev/null && {
			log_success "Opening: ${D_CYAN}$url${NC}"
			return 0
		}
		log_warn "Failed to open URL, printing to terminal instead"
		echo "  ${D_CYAN}$url${NC}"
	else
		log_info "Documentation at:"
		echo
		echo "  ${D_CYAN}$url${NC}"
		echo
	fi
}

open_help() {
	echo
	box "Karnel Open"
	echo
	log_info "Usage: karnel open <target>"
	echo
	log_info "Open documentation in browser"
	echo
	separator_section "Targets"
	echo
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "karnel" "Karnel overview"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "lang" "Language modules"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "db" "Database modules"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "ai" "AI tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "editor" "Code editor"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "dev" "Dev tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "npm" "Node.js tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "shell" "ZSH shell"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "ui" "Termux UI"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "auto" "Automation tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "deploy" "Deploy CLIs"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "supabase" "Supabase CLI"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "games" "Games"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "cleanup" "Cache cleanup"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "network" "Network tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "utils" "Utility tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "voice" "Voice command"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "osint" "OSINT tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "robin" "Robin OSINT service"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "plugin" "Plugin system"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "security" "Security tools"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "herdr" "Herdr terminal AI assistant"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "doctor" "Diagnostics & auto-fix"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "brain" "Second Brain memories"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "pg" "PostgreSQL helpers"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "backup" "Backup & restore"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "init" "Project scaffolding"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "env" "Environment variables"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "termux" "Termux setup guide"
	printf "    ${D_GREEN}%-14s${NC} ${D_DIM}%s${NC}\n" "linux" "Linux stack guide"
	echo
	separator_section "Website"
	echo
	list_item "${D_CYAN}$OPEN_DOCS${NC}"
	echo
}
