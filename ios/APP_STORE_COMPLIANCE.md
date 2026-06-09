# NFG Words — App Store compliance checklist

Use this before submitting to App Store Connect.

## In-app (implemented)

- [x] **Privacy Policy** — in-app on login screen and Mine tab
- [x] **Terms of Use** — in-app on login screen and Mine tab
- [x] **Account deletion** — Mine tab → Delete Account (Guideline 5.1.1(v))
- [x] **Username profanity filter** — client + server
- [x] **HTTPS API** — production server uses `https://y666suf.com`
- [x] **No tracking** — `NSPrivacyTracking` = false in Privacy Manifest
- [x] **Privacy Manifest** — `NFGWords/PrivacyInfo.xcprivacy`
- [x] **Export compliance** — `ITSAppUsesNonExemptEncryption` = false
- [x] **User-facing errors** — no developer-only messages shown to players
- [x] **Accessibility labels** — username field and login actions

## Info.plist

- [x] Display name, bundle ID, version
- [x] App category: Games
- [x] Copyright string
- [x] Portrait-only on iPhone
- [x] Launch screen with brand asset
- [x] arm64 requirement

## TestFlight

See **`ios/TESTFLIGHT.md`** for the full upload guide.

```bash
./scripts/ios_app_store_check.sh
./scripts/testflight_release.sh   # or Product → Archive in Xcode
```

## App Store Connect (you must complete)

- [ ] **Create app** in App Store Connect with bundle ID `com.yusufali.nfgwords`
- [ ] **App Privacy questionnaire** — match `PrivacyInfo.xcprivacy`:
  - User ID (player ID) — App Functionality, linked, not tracking
  - Other User Content (username) — App Functionality, linked, not tracking
  - Gameplay Content (scores/level) — App Functionality, linked, not tracking
- [ ] **Privacy Policy URL** — host at `https://y666suf.com/privacy` (or update `AppLegalConfig.swift`)
- [ ] **Support URL** — `https://y666suf.com/support` or support email
- [ ] **Age rating** — complete questionnaire (suggest 4+ with infrequent mild content if profanity filter only)
- [ ] **Screenshots** — iPhone 6.7" and 6.5" required sizes
- [ ] **App icon** — 1024×1024 in `AppIcon.appiconset`
- [ ] **Export compliance** — answer "No" for custom encryption (standard HTTPS only)
- [ ] **Content rights** — confirm you own NFG Words branding
- [ ] **Test on device** — login, play, leaderboard, delete account

## Server (for account deletion in production)

Deploy updated `server.py` with:

```
DELETE /api/word-games/players/{player_id}
```

Restart the Word Games service on your PC after deploy.

## Verify locally

```bash
cd ~/Documents/nfg-word-games/ios
xcodebuild -scheme NFGWords -destination 'generic/platform=iOS' -configuration Release build
./scripts/ios_app_store_check.sh
```
