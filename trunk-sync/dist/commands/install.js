import { execSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { getGitRoot, commandExists } from "../lib/git.js";
const REPO = "elimydlarz/claude-code-plugins";
const MARKETPLACE_NAME = "elimydlarz";
export function installCommand(args) {
    if (args.includes("--help") || args.includes("-h")) {
        console.log(`Usage: trunk-sync install [--client claude|codex|opencode] [--scope user|project]

Installs the trunk-sync plugin for the chosen agent CLI.

Options:
  --client <name>  Target CLI: "claude" (default), "codex", or "opencode"
  --scope <scope>  (claude only) Installation scope: "project" (default) or "user"
                   project — active in this repo only (.claude/plugins.json)
                   user    — active in all repos (~/.claude/plugins.json)
  -h, --help       Show this help message`);
        return;
    }
    const clientIdx = args.indexOf("--client");
    const client = clientIdx !== -1 ? args[clientIdx + 1] : "claude";
    if (client === "claude") {
        installClaude(args);
        return;
    }
    if (client === "codex") {
        installCodex();
        return;
    }
    if (client === "opencode") {
        installOpencode();
        return;
    }
    console.error(`Invalid client: ${client}. Must be "claude", "codex", or "opencode".`);
    process.exit(1);
}
function installClaude(args) {
    const scopeIdx = args.indexOf("--scope");
    const scope = scopeIdx !== -1 ? args[scopeIdx + 1] : "project";
    if (scope !== "project" && scope !== "user") {
        console.error(`Invalid scope: ${scope}. Must be "project" or "user".`);
        process.exit(1);
    }
    if (!getGitRoot()) {
        if (scope === "project") {
            console.warn("Warning: not inside a git repository. trunk-sync needs git to auto-commit and sync.");
        }
    }
    else {
        try {
            execSync("git remote get-url origin", { stdio: "ignore" });
        }
        catch {
            // No remote is fine — hook will commit locally and skip pushing
        }
    }
    if (!commandExists("jq")) {
        console.error("jq is required. Install: brew install jq / apt install jq");
        process.exit(1);
    }
    if (!commandExists("claude")) {
        console.error("Claude Code CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code");
        process.exit(1);
    }
    console.log(`Adding ${MARKETPLACE_NAME} marketplace...`);
    try {
        execSync(`claude plugin marketplace add ${REPO} --scope ${scope}`, { stdio: "inherit" });
    }
    catch {
        // May already be added — continue to install
    }
    console.log(`Updating ${MARKETPLACE_NAME} marketplace...`);
    try {
        execSync(`claude plugin marketplace update ${MARKETPLACE_NAME}`, { stdio: "inherit" });
    }
    catch {
        // Non-fatal — install may still work with existing cache
    }
    console.log(`Installing trunk-sync plugin (scope: ${scope})...`);
    try {
        execSync(`claude plugin install trunk-sync@${MARKETPLACE_NAME} --scope ${scope}`, {
            stdio: "inherit",
        });
    }
    catch {
        console.error("Plugin installation failed.");
        process.exit(1);
    }
    console.log(`\ntrunk-sync installed successfully (scope: ${scope}).

Every file edit will now auto-commit and sync to the remote.
Works on main, on branches, or in worktrees.`);
}
function installOpencode() {
    const projectRoot = getGitRoot() ?? process.cwd();
    if (!getGitRoot()) {
        console.warn("Warning: not inside a git repository. trunk-sync needs git to auto-commit and sync.");
    }
    const sourceDir = join(dirname(fileURLToPath(import.meta.url)), "..", "..", ".opencode");
    const targetDir = join(projectRoot, ".opencode");
    // plugin file is trunk-sync's own — copy it verbatim
    mkdirSync(join(targetDir, "plugin"), { recursive: true });
    copyFileSync(join(sourceDir, "plugin", "trunk-sync.ts"), join(targetDir, "plugin", "trunk-sync.ts"));
    mergeOpencodePackageJson(join(sourceDir, "package.json"), join(targetDir, "package.json"));
    mergeOpencodeConfig(join(sourceDir, "opencode.json"), join(targetDir, "opencode.json"));
    console.log(`Installed trunk-sync into ${targetDir}.

OpenCode will auto-install @dotnich/trunk-sync on its next start.
Every edit then commits with Agent: opencode and the active Model.`);
}
function mergeOpencodePackageJson(sourcePath, targetPath) {
    const source = JSON.parse(readFileSync(sourcePath, "utf-8"));
    const target = existsSync(targetPath)
        ? JSON.parse(readFileSync(targetPath, "utf-8"))
        : {};
    target.dependencies = { ...target.dependencies, ...source.dependencies };
    writeFileSync(targetPath, JSON.stringify(target, null, 2) + "\n");
}
function mergeOpencodeConfig(sourcePath, targetPath) {
    const source = JSON.parse(readFileSync(sourcePath, "utf-8"));
    const target = existsSync(targetPath)
        ? JSON.parse(readFileSync(targetPath, "utf-8"))
        : {};
    const merged = { ...target, ...source };
    merged.permission = {
        ...target.permission,
        ...source.permission,
        bash: { ...target.permission?.bash, ...source.permission?.bash },
    };
    writeFileSync(targetPath, JSON.stringify(merged, null, 2) + "\n");
}
function installCodex() {
    if (!commandExists("jq")) {
        console.error("jq is required. Install: brew install jq / apt install jq");
        process.exit(1);
    }
    const marketplacePath = join(homedir(), ".agents", "plugins", "marketplace.json");
    upsertCodexMarketplace(marketplacePath);
    console.log(`Updated ${marketplacePath}.

In Codex, run:
  /plugins install trunk-sync

Codex will load the plugin from ${REPO} on its next session.`);
}
function upsertCodexMarketplace(marketplacePath) {
    let marketplace;
    if (existsSync(marketplacePath)) {
        marketplace = JSON.parse(readFileSync(marketplacePath, "utf-8"));
        if (!marketplace.plugins)
            marketplace.plugins = [];
        if (!marketplace.name)
            marketplace.name = MARKETPLACE_NAME;
    }
    else {
        marketplace = {
            name: MARKETPLACE_NAME,
            interface: { displayName: "elimydlarz" },
            plugins: [],
        };
    }
    const entry = {
        name: "trunk-sync",
        source: {
            source: "git-subdir",
            url: `https://github.com/${REPO}.git`,
            path: "./trunk-sync",
        },
        policy: { installation: "AVAILABLE", authentication: "ON_INSTALL" },
        category: "Productivity",
    };
    const existingIdx = marketplace.plugins.findIndex((p) => p.name === "trunk-sync");
    if (existingIdx >= 0) {
        marketplace.plugins[existingIdx] = entry;
    }
    else {
        marketplace.plugins.push(entry);
    }
    mkdirSync(dirname(marketplacePath), { recursive: true });
    writeFileSync(marketplacePath, JSON.stringify(marketplace, null, 2) + "\n");
}
