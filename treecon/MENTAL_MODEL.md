## Core Domain Identity

- treecon injects LSP-derived semantic context into the model's turn so it never explores code via shell tools to understand symbol relationships.
- Injection over tool use: pay tokens every turn, but never decide to look something up and never get it wrong.
- Pre-implementation stage: a folder and this mental model only — no manifest, hooks, or marketplace entry yet.

## World-to-Code Mapping

- Warm language servers → a long-lived LSP daemon on a unix socket, started at session start.
- Prompt symbols/paths → a prompt-time hook that queries the daemon and prints a compact context block to stdout (the injection channel).
- A symbol string → `workspace/symbol` candidates → `documentSymbol` + `references` + `callHierarchy/incomingCalls` for the top-N.
- Edited symbols (later) → a post-edit hook that refreshes context for touched symbols.

## Ubiquitous Language

- Injection — printing context to hook stdout so it enters the model's turn.
- LSP daemon — the warm, long-lived holder of language servers (tsserver, pyright, rust-analyzer, gopls, …).
- Resolution — turning prompt strings into `(file, line, char)` locations.
- Ranking — exact match, then proximity to recently-edited files, then definition kind.
- Token cap — the budget bounding the injected block.

## Bounded Contexts

- Daemon — language-server lifecycle and socket transport.
- Resolution & ranking — turning prompt tokens into ranked semantic context.
- Injection — the prompt-time hook that emits the context block.

## Invariants

- The daemon is long-lived; per-prompt LSP startup is too slow to tolerate.
- No-op cheaply when the prompt has no symbol-like tokens.
- The injected block is always token-capped.

## Decision Rationale

- Injection is chosen over tool use to remove a decision point and a failure mode — the model cannot forget to look or look wrong.
- A daemon (not per-prompt startup) is used because language-server warm-up otherwise dominates latency.

## Temporal View

- Session start: launch the daemon, warm the language servers.
- Each prompt: parse symbols/paths → query the daemon → inject ranked context (or cheap no-op).
- Later: refresh context for touched symbols after edits.
- Unresolved (open questions): the Codex prompt-time hook event, and the daemon socket convention on Codex.
