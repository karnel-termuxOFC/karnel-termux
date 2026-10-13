#!/usr/bin/env bash
import "@/utils/log"
import "@/utils/version"
import "@/utils/install"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
CODEGRAPH_DATA_DIR="$KARNEL_DATA/codegraph-linux-arm64"
CODEGRAPH_MARKER="$CODEGRAPH_DATA_DIR/.karnel-managed"
CODEGRAPH_WRAPPER_MARKER="$CODEGRAPH_DATA_DIR/.karnel-wrapper"

_codegraph_dependencies() {
	loading "Installing dependencies" _codegraph_dependencies_impl
}

_codegraph_dependencies_impl() {
	declare -A DEPS=(
		["nodejs-lts"]="node"
		["ripgrep"]="rg"
		["sqlite"]="sqlite"
		["git"]="git"
		["python"]="python"
		["clang"]="cc"
		["make"]="make"
		["curl"]="curl"
	)

	local pkg_name bin_name
	for pkg_name in "${!DEPS[@]}"; do
		bin_name="${DEPS[$pkg_name]}"
		if ! command -v "$bin_name" &>/dev/null; then
			if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
				log_error "Failed to install $pkg_name"
				return 1
			fi
		fi
	done

	return 0
}

_download_codegraph() {
	loading "Downloading CodeGraph" _download_codegraph_impl
}

