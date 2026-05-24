#!/usr/bin/env bash
# Updates AltStore JSON files in ios/altstore/ after a successful IPA build.
set -euo pipefail

VERSION="${1:?version required}"
BUILD="${2:?build number required}"
IPA_PATH="${3:?ipa path required}"
DOWNLOAD_URL="${4:?download URL required}"

SIZE="$(wc -c < "$IPA_PATH" | tr -d ' ')"
SHA256="$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')"
ISO_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

export VERSION BUILD SIZE DOWNLOAD_URL SHA256 ISO_DATE

# Full AltStore source (add source in AltStore → Sources → URL to altstore-source.json on main).
jq \
  --arg version "$VERSION" \
  --arg build "$BUILD" \
  --argjson size "$SIZE" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --arg sha256 "$SHA256" \
  --arg date "$ISO_DATE" \
  '
  .apps[0].version = $version
  | .apps[0].buildVersion = $build
  | .apps[0].size = $size
  | .apps[0].downloadURL = $downloadURL
  | .apps[0].versionDate = $date
  ' \
  ios/altstore/altstore-source.json > ios/altstore/altstore-source.json.tmp
mv ios/altstore/altstore-source.json.tmp ios/altstore/altstore-source.json

# Standalone apps array (optional; some tools consume this file directly).
jq \
  --arg version "$VERSION" \
  --arg build "$BUILD" \
  --argjson size "$SIZE" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --arg date "$ISO_DATE" \
  '
  .[0].version = $version
  | .[0].buildVersion = $build
  | .[0].size = $size
  | .[0].downloadURL = $downloadURL
  | .[0].versionDate = $date
  ' \
  ios/altstore/apps.json > ios/altstore/apps.json.tmp
mv ios/altstore/apps.json.tmp ios/altstore/apps.json

# Companion manifest with checksum for debugging / mirrors.
jq \
  --arg version "$VERSION" \
  --arg build "$BUILD" \
  --argjson size "$SIZE" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --arg sha256 "$SHA256" \
  --arg date "$ISO_DATE" \
  '
  .version = $version
  | .buildVersion = $build
  | .size = $size
  | .downloadURL = $downloadURL
  | .sha256 = $sha256
  | .lastUpdated = $date
  ' \
  ios/altstore/manifest.json > ios/altstore/manifest.json.tmp
mv ios/altstore/manifest.json.tmp ios/altstore/manifest.json

echo "AltStore manifests updated (version=${VERSION}, build=${BUILD}, size=${SIZE} bytes)"
