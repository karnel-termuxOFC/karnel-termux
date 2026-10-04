#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOLS_DIR="$ROOT_DIR/karnel/tools"

# Modules whose lifecycle is routed without a registry (see
# _route_registryless_tools in karnel/utils/tools.sh).
REGISTRYLESS=(plugins voice)

declare -A registryless=()
for module in "${REGISTRYLESS[@]}"; do
  registryless["$module"]=1
done

total_tools=0
registered_tools=0
modules_checked=0

for module_dir in "$TOOLS_DIR"/*; do
  [[ -d "$module_dir" ]] || continue
  module=${module_dir##*/}
  registry="$module_dir/all.sh"

  mapfile -t tool_dirs < <(find "$module_dir" -mindepth 1 -maxdepth 1 -type d | sort)
  tools=()
  for dir in "${tool_dirs[@]}"; do
    [[ -f "$dir/install.sh" ]] && tools+=("${dir##*/}")
  done

  if [[ ! -f "$registry" ]]; then
    [[ -n "${registryless[$module]+set}" ]] || {
      printf 'module without a registry is not allowlisted: %s\n' "$module" >&2
      exit 1
    }
    total_tools=$(( total_tools + ${#tools[@]} ))
    continue
  fi

  mapfile -t entries < <(awk '
    /^[A-Za-z_][A-Za-z0-9_]*=\(/ { in_array=1 }
    in_array { print }
    in_array && /\)/ { exit }
  ' "$registry" | grep -oE '"[^"]+"' | tr -d '"')

  if [[ ${#entries[@]} -eq 0 ]]; then
    [[ -n "${registryless[$module]+set}" ]] || {
      printf 'module registry has no entries: %s\n' "$module" >&2
      exit 1
    }
    total_tools=$(( total_tools + ${#tools[@]} ))
    continue
  fi

  declared=()
  for entry in "${entries[@]}"; do
    if [[ "$module" == "ai" ]]; then
      declared+=("${entry%%:*}")
    else
      declared+=("$entry")
    fi
  done

  declare -A in_registry=()
  for id in "${declared[@]}"; do
    [[ -n "$id" ]] || { printf 'empty registry id in %s\n' "$module" >&2; exit 1; }
    [[ -z "${in_registry[$id]+dup}" ]] || {
      printf 'duplicate registry id in %s: %s\n' "$module" "$id" >&2
      exit 1
    }
    in_registry["$id"]=1
    [[ -f "$module_dir/$id/install.sh" ]] || {
      printf 'registry id without installer: %s/%s\n' "$module" "$id" >&2
      exit 1
    }
  done

  for id in "${tools[@]}"; do
    [[ -n "${in_registry[$id]+set}" ]] || {
      printf 'unregistered installer: %s/%s\n' "$module" "$id" >&2
      exit 1
    }
  done

  registered_tools=$(( registered_tools + ${#declared[@]} ))
  total_tools=$(( total_tools + ${#tools[@]} ))
  modules_checked=$(( modules_checked + 1 ))
done

# Every tool must ship a README with an H1 title and a description paragraph.
documented=0
for installer in "$TOOLS_DIR"/*/*/install.sh; do
  [[ -f "$installer" ]] || continue
  dir=${installer%/install.sh}
  readme="$dir/README.md"
  if [[ ! -f "$readme" ]]; then
    printf 'missing README.md: %s\n' "${dir#"$ROOT_DIR"/}" >&2
    exit 1
  fi
  grep -qE '^# [^#]' "$readme" || {
    printf 'README has no H1 title: %s\n' "${dir#"$ROOT_DIR"/}" >&2
    exit 1
  }
  description=$(awk '
    /^[ \t]*(#|\*\*|```|-|\||>)/ { next }
    /^[ \t]*$/ { next }
    { print; exit }
  ' "$readme")
  [[ -n "$description" ]] || {
    printf 'README has no description: %s\n' "${dir#"$ROOT_DIR"/}" >&2
    exit 1
  }
  documented=$(( documented + 1 ))
done

[[ "$total_tools" -eq "$documented" ]] || {
  printf 'tool count mismatch: %d installers, %d documented\n' "$total_tools" "$documented" >&2
  exit 1
}
[[ "$registered_tools" -eq "$total_tools" ]] || {
  printf 'registry count mismatch: %d registered, %d installers\n' "$registered_tools" "$total_tools" >&2
  exit 1
}

printf 'Registry coverage: %d modules, %d tools registered and documented\n' \
  "$modules_checked" "$total_tools"
