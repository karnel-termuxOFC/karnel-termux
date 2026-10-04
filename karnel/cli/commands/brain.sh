#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

readonly BRAIN_DIR="$KARNEL_DATA/brain"

# ── Helpers ──────────────────────────────────────────────────

_brain_ensure() {
	if [[ ! -d "$BRAIN_DIR" ]]; then
		log_error "Brain not initialized"
		list_item "Run: ${D_CYAN}karnel brain init${D_NC}"
		return 1
	fi
}

_brain_slug() {
	local title="$1"
	local slug
	slug=$(echo "$title" \
		| tr '[:upper:]' '[:lower:]' \
		| sed -E 's/ç/c/g; s/ã|â|á|à/a/g; s/é|ê|è/e/g; s/í|ì/i/g; s/ó|ô|õ|ò/o/g; s/ú|ù/u/g; s/[^a-z0-9]+/-/g' \
		| sed -E 's/^-+|-+$//g' \
		| cut -c1-60)
	echo "$slug"
}

_brain_frontmatter() {
	local title="$1" tags="$2" category="$3" related="$4"
	cat <<-EOF
	---
	title: $title
	tags: [$tags]
	created: $(date +%Y-%m-%d)
	category: $category
	EOF
	if [[ -n "$related" ]]; then
		echo "related: [$related]"
	fi
	echo "---"
}

_brain_title() {
	local file="$1"
	local t
	t=$(grep -m1 '^title: ' "$file" 2>/dev/null | sed 's/^title: //')
	if [[ -n "$t" ]]; then
		echo "$t"
	else
		local fallback
		fallback=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //')
		echo "${fallback:-$(basename "$file" .md)}"
	fi
}

_brain_find_memory() {
	local slug="$1"
	if [[ -z "$slug" ]]; then
		return 1
	fi
	local f
	f=$(find "$BRAIN_DIR" -name "${slug}.md" 2>/dev/null | head -1)
	if [[ -z "$f" ]]; then
		f=$(find "$BRAIN_DIR" -name "*_${slug}.md" 2>/dev/null | head -1)
	fi
	[[ -n "$f" ]] && echo "$f"
}

_brain_rg() {
	local -a flags=()
	local list=0
	local pattern=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-i)
			flags+=(-i)
			shift
			;;
		-l)
			list=1
			shift
			;;
		--glob | --no-heading)
			shift
			;;
		-e)
			pattern="$2"
			shift 2
			;;
		*)
			pattern="$1"
			shift
			;;
		esac
	done

	if [[ -z "$pattern" ]]; then
		return 1
	fi

	if command -v rg &>/dev/null; then
		if ((list)); then
			rg "${flags[@]}" -l --glob '*.md' "$pattern" "$BRAIN_DIR" 2>/dev/null
		else
			rg "${flags[@]}" -n --no-heading --glob '*.md' "$pattern" "$BRAIN_DIR" 2>/dev/null
		fi
	else
		if ((list)); then
			grep -r -E "${flags[@]}" -l --include='*.md' "$pattern" "$BRAIN_DIR" 2>/dev/null
		else
			grep -r -E -n "${flags[@]}" --include='*.md' "$pattern" "$BRAIN_DIR" 2>/dev/null
		fi
	fi
}

_brain_slug_escape() {
	printf '%s\n' "$1" | sed 's/[\/&]/\\&/g; s/\n/\\n/g'
}

_brain_update_related() {
	local file="$1" slug="$2"
	local tmp
	tmp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-brain.XXXXXX")
	local frontmatter_end
	frontmatter_end=$(awk '/^---$/ {++n} n==2 {print NR; exit}' "$file")

	if [[ -z "$frontmatter_end" ]]; then
		rm -f "$tmp"
		return
	fi

	head -n $((frontmatter_end - 1)) "$file" >"$tmp"

	if grep -q "related:.*$slug" "$tmp" 2>/dev/null; then
		rm -f "$tmp"
		return
	fi

	local escaped
	escaped=$(_brain_slug_escape "$slug")
	if grep -q "^related:" "$tmp" 2>/dev/null; then
		sed -i "s/^related: \[\(.*\)\]/related: [\1, $escaped]/" "$tmp"
	else
		sed -i "/^---$/a related: [$escaped]" "$tmp"
	fi
	tail -n +$((frontmatter_end)) "$file" >>"$tmp"
	mv "$tmp" "$file"
}

_brain_remove_related() {
	local file="$1" slug="$2"
	local tmp
	tmp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-brain.XXXXXX")
	local frontmatter_end
	frontmatter_end=$(awk '/^---$/ {++n} n==2 {print NR; exit}' "$file")

	if [[ -z "$frontmatter_end" ]]; then
		rm -f "$tmp"
		return
	fi

	head -n $((frontmatter_end - 1)) "$file" >"$tmp"
	local escaped
	escaped=$(_brain_slug_escape "$slug")
	# Only touch the `related:` line, and only strip the slug as a discrete
	# comma-separated token (never as a substring inside another slug).
	sed -i "/^related:/ s/, ${escaped}//g; s/${escaped}, //g; s/\[${escaped}\]/[]/g; s/\[, /[/g; s/, \]/]/g" "$tmp"
	tail -n +$((frontmatter_end)) "$file" >>"$tmp"
	mv "$tmp" "$file"
}

