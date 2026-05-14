#!/usr/bin/env bash
set -euo pipefail

PLUGIN="${1:-}"
VERSION="${2:-}"
if [ -z "$PLUGIN" ] || [ -z "$VERSION" ]; then
  echo "Usage: release-notes.sh <plugin> <version>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$PLUGIN" = "trunk-sync" ]; then
  TAG_PREFIX="v"
  TAG_PATTERN="v[0-9]*"
  PATH_ARGS=("trunk-sync/" ":!trunk-sync/dist/")
else
  TAG_PREFIX="${PLUGIN}-v"
  TAG_PATTERN="${PLUGIN}-v[0-9]*"
  PATH_ARGS=("${PLUGIN}/")
fi

NEW_TAG="${TAG_PREFIX}${VERSION}"

PREV_TAG=$(git -C "$REPO_ROOT" tag --list --sort=-v:refname "$TAG_PATTERN" \
  | grep -vx "$NEW_TAG" | head -n1 || true)

if [ -z "$PREV_TAG" ]; then
  RANGE_ARGS=()
else
  RANGE_ARGS=("${PREV_TAG}..HEAD")
fi

SEEN_SIDS=" "

while IFS=$'\t' read -r _hash msg; do
  [[ -z "$msg" ]] && continue
  [[ "$msg" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
  [[ "$msg" =~ ^[a-z0-9_-]+\ v[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
  [[ "$msg" =~ ^build: ]] && continue
  [[ "$msg" == "trunk sync noise" ]] && continue

  if [[ "$msg" =~ ^auto\(([^)]+)\):[[:space:]]*(.*)$ ]]; then
    sid="${BASH_REMATCH[1]}"
    msg="${BASH_REMATCH[2]}"
    case "$SEEN_SIDS" in *" $sid "*) continue ;; esac
    SEEN_SIDS="$SEEN_SIDS$sid "
  fi

  msg=$(printf '%s' "$msg" | sed -E 's/[[:space:]:]+$//')
  [[ -z "$msg" ]] && continue

  printf '%s\n' "- $msg"
done < <(git -C "$REPO_ROOT" log --format='%H%x09%s' "${RANGE_ARGS[@]}" -- "${PATH_ARGS[@]}")
