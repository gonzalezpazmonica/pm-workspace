## SPEC-076 — PENDING_USER_INPUT Protocol (2026-06-24)

### Added
- `scripts/pending-user-input.py`: Async agent-to-human input request protocol
  - DB: `~/.savia/zeroclaw/pending/{session-id}.json` (dir auto-created)
  - `--create --session ID --question "text"` → creates/overwrites pending record
  - `--check --session ID` → exit 0 (answered), exit 1 (waiting), exit 2 (not found)
  - `--resolve --session ID --answer "text"` → writes answer + ts_resolved, status=answered
  - `--list` → lists all sessions with WAITING / ANSWERED grouping
  - SAVIA_PENDING_DIR env override for isolated testing
- `tests/scripts/test_pending_user_input.py`: 21 pytest tests

### Tests
- 21/21 passing — create writes file, check→1 no answer, resolve writes answer+ts,
  check→0 after resolve, list shows sessions, create overwrites, resolve nonexistent→error,
  required fields present, full CLI lifecycle create→check→resolve→check
