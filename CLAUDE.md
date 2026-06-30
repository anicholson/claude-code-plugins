# CLAUDE.md

## Mental Model

> Each product's own mental model lives in its `MENTAL_MODEL.md`, indexed at [MENTAL_MODEL.md](MENTAL_MODEL.md). That index only references the per-product models and explains why the mental model is decomposed (do not centralize it). This section is the monorepo-level overview — what's here and how it's published — not a per-product model.

This is the **elimydlarz** monorepo — source code, plugin marketplace, and documentation for all Claude Code plugins and packages. The individual repos (`elimydlarz/trunk-sync`, `elimydlarz/req-mod-sync`, `elimydlarz/test-trees`, `elimydlarz/eli-rules`) are deprecated and point here.

Products in this repo:

- **trunk-sync** — multi-agent sync hook + seance CLI. The per-edit hook runs on Claude Code and Codex (stdin hook via `scripts/trunk-sync.sh`) and on OpenCode (the `src/opencode-plugin.ts` plugin shipped under `.opencode/`, which subprocesses the same `hook-entry`). npm package `@elimydlarz/trunk-sync`.
- **contree** — test trees as living requirements: setup, change, sync, and TDD skills with stop hook + coding rules. Ships from one `contree/` directory across three harnesses. Claude Code and Codex share `skills/` and `hooks/` via parallel `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` manifests (Codex sets `CLAUDE_PLUGIN_ROOT` in hook env, so the same hook commands run unchanged). OpenCode reuses `skills/` but reimplements the hooks as a single `.opencode/plugin/contree.ts` plugin — the Stop drift-check as a `session.idle` re-drive, the mental-model validator as `tool.execute.after` — since OpenCode has no `hooks.json` lifecycle.

Users add this repo as a marketplace (`claude plugin marketplace add elimydlarz/claude-code-plugins`), then install individual plugins. The marketplace uses relative paths (`"source": "./trunk-sync"`) so plugins are installed directly from this repo.

## Repo Map

```
package.json                    — root package with publish scripts (pnpm publish:<project>)
.claude-plugin/marketplace.json — plugin catalog (name: elimydlarz, relative paths to each plugin)
scripts/                        — publish scripts and shared helpers (bump-plugin-version.js)
README.md                       — unified docs for all products
CLAUDE.md                       — this file
MENTAL_MODEL.md                 — index of per-product mental models (references only — see the file for the rationale)

trunk-sync/                     — multi-agent sync plugin + seance CLI (has its own CLAUDE.md)
contree/                        — test trees as living requirements plugin (has its own CLAUDE.md)
```

Each subdirectory has its own `MENTAL_MODEL.md` (its mental model) and `CLAUDE.md` (requirements and development guidance, pointing at the mental model).

## Publishing

All projects publish via pnpm scripts from the repo root. Release notes are required — review commits since the last tag of the plugin's series, draft notes to a file, then pass it in:

```bash
git log <prev-tag>..HEAD -- <plugin>/    # review and draft notes to /tmp/notes.md
pnpm publish:contree patch --notes-file /tmp/notes.md    # or minor, major
```

Invoking a publish script without `--notes-file` fails fast and prints the exact `git log` command to use for review. Each script checks for clean source, runs tests (if any), bumps the version, commits, tags, pushes, and creates a GitHub release from the supplied notes file. trunk-sync also publishes to npm.

## Updating the marketplace

To add or update a plugin listing, edit `.claude-plugin/marketplace.json` and push to GitHub. Users pick up changes on their next `claude plugin marketplace update`.

Each plugin entry needs `name` and `source` at minimum. For plugins in this repo, use relative paths:

```json
{
  "name": "plugin-name",
  "source": "./plugin-name"
}
```
