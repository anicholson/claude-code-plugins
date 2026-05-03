import { join } from "node:path";

interface RewindOpts {
  rolloutLines: string[];
  commitTimestamp: string;
  worktreePath: string;
  newId: string;
  homeDir: string;
}

interface RewindResult {
  lines: string[];
  targetPath: string;
}

export function rewindCodexRollout(opts: RewindOpts): RewindResult | null {
  const cutoff = new Date(opts.commitTimestamp).getTime() + 999;
  const kept: string[] = [];
  for (const raw of opts.rolloutLines) {
    let obj: { timestamp?: string; type?: string; payload?: Record<string, unknown> };
    try {
      obj = JSON.parse(raw);
    } catch {
      continue;
    }
    if (!obj.timestamp) continue;
    if (new Date(obj.timestamp).getTime() > cutoff) continue;
    if (obj.type === "session_meta" && obj.payload) {
      obj.payload.id = opts.newId;
      obj.payload.cwd = opts.worktreePath;
    }
    kept.push(JSON.stringify(obj));
  }
  if (kept.length === 0) return null;

  const commitDate = new Date(opts.commitTimestamp);
  const y = commitDate.getUTCFullYear();
  const m = String(commitDate.getUTCMonth() + 1).padStart(2, "0");
  const d = String(commitDate.getUTCDate()).padStart(2, "0");
  const tsForName = commitDate.toISOString().replace(/[:.]/g, "-").replace(/-\d+Z$/, "Z").replace("Z", "");
  const filename = `rollout-${tsForName}-${opts.newId}.jsonl`;
  const targetPath = join(opts.homeDir, ".codex", "sessions", String(y), m, d, filename);
  return { lines: kept, targetPath };
}
