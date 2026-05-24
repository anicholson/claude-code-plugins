#!/usr/bin/env bash
INPUT=$(cat)

if printf '%s' "$INPUT" | jq -e '.stop_hook_active' 2>/dev/null | grep -q true; then
  exit 0
fi

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  LAST_CHAR=$(jq -rs '
    ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // "")
    | sub("[[:space:]]+$"; "")
    | if length > 0 then .[-1:] else "" end
  ' "$TRANSCRIPT" 2>/dev/null)
  if [ "$LAST_CHAR" = "?" ]; then
    exit 0
  fi
fi

if [ ! -f MENTAL_MODEL.md ]; then
  echo "MENTAL MODEL: MENTAL_MODEL.md is missing at the project root. Create it with these seven H2 sections in order: Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View. Each section starts with a one-line placeholder describing what belongs there until real content lands." >&2
else
  echo "MENTAL MODEL: Did this task reveal any knowledge NOT already described in documentation, tests, and code? Default is no change. If a change is warranted: name which of the seven sections it belongs to (Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View); if none fits, it is not part of the mental model; prefer tightening an existing line over adding a new one; state what is true, not what to avoid; when the target section is at its cap, displace or merge an existing item rather than appending." >&2
fi

echo "TEST TREES: Have test trees and implementation drifted apart? If so, propose solutions." >&2
echo "CLAUDE.md: Has CLAUDE.md content drifted from reality? If so, update it." >&2

if [ ! -f README.md ]; then
  echo "README: README.md is missing at the project root. Create it so consumers can understand what the project is, how to install it, how to configure it, and how to use it." >&2
else
  echo "README: Is the README out of date now? It should tell consumers what the project is, how to install it, how to configure it, and how to use it. If anything is stale or wrong, update it." >&2
fi

echo "CHANGE IMAGE: Did this task change the project? If so, invoke gpt2 image to generate an image representing the change the task made. Choose what the image depicts from the nature of the change, its important details, and its intended audience, and surface those choices for the user to review." >&2

echo "If nothing needs attention, reply 0." >&2
exit 2
