#!/usr/bin/env bash
set -euo pipefail

: "${CODESIGN_IDENTITY:?Set the Developer ID Application identity}"
: "${APPLE_API_KEY_PATH:?Set the App Store Connect private key path}"
: "${APPLE_API_KEY:?Set the App Store Connect key ID}"
: "${APPLE_API_ISSUER:?Set the App Store Connect issuer ID}"

app="build/macos/Build/Products/Release/iPing.app"
test -d "$app"
signing=(--force --options runtime --timestamp --sign "$CODESIGN_IDENTITY")
if [ -n "${KEYCHAIN_FILE:-}" ]; then
  signing+=(--keychain "$KEYCHAIN_FILE")
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

retry_apple_validation() {
  local attempt status
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    else
      status=$?
    fi
    [ "$attempt" -lt 3 ] || return "$status"
    sleep 5
  done
}


# LaunchAtLogin ships build-time helper archives with development signatures.
/usr/bin/find "$app/Contents/Resources" -path '*/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources/LaunchAtLoginHelper*.zip' -delete

while IFS= read -r -d '' binary; do
  if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
    retry_apple_validation /usr/bin/codesign "${signing[@]}" "$binary"
  fi
done < <(/usr/bin/find "$app/Contents" -type f -print0)

while IFS= read -r -d '' bundle; do
  retry_apple_validation /usr/bin/codesign "${signing[@]}" "$bundle"
done < <(/usr/bin/find "$app/Contents" -depth -type d \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \) -print0)

retry_apple_validation /usr/bin/codesign "${signing[@]}" \
  --entitlements macos/Runner/Release.entitlements "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
notary_auth=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY" --issuer "$APPLE_API_ISSUER")
xcrun notarytool submit "$work/notarize.zip" "${notary_auth[@]}" \
  --wait --output-format json > "$work/result.json"
if ! python3 - "$work/result.json" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit(f"Notarization failed: {result.get('status')} ({result.get('id')})")
PY
then
  submission="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$work/result.json")"
  xcrun notarytool log "$submission" "${notary_auth[@]}"
  exit 1
fi

retry_apple_validation xcrun stapler staple "$app"
retry_apple_validation xcrun stapler validate "$app"
retry_apple_validation /usr/sbin/spctl --assess --type execute --verbose "$app"
