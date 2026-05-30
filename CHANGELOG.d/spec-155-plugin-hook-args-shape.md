---
version_bump: patch
section: Fixed
---

### Fixed

- SPEC-155 [CRITICAL]: align plugin hook signature with OpenCode v1.14+ contract. Pre-fix, all 12 guards read input.args (undefined in real runtime) instead of output.args, operating on empty data = security theater. Symptom: spurious BLOCKED [tool-healing]: read called with empty file_path on valid tool calls. Helpers now prefer output.args with retro-compat fallback to input.args. 4 golden tests added with real v1.14 shape.