_download_codegraph_impl() {
	local staging_dir old_dir LATEST_VERSION
	case "$(uname -m)" in
		aarch64|arm64) ;;
		*) log_error "CodeGraph Linux ARM64 asset is unavailable for architecture: $(uname -m)"; return 1 ;;
	esac
	LATEST_VERSION=$(curl -sI https://github.com/colbymchenry/codegraph/releases/latest | grep -i location | sed -E 's#.*/tag/([^[:space:]]+).*#\1#')
	LATEST_VERSION="${LATEST_VERSION#v}"

	if [ -z "$LATEST_VERSION" ]; then
		log_error "Failed to fetch latest CodeGraph version"
		return 1
	fi

	if ! [[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		log_error "Invalid CodeGraph version from release server: $LATEST_VERSION"
		return 1
	fi

	mkdir -p "$KARNEL_DATA"
	staging_dir=$(mktemp -d "$KARNEL_DATA/.codegraph.XXXXXX") || return 1
	local tarball="$staging_dir/codegraph.tar.gz"
	local asset="codegraph-linux-arm64.tar.gz"

	if ! curl -fsSL "https://github.com/colbymchenry/codegraph/releases/download/v${LATEST_VERSION}/$asset" -o "$tarball" &>>"$LOG_FILE"; then
		log_error "Failed to download CodeGraph"
		rm -rf "$staging_dir"
		return 1
	fi

	if ! verify_github_release_asset colbymchenry/codegraph "v${LATEST_VERSION}" "$asset" "$tarball" ||
		! extract_tarball "$tarball" "$staging_dir" ||
		[[ ! -f "$staging_dir/codegraph-linux-arm64/lib/dist/bin/codegraph.js" ]]; then
		log_error "Failed to extract CodeGraph"
		rm -rf "$staging_dir"
		return 1
	fi

	if [[ -d "$CODEGRAPH_DATA_DIR" && ! -f "$CODEGRAPH_MARKER" ]]; then
		log_error "Refusing to replace CodeGraph data not owned by Karnel"
		rm -rf "$staging_dir"
		return 1
	fi
	printf '%s\n' 'karnel-managed-v1' >"$staging_dir/codegraph-linux-arm64/.karnel-managed"
	old_dir="$KARNEL_DATA/.codegraph-linux-arm64.previous.$$"
	if [ -d "$KARNEL_DATA/codegraph-linux-arm64" ] && ! mv "$KARNEL_DATA/codegraph-linux-arm64" "$old_dir"; then
		rm -rf "$staging_dir"
		return 1
	fi
	if ! mv "$staging_dir/codegraph-linux-arm64" "$KARNEL_DATA/codegraph-linux-arm64"; then
		[[ -d "$old_dir" ]] && mv "$old_dir" "$KARNEL_DATA/codegraph-linux-arm64"
		rm -rf "$staging_dir"
		return 1
	fi
	rm -rf "$staging_dir" "$old_dir"

	return 0
}

_write_codegraph_wrapper() {
	loading "Creating CodeGraph wrapper" _write_codegraph_wrapper_impl
}

_write_codegraph_wrapper_impl() {
	local wrapper_src="$KARNEL_PATH/tools/ai/codegraph/bin/codegraph"
	if [ ! -f "$wrapper_src" ]; then
		log_error "Wrapper template not found at $wrapper_src"
		return 1
	fi
	local staging_wrapper old_wrapper
	mkdir -p "$PREFIX/bin"
	staging_wrapper=$(mktemp "$PREFIX/bin/.codegraph.XXXXXX") || return 1
	if ! cp "$wrapper_src" "$staging_wrapper" || ! chmod +x "$staging_wrapper" || [[ ! -x "$staging_wrapper" ]]; then
		rm -f "$staging_wrapper"
		return 1
	fi
	old_wrapper="$PREFIX/bin/codegraph.previous.$$"
	if [ -e "$PREFIX/bin/codegraph" ] && ! mv "$PREFIX/bin/codegraph" "$old_wrapper"; then
		rm -f "$staging_wrapper"
		return 1
	fi
	if ! mv "$staging_wrapper" "$PREFIX/bin/codegraph"; then
		[[ -e "$old_wrapper" ]] && mv "$old_wrapper" "$PREFIX/bin/codegraph"
		return 1
	fi
	rm -f "$old_wrapper"
	record_managed_file "$PREFIX/bin/codegraph" "$CODEGRAPH_WRAPPER_MARKER"

	return 0
}

install_codegraph() {
	if command -v codegraph &>/dev/null; then
		log_info "CodeGraph is already installed"
		return 2
	fi
	if [ -e "$PREFIX/bin/codegraph" ]; then
		log_error "Refusing to replace an existing CodeGraph wrapper not owned by Karnel"
		return 1
	fi
	log_info "Installing CodeGraph..."

	mkdir -p "$(dirname "$LOG_FILE")"

	_codegraph_dependencies || return 1
	_download_codegraph || return 1
	_write_codegraph_wrapper || return 1

	log_success "CodeGraph installed"
	return 0
}

uninstall_codegraph() {
	if [ ! -f "$CODEGRAPH_MARKER" ] && ! managed_file_matches "$PREFIX/bin/codegraph" "$CODEGRAPH_WRAPPER_MARKER"; then
		log_info "CodeGraph is not installed"
		return 2
	fi
	log_info "Uninstalling CodeGraph..."
	mkdir -p "$(dirname "$LOG_FILE")"

	loading "Removing CodeGraph" _uninstall_codegraph_impl || return 1

	log_success "CodeGraph uninstalled"
	return 0
}

_uninstall_codegraph_impl() {
	if [ ! -f "$CODEGRAPH_MARKER" ] || ! managed_file_matches "$PREFIX/bin/codegraph" "$CODEGRAPH_WRAPPER_MARKER"; then
		log_error "Refusing to remove a CodeGraph installation not owned by Karnel"
		return 1
	fi
	if rm -f "$PREFIX/bin/codegraph" &>>"$LOG_FILE" && rm -rf "$CODEGRAPH_DATA_DIR"; then
		return 0
	else
		log_error "Failed to remove old CodeGraph installation"
		return 1
	fi
}

update_codegraph() {
  _check_update_needed "CodeGraph" "$(_get_installed_version codegraph)" "$(_get_remote_github_version colbymchenry/codegraph)" _do_update_codegraph
}

_do_update_codegraph() {
  _codegraph_dependencies || return 1
  _download_codegraph || return 1
  _write_codegraph_wrapper || return 1
  return 0
}

reinstall_codegraph() {
	if command -v codegraph &>/dev/null; then
		_do_update_codegraph
	else
		install_codegraph
	fi
}
