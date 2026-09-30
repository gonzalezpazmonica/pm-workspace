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
#   si existe ~/.savia-vaults/nextcloud.env (lo crea scripts/vaults-nextcloud-setup.sh),
#   se sourcea y se intenta subir el
#   tar.gz vía WebDAV. Si el host no responde, el backup local NO falla (se
#   loguea y se continúa). NUNCA se sube a proveedores de terceros; el destino
#   es infraestructura controlada por la operadora. Cero egress fuera de ello.
#
# SE-417 — Savia Files:
#   3. el almacén de ficheros (~/.savia-vaults/files, o SAVIA_FILES_HOME) en un tar.gz
#      por noche, sin locks ni temporales; las cúpulas cifradas viajan cifradas.
#   4. las claves (SAVIA_FILES_KEYS_HOME) por otro canal: con fichero de recuperación,
#      copia sellada (`savia-vaults files keys backup`) que solo abre quien tiene la frase;
#      sin él, copia local 0600 y AVISO en el log. Las claves NUNCA se suben salvo que
#      SAVIA_BACKUP_UPLOAD_KEYS=true (config local; por defecto no) y solo la copia sellada.
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
FILES_HOME="${SAVIA_FILES_HOME:-$HOME/.savia-vaults/files}"
KEYS_HOME="${SAVIA_FILES_KEYS_HOME:-$HOME/.savia-vaults/keys/files}"
KEYS_BACKUP_DIR="${BACKUP_DIR}/keys"
VAULTS_CLI="${SAVIA_VAULTS_CLI:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/projects/savia-vaults/dist/cli/index.js}"

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

# ── SE-417: almacén de Savia Files ───────────────────────────────────────
backup_files() {
  [[ -d "$FILES_HOME" ]] && [[ -n "$(ls -A "$FILES_HOME" 2>/dev/null)" ]] || { log "skip: savia-files (sin almacén)"; return 0; }
  local out="${BACKUP_DIR}/savia-files-${RUN_TS}.tar.gz"
  if tar -czf "$out" --exclude='files.lock' --exclude='.work' --exclude='*.tmp-*' \
       -C "$(dirname "$FILES_HOME")" "$(basename "$FILES_HOME")" >/dev/null 2>&1; then
    chmod 600 "$out"
    (cd "$BACKUP_DIR" && sha256sum "${out##*/}" > "${out##*/}.sha256") 2>/dev/null
    log "OK: savia-files -> $out"
  else
    log "FAIL: tar de savia-files"; return 1
  fi
}

# node para la CLI de savia-vaults: SAVIA_NODE, el del PATH o el más reciente de nvm (cron no carga nvm).
resolve_node() {
  if [[ -n "${SAVIA_NODE:-}" ]]; then echo "$SAVIA_NODE"; return; fi
  command -v node 2>/dev/null && return
  ls -1d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | sort -V | tail -1
}

# ── SE-417: claves por otro canal ────────────────────────────────────────
backup_keys() {
  [[ -d "$KEYS_HOME" ]] && [[ -n "$(ls -A "$KEYS_HOME" 2>/dev/null)" ]] || return 0
  mkdir -p "$KEYS_BACKUP_DIR" && chmod 700 "$KEYS_BACKUP_DIR"
  if [[ -f "$KEYS_HOME/recovery.pub" ]]; then
    local node out="${KEYS_BACKUP_DIR}/savia-keys-${RUN_TS}.sealed"
    node=$(resolve_node)
    if [[ -n "$node" ]] && SAVIA_FILES_KEYS_HOME="$KEYS_HOME" "$node" "$VAULTS_CLI" files keys backup --out "$out" >/dev/null 2>&1; then
      chmod 600 "$out"
      log "OK: claves selladas -> $out"
      return 0
    fi
    log "FAIL: copia sellada de claves (node=${node:-ninguno}); se hace copia local"
  fi
  local out="${KEYS_BACKUP_DIR}/savia-keys-${RUN_TS}.tar.gz"
  (umask 077 && tar -czf "$out" -C "$(dirname "$KEYS_HOME")" "$(basename "$KEYS_HOME")") >/dev/null 2>&1 || { log "FAIL: copia local de claves"; return 1; }
  chmod 600 "$out"
  log "AVISO: claves sin fichero de recuperación: copia solo local ($out). Si se pierde el disco, los ficheros cifrados son irrecuperables. Genera el fichero con: savia-vaults files keys export"
}

rotate_keys() {
  local to_delete
  to_delete=$(ls -1t "$KEYS_BACKUP_DIR"/savia-keys-* 2>/dev/null | tail -n +$((RETENTION + 1)))
  for f in $to_delete; do rm -f "$f"; log "rotate: borrado $f"; done
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
    backup_files || fail=1
    backup_keys || fail=1
    for d in "${DOMES[@]}"; do rotate "$d"; done
    rotate "savia-files"
    rotate_keys
    # después de generar los backups, intenta subir el último tar.gz de cada cúpula
    last_tar=""; d=""
    for d in "${DOMES[@]}"; do
      last_tar=$(ls -1t "${BACKUP_DIR}"/"${d}"-[0-9]*.tar.gz 2>/dev/null | head -1)
      [[ -n "$last_tar" ]] && nc_push "$last_tar"
    done
    last_tar=$(ls -1t "${BACKUP_DIR}"/savia-files-[0-9]*.tar.gz 2>/dev/null | head -1)
    [[ -n "$last_tar" ]] && nc_push "$last_tar"
    # Claves: solo la copia sellada y solo si se ha activado en la configuración local.
    if [[ "${SAVIA_BACKUP_UPLOAD_KEYS:-false}" == "true" ]]; then
      last_keys=$(ls -1t "$KEYS_BACKUP_DIR"/savia-keys-*.sealed 2>/dev/null | head -1)
      [[ -n "$last_keys" ]] && nc_push "$last_keys"
    fi
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
      echo "nextcloud: NO configurado (falta $NC_ENV o vars; configúralo con scripts/vaults-nextcloud-setup.sh)"; fail=1
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