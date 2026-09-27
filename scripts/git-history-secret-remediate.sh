#!/usr/bin/env bash
# SE-239 — Git history secret remediation helper
# Genera el comando BFG/git-filter-repo para purgar un secret del historial.
# IMPORTANTE: Solo genera el comando — NO lo ejecuta. El humano decide.
# Uso: bash scripts/git-history-secret-remediate.sh --commit <hash> --file <path>
set -uo pipefail

COMMIT=""
FILE_PATH=""
TOOL="git-filter-repo"   # default: preferido sobre BFG

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit)  COMMIT="$2";    shift 2 ;;
    --file)    FILE_PATH="$2"; shift 2 ;;
    --bfg)     TOOL="bfg";     shift   ;;
    --help|-h)
      echo "Uso: bash git-history-secret-remediate.sh --commit <hash> --file <path> [--bfg]"
      echo ""
      echo "  Genera el comando para purgar el secret del historial git."
      echo "  NO ejecuta nada. Solo muestra los pasos que debe ejecutar el humano."
      echo ""
      echo "  --commit  Hash del commit donde aparece el secret (puede ser parcial)"
      echo "  --file    Ruta del fichero con el secret"
      echo "  --bfg     Generar comando BFG en lugar de git-filter-repo (default)"
      exit 0 ;;
    *) echo "Parámetro desconocido: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$COMMIT" ]] && [[ -z "$FILE_PATH" ]]; then
  echo "ERROR: Se necesita al menos --commit o --file." >&2
  echo "Uso: bash git-history-secret-remediate.sh --commit <hash> --file <path>" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: No estás en un repositorio git." >&2
  exit 1
}

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  SE-239 — Git History Secret Remediation                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "ADVERTENCIA: La reescritura de historial es destructiva e irreversible."
echo "Requiere force-push y coordinación con todo el equipo."
echo ""
echo "Pasos ANTES de ejecutar:"
echo "  1. Rota el secret inmediatamente (no esperes a la limpieza del historial)."
echo "  2. Avisa a todos los colaboradores del repo."
echo "  3. Haz un backup completo del repo: cp -r <repo> <repo>.bak"
echo "  4. Verifica que tienes permisos de force-push en el remote."
echo ""

if [[ "$TOOL" == "git-filter-repo" ]]; then
  echo "── Opción A: git-filter-repo (recomendado) ──────────────────────────────"
  echo ""
  if [[ -n "$FILE_PATH" ]]; then
    echo "  # Instalar si no está disponible:"
    echo "  pip install git-filter-repo"
    echo ""
    echo "  # Purgar el fichero completo del historial:"
    echo "  cd $REPO_ROOT"
    echo "  git filter-repo --path \"$FILE_PATH\" --invert-paths"
    echo ""
    echo "  # O purgar solo el contenido sensible (regex sobre el fichero):"
    echo "  git filter-repo --replace-text <(echo 'SECRET_VALUE==>SECRET_VALUE=<REDACTED>')"
  else
    echo "  # Purgar commits afectados (requiere análisis manual previo):"
    echo "  cd $REPO_ROOT"
    echo "  git filter-repo --commit-callback '"
    echo "    if commit.original_id == b\"${COMMIT}\"[:20]:"
    echo "      # modificar según necesidad"
    echo "      pass"
    echo "  '"
  fi
  echo ""
else
  echo "── Opción B: BFG Repo Cleaner ───────────────────────────────────────────"
  echo ""
  echo "  # Descargar BFG:"
  echo "  curl -L https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar -o bfg.jar"
  echo ""
  if [[ -n "$FILE_PATH" ]]; then
    FILENAME="$(basename "$FILE_PATH")"
    echo "  # Eliminar un fichero del historial:"
    echo "  cd $REPO_ROOT"
    echo "  java -jar bfg.jar --delete-files \"$FILENAME\""
  fi
  echo ""
  echo "  # Reemplazar cadenas sensibles (crea passwords.txt con valores a eliminar):"
  echo "  java -jar bfg.jar --replace-text passwords.txt"
  echo ""
fi

echo "── Pasos DESPUÉS ────────────────────────────────────────────────────────"
echo ""
echo "  # Limpiar refs y hacer gc:"
echo "  cd $REPO_ROOT"
echo "  git reflog expire --expire=now --all"
echo "  git gc --prune=now --aggressive"
echo ""
echo "  # Force-push (requiere permisos y coordinación con el equipo):"
echo "  git push origin --force --all"
echo "  git push origin --force --tags"
echo ""
echo "  # Todos los colaboradores deben hacer:"
echo "  git fetch origin"
echo "  git reset --hard origin/<branch>"
echo ""
echo "  # Verificar que el secret ya no aparece:"
echo "  bash scripts/git-history-secret-scan.sh"
echo ""
echo "RECUERDA: git push --no-verify no reemplaza esta limpieza."
echo "          El secret sigue en el historial hasta que reescribas el historial."
echo ""
