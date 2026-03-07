# Changelog

All notable changes to PM-Workspace will be documented in this file.

## [2.32.0] — 2026-03-07

### Added — Era 61: Google Chat Notifier

Rich notifications for PM events via Google Chat webhooks. Card-formatted messages for sprint status, deployments, escalations, and standup summaries.

- **`/chat-setup`** — Guide webhook configuration and send test message.
- **`/chat-notify {type} {project}`** — Send formatted notification: sprint-status, deployment, escalation, standup, custom.
- **`google-chat-notifier` skill** — 5 message types with Google Chat card format. Integrates with scheduled-messaging platform adapters.

---

[2.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v2.32.0
