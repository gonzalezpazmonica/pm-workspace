---
version_bump: patch
section: Fixed
---

### Fixed

- project-update: serialize SH03-aware jobs (mail/calendar/teams-chats) by alias to eliminate race on shared {alias}-cmd.json
- extract-teams-transcripts: guard CDP target=None and harden click_chat/click_transcript so a missing tab returns None instead of aborting the job

