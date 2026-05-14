# Test Trees

This file is the contract for repo-root infrastructure (publish scripts, marketplace plumbing). Each `###` subsection below is one tree, written in EARS syntax, reified by exactly one bats file under `test/`.

Per-product behaviour lives in each plugin's own `TEST_TREES.md`:
- [trunk-sync/TEST_TREES.md](trunk-sync/TEST_TREES.md)
- [contree/TEST_TREES.md](contree/TEST_TREES.md)
- [climber/TEST_TREES.md](climber/TEST_TREES.md)
- `openclaw-notifier/CLAUDE.md` (trees inline under `## Requirements`)

### System: release-notes (src: scripts/release-notes.sh; unit: test/release-notes.bats)

```
System: release-notes
  if invoked without a plugin or version
    then exits non-zero with a usage message
  when invoked with a plugin and version
    then gathers commits from the previous tag of the plugin's series to HEAD
    and considers only commits that touched the plugin's directory
    and drops version-bump commits matching "vX.Y.Z" or "<plugin> vX.Y.Z"
    and drops commits prefixed "build:"
    and drops the literal commit "trunk sync noise"
    and collapses commits sharing an "auto(<id>):" session id to the newest, stripping the prefix
    and prints one markdown bullet line per surviving commit, trimming trailing whitespace and colons
  where the plugin is trunk-sync
    then commits under trunk-sync/dist/ are excluded from the range
  if no prior tag of the plugin's series exists
    then the entire history is considered
```
