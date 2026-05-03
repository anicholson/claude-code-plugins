# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mental Model

trunk-sync has two independent layers that share one git repo:

**Hook layer** — a Claude Code plugin that fires after every Edit/Write tool use. It stages, commits, pulls from `origin/main`, and pushes — keeping multiple agents in continuous integration. The logic is implemented in TypeScript (functional core in `hook-plan.ts`, imperative shell in `hook-execute.ts`) and invoked via a thin bash wrapper (`scripts/trunk-sync.sh → node dist/lib/hook-entry.js`). Merge conflicts are surfaced as hook feedback (exit 2); the agent resolves by editing the file, and the hook completes the merge on the next fire.

**CLI layer** — a TypeScript CLI (`trunk-sync`) with three commands:
- `install` — soft checks (git repo warns, missing remote is silent), hard checks (jq, claude), adds the GitHub repo as a marketplace source, then installs the plugin via `claude plugin install` (default project scope, `--scope user` for all repos). `--client codex` writes a marketplace entry under `~/.agents/plugins/marketplace.json` instead.
- `seance` — traces a line of code via `git blame` → commit body → `Session:` + `Agent:` fields → truncates the session transcript to that commit's timestamp → creates a worktree at that commit → dispatches per agent: Claude resumes via `claude --resume` reading rewritten JSONL under `~/.claude/projects/<worktree-slug>/`; Codex resumes via `codex exec --sandbox read-only … resume <uuid>` reading a rewritten rollout under `~/.codex/sessions/<Y>/<M>/<D>/`.
- `config` — reads/writes `~/.trunk-sync` config file (key=value format)

The hook writes `Session: <uuid>` and `Agent: <claude|codex>` into every commit body, plus `TranscriptPath: <path>` when the payload provides one (Codex) — for Claude the transcript is derived from the project slug + session ID. This (and the optional `.transcripts/` snapshot) is the only coupling between the two layers.

Codex-side seance fact, non-obvious and not recoverable from code alone: **`codex resume <uuid>` finds rollouts by scanning `~/.codex/sessions/<date>/`**. A row in `~/.codex/state_5.sqlite`'s `threads` table is *not* required — placing a rollout file at the canonical path with a rewritten `SessionMeta.payload.id`/`cwd` is sufficient. Don't add DB insertion logic.

**Clocking in** — agents clock in and out of work. On every commit, the hook writes a timecard to `.trunk-sync/timeclock/<session-id>.json` recording who the agent is, what branch it's on, and what task it's working on (extracted from the transcript). Timecards are committed and pushed alongside code changes, giving cross-machine visibility. Agents with dead PIDs (local) or stale timestamps (remote, 30 min) are automatically clocked out. When other agents are clocked in, the hook surfaces a throttled message (exit 2, once per 5 min) so the agent can reason about resource conflicts (ports, build locks, test databases).

Key domain concepts: worktree (optional, via `claude -w` — needed for multi-agent to isolate working trees), trunk (always `origin/main`), session ID (links commits to Claude conversations), timecard (`.trunk-sync/timeclock/<id>.json` — who's clocked in, what they're working on).

## Repo Map

```
.claude-plugin/plugin.json    — plugin manifest (name, version)
.claude-plugin/marketplace.json — marketplace definition (name: susu-eng, lists plugins)
dist/                         — compiled JS (tracked in git — marketplace installs from repo)
hooks/hooks.json              — hook registration (Edit|Write|Bash → scripts/trunk-sync.sh)
scripts/trunk-sync.sh         — 4-line bash wrapper: exec node dist/lib/hook-entry.js
scripts/sync-plugin-version.js — npm version hook: syncs plugin.json version from package.json

src/lib/hook-types.ts         — types (HookInput, RepoState, HookPlan)
src/lib/hook-plan.ts          — pure decision logic (no I/O, no git)
src/lib/hook-plan.test.ts     — unit tests for pure logic (fast, no repos)
src/lib/hook-execute.ts       — gathers git state, executes the plan
src/lib/hook-execute.test.ts  — integration tests (temp repos)
src/lib/hook-entry.ts         — entry point: reads stdin, wires layers, exits

src/cli.ts                    — CLI entry point, argv dispatch
src/commands/install.ts       — trunk-sync install
src/commands/seance.ts        — trunk-sync seance (default/--inspect/--list modes)
src/commands/config.ts        — trunk-sync config (read/write ~/.trunk-sync)
src/commands/config.test.ts   — config command tests (node:test)
src/commands/install.test.ts  — install command tests (node:test)
.transcripts/                 — opt-in session snapshots committed by hook
src/lib/git.ts                — shared git utilities (blame, parseFileRef, extractSessionId, findSnapshotInCommit)
src/lib/git.test.ts           — unit tests (node:test)
src/commands/seance.test.ts   — integration tests (node:test)

test/trunk-sync.test.sh       — hook e2e test suite (TAP, temp repos + bare remote)
test/local-setup.sh           — manual test setup
test/local-cleanup.sh         — manual test teardown
```

