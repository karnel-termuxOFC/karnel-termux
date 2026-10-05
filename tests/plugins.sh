#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
TEST_REMOTES="$TEST_ROOT/remotes"
TEST_REGISTRY="$TEST_ROOT/registry.json"
TEST_NETWORK_DOWN=0
TESTS_RUN=0
TESTS_FAILED=0

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

export HOME="$TEST_ROOT/home"
export XDG_DATA_HOME="$TEST_ROOT/data"
export KARNEL_PATH="$ROOT_DIR/karnel"
mkdir -p "$HOME" "$TEST_REMOTES"

source "$KARNEL_PATH/utils/bootstrap.sh"
source "$KARNEL_PATH/utils/env.sh"
source "$KARNEL_PATH/utils/colors.sh"
source "$KARNEL_PATH/utils/log.sh"
source "$KARNEL_PATH/tools/plugins/install.sh"
source "$KARNEL_PATH/cli/karnel.sh"
source "$KARNEL_PATH/cli/commands/plugin.sh"

_plugin_fetch_registry() {
  local destination="$1"

  if [[ "$TEST_NETWORK_DOWN" == "1" ]]; then
    log_error "Test registry is unavailable."
    return 1
  fi
  cp -- "$TEST_REGISTRY" "$destination"
  _plugin_validate_registry "$destination"
}

_plugin_clone_repository() {
  local repo="$1"
  local ref="$2"
  local destination="$3"
  local source="$TEST_REMOTES/$repo"

  [[ -d "$source" ]] || {
    log_error "Test repository does not exist: $repo"
    return 1
  }
  if [[ -n "$ref" ]]; then
    git clone --quiet --depth=1 --branch "$ref" "file://$source" "$destination"
  else
    git clone --quiet --depth=1 "file://$source" "$destination"
  fi
}

_plugin_confirm_unsafe() {
  return 0
}

assert_true() {
  local message="$1"
  shift

  if "$@"; then
    return 0
  fi
  printf 'Assertion failed: %s\n' "$message" >&2
  return 1
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  fi
  printf 'Assertion failed: %s (expected %q, got %q)\n' "$message" "$expected" "$actual" >&2
  return 1
}

run_test() {
  local name="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))

  local rc=0 errexit_was_on=0
  [[ $- == *e* ]] && errexit_was_on=1
  set +e
  ( set -e; "$@" )
  rc=$?
  if (( errexit_was_on )); then set -e; fi
  if (( rc == 0 )); then
    printf 'ok - %s\n' "$name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'not ok - %s\n' "$name" >&2
  fi
}

reset_state() {
  rm -rf -- "$TEST_ROOT/plugins"
  mkdir -p "$TEST_ROOT/plugins"
  PLUGINS_DIR="$TEST_ROOT/plugins"
  TEST_NETWORK_DOWN=0
  write_registry
}

