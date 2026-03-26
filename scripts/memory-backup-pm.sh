#!/bin/bash
# memory-backup-pm.sh — Backup memory indices to PM repo (N4b, max privacy)
# Source of truth: auto-memory markdown. This backs up the DERIVED indices
# so they can be restored on a new machine without re-ingesting everything.
# Encrypted with AES-256 before writing to repo.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PM_REPO="${SAVIA_BACKUP_PM_REPO:-$PROJECT_ROOT/projects}"
BACKUP_DIR="$PM_REPO/memory-backup"
SAVIA_DIR="$HOME/.savia"
STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"

# Auto-memory path (Claude Code project memory)
# Auto-detect Claude Code project memory path
AUTOMEM_DIR=""
for d in "$HOME/.claude/projects/"*/memory; do
    [[ -f "$d/MEMORY.md" ]] && AUTOMEM_DIR="$d" && break
done

usage() {
    echo "memory-backup-pm.sh <backup|restore|status> [--passphrase FILE]"
    echo ""
    echo "  backup   — Encrypt and copy memory to PM repo"
    echo "  restore  — Decrypt and restore memory from PM repo"
    echo "  status   — Show backup freshness"
    echo ""
    echo "  --passphrase FILE  — Read passphrase from file (default: prompt)"
    echo ""
    echo "Backed up (encrypted):"
    echo "  - Auto-memory markdown files (MEMORY.md + topic files)"
    echo "  - JSONL memory store (semantic search index)"
    echo "  - Teams/email/DevOps cached data"
    echo ""
    echo "NOT backed up (rebuildable):"
    echo "  - FAISS vector index (rebuilt from JSONL)"
    echo "  - Browser sessions (re-authenticate)"
    exit 0
}

get_passphrase() {
    local pp_file="${1:-}"
    if [[ -n "$pp_file" && -f "$pp_file" ]]; then
        cat "$pp_file"
    elif [[ -n "${SAVIA_BACKUP_PASSPHRASE:-}" ]]; then
        echo "$SAVIA_BACKUP_PASSPHRASE"
    else
        read -s -p "Passphrase para cifrado de memoria: " pp
        echo "$pp"
    fi
}

