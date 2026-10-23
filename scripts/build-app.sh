#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Flip 7.app"
DEST="/Applications/Flip 7.app"

swift build -c release
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

swift scripts/make-icon.swift build/icon-1024.png
for px in 16 32 128 256 512; do
  sips -z $px $px build/icon-1024.png --out build/AppIcon.iconset/icon_${px}x${px}.png >/dev/null
  sips -z $((px * 2)) $((px * 2)) build/icon-1024.png --out build/AppIcon.iconset/icon_${px}x${px}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cp "$(swift build -c release --show-bin-path)/Flip7" "$APP/Contents/MacOS/Flip7"
cp App/Info.plist "$APP/Contents/Info.plist"
# Damit „Nach Updates suchen“ in den Einstellungen weiß, wo es pullen und bauen soll.
/usr/libexec/PlistBuddy -c "Add :Flip7SourceDirectory string $PWD" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :Flip7Commit string $(git rev-parse --short HEAD 2>/dev/null || echo unbekannt)" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Flip7 || true
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  echo "Installiert: $DEST"
else
  echo "Gebaut: $APP"
fi
