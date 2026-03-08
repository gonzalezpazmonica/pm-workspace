# Savia Mobile — Android App

> Tu asistente de Project Management de IA, en tu bolsillo.

## Vision

Savia Mobile brings the full power of the pm-workspace AI assistant to Android devices, providing a native, intuitive interface for project managers who need to stay connected on the go — without requiring SSH, Termux, or VPN knowledge.

## Problem Statement

Today, using Savia from a mobile device requires: Termux + Tailscale VPN + SSH + tmux + Claude Code CLI. This technical barrier excludes 95% of potential users (PMs, team leads, executives) who would benefit from AI-assisted project management.

## Solution

A native Android app that:

1. **Connects to Savia** via Claude API (direct) or SSH tunnel (advanced)
2. **Provides mobile-optimized UI** for common PM operations
3. **Works offline** for read-only access to cached project data
4. **Syncs context** with the pm-workspace on the user's computer

## Architecture Options

| Approach | Pros | Cons |
|----------|------|------|
| **A: Claude API Direct** | No server needed, works anywhere | Requires API key, no local file access |
| **B: SSH Tunnel** | Full access to pm-workspace | Requires computer running, VPN setup |
| **C: Hybrid** | Best of both worlds | More complex to build |

**Recommended: Approach C (Hybrid)** — API-first for quick queries, SSH tunnel for full workspace operations.

## Tech Stack

- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Architecture**: MVVM + Clean Architecture
- **Networking**: Ktor (HTTP client) + JSch (SSH)
- **Local Storage**: Room (SQLite)
- **Auth**: Anthropic API key + optional SSH keypair
- **CI/CD**: GitHub Actions
- **Target**: Android 10+ (API 29+), ~90% device coverage

## MVP Scope (v1.0)

- Chat interface with Savia personality
- Quick actions: sprint status, PBI decomposition, risk scoring
- Workspace health dashboard (read-only)
- Offline cache for recent conversations
- Dark/light theme, bilingual (ES/EN)

## Status

**Phase**: Specification & Design
