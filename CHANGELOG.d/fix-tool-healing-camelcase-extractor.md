---
version_bump: patch
section: Fixed
---

### Fixed

- Tool-healing guard no longer false-blocks read/write/edit on OpenCode v1.14 — extractFilePath/extractContent now recognize camelCase (filePath, newString) in addition to legacy snake_case (file_path, new_string). Resolves SPEC-TOOL-HEALING-FIX.

