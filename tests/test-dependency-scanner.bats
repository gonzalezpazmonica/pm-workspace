#!/usr/bin/env bats
# Ref: docs/rules/domain/dependency-security-policy.md — SE-244 / SE-376
#
# Comportamiento de scripts/dependency-scan.sh con un trivy (y un docker) falsos en el PATH:
# qué banderas recibe Trivy, cómo se traduce su resultado a códigos de salida y que un fallo
# del escáner nunca se presente como «limpio» ni como «vulnerabilidades», ni fabrique un SBOM.

SCRIPT="scripts/dependency-scan.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/bin" "$TMPDIR/proj" "$TMPDIR/out"
  printf '{"name":"demo","dependencies":{"lodash":"4.17.0"}}\n' > "$TMPDIR/proj/package.json"
  export DEP_SCAN_OUTPUT_DIR="$TMPDIR/out"
  export FAKE_LOG="$TMPDIR/calls.log"
  export FAKE_JSON='{"Results":[]}'
  export FAKE_RC=0
  export FAKE_SBOM_RC=0
  # trivy falso: registra la llamada; con --format json escribe FAKE_JSON; con cyclonedx, un SBOM.
  cat > "$TMPDIR/bin/trivy" <<'EOF'
#!/usr/bin/env bash
echo "trivy $*" >> "$FAKE_LOG"
out="" fmt=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) out="$2"; shift 2 ;;
    --format) fmt="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "$fmt" == "cyclonedx" ]]; then
  [[ "$FAKE_SBOM_RC" -ne 0 ]] && exit "$FAKE_SBOM_RC"
  printf '{"bomFormat":"CycloneDX","components":[{"name":"lodash"}]}\n' > "$out"
  exit 0
fi
[[ "$FAKE_RC" -ne 0 ]] && { echo "FATAL fake trivy failure" >&2; exit "$FAKE_RC"; }
[[ -n "$out" ]] && printf '%s\n' "$FAKE_JSON" > "$out"
exit 0
EOF
  chmod +x "$TMPDIR/bin/trivy"
  PATH="$TMPDIR/bin:$PATH"
}

teardown() {
  rm -rf "$TMPDIR"
}

vuln_json() {
  printf '{"Results":[{"Target":"package-lock.json","Vulnerabilities":[{"VulnerabilityID":"%s","PkgName":"lodash","InstalledVersion":"4.17.0","FixedVersion":"4.17.21","Severity":"%s"}]}]}' "$1" "$2"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "clean scan exits 0 with PASS and writes the JSON report" {
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  ls "$TMPDIR/out"/dep-scan-*.json
}

@test "HIGH vulnerability blocks with exit 1 and names the CVE and package" {
  FAKE_JSON="$(vuln_json CVE-2021-23337 HIGH)"
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CVE-2021-23337"* ]]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" != *"PASS"* ]]
}

@test "MEDIUM vulnerability does not block with the default severities" {
  FAKE_JSON="$(vuln_json CVE-2020-0001 MEDIUM)"
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
}

@test "scanner failure is an error (exit 2), never PASS and never a vulnerability verdict" {
  FAKE_RC=1
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"PASS"* ]]
  [[ "$output" != *"Vulnerabilidades CRITICAL/HIGH detectadas"* ]]
}

@test "invalid JSON from the scanner is an error, not a clean result" {
  FAKE_JSON='no es json'
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 2 ]
  [[ "$output" != *"PASS"* ]]
}

@test "trivy receives --scanners vuln, the severities and --skip-db-update" {
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj" --severity CRITICAL --skip-update
  [ "$status" -eq 0 ]
  grep -q -- "--scanners vuln" "$FAKE_LOG"
  grep -q -- "--severity CRITICAL" "$FAKE_LOG"
  grep -q -- "--skip-db-update" "$FAKE_LOG"
  ! grep -q -- "--security-checks" "$FAKE_LOG"
}

@test "scanner runs once per scan (no triple invocation)" {
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^trivy fs' "$FAKE_LOG")" -eq 1 ]
}

@test ".trivyignore in the scanned path is passed as --ignorefile" {
  printf 'CVE-2020-0001\n' > "$TMPDIR/proj/.trivyignore"
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
  grep -q -- "--ignorefile $TMPDIR/proj/.trivyignore" "$FAKE_LOG"
}

@test "SBOM is generated with trivy fs --format cyclonedx" {
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj" --generate-sbom
  [ "$status" -eq 0 ]
  grep -q "^trivy fs .*--format cyclonedx" "$FAKE_LOG"
  python3 -c "import json,sys,glob; d=json.load(open(glob.glob(sys.argv[1]+'/sbom-*.json')[0])); assert d['components']" "$TMPDIR/out"
}

@test "SBOM failure is an error and no empty SBOM is fabricated" {
  FAKE_SBOM_RC=1
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj" --generate-sbom
  [ "$status" -eq 2 ]
  [[ "$output" == *"SBOM"* ]]
  ! ls "$TMPDIR/out"/sbom-*.json 2>/dev/null
}

@test "docker fallback mounts the scanned path and passes the flags to trivy fs" {
  PATH="/usr/bin:/bin" command -v trivy >/dev/null && skip "trivy real en /usr/bin"
  mv "$TMPDIR/bin/trivy" "$TMPDIR/trivy.real"
  cat > "$TMPDIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE_LOG"
printf '%s\n' "$FAKE_JSON"
EOF
  chmod +x "$TMPDIR/bin/docker"
  run env PATH="$TMPDIR/bin:/usr/bin:/bin" bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
  grep -q -- "-v $TMPDIR/proj:/workspace" "$FAKE_LOG"
  grep -q -- "aquasec/trivy:latest fs .*--scanners vuln.*/workspace$" "$FAKE_LOG"
}

@test "missing --path or a nonexistent path is a usage error (exit 2)" {
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 2 ]
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/nonexistent"
  [ "$status" -eq 2 ]
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj" --bad-flag
  [ "$status" -eq 2 ]
}

@test "edge: null Results and empty Vulnerabilities count as clean" {
  FAKE_JSON='{"Results":null}'
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
  FAKE_JSON='{"Results":[{"Target":"x","Vulnerabilities":[]}]}'
  run bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 0 ]
}

@test "edge: neither trivy nor docker available is an error with install guidance" {
  PATH="/usr/bin:/bin" command -v trivy >/dev/null && skip "trivy real en /usr/bin"
  PATH="/usr/bin:/bin" command -v docker >/dev/null && skip "docker real en /usr/bin"
  rm -f "$TMPDIR/bin/trivy"
  run env PATH="$TMPDIR/bin:/usr/bin:/bin" bash "$REPO_ROOT/$SCRIPT" --path "$TMPDIR/proj"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Instala Trivy"* ]]
}
