#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?}" "${BRANCH:?}" "${RUNNER_TEMP:?}" "${GITHUB_WORKSPACE:?}"
[[ "$ARCH" =~ ^[a-zA-Z0-9_-]+$ ]]
[[ "$BRANCH" =~ ^openwrt-[0-9]+\.[0-9]+$ ]]
root="$(cd "$(dirname "$0")/../.." && pwd)"
sdk_started=$SECONDS
staging="$(mktemp -d "$RUNNER_TEMP/iping-sdk-XXXXXX")"
container=''
# shellcheck disable=SC2317
cleanup() {
  if [[ -n "$container" ]]; then docker rm --force "$container" >/dev/null 2>&1 || true; fi
  sudo chown -R "$(id -u):$(id -g)" "$staging"
  rm -rf "$staging"
}
trap 'cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

upstream=f5813d30eeef3534b58ac7e79c5d8842b6035434
curl -fsSL --retry 4 --retry-all-errors --connect-timeout 15 --max-time 120 \
  "https://raw.githubusercontent.com/openwrt/gh-action-sdk/$upstream/entrypoint.sh" -o "$staging/official.sh"
echo "e78cc3ca3ffe9a15d47096e2e9a2aa07399a22a77acdca31f4e5aef2fa0e6a9c  $staging/official.sh" | sha256sum -c -
python3 - "$staging/official.sh" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
marker = 'group "make defconfig"\nmake defconfig\nendgroup\n'
assert s.count(marker) == 1
p.write_text(s.replace(marker, marker + '\nbash /ci/cache.sh restore\n'))
PY
cp "$root/tool/ci/openwrt_sdk_cache.sh" "$staging/cache.sh"
mkdir "$staging/output"
sudo chown 1000:1000 "$staging/output"
chmod 755 "$staging"
image="ghcr.io/openwrt/sdk:$ARCH-$BRANCH"
docker pull "$image"
image_id="$(docker image inspect "$image" --format '{{.Id}}')"
volume=iping-openwrt-cache-v1
docker run --rm --user 0 --entrypoint /bin/sh -v "$volume:/ci-cache" "$image" -c 'chown 1000:1000 /ci-cache'
container="$(docker create --cpus 4 --entrypoint /bin/bash \
  --env "SDK_IMAGE_ID=$image_id" --env "SDK_SLOT=$BRANCH-$ARCH" \
  --env GOMAXPROCS=4 --env FEEDNAME=iping --env 'PACKAGES=iping-mihomo iping' \
  --env NO_REFRESH_CHECK=1 --env NO_SHFMT_CHECK=1 --env V=s \
  -v "$volume:/ci-cache" -v "$staging:/ci:ro" \
  -v "$staging/output:/artifacts" -v "$GITHUB_WORKSPACE/openwrt:/feed:ro" \
  "$image" -c 'set +e; bash /ci/official.sh; result=$?; if [ "$result" = 0 ]; then bash /ci/cache.sh save || echo "SDK cache save failed" >&2; fi; exit "$result"')"
docker start --attach "$container" || true
status="$(docker wait "$container")"
sudo chown -R "$(id -u):$(id -g)" "$staging/output"
cp -a "$staging/output/." "$GITHUB_WORKSPACE/"
echo "SDK $BRANCH/$ARCH completed in $((SECONDS - sdk_started))s (status $status)"
exit "$status"
