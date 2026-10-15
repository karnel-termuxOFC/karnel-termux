#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/install"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
HERMES_HOME="$HOME/.hermes"
HERMES_ROOT="$KARNEL_DATA/hermes-agent"
HERMES_DIR="$HERMES_ROOT/source"
HERMES_VENV="$HERMES_ROOT/venv"
HERMES_MARKER="$HERMES_ROOT/.karnel-installed"
HERMES_LAUNCHER="$HERMES_ROOT/hermes"
HERMES_REPO="https://github.com/NousResearch/hermes-agent.git"
HERMES_COMMIT="30e9449403c6448d24036ecf31b7f9ceaf67b769"

_hermes_root_owned() {
  [[ -f "$HERMES_MARKER" && "$(<"$HERMES_MARKER")" == "karnel-hermes-agent-v1" ]]
}

_hermes_owned() {
  _hermes_root_owned && [[ -L "$PREFIX/bin/hermes" && "$(readlink "$PREFIX/bin/hermes")" == "$HERMES_LAUNCHER" &&
    -x "$HERMES_LAUNCHER" ]]
}

_hermes_legacy_source() {
  local legacy_dir="$HERMES_HOME/hermes-agent" remote
  [[ -d "$legacy_dir/.git" ]] || return 1
  remote=$(git -C "$legacy_dir" remote get-url origin 2>/dev/null) || return 1
  [[ "$remote" == "https://github.com/NousResearch/hermes-agent.git" ||
    "$remote" == "git@github.com:NousResearch/hermes-agent.git" ]]
}

_hermes_legacy_wrapper() {
  [[ -f "$PREFIX/bin/hermes" && ! -L "$PREFIX/bin/hermes" ]] || return 1
  grep -qF 'from hermes_cli.main import main' "$PREFIX/bin/hermes" && _hermes_legacy_source
}

