#!/usr/bin/env bash
set -euo pipefail

command -v shellcheck &>/dev/null || {
  printf 'shellcheck is required\n' >&2
  exit 1
}

scripts=()
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
  file_list=$(git ls-files -co --exclude-standard)
else
  file_list=$(find . -type f \( -name '*.sh' -o -name '*.bash' \) ! -path './node_modules/*' ! -path './.git/*')
fi
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  first_line=""
  IFS= read -r first_line < "$file" || true
  case "$file:$first_line" in
    *.sh:*|*.bash:*|*:'#!/usr/bin/env bash'*|*:'#!/bin/bash'*|*:'#!/data/data/com.termux/files/usr/bin/bash'*)
      scripts+=("$file")
      ;;
  esac
done <<< "$file_list"

# -x lets shellcheck follow `source`/`# shellcheck source=` into files that are
# already part of the input set instead of failing with "was not specified as
# input"; -P SCRIPTDIR keeps those relative resolutions anchored to each script
# rather than to the caller's working directory, which made the run's outcome
# depend on how the suite was invoked (npm run vs. a direct bash call).
shellcheck --severity=error -x -P SCRIPTDIR "${scripts[@]}"
printf 'ShellCheck: %d Bash script(s), error gate clean\n' "${#scripts[@]}"
