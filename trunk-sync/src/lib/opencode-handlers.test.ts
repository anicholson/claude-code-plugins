import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { opencodeToolEventToHookInput } from "./opencode-handlers.js";

describe("opencodeToolEventToHookInput", () => {
  it("takes session_id from the OpenCode event's sessionID", () => {
    const input = opencodeToolEventToHookInput(
      { tool: "edit", sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
      null,
    );
    assert.equal(input.session_id, "ses_abc123");
  });

  it("sets agent to opencode", () => {
    const input = opencodeToolEventToHookInput(
      { tool: "edit", sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
      null,
    );
    assert.equal(input.agent, "opencode");
  });

  it("sets transcript_path to null, since OpenCode has no single transcript file", () => {
    const input = opencodeToolEventToHookInput(
      { tool: "edit", sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
      null,
    );
    assert.equal(input.transcript_path, null);
  });

  describe("when an edit or write tool event carries a file path in its args", () => {
    it("maps tool_name to the OpenCode tool name and file_path to that path", () => {
      for (const tool of ["edit", "write"]) {
        const input = opencodeToolEventToHookInput(
          { tool, sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
          null,
        );
        assert.equal(input.tool_name, tool);
        assert.equal(input.tool_input.file_path, "/repo/src/main.ts");
      }
    });
  });

  describe("when a bash or apply_patch tool event carries no file path", () => {
    it("sets no file_path, so the commit falls back to scanning modified tracked files", () => {
      for (const tool of ["bash", "apply_patch"]) {
        const input = opencodeToolEventToHookInput(
          { tool, sessionID: "ses_abc123", args: { command: "ls" } },
          null,
        );
        assert.equal(input.tool_name, tool);
        assert.equal(input.tool_input.file_path, undefined);
      }
    });
  });

  describe("when the active model for the session is known", () => {
    it("sets model to its provider/model identifier", () => {
      const input = opencodeToolEventToHookInput(
        { tool: "edit", sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
        "anthropic/claude-sonnet-4-6",
      );
      assert.equal(input.model, "anthropic/claude-sonnet-4-6");
    });
  });

  describe("when the active model for the session is unknown", () => {
    it("sets model to null", () => {
      const input = opencodeToolEventToHookInput(
        { tool: "edit", sessionID: "ses_abc123", args: { filePath: "/repo/src/main.ts" } },
        null,
      );
      assert.equal(input.model, null);
    });
  });
});
