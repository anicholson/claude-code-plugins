---
name: workflow
description: "The full arc from idea to verified working software — set expected behaviour, identify gaps, close them. Runs without pausing."
---

# Workflow

Carries an idea through the full arc: from intent to contract to verified implementation. Sets expected behaviour, identifies where reality diverges, and closes every gap — without pausing for review.

## When to Use

- When the user shares an idea and wants it built
- When the user wants the full cycle without manual phase transitions
- As an alternative to running `change`, `sync`, and `tdd` individually

## Process

### 1. CHANGE — set expected behaviour

Run the `change` skill process: understand the behaviour, identify the consumer, write or modify test trees in `## Test Trees`, decompose across layers and positions. **Outside-in: for a new user-visible flow the Journey tree is the only tree to write up front** (a capability under an existing journey starts as that capability's System tree). System and inner trees (Use-case, Domain, Port, Adapter) get added in step 3 (TDD) as the failing journey/functional test pulls them into being — not pre-specified here.

Do not pause for alignment — proceed directly.

### 2. SYNC — identify gaps and cruft

Run the `sync` skill process: load the test trees, inventory the implementation, compare both directions, resolve drift, identify gaps.

Do not pause to present gaps — proceed directly to implementation.

### 3. TDD — close gaps

For each gap identified by sync, run the `tdd` skill process: confirm test tree, RED functional, RED unit, implement, GREEN unit, GREEN functional, refactor. Repeat for each `when/then` path.

Run mutation testing at the end.

### 4. DONE — intent and implementation are one

All test trees in `## Test Trees` should now have passing tests and working implementation.
