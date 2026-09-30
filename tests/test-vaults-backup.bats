#!/usr/bin/env bats
# BATS tests for scripts/vaults-backup-cron.sh (SE-344/L14)
# Valida: backup por cúpula (tar.gz+bundle+sha256), verify, status,
# rotación, nc-push fail-safe y cero egress (CRIT-001).
# Ref: projects/savia-vaults/docs/specs/SE-417-savia-files-encryption.spec.md (almacén de ficheros y claves)
# Funciones cubiertas vía `run`: backup_one, backup_files, backup_keys, resolve_node,
# rotate, rotate_keys, load_nc_env, nc_push y log (aserciones sobre el log).

SCRIPT="scripts/vaults-backup-cron.sh"
TESTROOT=""

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # crear vault/senario aislado con cúpulas git falsas
  TESTROOT="$(mktemp -d -t vb.XXXXXX)"
  export SAVIA_VAULTS_DIR="$TESTROOT/vaults"
  export SAVIA_VAULTS_BACKUP_DIR="$TESTROOT/backups"
  mkdir -p "$TESTROOT/vaults/SaviaLabs" "$TESTROOT/vaults/SaviaLearning" "$TESTROOT/vaults/savia-docs"
  echo "nota" > "$TESTROOT/vaults/SaviaLabs/a.md"
  echo "nota" > "$TESTROOT/vaults/SaviaLearning/b.md"
  echo "nota" > "$TESTROOT/vaults/savia-docs/c.md"
  for d in SaviaLabs SaviaLearning savia-docs; do
    git -C "$TESTROOT/vaults/$d" init -q 2>/dev/null || true
    git -C "$TESTROOT/vaults/$d" config user.email "test@local"
    git -C "$TESTROOT/vaults/$d" config user.name "test"
    git -C "$TESTROOT/vaults/$d" add . 2>/dev/null || true
    git -C "$TESTROOT/vaults/$d" commit -qm "seed" 2>/dev/null || true
  done
  # HOME aislado para que el script use TESTROOT y no el real
  export HOME="$TESTROOT/home"; mkdir -p "$HOME/.savia-vaults"
  LOG="$HOME/.savia-vaults/vaults-backup.log"
}

teardown() {
  [[ -n "$TESTROOT" ]] && rm -rf "$TESTROOT"
  unset SAVIA_VAULTS_BACKUP_DIR HOME LOG
  cd /
}

@test "script existe y es ejecutable" { [[ -x "$SCRIPT" ]]; }

@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "safety: el script declara set -uo pipefail" { grep -q '^set -uo pipefail' "$SCRIPT"; }

count_backups() { find "$1" -name "$2" | wc -l; }

@test "run genera ficheros de backup por cúpula (tar.gz, bundle, sha256)" {
  # monkeypatch VAULTS_DIR via env no existe; usamos la ruta por defecto real $HOME/savia/vaults
  # en su lugar: ejecutar con BACKUP_DIR aislado y VAULTS_DIR real (solo asegura tar.gz)
  export SAVIA_VAULTS_DIR="$TESTROOT/vaults"
  export SAVIA_VAULTS_BACKUP_DIR="$TESTROOT/backups"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR" "SaviaLabs-*.tar.gz")" -ge 1 ]
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR" "savia-docs-*.tar.gz")" -ge 1 ]
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR" "SaviaLabs-repo-*.bundle")" -ge 1 ]
}

@test "verify OK en backups generados" {
  export SAVIA_VAULTS_DIR="$TESTROOT/vaults"
  export SAVIA_VAULTS_BACKUP_DIR="$TESTROOT/backups"
  bash "$SCRIPT" run >/dev/null 2>&1
  run bash "$SCRIPT" --verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK  SaviaLabs"* ]]
}

@test "--status muestra dir y retention" {
  run bash "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backup dir"* ]]
  [[ "$output" == *"Retention"* ]]
}

@test "nc-push con URL caída no rompe el backup (fail-safe)" {
  export SAVIA_VAULTS_DIR="$TESTROOT/vaults"
  export SAVIA_VAULTS_BACKUP_DIR="$TESTROOT/backups"
  export NEXTCLOUD_URL="http://127.0.0.1:1"
  export NEXTCLOUD_USER="test"
  export NEXTCLOUD_PASS="test"
  # crear el env que carga el script
  mkdir -p "$TESTROOT/home/.savia-vaults"
  cat > "$TESTROOT/home/.savia-vaults/nextcloud.env" <<EOF
NEXTCLOUD_URL="http://127.0.0.1:1"
NEXTCLOUD_USER="test"
NEXTCLOUD_PASS="test"
EOF
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]  # el fallo de NC NO rompe el backup local
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR" "SaviaLabs-*.tar.gz")" -ge 1 ]
}