write_registry() {
  local plugins='[]'
  local entry

  if (( $# > 0 )); then
    plugins="$(printf '%s\n' "$@" | jq -cs '.')"
  fi
  jq -n --argjson plugins "$plugins" '{schemaVersion: 1, description: "Test approved registry", plugins: $plugins}' >"$TEST_REGISTRY"
}

write_plugin_files() {
  local plugin_dir="$1"
  local name="$2"
  local version="$3"
  local command_name="$4"
  local message="$5"
  local exit_code="$6"
  local manifest="$plugin_dir/karnel-plugin.json"
  local checksum

  mkdir -p "$plugin_dir/commands"
  printf "%s_main() {\n  printf '%%s\\n' '%s'\n  return %s\n}\n" "$command_name" "$message" "$exit_code" >"$plugin_dir/commands/$command_name.sh"
  printf '%s\n' 'MIT License' >"$plugin_dir/LICENSE"
  jq -n \
    --arg name "$name" \
    --arg version "$version" \
    --arg command "$command_name" \
    --arg minimum "$KARNEL_VERSION" \
    '{schemaVersion: 1, name: $name, version: $version, description: ("Test plugin " + $name), commands: [$command], minKarnelVersion: $minimum, license: "MIT", capabilities: []}' >"$manifest"
  checksum="$(_plugin_payload_checksum "$plugin_dir")"
  jq --arg checksum "$checksum" '. + {checksum: $checksum}' "$manifest" >"$manifest.tmp"
  mv -- "$manifest.tmp" "$manifest"
}

refresh_payload_checksum() {
  local plugin_dir="$1"
  local manifest="$plugin_dir/karnel-plugin.json"
  local checksum

  checksum="$(_plugin_payload_checksum "$plugin_dir")"
  jq --arg checksum "$checksum" '.checksum = $checksum' "$manifest" >"$manifest.tmp"
  mv -- "$manifest.tmp" "$manifest"
}

create_plugin_repo() {
  local owner="$1"
  local repo="$2"
  local name="$3"
  local version="$4"
  local command_name="$5"
  local message="$6"
  local exit_code="$7"
  local plugin_dir="$TEST_REMOTES/$owner/$repo"

  mkdir -p "$plugin_dir"
  git init --quiet -b main "$plugin_dir"
  git -C "$plugin_dir" config user.email "tests@example.invalid"
  git -C "$plugin_dir" config user.name "Karnel Tests"
  write_plugin_files "$plugin_dir" "$name" "$version" "$command_name" "$message" "$exit_code"
  git -C "$plugin_dir" add .
  git -C "$plugin_dir" commit --quiet -m "initial plugin"
}

update_plugin_repo() {
  local owner="$1"
  local repo="$2"
  local name="$3"
  local version="$4"
  local command_name="$5"
  local message="$6"
  local exit_code="$7"
  local plugin_dir="$TEST_REMOTES/$owner/$repo"

  write_plugin_files "$plugin_dir" "$name" "$version" "$command_name" "$message" "$exit_code"
  git -C "$plugin_dir" add .
  git -C "$plugin_dir" commit --quiet -m "update plugin"
}

registry_entry() {
  local owner="$1"
  local repo="$2"
  local manifest="$TEST_REMOTES/$owner/$repo/karnel-plugin.json"

  jq -c --arg repo "$owner/$repo" '
    {
      name,
      repo: $repo,
      ref: "main",
      version,
      description,
      commands,
      minKarnelVersion,
      license,
      checksum,
      capabilities
    }
  ' "$manifest"
}

registry_entry_at_path() {
  local owner="$1"
  local repo="$2"
  local relative_path="$3"
  local manifest="$TEST_REMOTES/$owner/$repo/$relative_path/karnel-plugin.json"

  jq -c --arg repo "$owner/$repo" --arg path "$relative_path" '
    {
      name,
      repo: $repo,
      ref: "main",
      path: $path,
      version,
      description,
      commands,
      minKarnelVersion,
      license,
      checksum,
      capabilities
    }
  ' "$manifest"
}

registry_entry_for_invalid_source() {
  local name="$1"
  local owner="$2"
  local repo="$3"
  local command_name="$4"

  jq -cn \
    --arg name "$name" \
    --arg repo "$owner/$repo" \
    --arg command "$command_name" \
    --arg minimum "$KARNEL_VERSION" \
    '{name: $name, repo: $repo, ref: "main", version: "1.0.0", description: "Invalid source fixture", commands: [$command], minKarnelVersion: $minimum, license: "MIT", checksum: "sha256:0000000000000000000000000000000000000000000000000000000000000000", capabilities: []}'
}

test_registry_multiline_search_and_empty_registry() {
  reset_state
  create_plugin_repo registry search search-plugin 1.0.0 registry-search registry-ok 0
  local entry output
  entry="$(registry_entry registry search)"
  write_registry "$entry"

  output="$(karnel_main plugin search --command registry-search --compatible)"
  [[ "$output" == *"search-plugin"* ]] || return 1
  [[ "$output" == *"karnel plugin install search-plugin"* ]] || return 1

  write_registry
  output="$(karnel_main plugin search)"
  [[ "$output" == *"No plugins match"* ]]
}

test_valid_install_and_dispatch() {
  reset_state
  create_plugin_repo trusted valid valid-plugin 1.0.0 valid-command installed-ok 0
  write_registry "$(registry_entry trusted valid)"

  karnel_main plugin install valid-plugin >/dev/null
  assert_true "valid plugin directory exists" test -d "$PLUGINS_DIR/valid-plugin"
  assert_true "metadata exists" test -f "$PLUGINS_DIR/valid-plugin/.karnel-install.json"

  local output
  output="$(karnel_main valid-command)"
  [[ "$output" == "installed-ok" ]]
}

test_official_style_plugin_from_subdirectory() {
  reset_state
  local owner="israelmarques1024-dotcom"
  local repo="karnel-plugins"
  local source="$TEST_REMOTES/$owner/$repo"
  local output

  mkdir -p "$source/plugins/karnel-hello"
  git init --quiet -b main "$source"
  git -C "$source" config user.email "tests@example.invalid"
  git -C "$source" config user.name "Karnel Tests"
  write_plugin_files "$source/plugins/karnel-hello" karnel-hello 1.0.0 karnel-hello "Hello from the official Karnel plugin." 0
  git -C "$source" add .
  git -C "$source" commit --quiet -m "official plugin fixture"
  write_registry "$(registry_entry_at_path "$owner" "$repo" "plugins/karnel-hello")"

  karnel_main plugin install karnel-hello >/dev/null
  output="$(karnel_main karnel-hello)"
  [[ "$output" == "Hello from the official Karnel plugin." ]]
}

test_missing_and_malformed_manifests_leave_no_residue() {
  reset_state
  local missing="$TEST_REMOTES/bad/missing"
  local malformed="$TEST_REMOTES/bad/malformed"
  mkdir -p "$missing" "$malformed"
  git init --quiet -b main "$missing"
  git -C "$missing" config user.email "tests@example.invalid"
  git -C "$missing" config user.name "Karnel Tests"
  printf '%s\n' 'placeholder' >"$missing/README.md"
  git -C "$missing" add .
  git -C "$missing" commit --quiet -m "missing manifest"

  git init --quiet -b main "$malformed"
  git -C "$malformed" config user.email "tests@example.invalid"
  git -C "$malformed" config user.name "Karnel Tests"
  mkdir -p "$malformed/commands"
  printf '%s\n' '{bad json' >"$malformed/karnel-plugin.json"
  printf '%s\n' 'MIT License' >"$malformed/LICENSE"
  git -C "$malformed" add .
  git -C "$malformed" commit --quiet -m "malformed manifest"

  write_registry \
    "$(registry_entry_for_invalid_source missing-plugin bad missing missing-command)" \
    "$(registry_entry_for_invalid_source malformed-plugin bad malformed malformed-command)"
  if install_plugin missing-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin malformed-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ ! -e "$PLUGINS_DIR/missing-plugin" && ! -e "$PLUGINS_DIR/malformed-plugin" ]] || return 1
  ! compgen -G "$PLUGINS_DIR/.karnel-plugin.*" >/dev/null
}

