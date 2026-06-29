import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync } from "node:child_process";
import type { Timecard } from "../lib/hook-types.js";

function runProgress(args: string, cwd: string): { stdout: string; stderr: string; exitCode: number } {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  try {
    const stdout = execSync(`node "${cliPath}" progress ${args}`, { encoding: "utf-8", cwd }).trim();
    return { stdout, stderr: "", exitCode: 0 };
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; status?: number };
    return { stdout: (err.stdout || "").trim(), stderr: (err.stderr || "").trim(), exitCode: err.status ?? 1 };
  }
}

function timecardPath(repo: string, id: string): string {
  return join(repo, ".trunk-sync", "timeclock", `${id}.json`);
}

function readCard(repo: string, id: string): Timecard {
  return JSON.parse(readFileSync(timecardPath(repo, id), "utf-8")) as Timecard;
}

describe("progress command", () => {
  let repo: string;
  beforeEach(() => {
    repo = mkdtempSync(join(tmpdir(), "progress-test-"));
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("prints usage with --help", () => {
    const r = runProgress("--help", repo);
    assert.equal(r.exitCode, 0);
    assert.match(r.stdout, /progress/);
  });

  it("sets lastStep and remainingSteps on the matching timecard, preserving other fields", () => {
    const id = "sess-1";
    mkdirSync(join(repo, ".trunk-sync", "timeclock"), { recursive: true });
    const original: Timecard = {
      sessionId: id, pid: 4242, hostname: "host-a", clockedInAt: "2026-01-01T00:00:00.000Z",
      lastActiveAt: "2026-01-01T00:00:00.000Z", branch: "feat", task: "build the thing",
      lastStep: null, remainingSteps: null,
    };
    writeFileSync(timecardPath(repo, id), JSON.stringify(original, null, 2) + "\n");

    const r = runProgress(`${id} --last "wrote the parser" --next "wire the CLI, add tests"`, repo);
    assert.equal(r.exitCode, 0);

    const card = readCard(repo, id);
    assert.equal(card.lastStep, "wrote the parser");
    assert.equal(card.remainingSteps, "wire the CLI, add tests");
    assert.equal(card.clockedInAt, "2026-01-01T00:00:00.000Z");
    assert.equal(card.task, "build the thing");
    assert.equal(card.pid, 4242);
    assert.equal(card.branch, "feat");
  });

  it("creates a timecard carrying the progress when none exists yet", () => {
    const id = "sess-2";
    const r = runProgress(`${id} --last "first step" --next "second step"`, repo);
    assert.equal(r.exitCode, 0);
    assert.ok(existsSync(timecardPath(repo, id)));
    const card = readCard(repo, id);
    assert.equal(card.sessionId, id);
    assert.equal(card.lastStep, "first step");
    assert.equal(card.remainingSteps, "second step");
  });

  it("exits 1 with usage when the session id is missing", () => {
    const r = runProgress(`--last "x" --next "y"`, repo);
    assert.equal(r.exitCode, 1);
    assert.match(r.stderr + r.stdout, /usage|session/i);
  });
});
