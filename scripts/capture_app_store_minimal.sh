#!/usr/bin/env bash
# Fast minimum screenshots for App Store Connect (1 per required device size).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
OUT="$IOS/AppStoreScreenshots"
BUNDLE="com.yusufali.nfgwords"
SCENE="hub"

IPHONE_UDID="${IPHONE_UDID:-9E237885-1CEA-46C7-B178-168CE47EA171}"
IPAD_UDID="${IPAD_UDID:-7BB038B1-5FE2-41D6-94AF-81F896053DA9}"

mkdir -p "$OUT/iphone-6.5" "$OUT/ipad-13"

APP="$IOS/build/ScreenshotDerived/Build/Products/Debug-iphonesimulator/NFGWords.app"
if [[ ! -d "$APP" ]]; then
  echo "Building once (Debug simulator)..."
  cd "$IOS"
  xcodebuild -scheme NFGWords -configuration Debug \
    -destination "platform=iOS Simulator,id=$IPHONE_UDID" \
    -derivedDataPath "$IOS/build/ScreenshotDerived" build -quiet
fi

shot() {
  local udid="$1" out="$2" w="$3" h="$4"
  echo "→ $out"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$APP"
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$udid" "$BUNDLE" "-AppStoreScreenshot=$SCENE" >/dev/null
  sleep 2
  local raw="/tmp/nfg-shot-$$.png"
  xcrun simctl io "$udid" screenshot "$raw"
  sips -z "$h" "$w" "$raw" --out "$out" >/dev/null
  rm -f "$raw"
  sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/{printf "  %s ", $0} END{print ""}'
}

shot "$IPHONE_UDID" "$OUT/iphone-6.5/01-hub.png" 1284 2778
shot "$IPAD_UDID"   "$OUT/ipad-13/01-hub.png"     2064 2752

echo ""
echo "Done. Upload these two files in App Store Connect → Media Manager:"
echo "  iPhone 6.5\": $OUT/iphone-6.5/01-hub.png"
echo "  iPad 13\":    $OUT/ipad-13/01-hub.png"
