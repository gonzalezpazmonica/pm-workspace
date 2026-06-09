---
version_bump: patch
section: Fixed
---

### Fixed

- opencode.json: remove unknown schema fields (_hooks_doc, _comment, websearch, subtask) that caused startup failure
- savia-bridge.py: probe nvm versioned bin paths in find_claude_cli() so bridge resolves claude binary under nvm

