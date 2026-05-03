# CLAUDE.md

## Mental Model

**treecon** injects LSP-derived semantic context into the model's turn so it does not need to explore code via shell tools to understand symbol relationships.

Injection over tool use: the model pays tokens every turn but never has to decide to look something up, and never gets it wrong.

### Architecture

- **Long-lived LSP daemon** — started on session start, holds language servers (tsserver, pyright, rust-analyzer, gopls, …) warm against the workspace, listens on a unix socket. Per-prompt LSP startup is too slow.
- **Prompt-time hook** — parses the user prompt for symbol-ish tokens and file paths, queries the daemon, prints a compact context block to stdout. Hook stdout is the injection channel.
- **Post-edit hook (later)** — after tool edits, refresh context for touched symbols.

### Resolution

LSP wants `(file, line, char)`; prompts give strings. Two-step:

1. `workspace/symbol "Foo"` → candidate locations
2. For top-N candidates: `documentSymbol` outline + `references` + `callHierarchy/incomingCalls`

Rank by: exact match, then proximity to recently-edited files, then definition kind. Token-cap the inject block.

No-op cheaply when the prompt has no symbol-like tokens.

### Open questions

- **Codex hook event for prompt-time injection.** Claude Code has `UserPromptSubmit`. Codex's equivalent needs verification against current Codex docs before committing to the manifest shape.
- **Daemon transport on Codex.** SessionStart hook lifecycle and env (`CLAUDE_PLUGIN_ROOT` is set) is known to work for both harnesses; socket path convention TBD.
