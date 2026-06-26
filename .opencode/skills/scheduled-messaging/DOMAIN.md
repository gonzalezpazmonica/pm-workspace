# Scheduled Messaging — Domain Context

## Why this skill exists

Team async communication via scheduled messages (standups, blockers, deployments) replaces email ping-pong and meeting overload. Scheduled messages are templated, recurring, sent to Slack/Telegram/Teams at fixed times. This skill orchestrates setup, template management, and delivery across 5+ messaging platforms.

## Domain concepts

- **Scheduled Task** — Recurring message: cron expression + platform + template + recipients
- **Template** — Pre-filled message structure with variable substitution (e.g., {{velocity}}, {{blockers}})
- **Platform Adapter** — Platform-specific code: Slack webhook, Telegram bot, Teams connector, etc.
- **Delivery Window** — Time-of-day + timezone for message send
- **Result Sink** — Where to capture task output: Slack thread, Telegram chat, email

## Business rules it implements

- **RN-MSG-01**: Scheduled message must have template (never freeform)
- **RN-MSG-02**: All scheduled tasks must be logged for audit
- **RN-MSG-03**: Delivery failure must alert on-call (not silently drop)
- **RN-MSG-04**: Max 1 standup message per channel per day (prevent spam)

## Relationship to other skills

**Upstream:** None (messaging is notifications of project events)
**Downstream:** `reporting` generates content for standup/burndown templates
**Parallel:** Works with `sprint-management` to send standup reminders

## Key decisions

- **Wizard-guided setup** — Don't expect users to write cron + API keys. Interactive 5-step setup.
- **Template library** — Pre-built: standup, blockers, burndown, deploy, security alerts
- **Platform abstraction** — One skill, 5 adapters. Add new platform via adapter plugin.