cmd_backup() {
    local pp_file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --passphrase) pp_file="$2"; shift 2;; *) shift;; esac
    done

    local passphrase
    passphrase=$(get_passphrase "$pp_file")
    [[ -z "$passphrase" ]] && { echo "Error: passphrase vacía"; exit 1; }

    mkdir -p "$BACKUP_DIR"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    # 1. Copy auto-memory markdown
    if [[ -d "$AUTOMEM_DIR" ]]; then
        mkdir -p "$tmp_dir/auto-memory"
        cp "$AUTOMEM_DIR"/*.md "$tmp_dir/auto-memory/" 2>/dev/null || true
        echo "Auto-memory: $(ls "$tmp_dir/auto-memory/" 2>/dev/null | wc -l) files"
    fi

    # 2. Copy JSONL store
    if [[ -f "$STORE_FILE" ]]; then
        cp "$STORE_FILE" "$tmp_dir/memory-store.jsonl"
        echo "JSONL store: $(wc -l < "$STORE_FILE") entries"
    fi

    # 3. Copy cached data (Teams, email, DevOps snapshots)
    if [[ -d "$SAVIA_DIR/teams-inbox" ]]; then
        mkdir -p "$tmp_dir/cache/teams"
        cp "$SAVIA_DIR/teams-inbox/"*.json "$tmp_dir/cache/teams/" 2>/dev/null || true
    fi
    if [[ -d "$SAVIA_DIR/outlook-inbox" ]]; then
        mkdir -p "$tmp_dir/cache/outlook"
        cp "$SAVIA_DIR/outlook-inbox/"*.json "$tmp_dir/cache/outlook/" 2>/dev/null || true
    fi
    if [[ -d "$SAVIA_DIR/devops-read" ]]; then
        mkdir -p "$tmp_dir/cache/devops"
        cp "$SAVIA_DIR/devops-read/"*.json "$tmp_dir/cache/devops/" 2>/dev/null || true
    fi

    # 4. Generate manifest
    find "$tmp_dir" -type f | while read -r f; do
        local rel="${f#$tmp_dir/}"
        local hash
        hash=$(sha256sum "$f" | cut -d' ' -f1)
        echo "$hash  $rel"
    done > "$tmp_dir/MANIFEST.sha256"

    # 5. Add metadata
    cat > "$tmp_dir/META.json" << EOFMETA
{
    "ts": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "machine": "$(hostname)",
    "user": "$(whoami)",
    "auto_memory_count": $(ls "$tmp_dir/auto-memory/" 2>/dev/null | wc -l),
    "jsonl_entries": $(wc -l < "$tmp_dir/memory-store.jsonl" 2>/dev/null || echo 0),
    "version": "1.0"
}
EOFMETA

    # 6. Tar + encrypt
    local backup_file="$BACKUP_DIR/memory-backup-$(date +%Y%m%d-%H%M%S).enc"
    tar czf - -C "$tmp_dir" . | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
        -pass "pass:$passphrase" -out "$backup_file"

    # 7. Keep only last 3 backups
    ls -t "$BACKUP_DIR"/memory-backup-*.enc 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true

    local size
    size=$(du -h "$backup_file" | cut -f1)
    echo ""
    echo "Backup cifrado: $backup_file ($size)"
    echo "Retención: últimos 3 backups"
    echo "Para restaurar: memory-backup-pm.sh restore --passphrase <file>"
}

cmd_restore() {
    local pp_file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --passphrase) pp_file="$2"; shift 2;; *) shift;; esac
    done

    local passphrase
    passphrase=$(get_passphrase "$pp_file")
    [[ -z "$passphrase" ]] && { echo "Error: passphrase vacía"; exit 1; }

    # Find latest backup
    local latest
    latest=$(ls -t "$BACKUP_DIR"/memory-backup-*.enc 2>/dev/null | head -1)
    [[ -z "$latest" ]] && { echo "No hay backups en $BACKUP_DIR"; exit 1; }

    echo "Restaurando desde: $(basename "$latest")"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    # Decrypt + extract
    if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
        -pass "pass:$passphrase" -in "$latest" | tar xzf - -C "$tmp_dir" 2>/dev/null; then
        echo "Error: passphrase incorrecta o backup corrupto"
        exit 1
    fi

    # Verify manifest
    echo "Verificando integridad..."
    local errors=0
    while read -r expected_hash rel_path; do
        local actual_hash
        actual_hash=$(sha256sum "$tmp_dir/$rel_path" 2>/dev/null | cut -d' ' -f1)
        if [[ "$expected_hash" != "$actual_hash" ]]; then
            echo "  CORRUPTO: $rel_path"
            ((errors++))
        fi
    done < "$tmp_dir/MANIFEST.sha256"
    [[ $errors -gt 0 ]] && { echo "$errors ficheros corruptos. Abortando."; exit 1; }
    echo "Integridad OK"

    # Show what will be restored
    echo ""
    cat "$tmp_dir/META.json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Backup de: {d[\"ts\"]} en {d[\"machine\"]}')
print(f'  Auto-memory: {d[\"auto_memory_count\"]} ficheros')
print(f'  JSONL entries: {d[\"jsonl_entries\"]}')
" 2>/dev/null || cat "$tmp_dir/META.json"

    echo ""
    read -p "¿Restaurar? Esto sobreescribe memoria actual. [s/N] " confirm
    [[ "$confirm" != "s" && "$confirm" != "S" ]] && { echo "Cancelado."; exit 0; }

    # Restore auto-memory
    if [[ -d "$tmp_dir/auto-memory" ]]; then
        mkdir -p "$AUTOMEM_DIR"
        cp "$tmp_dir/auto-memory/"*.md "$AUTOMEM_DIR/" 2>/dev/null || true
        echo "Auto-memory restaurada: $(ls "$tmp_dir/auto-memory/" | wc -l) ficheros"
    fi

    # Restore JSONL store
    if [[ -f "$tmp_dir/memory-store.jsonl" ]]; then
        cp "$tmp_dir/memory-store.jsonl" "$STORE_FILE"
        echo "JSONL store restaurado: $(wc -l < "$STORE_FILE") entries"
    fi

    # Restore cache
    for subdir in teams outlook devops; do
        if [[ -d "$tmp_dir/cache/$subdir" ]]; then
            local target=""
            case "$subdir" in
                teams) target="$SAVIA_DIR/teams-inbox";;
                outlook) target="$SAVIA_DIR/outlook-inbox";;
                devops) target="$SAVIA_DIR/devops-read";;
            esac
            mkdir -p "$target"
            cp "$tmp_dir/cache/$subdir/"*.json "$target/" 2>/dev/null || true
            echo "Cache $subdir restaurada"
        fi
    done

    # Rebuild FAISS index
    echo "Reconstruyendo índice vectorial..."
    python3 "$SCRIPT_DIR/memory-vector.py" rebuild --store "$STORE_FILE" 2>/dev/null \
        && echo "Índice FAISS reconstruido" \
        || echo "Sin dependencias para FAISS (búsqueda grep disponible)"

    echo ""
    echo "Restauración completa."
}

cmd_status() {
    echo "=== Estado del backup de memoria ==="
    echo ""

    # Auto-memory
    if [[ -d "$AUTOMEM_DIR" ]]; then
        echo "Auto-memory: $(ls "$AUTOMEM_DIR"/*.md 2>/dev/null | wc -l) ficheros"
    else
        echo "Auto-memory: no encontrada"
    fi

    # JSONL
    if [[ -f "$STORE_FILE" ]]; then
        echo "JSONL store: $(wc -l < "$STORE_FILE") entries"
    else
        echo "JSONL store: vacío"
    fi

    # FAISS
    local faiss_file="${STORE_FILE%.jsonl}-index.faiss"
    if [[ -f "$faiss_file" ]]; then
        echo "FAISS index: $(du -h "$faiss_file" | cut -f1)"
    else
        echo "FAISS index: no existe"
    fi

    # Backups
    echo ""
    echo "Backups en PM repo:"
    if ls "$BACKUP_DIR"/memory-backup-*.enc 2>/dev/null | head -1 > /dev/null 2>&1; then
        ls -lh "$BACKUP_DIR"/memory-backup-*.enc 2>/dev/null | awk '{print "  " $NF " (" $5 ", " $6 " " $7 ")"}'
    else
        echo "  Ninguno"
    fi
}

# Main
case "${1:-}" in
    backup) shift; cmd_backup "$@";;
    restore) shift; cmd_restore "$@";;
    status) cmd_status;;
    -h|--help|"") usage;;
    *) echo "Subcomando desconocido: $1"; usage;;
esac
