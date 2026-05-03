#!/usr/bin/env bash
set -euo pipefail

BUMP="${1:-}"
if [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: publish-trunk-sync.sh <patch|minor|major>" >&2
  exit 1
fi

if [ -z "${SUSU_ENG_NPM_TOKEN:-}" ]; then
  echo "SUSU_ENG_NPM_TOKEN is not set — export it before publishing" >&2
  exit 1
fi
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT/trunk-sync"

# Source changes must be committed — dist/ staleness is handled below
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'trunk-sync/' ':!trunk-sync/dist/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted source changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

# Build and test
echo "==> Build"
pnpm run build

echo "==> Test (unit)"
pnpm test

echo "==> Test (e2e)"
pnpm run test:e2e

# Commit dist/ if the build produced changes
if [ -n "$(git -C "$REPO_ROOT" status --porcelain trunk-sync/dist/)" ]; then
  echo "==> Committing stale dist/"
  git -C "$REPO_ROOT" add trunk-sync/dist/
  git -C "$REPO_ROOT" commit -m "build: compile trunk-sync dist/"
fi

# Bump version — lifecycle script syncs plugin.json
echo "==> Version bump ($BUMP)"
pnpm version "$BUMP" --no-git-tag-version
node scripts/sync-plugin-version.js

VERSION=$(node -p "require('./package.json').version")
git -C "$REPO_ROOT" add trunk-sync/package.json trunk-sync/.claude-plugin/plugin.json
git -C "$REPO_ROOT" commit -m "v$VERSION"
git -C "$REPO_ROOT" tag "v$VERSION"

# Publish to npm — auth via SUSU_ENG_NPM_TOKEN, no OTP
echo "==> Publish to npm"
NPMRC="$REPO_ROOT/trunk-sync/.npmrc"
trap 'rm -f "$NPMRC"' EXIT
printf '//registry.npmjs.org/:_authToken=%s\n' "$SUSU_ENG_NPM_TOKEN" > "$NPMRC"
pnpm publish --no-git-checks

# Push commits + tag to GitHub
echo "==> Push to GitHub"
git -C "$REPO_ROOT" push origin main --follow-tags

echo ""
echo "published @susu-eng/trunk-sync v$VERSION"
echo "  npm: https://www.npmjs.com/package/@susu-eng/trunk-sync"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