_patch_psutil_for_termux() {
  "$HERMES_VENV/bin/python" -c "import psutil; print(psutil.__version__)" 2>/dev/null && return 0
  local tmp
  tmp=$(mktemp -d "$KARNEL_CACHE/psutil_patch.XXXXXX") || return 1

  # Fetch the sdist straight from PyPI instead of letting pip "download" it.
  # pip download has to build the package metadata first, and psutil's setup.py
  # exits on sys.platform == "android" before a single byte is written, so the
  # android fix below would never get a chance to run. The sdist URL and its
  # SHA-256 both come from PyPI's own metadata, so the download stays pinned.
  local meta sdist_url sdist_sha sdist_tar
  meta=$(curl -fsSL --connect-timeout 20 "https://pypi.org/pypi/psutil/7.2.2/json") || { rm -rf "$tmp"; return 1; }
  sdist_url=$(printf '%s' "$meta" | jq -r '.urls[] | select(.packagetype=="sdist") | .url' | head -1)
  sdist_sha=$(printf '%s' "$meta" | jq -r '.urls[] | select(.packagetype=="sdist") | .digests.sha256' | head -1)
  if [[ ! $sdist_url =~ ^https://files\.pythonhosted\.org/ ]]; then
    log_error "psutil 7.2.2 sdist is missing from PyPI metadata"
    rm -rf "$tmp"
    return 1
  fi
  sdist_tar="$tmp/psutil-7.2.2.tar.gz"
  curl -fsSL --connect-timeout 20 -o "$sdist_tar" "$sdist_url" || { rm -rf "$tmp"; return 1; }
  verify_sha256 "$sdist_tar" "$sdist_sha" || { rm -rf "$tmp"; return 1; }

  safe_extract_tar "$sdist_tar" "$tmp" || { rm -rf "$tmp"; return 1; }
  sed -i 's/LINUX = sys.platform.startswith("linux")/LINUX = sys.platform.startswith(("linux", "android"))/' "$tmp/psutil-7.2.2/psutil/_common.py" || { rm -rf "$tmp"; return 1; }
  # --no-build-isolation: an isolated build runs in a throwaway environment
  # that inherits this Termux platform, so psutil's setup.py would refuse it
  # again. Building against the venv keeps the patched source in play.
  "$HERMES_VENV/bin/python" -m pip install --no-build-isolation "$tmp/psutil-7.2.2" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

_prebuild_c_exts() {
  # pybind11 is imported by the build of uvloop/tornado but is not declared as
  # a build requirement, so metadata generation dies on a bare venv. Put it in
  # place first.
  for pkg in pybind11 ruamel.yaml.clib uvloop tornado; do
    "$HERMES_VENV/bin/python" -m pip install "$pkg" 2>>"$LOG_FILE" || return 1
  done
}

_hermes_relax_python_requirement() {
  local pyproject="$HERMES_DIR/pyproject.toml"
  if ! grep -q '^requires-python' "$pyproject"; then
    return 0
  fi
  sed -i -E 's/^requires-python\s*=.*/requires-python = ">=3.11,<3.15"/' "$pyproject"
  return 0
}

_install_hermes_agent_impl() {
  local legacy_dir="$HERMES_HOME/hermes-agent" legacy_wrapper=0
  _hermes_legacy_wrapper && legacy_wrapper=1
  if [[ -e "$PREFIX/bin/hermes" || -L "$PREFIX/bin/hermes" ]]; then
    if ! _hermes_owned && (( legacy_wrapper == 0 )); then
      log_error "hermes command is owned by another installation"
      return 1
    fi
  fi
  if [[ -e "$HERMES_ROOT" && ! -f "$HERMES_MARKER" ]]; then
    log_error "Hermes data directory is not owned by Karnel"
    return 1
  fi
  mkdir -p "$HERMES_ROOT" "$PREFIX/bin" || return 1
  if ! _hermes_root_owned; then
    printf '%s\n' 'karnel-hermes-agent-v1' >"$HERMES_MARKER" || return 1
  fi
  if [[ ! -e "$HERMES_DIR" ]] && _hermes_legacy_source; then
    mv "$legacy_dir" "$HERMES_DIR" || return 1
    printf '%s\n%s\n' 'karnel-pinned-git-v1' "$HERMES_REPO" >"$HERMES_DIR/.karnel-pinned-git" || return 1
  fi

  install_pinned_git_repo "$HERMES_REPO" "$HERMES_COMMIT" "$HERMES_DIR" || return 1

  _hermes_relax_python_requirement || return 1
  [[ -x "$HERMES_VENV/bin/python" ]] || python3 -m venv "$HERMES_VENV" || return 1
  # A 3.12+ venv ships pip but not setuptools, and every --no-build-isolation
  # install below needs setuptools.build_meta to be importable inside it.
  # maturin is needed because openai pulls in jiter, a Rust extension with no
  # Android wheel; without it, metadata generation dies on "Cannot import
  # 'maturin'". Exposing the venv's bin on PATH matters too: maturin's Python
  # shim shells out to the maturin binary by name.
  export PATH="$HERMES_VENV/bin:$PATH"
  "$HERMES_VENV/bin/python" -m pip install --quiet --upgrade setuptools wheel 2>>"$LOG_FILE" || return 1
  "$HERMES_VENV/bin/python" -m pip install --quiet maturin 2>>"$LOG_FILE" || return 1
  _patch_psutil_for_termux || return 1
  _prebuild_c_exts || return 1
  # Editable, not a built wheel: upstream refuses to produce one on purpose
  # ("Building wheels or sdists for hermes-agent is not supported") and points
  # at an editable install instead. Building from source is what failed here.
  "$HERMES_VENV/bin/python" -m pip install --no-build-isolation -e "$HERMES_DIR" || return 1

  # cryptography 50.0.0 builds here but its extension cannot be dlopened on
  # Android ("cannot locate symbol PyModule_Type") - it breaks every
  # `import cryptography` on the device, not just ours, and Hermes needs it for
  # its secret sources. 44.0.3 builds and imports cleanly, and nothing in
  # Hermes requires the newer major.
  if ! "$HERMES_VENV/bin/python" -c "import cryptography.hazmat.primitives.hashes" &>/dev/null; then
    "$HERMES_VENV/bin/python" -m pip install --no-build-isolation --force-reinstall "cryptography==44.0.3" 2>>"$LOG_FILE" || return 1
  fi

  printf '%s\n' "#!$HERMES_VENV/bin/python" 'from hermes_cli.main import main' 'main()' >"$HERMES_LAUNCHER" || return 1
  chmod +x "$HERMES_LAUNCHER" || return 1
  if (( legacy_wrapper != 0 )); then rm -f "$PREFIX/bin/hermes" || return 1; fi
  if [[ ! -L "$PREFIX/bin/hermes" ]]; then
    ln -s "$HERMES_LAUNCHER" "$PREFIX/bin/hermes" || return 1
  fi
}

install_hermes_agent() {
  if _hermes_owned; then
    log_info "Hermes Agent is already installed"
    return 2
  fi
  if command -v hermes &>/dev/null && ! _hermes_legacy_wrapper; then
    log_error "hermes command is owned by another installation"
    return 1
  fi

  log_info "Installing Hermes Agent (gambiarra Termux)..."
  mkdir -p "$(dirname "$LOG_FILE")" || return 1

  loading "Installing Hermes Agent" _install_hermes_agent_impl || return 1

  if _hermes_owned && command -v hermes &>/dev/null; then
    log_success "Hermes Agent installed successfully"
    return 0
  else
    log_error "Failed to install Hermes Agent"
    return 1
  fi
}

uninstall_hermes_agent() {
  if ! _hermes_root_owned; then
    log_info "Hermes Agent is not installed"
    return 2
  fi
  log_info "Uninstalling Hermes Agent..."
  mkdir -p "$(dirname "$LOG_FILE")"

  loading "Removing Hermes Agent" _uninstall_hermes_agent_impl || return 1

  log_success "Hermes Agent uninstalled successfully"
  return 0
}

_uninstall_hermes_agent_impl() {
  if [[ -L "$PREFIX/bin/hermes" && "$(readlink "$PREFIX/bin/hermes")" == "$HERMES_LAUNCHER" ]]; then
    rm -f "$PREFIX/bin/hermes" || return 1
  fi
  if rm -rf "$HERMES_ROOT" &>>"$LOG_FILE"; then
    return 0
  else
    log_error "Failed to uninstall Hermes Agent"
    return 1
  fi
}

update_hermes_agent() {
  _update_hermes_agent_impl
}

_update_hermes_agent_impl() {
  _hermes_owned || { log_error "Hermes Agent is not installed by Karnel"; return 1; }
  install_pinned_git_repo "$HERMES_REPO" "$HERMES_COMMIT" "$HERMES_DIR" || return 1
  _hermes_relax_python_requirement || return 1
  # Same two constraints as the install path: editable because upstream
  # forbids building a wheel, and the venv on PATH so maturin can be found.
  export PATH="$HERMES_VENV/bin:$PATH"
  "$HERMES_VENV/bin/python" -m pip install --no-build-isolation -e "$HERMES_DIR"
}

reinstall_hermes_agent() {
  uninstall_hermes_agent || return $?
  install_hermes_agent
}
