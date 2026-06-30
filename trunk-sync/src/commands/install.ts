import { execSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { getGitRoot, commandExists } from "../lib/git.js";

const REPO = "elimydlarz/claude-code-plugins";
const MARKETPLACE_NAME = "elimydlarz";

export function installCommand(args: string[]): void {
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

function installClaude(args: string[]): void {
  const scopeIdx = args.indexOf("--scope");
  const scope = scopeIdx !== -1 ? args[scopeIdx + 1] : "project";

  if (scope !== "project" && scope !== "user") {
    console.error(`Invalid scope: ${scope}. Must be "project" or "user".`);
    process.exit(1);
  }

  if (!getGitRoot()) {
    if (scope === "project") {
      console.warn(
        "Warning: not inside a git repository. trunk-sync needs git to auto-commit and sync."
      );
    }
  } else {
    try {
      execSync("git remote get-url origin", { stdio: "ignore" });
    } catch {
      // No remote is fine — hook will commit locally and skip pushing
    }
  }

  if (!commandExists("jq")) {
    console.error("jq is required. Install: brew install jq / apt install jq");
    process.exit(1);
  }

  if (!commandExists("claude")) {
    console.error(
      "Claude Code CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code"
    );
    process.exit(1);
  }

  console.log(`Adding ${MARKETPLACE_NAME} marketplace...`);
  try {
    execSync(
      `claude plugin marketplace add ${REPO} --scope ${scope}`,
      { stdio: "inherit" }
    );
  } catch {
    // May already be added — continue to install
  }

  console.log(`Updating ${MARKETPLACE_NAME} marketplace...`);
  try {
    execSync(
      `claude plugin marketplace update ${MARKETPLACE_NAME}`,
      { stdio: "inherit" }
    );
  } catch {
    // Non-fatal — install may still work with existing cache
  }

  console.log(`Installing trunk-sync plugin (scope: ${scope})...`);
  try {
    execSync(`claude plugin install trunk-sync@${MARKETPLACE_NAME} --scope ${scope}`, {
      stdio: "inherit",
    });
  } catch {
    console.error("Plugin installation failed.");
    process.exit(1);
  }

  console.log(`\ntrunk-sync installed successfully (scope: ${scope}).

Every file edit will now auto-commit and sync to the remote.
Works on main, on branches, or in worktrees.`);
}

function installCodex(): void {
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

interface CodexMarketplaceEntry {
  name: string;
  source:
    | { source: "local"; path: string }
    | { source: "url"; url: string; path?: string; ref?: string }
    | { source: "git-subdir"; url: string; path: string; ref?: string };
  policy: { installation: string; authentication: string };
  category: string;
}

interface CodexMarketplace {
  name: string;
  interface?: { displayName?: string };
  plugins: CodexMarketplaceEntry[];
}

function upsertCodexMarketplace(marketplacePath: string): void {
  let marketplace: CodexMarketplace;
  if (existsSync(marketplacePath)) {
    marketplace = JSON.parse(readFileSync(marketplacePath, "utf-8")) as CodexMarketplace;
    if (!marketplace.plugins) marketplace.plugins = [];
    if (!marketplace.name) marketplace.name = MARKETPLACE_NAME;
  } else {
    marketplace = {
      name: MARKETPLACE_NAME,
      interface: { displayName: "elimydlarz" },
      plugins: [],
    };
  }

  const entry: CodexMarketplaceEntry = {
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
  } else {
    marketplace.plugins.push(entry);
  }

  mkdirSync(dirname(marketplacePath), { recursive: true });
  writeFileSync(marketplacePath, JSON.stringify(marketplace, null, 2) + "\n");
}
