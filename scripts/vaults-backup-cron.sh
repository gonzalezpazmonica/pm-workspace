#!/usr/bin/env bash
# vaults-backup-cron.sh — Backup automático de las cúpulas SaviaVaults (CRIT-001).
#
# Restaura el mecanismo que dejó de funcionar (el cron apuntaba a este fichero
# que ya no existía). Genera, para cada cúpula de vaults/:
#   1. git bundle (repo completo, portable, restaurable con git clone),
#   2. tar.gz comprimido,
#   3. sha256sum sidecar de ambos.
# Rotación: mantiene BACKUP_RETENTION copias por cúpula (por defecto 30).
#
# Destino Nextcloud (WebDAV propio, infraestructura de la operadora — CRIT-001):
#   si existe ~/.savia-vaults/nextcloud.env, se sourcea y se intenta subir el
#   tar.gz vía WebDAV. Si el host no responde, el backup local NO falla (se
#   loguea y se continúa). NUNCA se sube a proveedores de terceros; el destino
#   es infraestructura controlada por la operadora. Cero egress fuera de ello.
#
# Uso:
#   bash scripts/vaults-backup-cron.sh                  # backup + rotación + log
#   bash scripts/vaults-backup-cron.sh --verify         # verifica integridad
#   bash scripts/vaults-backup-cron.sh --nextcloud-test # prueba conexión (sin subir)
#   bash scripts/vaults-backup-cron.sh --status         # estado
#
# Salida: 0 OK · 1 fallo
set -uo pipefail

VAULTS_DIR="${SAVIA_VAULTS_DIR:-$HOME/savia/vaults}"
BACKUP_DIR="${SAVIA_VAULTS_BACKUP_DIR:-${HOME}/.savia-vaults/backups}"
RETENTION="${SAVIA_BACKUP_RETENTION:-30}"
LOG_DIR="${HOME}/.savia-vaults"
LOG_FILE="${LOG_DIR}/vaults-backup.log"
NC_ENV="${HOME}/.savia-vaults/nextcloud.env"
RUN_TS=$(date -u +%Y-%m-%dT%H-%M-%S)

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# ── Cargar credenciales Nextcloud (WebDAV propio) si existen ─────────────
load_nc_env() {
  if [[ -f "$NC_ENV" ]]; then
    # shellcheck disable=SC1090
    set +u
    set -a; source "$NC_ENV" 2>/dev/null; set +a
    set -u
  fi
}

# Envío WebDAV del tar.gz (best-effort: no rompe el backup local si falla)
nc_push() {
  local file="$1"
  [[ -n "${NEXTCLOUD_URL:-}" && -n "${NEXTCLOUD_USER:-}" && -n "${NEXTCLOUD_PASS:-}" ]] || { log "nextcloud: no config (env ausente)"; return 0; }
  curl -s -m 30 -o /dev/null -w "%{http_code}" -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASS" \
    -X PUT --data-binary "@$file" \
    "${NEXTCLOUD_URL}/remote.php/dav/files/${NEXTCLOUD_USER}/SaviaVaults/$(basename "$file")" 2>/dev/null \
    | grep -qE "20[0-9]" && log "nextcloud: OK $(basename "$file")" || log "nextcloud: FALLO subida $(basename "$file") (¿host offline?)"
}

# Estrutura: projects/savia-vaults/dist/cli/... el backup del servidor vive en
# vaults/<dome>; cada dome es un repo git propio.
DOMES=("SaviaLabs" "SaviaLearning" "savia-docs")

