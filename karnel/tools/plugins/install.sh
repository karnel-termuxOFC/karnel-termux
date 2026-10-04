# shellcheck shell=bash

PLUGINS_DIR="${KARNEL_DATA}/plugins"
PLUGIN_REGISTRY_COMMIT="f19d3cdd87c67f0a8fa052565ab23c74aea4b27b"
PLUGIN_REGISTRY_SHA256="ea82bf2f9182b5967c0ba9769882a92d8d1aa9ec430fbbbf0dcb21591907b620"
PLUGIN_REGISTRY_URL="https://raw.githubusercontent.com/israelmarques1024-dotcom/karnel-plugins/${PLUGIN_REGISTRY_COMMIT}/registry.json"
PLUGIN_DISPATCH_FOUND=0
PLUGIN_SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\+([0-9A-Za-z-]+)(\.[0-9A-Za-z-]+)*)?$'

_plugin_require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    log_error "Plugin manager requires '$command_name'."
    if [[ "$command_name" == "jq" ]]; then
      log_info "Install it with: pkg install jq"
    fi
    return 1
  fi
}

_plugin_require_jq() {
  _plugin_require_command jq
}

_plugin_name_is_valid() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]
}

_plugin_validate_name() {
  local name="$1"

  if ! _plugin_name_is_valid "$name"; then
    log_error "Invalid plugin name '$name'. Use lowercase letters, digits, and hyphens; start with a letter."
    return 1
  fi
}

_plugin_command_is_valid() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]
}

_plugin_repo_is_valid() {
  local repo="$1"
  local owner project

  [[ "$repo" == */* && "$repo" != */*/* ]] || return 1
  owner="${repo%%/*}"
  project="${repo#*/}"

  [[ "$owner" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}$ ]] || return 1
  [[ "$project" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$ ]] || return 1
  [[ "$project" != *..* && "$project" != *.git ]] || return 1
}

_plugin_validate_repo() {
  local repo="$1"

  if ! _plugin_repo_is_valid "$repo"; then
    log_error "Invalid repository '$repo'. Use exactly owner/repo from GitHub."
    return 1
  fi
}

