#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

# AI Manager (karnel ia) — router for all AI agents and sessions
IA_SESSIONS_DIR="${KARNEL_DATA:-$HOME/.local/share/karnel-data}/ia/sessions"
IA_DATA_DIR="${KARNEL_DATA:-$HOME/.local/share/karnel-data}/ia"

ia_help() {
	echo
	box "KARNEL IA — AI Agent Manager"
	echo
	log_info "Usage: karnel ia <command> [options]"
	echo
	separator_section "Commands"
	echo
	printf "    ${D_CYAN}%-12s${NC} %s\n" "sessions" "List all AI conversation sessions"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "install" "Install AI tools"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "routes" "Show available AI CLI methods/launchers"
	echo
	separator_section "Examples"
	echo
	printf "    ${D_CYAN}karnel ia sessions${NC}         # Show all AI sessions\n"
	printf "    ${D_CYAN}karnel ia install omni-route${NC}  # Install omniRoute\n"
	printf "    ${D_CYAN}karnel ia routes${NC}             # Show AI CLI routes\n"
	printf "    ${D_CYAN}karnel list ai${NC}               # List installed AI tools\n"
	echo
}

# List all AI sessions from known tools
ia_sessions() {
	# $1 was historically `--all`; agent names are always shown now.
	mkdir -p "$IA_SESSIONS_DIR"

	local -a sessions=()
	local session_file=""

	# OpenCode prompt history
	if [[ -f "$HOME/.local/state/opencode/prompt-history.jsonl" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			local input=""
			input=$(printf '%s' "$line" | jq -r '.input // empty' 2>/dev/null || true)
			if [[ -n "$input" ]]; then
				local ts="unknown"
				local json_ts
				json_ts=$(printf '%s' "$line" | jq -r '.timestamp // empty' 2>/dev/null || true)
				if [[ -n "$json_ts" && "$json_ts" != "null" ]]; then
					ts=$(date -d "@$json_ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "$json_ts")
				else
					local mtime
					mtime=$(stat -c %Y "$HOME/.local/state/opencode/prompt-history.jsonl" 2>/dev/null || echo "unknown")
					ts=$(date -d "@$mtime" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
				fi
				local display="${input:0:60}"
				display="${display//$'\n'/ }"
				sessions+=("[opencode]|$ts|$display")
			fi
		done < <(cat "$HOME/.local/state/opencode/prompt-history.jsonl" 2>/dev/null || true)
	fi

	# OpenCode real sessions (sqlite db via python3)
	if [[ -f "$HOME/.local/share/opencode/opencode.db" ]] && command -v python3 &>/dev/null; then
		while IFS=$'\t' read -r ts_epoch title; do
			[[ -z "$ts_epoch" ]] && continue
			local ts
			ts=$(date -d "@$((ts_epoch / 1000))" +%Y%m%d_%H%M%S 2>/dev/null || echo "$ts_epoch")
			local display="${title:0:60}"
			display="${display//$'\n'/ }"
			sessions+=("[opencode]|$ts|$display")
		done < <(python3 - <<'PY' 2>/dev/null
import sqlite3, sys, os
db = os.path.expanduser("~/.local/share/opencode/opencode.db")
try:
    con = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
    cur = con.cursor()
    for row in cur.execute("SELECT COALESCE(time_updated, time_created, 0), COALESCE(title, slug, 'session') FROM session WHERE time_archived IS NULL ORDER BY COALESCE(time_updated, time_created) DESC LIMIT 50").fetchall():
        print("%s\t%s" % (row[0], row[1]))
    con.close()
except Exception:
    pass
PY
)
	fi

	# Hermes sessions
	if [[ -d "$HOME/.hermes/sessions" ]]; then
		for f in "$HOME/.hermes/sessions"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[hermes]|$readable_ts|$basename")
		done
	fi

	# Kimi-code sessions
	if [[ -d "$HOME/.kimi-code/sessions" ]]; then
		for d in "$HOME/.kimi-code/sessions"/*; do
			[[ -d "$d" ]] || continue
			local basename; basename=$(basename "$d")
			local ts; ts=$(stat -c %Y "$d" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[kimi]|$readable_ts|$basename")
		done
	fi

	# Pi agent sessions
	if [[ -d "$HOME/.pi/agent/sessions" ]]; then
		for d in "$HOME/.pi/agent/sessions"/*; do
			[[ -d "$d" ]] || continue
			local basename; basename=$(basename "$d")
			local ts; ts=$(stat -c %Y "$d" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[pi]|$readable_ts|$basename")
		done
	fi

	# Codex sessions
	if [[ -d "$HOME/.codex" ]]; then
		for f in "$HOME/.codex"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[codex]|$readable_ts|$basename")
		done
	fi

	# OpenClaw sessions
	if [[ -d "$HOME/.openclaw/agents/main/sessions" ]]; then
		for f in "$HOME/.openclaw/agents/main/sessions"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[openclaw]|$readable_ts|$basename")
		done
	fi

	# Odysseus sessions
	if [[ -d "$HOME/.local/share/karnel-data/odysseus" ]]; then
		local ody_sessions_dir="$HOME/.local/share/karnel-data/odysseus/sessions"
		if [[ -d "$ody_sessions_dir" ]]; then
			for f in "$ody_sessions_dir"/*.json; do
				[[ -f "$f" ]] || continue
				local basename; basename=$(basename "$f")
				local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
				local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
				sessions+=("[odysseus]|$readable_ts|$basename")
			done
		fi
	fi

	# MimoCode sessions
	if [[ -d "$HOME/.local/share/karnel-data/mimocode" ]]; then
		local mimo_sessions_dir="$HOME/.local/share/karnel-data/mimocode/sessions"
		if [[ -d "$mimo_sessions_dir" ]]; then
			for f in "$mimo_sessions_dir"/*.json; do
				[[ -f "$f" ]] || continue
				local basename; basename=$(basename "$f")
				local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
				local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
				sessions+=("[mimocode]|$readable_ts|$basename")
			done
		fi
	fi

	# Claude Code sessions
	if [[ -d "$HOME/.claude" ]]; then
		for f in "$HOME/.claude"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[claude]|$readable_ts|$basename")
		done
		for f in "$HOME/.claude"/*.jsonl; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[claude]|$readable_ts|$basename")
		done
	fi

	# Gemini CLI sessions
	if [[ -d "$HOME/.gemini" ]]; then
		for f in "$HOME/.gemini"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[gemini]|$readable_ts|$basename")
		done
		for f in "$HOME/.gemini"/*.jsonl; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[gemini]|$readable_ts|$basename")
		done
	fi

	# Qwen sessions
	if [[ -d "$HOME/.qwen" ]]; then
		for f in "$HOME/.qwen"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[qwen]|$readable_ts|$basename")
		done
		for f in "$HOME/.qwen"/*.jsonl; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[qwen]|$readable_ts|$basename")
		done
	fi

	# Vibe sessions
	if [[ -d "$HOME/.vibe" ]]; then
		for f in "$HOME/.vibe"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[vibe]|$readable_ts|$basename")
		done
		for f in "$HOME/.vibe"/*.jsonl; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[vibe]|$readable_ts|$basename")
		done
	fi

	# Codebuff sessions
	if [[ -d "$HOME/.codebuff" ]]; then
		for f in "$HOME/.codebuff"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[codebuff]|$readable_ts|$basename")
		done
	fi

	# Freebuff sessions
	if [[ -d "$HOME/.freebuff" ]]; then
		for f in "$HOME/.freebuff"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[freebuff]|$readable_ts|$basename")
		done
	fi

	# Agnostic sessions
	if [[ -d "$HOME/.agy" ]]; then
		for f in "$HOME/.agy"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[agy]|$readable_ts|$basename")
		done
	fi

	# MMX sessions
	if [[ -d "$HOME/.mmx" ]]; then
		for f in "$HOME/.mmx"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[mmx]|$readable_ts|$basename")
		done
	fi

	# Gentle AI sessions
	if [[ -d "$HOME/.gentle-ai" ]]; then
		for f in "$HOME/.gentle-ai"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[gentle-ai]|$readable_ts|$basename")
		done
	fi

	# GGA sessions
	if [[ -d "$HOME/.gga" ]]; then
		for f in "$HOME/.gga"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[gga]|$readable_ts|$basename")
		done
	fi

	# Engram sessions
	if [[ -d "$HOME/.engram" ]]; then
		for f in "$HOME/.engram"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[engram]|$readable_ts|$basename")
		done
	fi

	# CodeGraph sessions
	if [[ -d "$HOME/.codegraph" ]]; then
		for f in "$HOME/.codegraph"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[codegraph]|$readable_ts|$basename")
		done
	fi

	# Kilow sessions
	if [[ -d "$HOME/.kilow" ]]; then
		for f in "$HOME/.kilow"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[kilow]|$readable_ts|$basename")
		done
	fi
	# Kilocode sessions
	if command -v kilocode >/dev/null 2>&1; then
		sessions+=("[kilocode]|$(date +%Y%m%d_%H%M%S)|kilocode binary present")
	fi

	# Command Code sessions
	if [[ -d "$HOME/.command-code" ]]; then
		for f in "$HOME/.command-code"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[command-code]|$readable_ts|$basename")
		done
	fi

	# Kimchi sessions
	if [[ -d "$HOME/.kimchi" ]]; then
		for f in "$HOME/.kimchi"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[kimchi]|$readable_ts|$basename")
		done
	fi

	# Ollama model sessions/local chat
	if [[ -d "$HOME/.ollama/history" ]]; then
		for f in "$HOME/.ollama/history"/*.json; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[ollama]|$readable_ts|$basename")
		done
	fi

	# Brain AI cache as sessions
	if [[ -d "$KARNEL_CACHE/brain_ai_cache" ]]; then
		for f in "$KARNEL_CACHE/brain_ai_cache"/*; do
			[[ -f "$f" ]] || continue
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[brain]|$readable_ts|$basename")
		done
	fi

	# Copilot-Termux sessions
	if [[ -d "$HOME/.copilot" ]]; then
		while IFS= read -r -d '' f; do
			local basename; basename=$(basename "$f")
			local ts; ts=$(stat -c %Y "$f" 2>/dev/null || echo "unknown")
			local readable_ts; readable_ts=$(date -d "@$ts" +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
			sessions+=("[copilot]|$readable_ts|$basename")
		done < <(find "$HOME/.copilot" \( -name 'events.jsonl' -o -name 'command-history-state.json' \) -type f -print0 2>/dev/null)
	fi

	if [[ ${#sessions[@]} -eq 0 ]]; then
		log_warn "No AI sessions found"
		log_info "Start an AI tool to create your first session"
		return 0
	fi

	# Persist all discovered sessions to IA_SESSIONS_DIR for history
	local persist_file="$IA_SESSIONS_DIR/.all_sessions.json"
	local tmp_persist
	tmp_persist=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")
	echo "[" > "$tmp_persist"
	local first=1
	for session in "${sessions[@]}"; do
		local tool ts_raw name
		tool=$(echo "$session" | cut -d'|' -f1)
		ts_raw=$(echo "$session" | cut -d'|' -f2)
		name=$(echo "$session" | cut -d'|' -f3-)
		local escaped_name
		escaped_name=${name//\\/\\\\}
		escaped_name=${escaped_name//\"/\\\"}
		escaped_name=${escaped_name//$'\n'/\\n}
		escaped_name=${escaped_name//$'\r'/\\r}
		escaped_name=${escaped_name//$'\t'/\\t}
		if [[ $first -eq 1 ]]; then
			first=0
		else
			echo "," >> "$tmp_persist"
		fi
		printf '{"tool":"%s","ts":"%s","name":"%s"}\n' "$tool" "$ts_raw" "$escaped_name" >> "$tmp_persist"
	done
	echo "]" >> "$tmp_persist"
	mv "$tmp_persist" "$persist_file" 2>/dev/null || true

	separator
	box "AI Sessions (${#sessions[@]})"
	separator
	echo

	# Sort by date (newest first)
	mapfile -t sorted_sessions < <(printf '%s\n' "${sessions[@]}" | sort -t'|' -k2 -r)

	local idx=1
	for session in "${sorted_sessions[@]}"; do
		local tool ts name
		tool=$(echo "$session" | cut -d'|' -f1)
		ts=$(echo "$session" | cut -d'|' -f2)
		name=$(echo "$session" | cut -d'|' -f3-)

		local display_name="$name"
		if [[ ${#name} -gt 50 ]]; then
			display_name="${name:0:47}..."
		fi

		printf "    ${D_CYAN}%3d.${D_NC} %-14s %s  %s\n" "$idx" "$tool" "$ts" "$display_name"
		((idx++))
	done

	echo
	log_info "Total: ${#sessions[@]} sessions across all AI tools"
	log_info "History saved in: $IA_SESSIONS_DIR"
}

# List available AI CLI launchers/routers
ia_routes() {
	separator
	box "AI CLI Routes / Launchers"
	separator
	echo

	local -a routes=()

	import "@/tools/ai/all"
	local entry binaries cmd
	for entry in "${AI_TOOLS_REGISTRY[@]}"; do
		binaries="${entry##*:}"
		IFS=',' read -ra route_commands <<< "$binaries"
		for cmd in "${route_commands[@]}"; do
		if command -v "$cmd" &>/dev/null; then
			local path
			path=$(command -v "$cmd")
			routes+=("$cmd|$path|installed")
		else
			routes+=("$cmd|not installed|missing")
		fi
		done
	done

	table_start "CLI" "Path" "Status"
	for route in "${routes[@]}"; do
		local cli
		cli=$(echo "$route" | cut -d'|' -f1)
		local path
		path=$(echo "$route" | cut -d'|' -f2)
		local status
		status=$(echo "$route" | cut -d'|' -f3)

		local display_status
		if [[ "$status" == "installed" ]]; then
			display_status="${D_GREEN}installed${NC}"
		else
			display_status="${D_RED}missing${NC}"
		fi

		table_row "${D_CYAN}${cli}${NC}" "$path" "$display_status"
	done
	table_end
	echo

	log_info "Install missing ones with: ${D_CYAN}karnel install ai${NC}"
}

# Install AI tools
ia_install() {
	local tool="${1:-}"

	if [[ -z "$tool" ]]; then
		log_error "Please specify an AI tool to install"
		log_info "Usage: karnel ia install <tool>"
		log_info "Example: karnel ia install odysseus"
		return 1
	fi

	log_info "Installing AI tool: $tool"
	karnel_main "install" "ai" "--$tool"
}

# Main router
ia_main() {
	local cmd="$1"
	shift || true

	case "$cmd" in
	sessions)
		ia_sessions "$@"
		;;
	install)
		ia_install "$@"
		;;
	routes | launchers)
		ia_routes
		;;
	"" | --help | -h)
		ia_help
		;;
	*)
		log_error "Unknown command: $cmd"
		ia_help
		return 1
		;;
	esac
}
