#!/usr/bin/env bash
set -euo pipefail

BUMP=""
NOTES_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    patch|minor|major) BUMP="$1"; shift ;;
    --notes-file) NOTES_FILE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: publish-openclaw-notifier.sh <patch|minor|major> --notes-file <path>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$NOTES_FILE" ]; then
  PREV=$(git -C "$REPO_ROOT" tag --list --sort=-v:refname 'openclaw-notifier-v*' | head -n1)
  echo "Release notes required. Pass --notes-file <path>." >&2
  echo "Review commits with: git log ${PREV:+$PREV..}HEAD -- openclaw-notifier/" >&2
  exit 1
fi

if [ ! -f "$NOTES_FILE" ]; then
  echo "Notes file not found: $NOTES_FILE" >&2
  exit 1
fi

cd "$REPO_ROOT/openclaw-notifier"

# Source changes must be committed
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'openclaw-notifier/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

# Bump version in plugin.json
echo "==> Version bump ($BUMP)"
VERSION=$(node "$REPO_ROOT/scripts/bump-plugin-version.js" .claude-plugin/plugin.json "$BUMP")

git -C "$REPO_ROOT" add openclaw-notifier/.claude-plugin/plugin.json
git -C "$REPO_ROOT" commit -m "openclaw-notifier v$VERSION"
git -C "$REPO_ROOT" tag -a "openclaw-notifier-v$VERSION" -m "openclaw-notifier v$VERSION"

# Push commits + tag to GitHub
echo "==> Push to GitHub"
git -C "$REPO_ROOT" push origin main --follow-tags

echo "==> Create GitHub release"
gh release create "openclaw-notifier-v$VERSION" --title "openclaw-notifier v$VERSION" --notes-file "$NOTES_FILE"

echo ""
echo "==> Update marketplace and reinstall"
claude plugin marketplace update elimydlarz
claude plugin install openclaw-notifier@elimydlarz --scope user

echo ""
echo "published openclaw-notifier v$VERSION"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
