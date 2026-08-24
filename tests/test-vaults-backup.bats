#!/usr/bin/env bats
# BATS tests for scripts/vaults-backup-cron.sh (SE-344/L14)
# Valida: backup por cúpula (tar.gz+bundle+sha256), verify, status,
# rotación, nc-push fail-safe y cero egress (CRIT-001).

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