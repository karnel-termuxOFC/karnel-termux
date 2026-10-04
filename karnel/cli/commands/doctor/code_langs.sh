#!/usr/bin/env bash

declare -g _LANG_SETUP=""

_init_lang_tools() {
  [[ -n "$_LANG_SETUP" ]] && return
  _LANG_SETUP=1
  declare -gA LANG_TOOLS

  # JavaScript
  LANG_TOOLS["JavaScript:eslint"]="eslint|lint|npx --no-install eslint .|npx --no-install eslint . --fix|safe|native"
  LANG_TOOLS["JavaScript:prettier"]="prettier|format|npx --no-install prettier . --check|npx --no-install prettier . --write|safe|native"
  LANG_TOOLS["JavaScript:npm_audit"]="npm audit|deps|npm audit --audit-level=high|||native"
  LANG_TOOLS["JavaScript:vitest"]="vitest|test|npx --no-install vitest run|||native"
  LANG_TOOLS["JavaScript:jest"]="jest|test|npx --no-install jest|||native"
  LANG_TOOLS["JavaScript:markdownlint"]="markdownlint-cli2|docs|npx --no-install markdownlint-cli2 \"**/*.md\"|npx --no-install markdownlint-cli2 --fix \"**/*.md\"|safe|native"

  # TypeScript
  LANG_TOOLS["TypeScript:tsc"]="tsc|type-check|npx --no-install tsc --noEmit|||native"
  LANG_TOOLS["TypeScript:biome"]="biome|lint+format|npx --no-install biome check .|npx --no-install biome check --write .|safe|native"
  LANG_TOOLS["TypeScript:eslint"]="eslint|lint|npx --no-install eslint . --ext .ts,.tsx|npx --no-install eslint . --ext .ts,.tsx --fix|safe|native"
  LANG_TOOLS["TypeScript:prettier"]="prettier|format|npx --no-install prettier . --check|npx --no-install prettier . --write|safe|native"

  # Python
  LANG_TOOLS["Python:compileall"]="python|syntax|python -c 'import ast,pathlib; [ast.parse(p.read_text(encoding=\"utf-8\"), filename=str(p)) for p in pathlib.Path(\".\").rglob(\"*.py\") if not any(part in p.parts for part in (\"node_modules\", \".venv\", \"venv\", \"__pycache__\"))]'|||native"
  LANG_TOOLS["Python:ruff"]="ruff|lint+format|ruff check .|ruff check . --fix|safe|native"
  LANG_TOOLS["Python:ruff_format"]="ruff|format|ruff format --check .|ruff format .|safe|native"
  LANG_TOOLS["Python:pyright"]="pyright|type-check|pyright|||community"
  LANG_TOOLS["Python:mypy"]="mypy|type-check|mypy .|||community"
  LANG_TOOLS["Python:bandit"]="bandit|security|bandit -r . -x 'node_modules,.venv,venv,__pycache__'|||community"
  LANG_TOOLS["Python:pip_audit"]="pip-audit|deps|pip-audit|||community"
  LANG_TOOLS["Python:pytest"]="pytest|test|python -m pytest|||native"
  LANG_TOOLS["Python:pytest_cov"]="pytest-cov|coverage|python -m pytest --cov=. --cov-report=term-missing|||community"
  LANG_TOOLS["Python:vulture"]="vulture|dead-code|vulture . --exclude 'node_modules,.venv,venv,__pycache__'|||community"
  LANG_TOOLS["Python:radon"]="radon|complexity|radon cc . -s -a --exclude 'node_modules,.venv,venv,__pycache__'|||community"

  # Shell
  LANG_TOOLS["Shell:bash_syntax"]="bash|syntax|bash -n {}|||native"
  LANG_TOOLS["Shell:zsh_syntax"]="zsh|syntax|zsh -n {}|||native"
  LANG_TOOLS["Shell:shellcheck"]="shellcheck|lint|shellcheck {}|||community"
  LANG_TOOLS["Shell:shfmt"]="shfmt|format|shfmt -d {}|shfmt -w {}|safe|community"
  LANG_TOOLS["Shell:checkmake"]="checkmake|build|checkmake Makefile|||community"

  # SQL
  LANG_TOOLS["SQL:sqlfluff"]="sqlfluff|lint|sqlfluff lint {} --dialect ansi|sqlfluff fix {} --dialect ansi|safe|community"

  # Go
  LANG_TOOLS["Go:gofmt"]="gofmt|format|while IFS= read -r -d '' file; do gofmt -d \"\$file\"; done < <(find . -type f -name '*.go' -not -path './vendor/*' -print0)|while IFS= read -r -d '' file; do gofmt -w \"\$file\"; done < <(find . -type f -name '*.go' -not -path './vendor/*' -print0)|safe|official"
  LANG_TOOLS["Go:go_vet"]="go vet|lint|go vet ./...|||official"
  LANG_TOOLS["Go:staticcheck"]="staticcheck|lint|staticcheck ./...|||community"
  LANG_TOOLS["Go:govulncheck"]="govulncheck|deps|govulncheck ./...|||official"
  LANG_TOOLS["Go:go_test"]="go test|test|go test ./...|||official"

  # Rust
  LANG_TOOLS["Rust:cargo_check"]="cargo|syntax|cargo check --all-targets --all-features 2>&1 | tail -5|||official"
  LANG_TOOLS["Rust:rustfmt"]="rustfmt|format|cargo fmt --all -- --check|cargo fmt --all|safe|official"
  LANG_TOOLS["Rust:clippy"]="clippy|lint|cargo clippy --all-targets --all-features -- -D warnings|cargo clippy --fix --allow-dirty|safe|official"
  LANG_TOOLS["Rust:cargo_test"]="cargo test|test|cargo test --all-features|||official"
  LANG_TOOLS["Rust:cargo_audit"]="cargo-audit|deps|cargo audit|||community"

  # C/C++
  LANG_TOOLS["C/C++:clang_syntax"]="clang|syntax|clang -fsyntax-only -Wall {} 2>&1 | head -20|||official"
  LANG_TOOLS["C/C++:clang_format"]="clang-format|format|clang-format --dry-run --Werror {}|clang-format -i {}|safe|official"
  LANG_TOOLS["C/C++:clang_tidy"]="clang-tidy|lint|clang-tidy {} -- -std=c17 2>&1 | head -20|||official"

  # Java
  LANG_TOOLS["Java:javac"]="javac|syntax|javac -d \"${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}\" -Xlint:all {} 2>&1 | head -10|||official"

  # Docker
  LANG_TOOLS["Docker:hadolint"]="hadolint|lint|hadolint Dockerfile|||community"
  LANG_TOOLS["Docker:docker_compose"]="docker compose|syntax|docker compose config -q|||official"

  # Terraform
  LANG_TOOLS["Terraform:terraform_fmt"]="terraform|format|terraform fmt -check -recursive|terraform fmt -recursive|safe|official"
  LANG_TOOLS["Terraform:terraform_validate"]="terraform|syntax|terraform validate|||official"
  LANG_TOOLS["Terraform:tflint"]="tflint|lint|tflint --recursive|||community"

  # PHP
  LANG_TOOLS["PHP:php_lint"]="php|syntax|php -l {}|||official"
  LANG_TOOLS["PHP:phpstan"]="phpstan|type-check|phpstan analyse --no-progress 2>&1 | tail -20|||community"
  LANG_TOOLS["PHP:phpunit"]="phpunit|test|phpunit|||community"

  # Ruby
  LANG_TOOLS["Ruby:ruby_syntax"]="ruby|syntax|ruby -c {}|||official"
  LANG_TOOLS["Ruby:rubocop"]="rubocop|lint|rubocop|rubocop -a|safe|community"

  # Dart
  LANG_TOOLS["Dart:dart_analyze"]="dart|lint|dart analyze|||official"
  LANG_TOOLS["Dart:dart_format"]="dart|format|dart format -o none --set-exit-if-changed .|dart format .|safe|official"

  # Elixir
  LANG_TOOLS["Elixir:mix_compile"]="mix|syntax|mix compile --warnings-as-errors|||official"
  LANG_TOOLS["Elixir:mix_format"]="mix|format|mix format --check-formatted|mix format|safe|official"
  LANG_TOOLS["Elixir:mix_test"]="mix|test|mix test|||official"

  # Kotlin
  LANG_TOOLS["Kotlin:detekt"]="detekt|lint|detekt|||community"
  LANG_TOOLS["Kotlin:ktlint"]="ktlint|format|ktlint --relative|ktlint --format --relative|safe|community"

  # Swift
  LANG_TOOLS["Swift:swift_build"]="swift|syntax|swift build|||official"
  LANG_TOOLS["Swift:swiftlint"]="swiftlint|lint|swiftlint lint|swiftlint --fix|safe|community"

  # Haskell
  LANG_TOOLS["Haskell:hlint"]="hlint|lint|hlint .|||community"

  # Lua
  LANG_TOOLS["Lua:luac"]="luac|syntax|luac -p {}|||official"

  # Lua
  LANG_TOOLS["Lua:selene"]="selene|lint|selene .|||community"
  LANG_TOOLS["Lua:stylua"]="stylua|format|stylua --check .|stylua .|safe|community"

  # Nix
  LANG_TOOLS["Nix:nix_flake"]="nix|syntax|nix flake check|||official"
  LANG_TOOLS["Nix:statix"]="statix|lint|statix check .|||community"

  # Julia
  LANG_TOOLS["Julia:julia_test"]="julia|test|julia --project -e 'using Pkg; Pkg.test()'|||native"

  # Zig
  LANG_TOOLS["Zig:zig_build"]="zig|syntax|zig build|||official"
  LANG_TOOLS["Zig:zig_fmt"]="zig|format|zig fmt --check .|zig fmt .|safe|official"

  # GitHub Actions
  LANG_TOOLS["GitHub Actions:actionlint"]="actionlint|lint|actionlint|||community"

  # Ansible
  LANG_TOOLS["Ansible:ansible_lint"]="ansible-lint|lint|ansible-lint|||community"

  # Cross-language tools
  LANG_TOOLS["*:yamllint"]="yamllint|lint|yamllint .|||community"
  LANG_TOOLS["*:jq_json"]="jq|syntax|jq empty {} 2>/dev/null|||native"
  LANG_TOOLS["*:xmllint"]="xmllint|syntax|xmllint --noout {} 2>&1|||official"
  LANG_TOOLS["*:trivy"]="trivy|security|trivy fs --scanners=config,vuln --quiet .|||community"
  LANG_TOOLS["*:semgrep"]="semgrep|security|semgrep --quiet 2>&1 | tail -10|||community"
}

