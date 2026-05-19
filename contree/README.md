# contree

Test trees as living requirements. Combines test-driven development with automatic requirements synchronisation — your test trees in `TEST_TREES.md` ARE the specification, always up to date. Tests are layered by hexagonal seam — Domain, Use-case, Adapter, System. The **System layer is max-validity functional testing**: real driven adapters at the highest tolerable realism, with a single expansive journey as the floor when breadth at that realism is unaffordable. Inner layers — Domain, Use-case, Adapter — emerge only when a failing functional test demands them. In-memory adapters keep Use-case tests fast; a shared port contract suite keeps in-memory and real adapters honest.

## What it does

**Test trees become requirements.** Instead of separate requirement documents and test code, contree puts `when/then` test trees directly in your project's `TEST_TREES.md` at the project root. Every test you write reifies exactly one tree.

Five skills:

- **`/contree:setup`** — Configures your test framework with tree reporters and generates initial test trees from your existing codebase (or plans). Run once per project.
- **`/contree:change`** — Write or modify test trees in `TEST_TREES.md` before any code is written. Auto-triggers when planning behaviour changes.
- **`/contree:tdd`** — Auto-triggers when implementing behaviour. Enforces outside-in TDD: confirms tree exists → failing System test → TDD inward through Driving adapter → Use-case → Domain / port contract → Driven adapter, one failing test at a time.
- **`/contree:sync`** — Audits test trees against implementation, finds gaps and drift, then TDDs any gaps closed.
- **`/contree:workflow`** — Runs change → sync → tdd end-to-end without pausing.

Plus a **stop hook** that prompts Claude to keep test trees, mental model, CLAUDE.md, and README.md current after every response — and yields silently when Claude ends with a question, so questions to you aren't buried. A **self-care hook** that reminds you to look at something 20 feet away for 20 seconds every 20 minutes (20-20-20 rule). A **session-start header** with skill directions, coding rules, and a random **pressure phrase** ("My boss is watching — make it count", "I'll tip you $200 for a perfect answer"), so the agent starts every session knowing when to reach for each skill and under a little stage-light.

## Install

**Claude Code:**

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install contree@susu-eng --scope project
```

**Codex CLI** — install via `/plugins` in the Codex CLI, pointing at this repository. Skills run by default; hooks require enabling codex's under-development `plugin_hooks` feature: `codex features enable plugin_hooks`. Codex sets `CLAUDE_PLUGIN_ROOT` in hook command env so the existing scripts work unchanged.

## How it works

1. Run `/contree:setup` — sets up test framework, generates test trees in `TEST_TREES.md`
2. When you plan a behaviour change, `/contree:change` writes or modifies test trees first
3. `/contree:tdd` auto-triggers during implementation — outside-in TDD against test trees
4. The stop hook keeps `CLAUDE.md` and `README.md` current after every response
5. Run `/contree:sync` periodically to verify completeness, or `/contree:workflow` for the full cycle

## Test tree format

Trees in `TEST_TREES.md` look like this:

A slice is described by a few small trees, one per hexagonal seam. For a bookmarks feature:

```markdown
### canonicaliseUrl (Domain)

canonicaliseUrl (src: src/features/bookmarks/domain/canonicalise-url.ts; unit: src/features/bookmarks/domain/canonicalise-url.domain.test.ts)
  canonicaliseUrl
    when the host contains mixed case
      then the host is lower-cased
    when the path has a trailing slash
      then the trailing slash is stripped
    when the URL uses the scheme's default port
      then the port is removed
    if the input cannot be parsed as a URL
      then a ParseError is thrown

### createBookmark (Use-case)

createBookmark (src: src/features/bookmarks/use-cases/create-bookmark.ts; unit: src/features/bookmarks/use-cases/create-bookmark.usecase.test.ts)
  createBookmark
    when called with a valid URL for an authenticated user
      then the URL is canonicalised via the Domain
      and the bookmark is saved through the BookmarkStore port
      and the saved bookmark is returned
      when a bookmark with the same canonical URL already exists for the user
        then the existing bookmark is returned
        and the store is not written to
    if canonicalisation fails
      then a ValidationError is raised before the store is touched

### CreateBookmark (System)

CreateBookmark (src: src/features/bookmarks/system/create-bookmark.ts; functional: test/system/create-bookmark.system.test.ts)
  when an authenticated user submits a bookmark with a valid URL
    then the bookmark is persisted against their library
    and the canonicalised URL is returned to the caller
  if the caller is not authenticated
    then the request is rejected before the store is touched
```

Domain and Use-case trees are code-shaped — the top-level describe is the function itself, and every path is an observable branch. System trees describe the slice at its outer seam in consumer vocabulary. Causal nesting (the duplicate-URL case under successful persistence) keeps dependent behaviour attached to the outcome it depends on.

Each behavioural unit gets its own tree — slice (System), use-case, port contract, adapter, domain object. Every tree names its coverage in parenthesised semicolon-separated labelled pairs on the tree-name line. The categories are `src`, `unit`, `integration`, `functional`. Gaps are declared explicitly: `none` for a category that is expected but uncovered (so readers and `sync` spot it); categories that are genuinely not applicable are omitted. At Domain, Use-case, and Port-contract, trees are code-shaped: top-level describes are the unit's functions/methods and every path is an observable branch. At Adapter and System, trees describe observable behaviour at the seam using consumer vocabulary — principles, not enumerated cases. Every test file's describe/it hierarchy mirrors its tree verbatim.

## Supported languages

Setup configures tree reporters, test runners, and mutation testing for:

| Language | Tree reporter | Mutation testing |
|---|---|---|
| JavaScript/TypeScript | Vitest, Jest, Mocha | Stryker |
| Python | pytest + pytest-spec | mutmut |
| Ruby | RSpec | mutant |
| Java/Kotlin | JUnit 5 + Gradle/Maven | PIT (pitest) |
| PHP | PHPUnit | Infection |
| C#/.NET | dotnet test | Stryker.NET |
| Go | gotestsum (flat) | go-mutesting (experimental) |
| Rust | cargo nextest (flat) | cargo-mutants |
| Elixir | ExUnit (flat) | — |
| Shell/Bash | Bats (flat) | — |
| Swift | Swift Testing (flat) | — |

Languages marked "flat" don't support nested test output natively — contree uses the best available option and is honest about the limitation.

## Dependencies

- `jq` on the host system (for the stop hook)