test_schema_integrity_compatibility_handlers_symlinks_and_native_collisions_are_rejected() {
  reset_state
  create_plugin_repo invalid schema schema-plugin 1.0.0 schema-command schema 0
  jq '. + {unexpected: true}' "$TEST_REMOTES/invalid/schema/karnel-plugin.json" >"$TEST_REMOTES/invalid/schema/karnel-plugin.json.tmp"
  mv -- "$TEST_REMOTES/invalid/schema/karnel-plugin.json.tmp" "$TEST_REMOTES/invalid/schema/karnel-plugin.json"
  git -C "$TEST_REMOTES/invalid/schema" add karnel-plugin.json
  git -C "$TEST_REMOTES/invalid/schema" commit --quiet -m "unknown manifest field"

  create_plugin_repo invalid symlink symlink-plugin 1.0.0 symlink-command symlink 0
  local outside="$TEST_ROOT/outside-command"
  printf '%s\n' 'outside' >"$outside"
  rm -- "$TEST_REMOTES/invalid/symlink/commands/symlink-command.sh"
  ln -s "$outside" "$TEST_REMOTES/invalid/symlink/commands/symlink-command.sh"
  git -C "$TEST_REMOTES/invalid/symlink" add -A
  git -C "$TEST_REMOTES/invalid/symlink" commit --quiet -m "escaping command symlink"

  create_plugin_repo invalid incompatible incompatible-plugin 1.0.0 incompatible-command incompatible 0
  jq '.minKarnelVersion = "99.0.0"' "$TEST_REMOTES/invalid/incompatible/karnel-plugin.json" >"$TEST_REMOTES/invalid/incompatible/karnel-plugin.json.tmp"
  mv -- "$TEST_REMOTES/invalid/incompatible/karnel-plugin.json.tmp" "$TEST_REMOTES/invalid/incompatible/karnel-plugin.json"
  git -C "$TEST_REMOTES/invalid/incompatible" add karnel-plugin.json
  git -C "$TEST_REMOTES/invalid/incompatible" commit --quiet -m "incompatible plugin"

  create_plugin_repo invalid checksum checksum-plugin 1.0.0 checksum-command checksum 0
  jq '.checksum = "sha256:0000000000000000000000000000000000000000000000000000000000000000"' "$TEST_REMOTES/invalid/checksum/karnel-plugin.json" >"$TEST_REMOTES/invalid/checksum/karnel-plugin.json.tmp"
  mv -- "$TEST_REMOTES/invalid/checksum/karnel-plugin.json.tmp" "$TEST_REMOTES/invalid/checksum/karnel-plugin.json"
  git -C "$TEST_REMOTES/invalid/checksum" add karnel-plugin.json
  git -C "$TEST_REMOTES/invalid/checksum" commit --quiet -m "invalid checksum"

  create_plugin_repo invalid handler handler-plugin 1.0.0 handler-command handler 0
  printf '%s\n' 'wrong_handler() { return 0; }' >"$TEST_REMOTES/invalid/handler/commands/handler-command.sh"
  refresh_payload_checksum "$TEST_REMOTES/invalid/handler"
  git -C "$TEST_REMOTES/invalid/handler" add .
  git -C "$TEST_REMOTES/invalid/handler" commit --quiet -m "missing declared handler"

  create_plugin_repo invalid payload payload-plugin 1.0.0 payload-command payload 0
  mkdir -p "$TEST_REMOTES/invalid/payload/helpers"
  printf '%s\n' 'helper version one' >"$TEST_REMOTES/invalid/payload/helpers/shared.sh"
  refresh_payload_checksum "$TEST_REMOTES/invalid/payload"
  git -C "$TEST_REMOTES/invalid/payload" add .
  git -C "$TEST_REMOTES/invalid/payload" commit --quiet -m "add helper"
  printf '%s\n' 'helper version two' >"$TEST_REMOTES/invalid/payload/helpers/shared.sh"
  git -C "$TEST_REMOTES/invalid/payload" add helpers/shared.sh
  git -C "$TEST_REMOTES/invalid/payload" commit --quiet -m "modify unchecked helper"

  create_plugin_repo invalid native native-plugin 1.0.0 plugin native 0
  write_registry \
    "$(registry_entry invalid schema)" \
    "$(registry_entry invalid symlink)" \
    "$(registry_entry invalid incompatible)" \
    "$(registry_entry invalid checksum)" \
    "$(registry_entry invalid handler)" \
    "$(registry_entry invalid payload)" \
    "$(registry_entry invalid native)"

  if install_plugin schema-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin symlink-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin incompatible-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin checksum-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin handler-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin payload-plugin >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin native-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ ! -e "$PLUGINS_DIR/schema-plugin" && ! -e "$PLUGINS_DIR/symlink-plugin" && ! -e "$PLUGINS_DIR/incompatible-plugin" && ! -e "$PLUGINS_DIR/checksum-plugin" && ! -e "$PLUGINS_DIR/handler-plugin" && ! -e "$PLUGINS_DIR/payload-plugin" && ! -e "$PLUGINS_DIR/native-plugin" ]]
}

