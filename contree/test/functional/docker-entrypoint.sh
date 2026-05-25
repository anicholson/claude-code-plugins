#!/usr/bin/env bash
set -euo pipefail

# Runs a contree functional case against a coding-agent harness.
# Works both inside Docker (called by docker-run.sh) and directly on the host.
#
# Expects:
#   - For claude: ANTHROPIC_API_KEY in environment or in .env
#   - For codex:  OPENAI_API_KEY in environment or in .env
#   - $1 is the test name (layered-workflow | mental-model-validator-smoke | describe-it-drift | diff-images)
#   - $2 is the harness  (claude | codex), default claude

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name> [claude|codex]}"
HARNESS="${2:-claude}"
case "$HARNESS" in claude|codex) ;; *) echo "Unknown harness: $HARNESS (use claude or codex)" >&2; exit 1;; esac

if [ -d "/work/contree" ]; then
  CONTREE_ROOT="/work/contree"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

ENV_FILE="$CONTREE_ROOT/test/functional/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi
FIXTURES="$CONTREE_ROOT/test/fixtures"
PROJECT_DIR="/tmp/contree-test-project"
OUTPUT_DIR="$CONTREE_ROOT/test/functional"
if [ -d "/output" ]; then
  OUTPUT_DIR="/output"
fi
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-verify.txt"

rm -f "$TRANSCRIPT_FILE"

# --- Helpers ---

seed_project() {
  local fixture_name="$1"
  local fixture_dir="/fixtures/$fixture_name"
  [ -d "$fixture_dir" ] || fixture_dir="$FIXTURES/$fixture_name"

  rm -rf "$PROJECT_DIR"
  cp -r "$fixture_dir" "$PROJECT_DIR"
  [ -f "$FIXTURES/$fixture_name/CLAUDE.md" ] && cp "$FIXTURES/$fixture_name/CLAUDE.md" "$PROJECT_DIR/"
  (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed")
}

CODEX_PRIMED=0

prime_codex_plugin() {
  # Codex reads cached plugins from ~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/
  # plus a config.toml entry that enables the plugin and the under-development
  # plugin_hooks feature (without it, hook scripts in hooks.json are ignored).
  # See codex-rs/core/src/plugins/manager_tests.rs::plugins_for_config_reloads_when_plugin_hooks_enablement_changes.
  [ "$CODEX_PRIMED" -eq 1 ] && return 0
  CODEX_PRIMED=1

  local cache_dir="$HOME/.codex/plugins/cache/local-marketplace/contree/local"
  rm -rf "$cache_dir"
  mkdir -p "$(dirname "$cache_dir")"
  cp -r "$CONTREE_ROOT" "$cache_dir"

  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<'CONFIG'
model_reasoning_effort = "low"

[features]
plugin_hooks = true

[plugins."contree@local-marketplace"]
enabled = true
CONFIG

  : "${CODEX_API_KEY:?CODEX_API_KEY required for codex harness (set from OPENAI_API_KEY in docker-run.sh)}"
}

AGENT_CALL_COUNT=0

run_agent() {
  local prompt="$1"
  AGENT_CALL_COUNT=$((AGENT_CALL_COUNT + 1))

  if [ "$HARNESS" = "claude" ]; then
    local continue_flag=()
    [ "$AGENT_CALL_COUNT" -gt 1 ] && continue_flag=(-c)
    (cd "$PROJECT_DIR" && claude -p "$prompt" \
      "${continue_flag[@]}" \
      --plugin-dir "$CONTREE_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      --output-format stream-json \
      --verbose \
      2>&1) | tee -a "$TRANSCRIPT_FILE" || true
    return
  fi

  prime_codex_plugin
  if [ "$AGENT_CALL_COUNT" -eq 1 ]; then
    (cd "$PROJECT_DIR" && codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      --skip-git-repo-check \
      --json \
      -m gpt-5.4-mini \
      -C "$PROJECT_DIR" \
      "$prompt" 2>&1) | tee -a "$TRANSCRIPT_FILE" || true
  else
    (cd "$PROJECT_DIR" && codex exec resume --last \
      --dangerously-bypass-approvals-and-sandbox \
      --skip-git-repo-check \
      --json \
      -m gpt-5.4-mini \
      "$prompt" 2>&1) | tee -a "$TRANSCRIPT_FILE" || true
  fi
}

write_verify() {
  cat > "$VERIFY_FILE"
  echo ""
  cat "$VERIFY_FILE"
}

OPENAI_STUB_PID=0

start_openai_image_stub() {
  # Mock OpenAI's images generations endpoint so /diff can run without a real
  # (billable, non-deterministic) gpt-image-2 call. Serves a canned b64_json
  # image. Both the OpenAI SDK (via OPENAI_BASE_URL) and the skill's curl recipe
  # (via a URL-rewriting curl shim) are pointed at this local stub.
  local port=8771
  local stub="/tmp/openai-image-stub.js"
  cat > "$stub" <<'JS'
const http = require('http')
const image = Buffer.from('mock-image').toString('base64')
http.createServer((req, res) => {
  let body = ''
  req.on('data', (c) => (body += c))
  req.on('end', () => {
    if (req.method === 'POST' && req.url.includes('/images/generations')) {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ data: [{ b64_json: image }] }))
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' })
      res.end('{}')
    }
  })
}).listen(process.env.STUB_PORT, () => console.error('openai-image-stub listening'))
JS
  STUB_PORT="$port" node "$stub" &
  OPENAI_STUB_PID=$!

  local real_curl; real_curl="$(command -v curl)"
  cat > /usr/local/bin/curl <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do args+=("\${a//https:\/\/api.openai.com\/v1/http:\/\/127.0.0.1:$port\/v1}"); done
