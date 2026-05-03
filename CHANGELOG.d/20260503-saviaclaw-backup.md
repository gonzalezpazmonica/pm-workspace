## 6.14.1 — SaviaClaw daily memory backup (2026-05-03)

### Added
- scripts/saviaclaw-backup.sh: daily zip of critical Savia memory files + email via Gmail SMTP
- scripts/saviaclaw-backup.service + .timer: systemd timer daily at 22:30, keeps last 7 backups
