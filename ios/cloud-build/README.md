# iOS cloud build (GitHub Actions + AltStore)

This folder documents how **TOTA Study Bible** is built on GitHub’s macOS runners, signed, published as a **GitHub Release IPA**, and listed in an **AltStore source** JSON file stored in this repository.

## Repository layout

| Path | Purpose |
|------|---------|
| `.github/workflows/build-ios.yml` | Main CI workflow (push to `main` + manual dispatch) |
| `.github/scripts/ios-generate-export-options.sh` | Writes `ios/signing/ExportOptions.plist` from secrets |
| `.github/scripts/ios-generate-ci-signing-xcconfig.sh` | Writes `ios/Flutter/CI-Signing.xcconfig` for Xcode |
| `.github/scripts/ios-update-altstore-manifest.sh` | Updates AltStore JSON after a successful build |
| `ios/signing/ExportOptions.plist.example` | Documented template for export options |
| `ios/signing/CI-Signing.xcconfig.example` | Local signing example (optional) |
| `ios/altstore/altstore-source.json` | **AltStore source** — add this URL in AltStore |
| `ios/altstore/apps.json` | Apps array mirror (updated by CI) |
| `ios/altstore/manifest.json` | Build metadata (version, size, SHA-256, download URL) |
| `dist/ios/` | Not committed; IPA is uploaded as a **Release asset** + workflow artifact |

IPA files are **not** stored in git (too large). They appear under **Actions → workflow run → Artifacts** and **GitHub Releases**.

## GitHub Secrets (required)

Configure in **GitHub → Repository → Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Description |
|--------|-------------|
| `IOS_P12_BASE64` | Base64 of your **.p12** codesigning certificate (Apple Distribution for Ad Hoc, or Apple Development for dev profiles) |
| `IOS_P12_PASSWORD` | Password used when exporting the .p12 |
| `IOS_PROVISION_PROFILE_BASE64` | Base64 of the **.mobileprovision** for `com.example.njbibleapp` |
| `IOS_TEAM_ID` | Apple Developer **Team ID** (10 characters, e.g. `AB12CD34EF`) |
| `IOS_PROVISIONING_PROFILE_NAME` | Exact **name** of the provisioning profile (Xcode → Accounts → Manage Certificates / Profiles, or inside the profile) |

### Shared app secrets (same as Android CI)

| Secret | Description |
|--------|-------------|
| `FIREBASE_OPTIONS_DART` | Full contents of `lib/firebase_options.dart` |
| `GOOGLE_SERVICE_INFO_PLIST` | *(Optional)* Overrides `ios/Runner/GoogleService-Info.plist` if not committed |
| `API_BIBLE_KEY` | *(Optional)* `--dart-define=API_BIBLE_KEY=...` for online Bible fallback |

### Optional

| Secret | Description |
|--------|-------------|
| `IOS_CODE_SIGN_IDENTITY` | Default: `Apple Distribution`. Use `Apple Development` for development profiles. |
| `IOS_KEYCHAIN_PASSWORD` | Not required; `apple-actions/import-codesign-certs` manages the keychain. |

## How to create signing assets

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create an **App ID** for `com.example.njbibleapp` (or change bundle ID in Xcode + secrets + AltStore JSON together).
3. Create a provisioning profile:
   - **Ad Hoc** — for `IOS_EXPORT_METHOD=ad-hoc` (devices must be registered in the profile).
   - **Development** — for `IOS_EXPORT_METHOD=development` (common with AltStore refresh).
4. Export the certificate as **.p12** from Keychain Access.
5. Base64-encode for secrets:

```bash
# macOS / Linux
base64 -i Certificates.p12 | pbcopy   # macOS copies to clipboard
base64 -i profile.mobileprovision | pbcopy
```

On Windows (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Certificates.p12")) | Set-Clipboard
```

## Workflow behavior

1. Triggers on **push to `main`** and **workflow_dispatch**.
2. Builds `flutter build ipa` with manual signing from secrets.
3. Uploads **`TOTAStudyBible.ipa`** as a workflow artifact.
4. Creates a GitHub Release tag `ios-v{version}-{run}` with the IPA attached.
5. Updates `ios/altstore/*.json` with `downloadURL`, `version`, `buildVersion`, `size`, and commits with **`[skip ci]`** to avoid infinite rebuild loops.

## AltStore source URL

After the first successful run, add this source in **AltStore → Sources → Add Source**:

```
https://raw.githubusercontent.com/SycaJay/TOTAStudyBible/main/ios/altstore/altstore-source.json
```

Replace `SycaJay/TOTAStudyBible` if you fork the repository.

## Local signed IPA (optional)

1. Copy `ios/signing/CI-Signing.xcconfig.example` → `ios/Flutter/CI-Signing.xcconfig` and fill in values.
2. Copy `ios/signing/ExportOptions.plist.example` → `ios/signing/ExportOptions.plist`.
3. Run:

```bash
flutter build ipa --release --export-options-plist=ios/signing/ExportOptions.plist
```

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| `No profiles for 'com.example.njbibleapp'` | Profile bundle ID and certificate type must match |
| `errSecInternalComponent` | Re-export .p12; verify `IOS_P12_PASSWORD` |
| Firebase / Google Sign-In fails on device | `GoogleService-Info.plist`, URL schemes, iOS OAuth client in Firebase |
| Workflow never runs | Secrets missing — see “Verify iOS signing secrets” step log |

## Export method

Set in `.github/workflows/build-ios.yml` (`IOS_EXPORT_METHOD`):

- `ad-hoc` — Ad Hoc provisioning profile (default)
- `development` — Development profile
- `release-testing` — Internal TestFlight-style export (rare for AltStore)

The method **must match** the installed `.mobileprovision`.
