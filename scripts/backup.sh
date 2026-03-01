#!/bin/bash
# backup.sh — Backup cifrado de datos locales a NextCloud/GDrive
# Uso: bash scripts/backup.sh {now|restore|auto-on|auto-off|status}
#
# Cifra y sube perfiles, configs, PATs a NextCloud (WebDAV) o Google Drive.
# Rotación: máx 7 backups.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"
CONFIG_DIR="$HOME/.pm-workspace"
BACKUP_CONFIG="$CONFIG_DIR/backup-config"
BACKUP_DIR="$CONFIG_DIR/backups"
MAX_BACKUPS=7

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# ── Config helpers ──────────────────────────────────────────────────
ensure_config() {
  mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
  if [ ! -f "$BACKUP_CONFIG" ]; then
    printf "auto_backup=false\nlast_backup=0\ncloud_type=none\nnextcloud_url=\nnextcloud_user=\n" > "$BACKUP_CONFIG"
  fi
}

read_config() {
  local key="$1"
  grep -oP "${key}=\\K.*" "$BACKUP_CONFIG" 2>/dev/null || echo ""
}

write_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$BACKUP_CONFIG" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$BACKUP_CONFIG"
  else
    echo "${key}=${value}" >> "$BACKUP_CONFIG"
  fi
}

# ── Qué respaldar ──────────────────────────────────────────────────
get_backup_paths() {
  local paths=()

  # Perfiles de usuario activo
  local active_user="$WORKSPACE_DIR/.claude/profiles/active-user.md"
  if [ -f "$active_user" ]; then
    paths+=("$active_user")
    local slug
    slug=$(grep -oP 'active_slug:\s*"\K[^"]+' "$active_user" 2>/dev/null || echo "")
    if [ -n "$slug" ] && [ -d "$WORKSPACE_DIR/.claude/profiles/users/$slug" ]; then
      paths+=("$WORKSPACE_DIR/.claude/profiles/users/$slug")
    fi
  fi

  # Config local
  [ -f "$WORKSPACE_DIR/CLAUDE.local.md" ] && paths+=("$WORKSPACE_DIR/CLAUDE.local.md")
  [ -f "$WORKSPACE_DIR/decision-log.md" ] && paths+=("$WORKSPACE_DIR/decision-log.md")
  [ -f "$WORKSPACE_DIR/.claude/rules/pm-config.local.md" ] && paths+=("$WORKSPACE_DIR/.claude/rules/pm-config.local.md")

  # PAT (opcional)
  [ -f "$HOME/.azure/devops-pat" ] && paths+=("$HOME/.azure/devops-pat")

  # Update config
  [ -f "$CONFIG_DIR/update-config" ] && paths+=("$CONFIG_DIR/update-config")

  echo "${paths[@]}"
}

# ── Cifrar ──────────────────────────────────────────────────────────
do_encrypt() {
  local source_dir="$1"
  local output_file="$2"
  local passphrase="$3"

  tar czf - -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -pass "pass:$passphrase" -out "$output_file" 2>/dev/null

  if [ -f "$output_file" ]; then
    log_ok "Cifrado: $(basename "$output_file") ($(du -h "$output_file" | cut -f1))"
    return 0
  else
    log_error "Error al cifrar"
    return 1
  fi
}

# ── Descifrar ─────────────────────────────────────────────────────
do_decrypt() {
  local input_file="$1"
  local output_dir="$2"
  local passphrase="$3"

  mkdir -p "$output_dir"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -pass "pass:$passphrase" -in "$input_file" 2>/dev/null | \
    tar xzf - -C "$output_dir" 2>/dev/null

  if [ $? -eq 0 ]; then
    log_ok "Descifrado en: $output_dir"
    return 0
  else
    log_error "Error al descifrar (¿passphrase incorrecta?)"
    return 1
  fi
}

# ── Subir a NextCloud (WebDAV) ──────────────────────────────────────
upload_nextcloud() {
  local file="$1"
  local nc_url
  nc_url=$(read_config "nextcloud_url")
  local nc_user
  nc_user=$(read_config "nextcloud_user")
  local nc_pass
  nc_pass=$(read_config "nextcloud_pass")

  if [ -z "$nc_url" ] || [ -z "$nc_user" ]; then
    log_error "NextCloud no configurado. Ejecuta: backup.sh config nextcloud URL USER"
    return 1
  fi

  local remote_path="$nc_url/remote.php/dav/files/$nc_user/pm-workspace-backups/$(basename "$file")"
  log_info "Subiendo a NextCloud: $(basename "$file")..."

  # Crear directorio si no existe
  curl -s -u "$nc_user:$nc_pass" -X MKCOL \
    "$nc_url/remote.php/dav/files/$nc_user/pm-workspace-backups/" 2>/dev/null || true

  curl -s -u "$nc_user:$nc_pass" -T "$file" "$remote_path" 2>/dev/null
  if [ $? -eq 0 ]; then
    log_ok "Subido a NextCloud"
  else
    log_error "Error al subir a NextCloud"
  fi
}

