# Savia Monitor

Desktop control tower for orchestrating multiple Claude Code sessions in parallel.

## What it does

- **Sessions**: detects all active Claude Code instances, shows project, branch, agents and Shield status
- **Shield**: monitors 8 data protection layers in real-time
- **Git**: visualizes branches grouped by type, pending files, merge status, nidos
- **Activity**: real-time feed of tools, agents and security events

## Stack

- **Backend**: Rust (Tauri v2) — system tray, HTTP polling, session detection
- **Frontend**: Vue 3 + TypeScript + Pinia — reactive components, i18n ES/EN
- **Design**: glassmorphism with shared CSS variables from savia-web

## Requirements

- Node.js 18+
- Rust toolchain (rustup)
- MSVC Build Tools + Windows SDK (Windows) or gcc (Linux)

## Development

```bash
npm install
npm run tauri dev    # Start with hot reload
npm run test         # Unit tests (Vitest)
npx playwright test  # E2E tests
```

## Architecture

Savia Monitor detects Claude Code sessions by reading `~/.claude/sessions/*.json` and verifying PID liveness. Activity data comes from `~/.savia/live.log` (tools), `output/agent-lifecycle/lifecycle.jsonl` (agents) and `output/data-sovereignty-audit.jsonl` (Shield). HTTP polling every 5s checks the Shield daemon, Ollama and proxy.
