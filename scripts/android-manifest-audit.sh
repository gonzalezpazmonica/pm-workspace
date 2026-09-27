#!/usr/bin/env bash
# SE-240 — Android Manifest Audit
# Análisis ligero del AndroidManifest.xml sin necesidad de MobSF
# Detecta: debuggable=true, allowBackup=true, exported components sin permisos, permisos peligrosos
# Uso: ./scripts/android-manifest-audit.sh <path/to/AndroidManifest.xml>
set -uo pipefail

MANIFEST_PATH="${1:-}"

if [[ -z "$MANIFEST_PATH" ]]; then
  echo "Uso: $0 <path/to/AndroidManifest.xml>" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "ERROR: Fichero no encontrado: $MANIFEST_PATH" >&2
  exit 1
fi

# ── Seleccionar parser XML ────────────────────────────────────────────────────
XML_PARSER=""
if command -v xmllint &>/dev/null; then
  XML_PARSER="xmllint"
elif command -v python3 &>/dev/null; then
  XML_PARSER="python3"
else
  echo "ERROR: Se requiere xmllint o python3 para parsear el manifest." >&2
  exit 1
fi

# ── Función de extracción con xmllint ─────────────────────────────────────────
xpath_query_xmllint() {
  local xpath="$1"
  xmllint --xpath "$xpath" "$MANIFEST_PATH" 2>/dev/null || echo ""
}

# ── Función de extracción con python3 ─────────────────────────────────────────
xpath_query_python() {
  local query="$1"
  python3 - "$MANIFEST_PATH" "$query" <<'PYEOF' 2>/dev/null || echo ""
import sys
import xml.etree.ElementTree as ET

manifest_path = sys.argv[1]
query = sys.argv[2]

try:
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    # Namespace Android
    ns = {'android': 'http://schemas.android.com/apk/res/android'}

    if query == "debuggable":
        app = root.find('application')
        if app is not None:
            val = app.get('{http://schemas.android.com/apk/res/android}debuggable', 'false')
            print(val)
    elif query == "allowBackup":
        app = root.find('application')
        if app is not None:
            val = app.get('{http://schemas.android.com/apk/res/android}allowBackup', 'true')
            print(val)
    elif query == "exported_no_permission":
        count = 0
        for tag in ['activity', 'service', 'receiver', 'provider']:
            for elem in root.iter(tag):
                exported = elem.get('{http://schemas.android.com/apk/res/android}exported', '')
                permission = elem.get('{http://schemas.android.com/apk/res/android}permission', '')
                if exported == 'true' and not permission:
                    count += 1
        print(count)
    elif query == "dangerous_permissions":
        dangerous = [
            'READ_CONTACTS', 'WRITE_CONTACTS', 'READ_CALL_LOG',
            'WRITE_CALL_LOG', 'READ_SMS', 'RECEIVE_SMS', 'SEND_SMS',
            'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION',
            'READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE',
            'CAMERA', 'RECORD_AUDIO', 'READ_PHONE_STATE',
            'PROCESS_OUTGOING_CALLS', 'BODY_SENSORS',
            'MANAGE_EXTERNAL_STORAGE'
        ]
        found = []
        for perm in root.findall('uses-permission'):
            name = perm.get('{http://schemas.android.com/apk/res/android}name', '')
            short = name.replace('android.permission.', '')
            if short in dangerous:
                found.append(short)
        print(','.join(found))
except Exception as e:
    print('')
PYEOF
}

# ── Wrapper según parser disponible ──────────────────────────────────────────
get_value() {
  local query="$1"
  if [[ "$XML_PARSER" == "xmllint" ]]; then
    case "$query" in
      debuggable)
        xmllint --xpath "string(//application/@android:debuggable)" --format "$MANIFEST_PATH" 2>/dev/null || echo ""
        ;;
      allowBackup)
        xmllint --xpath "string(//application/@android:allowBackup)" --format "$MANIFEST_PATH" 2>/dev/null || echo ""
        ;;
      *)
        xpath_query_python "$query"
        ;;
    esac
  else
    xpath_query_python "$query"
  fi
}

# ── Auditar el manifest ────────────────────────────────────────────────────────
FINDINGS_COUNT=0
echo "=== AndroidManifest Audit: $MANIFEST_PATH ==="
echo ""

# 1. android:debuggable=true → CRITICAL
DEBUGGABLE=$(xpath_query_python "debuggable")
if [[ "$DEBUGGABLE" == "true" ]]; then
  echo "CRITICAL: android:debuggable=\"true\" — Debug mode habilitado en release build."
  echo "  Fix: Eliminar android:debuggable del <application> o establecer a false."
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
fi

# 2. android:allowBackup=true → HIGH
ALLOW_BACKUP=$(xpath_query_python "allowBackup")
if [[ "$ALLOW_BACKUP" == "true" || -z "$ALLOW_BACKUP" ]]; then
  # default es true si no está especificado
  echo "HIGH: android:allowBackup=\"true\" (default) — Backup ADB expone datos de la app."
  echo "  Fix: Establecer android:allowBackup=\"false\" en <application>."
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
fi

# 3. Componentes exportados sin permission → HIGH
EXPORTED_NO_PERM=$(xpath_query_python "exported_no_permission")
if [[ -n "$EXPORTED_NO_PERM" && "$EXPORTED_NO_PERM" -gt 0 ]]; then
  echo "HIGH: ${EXPORTED_NO_PERM} componentes exportados sin android:permission declarado."
  echo "  Fix: Añadir android:permission o establecer android:exported=\"false\" si no es necesario."
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
fi

# 4. Permisos peligrosos → MEDIUM
DANGEROUS_PERMS=$(xpath_query_python "dangerous_permissions")
if [[ -n "$DANGEROUS_PERMS" ]]; then
  echo "MEDIUM: Permisos peligrosos declarados: $DANGEROUS_PERMS"
  echo "  Fix: Revisar si todos son necesarios. Documentar justificación de negocio."
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
fi

echo ""
echo "=== Total findings: $FINDINGS_COUNT ==="

if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "PASS: No se encontraron issues críticos en el manifest."
  exit 0
else
  exit "$FINDINGS_COUNT"
fi