# ── Rotación ────────────────────────────────────────────────────────
rotate_backups() {
  local count
  count=$(find "$BACKUP_DIR" -name "pm-backup-*.enc" -type f 2>/dev/null | wc -l)
  if [ "$count" -gt "$MAX_BACKUPS" ]; then
    local to_delete=$((count - MAX_BACKUPS))
    find "$BACKUP_DIR" -name "pm-backup-*.enc" -type f 2>/dev/null | \
      sort | head -n "$to_delete" | while read -r f; do
        rm -f "$f"
        log_info "Rotación: eliminado $(basename "$f")"
      done
  fi
}

# ── Backup ahora ───────────────────────────────────────────────────
do_now() {
  ensure_config

  log_info "Preparando backup..."

  # Recopilar ficheros
  local staging="$BACKUP_DIR/staging-$$"
  mkdir -p "$staging/data"

  local backup_paths
  backup_paths=$(get_backup_paths)
  local file_count=0

  for path in $backup_paths; do
    if [ -e "$path" ]; then
      cp -r "$path" "$staging/data/"
      file_count=$((file_count + 1))
    fi
  done

  if [ "$file_count" -eq 0 ]; then
    log_warn "No hay ficheros para respaldar"
    rm -rf "$staging"
    return 0
  fi

  log_info "Ficheros recopilados: $file_count"

  # Generar SHA256 manifest
  find "$staging/data" -type f -exec sha256sum {} \; > "$staging/data/MANIFEST.sha256"

  # Timestamp
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_file="$BACKUP_DIR/pm-backup-$timestamp.enc"

  # Pedir passphrase (o usar la guardada)
  local passphrase
  passphrase=$(read_config "passphrase_hash")
  if [ -z "$passphrase" ]; then
    log_info "Primera vez: define una passphrase para cifrar el backup."
    log_info "IMPORTANTE: guárdala en un lugar seguro — sin ella no podrás restaurar."
    echo -n "Passphrase: "
    read -rs passphrase
    echo ""
    echo -n "Confirma: "
    read -rs passphrase_confirm
    echo ""
    if [ "$passphrase" != "$passphrase_confirm" ]; then
      log_error "Las passphrases no coinciden"
      rm -rf "$staging"
      return 1
    fi
    # Guardar hash (no la passphrase en sí)
    local hash
    hash=$(echo -n "$passphrase" | sha256sum | cut -d' ' -f1)
    write_config "passphrase_hash" "$hash"
  else
    echo -n "Passphrase: "
    read -rs passphrase
    echo ""
    local hash
    hash=$(echo -n "$passphrase" | sha256sum | cut -d' ' -f1)
    if [ "$hash" != "$passphrase" ]; then
      log_warn "Passphrase diferente a la original (hash no coincide)"
    fi
  fi

  # Cifrar
  if do_encrypt "$staging/data" "$backup_file" "$passphrase"; then
    write_config "last_backup" "$(date +%s)"
    write_config "last_backup_file" "$backup_file"
    rotate_backups

    # Subir a cloud si configurado
    local cloud_type
    cloud_type=$(read_config "cloud_type")
    if [ "$cloud_type" = "nextcloud" ]; then
      upload_nextcloud "$backup_file"
    elif [ "$cloud_type" = "gdrive" ]; then
      log_info "Google Drive: usa el MCP connector para subir $backup_file"
    fi

    log_ok "Backup completado: $backup_file"
  fi

  rm -rf "$staging"
}

# ── Restaurar ──────────────────────────────────────────────────────
do_restore() {
  ensure_config

  # Buscar último backup
  local latest
  latest=$(find "$BACKUP_DIR" -name "pm-backup-*.enc" -type f 2>/dev/null | sort -r | head -1)

  if [ -z "$latest" ]; then
    log_error "No hay backups disponibles en $BACKUP_DIR"
    log_info "Si tienes un backup en la nube, descárgalo primero a $BACKUP_DIR"
    return 1
  fi

  log_info "Último backup: $(basename "$latest")"
  log_info "Tamaño: $(du -h "$latest" | cut -f1)"

  echo -n "Passphrase: "
  read -rs passphrase
  echo ""

  local restore_dir="$BACKUP_DIR/restore-$$"
  if do_decrypt "$latest" "$restore_dir" "$passphrase"; then
    log_info "Verificando SHA256..."
    if [ -f "$restore_dir/data/MANIFEST.sha256" ]; then
      cd "$restore_dir/data"
      if sha256sum -c MANIFEST.sha256 --quiet 2>/dev/null; then
        log_ok "Integridad verificada"
      else
        log_warn "Algunos ficheros no coinciden con el manifest"
      fi
      cd - >/dev/null
    fi

    log_info "Ficheros restaurados en: $restore_dir/data/"
    log_info "Revisa y copia manualmente a sus ubicaciones originales."
    find "$restore_dir/data" -type f -not -name "MANIFEST.sha256" | while read -r f; do
      echo "  $(echo "$f" | sed "s|$restore_dir/data/||")"
    done
  fi
}

