#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

# Tools live in tools/<module>/<tool>/ with a README whose first line is the
# display name and whose first paragraph is the description. Deriving the
# search index from the filesystem keeps it in sync with the registries
# automatically instead of relying on a single registry's field format.
_karnel_search_catalog() {
  local dir
  local -a readmes=()
  for dir in "$KARNEL_PATH/tools"/*/*/; do
    [[ -f "$dir/install.sh" && -f "$dir/README.md" ]] || continue
    readmes+=("${dir%/}/README.md")
  done
  ((${#readmes[@]} > 0)) || return 0

  # Single awk pass: spawning a process per tool is prohibitively slow on
  # Android shared storage.
  awk '
    FILENAME != previous {
      if (previous != "") emit()
      previous = FILENAME
      name = ""
      desc = ""
      titled = 0
    }
    FNR == 1 && !titled {
      line = $0
      sub(/^#+[ \t]*/, "", line)
      name = line
      titled = 1
      next
    }
    desc == "" && FNR > 1 && $0 ~ /^[^#[:space:]]/ { desc = $0 }
    function emit(   count, parts) {
      count = split(previous, parts, "/")
      printf "%s\t%s\t%s\t%s\n", parts[count - 2], parts[count - 1], name, desc
    }
    END { if (previous != "") emit() }
  ' "${readmes[@]}"
}

search_main() {
  local query="$*"
  if [[ -z "$query" ]]; then
    echo
    box "◈ KARNEL SEARCH ◈"
    echo
    log_info "Search across all tools and brain memories"
    echo
    log_info "Usage: karnel search <query>"
    echo
    return
  fi

  echo
  box "◈ Search: $query ◈"
  echo

  local any_found=false
  local module tool name desc

  separator_section "Tools"
  echo
  while IFS=$'\t' read -r module tool name desc; do
    if printf '%s\n%s\n%s' "$tool" "$name" "$desc" | grep -Fqi -- "$query"; then
      list_item "${D_CYAN}$module${NC}: $name ($tool)"
      any_found=true
    fi
  done < <(_karnel_search_catalog | sort)
  if ! $any_found; then
    log_info "No tools found matching '$query'"
  fi

  echo
  separator_section "Brain Memories"
  echo
  any_found=false
  if [[ -d "$KARNEL_DATA/brain" ]]; then
    while IFS= read -r file; do
      local title
      title=$(head -1 "$file" 2>/dev/null | sed 's/^# //')
      list_item "${D_CYAN}$(basename "$file")${NC}: ${title:-$file}"
      any_found=true
    done < <(grep -rFil -- "$query" "$KARNEL_DATA/brain" 2>/dev/null)
    if ! $any_found; then
      log_info "No memories found matching '$query'"
    fi
  else
    log_info "Brain not initialized (run 'karnel brain init')"
  fi

  echo
}
