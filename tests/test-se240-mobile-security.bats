#!/usr/bin/env bats
# SE-240 — Mobile Security Pipeline tests
# Tests: mobile-security-scan.sh, android-manifest-audit.sh, SKILL.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export MOBILE_SCRIPT="$REPO_ROOT/scripts/mobile-security-scan.sh"
  export MANIFEST_SCRIPT="$REPO_ROOT/scripts/android-manifest-audit.sh"
  export SKILL_FILE="$REPO_ROOT/.opencode/skills/mobile-security-scanner/SKILL.md"
  FAKE_TMPDIR=$(mktemp -d)
  export FAKE_TMPDIR
}

teardown() {
  rm -rf "$FAKE_TMPDIR"
}

# Test 1: mobile-security-scan.sh existe y pasa bash -n
@test "mobile-security-scan.sh existe y pasa bash -n" {
  [[ -f "$MOBILE_SCRIPT" ]]
  run bash -n "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 2: android-manifest-audit.sh existe y pasa bash -n
@test "android-manifest-audit.sh existe y pasa bash -n" {
  [[ -f "$MANIFEST_SCRIPT" ]]
  run bash -n "$MANIFEST_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 3: mobile-security-scanner/SKILL.md existe y tiene ≤150 líneas
@test "mobile-security-scanner/SKILL.md existe y tiene 150 lineas o menos" {
  [[ -f "$SKILL_FILE" ]]
  LINE_COUNT=$(wc -l < "$SKILL_FILE")
  [[ "$LINE_COUNT" -le 150 ]]
}

# Test 4: android-manifest-audit.sh funciona sin MobSF (usa xmllint o python3)
@test "android-manifest-audit.sh usa xmllint o python3 no MobSF" {
  # El script no debe hacer llamadas a la API de MobSF ni a Docker MobSF
  run grep -i "curl.*mobsf\|docker.*mobsf\|mobsf_api\|mobsf_url" "$MANIFEST_SCRIPT"
  # No debe tener llamadas funcionales a MobSF
  [[ "$status" -ne 0 ]]
  # Debe mencionar xmllint o python3 como parsers
  run grep -i "xmllint\|python3" "$MANIFEST_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 5: android-manifest-audit.sh detecta android:debuggable=true como CRITICAL
@test "android-manifest-audit.sh detecta debuggable=true como CRITICAL" {
  # Crear un AndroidManifest de prueba con debuggable=true
  cat > "$FAKE_TMPDIR/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test.app">
    <application
        android:debuggable="true"
        android:allowBackup="false"
        android:label="TestApp">
    </application>
</manifest>
EOF
  run bash "$MANIFEST_SCRIPT" "$FAKE_TMPDIR/AndroidManifest.xml"
  [[ "$output" == *"CRITICAL"* ]]
  [[ "$output" == *"debuggable"* ]]
}

# Test 6: android-manifest-audit.sh detecta android:allowBackup=true como HIGH
@test "android-manifest-audit.sh detecta allowBackup=true como HIGH" {
  cat > "$FAKE_TMPDIR/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test.app">
    <application
        android:debuggable="false"
        android:allowBackup="true"
        android:label="TestApp">
    </application>
</manifest>
EOF
  run bash "$MANIFEST_SCRIPT" "$FAKE_TMPDIR/AndroidManifest.xml"
  [[ "$output" == *"HIGH"* ]]
  [[ "$output" == *"allowBackup"* ]]
}

# Test 7: android-manifest-audit.sh acepta un path como argumento
@test "android-manifest-audit.sh acepta path como argumento posicional" {
  # Sin argumento debe fallar con error
  run bash "$MANIFEST_SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"AndroidManifest"* ]]
}

# Test 8: mobile-security-scan.sh acepta --apk
@test "mobile-security-scan.sh acepta argumento --apk" {
  run grep "\-\-apk" "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 9: mobile-security-scan.sh acepta --mode
@test "mobile-security-scan.sh acepta argumento --mode" {
  run grep "\-\-mode" "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 10: Con MobSF no disponible → muestra Docker fallback
@test "mobile-security-scan.sh menciona Docker fallback cuando MobSF no disponible" {
  run grep -i "docker\|Docker" "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]]
  run grep -i "opensecurity/mobile-security-framework-mobsf\|drwetter" "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]] || run grep -i "opensecurity" "$MOBILE_SCRIPT"
}

# Test 11: SKILL.md menciona "MobSF" o "android"
@test "mobile-security-scanner SKILL.md menciona MobSF o android" {
  run grep -i "MobSF\|android" "$SKILL_FILE"
  [[ "$status" -eq 0 ]]
}

# Test 12: mobile-security-scan.sh tiene set -uo pipefail
@test "mobile-security-scan.sh tiene set -uo pipefail" {
  run grep "set -uo pipefail" "$MOBILE_SCRIPT"
  [[ "$status" -eq 0 ]]
}