test_interrupted_replacement_and_legacy_reinstall_are_recovered() {
  reset_state
  create_plugin_repo legacy source legacy-plugin 1.0.0 legacy-command before 0
  write_registry "$(registry_entry legacy source)"
  install_plugin legacy-plugin >/dev/null

  mv -- "$PLUGINS_DIR/legacy-plugin" "$PLUGINS_DIR/.karnel-backup-legacy-plugin.interrupted"
  TEST_NETWORK_DOWN=1
  if update_plugin legacy-plugin >/dev/null 2>&1; then
    return 1
  fi
  TEST_NETWORK_DOWN=0
  [[ -d "$PLUGINS_DIR/legacy-plugin" && ! -e "$PLUGINS_DIR/.karnel-backup-legacy-plugin.interrupted" ]] || return 1

  rm -- "$PLUGINS_DIR/legacy-plugin/.karnel-install.json"
  jq '{name, version, description, commands: [], tools: []}' "$PLUGINS_DIR/legacy-plugin/karnel-plugin.json" >"$PLUGINS_DIR/legacy-plugin/karnel-plugin.json.tmp"
  mv -- "$PLUGINS_DIR/legacy-plugin/karnel-plugin.json.tmp" "$PLUGINS_DIR/legacy-plugin/karnel-plugin.json"
  git -C "$PLUGINS_DIR/legacy-plugin" remote set-url origin "https://github.com/legacy/source.git"
  if karnel_main reinstall plugin >/dev/null 2>&1; then
    return 1
  fi
  karnel_main reinstall plugin --unsafe >/dev/null
  [[ "$(jq -r '.source' "$PLUGINS_DIR/legacy-plugin/.karnel-install.json")" == "unsafe" ]]
}

