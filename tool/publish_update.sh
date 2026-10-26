#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
remote="${IPING_UPDATE_REMOTE:-minio:iping/releases}"
staging="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/iping-release.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/update_manifest.dart --output "$staging" "$@"
version="$(python3 - "$staging/latest.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
print(f"{m['version']}+{m['buildNumber']}")
PY
)"
cp "$staging/latest.json" "$staging/$version/latest.json"
python3 - "$staging/$version" <<'PYCODE'
import hashlib,sys
from pathlib import Path
folder=Path(sys.argv[1])
(folder/'SHA256SUMS').write_text(''.join(
    hashlib.file_digest(path.open('rb'),'sha256').hexdigest()+'  '+path.name+'\n'
    for path in sorted(folder.iterdir()) if path.is_file()))
PYCODE
rclone_command() {
    set -- --s3-disable-http2 --s3-no-check-bucket "$@"
    if command -v rclone >/dev/null; then rclone "$@"
    else
        docker run --rm --user "$(id -u):$(id -g)" -v "$staging:$staging" \
            -e RCLONE_CONFIG=/dev/null -e RCLONE_CONFIG_MINIO_TYPE -e RCLONE_CONFIG_MINIO_PROVIDER \
            -e RCLONE_CONFIG_MINIO_ACCESS_KEY_ID -e RCLONE_CONFIG_MINIO_SECRET_ACCESS_KEY \
            -e RCLONE_CONFIG_MINIO_ENDPOINT -e RCLONE_CONFIG_MINIO_FORCE_PATH_STYLE rclone/rclone:1.69.1@sha256:600f51856285df1ae5d91c8bb2682cbbe31bf109ebeeef9ecead6ca8c0ff6138 "$@"
    fi
}
rclone_command copy "$staging/$version" "$remote/$version" --immutable --checksum
rclone_command check "$staging/$version" "$remote/$version" --one-way --download
if [ "${IPING_PUBLISH_LATEST:-1}" = 1 ]; then
    if [ -f "$staging/install-linux.sh" ]; then
        rclone_command copyto "$staging/install-linux.sh" "$remote/install-linux.sh" --header-upload 'Cache-Control: no-cache, no-store, must-revalidate'
    fi
    rclone_command copyto "$staging/latest.json" "$remote/latest.json" --header-upload 'Cache-Control: no-cache, no-store, must-revalidate'
fi