## Behaviour Contract

Behavioural requirements live as test trees in [`TEST_TREES.md`](./TEST_TREES.md). Each tree reifies one test file; each path corresponds to one `describe`/`it`. Trees are the contract — modify trees before code, then drive code from failing tests.

## Conventions (non-behavioural)

- **version-sync**: `npm version` automatically updates `.claude-plugin/plugin.json` to match `package.json` via the `version` lifecycle script
- **dist-tracked**: `dist/` is committed to git (excluding tests and `.d.ts`) so marketplace plugin installs have the compiled hook entry point
- **doc-alignment**: user-facing docs (README, rules, CLI output) must stay consistent with the trees — worktree mode is optional (for multi-agent), not required for single-agent use

## Development

### Tests

```bash
# CLI tests (TypeScript, node:test)
pnpm run build && pnpm test

# Hook e2e tests (shell, TAP output)
pnpm run test:e2e
```

Hook tests create isolated temp repos with worktrees and a bare remote. Safe to run anywhere — no network access needed.

### Building the CLI

```bash
pnpm run build        # compile TypeScript → dist/
pnpm run dev -- <cmd> # run from source via tsx
```

### Manual testing

Scripts for testing the hook live against origin with real worktrees:

```bash
# 1. Setup — commits a file on local main without pushing
bash test/local-setup.sh

# 2. Launch two agents in worktrees
#    Terminal 1:
claude -w
#    Terminal 2:
claude -w

# 3. Give each agent a task that edits test/battlefield.txt
#    They will conflict on the same file and the hook will handle it.

# 4. Verify
git log --oneline origin/main   # should have auto-commits + local-only commit
git status                       # main should be clean and up to date
cat test/battlefield.txt         # should reflect the resolved content

# 5. Cleanup — resets local main and origin/main to pre-test state,
#    removes all worktrees and trunk-sync branches
bash test/local-cleanup.sh
```

### Publishing

Two distribution channels — both must be updated together:

```bash
# 1. Bump version in both manifests
#    - package.json (npm)
#    - .claude-plugin/plugin.json (plugin)

# 2. Build (dist/ is tracked — marketplace installs need compiled JS)
pnpm run build

# 3. Publish to npm (prepublishOnly also runs build)
pnpm publish

# 4. Push to GitHub (plugin installs from repo root)
git push origin main
```

`dist/` is tracked in git because the marketplace plugin installs directly from the repo — without compiled JS, the hook silently fails. Test files and `.d.ts` are gitignored. The npm tarball uses the `files` field in `package.json` to select what ships.


### Key conventions

- Hook no longer requires `jq` at runtime (TypeScript handles JSON parsing); `jq` is still checked by `install` command
- CLI has zero runtime dependencies — only devDependencies (typescript, tsx, @types/node)
- All TypeScript imports use `.js` extensions (Node16 ESM requirement)
- Hook exit codes: 0 = success/no-op, 2 = conflict/failure with agent feedback on stderr

### Testing conventions

- Every exported function must have tests — when adding a new export, add tests in the same PR
- Three-layer rule: pure logic → unit tests; git/fs callers → integration tests (real temp repos); shell E2E as safety net
- Test file placement: `foo.ts` → `foo.test.ts`, CLI tests in `src/commands/`
- Reuse helpers: `initRepo()`, `makeInput()`, `makeState()`, `setupRepoWithRemote()`
- No mocks for git — use real temp repos with `mkdtempSync`
- CLI command tests via subprocess (`node dist/cli.js`)
- Execution functions (`executePlan`, `executeSync`, `amendWithTranscriptSnapshot`) require tests covering changed behavior
