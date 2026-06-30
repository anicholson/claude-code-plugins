/**
 * Map an OpenCode tool event onto the harness-agnostic HookInput so the existing
 * planHook/executePlan core drives the commit. The harness is known here, so the
 * agent is stamped explicitly rather than inferred from the tool name.
 */
export function opencodeToolEventToHookInput(event, model) {
    const filePath = typeof event.args?.filePath === "string" ? event.args.filePath : null;
    return {
        tool_name: event.tool,
        tool_input: filePath ? { file_path: filePath } : {},
        session_id: event.sessionID,
        transcript_path: null,
        agent: "opencode",
        model,
    };
}
