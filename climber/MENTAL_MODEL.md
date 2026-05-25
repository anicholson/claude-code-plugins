## Core Domain Identity

- Climber builds an autonomous clone that directs a Claude Code session the way the user does, so the user climbs a level of abstraction.
- The job splits into build time (mine transcripts → artefacts) and test time (the clone consumes artefacts).
- The clone codes directly — no dispatch layer; a Stop hook is the whole orchestration mechanism.
- Autonomy is the goal: the clone asks the user only when it genuinely cannot predict what they would do.

## World-to-Code Mapping

- Build time → `/climb` mines `~/.claude/projects/**/*.jsonl` → artefacts under `~/.claude/climber/`.
- Artefacts → `manual.md` (ambient rulebook), `antipatterns.md` (review-turn), `precedents.md` (predict-user), `lessons.md` (human review).
- Ambient rulebook → SessionStart hook `inject-manual.sh` injects `manual.md` each session.
- The goal → `./VISION.md`; the loop → Stop hook `drive-to-vision.sh` blocks turn-end until it is achieved.
- Test-time skills → `drive-to-vision`, `review-turn`, `predict-user`, `refactor-rulebook`.

## Ubiquitous Language

- Build time — all transcript mining; the `/climb` skill.
- Test time — the clone operating a session, consuming artefacts only.
- Clone — the autonomous operator of the session.
- Manual — the ambient rulebook injected at session start.
- VISION.md — the goal the clone drives toward; `Status: Achieved` ends the loop.
- Antipatterns / precedents / lessons — the consumable artefacts.
- Escalation — the clone ends a message with `?` to hand back to the user.

## Bounded Contexts

- Build time — mining and artefact generation (`/climb`).
- Test-time operation — the skills that consume artefacts.
- Orchestration — the Stop-hook loop driving toward VISION.md.
- Ambient context — the SessionStart manual injection.

## Invariants

- No skill ever touches raw transcripts at test time — only artefacts.
- All transcript work is `/climb` (build time).
- The Stop hook yields when the clone's last message ends with `?`, when VISION.md is absent, or when it is marked achieved.
- Artefacts grow by subtraction: tighten an existing line before appending.
- The user's voice is preserved — quote actual corrections, do not normalise.

## Decision Rationale

- The build/test split keeps expensive transcript mining out of the hot path; test time stays cheap and artefact-driven.
- The Stop hook is the entire orchestration because one re-firing loop is simpler than a dispatch layer.
- The manual is injected at SessionStart so the clone is ambient from turn one without the user pasting anything.
- Grow-by-subtraction prevents artefacts bloating into ignored walls of text.

## Temporal View

- Once: run `/climb` to populate `~/.claude/climber/`.
- Each session: SessionStart injects `manual.md`.
- Each turn: the Stop hook re-fires; while VISION.md is unachieved it directs `drive-to-vision` to do one turn's work.
- After non-trivial turns: `review-turn` audits against antipatterns.
- Before escalating: `predict-user` consults precedents.
- On learning: `refactor-rulebook` folds the lesson in by tightening.
