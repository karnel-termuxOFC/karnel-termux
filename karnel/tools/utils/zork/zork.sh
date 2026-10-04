#!/data/data/com.termux/files/usr/bin/env bash
ZORK_DIR="$HOME/.local/share/karnel-data/zork"
if [ ! -f "$ZORK_DIR/zork1.dat" ]; then
  mkdir -p "$ZORK_DIR"
  tmpdir="$(mktemp -d "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/zork.XXXXXX")" || exit 1
  if ! curl -fsSL "http://www.infocom-if.org/downloads/zork1.zip" -o "$tmpdir/zork1.zip"; then
    echo "Failed to download Zork I" >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  # Refuse archives with path-traversal or absolute-path members.
  if unzip -l "$tmpdir/zork1.zip" 2>/dev/null | awk 'NR>3{print $NF}' | grep -qE '\.\./|^\.\.?/|^/|[A-Za-z]:\\'; then
    echo "Refusing potentially unsafe Zork archive" >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  extracted="$tmpdir/extracted"
  if ! unzip -o "$tmpdir/zork1.zip" -d "$extracted" 2>/dev/null; then
    echo "Failed to extract Zork I" >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  # Reject symlink/hardlink members and any non-regular file (prevents escape).
  if find "$extracted" -type l -print -quit | grep -q .; then
    echo "Refusing Zork archive with symlink members" >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  for f in "$extracted"/*; do
    [ -f "$f" ] || { echo "Unexpected member in Zork archive" >&2; rm -rf "$tmpdir"; exit 1; }
  done
  mv "$extracted"/* "$ZORK_DIR"/ 2>/dev/null || {
    echo "Failed to install Zork data" >&2
    rm -rf "$tmpdir"
    exit 1
  }
  rm -rf "$tmpdir"
fi
exec frotz "$ZORK_DIR/zork1.dat" "$@"
