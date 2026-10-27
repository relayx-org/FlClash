#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/commit_msg.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

message_file="$temp_dir/COMMIT_EDITMSG"
failures=0
subject='fix(core): keep the socket alive'

run() {
  printf '%s\n' "$@" >"$message_file"
  set +e
  bash "$checker" "$message_file" >"$temp_dir/out" 2>"$temp_dir/err"
  local status=$?
  set -e
  return $status
}

expect_pass() {
  local name="$1"
  shift
  if run "$@"; then
    return
  fi
  echo "FAIL: $name should be accepted" >&2
  cat "$temp_dir/err" >&2
  failures=$((failures + 1))
}

expect_fail() {
  local name="$1"
  local needle="$2"
  shift 2
  if run "$@"; then
    echo "FAIL: $name should be rejected" >&2
    failures=$((failures + 1))
    return
  fi
  if ! grep -q "$needle" "$temp_dir/err"; then
    echo "FAIL: $name did not explain the problem ($needle)" >&2
    cat "$temp_dir/err" >&2
    failures=$((failures + 1))
  fi
}

expect_pass 'a conventional subject' "$subject"
expect_pass 'a leading blank line still finds the subject' '' "$subject"
expect_pass 'a merge subject' 'Merge branch main into dev'
expect_pass 'a fixup subject' "fixup! $subject"
expect_pass 'a breaking commit with its footer' \
  'feat(backup)!: new archive layout' \
  '' \
  'BREAKING CHANGE: Archives from 0.8.95 and earlier need re-import'
expect_fail 'an empty message' 'empty' ''
expect_fail 'a non conventional subject' 'Conventional Commits' 'Optimize core service'
expect_fail 'an upper case description' 'lower case' 'fix(core): Keep the socket alive'
expect_pass 'a camel case identifier' 'fix(ui): AppBar text is truncated'
expect_pass 'an acronym' 'fix(core): DNS leaks after wake'
expect_fail 'an upper case first word before punctuation' 'lower case' \
  'fix(core): Keep, or drop, the socket'
expect_fail 'a trailing period' 'period' "$subject."
expect_fail 'a breaking marker with no footer' 'BREAKING CHANGE' \
  'feat(core)!: drop the legacy socket'
for trailer in \
  'co-authored-by: Devin <devin@example.com>' \
  'Co-authored-by: Review Helper <helper@openai.com>' \
  'Co-authored-by: Cursor Agent <cursoragent@cursor.com>' \
  'Co-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>'; do
  expect_fail "an agent co-author ($trailer)" 'coding agent' \
    "$subject" '' "$trailer"
done
expect_pass 'a human co-author' \
  "$subject" '' 'Co-authored-by: Jane Doe <jane.doe@example.com>'

expect_pass 'a user facing commit without release copy' \
  'feat(profiles): support override scripts'
if [[ -s "$temp_dir/err" ]]; then
  echo 'FAIL: a commit without release copy should not produce a warning' >&2
  failures=$((failures + 1))
fi
expect_fail 'leading blanks do not hide an agent co-author' 'coding agent' \
  '' "$subject" '' 'Co-authored-by: Codex <codex@example.com>'

if ((failures > 0)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi

echo 'commit_msg.sh behaves as documented.'