_parse_lang_tool() {
  local entry="$1"
  local parsed_tool parsed_category parsed_run parsed_fix parsed_safety parsed_termux

  parsed_termux="${entry##*|}"
  entry="${entry%|*}"
  parsed_safety="${entry##*|}"
  entry="${entry%|*}"
  parsed_fix="${entry##*|}"
  entry="${entry%|*}"
  parsed_tool="${entry%%|*}"
  entry="${entry#*|}"
  parsed_category="${entry%%|*}"
  parsed_run="${entry#*|}"

  declare -g -a PARSED_LANG_TOOL
  PARSED_LANG_TOOL=("$parsed_tool" "$parsed_category" "$parsed_run" "$parsed_fix" "$parsed_safety" "$parsed_termux")
}

_get_lang_tools() {
  local lang="$1" mode="${2:-quick}" include_global="${3:-true}"
  _init_lang_tools
  local results=()

  for key in "${!LANG_TOOLS[@]}"; do
    local k_lang="${key%%:*}"
    [[ "$k_lang" == "*" || "$k_lang" == "$lang" ]] || continue
    [[ "$k_lang" != "*" || "$include_global" == "true" ]] || continue
    local entry="${LANG_TOOLS[$key]}"
    _parse_lang_tool "$entry"
    local category="${PARSED_LANG_TOOL[1]}"

    # Filter by mode
    case "$mode" in
      quick)
        case "$category" in
          syntax|format|lint|lint+format|type-check|test) ;;
          *) continue ;;
        esac ;;
      standard)
        case "$category" in
          syntax|format|lint|lint+format|type-check|test|security|deps|coverage|dead-code|complexity) ;;
          *) continue ;;
        esac ;;
      deep) ;; # All categories
    esac

    results+=("$entry")
  done
  printf '%s\n' "${results[@]}"
}

