#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
remote="${IPING_UPDATE_REMOTE:-minio:iping/releases}"
staging="$(mktemp -d "${TMPDIR:-/tmp}/iping-release.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
dart run tool/update_manifest.dart --output "$staging" "$@"
version="$(python3 - "$staging/latest.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
print(f"{m['version']}+{m['buildNumber']}")
PY
)"
rclone copy "$staging/$version" "$remote/$version" --immutable
rclone check "$staging/$version" "$remote/$version" --one-way --download
rclone copyto "$staging/latest.json" "$remote/latest.json" --header-upload 'Cache-Control: no-cache, no-store, must-revalidate'