test_active_operation_lock_prevents_concurrent_activation() {
  reset_state
  create_plugin_repo locking source locked-plugin 1.0.0 locked-command locked 0
  write_registry "$(registry_entry locking source)"
  mkdir "$PLUGINS_DIR/.karnel-lock-locked-plugin"
  printf '%s\n' "${BASHPID:-$$}" >"$PLUGINS_DIR/.karnel-lock-locked-plugin/pid"

  if install_plugin locked-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ ! -e "$PLUGINS_DIR/locked-plugin" ]] || return 1
  rm -rf -- "$PLUGINS_DIR/.karnel-lock-locked-plugin"
  install_plugin locked-plugin >/dev/null
  [[ -d "$PLUGINS_DIR/locked-plugin" ]]
}

test_active_operation_lock_prevents_removal() {
  reset_state
  create_plugin_repo locking removal removal-plugin 1.0.0 removal-command removal 0
  write_registry "$(registry_entry locking removal)"
  install_plugin removal-plugin >/dev/null
  mkdir "$PLUGINS_DIR/.karnel-lock-removal-plugin"
  printf '%s\n' "${BASHPID:-$$}" >"$PLUGINS_DIR/.karnel-lock-removal-plugin/pid"

  if uninstall_plugin removal-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ -d "$PLUGINS_DIR/removal-plugin" ]] || return 1

  rm -rf -- "$PLUGINS_DIR/.karnel-lock-removal-plugin"
  uninstall_plugin removal-plugin >/dev/null
  [[ ! -e "$PLUGINS_DIR/removal-plugin" ]]
}

test_stale_operation_locks_are_recovered() {
  reset_state
  local lock start lock_case

  for lock_case in empty orphan reused; do
    lock="$PLUGINS_DIR/.karnel-lock-stale-plugin"
    mkdir "$lock"
    case "$lock_case" in
      orphan) printf '%s\n' 99999999 >"$lock/pid" ;;
      reused)
        printf '%s\n' "${BASHPID:-$$}" >"$lock/pid"
        start="$(_karnel_process_start_time "${BASHPID:-$$}")" || return 1
        printf '%s\n' "$((start + 1))" >"$lock/start"
        ;;
    esac
    _plugin_acquire_plugin_lock stale-plugin || return 1
    _plugin_release_plugin_lock || return 1
  done
}

test_create_and_legacy_module_do_not_install_false_plugin() {
  reset_state
  local output
  output="$(karnel_main plugin create local-plugin)"
  [[ "$output" == *"scaffolded"* ]] || return 1
  [[ "$(karnel_main local-plugin)" == "Hello from local-plugin" ]] || return 1

  karnel_main plugin remove local-plugin >/dev/null
  output="$(karnel_main install plugin)"
  [[ "$output" == *"built in"* ]] || return 1
  ! compgen -G "$PLUGINS_DIR/*" >/dev/null
}

test_path_traversal_is_rejected() {
  reset_state
  local outside="$TEST_ROOT/outside"
  mkdir -p "$outside"
  printf '%s\n' keep >"$outside/marker"

  if install_plugin ../outside >/dev/null 2>&1; then
    return 1
  fi
  if _scaffold_plugin ../outside >/dev/null 2>&1; then
    return 1
  fi
  if uninstall_plugin ../outside >/dev/null 2>&1; then
    return 1
  fi
  [[ -f "$outside/marker" ]]
}

