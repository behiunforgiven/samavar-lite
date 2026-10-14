#!/bin/bash
# Samovar Lite installer for macOS.
#
#   ./install_mac.sh               install/update: Python environment, `samovar-lite` command, build app bundle
#   ./install_mac.sh --install-app install Samovar Lite.app to /Applications
#   ./install_mac.sh --no-app      only build the Python environment in .venv
#   ./install_mac.sh --remove      remove the command and application
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

BIN="$HOME/.local/bin"
APP_DEST="/Applications/Samovar Lite.app"

if [ "$1" = "--remove" ]; then
    rm -f "$BIN/samovar-lite"
    rm -rf "$APP_DEST" "$HOME/Applications/Samovar Lite.app" "dist/Samovar Lite.app"
    echo "Removed the samovar-lite command and application. Settings remain in ~/.config/samovar-lite."
    exit 0
fi

# 1. Check for Homebrew and libmpv
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is recommended for installing libmpv on macOS."
    echo "Visit https://brew.sh or install mpv library manually."
fi

libmpv_ok() {
    [ -f "/opt/homebrew/lib/libmpv.dylib" ] || \
    [ -f "/usr/local/lib/libmpv.dylib" ] || \
    [ -f "/opt/local/lib/libmpv.dylib" ] || \
    [ -n "$SAMOVAR_LITE_LIBMPV" ]
}

if ! libmpv_ok; then
    if command -v brew >/dev/null 2>&1; then
        echo "Installing mpv via Homebrew..."
        brew install mpv
    else
        echo "Error: libmpv not found. Please install with: brew install mpv" >&2
        exit 1
    fi
fi

# 2. Python virtual environment
echo "Setting up Python environment..."
if [ ! -x .venv/bin/python ]; then
    if command -v uv >/dev/null 2>&1; then
        uv venv .venv
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m venv .venv
    else
        echo "Error: Python 3 not found." >&2
        exit 1
    fi
fi

if command -v uv >/dev/null 2>&1; then
    uv pip install --python .venv/bin/python -e .
else
    .venv/bin/python -m pip install --quiet --upgrade pip
    .venv/bin/python -m pip install --quiet -e .
fi

# 3. CLI command
mkdir -p "$BIN"
ln -sf "$DIR/.venv/bin/samovar-lite" "$BIN/samovar-lite"

if [ "$1" = "--no-app" ]; then
    echo "Environment ready: $DIR/.venv/bin/samovar-lite"
    echo "CLI command created: $BIN/samovar-lite"
    exit 0
fi

# 4. Build macOS App Bundle
./build_app.sh --no-dmg

if [ "$1" = "--install-app" ]; then
    echo "Installing to /Applications..."
    rm -rf "$APP_DEST"
    cp -R "dist/Samovar Lite.app" "$APP_DEST"
    echo "Installed to $APP_DEST"
fi

echo ""
echo "Installation complete!"
echo "  • CLI command: $BIN/samovar-lite"
echo "  • App bundle:  $DIR/dist/Samovar Lite.app"
if [ "$1" != "--install-app" ]; then
    echo "Tip: Run './install_mac.sh --install-app' to copy it to your Applications folder."
fi

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "Note: $BIN is not on your PATH yet. Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.zshrc." ;;
esac
