#!/usr/bin/env bash
# Generates ios/signing/ExportOptions.plist for flutter build ipa (CI only).
set -euo pipefail

METHOD="${IOS_EXPORT_METHOD:-ad-hoc}"
TEAM_ID="${IOS_TEAM_ID:?Set IOS_TEAM_ID secret}"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.example.njbibleapp}"
PROFILE_NAME="${IOS_PROVISIONING_PROFILE_NAME:?Set IOS_PROVISIONING_PROFILE_NAME secret}"

OUT="ios/signing/ExportOptions.plist"
mkdir -p ios/signing

cat > "$OUT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${METHOD}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>uploadSymbols</key>
	<false/>
	<key>compileBitcode</key>
	<false/>
	<key>signingStyle</key>
	<string>manual</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
	</dict>
</dict>
</plist>
PLIST

echo "Wrote ${OUT} (method=${METHOD}, team=${TEAM_ID}, profile=${PROFILE_NAME})"