test_command_collisions_are_blocked() {
  reset_state
  create_plugin_repo collision first first-plugin 1.0.0 shared-command first 0
  create_plugin_repo collision second second-plugin 1.0.0 shared-command second 0
  write_registry "$(registry_entry collision first)" "$(registry_entry collision second)"

  install_plugin first-plugin >/dev/null
  if install_plugin second-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ -d "$PLUGINS_DIR/first-plugin" && ! -e "$PLUGINS_DIR/second-plugin" ]]
}

test_dispatch_preserves_plugin_exit_code() {
  reset_state
  create_plugin_repo dispatch failing failing-plugin 1.0.0 failing-command failure 42
  write_registry "$(registry_entry dispatch failing)"
  install_plugin failing-plugin >/dev/null

  local output status
  if output="$(karnel_main failing-command 2>&1)"; then
    status=0
  else
    status=$?
  fi
  assert_equals 42 "$status" "dispatcher preserves plugin exit code"
  [[ "$output" == *"failure"* && "$output" != *"Command not found"* ]]
}

test_update_is_atomic_and_records_new_commit() {
  reset_state
  create_plugin_repo lifecycle update update-plugin 1.0.0 update-command version-one 0
  write_registry "$(registry_entry lifecycle update)"
  install_plugin update-plugin >/dev/null
  local old_commit new_commit output
  old_commit="$(jq -r '.commit' "$PLUGINS_DIR/update-plugin/.karnel-install.json")"

  update_plugin_repo lifecycle update update-plugin 1.1.0 update-command version-two 0
  write_registry "$(registry_entry lifecycle update)"
  karnel_main plugin update update-plugin >/dev/null
  new_commit="$(jq -r '.commit' "$PLUGINS_DIR/update-plugin/.karnel-install.json")"
  output="$(karnel_main update-command)"

  [[ "$old_commit" != "$new_commit" ]] || return 1
  [[ "$(jq -r '.version' "$PLUGINS_DIR/update-plugin/karnel-plugin.json")" == "1.1.0" ]] || return 1
  [[ "$output" == "version-two" ]]
}

test_reinstall_uses_validated_replacement() {
  reset_state
  create_plugin_repo lifecycle reinstall reinstall-plugin 1.0.0 reinstall-command before-reinstall 0
  write_registry "$(registry_entry lifecycle reinstall)"
  install_plugin reinstall-plugin >/dev/null

  update_plugin_repo lifecycle reinstall reinstall-plugin 1.1.0 reinstall-command after-reinstall 0
  write_registry "$(registry_entry lifecycle reinstall)"
  reinstall_plugin reinstall-plugin >/dev/null

  [[ "$(jq -r '.version' "$PLUGINS_DIR/reinstall-plugin/karnel-plugin.json")" == "1.1.0" ]] || return 1
  [[ "$(karnel_main reinstall-command)" == "after-reinstall" ]]
}

test_secure_removal_and_symlink_guard() {
  reset_state
  create_plugin_repo remove safe removable-plugin 1.0.0 removable-command remove 0
  write_registry "$(registry_entry remove safe)"
  install_plugin removable-plugin >/dev/null
  karnel_main plugin remove removable-plugin >/dev/null
  [[ ! -e "$PLUGINS_DIR/removable-plugin" ]] || return 1

  local outside="$TEST_ROOT/removal-outside"
  mkdir -p "$outside"
  printf '%s\n' keep >"$outside/marker"
  ln -s "$outside" "$PLUGINS_DIR/trap-plugin"
  if uninstall_plugin trap-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ -f "$outside/marker" ]]
}

test_failed_update_rolls_back() {
  reset_state
  create_plugin_repo lifecycle rollback rollback-plugin 1.0.0 rollback-command stable 0
  write_registry "$(registry_entry lifecycle rollback)"
  install_plugin rollback-plugin >/dev/null

  printf '%s\n' '{invalid json' >"$TEST_REMOTES/lifecycle/rollback/karnel-plugin.json"
  git -C "$TEST_REMOTES/lifecycle/rollback" add karnel-plugin.json
  git -C "$TEST_REMOTES/lifecycle/rollback" commit --quiet -m "break manifest"
  if update_plugin rollback-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ "$(jq -r '.version' "$PLUGINS_DIR/rollback-plugin/karnel-plugin.json")" == "1.0.0" ]] || return 1
  [[ "$(karnel_main rollback-command)" == "stable" ]]
}

