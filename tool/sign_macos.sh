#!/usr/bin/env bash
set -euo pipefail

: "${CODESIGN_IDENTITY:?Set the Developer ID Application identity}"
: "${APPLE_API_KEY_PATH:?Set the App Store Connect private key path}"
: "${APPLE_API_KEY:?Set the App Store Connect key ID}"
: "${APPLE_API_ISSUER:?Set the App Store Connect issuer ID}"

app="build/macos/Build/Products/Release/iPing.app"
test -d "$app"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

while IFS= read -r -d '' binary; do
  if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$binary"
  fi
done < <(/usr/bin/find "$app/Contents" -type f -print0)

while IFS= read -r -d '' bundle; do
  /usr/bin/codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$bundle"
done < <(/usr/bin/find "$app/Contents" -depth -type d \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \) -print0)

/usr/bin/codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" \
  --entitlements macos/Runner/Release.entitlements "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
xcrun notarytool submit "$work/notarize.zip" \
  --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY" --issuer "$APPLE_API_ISSUER" \
  --wait --output-format json > "$work/result.json"
python3 - "$work/result.json" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit(f"Notarization failed: {result.get('status')} ({result.get('id')})")
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
/usr/sbin/spctl --assess --type execute --verbose "$app"
