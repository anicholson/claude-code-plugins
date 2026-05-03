import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { rewindCodexRollout } from "./seance-codex.js";

const NEW_ID = "11111111-2222-3333-4444-555555555555";

function meta(ts: string, id = "old-uuid", cwd = "/old/cwd"): string {
  return JSON.stringify({
    timestamp: ts,
    type: "session_meta",
    payload: { id, cwd, originator: "test" },
  });
}

function event(ts: string): string {
  return JSON.stringify({ timestamp: ts, type: "event_msg", payload: { kind: "x" } });
}

describe("rewindCodexRollout", () => {
  it("drops lines whose timestamp is later than the commit timestamp", () => {
    const result = rewindCodexRollout({
      rolloutLines: [
        meta("2026-05-03T10:00:00.000Z"),
        event("2026-05-03T10:01:00.000Z"),
        event("2026-05-03T10:05:00.000Z"),
        event("2026-05-03T10:09:00.000Z"),
      ],
      commitTimestamp: "2026-05-03T10:05:00+00:00",
      worktreePath: "/work/tree",
      newId: NEW_ID,
      homeDir: "/home/u",
    });
    assert.ok(result);
    assert.equal(result.lines.length, 3);
  });

  it("rewrites the SessionMeta line's payload.id with the new UUID", () => {
    const result = rewindCodexRollout({
      rolloutLines: [meta("2026-05-03T10:00:00.000Z")],
      commitTimestamp: "2026-05-03T10:05:00+00:00",
      worktreePath: "/work/tree",
      newId: NEW_ID,
      homeDir: "/home/u",
    });
    assert.ok(result);
    assert.equal(JSON.parse(result.lines[0]).payload.id, NEW_ID);
  });

  it("rewrites the SessionMeta line's payload.cwd with the worktree path", () => {
    const result = rewindCodexRollout({
      rolloutLines: [meta("2026-05-03T10:00:00.000Z")],
      commitTimestamp: "2026-05-03T10:05:00+00:00",
      worktreePath: "/work/tree",
      newId: NEW_ID,
      homeDir: "/home/u",
    });
    assert.ok(result);
    assert.equal(JSON.parse(result.lines[0]).payload.cwd, "/work/tree");
  });

  it("returns a target path under ~/.codex/sessions/<Y>/<M>/<D>/rollout-<ts>-<newuuid>.jsonl using the commit date", () => {
    const result = rewindCodexRollout({
      rolloutLines: [meta("2026-05-03T10:00:00.000Z")],
      commitTimestamp: "2026-05-03T10:05:00+00:00",
      worktreePath: "/work/tree",
      newId: NEW_ID,
      homeDir: "/home/u",
    });
    assert.ok(result);
    assert.match(
      result.targetPath,
      new RegExp(`^/home/u/\\.codex/sessions/2026/05/03/rollout-2026-05-03T.*-${NEW_ID}\\.jsonl$`),
    );
  });

  it("returns null if no line's timestamp is at or before the commit timestamp", () => {
    const result = rewindCodexRollout({
      rolloutLines: [event("2026-05-03T11:00:00.000Z")],
      commitTimestamp: "2026-05-03T10:00:00+00:00",
      worktreePath: "/work/tree",
      newId: NEW_ID,
      homeDir: "/home/u",
    });
    assert.equal(result, null);
  });
});