_plugin_ref_is_valid() {
  local ref="$1"

  [[ "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$ ]] || return 1
  [[ "$ref" != *..* && "$ref" != *//* && "$ref" != */ && "$ref" != ./* && "$ref" != *.lock ]]
}

_plugin_relative_path_is_valid() {
  local path="$1"

  [[ "$path" == "." ]] && return 0
  [[ "$path" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$ ]] || return 1
  [[ "$path" != *..* && "$path" != *//* && "$path" != */ && "$path" != .git && "$path" != .git/* ]]
}

_plugin_semver_is_valid() {
  [[ "$1" =~ $PLUGIN_SEMVER_RE ]]
}

_plugin_prepare_plugins_dir() {
  local canonical

  _plugin_require_command realpath || return 1

  if [[ -L "$PLUGINS_DIR" ]]; then
    log_error "Plugin directory must not be a symbolic link: $PLUGINS_DIR"
    return 1
  fi

  if ! mkdir -p -- "$PLUGINS_DIR"; then
    log_error "Cannot create plugin directory: $PLUGINS_DIR"
    return 1
  fi

  if ! chmod 700 -- "$PLUGINS_DIR"; then
    log_error "Cannot secure plugin directory: $PLUGINS_DIR"
    return 1
  fi

  if ! canonical="$(realpath -e -- "$PLUGINS_DIR")"; then
    log_error "Cannot canonicalize plugin directory: $PLUGINS_DIR"
    return 1
  fi

  if [[ "$canonical" == "/" || ! -d "$canonical" ]]; then
    log_error "Invalid plugin directory: $PLUGINS_DIR"
    return 1
  fi

  PLUGINS_DIR="$canonical"
}

_plugin_canonical_existing_path() {
  local path="$1"

  realpath -e -- "$path"
}

_plugin_path_is_inside() {
  local root="$1"
  local path="$2"
  local canonical

  [[ ! -L "$path" ]] || return 1
  canonical="$(_plugin_canonical_existing_path "$path")" || return 1
  [[ "$canonical" == "$root"/* ]] || return 1
  printf '%s\n' "$canonical"
}

_plugin_path_is_within_or_equal() {
  local root="$1"
  local path="$2"
  local canonical

  [[ ! -L "$path" ]] || return 1
  canonical="$(_plugin_canonical_existing_path "$path")" || return 1
  [[ "$canonical" == "$root" || "$canonical" == "$root"/* ]] || return 1
  printf '%s\n' "$canonical"
}

_plugin_validate_symlinks() {
  local plugin_root="$1"
  local link_target

  _plugin_require_command find || return 1
  while IFS= read -r -d '' link_target; do
    log_error "Plugin payload must not contain symbolic links: $link_target"
    return 1
  done < <(find -P "$plugin_root" -type l -print0)
}

_plugin_dir() {
  local name="$1"

  _plugin_validate_name "$name" || return 1
  printf '%s/%s\n' "$PLUGINS_DIR" "$name"
}

_plugin_manifest() {
  local name="$1"
  local dir

  dir="$(_plugin_dir "$name")" || return 1
  printf '%s/karnel-plugin.json\n' "$dir"
}

_plugin_installed() {
  local name="$1"
  local dir

  _plugin_prepare_plugins_dir || return 1
  dir="$(_plugin_dir "$name")" || return 1
  [[ -d "$dir" && ! -L "$dir" && -f "$dir/karnel-plugin.json" && -f "$dir/.karnel-install.json" ]]
}

_plugin_array_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

_plugin_semver_compare() {
  local left="$1"
  local right="$2"
  local left_without_build="${left%%+*}"
  local right_without_build="${right%%+*}"
  local left_base="${left_without_build%%-*}"
  local right_base="${right_without_build%%-*}"
  local left_pre=""
  local right_pre=""
  local left_major left_minor left_patch right_major right_minor right_patch

  [[ "$left_without_build" == *-* ]] && left_pre="${left_without_build#*-}"
  [[ "$right_without_build" == *-* ]] && right_pre="${right_without_build#*-}"
  IFS='.' read -r left_major left_minor left_patch <<<"$left_base"
  IFS='.' read -r right_major right_minor right_patch <<<"$right_base"

  local left_part right_part
  for left_part in "$left_major" "$left_minor" "$left_patch"; do
    case "$left_part" in
    *[!0-9]*) return 1 ;;
    esac
  done
  for right_part in "$right_major" "$right_minor" "$right_patch"; do
    case "$right_part" in
    *[!0-9]*) return 1 ;;
    esac
  done

  local -a left_numbers=("$left_major" "$left_minor" "$left_patch")
  local -a right_numbers=("$right_major" "$right_minor" "$right_patch")
  local index
  for index in 0 1 2; do
    if ((10#${left_numbers[$index]} < 10#${right_numbers[$index]})); then
      printf '%s\n' '-1'
      return 0
    fi
    if ((10#${left_numbers[$index]} > 10#${right_numbers[$index]})); then
      printf '%s\n' '1'
      return 0
    fi
  done

  if [[ -z "$left_pre" && -z "$right_pre" ]]; then
    printf '%s\n' '0'
    return 0
  fi
  if [[ -z "$left_pre" ]]; then
    printf '%s\n' '1'
    return 0
  fi
  if [[ -z "$right_pre" ]]; then
    printf '%s\n' '-1'
    return 0
  fi

  local -a left_identifiers right_identifiers
  IFS='.' read -r -a left_identifiers <<<"$left_pre"
  IFS='.' read -r -a right_identifiers <<<"$right_pre"
  local limit="${#left_identifiers[@]}"
  (( ${#right_identifiers[@]} < limit )) && limit="${#right_identifiers[@]}"

  for ((index = 0; index < limit; index++)); do
    left_part="${left_identifiers[$index]}"
    right_part="${right_identifiers[$index]}"
    [[ "$left_part" == "$right_part" ]] && continue

    if [[ "$left_part" =~ ^[0-9]+$ && "$right_part" =~ ^[0-9]+$ ]]; then
      if ((10#$left_part < 10#$right_part)); then
        printf '%s\n' '-1'
      else
        printf '%s\n' '1'
      fi
      return 0
    fi
    if [[ "$left_part" =~ ^[0-9]+$ ]]; then
      printf '%s\n' '-1'
      return 0
    fi
    if [[ "$right_part" =~ ^[0-9]+$ ]]; then
      printf '%s\n' '1'
      return 0
    fi
    if [[ "$left_part" < "$right_part" ]]; then
      printf '%s\n' '-1'
    else
      printf '%s\n' '1'
    fi
    return 0
  done

  if (( ${#left_identifiers[@]} < ${#right_identifiers[@]} )); then
    printf '%s\n' '-1'
  elif (( ${#left_identifiers[@]} > ${#right_identifiers[@]} )); then
    printf '%s\n' '1'
  else
    printf '%s\n' '0'
  fi
}

_plugin_check_min_karnel_version() {
  local minimum="$1"
  local plugin_name="$2"
  local comparison

  if ! _plugin_semver_is_valid "$KARNEL_VERSION" || ! _plugin_semver_is_valid "$minimum"; then
    log_error "Cannot compare Karnel compatibility for '$plugin_name'."
    return 1
  fi

  comparison="$(_plugin_semver_compare "$KARNEL_VERSION" "$minimum")" || return 1
  if ((comparison < 0)); then
    log_error "Plugin '$plugin_name' requires Karnel >= $minimum (current: $KARNEL_VERSION)."
    return 1
  fi
}

_plugin_manifest_errors() {
  local manifest="$1"

  jq -r '
    def semver:
      type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+)(\\.[0-9A-Za-z-]+)*)?$");
    def safe_name:
      type == "string" and test("^[a-z][a-z0-9-]{0,62}$");
    def safe_command:
      type == "string" and test("^[a-z][a-z0-9-]{0,62}$");
    def safe_license:
      type == "string" and test("^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$");
    def safe_checksum:
      type == "string" and test("^sha256:[0-9a-f]{64}$");
    def valid_capabilities:
      type == "array" and
      all(.[]; . as $cap | ($cap | type == "string") and (["network", "filesystem-read", "filesystem-write", "process", "environment"] | index($cap) != null)) and
      (length == (unique | length));
    if type != "object" then
      ["root must be a JSON object"]
    else
      . as $manifest |
      [
        (($manifest | keys | sort) - ["capabilities", "checksum", "commands", "description", "license", "minKarnelVersion", "name", "schemaVersion", "version"]) as $unknown |
        if ($unknown | length) > 0 then "unknown field(s): " + ($unknown | join(", ")) else empty end,
        (["schemaVersion", "name", "version", "description", "commands", "minKarnelVersion", "license"] | map(select($manifest[.] == null))) as $missing |
        if ($missing | length) > 0 then "missing required field(s): " + ($missing | join(", ")) else empty end,
        if $manifest.schemaVersion != 1 then "schemaVersion must be 1" else empty end,
        if ($manifest.name | safe_name | not) then "name must match ^[a-z][a-z0-9-]{0,62}$" else empty end,
        if ($manifest.version | semver | not) then "version must be valid SemVer" else empty end,
        if (($manifest.description | type) != "string" or ($manifest.description | length) == 0 or ($manifest.description | length) > 160 or ($manifest.description | test("[[:cntrl:]]"))) then "description must be a non-empty single-line string up to 160 characters" else empty end,
        if (($manifest.commands | type) != "array" or ($manifest.commands | length) == 0) then "commands must be a non-empty array" else empty end,
        if (($manifest.commands | type) == "array" and ($manifest.commands | all(.[]; safe_command) | not)) then "commands must contain only safe command names" else empty end,
        if (($manifest.commands | type) == "array" and ($manifest.commands | length) != ($manifest.commands | unique | length)) then "commands must not contain duplicates" else empty end,
        if ($manifest.minKarnelVersion | semver | not) then "minKarnelVersion must be valid SemVer" else empty end,
        if ($manifest.license | safe_license | not) then "license must be an SPDX identifier" else empty end,
        if ($manifest | has("checksum") and ($manifest.checksum | safe_checksum | not)) then "checksum must match sha256:<64 lowercase hex characters>" else empty end,
        if ($manifest | has("capabilities") and ($manifest.capabilities | valid_capabilities | not)) then "capabilities must be a unique list of supported declarations" else empty end
      ]
    end | .[]
  ' "$manifest"
}

_plugin_validate_manifest() {
  local plugin_root="$1"
  local manifest="$plugin_root/karnel-plugin.json"
  local errors

  _plugin_require_jq || return 1

  if [[ ! -f "$manifest" || -L "$manifest" ]]; then
    log_error "Missing regular karnel-plugin.json in '$plugin_root'."
    return 1
  fi

  if ! manifest="$(_plugin_path_is_inside "$plugin_root" "$manifest")"; then
    log_error "Manifest escapes the plugin directory: $plugin_root"
    return 1
  fi

  if ! errors="$(_plugin_manifest_errors "$manifest")"; then
    log_error "Invalid JSON in $manifest."
    return 1
  fi

  if [[ -n "$errors" ]]; then
    log_error "Manifest validation failed for '$plugin_root':"
    while IFS= read -r error_line; do
      log_error "  $error_line"
    done <<<"$errors"
    return 1
  fi
}

_plugin_file_sha256() {
  local file="$1"
  local result

  if command -v sha256sum >/dev/null 2>&1; then
    result="$(sha256sum -- "$file")" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    result="$(shasum -a 256 -- "$file")" || return 1
  else
    log_error "Plugin checksum verification requires sha256sum or shasum."
    return 1
  fi

  printf '%s\n' "${result%% *}"
}

_plugin_verify_registry_checksum() {
  local registry="$1"
  local checksum

  if ! checksum="$(_plugin_file_sha256 "$registry")"; then
    return 1
  fi

  if [[ "$checksum" != "$PLUGIN_REGISTRY_SHA256" ]]; then
    log_error "Plugin registry checksum verification failed."
    return 1
  fi
}

_plugin_payload_checksum() {
  local plugin_root="$1"
  local file relative file_hash checksum_line

  _plugin_require_command find || return 1
  _plugin_require_command sort || return 1

  if command -v sha256sum >/dev/null 2>&1; then
    checksum_line="$({
      set -o pipefail
      while IFS= read -r -d '' file; do
        relative="${file#"$plugin_root"/}"
        case "$relative" in
        karnel-plugin.json|.karnel-install.json) continue ;;
        esac
        file_hash="$(_plugin_file_sha256 "$file")" || exit 1
        printf '%s\0%s\0' "$relative" "$file_hash"
      done < <(LC_ALL=C find -P "$plugin_root" -path "$plugin_root/.git" -prune -o -type f -print0 | LC_ALL=C sort -z)
    } | sha256sum)" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    checksum_line="$({
      set -o pipefail
      while IFS= read -r -d '' file; do
        relative="${file#"$plugin_root"/}"
        case "$relative" in
        karnel-plugin.json|.karnel-install.json) continue ;;
        esac
        file_hash="$(_plugin_file_sha256 "$file")" || exit 1
        printf '%s\0%s\0' "$relative" "$file_hash"
      done < <(LC_ALL=C find -P "$plugin_root" -path "$plugin_root/.git" -prune -o -type f -print0 | LC_ALL=C sort -z)
    } | shasum -a 256)" || return 1
  else
    log_error "Plugin checksum verification requires sha256sum or shasum."
    return 1
  fi

  printf 'sha256:%s\n' "${checksum_line%% *}"
}

_plugin_command_declares_handler() {
  local command_file="$1"
  local command_name="$2"
  local handler="${command_name}_main"

  # Sourcing to inspect declarations would execute untrusted plugin code.
  grep -Eq "^[[:space:]]*(function[[:space:]]+)?${handler}[[:space:]]*(\\([[:space:]]*\\))?[[:space:]]*\\{" "$command_file"
}

_plugin_validate_declared_commands() {
  local plugin_root="$1"
  local manifest="$plugin_root/karnel-plugin.json"
  local commands_dir="$plugin_root/commands"
  local canonical_commands_dir command_name command_file canonical_file file_name
  local -a commands

  if [[ ! -d "$commands_dir" || -L "$commands_dir" ]]; then
    log_error "Plugin '$plugin_root' must contain a regular commands directory."
    return 1
  fi

  if ! canonical_commands_dir="$(_plugin_path_is_inside "$plugin_root" "$commands_dir")"; then
    log_error "Commands directory escapes plugin '$plugin_root'."
    return 1
  fi

  mapfile -t commands < <(jq -r '.commands[]' "$manifest")
  for command_name in "${commands[@]}"; do
    command_file="$canonical_commands_dir/$command_name.sh"
    if [[ ! -f "$command_file" || -L "$command_file" || ! -r "$command_file" ]]; then
      log_error "Declared command '$command_name' must have a readable regular file at commands/$command_name.sh."
      return 1
    fi
    if ! canonical_file="$(_plugin_path_is_inside "$plugin_root" "$command_file")"; then
      log_error "Command '$command_name' escapes plugin '$plugin_root'."
      return 1
    fi
    if ! bash -n "$canonical_file"; then
      log_error "Command '$command_name' has invalid Bash syntax."
      return 1
    fi
    if ! _plugin_command_declares_handler "$canonical_file" "$command_name"; then
      log_error "Command '$command_name' must define ${command_name}_main."
      return 1
    fi
  done

  for command_file in "$canonical_commands_dir"/* "$canonical_commands_dir"/.[!.]* "$canonical_commands_dir"/..?*; do
    [[ -e "$command_file" ]] || continue
    if [[ ! -f "$command_file" || -L "$command_file" ]]; then
      log_error "Commands directory contains an unsafe non-regular entry: $command_file"
      return 1
    fi
    if [[ "$command_file" != *.sh ]]; then
      log_error "Commands directory contains a non-command file: $command_file"
      return 1
    fi
    file_name="${command_file##*/}"
    file_name="${file_name%.sh}"
    if ! _plugin_array_contains "$file_name" "${commands[@]}"; then
      log_error "Undeclared command file '$file_name.sh' in plugin '$plugin_root'."
      return 1
    fi
  done
}

_plugin_verify_checksum() {
  local plugin_root="$1"
  local manifest="$plugin_root/karnel-plugin.json"
  local expected actual

  expected="$(jq -r '.checksum // empty' "$manifest")" || return 1
  if [[ -z "$expected" ]]; then
    log_error "Plugin '$(jq -r '.name' "$manifest")' has no checksum; refusing install"
    return 1
  fi

  actual="$(_plugin_payload_checksum "$plugin_root")" || return 1
  if [[ "$actual" != "$expected" ]]; then
    log_error "Checksum mismatch for plugin '$(jq -r '.name' "$manifest")'."
    return 1
  fi
}

_plugin_validate_plugin_contents() {
  local plugin_root="$1"
  local canonical_root manifest minimum plugin_name

  if [[ ! -d "$plugin_root" || -L "$plugin_root" ]]; then
    log_error "Plugin directory is missing or is a symbolic link: $plugin_root"
    return 1
  fi

  canonical_root="$(_plugin_canonical_existing_path "$plugin_root")" || {
    log_error "Cannot canonicalize plugin directory: $plugin_root"
    return 1
  }

  _plugin_validate_symlinks "$canonical_root" || return 1
  _plugin_validate_manifest "$canonical_root" || return 1
  manifest="$canonical_root/karnel-plugin.json"
  _plugin_validate_declared_commands "$canonical_root" || return 1
  _plugin_verify_checksum "$canonical_root" || return 1

  plugin_name="$(jq -r '.name' "$manifest")" || return 1
  minimum="$(jq -r '.minKarnelVersion' "$manifest")" || return 1
  _plugin_check_min_karnel_version "$minimum" "$plugin_name" || return 1

  if [[ ! -f "$canonical_root/LICENSE" && ! -f "$canonical_root/LICENSE.md" ]]; then
    log_error "Plugin '$plugin_name' must include LICENSE or LICENSE.md."
    return 1
  fi

  printf '%s\n' "$canonical_root"
}

_plugin_install_metadata_errors() {
  local metadata="$1"

  jq -r '
    def safe_name:
      type == "string" and test("^[a-z][a-z0-9-]{0,62}$");
    def safe_repo:
      (type == "string") and test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$") and (contains("..") | not);
    def safe_ref:
      (type == "string") and test("^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$") and (contains("..") | not);
    def semver:
      type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+)(\\.[0-9A-Za-z-]+)*)?$");
    def checksum_or_null:
      . == null or (type == "string" and test("^sha256:[0-9a-f]{64}$"));
    if type != "object" then
      ["root must be a JSON object"]
    else
      . as $metadata |
      [
        if (($metadata | keys | sort) != ["checksum", "commit", "config", "enabled", "name", "ref", "registryName", "repo", "schemaVersion", "source", "version"]) then "metadata has unknown or missing fields" else empty end,
        if $metadata.schemaVersion != 1 then "metadata schemaVersion must be 1" else empty end,
        if (["registry", "unsafe", "local"] | index($metadata.source)) == null then "metadata source is invalid" else empty end,
        if ($metadata.name | safe_name | not) then "metadata name is invalid" else empty end,
        if ($metadata.version | semver | not) then "metadata version is invalid" else empty end,
        if ($metadata.checksum | checksum_or_null | not) then "metadata checksum is invalid" else empty end,
        if ($metadata.source == "local" and ($metadata.repo != null or $metadata.ref != null or $metadata.commit != null or $metadata.registryName != null)) then "local metadata must not declare a remote" else empty end,
        if ($metadata.source != "local" and (($metadata.repo | safe_repo | not) or ($metadata.ref | safe_ref | not) or (($metadata.commit | type) != "string") or ($metadata.commit | test("^[0-9a-f]{40}$") | not))) then "remote metadata is invalid" else empty end,
        if ($metadata.source == "registry" and ($metadata.registryName | safe_name | not)) then "registry metadata must include registryName" else empty end,
        if ($metadata.source == "unsafe" and $metadata.registryName != null) then "unsafe metadata must not include registryName" else empty end
      ]
    end | .[]
  ' "$metadata"
}

_plugin_validate_install_metadata() {
  local plugin_root="$1"
  local manifest="$plugin_root/karnel-plugin.json"
  local metadata="$plugin_root/.karnel-install.json"
  local errors

  if [[ ! -f "$metadata" || -L "$metadata" ]]; then
    log_error "Plugin '$plugin_root' is missing trusted installation metadata."
    return 1
  fi

  if ! metadata="$(_plugin_path_is_inside "$plugin_root" "$metadata")"; then
    log_error "Installation metadata escapes plugin '$plugin_root'."
    return 1
  fi

  if ! errors="$(_plugin_install_metadata_errors "$metadata")"; then
    log_error "Invalid JSON in $metadata."
    return 1
  fi

  if [[ -n "$errors" ]]; then
    log_error "Installation metadata validation failed for '$plugin_root':"
    while IFS= read -r error_line; do
      log_error "  $error_line"
    done <<<"$errors"
    return 1
  fi

  if ! jq -e '
    . as $metadata |
    input as $manifest |
    $metadata.name == $manifest.name and
    $metadata.version == $manifest.version and
    $metadata.checksum == ($manifest.checksum // null)
  ' "$metadata" "$manifest" >/dev/null; then
    log_error "Installation metadata does not match manifest in '$plugin_root'."
    return 1
  fi
}

_plugin_validate_installed_plugin() {
  local plugin_dir="$1"
  local expected_name="$2"
  local canonical_root manifest_name

  canonical_root="$(_plugin_path_is_inside "$PLUGINS_DIR" "$plugin_dir")" || {
    log_error "Plugin path is outside PLUGINS_DIR: $plugin_dir"
    return 1
  }
  canonical_root="$(_plugin_validate_plugin_contents "$canonical_root")" || return 1
  manifest_name="$(jq -r '.name' "$canonical_root/karnel-plugin.json")" || return 1

  if [[ "$manifest_name" != "$expected_name" ]]; then
    log_error "Plugin directory '$expected_name' does not match manifest name '$manifest_name'."
    return 1
  fi

  _plugin_validate_install_metadata "$canonical_root" || return 1
  printf '%s\n' "$canonical_root"
}

_plugin_registry_errors() {
  local registry="$1"

  jq -r '
    def semver:
      type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+)(\\.[0-9A-Za-z-]+)*)?$");
    def safe_name:
      type == "string" and test("^[a-z][a-z0-9-]{0,62}$");
    def safe_repo:
      (type == "string") and test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$") and (contains("..") | not) and (endswith(".git") | not);
    def safe_ref:
      (type == "string") and test("^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$") and (contains("..") | not) and (contains("//") | not) and (endswith("/") | not) and (endswith(".lock") | not);
    def safe_path:
      . == "." or ((type == "string") and test("^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$") and (contains("..") | not) and (contains("//") | not) and (endswith("/") | not) and (startswith(".git") | not));
    def safe_license:
      type == "string" and test("^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$");
    def safe_checksum:
      type == "string" and test("^sha256:[0-9a-f]{64}$");
    def valid_capabilities:
      type == "array" and
      all(.[]; . as $cap | ($cap | type == "string") and (["network", "filesystem-read", "filesystem-write", "process", "environment"] | index($cap) != null)) and
      (length == (unique | length));
    def valid_plugin:
      . as $plugin |
      ($plugin | type == "object") and
      (($plugin | keys | sort) - ["capabilities", "checksum", "commands", "commit", "description", "license", "minKarnelVersion", "name", "path", "ref", "repo", "version"] | length == 0) and
      (["name", "repo", "ref", "version", "description", "commands", "minKarnelVersion", "license", "checksum"] | all(.[]; . as $field | $plugin | has($field))) and
      ($plugin.name | safe_name) and
      ($plugin.repo | safe_repo) and
      ($plugin.ref | safe_ref) and
      ($plugin.version | semver) and
      (($plugin.description | type) == "string" and ($plugin.description | length) > 0 and ($plugin.description | length) <= 160 and ($plugin.description | test("[[:cntrl:]]") | not)) and
      (($plugin.commands | type) == "array" and ($plugin.commands | length) > 0 and ($plugin.commands | all(.[]; type == "string" and test("^[a-z][a-z0-9-]{0,62}$"))) and ($plugin.commands | length) == ($plugin.commands | unique | length)) and
      ($plugin.minKarnelVersion | semver) and
      ($plugin.license | safe_license) and
      ($plugin.checksum | safe_checksum) and
      (($plugin | has("commit") | not) or ($plugin.commit | type == "string" and test("^[0-9a-f]{40}$"))) and
      (($plugin | has("path") | not) or ($plugin.path | safe_path)) and
      (($plugin | has("capabilities") | not) or ($plugin.capabilities | valid_capabilities));
    if type != "object" then
      ["root must be a JSON object"]
    else
      . as $registry |
      [
        if (($registry | keys | sort) != ["description", "plugins", "schemaVersion"]) then "registry has unknown or missing fields" else empty end,
        if $registry.schemaVersion != 1 then "schemaVersion must be 1" else empty end,
        if (($registry.description | type) != "string" or ($registry.description | length) == 0) then "description must be a non-empty string" else empty end,
        if (($registry.plugins | type) != "array") then "plugins must be an array" else empty end,
        if (($registry.plugins | type) == "array" and ($registry.plugins | all(.[]; valid_plugin) | not)) then "one or more plugin entries violate registry schema v1" else empty end,
        if (($registry.plugins | type) == "array" and ($registry.plugins | map(.name) | length) != ($registry.plugins | map(.name) | unique | length)) then "plugin names must be unique" else empty end,
        if (($registry.plugins | type) == "array" and ($registry.plugins | map(.repo + ":" + (.path // ".")) | length) != ($registry.plugins | map(.repo + ":" + (.path // ".")) | unique | length)) then "plugin repository paths must be unique" else empty end
      ]
    end | .[]
  ' "$registry"
}

_plugin_validate_registry() {
  local registry="$1"
  local errors

  _plugin_require_jq || return 1

  if [[ ! -f "$registry" || -L "$registry" ]]; then
    log_error "Registry file is missing or unsafe: $registry"
    return 1
  fi

  if ! errors="$(_plugin_registry_errors "$registry")"; then
    log_error "Registry is not valid JSON: $registry"
    return 1
  fi

  if [[ -n "$errors" ]]; then
    log_error "Registry validation failed:"
    while IFS= read -r error_line; do
      log_error "  $error_line"
    done <<<"$errors"
    return 1
  fi
}

_plugin_fetch_registry() {
  local destination="$1"
  local registry_url="$PLUGIN_REGISTRY_URL"

  _plugin_require_command curl || return 1

  if [[ "$registry_url" != https://* ]]; then
    log_error "Plugin registry URL must use HTTPS."
    return 1
  fi

  if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 30 --output "$destination" "$registry_url"; then
    log_error "Failed to fetch the plugin registry. Check your network connection."
    return 1
  fi

  if [[ ! -s "$destination" ]]; then
    log_error "Plugin registry response is empty."
    return 1
  fi

  _plugin_verify_registry_checksum "$destination" || return 1
  _plugin_validate_registry "$destination"
}

_plugin_registry_entry_for() {
  local registry="$1"
  local selector="$2"
  local filter result count

  if _plugin_repo_is_valid "$selector"; then
    filter='[.plugins[] | select(.repo == $selector)]'
  elif _plugin_name_is_valid "$selector"; then
    filter='[.plugins[] | select(.name == $selector)]'
  else
    return 1
  fi

  result="$(jq -c --arg selector "$selector" "$filter" "$registry")" || return 1
  count="$(jq 'length' <<<"$result")" || return 1
  (( count > 0 )) || return 1
  if (( count > 1 )); then
    log_error "Repository '$selector' provides multiple plugins; install one by its approved name."
    return 2
  fi
  jq -c '.[0]' <<<"$result"
}

_plugin_registry_entry_matches_manifest() {
  local manifest="$1"
  local entry="$2"

  jq -e --argjson entry "$entry" '
    . as $manifest |
    $entry as $registry |
    $manifest.name == $registry.name and
    $manifest.version == $registry.version and
    $manifest.description == $registry.description and
    $manifest.commands == $registry.commands and
    $manifest.minKarnelVersion == $registry.minKarnelVersion and
    $manifest.license == $registry.license and
    $manifest.checksum == $registry.checksum and
    ($manifest.capabilities // []) == ($registry.capabilities // [])
  ' "$manifest" >/dev/null
}

_plugin_native_command_exists() {
  local command_name="$1"

  [[ -f "$KARNEL_PATH/cli/commands/$command_name.sh" || "$command_name" == "karnel" ]]
}

_plugin_check_command_collisions() {
  local candidate_root="$1"
  local candidate_name="$2"
  local candidate_manifest="$candidate_root/karnel-plugin.json"
  local command_name plugin_dir plugin_name canonical_root
  local -a candidate_commands installed_commands

  mapfile -t candidate_commands < <(jq -r '.commands[]' "$candidate_manifest")
  for command_name in "${candidate_commands[@]}"; do
    if _plugin_native_command_exists "$command_name"; then
      log_error "Plugin '$candidate_name' cannot override native command '$command_name'."
      return 1
    fi
  done

  for plugin_dir in "$PLUGINS_DIR"/*; do
    [[ -d "$plugin_dir" ]] || continue
    [[ -L "$plugin_dir" ]] && {
      log_error "Refusing plugin directory symbolic link: $plugin_dir"
      return 1
    }
    plugin_name="${plugin_dir##*/}"
    _plugin_name_is_valid "$plugin_name" || continue
    [[ "$plugin_name" == "$candidate_name" ]] && continue

    canonical_root="$(_plugin_validate_installed_plugin "$plugin_dir" "$plugin_name")" || return 1
    mapfile -t installed_commands < <(jq -r '.commands[]' "$canonical_root/karnel-plugin.json")
    for command_name in "${candidate_commands[@]}"; do
      if _plugin_array_contains "$command_name" "${installed_commands[@]}"; then
        log_error "Command collision: '$command_name' is already provided by plugin '$plugin_name'."
        return 1
      fi
    done
  done
}

_plugin_safe_remove_path() {
  local path="$1"
  local canonical

  [[ -e "$path" || -L "$path" ]] || return 0
  if [[ -L "$path" ]]; then
    log_error "Refusing to remove symbolic link: $path"
    return 1
  fi
  if ! canonical="$(_plugin_path_is_inside "$PLUGINS_DIR" "$path")"; then
    log_error "Refusing to remove path outside PLUGINS_DIR: $path"
    return 1
  fi
  rm -rf -- "$canonical"
}

_plugin_cleanup_staging() {
  local staging="$1"

  _plugin_safe_remove_path "$staging"
}

_plugin_cleanup_temp_file() {
  local file="$1"

  [[ -e "$file" || -L "$file" ]] || return 0
  if [[ -L "$file" ]] || ! _plugin_path_is_inside "$PLUGINS_DIR" "$file" >/dev/null; then
    log_error "Refusing to clean unsafe temporary file: $file"
    return 1
  fi
  rm -f -- "$file"
}

_plugin_clone_repository() {
  local repo="$1"
  local ref="$2"
  local destination="$3"
  local commit="$4"
  local source_url="https://github.com/$repo.git"

  _plugin_require_command git || return 1

  if [[ -n "$commit" ]]; then
    git clone "$source_url" "$destination" || return 1
    git -C "$destination" checkout "$commit" --detach || return 1
  elif [[ -n "$ref" ]]; then
    git clone --depth=1 --branch "$ref" "$source_url" "$destination"
  else
    git clone --depth=1 "$source_url" "$destination"
  fi
}

_plugin_write_install_metadata() {
  local plugin_root="$1"
  local source="$2"
  local repo="$3"
  local ref="$4"
  local commit="$5"
  local registry_name="$6"
  local manifest="$plugin_root/karnel-plugin.json"
  local name version checksum metadata="$plugin_root/.karnel-install.json"
  local repo_json ref_json commit_json registry_json

  name="$(jq -r '.name' "$manifest")" || return 1
  version="$(jq -r '.version' "$manifest")" || return 1
  checksum="$(jq -r '.checksum // empty' "$manifest")" || return 1

  repo_json='null'
  ref_json='null'
  commit_json='null'
  registry_json='null'
  [[ -n "$repo" ]] && repo_json="$(jq -Rn --arg value "$repo" '$value')"
  [[ -n "$ref" ]] && ref_json="$(jq -Rn --arg value "$ref" '$value')"
  [[ -n "$commit" ]] && commit_json="$(jq -Rn --arg value "$commit" '$value')"
  [[ -n "$registry_name" ]] && registry_json="$(jq -Rn --arg value "$registry_name" '$value')"

  if ! jq -n \
    --arg source "$source" \
    --arg name "$name" \
    --arg version "$version" \
    --arg checksum "$checksum" \
    --argjson repo "$repo_json" \
    --argjson ref "$ref_json" \
    --argjson commit "$commit_json" \
    --argjson registry_name "$registry_json" \
    '{schemaVersion: 1, source: $source, name: $name, repo: $repo, ref: $ref, commit: $commit, version: $version, checksum: (if $checksum == "" then null else $checksum end), registryName: $registry_name, enabled: true, config: {}}' >"$metadata"; then
    log_error "Failed to write installation metadata for '$name'."
    return 1
  fi

  chmod 600 -- "$metadata"
}

_plugin_recover_interrupted_replacement() {
  local name="$1"
  local destination="$PLUGINS_DIR/$name"
  local backup=""
  local candidate count=0

  for candidate in "$PLUGINS_DIR"/.karnel-backup-"$name".*; do
    [[ -e "$candidate" || -L "$candidate" ]] || continue
    backup="$candidate"
    count=$((count + 1))
  done

  if ((count == 0)); then
    return 0
  fi
  if ((count > 1)); then
    log_error "Multiple rollback directories found for '$name'; refusing automatic recovery."
    return 1
  fi
  if [[ -L "$backup" ]] || ! _plugin_path_is_inside "$PLUGINS_DIR" "$backup" >/dev/null; then
    log_error "Rollback directory for '$name' is unsafe: $backup"
    return 1
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ -L "$destination" ]] || ! _plugin_path_is_inside "$PLUGINS_DIR" "$destination" >/dev/null; then
      log_error "Plugin destination for '$name' is unsafe: $destination"
      return 1
    fi
    log_warn "Cleaning rollback data left by a completed update of '$name'."
    _plugin_safe_remove_path "$backup"
    return $?
  fi

  if ! mv -- "$backup" "$destination"; then
    log_error "Failed to restore '$name' after an interrupted update."
    return 1
  fi
  log_warn "Restored '$name' after an interrupted update."
}

_plugin_recover_all_interrupted_replacements() {
  local backup name

  for backup in "$PLUGINS_DIR"/.karnel-backup-*.*; do
    [[ -e "$backup" || -L "$backup" ]] || continue
    name="${backup##*/.karnel-backup-}"
    name="${name%%.*}"
    if ! _plugin_name_is_valid "$name"; then
      log_error "Invalid rollback directory detected: $backup"
      return 1
    fi
    _plugin_recover_interrupted_replacement "$name" || return 1
  done
}

_plugin_acquire_plugin_lock() {
  local name="$1"
  local lock="$PLUGINS_DIR/.karnel-lock-$name"

  if _karnel_acquire_lock "$lock"; then
    PLUGIN_OPERATION_LOCK="$lock"
    return 0
  fi

  log_error "Another operation is already changing plugin '$name'."
  return 1
}

_plugin_release_plugin_lock() {
  local lock="${PLUGIN_OPERATION_LOCK:-}"

  [[ -n "$lock" ]] || return 0
  if ! _karnel_release_lock "$lock"; then
    log_error "Failed to release plugin operation lock: $lock"
    return 1
  fi
  PLUGIN_OPERATION_LOCK=""
}

_plugin_place_candidate() {
  local candidate="$1"
  local name="$2"
  local replace_existing="$3"
  local destination="$PLUGINS_DIR/$name"
  local backup=""
  local status=0

  _plugin_acquire_plugin_lock "$name" || return 1
  if ! _plugin_recover_interrupted_replacement "$name"; then
    status=1
  elif [[ -e "$destination" || -L "$destination" ]]; then
    if [[ "$replace_existing" != "1" ]]; then
      log_info "Plugin '$name' is already installed."
      status=2
    elif [[ -L "$destination" ]] || ! _plugin_path_is_inside "$PLUGINS_DIR" "$destination" >/dev/null; then
      log_error "Refusing to replace unsafe plugin directory: $destination"
      status=1
    else
      backup="$(mktemp -d "$PLUGINS_DIR/.karnel-backup-$name.XXXXXX")" || {
        log_error "Failed to create rollback directory for '$name'."
        status=1
      }
      if ((status == 0)) && ! rmdir -- "$backup"; then
        log_error "Failed to prepare rollback directory for '$name'."
        status=1
      fi
      if ((status == 0)) && ! mv -- "$destination" "$backup"; then
        log_error "Failed to stage existing plugin '$name' for replacement."
        status=1
      fi
    fi
  fi

  if ((status == 0)) && ! mv -- "$candidate" "$destination"; then
    log_error "Failed to activate plugin '$name'."
    if [[ -n "$backup" ]] && ! mv -- "$backup" "$destination"; then
      log_error "Critical: failed to restore previous plugin '$name'."
    fi
    status=1
  fi

  if ((status == 0)) && [[ -n "$backup" ]] && ! _plugin_safe_remove_path "$backup"; then
    log_error "Plugin '$name' was updated, but rollback data remains at $backup."
    status=1
  fi

  if ((status != 0)) && [[ -n "$backup" && -e "$backup" && ( -e "$destination" || -L "$destination" ) ]]; then
    if ! _plugin_safe_remove_path "$backup"; then
      log_error "Failed to clean rollback data for '$name': $backup"
    fi
  fi

  if ! _plugin_release_plugin_lock; then
    ((status == 0)) && status=1
  fi
  return "$status"
}

_plugin_stage_and_install() {
  local repo="$1"
  local ref="$2"
  local relative_path="$3"
  local registry_entry="$4"
  local source="$5"
  local expected_name="$6"
  local replace_existing="$7"
  local staging checkout checkout_root candidate candidate_root manifest_name commit installed_ref expected_commit registry_name

  expected_commit=""
  registry_name=""
  if [[ -n "$registry_entry" ]]; then
    expected_commit="$(jq -r '.commit // empty' <<<"$registry_entry")" || return 1
    registry_name="$(jq -r '.name' <<<"$registry_entry")" || return 1
  fi

  _plugin_prepare_plugins_dir || return 1
  _plugin_validate_repo "$repo" || return 1
  [[ -z "$ref" ]] || _plugin_ref_is_valid "$ref" || {
    log_error "Invalid Git ref '$ref'."
    return 1
  }
  _plugin_relative_path_is_valid "$relative_path" || {
    log_error "Invalid plugin path '$relative_path'."
    return 1
  }

  staging="$(mktemp -d "$PLUGINS_DIR/.karnel-plugin.XXXXXX")" || {
    log_error "Failed to create temporary plugin directory."
    return 1
  }
  checkout="$staging/repository"

  if ! _plugin_clone_repository "$repo" "$ref" "$checkout" "$expected_commit"; then
    log_error "Failed to clone plugin repository '$repo'."
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  checkout_root="$(_plugin_path_is_inside "$PLUGINS_DIR" "$checkout")" || {
    log_error "Cloned repository escaped the temporary plugin directory."
    _plugin_cleanup_staging "$staging"
    return 1
  }
  candidate="$checkout_root"
  [[ "$relative_path" == "." ]] || candidate="$checkout_root/$relative_path"
  candidate_root="$(_plugin_path_is_within_or_equal "$checkout_root" "$candidate")" || {
    log_error "Plugin path '$relative_path' escapes repository '$repo'."
    _plugin_cleanup_staging "$staging"
    return 1
  }

  candidate_root="$(_plugin_validate_plugin_contents "$candidate_root")" || {
    _plugin_cleanup_staging "$staging"
    return 1
  }
  manifest_name="$(jq -r '.name' "$candidate_root/karnel-plugin.json")" || {
    _plugin_cleanup_staging "$staging"
    return 1
  }

  if [[ -n "$expected_name" && "$manifest_name" != "$expected_name" ]]; then
    log_error "Manifest name '$manifest_name' does not match expected plugin '$expected_name'."
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  if [[ -n "$registry_entry" ]] && ! _plugin_registry_entry_matches_manifest "$candidate_root/karnel-plugin.json" "$registry_entry"; then
    log_error "Plugin manifest does not match its approved registry entry."
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  _plugin_check_command_collisions "$candidate_root" "$manifest_name" || {
    _plugin_cleanup_staging "$staging"
    return 1
  }

  if ! commit="$(git -C "$checkout_root" rev-parse HEAD)" || [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    log_error "Cannot determine installed commit for '$repo'."
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  installed_ref="$ref"
  if [[ -z "$installed_ref" ]]; then
    if ! installed_ref="$(git -C "$checkout_root" symbolic-ref --short -q HEAD)"; then
      installed_ref="detached"
    fi
  fi

  if [[ -n "$registry_entry" ]]; then
    expected_commit="$(jq -r '.commit // empty' <<<"$registry_entry")" || {
      _plugin_cleanup_staging "$staging"
      return 1
    }
    registry_name="$(jq -r '.name' <<<"$registry_entry")" || {
      _plugin_cleanup_staging "$staging"
      return 1
    }
    if [[ -n "$expected_commit" && "$commit" != "$expected_commit" ]]; then
      log_error "Registry commit for '$manifest_name' does not match the fetched source."
      _plugin_cleanup_staging "$staging"
      return 1
    fi
  else
    registry_name=""
  fi

  if ! _plugin_write_install_metadata "$candidate_root" "$source" "$repo" "$installed_ref" "$commit" "$registry_name"; then
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  if ! _plugin_place_candidate "$candidate_root" "$manifest_name" "$replace_existing"; then
    _plugin_cleanup_staging "$staging"
    return 1
  fi

  _plugin_cleanup_staging "$staging" || return 1
  log_success "Plugin '$manifest_name' installed (commit ${commit:0:12})."
}

_plugin_install_registry_entry() {
  local entry="$1"
  local replace_existing="$2"
  local repo ref relative_path name

  repo="$(jq -r '.repo' <<<"$entry")" || return 1
  ref="$(jq -r '.ref' <<<"$entry")" || return 1
  relative_path="$(jq -r '.path // "."' <<<"$entry")" || return 1
  name="$(jq -r '.name' <<<"$entry")" || return 1

  _plugin_check_min_karnel_version "$(jq -r '.minKarnelVersion' <<<"$entry")" "$name" || return 1
  _plugin_stage_and_install "$repo" "$ref" "$relative_path" "$entry" "registry" "$name" "$replace_existing"
}

_plugin_confirm_unsafe() {
  local repo="$1"
  local answer

  log_warn "'$repo' is not approved by the Karnel registry."
  log_warn "Plugins execute Bash with all permissions of your current user; Bash has no sandbox here."
  read_confirm "Install unsafe plugin '$repo'?" answer n
}

_plugin_install_unsafe_repo() {
  local repo="$1"
  local expected_name="$2"
  local replace_existing="$3"

  _plugin_confirm_unsafe "$repo" || {
    log_info "Unsafe plugin installation cancelled."
    return 1
  }
  _plugin_stage_and_install "$repo" "" "." "" "unsafe" "$expected_name" "$replace_existing"
}

install_plugin() {
  local target="${1:-}"
  local unsafe_flag="${2:-}"
  local registry_file entry

  if [[ -z "$target" ]]; then
    log_error "Usage: karnel plugin install <approved-name|owner/repo> [--unsafe]"
    return 1
  fi
  if [[ -n "$unsafe_flag" && "$unsafe_flag" != "--unsafe" ]]; then
    log_error "Unknown install option: $unsafe_flag"
    return 1
  fi
  if ! _plugin_name_is_valid "$target" && ! _plugin_repo_is_valid "$target"; then
    log_error "Invalid plugin name or repository: $target"
    return 1
  fi

  _plugin_require_jq || return 1
  _plugin_prepare_plugins_dir || return 1
  registry_file="$(mktemp "$PLUGINS_DIR/.karnel-registry.XXXXXX")" || return 1

  if ! _plugin_fetch_registry "$registry_file"; then
    if ! _plugin_cleanup_temp_file "$registry_file"; then
      log_error "Failed to clean temporary registry data."
    fi
    return 1
  fi

  if entry="$(_plugin_registry_entry_for "$registry_file" "$target")"; then
    _plugin_cleanup_temp_file "$registry_file" || return 1
    _plugin_install_registry_entry "$entry" 0
    return $?
  fi

  _plugin_cleanup_temp_file "$registry_file" || return 1
  if [[ "$unsafe_flag" != "--unsafe" ]]; then
    log_error "'$target' is not an approved registry plugin. Use --unsafe only after reviewing its source."
    return 1
  fi
  if ! _plugin_repo_is_valid "$target"; then
    log_error "--unsafe requires an exact owner/repo repository."
    return 1
  fi

  _plugin_install_unsafe_repo "$target" "" 0
}

uninstall_plugin() {
  local name="$1"
  local plugin_dir status=0

  _plugin_validate_name "$name" || return 1
  _plugin_prepare_plugins_dir || return 1
  _plugin_acquire_plugin_lock "$name" || return 1

  if ! _plugin_recover_interrupted_replacement "$name"; then
    status=1
  else
    plugin_dir="$PLUGINS_DIR/$name"
    if [[ ! -e "$plugin_dir" && ! -L "$plugin_dir" ]]; then
      log_info "Plugin '$name' is not installed."
      status=2
    elif [[ -d "$plugin_dir" && ! -L "$plugin_dir" ]] && ! _plugin_validate_symlinks "$(_plugin_canonical_existing_path "$plugin_dir")"; then
      status=1
    else
      log_info "Removing plugin '$name'..."
      if _plugin_safe_remove_path "$plugin_dir"; then
        log_success "Plugin '$name' removed."
      else
        status=1
      fi
    fi
  fi

  if ! _plugin_release_plugin_lock && ((status == 0)); then
    status=1
  fi
  return "$status"
}

_plugin_read_metadata_field() {
  local plugin_root="$1"
  local field="$2"

  jq -r ".$field // empty" "$plugin_root/.karnel-install.json"
}

_plugin_is_enabled() {
  local plugin_root="$1"
  local enabled

  enabled="$(_plugin_read_metadata_field "$plugin_root" enabled)"
  [[ "$enabled" != "false" ]]
}

_plugin_set_enabled() {
  local plugin_root="$1"
  local enabled="$2"
  local metadata="$plugin_root/.karnel-install.json"

  if ! jq --arg val "$enabled" '.enabled = $val' "$metadata" >"$metadata.tmp"; then
    log_error "Failed to update enabled state."
    return 1
  fi
  if ! mv -- "$metadata.tmp" "$metadata"; then
    log_error "Failed to persist enabled state."
    return 1
  fi
}

_plugin_get_config() {
  local plugin_root="$1"
  local key="${2:-}"
  local metadata="$plugin_root/.karnel-install.json"

  if [[ -z "$key" ]]; then
    jq -r '.config // {}' "$metadata"
  else
    jq -r --arg k "$key" '.config[$k] // empty' "$metadata"
  fi
}

_plugin_set_config() {
  local plugin_root="$1"
  local key="$2"
  local value="$3"
  local metadata="$plugin_root/.karnel-install.json"

  if ! jq --arg k "$key" --arg v "$value" '.config[$k] = $v' "$metadata" >"$metadata.tmp"; then
    log_error "Failed to set config '$key'."
    return 1
  fi
  if ! mv -- "$metadata.tmp" "$metadata"; then
    log_error "Failed to persist config."
    return 1
  fi
}

_plugin_delete_config() {
  local plugin_root="$1"
  local key="$2"
  local metadata="$plugin_root/.karnel-install.json"

  if ! jq --arg k "$key" 'del(.config[$k])' "$metadata" >"$metadata.tmp"; then
    log_error "Failed to delete config '$key'."
    return 1
  fi
  if ! mv -- "$metadata.tmp" "$metadata"; then
    log_error "Failed to persist config."
    return 1
  fi
}

update_plugin() {
  local name="$1"
  local unsafe_flag="${2:-}"
  local plugin_dir plugin_root source repo ref registry_name registry_file entry

  _plugin_validate_name "$name" || return 1
  if [[ -n "$unsafe_flag" && "$unsafe_flag" != "--unsafe" ]]; then
    log_error "Unknown update option: $unsafe_flag"
    return 1
  fi
  _plugin_require_jq || return 1
  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_interrupted_replacement "$name" || return 1
  plugin_dir="$PLUGINS_DIR/$name"
  plugin_root="$(_plugin_validate_installed_plugin "$plugin_dir" "$name")" || return 1
  source="$(_plugin_read_metadata_field "$plugin_root" source)" || return 1

  case "$source" in
  registry)
    registry_name="$(_plugin_read_metadata_field "$plugin_root" registryName)" || return 1
    registry_file="$(mktemp "$PLUGINS_DIR/.karnel-registry.XXXXXX")" || return 1
    if ! _plugin_fetch_registry "$registry_file"; then
      if ! _plugin_cleanup_temp_file "$registry_file"; then
        log_error "Failed to clean temporary registry data."
      fi
      return 1
    fi
    if ! entry="$(_plugin_registry_entry_for "$registry_file" "$registry_name")"; then
      if ! _plugin_cleanup_temp_file "$registry_file"; then
        log_error "Failed to clean temporary registry data."
      fi
      log_error "Approved registry entry '$registry_name' no longer exists; refusing to update."
      return 1
    fi
    _plugin_cleanup_temp_file "$registry_file" || return 1
    _plugin_install_registry_entry "$entry" 1
    ;;
  unsafe)
    if [[ "$unsafe_flag" != "--unsafe" ]]; then
      log_error "Unsafe plugin '$name' requires --unsafe and confirmation for updates."
      return 1
    fi
    repo="$(_plugin_read_metadata_field "$plugin_root" repo)" || return 1
    ref="$(_plugin_read_metadata_field "$plugin_root" ref)" || return 1
    [[ "$ref" != "detached" ]] || {
      log_error "Unsafe plugin '$name' has no updateable branch or tag. Reinstall it after reviewing the source."
      return 1
    }
    _plugin_confirm_unsafe "$repo" || {
      log_info "Unsafe plugin update cancelled."
      return 1
    }
    _plugin_stage_and_install "$repo" "$ref" "." "" "unsafe" "$name" 1
    ;;
  local)
    log_error "Local plugin '$name' has no remote update source. Publish it and install its approved registry entry instead."
    return 1
    ;;
  *)
    log_error "Unsupported plugin trust source for '$name'."
    return 1
    ;;
  esac
}

reinstall_plugin() {
  local name="$1"
  local unsafe_flag="${2:-}"
  local plugin_dir plugin_root metadata remote repo

  _plugin_validate_name "$name" || return 1
  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_interrupted_replacement "$name" || return 1
  plugin_dir="$PLUGINS_DIR/$name"
  plugin_root="$(_plugin_path_is_inside "$PLUGINS_DIR" "$plugin_dir")" || {
    log_error "Plugin path is outside PLUGINS_DIR: $plugin_dir"
    return 1
  }
  _plugin_validate_symlinks "$plugin_root" || return 1
  metadata="$plugin_root/.karnel-install.json"

  if [[ -f "$metadata" && ! -L "$metadata" ]]; then
    _plugin_validate_plugin_contents "$plugin_root" >/dev/null || return 1
    _plugin_validate_install_metadata "$plugin_root" || return 1
    update_plugin "$name" "$unsafe_flag"
    return $?
  fi

  if [[ "$unsafe_flag" != "--unsafe" ]]; then
    log_error "Legacy plugin '$name' has no trusted metadata. Reinstall requires --unsafe and confirmation."
    return 1
  fi
  _plugin_require_command git || return 1
  if ! remote="$(git -C "$plugin_root" remote get-url origin)"; then
    log_error "Cannot determine the remote for legacy plugin '$name'."
    return 1
  fi
  repo="$(_plugin_repo_from_remote "$remote")" || {
    log_error "Legacy plugin '$name' has an untrusted remote: $remote"
    return 1
  }

  # The remote is validated before staging a replacement; the installed plugin is never deleted first.
  _plugin_install_unsafe_repo "$repo" "$name" 1
}

_plugin_repo_from_remote() {
  local remote="$1"
  local repo=""

  case "$remote" in
  https://github.com/*.git)
    repo="${remote#https://github.com/}"
    repo="${repo%.git}"
    ;;
  git@github.com:*.git)
    repo="${remote#git@github.com:}"
    repo="${repo%.git}"
    ;;
  ssh://git@github.com/*.git)
    repo="${remote#ssh://git@github.com/}"
    repo="${repo%.git}"
    ;;
  *) return 1 ;;
  esac

  _plugin_repo_is_valid "$repo" || return 1
  printf '%s\n' "$repo"
}

update_all_plugins() {
  local plugin_dir name rc failures=0 skipped=0

  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_all_interrupted_replacements || return 1
  for plugin_dir in "$PLUGINS_DIR"/*; do
    [[ -d "$plugin_dir" ]] || continue
    name="${plugin_dir##*/}"
    _plugin_name_is_valid "$name" || continue
    update_plugin "$name"
    rc=$?
    case $rc in
      0) ;;
      2) skipped=$((skipped + 1)) ;;
      *) failures=$((failures + 1)) ;;
    esac
  done

  ((skipped == 0)) || log_info "$skipped plugin update(s) skipped."
  if ((failures > 0)); then
    log_error "$failures plugin update(s) failed."
    return 1
  fi
}

