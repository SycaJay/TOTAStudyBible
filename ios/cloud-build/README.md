# iOS cloud build (GitHub Actions + AltStore, free Apple ID)

This project builds an **unsigned IPA** on GitHub Actions. **AltStore** installs it on your iPhone and **re-signs it with your free Apple ID** (via AltServer on your PC/Mac). You do **not** need the paid Apple Developer Program ($99/year) for this flow.

## How it works

| Step | Where | What happens |
|------|--------|----------------|
| 1 | GitHub Actions | `flutter build ipa --no-codesign` → `TOTAStudyBible.ipa` |
| 2 | GitHub Release | IPA hosted as a download |
| 3 | Your iPhone | AltStore downloads IPA from your source JSON |
| 4 | AltServer + free Apple ID | AltStore signs the app for your device (7-day certificate, refresh in AltStore) |

## GitHub Secrets (required)

Only the same app config as Android CI:

| Secret | Description |
|--------|-------------|
| `FIREBASE_OPTIONS_DART` | Full contents of `lib/firebase_options.dart` |

### Optional

| Secret | Description |
|--------|-------------|
| `GOOGLE_SERVICE_INFO_PLIST` | Overrides `ios/Runner/GoogleService-Info.plist` |
| `API_BIBLE_KEY` | Online Bible API fallback |

**No** `IOS_P12_*`, Team ID, or provisioning profile secrets are needed for the default workflow.

## Repository layout

| Path | Purpose |
|------|---------|
| `.github/workflows/build-ios.yml` | Unsigned IPA build + release + AltStore JSON update |
| `.github/scripts/ios-update-altstore-manifest.sh` | Updates `ios/altstore/*.json` after each build |
| `ios/altstore/altstore-source.json` | URL to add in AltStore → Sources |
| `ios/altstore/apps.json` | Apps list mirror |
| `ios/altstore/manifest.json` | Version, size, SHA-256 metadata |
| `ios/signing/*.example` | Optional — only if you later use paid signing locally |

## AltStore source URL

```
https://raw.githubusercontent.com/SycaJay/TOTAStudyBible/main/ios/altstore/altstore-source.json
```

(Replace `SycaJay/TOTAStudyBible` if you use a fork.)

## Install on iPhone (AltServer)

1. Install **AltServer** on Windows or Mac ([altstore.io](https://altstore.io)).
2. Install **AltStore** on your iPhone (same Wi‑Fi as AltServer, or USB).
3. Sign in with your **free Apple ID** in AltStore.
4. **Sources → Add Source** → paste the URL above.
5. Open the source → **TOTA Study Bible** → install.
6. Refresh the app in AltStore before the 7-day signing expires.

## Limits (free Apple ID)

- Apps must be **refreshed** in AltStore about every **7 days**.
- Apple limits how many sideloaded apps you can have at once (AltStore + others share the limit).
- Push notifications and some capabilities may not work compared to App Store builds.

## Optional: paid Apple Developer signing

If you later enroll in the Apple Developer Program, you can sign IPAs in CI with certificates. See `ios/signing/ExportOptions.plist.example` and `ios/signing/CI-Signing.xcconfig.example`, or use a separate workflow with secrets:

`IOS_P12_BASE64`, `IOS_P12_PASSWORD`, `IOS_PROVISION_PROFILE_BASE64`, `IOS_TEAM_ID`, `IOS_PROVISIONING_PROFILE_NAME`

That path is **not required** for AltStore + free Apple ID.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Workflow fails on secrets | Add `FIREBASE_OPTIONS_DART` |
| AltStore “Unable to install” | Refresh AltServer connection; check Wi‑Fi/USB |
| App expires after 7 days | Open AltStore → Refresh All |
| Google Sign-In fails on device | Firebase iOS app + URL schemes configured |
