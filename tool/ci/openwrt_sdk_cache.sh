#!/usr/bin/env bash
set -euo pipefail

cd /builder
: "${SDK_IMAGE_ID:?}" "${SDK_SLOT:?}"
[[ "$SDK_SLOT" =~ ^openwrt-[0-9]+\.[0-9]+-[a-zA-Z0-9_-]+$ ]]
mkdir -p /ci-cache/states /ci-cache/downloads /ci-cache/locks
identity="$(
  printf '%s\n' "$SDK_IMAGE_ID"
  cat version.buildinfo 2>/dev/null || true
  if [[ -d feeds/packages/lang/golang ]]; then
    find feeds/packages/lang/golang -type f -print0 | sort -z | xargs -0 sha256sum
  fi
)"
identity="$(printf '%s' "$identity" | sha256sum | cut -d' ' -f1)"
state="/ci-cache/states/$SDK_SLOT"

case "${1:?}" in
restore)
  exec 8>"/ci-cache/locks/$SDK_SLOT"
  flock 8
  if [[ -f "$state/identity" && "$(cat "$state/identity")" == "$identity" ]] && gzip -t "$state/state.tar.gz"; then
    echo "Restoring compiled SDK dependencies: $SDK_SLOT"
    tar -xzf "$state/state.tar.gz"
  else
    echo "Cold SDK dependency cache: $SDK_SLOT"
  fi
  flock -u 8
  for directory in build_dir/target-*/iping-[0-9]*; do
    [[ ! -d "$directory" ]] || rm -rf "$directory"
  done
  if [[ -d bin/packages ]]; then
    find bin/packages -type f \( -name 'iping_[0-9]*.ipk' -o -name 'iping-[0-9]*.apk' \) -delete
  fi
  # Cgo caches must follow the SDK's target libc and host ABI.
  mkdir -p "/ci-cache/go-build/$identity" /ci-cache/go-mod-cache tmp dl
  rm -rf tmp/go-build dl/go-mod-cache
  ln -s "/ci-cache/go-build/$identity" tmp/go-build
  ln -s /ci-cache/go-mod-cache dl/go-mod-cache
  exec 9>/ci-cache/locks/downloads
  flock 9
  cp -a /ci-cache/downloads/. dl/
  flock -u 9
  ;;
save)
  exec 9>/ci-cache/locks/downloads
  flock 9
  find dl -maxdepth 1 -type f ! -name '*.dl' ! -name '*.hash' -exec cp -p -t /ci-cache/downloads/ {} +
  flock -u 9
  temporary="$(mktemp -d "/ci-cache/states/$SDK_SLOT-XXXXXX")"
  trap 'rm -rf "$temporary"' EXIT
  paths=()
  for directory in build_dir/hostpkg build_dir/target-* staging_dir/hostpkg staging_dir/target-*; do
    [[ ! -d "$directory" ]] || paths+=("$directory")
  done
  tar -cf - "${paths[@]}" -C /artifacts bin | gzip -1 > "$temporary/state.tar.gz"
  printf '%s\n' "$identity" > "$temporary/identity"
  exec 8>"/ci-cache/locks/$SDK_SLOT"
  flock 8
  rm -rf "$state"
  mv "$temporary" "$state"
  echo "Saved compiled SDK dependencies: $SDK_SLOT ($(du -h "$state/state.tar.gz" | cut -f1))"
  ;;
*) exit 2 ;;
esac
