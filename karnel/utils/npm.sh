#!/usr/bin/env bash

# Shared npm invocation for Termux.
#
# Two host problems are handled here, because both make every npm-based
# `karnel install` fail on a real device:
#
# 1. Unrunnable shebang. Termux ships npm as a symlink to npm-cli.js whose
#    first line is `#!/usr/bin/env node`. Termux has no /usr, so unless the
#    package rewrote that shebang to $PREFIX/bin/env, the kernel refuses to
#    exec it and prints "bad interpreter". karnel_npm() detects the missing
#    interpreter and runs the same file through `node` directly.
#
# 2. EBADPLATFORM. Termux reports `os=android` to npm, so any package whose
#    `os` field lists only darwin/linux/win32 (freebuff, opencode-ai, ...) is
#    rejected even though it runs fine here. karnel_npm() keeps npm's
#    stdout/stderr intact and retries the exact same command with --force only
#    when npm failed with that specific platform rejection.
#
# The resolved command is exported as KARNEL_NPM_CMD so installers that need a
# raw npm-looking shell line can still route through the same resolution.

KARNEL_NPM_CMD=(npm)

# Pick the command that can actually execute npm on this host.
# Returns 0 with KARNEL_NPM_CMD set; leaves KARNEL_NPM_CMD=(npm) when nothing
# better is available.
_karnel_npm_resolve() {
  KARNEL_NPM_CMD=(npm)
  local npm_path first interpreter resolved
  npm_path="$(command -v npm 2>/dev/null)" || return 1
  [[ -e "$npm_path" ]] || return 1

  # Print line 1 with any trailing CR stripped. The `p` must not be gated on
  # the substitution, otherwise a LF-only file prints nothing at all.
  first="$(sed -n '1{s/\r$//;p}' "$npm_path" 2>/dev/null)"
  case "$first" in
    '#!'*) ;;
    *) return 0 ;;
  esac

  interpreter="${first#\#!}"
  interpreter="${interpreter%% *}"
  [[ -x "$interpreter" ]] && return 0

  resolved="$(readlink -f "$npm_path" 2>/dev/null)"
  [[ -n "$resolved" && "$resolved" == *.js && -f "$resolved" ]] || return 1
  command -v node >/dev/null 2>&1 || return 1
  KARNEL_NPM_CMD=(node "$resolved")
}

karnel_npm() {
  local err_file="" retry_file="" dir rc=0
  local -a dirs=()

  _karnel_npm_resolve || :

  [[ -n "${KARNEL_CACHE:-}" ]] && dirs+=("$KARNEL_CACHE")
  [[ -n "${TMPDIR:-}" ]] && dirs+=("$TMPDIR")
  dirs+=("${HOME:-}")

  for dir in "${dirs[@]}"; do
    [[ -n "$dir" && -d "$dir" && -w "$dir" ]] || continue
    err_file="$(mktemp "$dir/karnel-npm.XXXXXX" 2>/dev/null)" && break
    err_file=""
  done

  if [[ -z "$err_file" ]]; then
    "${KARNEL_NPM_CMD[@]}" "$@"
    return $?
  fi

  # `|| rc=$?` keeps this helper working when the caller runs with `set -e`;
  # a bare `npm ...; rc=$?` would abort before rc is captured.
  "${KARNEL_NPM_CMD[@]}" "$@" 2>"$err_file" || rc=$?
  if [[ -s "$err_file" ]]; then
    cat "$err_file" >&2
  fi

  if ((rc != 0)) && grep -q "EBADPLATFORM" "$err_file" 2>/dev/null; then
    if declare -f log_info >/dev/null 2>&1; then
      log_info "Package does not declare android support; retrying with npm --force"
    fi
    retry_file="${err_file}.retry"
    rc=0
    "${KARNEL_NPM_CMD[@]}" "$@" --force 2>"$retry_file" || rc=$?
    if [[ -s "$retry_file" ]]; then
      cat "$retry_file" >&2
    fi
    rm -f "$retry_file"
  fi

  rm -f "$err_file"
  return "$rc"
}
