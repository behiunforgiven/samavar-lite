#!/bin/bash
# Builds a standalone macOS Application Bundle (Samovar Lite.app) and DMG.
#
#   ./build_app.sh           # Builds dist/Samovar Lite.app and dist/Samovar-Lite-<version>.dmg
#   ./build_app.sh --no-dmg  # Only builds dist/Samovar Lite.app
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# 1. Ensure Python environment exists
if [ -x ".venv/bin/python" ]; then
    PYTHON=".venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
else
    echo "Error: Python 3 not found." >&2
    exit 1
fi

# Ensure dependencies & PyInstaller are installed
if ! "$PYTHON" -c "import PySide6, mpv, PyInstaller" 2>/dev/null; then
    echo "Installing build dependencies..."
    if command -v uv >/dev/null 2>&1; then
        uv pip install --python "$PYTHON" -e . pyinstaller
    else
        "$PYTHON" -m pip install --quiet -e . pyinstaller
    fi
fi

# 2. Generate high-resolution macOS .icns icon
echo "Generating macOS application icon..."
mkdir -p build/SamovarLite.iconset
"$PYTHON" -c "
from PySide6.QtGui import QGuiApplication
from samovar_lite import skin
app = QGuiApplication([])
for s in [16, 32, 64, 128, 256, 512]:
    skin.app_icon_pixmap(s).save(f'build/SamovarLite.iconset/icon_{s}x{s}.png')
    skin.app_icon_pixmap(s * 2).save(f'build/SamovarLite.iconset/icon_{s}x{s}@2x.png')
"
iconutil -c icns build/SamovarLite.iconset -o build/SamovarLite.icns

# 3. Build .app bundle with PyInstaller
echo "Building Samovar Lite.app with PyInstaller..."
rm -rf "dist/Samovar Lite" "dist/Samovar Lite.app"
"$PYTHON" -m PyInstaller \
    --name="Samovar Lite" \
    --windowed \
    --noconfirm \
    --icon="build/SamovarLite.icns" \
    --collect-submodules="samovar_lite" \
    --osx-bundle-identifier="com.samovar-lite.app" \
    samovar_lite/__main__.py

# 4. Enhance Info.plist with version and supported media types for Finder
echo "Updating Info.plist with file associations..."
"$PYTHON" -c "
import plistlib
from samovar_lite import __version__

plist_path = 'dist/Samovar Lite.app/Contents/Info.plist'
with open(plist_path, 'rb') as fp:
    pl = plistlib.load(fp)

pl['CFBundleShortVersionString'] = __version__
pl['CFBundleVersion'] = __version__
pl['CFBundleDocumentTypes'] = [
    {
        'CFBundleTypeName': 'Video and Audio Files',
        'CFBundleTypeRole': 'Viewer',
        'LSHandlerRank': 'Alternate',
        'CFBundleTypeExtensions': [
            'mp4', 'mkv', 'webm', 'avi', 'mov', 'wmv', 'flv', 'm4v',
            'ts', 'm2ts', 'mpg', 'mpeg', '3gp', 'ogv',
            'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus',
            'srt', 'ass', 'ssa', 'vtt'
        ],
    }
]

with open(plist_path, 'wb') as fp:
    plistlib.dump(pl, fp)
"

# 5. Ad-hoc codesign the bundle
echo "Signing application bundle..."
codesign --force --deep -s - "dist/Samovar Lite.app"

VERSION=$("$PYTHON" -c "import samovar_lite; print(samovar_lite.__version__)")
echo "Built: dist/Samovar Lite.app (v$VERSION)"

# 6. Build DMG disk image (unless --no-dmg passed)
if [ "$1" != "--no-dmg" ] && command -v hdiutil >/dev/null 2>&1; then
    DMG_NAME="Samovar-Lite-$VERSION.dmg"
    echo "Creating DMG disk image: dist/$DMG_NAME..."
    rm -f "dist/$DMG_NAME"
    hdiutil create -volname "Samovar Lite" -srcfolder "dist/Samovar Lite.app" -ov -format UDZO "dist/$DMG_NAME"
    echo "Created: dist/$DMG_NAME"
fi

echo "Done! You can launch the app with: open 'dist/Samovar Lite.app'"