_tool_command() {
  local cmd="$1" file="$2"
  if [[ "$cmd" == *'{}'* ]] && [[ -n "$file" ]]; then
    local quoted_file
    printf -v quoted_file '%q' "$file"
    cmd="${cmd//\{\}/$quoted_file}"
  fi
  printf '%s\n' "$cmd"
}

_is_tool_available() {
  local tool="$1"
  case "$tool" in
    python) command -v python3 &>/dev/null || command -v python &>/dev/null ;;
    eslint|prettier|vitest|jest|markdownlint-cli2|tsc|biome)
      command -v "$tool" &>/dev/null || {
        command -v npx &>/dev/null && timeout 5 npx --no-install "$tool" --version &>/dev/null
      } ;;
    "npm audit") command -v npm &>/dev/null ;;
    "go vet"|"go test") command -v go &>/dev/null ;;
    cargo|"cargo test") command -v cargo &>/dev/null ;;
    clippy) command -v cargo &>/dev/null && cargo clippy --help &>/dev/null ;;
    rustfmt) command -v cargo &>/dev/null && cargo fmt --help &>/dev/null ;;
    "docker compose") command -v docker &>/dev/null && docker compose version &>/dev/null ;;
    pytest-cov) python -c 'import pytest_cov' &>/dev/null ;;
    pip-audit) python -m pip_audit --help &>/dev/null || command -v pip-audit &>/dev/null ;;
    *) command -v "$tool" &>/dev/null ;;
  esac
}

_run_tool_check() {
  local tool="$1" cmd="$2"
  local timeout_val="${3:-30}"
  if ! _is_tool_available "$tool"; then
    printf '%s\n' "__TOOL_NOT_FOUND__"
    return 2
  fi
  timeout "$timeout_val" bash -o pipefail -c "$cmd" 2>&1
}
