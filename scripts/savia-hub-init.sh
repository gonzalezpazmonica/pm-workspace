#!/usr/bin/env bash
# savia-hub-init.sh — Inicializa el repositorio local de SaviaHub
# Uso: bash scripts/savia-hub-init.sh [--remote URL] [--path PATH]
# Exit: 0 creado o ya existente · 1 uso · 3 no se pudo clonar · 4 fallo de git
set -euo pipefail

SAVIA_HUB_PATH="${SAVIA_HUB_PATH:-$HOME/.savia-hub}"
SAVIA_HUB_REMOTE="${SAVIA_HUB_REMOTE:-}"
LOCAL_ONLY=(.savia-hub-config.md .sync-queue.jsonl)

die() { echo "ERROR: $2" >&2; exit "$1"; }

usage() {
  cat <<'EOF'
Uso: savia-hub-init.sh [--remote URL] [--path PATH]

  --remote URL   Clona un SaviaHub existente (si está vacío, siembra la estructura)
  --path PATH    Ubicación (por defecto: ~/.savia-hub)
  --help         Esta ayuda

Variables de entorno: SAVIA_HUB_PATH (= --path), SAVIA_HUB_REMOTE (= --remote)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote|--path)
      [[ $# -ge 2 && -n "$2" ]] || die 1 "$1 requiere un valor"
      if [[ "$1" == --remote ]]; then SAVIA_HUB_REMOTE="$2"; else SAVIA_HUB_PATH="$2"; fi
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die 1 "opción desconocida: $1 (ver --help)" ;;
  esac
done

# Ficheros locales fuera de git aunque el remote no traiga .gitignore:
# .git/info/exclude nunca se sube, así la config (con la URL del remote) no se filtra.
ensure_local_excludes() {
  local ex="$SAVIA_HUB_PATH/.git/info/exclude" f
  mkdir -p "$(dirname "$ex")"; touch "$ex"
  for f in "${LOCAL_ONLY[@]}"; do grep -qxF "$f" "$ex" || echo "$f" >> "$ex"; done
}

# Plantillas: solo crea lo que falte (re-ejecutar no pisa nada).
seed_structure() {
  cd "$SAVIA_HUB_PATH"
  mkdir -p company clients users
  [ -f users/.gitkeep ] || : > users/.gitkeep
  [ -f company/identity.md ] || cat > company/identity.md <<'EOF'
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
  [ -f company/org-chart.md ] || cat > company/org-chart.md <<'EOF'
---
last_updated: ""
---
## Estructura Organizativa
| Equipo | Lead | Miembros | Proyectos |
|--------|------|----------|-----------|
| | | | |
EOF
  [ -f clients/.index.md ] || cat > clients/.index.md <<'EOF'
# Índice de Clientes

(Auto-mantenido por SaviaHub. No editar manualmente.)

| Slug | Nombre | Sector | Proyectos | Última edición |
|------|--------|--------|-----------|----------------|
EOF
  [ -f .gitignore ] || printf '# SaviaHub: config local (nunca se sube)\n%s\n%s\n' "${LOCAL_ONLY[@]}" > .gitignore
}

write_config() {
  local cfg="$SAVIA_HUB_PATH/.savia-hub-config.md"
  [ -f "$cfg" ] && return 0
  cat > "$cfg" <<EOF
---
version: 1
created: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
remote_url: "$SAVIA_HUB_REMOTE"
flight_mode: false
last_sync: null
sync_interval_seconds: 3600
auto_sync_on_change: true
---
EOF
}

echo "SaviaHub — repositorio compartido de conocimiento"

# Ya existe = repo git con al menos un commit. Un .git sin commits es un init
# interrumpido y se completa en vez de darlo por bueno.
if git -C "$SAVIA_HUB_PATH" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  echo "SaviaHub ya existe en: $SAVIA_HUB_PATH (sin cambios)"
  echo "  Estado: bash scripts/savia-hub-sync.sh status"
  exit 0
fi

if [ -n "$SAVIA_HUB_REMOTE" ] && [ ! -d "$SAVIA_HUB_PATH/.git" ]; then
  echo "Clonando desde: $SAVIA_HUB_REMOTE"
  GIT_TERMINAL_PROMPT=0 git clone -q "$SAVIA_HUB_REMOTE" "$SAVIA_HUB_PATH" 2>&1 \
    || die 3 "No se pudo clonar $SAVIA_HUB_REMOTE (sin red, sin permisos o remote inexistente). No se ha creado nada."
else
  mkdir -p "$SAVIA_HUB_PATH"
  if [ ! -d "$SAVIA_HUB_PATH/.git" ]; then
    git -C "$SAVIA_HUB_PATH" init -q
    git -C "$SAVIA_HUB_PATH" symbolic-ref HEAD refs/heads/main   # rama documentada
  fi
fi

ensure_local_excludes
write_config

if git -C "$SAVIA_HUB_PATH" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  # Clon de un hub con contenido: se verifica la estructura, no se toca.
  for d in company clients users; do
    [ -d "$SAVIA_HUB_PATH/$d" ] || echo "AVISO: el hub clonado no tiene $d/"
  done
else
  # Hub nuevo o remote vacío: estructura + commit local. No se sube nada:
  # el push exige confirmación (savia-hub-sync.sh push --yes).
  seed_structure
  git -C "$SAVIA_HUB_PATH" add -A
  git -C "$SAVIA_HUB_PATH" commit -q -m "[savia-hub] init: repositorio creado" \
    || die 4 "git commit falló (¿falta user.name/user.email?). Re-ejecuta init tras corregirlo."
  echo "Estructura creada y commit inicial hecho (solo local)"
fi

echo "Ruta:   $SAVIA_HUB_PATH"
if [ -n "$SAVIA_HUB_REMOTE" ]; then
  echo "Remote: $SAVIA_HUB_REMOTE (nada subido; usa savia-hub-sync.sh push)"
else
  echo "Modo:   solo local (añade remote con git remote add origin URL)"
fi
