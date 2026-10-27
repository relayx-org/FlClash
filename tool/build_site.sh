#!/usr/bin/env bash
set -euo pipefail

repo="${SITE_REPOSITORY:-chen08209/FlClash}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/site}"

if ! command -v node >/dev/null; then
  echo "error: tool/render_site.mjs needs Node.js on PATH" >&2
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"
cp -R "$root/site/." "$out/"
cp "$root/snapshots/preview.png" "$root/snapshots/preview-dark.png" "$out/"
cp "$root/assets/images/icon.png" "$out/icon.png"
cp "$root/assets_source/images/icon/glyph.svg" "$out/favicon.svg"

if stars="$(gh api "repos/$repo" --jq '.stargazers_count' 2>/dev/null)" &&
  release="$(gh api "repos/$repo/releases/latest" --jq ".tag_name, ({
  tag: .tag_name,
  publishedAt: .published_at,
  assets: [.assets[] | {name, size, digest}],
  stars: $stars
} | tojson)" 2>/dev/null)"; then
  { read -r tag && read -r json; } <<<"$release"
  printf '%s\n' "$json" >"$out/release.json"
else
  echo "warning: no release metadata from $repo; the page falls back to CHANGELOG.md" >&2
  tag=""
fi

cp "$root/CHANGELOG.md" "$out/CHANGELOG.md"

node "$root/tool/render_site.mjs" "$out" "${SITE_URL:-https://chen08209.github.io/FlClash}"

echo "site assembled in $out"
