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
- **Windows**: MSVC Build Tools + Windows SDK
- **Linux**: WebKitGTK, GTK3, librsvg2 (see below)
- **macOS**: Xcode Command Line Tools

### Linux — system prerequisites

**Debian/Ubuntu:**
```bash
sudo apt install libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev \
                 librsvg2-dev build-essential curl wget file libssl-dev libxdo-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file \
                 libappindicator-gtk3-devel librsvg2-devel gtk3-devel
```

## Development

```bash
npm install
npm run tauri dev    # Start with hot reload
npm run test         # Unit tests (Vitest)
npx playwright test  # E2E tests
```

## Linux Build

Automated script that verifies environment, builds frontend and generates bundles:

```bash
# Full build (.deb + .rpm + .AppImage)
bash scripts/build-linux.sh

# Environment check only
bash scripts/build-linux.sh --check

# Single target
bash scripts/build-linux.sh --deb-only
bash scripts/build-linux.sh --appimage-only
bash scripts/build-linux.sh --rpm-only
```

Artifacts are generated in `$CARGO_TARGET_DIR/release/bundle/` (default `~/.savia/cargo-target/savia-monitor/release/bundle/`).

## Architecture

Savia Monitor detects Claude Code sessions by reading `~/.claude/sessions/*.json` and verifying PID liveness. Activity data comes from `~/.savia/live.log` (tools), `output/agent-lifecycle/lifecycle.jsonl` (agents) and `output/data-sovereignty-audit.jsonl` (Shield). HTTP polling every 5s checks the Shield daemon, Ollama and proxy.
