# Secret Rotation Policy

Rotation strategy for all secrets in Savia infrastructure to minimize breach impact.

## Secrets & Frequency

| Secret | Type | Interval | Storage |
|--------|------|----------|---------|
| Bridge Token | API Token | 90 days | `$HOME/.azure/bridge-token` |
| GitHub PAT | Token | 90 days | `$HOME/.github/pat` |
| API Keys | OAuth 2.0 | 365 days | `.env.{ENV}` |
| JWT Secret | Signing Key | 365 days | `.env.{ENV}` |
| DB Passphrase | Database Auth | 365 days | `.env.{ENV}` |

## Rotation Procedures

**Bridge Token**: Generate in admin console → test staging → update file → revoke old

**GitHub PAT**: Generate new PAT → preserve scopes → update file → delete old from GitHub

**API Keys**: Request from provider → update `.env.DEV|PRE|PRO` → verify connectivity → revoke after 7 days

**JWT Secret**: `openssl rand -hex 32` → add versioned to `.env.{ENV}` → test staging → remove old after 30 days

**DB Passphrase**: Coordinate with DBA → generate new → update `.env.PRO` → verify backups

## Automation

Calendar reminders 1 week before due date. Audit log maintained at `.claude/audit/secret-rotations.log`.

Grace periods: Tokens 7 days, Keys 7 days, Database 30 days, JWT 30 days.
