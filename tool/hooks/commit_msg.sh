#!/usr/bin/env bash

set -euo pipefail

message_file="${1:?commit message file is required}"

# The subject and the body have to be cut from the same text, or they overlap:
# `git commit --cleanup=verbatim` and hook-written templates both leave blank
# lines above the subject, and a body taken as "everything from line two" then
# contains the subject itself — enough for the trailer checks below to read the
# subject as a footer.
cleaned="$(grep -v '^#' "$message_file" | sed '/[^[:space:]]/,$!d' || true)"

subject="$(head -n 1 <<<"$cleaned")"

if [[ -z "$subject" ]]; then
  echo 'Commit message is empty.' >&2
  exit 1
fi

if [[ "$subject" =~ ^(Merge|Revert)[[:space:]] ]]; then
  exit 0
fi

if [[ "$subject" =~ ^(fixup|squash)! ]]; then
  exit 0
fi

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

if [[ ! "$subject" =~ ^($types)(\([a-z0-9,./_-]+\))?!?:[[:space:]].+ ]]; then
  cat >&2 <<EOF
Commit subject does not follow Conventional Commits:

  $subject

Expected: <type>[(scope)][!]: <description>
Types:    ${types//|/, }
Examples:
  perf(views): stop redoing per-frame work in build
  refactor(tray): replace the tray_manager fork with a first-party plugin
  fix(core,android)!: keep failures visible and lifecycle results honest
EOF
  exit 1
fi

if [[ ${#subject} -gt 100 ]]; then
  echo "Commit subject is ${#subject} characters; keep it within 100." >&2
  exit 1
fi

description="${subject#*: }"

first_word="${description%% *}"
first_word="${first_word%%[^[:alnum:]]*}"

if [[ "$first_word" =~ ^[A-Z][a-z]+$ ]]; then
  echo "Commit description should start in lower case: $description" >&2
  echo 'Identifiers and acronyms keep their own casing, for example AppBar or DNS.' >&2
  exit 1
fi

if [[ "$description" =~ \.$ ]]; then
  echo "Commit description should not end with a period: $description" >&2
  exit 1
fi

body="$(tail -n +2 <<<"$cleaned")"

agents='anthropic|claude|codex|copilot|cursor|devin|gemini|openai|\[bot\]'

if grep -qiE "^Co-authored-by:.*($agents)" <<<"$body"; then
  cat >&2 <<'EOF'
Do not credit a coding agent in a Co-authored-by trailer.

The history records who owns the change, not which tool typed it. Human
co-authors are still fine.
EOF
  exit 1
fi

if [[ "$subject" =~ ^($types)(\([a-z0-9,./_-]+\))?!: ]] &&
  ! grep -qE '^BREAKING[ -]CHANGE:' <<<"$body"; then
  cat >&2 <<'EOF'
A breaking commit needs a BREAKING CHANGE footer describing what breaks:

  feat(backup)!: new archive layout

  BREAKING CHANGE: Archives from 0.8.95 and earlier need re-import
EOF
  exit 1
fi
