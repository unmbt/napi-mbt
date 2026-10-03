#!/usr/bin/env bash
set -eu

# Install the native MoonBit CLI. npm is intentionally not used here; the
# Node implementation is downloaded as a runtime payload for commands that
# still use the tree-sitter transport.
REPO="${NAPI_MBT_REPO:-unmbt/napi-mbt}"
ROOT="${NAPI_MBT_HOME:-$HOME/.unmbt}"
VERSION="${NAPI_MBT_VERSION:-}"

if [ "${1:-}" = "uninstall" ] || [ "${1:-}" = "--uninstall" ]; then
  rm -rf "$ROOT"
  echo "Removed $ROOT"
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS:$ARCH" in
  Linux:x86_64|Linux:amd64) ASSET="napi-mbt-linux-amd64" ;;
  Linux:aarch64|Linux:arm64) ASSET="napi-mbt-linux-arm64" ;;
  Darwin:x86_64|Darwin:amd64) ASSET="napi-mbt-macos-x64" ;;
  Darwin:arm64) ASSET="napi-mbt-macos-arm64" ;;
  *) echo "Unsupported platform: $OS/$ARCH" >&2; exit 1 ;;
esac

if [ -z "$VERSION" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
fi
[ -n "$VERSION" ] || { echo "Unable to determine the latest release; set NAPI_MBT_VERSION" >&2; exit 1; }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t napi-mbt)"
trap 'rm -rf "$TMP"' EXIT
URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET.tar.gz"
curl -fL "$URL" -o "$TMP/cli.tar.gz"
rm -rf "$ROOT"
mkdir -p "$ROOT/runtime"
tar -xzf "$TMP/cli.tar.gz" -C "$ROOT"

if [ ! -x "$ROOT/napi-mbt" ]; then
  echo "Release $VERSION did not contain napi-mbt" >&2
  exit 1
fi
mv "$ROOT/napi-mbt" "$ROOT/napi-mbt-bin"
cat > "$ROOT/napi-mbt" <<EOF
#!/usr/bin/env bash
set -e
export NAPI_MBT_NODE_RUNTIME="$ROOT/runtime/cli/bin/napi-mbt.js"
exec "$ROOT/napi-mbt-bin" "\$@"
EOF
chmod +x "$ROOT/napi-mbt"

case ":${PATH}:" in
  *:"$ROOT":*) ;;
  *)
    PROFILE="$HOME/.profile"
    [ -f "$PROFILE" ] || touch "$PROFILE"
    if ! grep -Fqs "$ROOT" "$PROFILE"; then
      printf '\n# napi-mbt\nexport PATH="$PATH:%s"\n' "$ROOT" >> "$PROFILE"
    fi
    ;;
esac
echo "Installed napi-mbt $VERSION in $ROOT"
echo "Restart your shell or run: export PATH=\"$ROOT:\$PATH\""
