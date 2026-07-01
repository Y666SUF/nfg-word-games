#!/usr/bin/env bash
# Capture App Store screenshots at required iPhone 6.5" and iPad 13" sizes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
OUT="$IOS/AppStoreScreenshots"
BUNDLE="com.yusufali.nfgwords"

# App Store Connect required portrait sizes (2026)
IPHONE_W=1284
IPHONE_H=2778
IPAD_W=2064
IPAD_H=2752

# Simulators on this Mac (override with env vars if needed)
IPHONE_UDID="${IPHONE_UDID:-9E237885-1CEA-46C7-B178-168CE47EA171}"   # iPhone 17 Pro Max → scaled to 6.5"
IPAD_UDID="${IPAD_UDID:-7BB038B1-5FE2-41D6-94AF-81F896053DA9}"       # iPad Pro 13-inch (M5)

SCENES=(welcome hub wordwheel journey leaderboard mine style wordwich timed profile)
SCENE_LABELS=(01-welcome 02-hub 03-wordwheel 04-journey 05-leaderboard 06-mine 07-style 08-wordwich 09-timed 10-profile)
SCENE_SLEEP=(2 2 3 5 2 2 2 2 3 3)

mkdir -p "$OUT/iphone-6.5" "$OUT/ipad-13"

echo "==> Building for iOS Simulator"
cd "$IOS"
xcodebuild \
  -scheme NFGWords \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$IPHONE_UDID" \
  -derivedDataPath "$IOS/build/ScreenshotDerived" \
  build \
  -quiet

APP="$IOS/build/ScreenshotDerived/Build/Products/Debug-iphonesimulator/NFGWords.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: App not found at $APP"
  exit 1
fi

capture_device() {
  local udid="$1"
  local device_dir="$2"
  local target_w="$3"
  local target_h="$4"

  echo ""
  echo "==> Device $udid → $device_dir (${target_w}×${target_h})"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"

  local i=0
  for scene in "${SCENES[@]}"; do
    local label="${SCENE_LABELS[$i]}"
    local raw="/tmp/nfg-screenshot-${udid}-${label}.png"
    local out="$device_dir/${label}.png"

    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    sleep 0.5
    xcrun simctl launch "$udid" "$BUNDLE" "-AppStoreScreenshot=$scene" >/dev/null
    sleep "${SCENE_SLEEP[$i]:-3}"
    xcrun simctl io "$udid" screenshot "$raw"

    # Exact App Store dimensions, RGB PNG (no alpha)
    sips -z "$target_h" "$target_w" "$raw" --out "$out" >/dev/null
    sips -s format png -s formatOptions default "$out" >/dev/null

    local w h
    w=$(sips -g pixelWidth "$out" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$out" | awk '/pixelHeight/{print $2}')
    echo "  ✓ $label → ${w}×${h} ($out)"
    i=$((i + 1))
  done
}

capture_device "$IPHONE_UDID" "$OUT/iphone-6.5" "$IPHONE_W" "$IPHONE_H"
capture_device "$IPAD_UDID" "$OUT/ipad-13" "$IPAD_W" "$IPAD_H"

echo ""
echo "Done. Upload these folders in App Store Connect → Media Manager:"
echo "  iPhone 6.5\" display: $OUT/iphone-6.5/"
echo "  iPad 13\" display:     $OUT/ipad-13/"
echo ""
echo "Minimum: upload at least 01-welcome.png (or 02-hub.png) to each slot to pass validation."