backup_one() {
  local dome="$1"
  local src="${VAULTS_DIR}/${dome}"
  [[ -d "$src" ]] || { log "skip: $dome (sin dir)"; return 0; }

  local ok=1
  # 1) git bundle (repo completo)
  if [[ -d "$src/.git" ]]; then
    if git -C "$src" bundle create "${BACKUP_DIR}/${dome}-repo-${RUN_TS}.bundle" --all >/dev/null 2>&1; then
      (cd "$BACKUP_DIR" && sha256sum "${dome}-repo-${RUN_TS}.bundle" > "${dome}-repo-${RUN_TS}.bundle.sha256") 2>/dev/null
      ok=0
    else
      log "FAIL: bundle de $dome"
    fi
  fi

  # 2) tar.gz (directorio, incluye .git + worktree)
  if tar -czf "${BACKUP_DIR}/${dome}-${RUN_TS}.tar.gz" -C "${VAULTS_DIR}" "${dome}" >/dev/null 2>&1; then
    (cd "$BACKUP_DIR" && sha256sum "${dome}-${RUN_TS}.tar.gz" > "${dome}-${RUN_TS}.tar.gz.sha256") 2>/dev/null
    ok=0
  else
    log "FAIL: tar de $dome"
  fi

  [[ $ok -eq 0 ]] && log "OK: $dome -> ${BACKUP_DIR}/${dome}[-repo]-${RUN_TS}.{tar.gz,bundle}"
  return $ok
}

rotate() {
  local prefix="$1"
  # reduce a RETENTION copias por cúpula mirando los .tar.gz (los más recientes primero)
  local to_delete
  to_delete=$(ls -1t "${BACKUP_DIR}"/"${prefix}"-[0-9]*.tar.gz 2>/dev/null | tail -n +$((RETENTION + 1)))
  if [[ -n "$to_delete" ]]; then
    for f in $to_delete; do
      local base="${f%.tar.gz}"
      rm -f "$f" "$base.sha256" 2>/dev/null
      log "rotate: borrado $f"
    done
  fi
}

fail=0
case "${1:-run}" in
  run)
    load_nc_env
    for d in "${DOMES[@]}"; do backup_one "$d" || fail=1; done
    for d in "${DOMES[@]}"; do rotate "$d"; done
    # después de generar los backups, intenta subir el último tar.gz de cada cúpula
    last_tar=""; d=""
    for d in "${DOMES[@]}"; do
      last_tar=$(ls -1t "${BACKUP_DIR}"/"${d}"-[0-9]*.tar.gz 2>/dev/null | head -1)
      [[ -n "$last_tar" ]] && nc_push "$last_tar"
    done
    log "--- run completo (fail=$fail) ---"
    ;;
  --verify)
    # verifica el último tar.gz de cada cúpula
    last_tar=""; d=""
    for d in "${DOMES[@]}"; do
      last_tar=$(ls -1t "${BACKUP_DIR}"/"${d}"-[0-9]*.tar.gz 2>/dev/null | head -1)
      if [[ -n "$last_tar" ]]; then
        if gzip -t "$last_tar" 2>/dev/null && (cd "$BACKUP_DIR" && sha256sum -c "${last_tar##*/}.sha256" >/dev/null 2>&1); then
          echo "OK  $d: $last_tar"
        else
          echo "BAD $d: $last_tar"; fail=1
        fi
      else
        echo "NONE $d"
      fi
    done
    ;;
  --nextcloud-test)
    load_nc_env
    if [[ -z "${NEXTCLOUD_URL:-}" || -z "${NEXTCLOUD_USER:-}" ]]; then
      echo "nextcloud: NO configurado (falta $NC_ENV o vars)"; fail=1
    else
      echo "nextcloud: URL=$NEXTCLOUD_URL USER=$NEXTCLOUD_USER (pass oculta)"
      code=$(curl -s -m 15 -o /dev/null -w "%{http_code}" -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASS" \
        "${NEXTCLOUD_URL}/remote.php/webdav/" 2>/dev/null)
      echo "nextcloud: PROPFIND webdav -> HTTP $code"
      case "$code" in
        200|207) echo "nextcloud: OK — conexión operativa" ;;
        401|403) echo "nextcloud: credenciales rechazadas"; fail=1 ;;
        000)     echo "nextcloud: host sin respuesta (¿Lima offline?)"; fail=1 ;;
        *)       echo "nextcloud: respuesta inesperada"; fail=1 ;;
      esac
    fi
    ;;

  --status)
    echo "Backup dir: $BACKUP_DIR"
    echo "Retention: $RETENTION"
    echo "Último log:"
    tail -5 "$LOG_FILE" 2>/dev/null
    ;;
  *) echo "uso: $0 [run|--verify|--status]"; exit 2 ;;
esac

exit $fail