#!/usr/bin/env bash
# Upload NFGWords.ipa to App Store Connect / TestFlight.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${IPA:-$ROOT/ios/build/TestFlight/NFGWords.ipa}"
API_KEY_PATH="${API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_3W7V3A8AKG.p8}"
API_KEY_ID="${API_KEY_ID:-3W7V3A8AKG}"

if [[ ! -f "$IPA" ]]; then
  echo "IPA not found: $IPA"
  echo "Run ./scripts/testflight_release.sh first."
  exit 1
fi

if [[ -z "${ASC_ISSUER_ID:-}" && -f "$HOME/.appstoreconnect/issuer_id" ]]; then
  ASC_ISSUER_ID="$(tr -d '[:space:]' < "$HOME/.appstoreconnect/issuer_id")"
fi

if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "Set your App Store Connect Issuer ID (Users and Access → Integrations → App Store Connect API):"
  echo "  echo 'your-issuer-uuid' > ~/.appstoreconnect/issuer_id"
  echo "  # or: export ASC_ISSUER_ID='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'"
  echo "  ./scripts/testflight_upload.sh"
  echo ""
  echo "Or use Xcode account upload: ./scripts/testflight_upload_direct.sh"
  exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "API key not found: $API_KEY_PATH"
  exit 1
fi

echo "Validating IPA..."
xcrun altool --validate-app -f "$IPA" \
  --type ios \
  --api-key "$API_KEY_ID" \
  --api-issuer "$ASC_ISSUER_ID"

echo "Uploading to App Store Connect..."
xcrun altool --upload-app -f "$IPA" \
  --type ios \
  --api-key "$API_KEY_ID" \
  --api-issuer "$ASC_ISSUER_ID"

echo "Upload submitted. Check App Store Connect → TestFlight in ~5–15 minutes."
