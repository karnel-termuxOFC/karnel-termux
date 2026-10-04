#!/usr/bin/env bash
unset LD_LIBRARY_PATH
unset LD_PRELOAD
NODE_GLIBC="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/node-glibc/bin/node"
if [[ ! -x "$NODE_GLIBC" ]]; then
	echo "Turbopack toolchain not installed. Run: karnel install npm --turbopack" >&2
	exit 1
fi
exec "$NODE_GLIBC" "$@"
