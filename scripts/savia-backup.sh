#!/bin/bash

# Savia Backup & Restore Script
# Persistent backup of Savia configuration and state
# Supports cloud backup (git tags) and local rotation

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${ROOT}/backups"
MAX_BACKUPS=5

# Timestamps
TIMESTAMP=$(date -u +%Y-%m-%d-%H%M%S)
BACKUP_NAME="savia-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Files to backup (critical Savia state)
BACKUP_FILES=(
  ".claude/savia-identity.md"
  ".claude/savia-roadmap.md"
  ".claude/settings.json"
  ".claude/CLAUDE.md"
)

# ─────────────────────────────────────────────────────────────────────────────
# Main Functions
# ─────────────────────────────────────────────────────────────────────────────

backup_create() {
  echo "🔄 Creating backup: ${BACKUP_NAME}"

  mkdir -p "${BACKUP_PATH}"

  # Copy critical files
  for file in "${BACKUP_FILES[@]}"; do
    if [[ -f "${ROOT}/${file}" ]]; then
      mkdir -p "${BACKUP_PATH}/$(dirname "${file}")"
      cp "${ROOT}/${file}" "${BACKUP_PATH}/${file}"
    fi
  done

  # Create manifest
  cat > "${BACKUP_PATH}/MANIFEST.md" <<EOF
# Savia Backup Manifest

**Backup ID:** ${BACKUP_NAME}
**Created:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Files:**
EOF

  for file in "${BACKUP_FILES[@]}"; do
    if [[ -f "${BACKUP_PATH}/${file}" ]]; then
      echo "- \`${file}\`" >> "${BACKUP_PATH}/MANIFEST.md"
    fi
  done

  echo "✅ Backup created at ${BACKUP_PATH}"
}

backup_list() {
  echo "📦 Available backups:"
  echo

  if [[ ! -d "${BACKUP_DIR}" ]]; then
    echo "   No backups found (directory doesn't exist)"
    return 0
  fi

  count=0
  for backup in $(ls -1t "${BACKUP_DIR}" 2>/dev/null | grep '^savia-'); do
    manifest="${BACKUP_DIR}/${backup}/MANIFEST.md"
    if [[ -f "${manifest}" ]]; then
      created=$(grep "^\\*\\*Created:" "${manifest}" | cut -d: -f2-)
      echo "   ${backup}${created}"
      count=$((count + 1))
    fi
  done

  if [[ $count -eq 0 ]]; then
    echo "   No backups found"
  else
    echo
    echo "   Total: ${count} backups"
  fi
}

backup_restore() {
  local restore_id="${1:?Backup ID required. Use --list to see available}"

  if [[ ! -d "${BACKUP_DIR}/${restore_id}" ]]; then
    echo "❌ Backup not found: ${restore_id}"
    return 1
  fi

  echo "🔄 Restoring from: ${restore_id}"

  # Verify manifest exists
  if [[ ! -f "${BACKUP_DIR}/${restore_id}/MANIFEST.md" ]]; then
    echo "❌ No manifest found. Backup may be corrupted."
    return 1
  fi

  # Restore files
  for file in "${BACKUP_FILES[@]}"; do
    src="${BACKUP_DIR}/${restore_id}/${file}"
    dst="${ROOT}/${file}"

    if [[ -f "${src}" ]]; then
      mkdir -p "$(dirname "${dst}")"
      cp "${src}" "${dst}"
      echo "   ✓ Restored ${file}"
    fi
  done

  echo "✅ Restoration complete"
}

backup_rotate() {
  echo "🔄 Rotating old backups (keeping last ${MAX_BACKUPS})"

  if [[ ! -d "${BACKUP_DIR}" ]]; then
    return 0
  fi

  local count=$(ls -1 "${BACKUP_DIR}" 2>/dev/null | grep '^savia-' | wc -l)

  if [[ $count -le ${MAX_BACKUPS} ]]; then
    echo "   No rotation needed (${count} backups)"
    return 0
  fi

  local excess=$((count - MAX_BACKUPS))
  echo "   Removing ${excess} old backups..."

  ls -1t "${BACKUP_DIR}" | grep '^savia-' | tail -n ${excess} | while read -r old_backup; do
    rm -rf "${BACKUP_DIR:?}/${old_backup}"
    echo "   🗑️  Deleted ${old_backup}"
  done
}

backup_cloud() {
  local tag="backup/savia-${TIMESTAMP}"

  echo "🌐 Creating git tag for cloud persistence: ${tag}"

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Not a git repository. Cloud backup requires git."
    return 1
  fi

  # Create backup first
  backup_create

  # Stage files
  git add "${BACKUP_FILES[@]}"

  # Create tag
  git tag -a "${tag}" -m "Savia backup: ${TIMESTAMP}" 2>/dev/null || {
    echo "⚠️  Tag already exists or git error. Skipping cloud push."
    return 1
  }

  echo "✅ Git tag created: ${tag}"
  echo "   Push with: git push origin ${tag}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Usage & CLI
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
  cat <<'EOF'
Savia Backup & Restore Script

Usage:
  savia-backup.sh [command] [options]

Commands:
  create              Create a new backup (default)
  --list              List available backups
  --restore TIMESTAMP Restore from specific backup (format: YYYY-MM-DD-HHMMSS)
  --cloud             Create backup and git tag for cloud persistence
  --rotate            Rotate old backups, keep last 5

Examples:
  savia-backup.sh create
  savia-backup.sh --list
  savia-backup.sh --restore 2026-03-05-091500
  savia-backup.sh --cloud
  savia-backup.sh --rotate

Files backed up:
  - .claude/savia-identity.md
  - .claude/savia-roadmap.md
  - .claude/settings.json
  - .claude/CLAUDE.md

Storage:
  Local backups: ./backups/savia-YYYY-MM-DD-HHMMSS/
  Git tags: backup/savia-YYYY-MM-DD-HHMMSS (for remote persistence)

Max local backups: 5 (automatic rotation after each create)
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
  local cmd="${1:-create}"

  case "${cmd}" in
    create)
      backup_create
      backup_rotate
      ;;
    --list)
      backup_list
      ;;
    --restore)
      backup_restore "${2:?Backup timestamp required}"
      ;;
    --cloud)
      backup_cloud
      backup_rotate
      ;;
    --rotate)
      backup_rotate
      ;;
    --help|-h|help)
      show_help
      ;;
    *)
      echo "❌ Unknown command: ${cmd}"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
