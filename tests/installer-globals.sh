#!/usr/bin/env bash
# All installers of a module are sourced into one shared shell. A variable
# assigned at file top-level by more than one installer silently collapses to
# whichever file was sourced last, so every handler of that module ends up
# using the wrong value. Identical values (per-module log files, shared
# directories) are harmless; divergent ones are a bug.
#
# Heredoc bodies are skipped: generated wrapper scripts legitimately re-declare
# their own variables at column 0.
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

pass=0
failed=0

run_test() {
  local name="$1"
  shift
    local rc=0 errexit_was_on=0
  [[ $- == *e* ]] && errexit_was_on=1
  set +e
  ( set -e; "$@" )
  rc=$?
  if (( errexit_was_on )); then set -e; fi
  if (( rc == 0 )); then
    ((pass += 1))
    printf 'ok - %s\n' "$name"
  else
    ((failed += 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

list_toplevel_assignments() {
  awk '
    {
      if (heredoc != "") {
        line = $0
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (index(line, heredoc) == 1) heredoc = ""
        next
      }
      if (match($0, /<<-?[ \t]*[\047"]?[A-Za-z_][A-Za-z_0-9]*[\047"]?/)) {
        word = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[ \t]*[\047"]?/, "", word)
        sub(/[\047"]?$/, "", word)
        heredoc = word
      }
      if ($0 ~ /^[A-Za-z_][A-Za-z_0-9]*=/) print $0
    }
  ' "$1"
}

check_module_globals() (
  local module="$1"
  local tools_dir="$ROOT_DIR/karnel/tools/$module"
  [[ -d "$tools_dir" ]] || exit 0

  local -A values=()
  local -A sources=()
  local file line name value
  for file in "$tools_dir"/*/install.sh; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      [[ "$line" == LOG_FILE=* ]] && continue
      name="${line%%=*}"
      value="${line#*=}"
      if [[ -n "${values[$name]+x}" ]]; then
        if [[ "${values[$name]}" != "$value" ]]; then
          printf 'collision in %s: %s has divergent top-level values\n  %s: %s\n  %s: %s\n' \
            "$module" "$name" "${sources[$name]}" "${values[$name]}" "$file" "$value" >&2
          exit 1
        fi
      else
        values[$name]="$value"
        sources[$name]="$file"
      fi
    done < <(list_toplevel_assignments "$file")
  done
  exit 0
)

for module_dir in "$ROOT_DIR"/karnel/tools/*/; do
  module="$(basename "$module_dir")"
  compgen -G "$module_dir*/install.sh" >/dev/null || continue
  run_test "no divergent top-level globals in module $module" check_module_globals "$module"
done

echo
echo "installer-globals: $pass passed, $failed failed"
((failed == 0))
