import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { opencodeToolEventToHookInput } from "./lib/opencode-handlers.js";
const HOOK_ENTRY = join(dirname(fileURLToPath(import.meta.url)), "lib", "hook-entry.js");
const COMMIT_TOOLS = new Set(["edit", "write", "bash", "apply_patch"]);
/**
 * trunk-sync as an OpenCode plugin. Mirrors the Claude/Codex hook: after every
 * edit/write/bash/apply_patch it runs the same hook-entry pipeline that commits
 * and syncs to trunk. The model is tracked per session from chat.message so the
 * commit can record which of OpenCode's many models did the work.
 */
export const TrunkSyncPlugin = async ({ directory, client }) => {
    const modelBySession = new Map();
    return {
        "chat.message": async (input) => {
            if (input.model) {
                modelBySession.set(input.sessionID, `${input.model.providerID}/${input.model.modelID}`);
            }
        },
        "tool.execute.after": async (input) => {
            if (!COMMIT_TOOLS.has(input.tool))
                return;
            const model = modelBySession.get(input.sessionID) ?? null;
            const hookInput = opencodeToolEventToHookInput({
                tool: input.tool,
                sessionID: input.sessionID,
                args: (input.args ?? {}),
            }, model);
            const result = spawnSync("node", [HOOK_ENTRY], {
                input: JSON.stringify(hookInput),
                cwd: directory,
                encoding: "utf-8",
            });
            const feedback = (result.stderr || "").trim();
            if (feedback) {
                await client?.tui?.showToast?.({ message: feedback, variant: "info" }).catch(() => { });
            }
        },
    };
};
