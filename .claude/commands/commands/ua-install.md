---
name: ua-install
description: Install or update the Understand-Anything knowledge graph plugin
---

# /ua-install — Install Understand-Anything

Installs [Understand-Anything](https://github.com/Lum1104/Understand-Anything),
a codebase knowledge graph plugin compatible with OpenCode.

## Usage

```
/ua-install            # first-time install
/ua-install --force     # reinstall/update
```

## What it does

1. Clones the UA repository to `~/.opencode/understand-anything/`
2. Installs dependencies (pnpm or npm)
3. Creates symlinks for skills in `~/.agents/skills/`

## Prerequisites

- Node.js 20+
- pnpm (preferred) or npm