reinstall_all_plugins() {
  local unsafe_flag="${1:-}"
  local plugin_dir name rc failures=0 skipped=0

  if [[ -n "$unsafe_flag" && "$unsafe_flag" != "--unsafe" ]]; then
    log_error "Unknown reinstall option: $unsafe_flag"
    return 1
  fi

  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_all_interrupted_replacements || return 1
  for plugin_dir in "$PLUGINS_DIR"/*; do
    [[ -d "$plugin_dir" ]] || continue
    name="${plugin_dir##*/}"
    _plugin_name_is_valid "$name" || continue
    reinstall_plugin "$name" "$unsafe_flag"
    rc=$?
    case $rc in
      0) ;;
      2) skipped=$((skipped + 1)) ;;
      *) failures=$((failures + 1)) ;;
    esac
  done

  ((skipped == 0)) || log_info "$skipped plugin reinstall(s) skipped."
  if ((failures > 0)); then
    log_error "$failures plugin reinstall(s) failed."
    return 1
  fi
}

_list_plugins() {
  local plugin_dir name plugin_root manifest description version source found=0 failures=0

  _plugin_require_jq || return 1
  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_all_interrupted_replacements || return 1
  for plugin_dir in "$PLUGINS_DIR"/*; do
    [[ -d "$plugin_dir" ]] || continue
    name="${plugin_dir##*/}"
    if ! _plugin_name_is_valid "$name"; then
      log_warn "Ignoring invalid plugin directory: $plugin_dir"
      failures=$((failures + 1))
      continue
    fi
    if ! plugin_root="$(_plugin_validate_installed_plugin "$plugin_dir" "$name")"; then
      printf "  ${D_RED}%-20s${NC} %s\n" "$name" "invalid or untrusted plugin"
      failures=$((failures + 1))
      continue
    fi
    manifest="$plugin_root/karnel-plugin.json"
    description="$(jq -r '.description' "$manifest")" || return 1
    version="$(jq -r '.version' "$manifest")" || return 1
    source="$(_plugin_read_metadata_field "$plugin_root" source)" || return 1
    if _plugin_is_enabled "$plugin_root"; then
      printf "  ${D_GREEN}%-20s${NC} v%-10s [%s] %s\n" "$name" "$version" "$source" "$description"
    else
      printf "  ${D_YELLOW}%-20s${NC} v%-10s [%s] [disabled] %s\n" "$name" "$version" "$source" "$description"
    fi
    found=1
  done

  if ((found == 0 && failures == 0)); then
    echo "  No plugins installed."
  fi
  ((failures == 0))
}

