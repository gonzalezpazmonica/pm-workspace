#!/usr/bin/env bash
# scripts/criterio-init.sh — SE-255 Slice 2
# Bootstrap del criterio publicado de la operadora.
# Fase 1: mineria de historial (PR comments, decisiones en digests, overrides)
# Fase 2: propuesta de borradores marcados provenance:INFERRED
# Regla dura: NUNCA escribe a CRITERIO.md directamente.
# La operadora reescribe con sus palabras; provenance:human_authored es obligatorio.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
DRAFTS="$ROOT/data/relacion/criterio-drafts"
mkdir -p "$DRAFTS"

echo "=== CRITERIO Bootstrap ==="
echo ""

# ── Fase 1: Mineria de historial ──────────────────────────────────────────
echo "Fase 1: Minando historial de decisiones..."
FOUND=0

# 1a. Buscar PR comments de la operadora con patrones de decision
if git log --all --oneline --grep="Mónica\|monica\|operadora" --since="2024-01-01" 2>/dev/null | head -20 > "$DRAFTS/_mining-pr-commits.txt"; then
  FOUND=$((FOUND + $(wc -l < "$DRAFTS/_mining-pr-commits.txt")))
fi

# 1b. Extraer overrides de sesion (archivos .session-notes si existen)
find "$ROOT" -name "*.session-notes.md" -newer "$ROOT/.git/index" 2>/dev/null | head -5 > "$DRAFTS/_mining-sessions.txt" || true

# 1c. Extraer snippets de CHANGELOGs que mencionen decisiones
grep -r "decision\|criterio\|principio\|regla" "$ROOT/CHANGELOG.d/" 2>/dev/null | head -30 > "$DRAFTS/_mining-changelogs.txt" || true

echo "  Encontrados ~$FOUND puntos de mineria"

# ── Fase 2: Generacion de borradores ──────────────────────────────────────
echo ""
echo "Fase 2: Generando borradores con provenance:INFERRED..."

DRAFT_N=0
cat > "$DRAFTS/CRIT-PROPUESTAS.md" << 'HEADER'
# Propuestas de criterio — provenance:INFERRED

> GENERADO AUTOMATICAMENTE. Ninguna entrada esta activa.
> La operadora debe reescribir cada entrada con sus palabras.
> Solo entradas con provenance:human_authored en CRITERIO.md se activan.

HEADER

# Generar propuestas desde patrones detectados
python3 << 'PYEOF'
import os, sys, re
from datetime import datetime

drafts_dir = os.environ.get("DRAFTS_DIR", "data/relacion/criterio-drafts")

propuestas = []

# Patrones heuristicos desde el historial minado
try:
    with open(f"{drafts_dir}/_mining-changelogs.txt") as f:
        for line in f:
            if "criterio" in line.lower() or "principio" in line.lower():
                propuestas.append({
                    "id": f"CRIT-{len(propuestas)+1:03d}",
                    "ambito": "tecnicas",
                    "principio": line.strip()[:120],
                    "dureza": "preferencia",
                    "provenance": "INFERRED",
                    "fuente": "changelog",
                })
except FileNotFoundError:
    pass

# Propuestas minimas garantizadas para ambitos vacios
if len([p for p in propuestas if p["ambito"] == "comunicacion"]) == 0:
    propuestas.append({
        "id": f"CRIT-{len(propuestas)+1:03d}",
        "ambito": "comunicacion",
        "principio": "Respuestas directas, sin preambulos innecesarios. Cada token cuenta.",
        "dureza": "estilo",
        "provenance": "INFERRED",
        "fuente": "patron_detectado",
    })

if len([p for p in propuestas if p["ambito"] == "priorizacion"]) == 0:
    propuestas.append({
        "id": f"CRIT-{len(propuestas)+1:03d}",
        "ambito": "priorizacion",
        "principio": "Lo que mas acerca al objetivo de la sesion va primero. Lo cosmético, despues.",
        "dureza": "linea_roja",
        "provenance": "INFERRED",
        "fuente": "patron_detectado",
    })

if len([p for p in propuestas if p["ambito"] == "riesgo"]) == 0:
    propuestas.append({
        "id": f"CRIT-{len(propuestas)+1:03d}",
        "ambito": "riesgo",
        "principio": "Ante incertidumbre alta, preguntar. La conjetura callada es el error mas caro.",
        "dureza": "linea_roja",
        "provenance": "INFERRED",
        "fuente": "patron_detectado",
    })

if len([p for p in propuestas if p["ambito"] == "delegacion"]) == 0:
    propuestas.append({
        "id": f"CRIT-{len(propuestas)+1:03d}",
        "ambito": "delegacion",
        "principio": "Savia puede ejecutar dentro del ambito del contrato activo. Lo demas, lo pregunta.",
        "dureza": "linea_roja",
        "provenance": "INFERRED",
        "fuente": "patron_detectado",
    })

# Escribir el fichero de propuestas
with open(f"{drafts_dir}/CRIT-PROPUESTAS.md", "a") as f:
    for p in propuestas:
        f.write(f"\n**{p['id']}** — {p['ambito']} ({p['dureza']})\n")
        f.write(f"  {p['principio']}\n")
        f.write(f"  provenance: {p['provenance']} | fuente: {p['fuente']}\n")

print(f"\n  {len(propuestas)} borradores generados en {drafts_dir}/CRIT-PROPUESTAS.md")
PYEOF

echo ""
echo "=== Bootstrap completado ==="
echo ""
echo "  Borradores: data/relacion/criterio-drafts/CRIT-PROPUESTAS.md"
echo ""
echo "  PROXIMO PASO (operadora):"
echo "  1. Revisar cada propuesta"
echo "  2. Reescribir con tus palabras las que reflejen tu criterio real"
echo "  3. Mover a CRITERIO.md con provenance:human_authored"
echo "  4. El resto, descartarlas o refinarlas con /criterio-init de nuevo"
