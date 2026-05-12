---
version_bump: minor
section: Added
---

### Added

- SH03 heartbeat IPC streaming orchestrator: per-job heartbeat protocol (`HEARTBEAT op=... phase=... processed=N/T elapsed=Xs`), hard caps per source (mail-:240s, calendar-:300s, teams-chats-:600s), stall detector (60s), term→kill kill chain, _dispatch_job router supporting both legacy run_one and new streaming run_one_streaming for SH03 jobs.

