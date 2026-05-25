## Core Domain Identity

- A Claude Code plugin that notifies OpenClaw when a subagent completes, so the parent session wakes to act on the result.
- The SubagentStop hook POSTs a `subagent-complete` message to the OpenClaw gateway.
- Fire-and-forget: notification failures never block the agent.
- Safe everywhere: with `OPENCLAW_URL` unset the hook is a silent no-op.

## World-to-Code Mapping

- Subagent completion event → SubagentStop hook → `scripts/notify.sh` (curl POST).
- Gateway location → `OPENCLAW_URL`; hooks bearer token → `OPENCLAW_TOKEN`.
- Payload → a `/hooks/agent` message carrying `agent_type`, `agent_id`, `reason`.
- Structural contract → `test/plugin.bats`; real HTTP behaviour → `test/functional/run.mjs` against `capture-server.mjs`.

## Ubiquitous Language

- SubagentStop — the Claude Code event that fires when a subagent finishes.
- Gateway — the OpenClaw endpoint at `OPENCLAW_URL`.
- `/hooks/agent` — the gateway path the notification POSTs to.
- `OPENCLAW_TOKEN` — the `hooks.token` Bearer token (NOT the gateway auth token).
- Fire-and-forget — the hook always exits 0 regardless of HTTP outcome.

## Bounded Contexts

- Notification — extracting the payload and POSTing it to the gateway.
- Configuration — the two env vars that gate and authenticate the request.

## Invariants

- The hook always exits 0 — failures are logged to stderr, never blocking the agent.
- With `OPENCLAW_URL` unset, no HTTP request is made.
- `OPENCLAW_TOKEN` set → an Authorization Bearer header; unset → no auth header.
- The message always carries `agent_type`, `agent_id`, and `reason`.

## Decision Rationale

- Fire-and-forget because a notifier must never become a point of failure for the agent.
- Silent no-op without `OPENCLAW_URL` so the plugin is safe to install in non-OpenClaw sessions.
- `OPENCLAW_TOKEN` is the hooks token, kept distinct from the gateway auth token so the wrong credential is never sent.

## Temporal View

- On each subagent completion: read the payload → (if `OPENCLAW_URL` set) POST → exit 0.
- Failures (network error or non-2xx) are logged to stderr and still exit 0.
