#!/usr/bin/env bash
# Quick App Store readiness checks for NFG Words iOS target.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
PLIST="$IOS/NFGWords/Info.plist"
PRIVACY="$IOS/NFGWords/PrivacyInfo.xcprivacy"
PBX="$IOS/NFGWords.xcodeproj/project.pbxproj"

fail=0
ok() { echo "OK  $1"; }
bad() { echo "FAIL $1"; fail=1; }

echo "NFG Words App Store checks"
echo "=========================="

[[ -f "$PLIST" ]] && ok "Info.plist exists" || bad "Info.plist missing"
[[ -f "$PRIVACY" ]] && ok "PrivacyInfo.xcprivacy exists" || bad "Privacy manifest missing"
grep -q "ITSAppUsesNonExemptEncryption" "$PLIST" && ok "Export compliance key present" || bad "Missing ITSAppUsesNonExemptEncryption"
grep -q "PrivacyInfo.xcprivacy" "$PBX" && ok "Privacy manifest in Xcode project" || bad "Privacy manifest not in pbxproj"
grep -q "deleteAccount" "$IOS/NFGWords/Services/ScoreStore.swift" && ok "In-app account deletion" || bad "Missing deleteAccount"
grep -q "Privacy Policy" "$IOS/NFGWords/Views/UsernamePromptView.swift" && ok "Privacy notice on login" || bad "Missing login privacy notice"
grep -q "NSPrivacyTracking" "$PRIVACY" && ok "Privacy tracking declared" || bad "Missing NSPrivacyTracking"
[[ -f "$IOS/NFGWords/Assets.xcassets/AppIcon.appiconset/Contents.json" ]] && ok "App icon asset catalog" || bad "App icon missing"

if grep -q "run-electron" "$IOS/NFGWords/Services/LeaderboardAPI.swift"; then
  bad "Developer-only error strings still in LeaderboardAPI"
else
  ok "User-facing API errors sanitized"
fi

[[ -f "$ROOT/legal/privacy.html" ]] && ok "Privacy web page" || bad "Missing legal/privacy.html"
[[ -f "$ROOT/legal/support.html" ]] && ok "Support web page" || bad "Missing legal/support.html"
[[ -f "$IOS/ExportOptions.plist" ]] && ok "TestFlight export plist" || bad "Missing ios/ExportOptions.plist"
grep -q "com.yusufali.nfgwords" "$PBX" && ok "Bundle ID com.yusufali.nfgwords" || bad "Bundle ID mismatch"
grep -q "DEVELOPMENT_TEAM = VM34N9485F" "$PBX" && ok "Development team set" || bad "Missing DEVELOPMENT_TEAM"
BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBX" | sed 's/.*= //;s/;//')
if [[ -n "${BUILD:-}" && "$BUILD" =~ ^[0-9]+$ ]]; then
  ok "Build number set ($BUILD)"
else
  bad "Build number missing"
fi

ICON="$IOS/NFGWords/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [[ -f "$ICON" ]]; then
  w=$(sips -g pixelWidth "$ICON" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  h=$(sips -g pixelHeight "$ICON" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ "$w" == "1024" && "$h" == "1024" ]]; then
    ok "App icon 1024x1024"
  else
    bad "App icon must be 1024x1024 (got ${w}x${h})"
  fi
else
  bad "AppIcon-1024.png missing"
fi

if [[ $fail -eq 0 ]]; then
  echo "=========================="
  echo "All automated checks passed."
  echo "Next: ./scripts/testflight_release.sh"
else
  echo "=========================="
  echo "Fix failures above before App Store submission."
  exit 1
fi
