# NFG Words — TestFlight release guide

## App details

| Field | Value |
|-------|--------|
| App name | NFG Words |
| Bundle ID | `com.yusufali.nfgwords` |
| Team ID | `VM34N9485F` |
| Version | 1.0 |
| Build | 2 (increment for each upload) |
| Min iOS | 17.0 |

## What is already done in the project

- Privacy manifest (`PrivacyInfo.xcprivacy`)
- In-app Privacy Policy, Terms, Support links
- Account deletion (Mine tab)
- Export compliance (`ITSAppUsesNonExemptEncryption` = false)
- App icon 1024×1024
- Release archive builds successfully
- Legal pages at `/privacy`, `/terms`, `/support` (deploy with server)

## One-time App Store Connect setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
2. Platform: **iOS**. Name: **NFG Words**. Bundle ID: **com.yusufali.nfgwords** (must match Xcode).
3. SKU: e.g. `nfgwords-ios`. User access: Full Access.
4. **App Privacy** — declare (not used for tracking):
   - User ID — App Functionality, linked
   - Other User Content (username) — App Functionality, linked
   - Gameplay Content (scores/level) — App Functionality, linked
5. **Privacy Policy URL**: `https://y666suf.com/privacy`
6. **Support URL**: `https://y666suf.com/support`
7. **Age rating** — complete questionnaire (likely 4+).
8. **Screenshots** — capture on iPhone 6.7" (required) and 6.5".
9. **Export compliance** — when prompted after upload: uses only standard HTTPS → **No** custom encryption.

## Deploy server before TestFlight testers play online

Ensure production `https://y666suf.com` proxies Word Games API and serves legal pages:

```bash
# Legal pages: /privacy /terms /support
# API: /api/word-games/*
# Include DELETE /api/word-games/players/{player_id}
```

Restart the Word Games service on your PC after deploying.

## Build and upload

### Option A — script (recommended)

```bash
cd ~/Documents/nfg-word-games
chmod +x scripts/testflight_release.sh
./scripts/testflight_release.sh
```

**Upload (same as NFG Crash — uses your Xcode Apple ID):**

```bash
./scripts/testflight_upload_direct.sh
```

Or upload the IPA from `ios/build/TestFlight/NFGWords.ipa`:

**Transporter (easiest):**
1. Open **Transporter** (Mac App Store, free from Apple)
2. Sign in with your Apple Developer Apple ID
3. Drag `ios/build/TestFlight/NFGWords.ipa` into the window
4. Click **Deliver**

**Or Xcode Organizer:**
1. **Window → Organizer → Archives**
2. If the archive isn’t listed, click **Import** and choose `ios/build/NFGWords.xcarchive`
3. **Distribute App → App Store Connect → Upload**

### Option B — Xcode GUI

1. Open `ios/NFGWords.xcodeproj` in Xcode.
2. Select **Any iOS Device (arm64)** as destination.
3. **Product → Archive**.
4. In Organizer: **Distribute App → App Store Connect → Upload**.

### Bump build number for each upload

In Xcode → target **NFGWords** → **General** → **Build** (or `CURRENT_PROJECT_VERSION` in project.pbxproj). Apple rejects duplicate build numbers.

## Add TestFlight testers

1. App Store Connect → your app → **TestFlight**.
2. Wait for build processing (~5–15 min).
3. Answer export compliance if prompted.
4. **Internal testing** — add team members (instant).
5. **External testing** — create a group, add emails, submit for Beta App Review (first time only).

## Pre-flight checklist

```bash
./scripts/ios_app_store_check.sh
cd ios && xcodebuild -scheme NFGWords -destination 'generic/platform=iOS' -configuration Release build
```

Manual tests on a Release build:

- [ ] Create username / login
- [ ] Play WordWheel round, save progress
- [ ] Leaderboard loads
- [ ] Delete account works
- [ ] Privacy / Terms links open in Safari

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Signing failed | Xcode → Settings → Accounts → download certificates; enable Automatic Signing |
| Bundle ID not in Connect | Register `com.yusufali.nfgwords` in Developer portal first |
| Upload stuck processing | Wait; check email for compliance questions |
| Leaderboard 404 in TestFlight | Deploy latest `server.py` to production PC |
