#!/usr/bin/env bash
# Regression guard for the sourced banner: it must render identically in bash
# and zsh, at exactly the terminal width, as valid UTF-8, and advertise the
# real package version instead of the 4.x fallback.
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BANNER="$ROOT_DIR/karnel/utils/banner.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

export HOME="$WORK_DIR/home"
export XDG_CACHE_HOME="$WORK_DIR/cache"
mkdir -p "$HOME" "$XDG_CACHE_HOME"

pass=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
ok() { pass=$((pass + 1)); }

render() {
  local shell_name="$1" out="$2" width="$3"
  COLUMNS="$width" "$shell_name" -f -c "source '$BANNER'; _render" \
    >"$out" 2>/dev/null || true
  [[ -s "$out" ]]
}

# Validates the rendered bytes: valid UTF-8, every non-blank line exactly the
# requested width, and the version resolved from package.json.
check_render() {
  local file="$1" width="$2" shell_name="$3"
  python3 - "$file" "$width" "$shell_name" <<'PY'
import pathlib, re, sys

path, width, shell_name = sys.argv[1], int(sys.argv[2]), sys.argv[3]
raw = pathlib.Path(path).read_bytes()
ansi = re.compile(rb"\x1b\[[0-9;]*m")

problems = []
try:
    raw.decode("utf-8")
except UnicodeDecodeError as exc:
    problems.append(f"invalid UTF-8 in {shell_name}: {exc}")

seen = 0
for number, line in enumerate(raw.split(b"\n"), 1):
    clean = ansi.sub(b"", line)
    if not clean.strip():
        continue
    text = clean.decode("utf-8", "replace")
    if "\ufffd" in text:
        problems.append(f"{shell_name} line {number}: undecodable bytes")
    if len(text) != width:
        problems.append(
            f"{shell_name} line {number}: width {len(text)} != {width}: {text!r}"
        )
    seen += 1

if seen == 0:
    problems.append(f"{shell_name}: produced no output")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
PY
}

version=$(node -p "require('$ROOT_DIR/package.json').version") ||
  fail "could not read package.json version"
[[ -n "$version" ]] || fail "package.json version is empty"
ok

render bash "$WORK_DIR/bash.out" 80 || fail "bash produced an empty banner"
check_render "$WORK_DIR/bash.out" 80 bash || fail "bash banner render is malformed"
ok

if grep -q "$version" "$WORK_DIR/bash.out"; then
  ok
else
  fail "bash banner does not show v$version (stuck on the 4.x fallback?)"
fi

if command -v zsh >/dev/null 2>&1; then
  render zsh "$WORK_DIR/zsh.out" 80 || fail "zsh produced an empty banner"
  check_render "$WORK_DIR/zsh.out" 80 zsh || fail "zsh banner render is malformed"
  ok

  # The two shells must agree on colours as well as geometry: bash and zsh
  # used to disagree because indexed arrays are 0-based in one and 1-based in
  # the other.
  bash_colors=$(grep -o $'\x1b\[[0-9;]*m' "$WORK_DIR/bash.out" | sort -u)
  zsh_colors=$(grep -o $'\x1b\[[0-9;]*m' "$WORK_DIR/zsh.out" | sort -u)
  [[ "$bash_colors" == "$zsh_colors" ]] ||
    fail "bash and zsh emit different banner colours"
  ok

  if grep -q "$version" "$WORK_DIR/zsh.out"; then
    ok
  else
    fail "zsh banner does not show v$version"
  fi
else
  printf 'zsh not installed, skipping the zsh banner checks\n'
fi

# A resized terminal must not replay a stale banner: the cache key carries the
# width, and cleanup must be able to drop every width variant.
render bash "$WORK_DIR/narrow.out" 60 || fail "60-column banner is empty"
check_render "$WORK_DIR/narrow.out" 60 bash || fail "60-column banner is malformed"
ok

grep -q 'banner_cache\*' "$ROOT_DIR/karnel/cli/commands/cleanup.sh" ||
  fail "cleanup.sh does not clear the width-keyed banner cache"
ok

printf 'Banner coverage: bash%s, %d checks passed\n' \
  "$(command -v zsh >/dev/null 2>&1 && printf '+zsh')" "$pass"
