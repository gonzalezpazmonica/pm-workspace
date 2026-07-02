---
name: worktree-setup
description: >
  Configurar git worktree para implementación paralela de agentes SDD.
  Automatiza creación, configuración y limpieza de worktrees.
agent: commit-guardian
tier: extended
---

# /worktree-setup

Crea y gestiona git worktrees para implementación paralela de agentes SDD.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  🌳 Worktree Setup                   ║
╚══════════════════════════════════════╝
```

### 2. Prerequisitos

- ✅/❌ Git repository
- ✅/❌ No uncommitted changes en main worktree
- ✅/❌ Branch base actualizada

### 3. Crear worktree

Parámetro: `{spec-id}` — ID de la spec para la que se crea el worktree

```bash
BRANCH="feature/sdd-${SPEC_ID}"
WORKTREE_DIR="../worktrees/${SPEC_ID}"
git worktree add "$WORKTREE_DIR" -b "$BRANCH"
```

### 4. Configurar worktree

- Copiar configuración local necesaria (`.env`, `config.local/`)
- Crear symlink a `node_modules` o `.venv` si existe
- Verificar que el proyecto compila/funciona

### 5. Listar worktrees activos

```bash
git worktree list
```

Mostrar directorio, rama y estado de cada worktree.

### 6. Limpiar worktrees completados

```bash
git worktree remove "$WORKTREE_DIR" --force
git branch -d "$BRANCH"
```

### 7. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Worktree Setup — Completo       ║
╚══════════════════════════════════════╝
📂 Worktree: {WORKTREE_DIR}
🌿 Rama: {BRANCH}
⚡ /compact
```

