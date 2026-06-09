#!/usr/bin/env bash
# Archive + upload NFG Words to TestFlight (same flow as nfg-crash/ios/scripts/upload-testflight.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
ARCHIVE="$IOS/build/NFGWords.xcarchive"
UPLOAD_PLIST="$IOS/ExportOptions-Upload.plist"
UPLOAD_DIR="$IOS/build/Upload"

BUILD="$(xcodebuild -showBuildSettings -scheme NFGWords -configuration Release -project "$IOS/NFGWords.xcodeproj" 2>/dev/null | awk -F' = ' '/CURRENT_PROJECT_VERSION/{print $2; exit}')"

echo "=== NFG Words TestFlight upload — build ${BUILD:-?} ==="

if [[ ! -f "$ARCHIVE/Info.plist" ]]; then
  echo "Archive missing. Run ./scripts/testflight_release.sh first."
  exit 1
fi

rm -rf "$UPLOAD_DIR"
mkdir -p "$UPLOAD_DIR"

cd "$IOS"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$UPLOAD_DIR" \
  -exportOptionsPlist "$UPLOAD_PLIST" \
  -allowProvisioningUpdates

echo ""
echo "Upload submitted. Check App Store Connect → NFG Words → TestFlight."
echo "Processing usually takes 5–15 minutes."