exec "$real_curl" "\${args[@]}"
EOF
  chmod +x /usr/local/bin/curl

  export OPENAI_API_KEY="test-key-mock"
  export OPENAI_BASE_URL="http://127.0.0.1:$port/v1"
}

# --- Test cases ---

case "$TEST_NAME" in
  mental-model-validator-smoke)
    seed_project "greenfield"

    cat > "$PROJECT_DIR/MENTAL_MODEL.md" <<'MM'
## Core Domain Identity

- placeholder

## World-to-Code Mapping

- placeholder

## Ubiquitous Language

- placeholder

## Bounded Contexts

- placeholder

## Invariants

- placeholder

## Decision Rationale

- placeholder

## Rogue Extra Section

- this heading is not one of the seven
MM
    (cd "$PROJECT_DIR" && git add -A && git commit -q -m "seed: malformed MENTAL_MODEL.md")

    run_agent \
      "Read MENTAL_MODEL.md and add one placeholder bullet to the Invariants section. Save the file. Do nothing else."

    write_verify << 'VERIFY'
Evaluate the transcript against the `post-update-hook` and `mental-model-validator` trees.

The scenario: MENTAL_MODEL.md was seeded malformed (missing the Temporal View
section; contains an extra "Rogue Extra Section" heading that is not one of
the seven named sections). The agent then edits the file. The PostToolUse hook
must fire, invoke the validator, and surface its findings via additionalContext
JSON, visible in the transcript as a hook event.

Expected signals in the transcript:

  - a hook-event entry whose hookEventName is "PostToolUse"
  - additionalContext naming the missing "Temporal View" section
  - additionalContext naming the rogue "Rogue Extra Section" heading
  - the agent acknowledges the findings in its next response

For each `when/then` path in `post-update-hook` and `mental-model-validator`,
return PASS / FAIL / N/A with quoted evidence. Report counts at the end.
VERIFY
    ;;

  layered-workflow)
    # The single end-to-end journey: setup → workflow → drift+sync against an
    # HTTP API fixture that exercises Journey, System, Adapter (driving + driven),
    # Use-case, Domain, ports, and in-memory adapters. Run under both harnesses.
    seed_project "bookmarks-api"

    echo ""
    echo "=== Phase 1: setup ==="
    run_agent \
      "This project has no code yet — read CLAUDE.md for the Mental Model, then run /contree:setup to configure the test framework and generate test trees. This project has HTTP endpoints and a persistence port, so expect trees at multiple layers."

    echo ""
    echo "=== Phase 2: workflow (change → sync → tdd) ==="
    run_agent \
      "Now implement the project. Use /contree:workflow to set expected behaviour in trees and drive the implementation outside-in. The project has a BookmarkRepository port — remember to build an in-memory adapter and a shared port contract suite alongside the file-based production adapter. Skip mutation testing for this run — configure it if setup tells you to, but do not execute Stryker."

    echo ""
    echo "=== Phase 3: drift injection + sync ==="
    HANDLER_FILE="$(find "$PROJECT_DIR/src" -maxdepth 3 \( -name '*.ts' -o -name '*.js' \) -not -name '*.test.*' -not -name '*.spec.*' -print0 | xargs -0 grep -l 'router\|app\.\(get\|post\|delete\|put\)' 2>/dev/null | head -n 1)"
    if [ -n "$HANDLER_FILE" ] && [ -f "$HANDLER_FILE" ]; then
      cat >> "$HANDLER_FILE" <<'DRIFT'

// Drift injected by the functional harness — this endpoint is NOT in the trees.
app.delete('/bookmarks/:id', (req, res) => {
  res.status(204).end()
})
DRIFT
      (cd "$PROJECT_DIR" && git add -A && git commit -q -m "inject drift: DELETE endpoint")
      echo "[harness] Injected drift into $HANDLER_FILE (added DELETE /bookmarks/:id)."
    else
      echo "[harness] WARNING: could not find a route handler to drift. Phase 3 may not see drift."
    fi

    run_agent \
      "Something feels off in this project — please audit for drift between the trees and the implementation, then propose fixes."

    write_verify << VERIFY
