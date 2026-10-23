#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_ENV:?}"
test -f pubspec.yaml && test -d core

base="${RUNNER_TOOL_CACHE:?}/iping"
target="$base/build/${1:?}"
mkdir -p "$target" "$base/pub" "$base/gradle" "$base/npm"
for path in build libclash .dart_tool/flutter_build .dart_tool/setup_build_cache .dart_tool/hooks_runner services/helper/target plugins/rust_api/rust/target; do
  mkdir -p "$target/$path" "$(dirname "$path")"
  if [ -L "$path" ] && [ "$(readlink "$path")" = "$target/$path" ]; then
    continue
  fi
  rm -rf "$path"
  ln -s "$target/$path" "$path"
done
{
  printf 'PUB_CACHE=%s/pub\n' "$base"
  printf 'GRADLE_USER_HOME=%s/gradle\n' "$base"
  printf 'npm_config_cache=%s/npm\n' "$base"
} >> "$GITHUB_ENV"
if [ "${RUNNER_OS:-}" = Linux ]; then
  mkdir -p "$base/go" "$base/go-build"
  {
    printf 'GOPATH=%s/go\nGOCACHE=%s/go-build\n' "$base" "$base"
  } >> "$GITHUB_ENV"
fi
echo 'Reusing local build and package caches outside the checkout.'