test_network_failure_and_unsafe_trust_gate() {
  reset_state
  create_plugin_repo arbitrary source arbitrary-plugin 1.0.0 arbitrary-command unsafe-ok 0
  write_registry

  if install_plugin arbitrary/source >/dev/null 2>&1; then
    return 1
  fi
  karnel_main plugin install arbitrary/source --unsafe >/dev/null
  [[ -d "$PLUGINS_DIR/arbitrary-plugin" ]] || return 1

  reset_state
  TEST_NETWORK_DOWN=1
  if karnel_main plugin search >/dev/null 2>&1; then
    return 1
  fi
  if install_plugin arbitrary-plugin >/dev/null 2>&1; then
    return 1
  fi
  [[ ! -e "$PLUGINS_DIR/arbitrary-plugin" ]]
}

test_registry_root_is_pinned_and_verified() {
  local original_checksum="$PLUGIN_REGISTRY_SHA256"
  local checksum

  [[ "$PLUGIN_REGISTRY_URL" == *"/$PLUGIN_REGISTRY_COMMIT/registry.json" ]] || return 1
  [[ "$PLUGIN_REGISTRY_COMMIT" =~ ^[0-9a-f]{40}$ ]] || return 1
  [[ "$PLUGIN_REGISTRY_SHA256" =~ ^[0-9a-f]{64}$ ]] || return 1

  checksum="$(_plugin_file_sha256 "$TEST_REGISTRY")" || return 1
  PLUGIN_REGISTRY_SHA256="$checksum"
  _plugin_verify_registry_checksum "$TEST_REGISTRY" || return 1

  PLUGIN_REGISTRY_SHA256="0000000000000000000000000000000000000000000000000000000000000000"
  if _plugin_verify_registry_checksum "$TEST_REGISTRY" >/dev/null 2>&1; then
    PLUGIN_REGISTRY_SHA256="$original_checksum"
    return 1
  fi
  PLUGIN_REGISTRY_SHA256="$original_checksum"
}

run_test "registry multiline, filters and empty registry" test_registry_multiline_search_and_empty_registry
run_test "valid approved installation and dispatch" test_valid_install_and_dispatch
run_test "official-style subdirectory plugin completes the trusted flow" test_official_style_plugin_from_subdirectory
run_test "missing or malformed manifest rolls back" test_missing_and_malformed_manifests_leave_no_residue
run_test "schema, integrity, compatibility, handlers, symlinks and native collisions are rejected" test_schema_integrity_compatibility_handlers_symlinks_and_native_collisions_are_rejected
run_test "interrupted replacement and legacy reinstall recover safely" test_interrupted_replacement_and_legacy_reinstall_are_recovered
run_test "active operation lock prevents concurrent activation" test_active_operation_lock_prevents_concurrent_activation
run_test "active operation lock prevents concurrent removal" test_active_operation_lock_prevents_removal
run_test "stale operation locks are recovered" test_stale_operation_locks_are_recovered
run_test "create works and legacy module does not clone Karnel" test_create_and_legacy_module_do_not_install_false_plugin
run_test "path traversal is rejected" test_path_traversal_is_rejected
run_test "plugin command collisions are blocked" test_command_collisions_are_blocked
run_test "dispatcher preserves command exit code" test_dispatch_preserves_plugin_exit_code
run_test "approved update is atomic and records commit" test_update_is_atomic_and_records_new_commit
run_test "reinstall uses validated replacement" test_reinstall_uses_validated_replacement
run_test "removal stays inside plugin directory" test_secure_removal_and_symlink_guard
run_test "failed update preserves installed plugin" test_failed_update_rolls_back
run_test "network failures and unsafe trust gate" test_network_failure_and_unsafe_trust_gate
run_test "registry root is pinned and checksum verified" test_registry_root_is_pinned_and_verified

printf 'Plugin tests: %d run, %d failure(s)\n' "$TESTS_RUN" "$TESTS_FAILED"
((TESTS_FAILED == 0))