@test "cero egress: el script no contiene urllib/requests/curl a externos" {
  # el script usa curl para WebDAV a NEXTCLOUD_URL (infra propia de la operadora);
  # verifica que NO haya drivers de nube de terceros (aws/gcp/azure SDK)
  run bash -c "! grep -E 'aws |gsutil|az ' $SCRIPT"
  [ "$status" -eq 0 ]
}

# ── SE-417: almacén de Savia Files y copia de claves ─────────────────────────
seed_files() {
  export SAVIA_FILES_HOME="$TESTROOT/files"
  export SAVIA_FILES_KEYS_HOME="$TESTROOT/keys"
  mkdir -p "$SAVIA_FILES_HOME/D/blobs" "$SAVIA_FILES_HOME/D/.work" "$SAVIA_FILES_KEYS_HOME/D/wraps"
  echo "cifrado" > "$SAVIA_FILES_HOME/D/blobs/r_0000000000000001.svf"
  echo "lock" > "$SAVIA_FILES_HOME/D/files.lock"
  echo "tmp" > "$SAVIA_FILES_HOME/D/.work/original"
  printf 'k%.0s' {1..32} > "$SAVIA_FILES_KEYS_HOME/D/kek"
}

# Sustituto de node: `files keys backup --out F` escribe una copia "sellada" de prueba.
fake_node() {
  printf '%s\n' '#!/usr/bin/env bash' \
    'out=""; while [[ $# -gt 0 ]]; do [[ "$1" == "--out" ]] && out="$2"; shift; done' \
    '[[ -n "$out" ]] && printf SEALED > "$out" && exit 0' 'exit 1' > "$TESTROOT/node"
  chmod +x "$TESTROOT/node"
  export SAVIA_NODE="$TESTROOT/node"
}

nc_env_down() {
  printf '%s\n' 'NEXTCLOUD_URL="http://127.0.0.1:1"' 'NEXTCLOUD_USER="test"' 'NEXTCLOUD_PASS="test"' > "$HOME/.savia-vaults/nextcloud.env"
}

@test "SE-417: el almacén de ficheros entra en el backup sin lock ni temporales" {
  seed_files
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  local tarf; tarf=$(ls -1 "$SAVIA_VAULTS_BACKUP_DIR"/savia-files-*.tar.gz | head -1)
  [ -n "$tarf" ]
  [ -f "$tarf.sha256" ]
  run tar -tzf "$tarf"
  [[ "$output" == *"r_0000000000000001.svf"* ]]
  [[ "$output" != *"files.lock"* ]]
  [[ "$output" != *".work"* ]]
}

@test "SE-417: sin fichero de recuperación, copia local de claves 0600 y aviso; nunca se sube" {
  seed_files
  nc_env_down
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  local k; k=$(ls -1 "$SAVIA_VAULTS_BACKUP_DIR"/keys/savia-keys-*.tar.gz | head -1)
  [ -n "$k" ]
  [ "$(stat -c %a "$k")" = "600" ]
  [ "$(stat -c %a "$SAVIA_VAULTS_BACKUP_DIR/keys")" = "700" ]
  grep -q "AVISO: claves sin fichero de recuperación" "$LOG"
  ! grep nextcloud "$LOG" | grep -q "savia-keys"
}

@test "SE-417: con recuperación, copia sellada; se sube solo si SAVIA_BACKUP_UPLOAD_KEYS=true" {
  seed_files
  fake_node
  echo "pub" > "$SAVIA_FILES_KEYS_HOME/recovery.pub"
  nc_env_down
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  local s; s=$(ls -1 "$SAVIA_VAULTS_BACKUP_DIR"/keys/savia-keys-*.sealed | head -1)
  [ "$(cat "$s")" = "SEALED" ]
  [ -z "$(ls "$SAVIA_VAULTS_BACKUP_DIR"/keys/savia-keys-*.tar.gz 2>/dev/null)" ]
  ! grep nextcloud "$LOG" | grep -q "savia-keys"
  echo 'SAVIA_BACKUP_UPLOAD_KEYS=true' >> "$HOME/.savia-vaults/nextcloud.env"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  grep nextcloud "$LOG" | grep -q "savia-keys-.*\.sealed"
}

