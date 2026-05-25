# CLAUDE.md

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View.

## Repo Map

- `CLAUDE.md` — this file
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `hooks/hooks.json` — SubagentStop hook registration
- `scripts/notify.sh` — notification script (curl POST, fire-and-forget)
- `package.json` — dev dependencies (bats) and test scripts
- `test/plugin.bats` — structural tests: manifest validity, hook registration, bash syntax
- `test/functional/capture-server.mjs` — Node.js HTTP capture server for functional tests
- `test/functional/run.mjs` — functional test runner: real HTTP assertions

## Testing

```bash
pnpm test                # unit tests (bats) — structural validity
pnpm run test:functional # functional tests (node) — real HTTP behaviour
```

## Requirements

### SubagentNotification

```
SubagentNotification
  when OPENCLAW_URL is set and a subagent completes
    then POSTs a message to OPENCLAW_URL/hooks/agent with name "subagent-complete"
    and the message contains agent_type, agent_id, and reason
    and exits 0
  when OPENCLAW_URL is not set
    then exits 0 without making any HTTP request
  when OPENCLAW_TOKEN is set
    then includes Authorization Bearer header in the request
  when OPENCLAW_TOKEN is not set
    then sends the request without an Authorization header
  when the HTTP request fails (network error)
    then logs the failure to stderr
    and exits 0
  when the server returns a non-2xx status
    then logs the status code to stderr
    and exits 0
```

### PluginManifest

```
PluginManifest
  plugin.json
    then contains name "openclaw-notifier"
    and contains a valid semver version
    and contains a description
  hooks.json
    then registers a SubagentStop hook
    and the hook command points to scripts/notify.sh
```
