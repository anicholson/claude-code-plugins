# climber

Build an autonomous clone that directs a Claude Code session the way you do, so you can climb up a level of abstraction completely.

## Test Trees

See [TEST_TREES.md](TEST_TREES.md) — the definition of functional and cross-functional requirements.

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View.

## Skills

- `climb` — build-time mining + artefact generation. Trigger: `/climb` or equivalent requests.
- `drive-to-vision` — does one turn of work toward `./VISION.md`, per the manual's "How you work toward a goal" section. Trigger: the Stop hook directs the clone to invoke it; also on clone-session start with an existing VISION.md.
- `review-turn` — audits the clone's own most recent turn against `antipatterns.md`; returns a verdict. Trigger: after every non-trivial turn.
- `predict-user` — consults `precedents.md` before the clone asks the user anything; returns a prediction + confidence. Trigger: before escalating or when choosing between two valid paths.
- `refactor-rulebook` — enforces tighten-existing-line over append when folding a new lesson into one of the artefacts. Trigger: when the clone learns something new.

## Principles

- **Autonomy is the goal.** The clone asks the user only when it is deeply unsure what they would do. If it can predict from context, prior decisions, or the rulebook, it acts.
- **Build vs test time.** All transcript work is `/climb`. Test-time skills consume artefacts.
- **Grow by subtraction.** Artefacts tighten existing lines before appending. Files that grow without subtracting are a signal to re-run `/climb`.
- **Preserve the user's voice.** Quote their actual corrections; don't normalise.

## Installation

```
/plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install climber@elimydlarz --scope project
```

Recommend `--scope project` so climber only activates where you want it. Then run `/climb` once to populate `~/.claude/climber/`.

## Publishing

```
pnpm publish:climber patch   # or minor, major
```
