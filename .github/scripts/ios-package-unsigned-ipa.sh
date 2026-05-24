#!/usr/bin/env bash
# flutter build ipa --no-codesign creates .xcarchive only; zip Runner.app into an .ipa for AltStore.
set -euo pipefail

OUT="${1:-dist/ios/TOTAStudyBible.ipa}"
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

find_runner_app() {
  local candidate
  for candidate in \
    "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app" \
    "build/ios/iphoneos/Runner.app" \
    "build/ios/Release-iphoneos/Runner.app"
  do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  local found
  found="$(find build/ios -type d -name 'Runner.app' 2>/dev/null | head -1 || true)"
  if [ -n "$found" ]; then
    echo "$found"
    return 0
  fi
  return 1
}

APP="$(find_runner_app)" || {
  echo "::error::Runner.app not found under build/ios"
  find build/ios -maxdepth 6 -type d 2>/dev/null | head -40 || true
  exit 1
}

echo "Packaging unsigned IPA from: $APP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/Runner.app"
rm -f "$OUT"
(
  cd "$STAGE"
  zip -qr "$OUT" Payload
)

ls -lh "$OUT"
echo "Created unsigned IPA: $OUT"
