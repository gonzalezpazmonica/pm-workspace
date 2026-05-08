# Tolaria — Savia Workspace Visualization

> Tolaria is a desktop markdown knowledge base app (refactoringhq, 8.8k stars)
> adopted as the visual interface for Savia's Context As Code.

## Quick Start

### 1. Install Tolaria

**Linux (AppImage):**
```bash
# Download latest release
wget https://github.com/refactoringhq/tolaria/releases/latest/download/Tolaria.AppImage
chmod +x Tolaria.AppImage
sudo mv Tolaria.AppImage /usr/local/bin/tolaria
```

**macOS:**
```bash
brew install --cask tolaria
```

**From source (if binary unavailable):**
```bash
git clone https://github.com/refactoringhq/tolaria
cd tolaria
pnpm install
pnpm tauri build  # produces binary in src-tauri/target/release/
```

### 2. Open Savia workspace

```bash
# From Savia CLI:
/tolaria-open

# Or directly:
tolaria ~/claude
```

The first time Tolaria opens the workspace, it creates `.tolaria/` directory
for local config. This directory is gitignored — it never enters the repo.

### 3. Navigate your Context As Code

Tolaria reads the workspace as flat files organized by directory:

| Directory | Content | Tolaria type | Color |
|-----------|---------|-------------|-------|
| `docs/rules/` | Rules (25+) | `rule` | Red |
| `docs/specs/` | Specs (~85) | `spec` | Blue |
| `docs/propuestas/` | Proposals | `proposal` | Yellow |
| `docs/ROADMAP.md` | Roadmap | `roadmap` | Purple |
| `.opencode/commands/` | Commands (535) | `command` | Orange |
| `.opencode/skills/` | Skills (92) | `skill` | Green |
| `.opencode/agents/` | Agents (70) | `agent` | Indigo |
| `CHANGELOG.md` | Changelog | `changelog` | Gray |

Use **Cmd/Ctrl + K** (command palette) to search across all notes.
Use **Cmd/Ctrl + P** to quick-open any file.

## Workflow Patterns

### Navigate specs

1. Open command palette (Cmd+K)
2. Type spec name or keyword
3. Tolaria shows matching files instantly
4. Click to open in editor

### Edit a spec

1. Navigate to the spec file
2. Edit markdown directly in Tolaria's editor
3. Save — changes go to disk immediately
4. Git will detect the change (Tolaria is just a markdown editor)

### Browse rules

1. Filter by type `rule` in the sidebar
2. See all rules grouped by category
3. Open `radical-honesty.md` or any rule for reference

### Search across everything

The command palette does full-text search across all markdown files.
Type any term ("sprint", "auditoria", "DeepSeek") and get results from
specs, rules, roadmap, and commands simultaneously.

## MCP Server (Advanced)

Tolaria includes an MCP server that exposes the vault to AI agents:

```bash
# Start MCP server on port 3456
tolaria mcp --port 3456 ~/claude
```

Savia/OpenCode can query the vault via MCP for:
- Semantic search across specs and rules
- Reading specific files by path
- Listing files by type

This is optional. Savia already reads files directly from disk.
The MCP server is useful when you want Savia to search the vault
without loading the full context into the LLM.

## Principles

- **Files remain plain markdown.** Tolaria reads them as-is. No migration format.
- **Tolaria is a viewer, not a dependency.** If you stop using it, nothing breaks.
- **Git continues to work.** Tolaria uses git under the hood for version history.
- **Offline first.** Works without internet. Your data stays on your machine.
- **Zero lock-in.** Close Tolaria, open any text editor — same files, same format.
