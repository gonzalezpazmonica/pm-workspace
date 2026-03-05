#!/usr/bin/env bash
# savia-hub-init.sh — Initialize SaviaHub local repository
# Usage: bash scripts/savia-hub-init.sh [--remote URL] [--path PATH]
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
SAVIA_HUB_PATH="${SAVIA_HUB_PATH:-$HOME/.savia-hub}"
SAVIA_HUB_REMOTE=""
SHOW_HELP=false

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)  SAVIA_HUB_REMOTE="$2"; shift 2 ;;
    --path)    SAVIA_HUB_PATH="$2"; shift 2 ;;
    --help|-h) SHOW_HELP=true; shift ;;
    *) echo "❌ Unknown option: $1"; exit 1 ;;
  esac
done

if $SHOW_HELP; then
  echo "Usage: savia-hub-init.sh [--remote URL] [--path PATH]"
  echo ""
  echo "Options:"
  echo "  --remote URL   Clone from existing SaviaHub remote"
  echo "  --path PATH    Custom location (default: ~/.savia-hub)"
  echo "  --help         Show this help"
  echo ""
  echo "Environment variables:"
  echo "  SAVIA_HUB_PATH    Same as --path"
  echo "  SAVIA_HUB_REMOTE  Same as --remote"
  exit 0
fi

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "  🦉 SaviaHub — Shared Knowledge Repository"
echo "  ══════════════════════════════════════════"
echo ""

# ── Check if already exists ──────────────────────────────────────────────────
if [ -d "$SAVIA_HUB_PATH/.git" ]; then
  echo "⚠️  SaviaHub already exists at: $SAVIA_HUB_PATH"
  echo "   Use /savia-hub status to check current state."
  echo "   Use /savia-hub pull to update from remote."
  exit 0
fi

# ── Clone or init ────────────────────────────────────────────────────────────
if [ -n "$SAVIA_HUB_REMOTE" ]; then
  echo "🔗 Cloning from remote: $SAVIA_HUB_REMOTE"
  git clone "$SAVIA_HUB_REMOTE" "$SAVIA_HUB_PATH"
  echo "✅ Cloned to: $SAVIA_HUB_PATH"
else
  echo "📁 Creating local SaviaHub at: $SAVIA_HUB_PATH"
  mkdir -p "$SAVIA_HUB_PATH"
  cd "$SAVIA_HUB_PATH"
  git init --quiet

  # ── Create directory structure ───────────────────────────────────────────
  mkdir -p company clients users

  # ── Company identity template ────────────────────────────────────────────
  cat > company/identity.md << 'EOF'
---
name: ""
sector: ""
founded: ""
location: ""
---

## Identidad de la Empresa

(Completar con `/savia-hub init` o `/context-interview`)

### Convenciones
- Idioma principal:
- Zona horaria:
- Metodología:
EOF

  # ── Org chart template ───────────────────────────────────────────────────
  cat > company/org-chart.md << 'EOF'
---
last_updated: ""
---
## Estructura Organizativa
| Equipo | Lead | Miembros | Proyectos |
|--------|------|----------|-----------|
| | | | |
EOF

  # ── Clients index ────────────────────────────────────────────────────────
  cat > clients/.index.md << 'EOF'
# Índice de Clientes

(Auto-mantenido por SaviaHub. No editar manualmente.)

| Slug | Nombre | Sector | Proyectos | Última edición |
|------|--------|--------|-----------|----------------|
EOF

  # ── .gitignore ───────────────────────────────────────────────────────────
  cat > .gitignore << 'EOF'
# SaviaHub local config (never push)
.savia-hub-config.md
.sync-queue.jsonl
EOF

  echo "✅ Directory structure created"
fi

# ── Create local config ───────────────────────────────────────────────────
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$SAVIA_HUB_PATH/.savia-hub-config.md" << EOF
---
version: 1
created: "$CREATED_AT"
remote_url: "$SAVIA_HUB_REMOTE"
flight_mode: false
last_sync: null
sync_interval_seconds: 3600
auto_sync_on_change: true
---
EOF

# ── Initial commit (local only) ──────────────────────────────────────────
if [ -z "$SAVIA_HUB_REMOTE" ]; then
  cd "$SAVIA_HUB_PATH"
  git add -A
  git commit --quiet -m "[savia-hub] init: local repository created"
  echo "✅ Initial commit created"
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "  🦉 SaviaHub initialized successfully!"
echo "  ──────────────────────────────────────"
echo "  Path:   $SAVIA_HUB_PATH"
if [ -n "$SAVIA_HUB_REMOTE" ]; then
  echo "  Remote: $SAVIA_HUB_REMOTE"
else
  echo "  Mode:   Local only (add remote later with git remote add)"
fi
echo "  Next: /savia-hub status | /client-create {name} (Era 31)"
echo ""
