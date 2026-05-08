---
name: tolaria-open
description: Open Tolaria desktop knowledge base on the Savia workspace (or specified path)
---

# /tolaria-open — Open Tolaria visual knowledge base

Opens [Tolaria](https://github.com/refactoringhq/tolaria) desktop app on the
Savia workspace (default: `~/claude`) for visual navigation of specs, rules,
roadmap, commands, skills, and agents.

## Usage

```
/tolaria-open                    # opens ~/claude (default Savia workspace)
/tolaria-open ~/claude           # explicit path
/tolaria-open ~/projects/foo     # specific project
```

## What it does

1. Detects Tolaria binary (`tolaria` command, or fallback paths)
2. Launches Tolaria with the specified vault path
3. Tolaria reads markdown + YAML frontmatter files as-is (zero migration)

## Prerequisites

Tolaria must be installed. Download from:
https://refactoringhq.github.io/tolaria/download/

Linux: AppImage or .deb package
macOS: `brew install --cask tolaria`
Windows: .exe installer

## Notes

Tolaria is an external desktop app. This command is a convenience wrapper.
The files remain plain markdown — Tolaria is a viewer, not a transformer.