Evaluate the transcript against every tree in the plugin's
\`contree/CLAUDE.md\` \`## Test Trees\` section.

Harness under test: **$HARNESS**.

Focus areas:
  - change-decomposes-across-layers (Journey → System → inner-layer decomposition; port decomposition, in-memory + real adapters, shared contract)
  - change-writes-trees (Domain/Use-case/Port-contract trees code-shaped; Journey/System/Adapter trees use consumer vocabulary)
  - outside-in-tdd (first failing test is a Journey test; Use-case wired with in-memory adapters; Adapter runs shared contract; describe/it mirrors trees verbatim; inner units get their own ground-level failing test before code — journey/functional coverage is not coverage)
  - composable-testing (file naming conventions, port contract suite)
  - dual-harness-compatibility (when run under codex: SessionStart rules visible in transcript; PostToolUse hook fires after edits)

Specific layer-shape checks:
  - Inspect TEST_TREES.md — at least one Domain/Use-case/Port-contract tree has top-level nodes named after the unit's functions/methods/operations.
  - Inspect the corresponding test file — describe/it mirrors the tree verbatim.
  - Journey/System/Adapter trees use consumer vocabulary, describe principles not enumerated cases.

Out of scope for this scenario (mark these tree paths N/A, not FAIL):
  - outside-in-tdd: "when all trees for a slice have passing tests then run mutation testing" — the prompt instructs the agent to skip Stryker execution to stay within budget. Stryker should be CONFIGURED (phase 1 setup) but NOT EXECUTED. If the transcript shows the agent ran Stryker anyway, that is a FAIL of obedience to the user instruction, not a tree FAIL.

For each \`when/then\` path in each tree, return one of:

  PASS — transcript demonstrates the assertion (quote evidence)
  FAIL — transcript contradicts the assertion (quote evidence)
  N/A  — the scenario did not exercise this assertion

The trees ARE the checklist. Report results grouped by tree, then a final summary
of PASS / FAIL / N/A counts across all trees.
VERIFY
    ;;

  diff-images)
    # Verifies the user-invoked /contree:diff skill end to end against a mocked
    # gpt-image-2 endpoint. Claude harness only — the stub overrides OPENAI_API_KEY,
    # which the codex harness needs for its own model calls.
    seed_project "greenfield"

    # Introduce an uncommitted, staged change for /diff to depict.
    cat > "$PROJECT_DIR/index.js" <<'JS'
export function add(a, b) {
  return a + b
}
JS
    (cd "$PROJECT_DIR" && git add index.js)

    start_openai_image_stub

    run_agent \
      "Run /contree:diff to generate an image of the current change."

    kill "$OPENAI_STUB_PID" 2>/dev/null || true

    write_verify << 'VERIFY'
Evaluate the transcript against the `diff-images-the-change` tree.

The scenario: the working tree has a staged change (a new `add(a, b)` function in
index.js). OpenAI's images generations endpoint is mocked — a local stub returns a
canned b64_json image, and both the OpenAI SDK (OPENAI_BASE_URL) and the skill's
curl recipe (a URL-rewriting curl shim) are pointed at it. The user runs /contree:diff.

Expected signals in the transcript:

  - the agent reads the change via `git diff` / `git diff --staged` (sees the add() function)
  - the agent calls the images generations endpoint for the `gpt-image-2` model
    (a request to /v1/images/generations naming model gpt-image-2-2026-04-21)
  - the agent decodes the returned base64 and saves a .png file in the project
  - the agent surfaces its choices — what it depicted, the details it foregrounded,
    and the audience — for the user to review
  - on success the agent does NOT report a fabricated/placeholder image

For each path in `diff-images-the-change`, return PASS / FAIL / N/A with quoted
evidence. Report counts at the end.
VERIFY
    ;;

  describe-it-drift)
    seed_project "describe-it-drift"

    run_agent \
      "Check this project for drift between the test trees and the test files."

    write_verify << 'VERIFY'
Evaluate the transcript against the `sync-audits-and-resolves` tree,
specifically the describe/it drift case.

The fixture: one tree named `Bookmark` with paths
  `parseUrl / when called with an https URL / then the canonical form is returned`
  `parseUrl / if called with a non-URL string / then InvalidUrl is thrown`
and a test file `src/bookmark.domain.test.js` whose describe/it hierarchy is
  `Bookmark / URL handling / returns canonical https form`
  `Bookmark / URL handling / throws for garbage input`
The code and the tree agree — only the test file's structure has drifted.

Expected signals in the transcript:

  - the agent invokes /contree:sync or follows the sync process
  - the agent identifies describe/it drift — the test file's describe/it hierarchy
    does not mirror the tree verbatim
  - the agent presents BOTH the tree paths AND the test file's describe/it structure
    to the user
  - the agent asks the user which side is authoritative — does NOT silently pick

For each expected signal, return PASS / FAIL / N/A with quoted evidence.
Report counts at the end.
VERIFY
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    echo ""
    echo "Available tests:"
    echo "  layered-workflow              — HTTP API: setup → workflow → drift → sync (every tree, every layer)"
    echo "  mental-model-validator-smoke  — one-shot: malformed MM + agent edit → verifies PostToolUse hook + validator"
    echo "  describe-it-drift             — one-shot: pre-seeded describe/it mismatch → verifies sync flags it"
    echo ""
    echo "Harness (2nd arg): claude | codex (default claude)"
    exit 1
    ;;
esac

echo ""
echo "Transcript: $TRANSCRIPT_FILE"
echo "Verify:     $VERIFY_FILE"