_plugin_collect_commands() {
  local plugin_dir name plugin_root command_name

  _plugin_prepare_plugins_dir || return 1
  _plugin_recover_all_interrupted_replacements || return 1
  for plugin_dir in "$PLUGINS_DIR"/*; do
    [[ -d "$plugin_dir" ]] || continue
    name="${plugin_dir##*/}"
    if ! _plugin_name_is_valid "$name"; then
      log_error "Invalid plugin directory detected: $plugin_dir"
      return 1
    fi
    plugin_root="$(_plugin_validate_installed_plugin "$plugin_dir" "$name")" || return 1
    if ! _plugin_is_enabled "$plugin_root"; then
      continue
    fi
    while IFS= read -r command_name; do
      printf '%s\t%s\t%s\n' "$name" "$plugin_root/commands/$command_name.sh" "$command_name"
    done < <(jq -r '.commands[]' "$plugin_root/karnel-plugin.json")
  done
}

_plugin_dispatch() {
  local command_name="$1"
  shift
  local plugin_name command_file declared_command source_status handler_status command_index
  local -a matches=()

  PLUGIN_DISPATCH_FOUND=0
  _plugin_prepare_plugins_dir || {
    PLUGIN_DISPATCH_FOUND=1
    return 1
  }
  command_index="$(mktemp "$PLUGINS_DIR/.karnel-command-index.XXXXXX")" || {
    PLUGIN_DISPATCH_FOUND=1
    log_error "Failed to create plugin command index."
    return 1
  }
  if ! _plugin_collect_commands >"$command_index"; then
    if ! _plugin_cleanup_temp_file "$command_index"; then
      log_error "Failed to clean plugin command index."
    fi
    PLUGIN_DISPATCH_FOUND=1
    return 1
  fi
  while IFS=$'\t' read -r plugin_name command_file declared_command; do
    [[ "$declared_command" == "$command_name" ]] && matches+=("$plugin_name"$'\t'"$command_file")
  done <"$command_index"
  if ! _plugin_cleanup_temp_file "$command_index"; then
    PLUGIN_DISPATCH_FOUND=1
    log_error "Failed to clean plugin command index."
    return 1
  fi

  if (( ${#matches[@]} == 0 )); then
    return 0
  fi
  if (( ${#matches[@]} > 1 )); then
    PLUGIN_DISPATCH_FOUND=1
    log_error "Plugin command collision detected for '$command_name'. Remove one conflicting plugin."
    return 1
  fi

  IFS=$'\t' read -r plugin_name command_file <<<"${matches[0]}"
  PLUGIN_DISPATCH_FOUND=1
  source "$command_file"
  source_status=$?
  if ((source_status != 0)); then
    log_error "Failed to load command '$command_name' from plugin '$plugin_name'."
    return "$source_status"
  fi

  if ! declare -F "${command_name}_main" >/dev/null; then
    log_error "Plugin '$plugin_name' does not define ${command_name}_main."
    return 126
  fi

  "${command_name}_main" "$@"
  handler_status=$?
  return "$handler_status"
}
