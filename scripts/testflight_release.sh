#!/usr/bin/env bash
# Archive NFG Words for TestFlight / App Store Connect upload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
ARCHIVE_PATH="${ARCHIVE_PATH:-$IOS/build/NFGWords.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$IOS/build/TestFlight}"
EXPORT_PLIST="$IOS/ExportOptions.plist"

echo "==> App Store compliance checks"
"$ROOT/scripts/ios_app_store_check.sh"

echo "==> Release archive"
mkdir -p "$IOS/build"
cd "$IOS"
# Note: avoid `clean` — can fail in some CI/sandbox environments during asset thinning.
xcodebuild \
  -scheme NFGWords \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "==> Export IPA for App Store Connect"
rm -rf "$EXPORT_PATH"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' | head -1)"
if [[ -z "$IPA" ]]; then
  echo "ERROR: No .ipa found in $EXPORT_PATH"
  exit 1
fi

echo ""
echo "Archive ready for TestFlight"
echo "  Archive: $ARCHIVE_PATH"
echo "  IPA:     $IPA"
echo ""
echo "Upload options:"
echo "  1. Open Xcode → Window → Organizer → Archives → Distribute App"
echo "  2. Or Transporter app (drag the .ipa)"
echo "  3. Or: xcrun altool --upload-app -f \"$IPA\" -t ios -u YOUR_APPLE_ID --password @keychain:AC_PASSWORD"
echo ""
echo "Before each new upload, bump CURRENT_PROJECT_VERSION in Xcode (build number)."
