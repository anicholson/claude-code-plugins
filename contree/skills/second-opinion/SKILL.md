---
name: second-opinion
description: "Get an independent review of completed work from a different model — sends the change and the test-tree contract to Z.AI's GLM 5.2 and surfaces its critique. TRIGGER when: sync has just finished, the user asks for a second opinion, an independent review, or a sanity check on completed work before a PR or release."
---

# Second Opinion

Sends the completed change to a **different model** — Z.AI's **GLM 5.2** — and surfaces its independent review. Once `sync` reports the trees and implementation are aligned, a second pair of eyes from another model catches what a single perspective misses: bugs, drift from the test-tree contract, rule violations, gaps the author rationalised away.

## When to Use

- Immediately after `sync` reports the project is in sync — the natural next step.
- Before a PR or release, as a final independent check on completed work.
- When the user asks for a second opinion, an independent review, or a sanity check.

## Process

### 1. Gather the completed work

Derive the change from the working tree: run `git diff` and `git diff --staged` to see what changed. Read `## Test Trees` (or `TEST_TREES.md`) — this is the contract the work must satisfy. If there is no change, say so and stop — there is nothing to review.

### 2. Ask GLM 5.2 to review against the contract

Call Z.AI's chat completions API with the `glm-5.2` model, authenticated with `ZAI_API_KEY`. Send the diff and the test trees, and ask GLM 5.2 to review the work as an independent critic: does the change satisfy the test-tree contract, are there bugs or drift, does it honour the rules (KISS, YAGNI, no fake code, fail-fast, no comments), and what would it change?

```bash
REVIEW_INPUT=$(printf 'TEST TREES (the contract):\n\n%s\n\nDIFF (the completed work):\n\n%s\n' \
  "$(cat TEST_TREES.md)" "$(git diff HEAD)")

curl -sS -f -X POST "https://api.z.ai/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer $ZAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg input "$REVIEW_INPUT" '{
        model: "glm-5.2",
        messages: [
          { role: "system", content: "You are an independent code reviewer. Review the completed work against the test-tree contract. Surface bugs, drift from the trees, rule violations, and gaps. Be specific and concrete." },
          { role: "user", content: $input }
        ]
      }')" \
  | jq -r '.choices[0].message.content'
```

### 3. Surface the review

Present GLM 5.2's review to the user verbatim, attributed to GLM 5.2 so it is clear this is a second opinion from another model, not your own. The user decides what to act on; where the review finds drift or gaps, route them back through `change`, `sync`, or `tdd`.

## Failure is loud

If the review request fails — missing `ZAI_API_KEY`, an API error, a non-2xx response (`curl -f`), or empty content — surface the failure as an error and stop. Never fabricate a review, summarise the diff yourself and pass it off as GLM 5.2's, or report a second opinion you did not get. A missing review is an honest outcome; a fake one is not.
