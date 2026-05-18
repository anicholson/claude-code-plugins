---
name: publish
description: "Publish a plugin from this repo end-to-end: review commits since the last tag, draft release notes, run the publish script. TRIGGER when the user says 'publish <plugin>', 'release <plugin>', 'cut a release', 'ship contree/trunk-sync/climber/openclaw-notifier', or asks to publish without specifying how."
---

# Publish a plugin

Drives `scripts/publish-<plugin>.sh` end-to-end. The script requires `--notes-file`; this skill produces the notes file from the actual commit history so the human never has to draft notes manually.

## Plugins and their tag prefixes

| Plugin | Script | Tag prefix |
|---|---|---|
| `contree` | `publish-contree.sh` | `contree-v` |
| `trunk-sync` | `publish-trunk-sync.sh` | `v` |
| `climber` | `publish-climber.sh` | `climber-v` |
| `openclaw-notifier` | `publish-openclaw-notifier.sh` | `openclaw-notifier-v` |

## Process

### 1. Resolve plugin and bump

From the user's request, pick `<plugin>` and `<bump>` (`patch`/`minor`/`major`). If bump isn't given, default to `patch` — that's almost always the right call for these plugins.

### 2. Review commits since last tag

```
PREV=$(git tag --list --sort=-v:refname '<prefix>*' | head -n1)
git log "$PREV"..HEAD --oneline -- <plugin>/
git log "$PREV"..HEAD --stat -- <plugin>/
```

Then read the actual diff for any commit whose message is uninformative (the `auto(...)` commits from trunk-sync usually need this) so the notes describe real user-visible changes, not commit-message noise. Group related commits into one bullet rather than one-per-commit.

### 3. Draft notes

Write to `/tmp/<plugin>-notes.md`. Format:

```markdown
## What's new

- **<Headline change>.** One sentence on user-visible impact.
- **<Next change>.** One sentence.
```

Notes describe **what changed for users**, not what files were touched. If a change is purely internal (refactor, test-only, hook plumbing with no behavioural effect), say so plainly — don't pad. Skip notes-worthy framing for changes that don't reach the user.

Do not pause for sign-off — proceed.

### 4. Run the publish

```
pnpm publish:<plugin> <bump> --notes-file /tmp/<plugin>-notes.md
```

The script handles: clean-source check, version bump, commit, annotated tag, push with `--follow-tags`, GitHub release. trunk-sync also publishes to npm.

### 5. If it fails

- **"Uncommitted changes"** — stop and surface the dirty files. Do not auto-commit; the user owns scope.
- **"tag exists locally but has not been pushed"** — this used to happen with lightweight tags; the scripts now use annotated tags so `--follow-tags` carries them. If it recurs, fix the script, don't paper over with a manual push.
- **`gh release create` fails for any other reason** — the commit and tag are already on GitHub. Re-run only the release step: `gh release create <tag> --title "<plugin> v<version>" --notes-file /tmp/<plugin>-notes.md`.

## What this skill is not

It is not a place to discuss whether to publish, what should be in the release, or whether the version bump is right. Those are upstream decisions. By the time this skill runs, the user has decided to ship — execute.