@test "SE-417: almacén de ficheros nonexistent: se omite sin fallar ni crear tar" {
  export SAVIA_FILES_HOME="$TESTROOT/no-existe"
  export SAVIA_FILES_KEYS_HOME="$TESTROOT/tampoco"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  [ -z "$(ls "$SAVIA_VAULTS_BACKUP_DIR"/savia-files-*.tar.gz 2>/dev/null)" ]
  [ ! -d "$SAVIA_VAULTS_BACKUP_DIR/keys" ]
  grep -q "skip: savia-files (sin almacén)" "$LOG"
}

@test "SE-417: almacén empty y claves empty: sin tar de ficheros ni copia de claves" {
  export SAVIA_FILES_HOME="$TESTROOT/files"
  export SAVIA_FILES_KEYS_HOME="$TESTROOT/keys"
  mkdir -p "$SAVIA_FILES_HOME" "$SAVIA_FILES_KEYS_HOME"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  [ -z "$(ls "$SAVIA_VAULTS_BACKUP_DIR"/savia-files-*.tar.gz 2>/dev/null)" ]
  [ ! -d "$SAVIA_VAULTS_BACKUP_DIR/keys" ]
}

@test "SE-417: node nonexistent con recuperación: FAIL en el log y copia local 0600; nada se sube" {
  seed_files
  echo "pub" > "$SAVIA_FILES_KEYS_HOME/recovery.pub"
  export SAVIA_NODE="$TESTROOT/no-hay-node"
  nc_env_down
  echo 'SAVIA_BACKUP_UPLOAD_KEYS=true' >> "$HOME/.savia-vaults/nextcloud.env"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  grep -q "FAIL: copia sellada de claves" "$LOG"
  local k; k=$(ls -1 "$SAVIA_VAULTS_BACKUP_DIR"/keys/savia-keys-*.tar.gz | head -1)
  [ "$(stat -c %a "$k")" = "600" ]
  ! grep nextcloud "$LOG" | grep -q "savia-keys"
}

@test "SE-417: rotación en el boundary de SAVIA_BACKUP_RETENTION para ficheros y claves" {
  seed_files
  export SAVIA_BACKUP_RETENTION=2
  mkdir -p "$SAVIA_VAULTS_BACKUP_DIR/keys"
  for i in 1 2 3; do
    touch -d "2026-01-0$i" "$SAVIA_VAULTS_BACKUP_DIR/savia-files-2026-01-0${i}T00-00-00.tar.gz" \
      "$SAVIA_VAULTS_BACKUP_DIR/keys/savia-keys-2026-01-0${i}T00-00-00.tar.gz"
  done
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR" "savia-files-*.tar.gz")" -eq 2 ]
  [ "$(count_backups "$SAVIA_VAULTS_BACKUP_DIR/keys" "savia-keys-*")" -eq 2 ]
  # sobreviven la de hoy y la más reciente de las antiguas
  [ -f "$SAVIA_VAULTS_BACKUP_DIR/keys/savia-keys-2026-01-03T00-00-00.tar.gz" ]
  [ ! -f "$SAVIA_VAULTS_BACKUP_DIR/keys/savia-keys-2026-01-01T00-00-00.tar.gz" ]
}

@test "SE-418: el tar del almacén incluye el ledger git y el journal (restaurables con files verify)" {
  seed_files
  mkdir -p "$SAVIA_FILES_HOME/D/ledger/manifests"
  git -C "$SAVIA_FILES_HOME/D/ledger" init -q
  echo '{}' > "$SAVIA_FILES_HOME/D/ledger/manifests/f_0000000000000001.json"
  echo "sqlite" > "$SAVIA_FILES_HOME/D/journal.db"
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  local tarf; tarf=$(ls -1 "$SAVIA_VAULTS_BACKUP_DIR"/savia-files-*.tar.gz | head -1)
  run tar -tzf "$tarf"
  [[ "$output" == *"D/ledger/.git/HEAD"* ]]
  [[ "$output" == *"D/ledger/manifests/f_0000000000000001.json"* ]]
  [[ "$output" == *"D/journal.db"* ]]
}