_brain_pick_file() {
	local prompt="$1"
	local -a files=()

	while IFS= read -r f; do
		files+=("$f")
	done < <(find "$BRAIN_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | sort)

	if [[ ${#files[@]} -eq 0 ]]; then
		echo ""
		return
	fi

	local idx=0
	for f in "${files[@]}"; do
		local t
		t=$(_brain_title "$f")
		printf "    ${D_GREEN}%2d.${D_NC} %s\n" $((idx + 1)) "$t" >&2
		((idx++))
	done

	echo >&2
	read_input "$prompt" pick

	if [[ -z "$pick" ]]; then
		echo ""
		return
	fi

	local selected=""
	if [[ "$pick" =~ ^[0-9]+$ ]] && ((pick >= 1 && pick <= ${#files[@]})); then
		selected="${files[$((pick - 1))]}"
	else
		for f in "${files[@]}"; do
			local t
			t=$(_brain_title "$f")
			if echo "$t" | grep -qi "$pick"; then
				selected="$f"
				break
			fi
		done
	fi

	echo "$selected"
}

_brain_editor() {
	local title="$1"

	local editor_bin
	editor_bin="${EDITOR:-nano}"
	editor_bin="${editor_bin%% *}"

	if ! command -v "$editor_bin" &>/dev/null; then
		log_error "${EDITOR:-nano} not found"
		list_item "Install it: ${D_CYAN}karnel install editor${D_NC}"
		return 1
	fi

	local tmpfile
	tmpfile=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")

	echo "# $title" >"$tmpfile"
	echo >>"$tmpfile"
	echo "- " >>"$tmpfile"

	${EDITOR:-nano} "$tmpfile" </dev/tty >/dev/tty

	local lines
	lines=$(wc -l <"$tmpfile")
	if ((lines <= 2)); then
		rm -f "$tmpfile"
		return 1
	fi

	echo "$tmpfile"
}

# ── Help ────────────────────────────────────────────────────

brain_help() {
	echo
	box "Karnel Brain — Your Second Brain"
	echo
	log_info "Usage: karnel brain <subcommand> [options]"
	echo
	separator_section "Subcommands"
	echo
	printf "    ${D_CYAN}%-12s${NC} %s\n" "init" "Initialize brain directory and GitHub repo"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "save" "Save a new memory interactively"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "add" "Quick non-interactive save"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "search" "Search memories by keywords or tags"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "ls" "List memories by category"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "edit" "Edit a memory in your \$EDITOR"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "delete" "Delete a memory permanently"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "reset" "Destroy the entire brain"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "show" "View a memory with its relations"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "graph" "Visual map of all connections"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "skill" "Create an AI skill from memories"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "relate" "Link two memories"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "sync" "Push/pull to GitHub private repo"
	echo
	separator_section "Examples"
	echo
	printf "    ${D_CYAN}karnel brain init${NC}              # Create local brain\n"
	printf "    ${D_CYAN}karnel brain save${NC}              # Interactive save\n"
	printf "    ${D_CYAN}karnel brain add TEXT${NC}          # Quick non-interactive save\n"
	printf "    ${D_CYAN}karnel brain search react${NC}      # Search all memories\n"
	printf "    ${D_CYAN}karnel brain ls${NC}                # List all categories\n"
	printf "    ${D_CYAN}karnel brain ls react${NC}          # List react category\n"
	printf "    ${D_CYAN}karnel brain edit${NC}              # Interactive edit\n"
	printf "    ${D_CYAN}karnel brain edit slug-name${NC}    # Edit by slug\n"
	printf "    ${D_CYAN}karnel brain delete${NC}            # Interactive delete\n"
	printf "    ${D_CYAN}karnel brain reset${NC}             # Destroy local brain\n"
	printf "    ${D_CYAN}karnel brain show slug-name${NC}    # View memory + relations\n"
	printf "    ${D_CYAN}karnel brain graph${NC}             # Show connection map\n"
	printf "    ${D_CYAN}karnel brain skill${NC}             # Create a skill from memories\n"
	printf "    ${D_CYAN}karnel brain sync${NC}              # Sync with GitHub\n"
	echo
}

# ── Init ────────────────────────────────────────────────────

brain_init() {
	separator
	box "Initialize Karnel Brain"
	separator
	echo

	if [[ -d "$BRAIN_DIR" ]]; then
		log_warn "Brain already exists at: ${D_CYAN}$BRAIN_DIR${D_NC}"
		separator
		return 0
	fi

	local gh_ok=false
	if command -v gh &>/dev/null && gh auth status &>/dev/null; then
		gh_ok=true
	fi

	if ! $gh_ok; then
		mkdir -p "$BRAIN_DIR" 2>/dev/null
		log_success "Local brain created: ${D_CYAN}$BRAIN_DIR${D_NC}"
		list_item "Install gh for GitHub sync: ${D_CYAN}karnel install dev${D_NC}"
		separator
		return 0
	fi

	local gh_user
	gh_user=$(gh api user --jq '.login' 2>/dev/null)
	local repo_name="karnel-brain"

	if gh repo view "$gh_user/$repo_name" &>/dev/null; then
		log_info "Found existing brain repo: ${D_CYAN}$gh_user/$repo_name${D_NC}"
		echo
		read_confirm "Clone it to restore your memories?" confirm
		if [[ "$confirm" == "y" ]]; then
			loading "Cloning repository..." gh repo clone "$gh_user/$repo_name" "$BRAIN_DIR"
			log_success "Brain restored from GitHub"
			separator
			return 0
		fi
	fi

	local orig_dir="$PWD"
	mkdir -p "$BRAIN_DIR"
	log_success "Local brain created: ${D_CYAN}$BRAIN_DIR${D_NC}"
	echo

	read_confirm "Create a private GitHub repo for your brain?" confirm
	if [[ "$confirm" != "y" ]]; then
		log_info "Skipping GitHub setup. You can set it up later."
		separator
		return 0
	fi

	log_info "Creating private repo: ${D_CYAN}$gh_user/$repo_name${D_NC}..."
	if gh repo create "$repo_name" --private &>/dev/null; then
		(
			git -C "$BRAIN_DIR" init -b main &>/dev/null || exit 1
			echo "# Karnel Brain" >"$BRAIN_DIR/README.md"
			git -C "$BRAIN_DIR" add -A
			git -C "$BRAIN_DIR" commit -m "init brain" &>/dev/null
			git -C "$BRAIN_DIR" remote add origin "https://github.com/$gh_user/$repo_name.git"
			loading "Pushing to GitHub..." git -C "$BRAIN_DIR" push -u origin main
		)
		log_success "Repo created and linked: ${D_CYAN}https://github.com/$gh_user/$repo_name${D_NC}"
	else
		log_warn "Failed to create repo. Check your permissions."
	fi

	separator
}

# ── Save ────────────────────────────────────────────────────

brain_save() {
	_brain_ensure || return 1

	if [[ ! -t 0 ]]; then
		log_error "Interactive mode requires a terminal."
		log_info "Use: ${D_CYAN}karnel brain add \"your text\"${NC}"
		return 1
	fi

	separator
	box "Save a New Memory"
	separator
	echo

	read_input "Title" title
	if [[ -z "$title" ]]; then
		log_error "Title cannot be empty"
		separator
		return 1
	fi

	local slug
	slug=$(_brain_slug "$title")
	local date_prefix
	date_prefix=$(date +%Y-%m-%d)

	# ── Categories ──
	local categories
	categories=$(find "$BRAIN_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".git" -exec basename {} \; 2>/dev/null | sort)
	echo
	if [[ -n "$categories" ]]; then
		log_info "Existing categories:"
		echo
		while IFS= read -r cat; do
			printf "    ${D_GREEN}•${D_NC} ${D_CYAN}%s${D_NC}\n" "$cat"
		done <<<"$categories"
		echo
	fi
	read_input "Category" category
	if [[ -z "$category" ]]; then
		category="general"
	fi
	category=$(_brain_slug "$category")

	# ── Tags ──
	read_input "Tags (comma separated)" tags_input
	tags_input="${tags_input:-}"
	local tags_formatted
	tags_formatted=$(echo "$tags_input" | sed 's/, */, /g' | sed 's/^, \|, $//g')

	# ── Content via editor ──
	local tmpfile
	tmpfile=$(_brain_editor "$title")
	if [[ -z "$tmpfile" ]]; then
		log_error "Content cannot be empty"
		return 1
	fi
	local content
	content=$(cat "$tmpfile")
	rm -f "$tmpfile"

	# ── Suggest relations ──
	local -a related_slugs=()
	if [[ -n "$tags_formatted" ]]; then
		local IFS=','
		for tag in $tags_formatted; do
			tag=$(echo "$tag" | xargs)
			while IFS= read -r match; do
				local match_slug
				match_slug=$(basename "$match" .md)
				# Don't relate to self and avoid duplicates
				if [[ "$match_slug" != "${date_prefix}_${slug}" ]]; then
					local already=false
					for r in "${related_slugs[@]}"; do
						[[ "$r" == "$match_slug" ]] && already=true && break
					done
					$already || related_slugs+=("$match_slug")
				fi
			done < <(_brain_rg -l -i "tags:.*$tag" || true)
		done
		IFS=$' \t\n'

		if [[ ${#related_slugs[@]} -gt 0 ]]; then
			echo
			log_info "Found ${#related_slugs[@]} related memory(ies) with shared tags:"
			for r in "${related_slugs[@]}"; do
				local rfile
				rfile=$(find "$BRAIN_DIR" -name "${r}.md" 2>/dev/null | head -1)
				local r_title
				r_title=$(_brain_title "$rfile")
				printf "    ${D_GREEN}•${D_NC} %s\n" "${r_title:-$r}"
			done
			read_confirm "Link these relations?" link_confirm
			if [[ "$link_confirm" != "y" ]]; then
				related_slugs=()
			fi
		fi
	fi

	# ── Build related string ──
	local related_str=""
	if [[ ${#related_slugs[@]} -gt 0 ]]; then
		related_str=$(IFS=,; echo "${related_slugs[*]}")
	fi

	# ── Write file ──
	mkdir -p "$BRAIN_DIR/$category"
	local filepath="$BRAIN_DIR/$category/${date_prefix}_${slug}.md"
	if [[ -e "$filepath" ]]; then
		log_error "A memory with this title already exists today: ${date_prefix}_${slug}.md"
		return 1
	fi

	{
		_brain_frontmatter "$title" "$tags_formatted" "$category" "$related_str"
		echo
		echo "$content"
	} >"$filepath"

	# ── Write reverse relations ──
	if [[ -n "$related_str" ]]; then
		local IFS=','
		for rslug in $related_str; do
			rslug=$(echo "$rslug" | xargs)
			local rfile
			rfile=$(find "$BRAIN_DIR" -name "${rslug}.md" 2>/dev/null | head -1)
			if [[ -n "$rfile" ]]; then
				_brain_update_related "$rfile" "${date_prefix}_${slug}"
			fi
		done
		IFS=$' \t\n'
	fi

	echo
	log_success "Memory saved to ${D_CYAN}$category/${date_prefix}_${slug}.md${D_NC}"

	if command -v glow &>/dev/null; then
		read_confirm "Preview with glow?" preview
		if [[ "$preview" == "y" ]]; then
			glow "$filepath"
		fi
	fi

	echo
}

# ── Add (non-interactive) ───────────────────────────────────

brain_add() {
	_brain_ensure || return 1

	if [[ $# -lt 1 ]]; then
		log_error "Usage: karnel brain add \"your text\" [--title T] [--category C] [--tags a,b]"
		return 1
	fi

	local title="" category="" tags_input=""
	local -a content_parts=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--title | -t)
			title="$2"
			shift 2
			;;
		--category | -c)
			category="$2"
			shift 2
			;;
		--tags)
			tags_input="$2"
			shift 2
			;;
		--)
			shift
			content_parts+=("$*")
			break
			;;
		*)
			content_parts+=("$1")
			shift
			;;
		esac
	done

	local text
	text=$(echo "${content_parts[*]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	if [[ -z "$text" ]]; then
		log_error "Memory text cannot be empty"
		return 1
	fi

	if [[ -z "$title" ]]; then
		title=$(echo "$text" | head -1 | cut -c1-60)
	fi
	if [[ -z "$title" ]]; then
		title="memory-$(date +%Y%m%d-%H%M%S)"
	fi

	if [[ -z "$category" ]]; then
		category="general"
	fi
	category=$(_brain_slug "$category")

	local tags_formatted=""
	if [[ -n "$tags_input" ]]; then
		tags_formatted=$(echo "$tags_input" | sed 's/, */, /g' | sed 's/^, \|, $//g')
	fi

	local slug date_prefix
	slug=$(_brain_slug "$title")
	date_prefix=$(date +%Y-%m-%d)

	mkdir -p "$BRAIN_DIR/$category"
	local filepath="$BRAIN_DIR/$category/${date_prefix}_${slug}.md"
	if [[ -e "$filepath" ]]; then
		log_error "A memory with this title already exists today: ${date_prefix}_${slug}.md"
		return 1
	fi

	{
		_brain_frontmatter "$title" "$tags_formatted" "$category" ""
		echo
		echo "$text"
	} >"$filepath"

	echo
	log_success "Memory saved to ${D_CYAN}$category/${date_prefix}_${slug}.md${D_NC}"
	echo
}

# ── Search ──────────────────────────────────────────────────

brain_search() {
	_brain_ensure || return 1

	local query="$*"
	if [[ -z "$query" ]]; then
		read_input "Search query" query
	fi
	if [[ -z "$query" ]]; then
		return 0
	fi

	separator
	box "Search: $query"
	separator
	echo

	local -a results=()
	while IFS=':' read -r file line content; do
		results+=("$file|$line|$content")
	done < <(_brain_rg -i "$query" || true)

	if [[ ${#results[@]} -eq 0 ]]; then
		log_warn "No results for: $query"
		return 0
	fi

	local total=${#results[@]}
	log_info "Found $total match(es):"
	echo

	local -a menu_files=()
	local -a menu_titles=()
	local idx=0
	for result in "${results[@]}"; do
		local f ln text
		f=$(echo "$result" | cut -d'|' -f1)
		ln=$(echo "$result" | cut -d'|' -f2)
		text=$(echo "$result" | cut -d'|' -f3-)
		local relative="${f#$BRAIN_DIR/}"
		local title
		title=$(_brain_title "$f")

		# Only show unique files in menu
		local seen=false
		for mf in "${menu_files[@]}"; do
			[[ "$mf" == "$f" ]] && seen=true && break
		done
		if ! $seen; then
			menu_files+=("$f")
			menu_titles+=("$title")
			printf "    ${D_GREEN}%2d.${D_NC} ${D_CYAN}%s${D_NC}\n" $((idx + 1)) "$title"
			((idx++))
		fi
	done

	echo
	read_input "Open memory (# or name)" pick

	if [[ -z "$pick" ]]; then
		return 0
	fi

	local selected_file=""
	if [[ "$pick" =~ ^[0-9]+$ ]] && ((pick >= 1 && pick <= ${#menu_files[@]})); then
		selected_file="${menu_files[$((pick - 1))]}"
	else
		for i in "${!menu_titles[@]}"; do
			if echo "${menu_titles[$i]}" | grep -qi "$pick"; then
				selected_file="${menu_files[$i]}"
				break
			fi
		done
	fi

	if [[ -z "$selected_file" ]] || [[ ! -f "$selected_file" ]]; then
		log_error "Memory not found"
		return 1
	fi

	echo
	if command -v glow &>/dev/null; then
		glow "$selected_file"
	else
		cat "$selected_file"
	fi

	echo
}

# ── List ─────────────────────────────────────────────────────

brain_ls() {
	_brain_ensure || return 1

	local filter="$*"

	separator
	box "Your Memories"
	separator
	echo

	local total=0
	local dirs

	if [[ -n "$filter" ]]; then
		dirs="$BRAIN_DIR/$filter"
		if [[ ! -d "$dirs" ]]; then
			log_warn "Category not found: $filter"
			return 1
		fi
	else
		dirs=$(find "$BRAIN_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".git" 2>/dev/null | sort)
		if [[ -z "$dirs" ]]; then
			echo -e "    ${GRAY}No memories yet${D_NC}"
			echo
			list_item "Add one: ${D_CYAN}karnel brain save${D_NC}"
			return 0
		fi
	fi

	while IFS= read -r dir; do
		local category
		category=$(basename "$dir")
		local files
		files=$(find "$dir" -maxdepth 1 -name "*.md" ! -name "README.md" 2>/dev/null | sort -r)

		if [[ -z "$files" ]]; then
			continue
		fi

		if [[ -z "$filter" ]]; then
			echo
			separator_section "$category"
			echo
		fi

		while IFS= read -r file; do
			local title
			title=$(_brain_title "$file")
			local tags_line
			tags_line=$(grep "^tags:" "$file" 2>/dev/null | sed 's/tags: \[//;s/\]//;s/, /, /g')
			printf "    ${D_GREEN}•${D_NC} %s\n" "$title"
			if [[ -n "$tags_line" ]]; then
				printf "      ${D_DIM}%s${D_NC}\n" "$tags_line"
			fi
			((total++))
		done <<<"$files"
	done <<<"$dirs"

	echo
	separator
	list_item "$total memory(ies)"
	separator
}

# ── Relate ──────────────────────────────────────────────────

brain_relate() {
	_brain_ensure || return 1

	local slug_a="$1"
	local slug_b="$2"
	local file_a="" file_b=""

	if [[ -z "$slug_a" ]] || [[ -z "$slug_b" ]]; then
		separator
		box "Relate Memories"
		separator
		echo
		log_info "Pick the first memory:"
		echo
		file_a=$(_brain_pick_file "First memory (# or name)")
		[[ -z "$file_a" ]] && return 0

		echo
		log_info "Pick the second memory:"
		echo
		file_b=$(_brain_pick_file "Second memory (# or name)")
		[[ -z "$file_b" ]] && return 0
	else
		file_a=$(_brain_find_memory "$slug_a")
		file_b=$(_brain_find_memory "$slug_b")

		if [[ -z "$file_a" ]]; then
			log_error "Memory not found: $slug_a"
			return 1
		fi
		if [[ -z "$file_b" ]]; then
			log_error "Memory not found: $slug_b"
			return 1
		fi
	fi

	echo
	slug_a=$(basename "$file_a" .md)
	slug_b=$(basename "$file_b" .md)

	_brain_update_related "$file_a" "$slug_b"
	_brain_update_related "$file_b" "$slug_a"

	log_success "Linked ${D_CYAN}$(_brain_title "$file_a")${D_NC} ↔ ${D_CYAN}$(_brain_title "$file_b")${D_NC}"
	echo
}

# ── Show ─────────────────────────────────────────────────────

_brain_show_relations() {
	local file="$1"
	local related
	related=$(grep "^related:" "$file" 2>/dev/null | sed 's/related: \[//;s/\]//')
	[[ -z "$related" ]] && return

	echo -e "    ${D_GRAY}──${D_NC} ${GRAY}Related${NC}"
	local IFS=','
	for r in $related; do
		r=$(echo "$r" | xargs)
		[[ -z "$r" ]] && continue
		local rfile
		rfile=$(find "$BRAIN_DIR" -name "${r}.md" 2>/dev/null | head -1)
		if [[ -n "$rfile" ]]; then
			local rtitle
			rtitle=$(_brain_title "$rfile")
			printf "    ${D_GREEN}•${D_NC} %s\n" "$rtitle"
		fi
	done
	IFS=$' \t\n'
}

brain_show() {
	_brain_ensure || return 1

	local slug="$1"
	local file=""

	if [[ -n "$slug" ]]; then
		file=$(_brain_find_memory "$slug")
		if [[ -z "$file" ]]; then
			log_error "Memory not found: $slug"
			return 1
		fi
	else
		echo
		separator_section "Show Memory"
		echo
		file=$(_brain_pick_file "Memory to show (# or name)")
		[[ -z "$file" ]] && return 0
	fi

	echo
	if command -v glow &>/dev/null; then
		glow "$file"
	else
		cat "$file"
	fi

	_brain_show_relations "$file"
	echo
}

# ── Graph ────────────────────────────────────────────────────

brain_graph() {
	_brain_ensure || return 1

	echo
	separator_section "Knowledge Graph"
	echo

	local -a files=()
	while IFS= read -r f; do
		files+=("$f")
	done < <(find "$BRAIN_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | sort)

	if [[ ${#files[@]} -eq 0 ]]; then
		list_item "No memories yet"
		return 0
	fi

	local total_edges=0
	for f in "${files[@]}"; do
		local title
		title=$(_brain_title "$f")
		local slug
		slug=$(basename "$f" .md)
		local category
		category=$(basename "$(dirname "$f")")
		local related
		related=$(grep "^related:" "$f" 2>/dev/null | sed 's/related: \[//;s/\]//')

		printf "    ${D_CYAN}%s${NC} ${D_DIM}(%s)${D_NC}\n" "$title" "$category"

		if [[ -n "$related" ]]; then
			local IFS=','
			for r in $related; do
				r=$(echo "$r" | xargs)
				[[ -z "$r" ]] && continue
				local rfile
				rfile=$(find "$BRAIN_DIR" -name "${r}.md" 2>/dev/null | head -1)
				if [[ -n "$rfile" ]]; then
					local rtitle
					rtitle=$(_brain_title "$rfile")
					local rcat
					rcat=$(basename "$(dirname "$rfile")")
					printf "    ${GRAY}└──${NC} %s ${D_DIM}(%s)${D_NC}\n" "$rtitle" "$rcat"
					((total_edges++))
				fi
			done
			IFS=$' \t\n'
		else
			printf "    ${GRAY}└──${NC} ${D_DIM}(no relations)${D_NC}\n"
		fi
		echo
	done

	list_item "$total_edges connections across ${#files[@]} memories"
	echo
}

# ── Sync ────────────────────────────────────────────────────

brain_sync() {
	_brain_ensure || return 1

	separator
	box "Sync Brain"
	separator
	echo

	if [[ ! -d "$BRAIN_DIR/.git" ]]; then
		log_warn "Not a git repository"
		list_item "Run: ${D_CYAN}karnel brain init${D_NC} to set up Git"
		separator
		return 1
	fi

	local branch
	branch=$(git -C "$BRAIN_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)

	if ! git -C "$BRAIN_DIR" remote get-url origin &>/dev/null; then
		log_info "No remote configured — local commit only"
		list_item "Set up GitHub sync with: ${D_CYAN}karnel brain init${D_NC}"
		separator
		return 0
	fi

	local commit_msg="brain sync $(date +%Y-%m-%d_%H:%M)"
	if [[ -n "$(git -C "$BRAIN_DIR" status --porcelain)" ]]; then
		loading "Staging changes..." git -C "$BRAIN_DIR" add -A
		loading "Committing changes..." git -C "$BRAIN_DIR" commit -m "$commit_msg"
	else
		log_info "No changes to commit"
	fi

	if ! git -C "$BRAIN_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' &>/dev/null; then
		loading "Pushing to origin/$branch..." git -C "$BRAIN_DIR" push -u origin "$branch"
		if [[ $? -eq 0 ]]; then
			log_success "Brain synced with GitHub"
		else
			log_error "Push failed"
			list_item "Check your GitHub authentication: ${D_CYAN}gh auth login${D_NC}"
		fi
		separator
		return
	fi

	loading "Pulling latest from remote..." git -C "$BRAIN_DIR" pull --rebase
	local pull_exit=$?
	if [[ $pull_exit -ne 0 ]]; then
		log_error "Pull failed — your local and remote histories diverged"
		list_item "Force push instead: ${D_CYAN}git push --force${D_NC}"
		list_item "Or resolve manually in: ${D_CYAN}$BRAIN_DIR${D_NC}"
		separator
		return 1
	fi

	loading "Pushing to remote..." git -C "$BRAIN_DIR" push
	if [[ $? -eq 0 ]]; then
		log_success "Brain synced with GitHub"
	else
		log_error "Push failed"
		list_item "Check your connection and permissions"
	fi

	separator
}

# ── Skill ───────────────────────────────────────────────────

brain_skill() {
	_brain_ensure || return 1

	local skill_name base_dir

	# ── Collect all memories ──
	local -a all_files=()
	while IFS= read -r f; do
		all_files+=("$f")
	done < <(find "$BRAIN_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | sort)

	if [[ ${#all_files[@]} -eq 0 ]]; then
		echo
		separator
		box "Create Skill from Memories"
		separator
		echo
		list_item "No memories yet"
		list_item "Create some: ${D_CYAN}karnel brain save${D_NC}"
		separator
		return 0
	fi

	# ── Pick memories (multi-select) ──
	while true; do
		echo
		separator
		box "Create Skill from Memories"
		separator
		echo

		local idx=0
		for f in "${all_files[@]}"; do
			local t
			t=$(_brain_title "$f")
			printf "    ${D_GREEN}%2d.${D_NC} %s\n" $((idx + 1)) "$t"
			((idx++))
		done

		echo
		log_info "Select memories to include in the skill"
		read_input "Numbers (comma-separated), 'all', or empty to cancel" pick

		if [[ -z "$pick" ]]; then
			return 0
		fi

		local -a selected=()

		if [[ "$pick" == "all" ]]; then
			for ((i = 0; i < ${#all_files[@]}; i++)); do
				selected+=("${all_files[$i]}")
			done
		else
			local IFS=','
			for num in $pick; do
				num=$(echo "$num" | xargs)
				if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#all_files[@]})); then
					selected+=("${all_files[$((num - 1))]}")
				fi
			done
			IFS=$' \t\n'
		fi

		# ── Expand relations ──
		local -a expanded=()
		local -a seen=()
		for f in "${selected[@]}"; do
			local slug
			slug=$(basename "$f" .md)
			# Avoid duplicates
			local dup=false
			for s in "${seen[@]}"; do
				[[ "$s" == "$slug" ]] && dup=true && break
			done
			$dup && continue
			seen+=("$slug")
			expanded+=("$f")

			# Add related memories
			local related
			related=$(grep "^related:" "$f" 2>/dev/null | sed 's/related: \[//;s/\]//')
			if [[ -n "$related" ]]; then
				local IFS=','
				for r in $related; do
					r=$(echo "$r" | xargs)
					[[ -z "$r" ]] && continue
					# Check dup
					local rdup=false
					for s in "${seen[@]}"; do
						[[ "$s" == "$r" ]] && rdup=true && break
					done
					$rdup && continue
					seen+=("$r")
					local rf
					rf=$(find "$BRAIN_DIR" -name "${r}.md" 2>/dev/null | head -1)
					[[ -n "$rf" ]] && expanded+=("$rf")
				done
				IFS=$' \t\n'
			fi
		done

		echo
		log_info "Skill will include ${#expanded[@]} memories:"
		for f in "${expanded[@]}"; do
			local et
			et=$(_brain_title "$f")
			echo -e "    ${D_GREEN}•${D_NC} $et"
		done
		echo
		read_confirm "Proceed?" confirm
		[[ "$confirm" == "y" ]] && break
	done

	# ── Skill name ──
	read_input "Skill name (kebab-case, e.g. termux-setup)" skill_name
	skill_name=$(echo "$skill_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')
	if [[ -z "$skill_name" ]]; then
		log_error "Skill name cannot be empty"
		separator
		return 1
	fi

	# ── Global or local ──
	echo
	log_info "Where do you want to install the skill?"
	read_confirm "Install globally (~/.agents/skills/)?" scope
	if [[ "$scope" == "y" ]]; then
		base_dir="$HOME/.agents/skills"
	else
		base_dir=".agents/skills"
	fi

	local skill_dir="$base_dir/$skill_name"
	if [[ -d "$skill_dir" ]]; then
		log_warn "Skill already exists: $skill_dir"
		read_confirm "Overwrite?" confirm n
		[[ "$confirm" != "y" ]] && return 0
		rm -rf "$skill_dir"
	fi

	mkdir -p "$skill_dir/memories"
	log_success "Creating skill: ${D_CYAN}$skill_name${D_NC}"

	# ── Generate SKILL.md ──
	local description="Skill generated from brain memories"
	local trigger="Use when the user asks about: "
	local first=true
	for f in "${expanded[@]}"; do
		local ft
		ft=$(_brain_title "$f")
		if $first; then
			trigger+="$ft"
			first=false
		else
			trigger+=", $ft"
		fi
	done

	{
		echo "---"
		echo "name: $skill_name"
		echo "description: $description"
		echo "trigger: $trigger"
		echo "---"
		echo
		echo "# $skill_name"
		echo
		echo "Skill created from the following brain memories:"
		echo
		for f in "${expanded[@]}"; do
			local ftag ftags
			ft=$(_brain_title "$f")
			ftags=$(grep "^tags:" "$f" 2>/dev/null | sed 's/tags: \[//;s/\]//')
			echo "## $ft"
			[[ -n "$ftags" ]] && echo "Tags: $ftags"
			echo
			# Include body after frontmatter
			local in_fm=false
			while IFS= read -r line; do
				if [[ "$line" == "---" ]]; then
					if $in_fm; then in_fm=false; continue; fi
					in_fm=true; continue
				fi
				$in_fm && continue
				echo "$line"
			done <"$f" | tail -n +2
			echo
			echo "---"
			echo
		done
	} >"$skill_dir/SKILL.md"

	# ── Link individual memory files ──
	local midx=1
	for f in "${expanded[@]}"; do
		local ft ftags frel
		ft=$(_brain_title "$f")
		ftags=$(grep "^tags:" "$f" 2>/dev/null | sed 's/tags: \[//;s/\]//')
		frel=$(grep "^related:" "$f" 2>/dev/null | sed 's/related: \[//;s/\]//')
		local fname
		fname=$(printf "%02d_%s.md" "$midx" "$(basename "$f" .md | sed 's/^[0-9-]*_//')")
		{
			echo "---"
			echo "title: $ft"
			[[ -n "$ftags" ]] && echo "tags: [$ftags]"
			[[ -n "$frel" ]] && echo "related: [$frel]"
			echo "---"
			echo
			# Copy body
			local in_fm=false
			while IFS= read -r line; do
				if [[ "$line" == "---" ]]; then
					if $in_fm; then in_fm=false; continue; fi
					in_fm=true; continue
				fi
				$in_fm && continue
				echo "$line"
			done <"$f"
		} >"$skill_dir/memories/$fname"
		((midx++))
	done

	log_success "Skill created: ${D_CYAN}$skill_dir${D_NC}"
	list_item "Your agent will load it automatically"
	separator
}

# ── Edit ─────────────────────────────────────────────────────

brain_edit() {
	_brain_ensure || return 1

	local slug="$1"
	local file=""

	if [[ -n "$slug" ]]; then
		file=$(_brain_find_memory "$slug")
		if [[ -z "$file" ]]; then
			log_error "Memory not found: $slug"
			return 1
		fi
	else
		echo
		separator_section "Edit Memory"
		echo
		file=$(_brain_pick_file "Memory to edit (# or name)")
	fi

	if [[ -z "$file" ]]; then
		return 0
	fi

	local -a editor_cmd=()
	read -r -a editor_cmd <<< "${EDITOR:-nano}"
	if ! command -v "${editor_cmd[0]}" &>/dev/null; then
		for e in vim nano vi; do
			if command -v "$e" &>/dev/null; then
				editor_cmd=("$e")
				break
			fi
		done
	fi

	if [[ ${#editor_cmd[@]} -eq 0 ]] || ! command -v "${editor_cmd[0]}" &>/dev/null; then
		log_error "No editor found"
		list_item "Install one: ${D_CYAN}karnel install editor${D_NC}"
		return 1
	fi

	echo
	log_info "Opening: ${D_CYAN}$(_brain_title "$file")${D_NC}"

	"${editor_cmd[@]}" "$file"

	log_success "Memory updated"
	echo
}

# ── Delete ───────────────────────────────────────────────────

brain_delete() {
	_brain_ensure || return 1

	local slug="$1"
	local file=""

	if [[ -n "$slug" ]]; then
		file=$(_brain_find_memory "$slug")
		if [[ -z "$file" ]]; then
			log_error "Memory not found: $slug"
			return 1
		fi
	else
		echo
		separator_section "Delete Memory"
		echo
		file=$(_brain_pick_file "Memory to delete (# or name)")
	fi

	if [[ -z "$file" ]]; then
		return 0
	fi

	local title
	title=$(_brain_title "$file")
	echo
	log_warn "Delete memory: ${D_CYAN}$title${D_NC}?"
	read_confirm "This cannot be undone" confirm n
	if [[ "$confirm" != "y" ]]; then
		log_info "Cancelled"
		return 0
	fi

	# Remove relations from related files
	local file_slug escaped_slug
	file_slug=$(basename "$file" .md)
	escaped_slug=$(_brain_slug_escape "$file_slug")
	while IFS= read -r rfile; do
		_brain_remove_related "$rfile" "$file_slug"
	done < <(_brain_rg -l "related:.*${escaped_slug}" || true)

	if [[ "$file" != "$BRAIN_DIR"/* ]]; then
		log_error "Refusing to delete file outside brain directory"
		return 1
	fi
	rm "$file"
	log_success "Deleted: ${D_CYAN}$title${D_NC}"

	# Clean up empty category directory
	local dir
	dir=$(dirname "$file")
	if [[ -z "$(find "$dir" -name '*.md' ! -name 'README.md' 2>/dev/null)" ]]; then
		rmdir "$dir" 2>/dev/null || true
		list_item "Empty category directory removed"
	fi

	echo
}

# ── Reset ────────────────────────────────────────────────────

brain_reset() {
	separator
	box "Reset Brain"
	separator
	echo

	if [[ ! -d "$BRAIN_DIR" ]]; then
		log_warn "Brain does not exist"
		separator
		return 0
	fi

	log_warn "This will DESTROY all local memories:"
	list_item "Location: ${D_CYAN}$BRAIN_DIR${D_NC}"
	echo

	read_confirm "Are you sure?" confirm n
	if [[ "$confirm" != "y" ]]; then
		log_info "Cancelled"
		separator
		return 0
	fi

	echo
	if [[ -z "$BRAIN_DIR" ]] || [[ "$BRAIN_DIR" == "/" ]]; then
		log_error "BRAIN_DIR is not set correctly, aborting"
		return 1
	fi
	loading "Deleting local brain..." rm -rf "$BRAIN_DIR"
	log_success "Brain destroyed"
	list_item "Recreate with: ${D_CYAN}karnel brain init${D_NC}"
	separator
}

# ── Dashboard ────────────────────────────────────────────────

brain_dashboard() {
	if [[ ! -d "$BRAIN_DIR" ]]; then
		brain_help
		return
	fi

	echo
	separator_section "Karnel Brain Dashboard"
	echo

	local total_files
	total_files=$(find "$BRAIN_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | wc -l)
	local total_categories
	total_categories=$(find "$BRAIN_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".git" 2>/dev/null | wc -l)
	local has_git=false
	[[ -d "$BRAIN_DIR/.git" ]] && has_git=true

	printf "    ${D_CYAN}%-20s${NC} ${GRAY}=${NC} %s\n" "Memories" "$total_files"
	printf "    ${D_CYAN}%-20s${NC} ${GRAY}=${NC} %s\n" "Categories" "$total_categories"
	printf "    ${D_CYAN}%-20s${NC} ${GRAY}=${NC} %s\n" "Git" "$($has_git && echo '✓' || echo '✗')"
	printf "    ${D_CYAN}%-20s${NC} ${GRAY}=${NC} ${D_DIM}%s${D_NC}\n" "Location" "$BRAIN_DIR"
	echo

	separator_section "Quick Start"
	echo
	list_item "Save: ${D_CYAN}karnel brain save${D_NC}"
	list_item "Show: ${D_CYAN}karnel brain show${D_NC}"
	list_item "Search: ${D_CYAN}karnel brain search${D_NC}"
	list_item "Edit: ${D_CYAN}karnel brain edit${D_NC}"
	list_item "Delete: ${D_CYAN}karnel brain delete${D_NC}"
	list_item "Reset: ${D_CYAN}karnel brain reset${D_NC}"
	list_item "Graph: ${D_CYAN}karnel brain graph${D_NC}"
	list_item "Skill: ${D_CYAN}karnel brain skill${D_NC}"
	list_item "Sync: ${D_CYAN}karnel brain sync${D_NC}"
	list_item "Ask: ${D_CYAN}karnel brain ask <pregunta>${D_NC}"
	echo
}

_run_ai_query() {
	local ai_cmd="$1"
	local full_prompt="$2"
	local default_model="$3"
	local out_file="$4"

	if [[ "$ai_cmd" == "gemini" ]]; then
		gemini -p "$full_prompt" >"$out_file" 2>&1
	elif [[ "$ai_cmd" == "opencode" ]]; then
		opencode run "$full_prompt" >"$out_file" 2>&1
	elif [[ "$ai_cmd" == "claude" ]]; then
		claude -p "$full_prompt" >"$out_file" 2>&1
	elif [[ "$ai_cmd" == "ollama" ]]; then
		local model="$default_model"
		if [[ -z "$model" ]]; then
			model=$(ollama list 2>/dev/null | awk 'NR==2 {print $1}')
		fi
		if [[ -n "$model" ]]; then
			ollama run "$model" "$full_prompt" >"$out_file" 2>&1
		else
			echo "Ollama is installed but no local models found. Run: ollama pull llama3" >"$out_file"
			return 1
		fi
	fi
}

brain_ai_config() {
	local config_file="$KARNEL_CONFIG/ai_config.json"
	mkdir -p "$KARNEL_CONFIG"
	if [[ ! -f "$config_file" ]]; then
		cat >"$config_file" <<'EOF'
{
  "provider": "auto",
  "default_model": "",
  "context_max_size": 4000,
  "cache_enabled": true,
  "only_memories": false
}
EOF
	fi

	if [[ $# -eq 0 ]]; then
		separator
		box "Brain AI Configuration"
		separator
		echo
		if command -v jq &>/dev/null; then
			jq . "$config_file"
		else
			cat "$config_file"
		fi
		echo
		log_info "Configure variables using: karnel brain config <key> <value>"
		list_item "Keys: provider, default_model, context_max_size, cache_enabled, only_memories"
		separator
		return 0
	fi

	local key="$1"
	local val="$2"

	if [[ -z "$val" ]]; then
		log_error "Value required. Usage: karnel brain config <key> <value>"
		return 1
	fi

	if command -v jq &>/dev/null; then
		local temp
		temp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")
		if [[ "$val" == "true" ]] || [[ "$val" == "false" ]]; then
			jq --argjson v "$val" ".${key} = \$v" "$config_file" > "$temp" && mv "$temp" "$config_file"
		elif [[ "$val" =~ ^[0-9]+$ ]]; then
			jq --argjson v "$val" ".${key} = \$v" "$config_file" > "$temp" && mv "$temp" "$config_file"
		else
			jq --arg v "$val" ".${key} = \$v" "$config_file" > "$temp" && mv "$temp" "$config_file"
		fi
		log_success "Updated config: $key = $val"
	else
		log_error "jq is required to modify config file"
		return 1
	fi
}

brain_ask() {
	_brain_ensure || return 1

	local only_memories_flag=false
	local clean_query=""
	for arg in "$@"; do
		if [[ "$arg" == "--only-memories" ]] || [[ "$arg" == "-m" ]]; then
			only_memories_flag=true
		else
			if [[ -z "$clean_query" ]]; then
				clean_query="$arg"
			else
				clean_query="$clean_query $arg"
			fi
		fi
	done

	if [[ -z "$clean_query" ]]; then
		read_input "Ask a question about your memories" clean_query
	fi
	if [[ -z "$clean_query" ]]; then
		return 0
	fi

	# Load config
	local config_file="$KARNEL_CONFIG/ai_config.json"
	mkdir -p "$KARNEL_CONFIG"
	if [[ ! -f "$config_file" ]]; then
		cat >"$config_file" <<'EOF'
{
  "provider": "auto",
  "default_model": "",
  "context_max_size": 4000,
  "cache_enabled": true,
  "only_memories": false
}
EOF
	fi

	local provider="auto"
	local default_model=""
	local context_max_size=4000
	local cache_enabled="true"
	local default_only_memories="false"

	if command -v jq &>/dev/null; then
		provider=$(jq -r '.provider // "auto"' "$config_file" 2>/dev/null)
		default_model=$(jq -r '.default_model // ""' "$config_file" 2>/dev/null)
		context_max_size=$(jq -r '.context_max_size // 4000' "$config_file" 2>/dev/null)
		cache_enabled=$(jq -r '.cache_enabled // true' "$config_file" 2>/dev/null)
		default_only_memories=$(jq -r '.only_memories // false' "$config_file" 2>/dev/null)
	fi

	if [[ "$default_only_memories" == "true" ]]; then
		only_memories_flag=true
	fi

	local -a matching_files=()
	while IFS= read -r f; do
		if [[ -n "$f" ]]; then
			matching_files+=("$f")
		fi
	done < <(_brain_rg -l -i "$clean_query" | head -n 5 || true)

	if [[ ${#matching_files[@]} -eq 0 ]]; then
		local -a words=($clean_query)
		local word_regex=""
		for w in "${words[@]}"; do
			if [[ ${#w} -gt 3 ]]; then
				if [[ -z "$word_regex" ]]; then
					word_regex="$w"
				else
					word_regex="$word_regex|$w"
				fi
			fi
		done
		if [[ -n "$word_regex" ]]; then
			while IFS= read -r f; do
				if [[ -n "$f" ]]; then
					matching_files+=("$f")
				fi
			done < <(_brain_rg -l -i -e "$word_regex" | head -n 5 || true)
		fi
	fi

	local context=""
	if [[ ${#matching_files[@]} -gt 0 ]]; then
		context="Here is some context from my personal memories:\n\n"
		for f in "${matching_files[@]}"; do
			local title
			title=$(_brain_title "$f")
			local content
			content=$(cat "$f")
			
			if (( ${#context} + ${#content} > context_max_size )); then
				local available=$(( context_max_size - ${#context} ))
				if [[ $available -gt 50 ]]; then
					content="${content:0:$available}...\n(truncated due to context limit)"
					context="${context}--- MEMORY: ${title} ---\n${content}\n\n"
				fi
				break
			else
				context="${context}--- MEMORY: ${title} ---\n${content}\n\n"
			fi
		done
	fi

	# Auto detect provider prioritizing local offline
	local ai_cmd=""
	if [[ "$provider" == "auto" ]]; then
		if command -v opencode &>/dev/null; then
			ai_cmd="opencode"
		elif command -v ollama &>/dev/null; then
			ai_cmd="ollama"
		elif command -v gemini &>/dev/null; then
			ai_cmd="gemini"
		elif command -v claude &>/dev/null; then
			ai_cmd="claude"
		fi
	else
		ai_cmd="$provider"
	fi

	if [[ -z "$ai_cmd" ]]; then
		log_warn "No AI assistant found or selected to process the query."
		log_info "Selected provider: $provider"
		log_info "Please install an AI assistant first (e.g. karnel install ai --opencode)"
		return 1
	fi

	local system_prompt=""
	if [[ "$only_memories_flag" == "true" ]]; then
		system_prompt="INSTRUÇÃO CRÍTICA: Responda a pergunta do usuário baseando-se UNICAMENTE e EXCLUSIVAMENTE nas memórias fornecidas acima. Se as memórias não contiverem a informação necessária para responder à pergunta, responda exatamente com: 'Não encontrei nenhuma memória relacionada a isso.' e nada mais. Não invente nenhuma informação fora do contexto.\n\n"
	fi

	local cache_dir="$KARNEL_CACHE/brain_ai_cache"
	mkdir -p "$cache_dir"
	local cache_key
	cache_key=$(echo -n "${only_memories_flag}_${context}_${clean_query}" | sha256sum | cut -d' ' -f1)
	local cache_file="$cache_dir/${cache_key}.txt"

	if [[ "$cache_enabled" == "true" ]] && [[ -f "$cache_file" ]]; then
		log_success "Response retrieved from cache (offline):"
		echo
		cat "$cache_file"
		echo
		return 0
	fi

	local full_prompt="${context}${system_prompt}Based on the context, answer the following question: ${clean_query}"
	log_info "Asking AI ($ai_cmd) with brain context..."
	echo

	local ai_response_temp
	ai_response_temp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")

	if loading "Generating AI response" _run_ai_query "$ai_cmd" "$full_prompt" "$default_model" "$ai_response_temp"; then
		echo
		cat "$ai_response_temp"
		echo
		if [[ "$cache_enabled" == "true" ]]; then
			cp "$ai_response_temp" "$cache_file"
		fi
	else
		echo
		log_error "AI query failed:"
		cat "$ai_response_temp"
		echo
		rm -f "$ai_response_temp"
		return 1
	fi
	rm -f "$ai_response_temp"
}

# ── Main dispatcher ──────────────────────────────────────────

brain_main() {
	local cmd="$1"
	shift || true

	case "$cmd" in
	init)
		brain_init
		;;
	save)
		brain_save
		;;
	add)
		brain_add "$@"
		;;
	search)
		brain_search "$@"
		;;
	ask)
		brain_ask "$@"
		;;
	config | ai-config)
		brain_ai_config "$@"
		;;
	ls | list)
		brain_ls "$@"
		;;
	edit)
		brain_edit "$@"
		;;
	delete | rm)
		brain_delete "$@"
		;;
	reset | destroy)
		brain_reset
		;;
	relate)
		brain_relate "$@"
		;;
	show | view)
		brain_show "$@"
		;;
	dashboard | dash | stats)
		brain_dashboard
		;;
	graph | map)
		brain_graph
		;;
	skill | skills)
		brain_skill
		;;
	sync)
		brain_sync
		;;
	"" | --help | -h)
		brain_help
		;;
	*)
		log_error "Unknown subcommand: $cmd"
		echo
		brain_help
		return 1
		;;
	esac
}
