#!/bin/zsh
set -euo pipefail

# Schneidet ein Release für die Nutzer, die die App als ZIP heruntergeladen haben:
# baut die App, schreibt die Release-Version ins Bundle (daran erkennt der Update-Button
# in den Einstellungen, ob eine neuere Version da ist), zippt sie und legt das GitHub-Release an.
#
#   ./scripts/release.sh v2

cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^v[0-9]+$ ]]; then
  echo "Aufruf: ./scripts/release.sh vN   (z. B. v2)" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Es gibt uncommittete Änderungen. Erst committen und pushen, dann releasen." >&2
  exit 1
fi

git fetch --quiet origin
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "HEAD ist nicht gleich origin/main. Erst pushen, damit das Release dem entspricht, was online liegt." >&2
  exit 1
fi

if git rev-parse "$VERSION" >/dev/null 2>&1 || gh release view "$VERSION" >/dev/null 2>&1; then
  echo "$VERSION gibt es schon. Nächste Nummer wählen." >&2
  exit 1
fi

APP="build/Flip 7.app"
ZIP="build/Flip-7-$VERSION.zip"

scripts/build-app.sh

# Release-Artefakt soll über GitHub updaten, nicht über einen Projektordner, der nur auf diesem Mac liegt.
/usr/libexec/PlistBuddy -c "Delete :Flip7SourceDirectory" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :Flip7Release string $VERSION" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# Release-Notes sind die Commit-Betreffe seit dem letzten Release – dieselben Nutzer-Sätze wie im Update-Button.
PREV="$(git describe --tags --abbrev=0 2>/dev/null || true)"
NOTES="$(git log --format='- %s' ${PREV:+$PREV..HEAD})"
INSTALL="Voraussetzung: Mac mit Apple-Chip und macOS 27. ZIP entpacken, \`Flip 7.app\` nach Programme ziehen. Beim ersten Start einmal unter Systemeinstellungen → Datenschutz & Sicherheit auf „Trotzdem öffnen\" klicken."

gh release create "$VERSION" "$ZIP" \
  --target main \
  --title "Flip 7 $VERSION" \
  --notes "$NOTES

$INSTALL"

echo "Release $VERSION ist online. ZIP-Nutzer bekommen es beim nächsten „Nach Updates suchen\"."