# ── Auto backup on/off ─────────────────────────────────────────────
do_auto_on() {
  ensure_config
  write_config "auto_backup" "true"
  log_ok "Auto-backup activado"
  log_info "Savia te recordará hacer backup al inicio de sesión si hace más de 24h"
}

do_auto_off() {
  ensure_config
  write_config "auto_backup" "false"
  log_ok "Auto-backup desactivado"
}

# ── Status ──────────────────────────────────────────────────────────
do_status() {
  ensure_config

  echo -e "${CYAN}━━━ Backup Status ━━━${NC}"
  echo ""

  local auto
  auto=$(read_config "auto_backup")
  echo -e "  Auto-backup:   ${auto:-false}"

  local last
  last=$(read_config "last_backup")
  if [ -n "$last" ] && [ "$last" != "0" ]; then
    local last_date
    last_date=$(date -d "@$last" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$last" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
    echo -e "  Último backup: $last_date"
  else
    echo -e "  Último backup: ${RED}nunca${NC}"
  fi

  local cloud
  cloud=$(read_config "cloud_type")
  echo -e "  Cloud:         ${cloud:-none}"

  local count
  count=$(find "$BACKUP_DIR" -name "pm-backup-*.enc" -type f 2>/dev/null | wc -l)
  echo -e "  Backups locales: $count/$MAX_BACKUPS"

  if [ "$count" -gt 0 ]; then
    echo ""
    echo -e "  ${CYAN}Backups disponibles:${NC}"
    find "$BACKUP_DIR" -name "pm-backup-*.enc" -type f 2>/dev/null | sort -r | while read -r f; do
      echo "    $(basename "$f") ($(du -h "$f" | cut -f1))"
    done
  fi
}

# ── Config cloud ────────────────────────────────────────────────────
do_config() {
  local provider="${1:-help}"
  shift || true

  case "$provider" in
    nextcloud)
      local url="${1:?Uso: backup.sh config nextcloud URL USER}"
      local user="${2:?Uso: backup.sh config nextcloud URL USER}"
      ensure_config
      write_config "cloud_type" "nextcloud"
      write_config "nextcloud_url" "$url"
      write_config "nextcloud_user" "$user"
      echo -n "NextCloud password: "
      read -rs nc_pass
      echo ""
      write_config "nextcloud_pass" "$nc_pass"
      log_ok "NextCloud configurado: $url (usuario: $user)"
      ;;
    gdrive)
      ensure_config
      write_config "cloud_type" "gdrive"
      log_ok "Google Drive configurado (usa MCP connector para subir)"
      ;;
    none)
      ensure_config
      write_config "cloud_type" "none"
      log_ok "Cloud desactivado — solo backups locales"
      ;;
    *)
      echo "Configurar proveedor cloud para backup"
      echo ""
      echo "Uso: backup.sh config {nextcloud|gdrive|none} [args]"
      echo ""
      echo "  nextcloud URL USER — Configurar NextCloud (WebDAV)"
      echo "  gdrive             — Configurar Google Drive (MCP)"
      echo "  none               — Solo backups locales"
      ;;
  esac
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    now)      do_now ;;
    restore)  do_restore ;;
    auto-on)  do_auto_on ;;
    auto-off) do_auto_off ;;
    status)   do_status ;;
    config)   do_config "$@" ;;
    help|*)
      echo "backup.sh — Backup cifrado de datos locales"
      echo ""
      echo "Uso: bash scripts/backup.sh {comando} [args]"
      echo ""
      echo "Comandos:"
      echo "  now                — Backup inmediato (cifrar + subir)"
      echo "  restore            — Restaurar desde último backup"
      echo "  auto-on            — Activar recordatorio de backup"
      echo "  auto-off           — Desactivar recordatorio"
      echo "  status             — Estado del backup"
      echo "  config {provider}  — Configurar NextCloud/GDrive"
      echo "  help               — Esta ayuda"
      ;;
  esac
}

main "$@"
