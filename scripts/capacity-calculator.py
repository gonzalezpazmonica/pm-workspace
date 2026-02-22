#!/usr/bin/env python3
"""
capacity-calculator.py — Cálculo de capacidades del equipo
===========================================================
Calcula horas disponibles reales por persona, cruza con la carga asignada
y genera alertas de sobre/sub-asignación.

Uso:
  python3 scripts/capacity-calculator.py --items /tmp/sprint-items.json
  python3 scripts/capacity-calculator.py --capacities /tmp/capacities.json --items /tmp/sprint-items.json

Requiere: Python 3.8+
"""

import json
import argparse
import sys
from datetime import datetime, date, timedelta
from typing import Optional


# ── CONSTANTES (editar según tu entorno) ──────────────────────────────────────
TEAM_HOURS_PER_DAY: float = float(8)           # horas laborables por día
FOCUS_FACTOR: float = float(0.75)              # factor de foco (75% productivo)
OVERLOAD_THRESHOLD: float = float(1.0)         # > 100% = sobre-cargado
WARNING_THRESHOLD: float = float(0.85)         # 85-100% = al límite

# Festivos de la Comunidad de Madrid (actualizar anualmente)
FESTIVOS_2026: list[date] = [
    date(2026, 1, 1),   # Año Nuevo
    date(2026, 1, 6),   # Reyes
    date(2026, 4, 2),   # Jueves Santo
    date(2026, 4, 3),   # Viernes Santo
    date(2026, 5, 1),   # Día del Trabajo
    date(2026, 5, 2),   # Comunidad de Madrid
    date(2026, 10, 12), # Día de la Hispanidad
    date(2026, 11, 1),  # Todos los Santos
    date(2026, 11, 9),  # Almudena
    date(2026, 12, 6),  # Constitución
    date(2026, 12, 8),  # Inmaculada
    date(2026, 12, 25), # Navidad
]


# ── HELPERS ────────────────────────────────────────────────────────────────────
def dias_habiles_entre(inicio: date, fin: date, festivos: list[date] = None) -> list[date]:
    """Devuelve la lista de días hábiles entre inicio y fin (ambos incluidos)."""
    festivos = festivos or FESTIVOS_2026
    dias = []
    actual = inicio
    while actual <= fin:
        if actual.weekday() < 5 and actual not in festivos:  # L-V, no festivo
            dias.append(actual)
        actual += timedelta(days=1)
    return dias


def parse_date(s: str) -> date:
    """Parsea fecha en formato YYYY-MM-DD o YYYY-MM-DDTHH:MM:SSZ."""
    return datetime.fromisoformat(s[:10]).date()


def semaforo(ratio: float) -> str:
    """Devuelve el semáforo según el ratio de utilización."""
    if ratio > OVERLOAD_THRESHOLD:
        return "🔴 SOBRE-CARGADO"
    elif ratio > WARNING_THRESHOLD:
        return "🟡 AL LÍMITE"
    else:
        return "🟢 OK"


# ── CÁLCULO DE CAPACITY ────────────────────────────────────────────────────────
def calcular_capacity_persona(
    inicio_sprint: date,
    fin_sprint: date,
    horas_dia: float = TEAM_HOURS_PER_DAY,
    factor_foco: float = FOCUS_FACTOR,
    dias_off_persona: list[date] = None,
) -> dict:
    """Calcula la capacity real de una persona para el sprint."""
    dias_off_persona = dias_off_persona or []
    dias_habiles = dias_habiles_entre(inicio_sprint, fin_sprint)
    dias_disponibles = [d for d in dias_habiles if d not in dias_off_persona]

    horas_disponibles = len(dias_disponibles) * horas_dia * factor_foco

    return {
        "dias_habiles_sprint": len(dias_habiles),
        "dias_off": len(dias_off_persona),
        "dias_disponibles": len(dias_disponibles),
        "horas_por_dia": horas_dia,
        "factor_foco": factor_foco,
        "horas_disponibles": round(horas_disponibles, 1),
    }


def calcular_carga_por_persona(items: list[dict]) -> dict:
    """Agrupa el RemainingWork por persona desde los work items del sprint."""
    carga: dict = {}
    for item in items:
        persona = item.get("asignado") or item.get("fields", {}).get("System.AssignedTo", {})
        if isinstance(persona, dict):
            persona = persona.get("displayName", "Sin asignar")
        persona = persona or "Sin asignar"

        remaining = item.get("restante_h") or item.get("fields", {}).get(
            "Microsoft.VSTS.Scheduling.RemainingWork", 0
        ) or 0
        completed = item.get("completado_h") or item.get("fields", {}).get(
            "Microsoft.VSTS.Scheduling.CompletedWork", 0
        ) or 0

        if persona not in carga:
            carga[persona] = {"remaining_h": 0.0, "completed_h": 0.0, "items": 0}
        carga[persona]["remaining_h"] += float(remaining)
        carga[persona]["completed_h"] += float(completed)
        carga[persona]["items"] += 1

    return carga


# ── REPORTE ────────────────────────────────────────────────────────────────────
def generar_reporte(
    items: list[dict],
    capacities_config: Optional[dict] = None,
    inicio_sprint: Optional[date] = None,
    fin_sprint: Optional[date] = None,
    sprint_days_left: int = 0,
) -> None:
    """Genera el reporte de capacity en terminal."""

    carga = calcular_carga_por_persona(items)

    print("\n" + "=" * 70)
    print("  CAPACITY REPORT — SPRINT ACTUAL")
    print("=" * 70)

    if inicio_sprint and fin_sprint:
        print(f"  Período: {inicio_sprint.strftime('%d/%m/%Y')} → {fin_sprint.strftime('%d/%m/%Y')}")
        dias = dias_habiles_entre(inicio_sprint, fin_sprint)
        print(f"  Días hábiles del sprint: {len(dias)}")

    if sprint_days_left:
        capacity_restante = sprint_days_left * TEAM_HOURS_PER_DAY * FOCUS_FACTOR
        print(f"  Días restantes: {sprint_days_left} | Capacity restante por persona: {capacity_restante:.0f}h")

    print()
    print(f"  {'Persona':<22} {'Asignado':>10} {'Completado':>11} {'Disponible':>11} {'Util%':>7}  Estado")
    print("  " + "-" * 68)

    total_asignado = 0.0
    total_completado = 0.0
    alertas = []

    for persona, datos in sorted(carga.items()):
        asignado = datos["remaining_h"] + datos["completed_h"]
        completado = datos["completed_h"]

        # Capacity disponible (desde config o default)
        if capacities_config and persona in capacities_config:
            disponible = capacities_config[persona].get("horas_disponibles", TEAM_HOURS_PER_DAY * 10 * FOCUS_FACTOR)
        else:
            if inicio_sprint and fin_sprint:
                cap = calcular_capacity_persona(inicio_sprint, fin_sprint)
                disponible = cap["horas_disponibles"]
            else:
                disponible = TEAM_HOURS_PER_DAY * 10 * FOCUS_FACTOR  # default sprint 2 semanas

        ratio = asignado / disponible if disponible > 0 else 0
        estado = semaforo(ratio)

        print(f"  {persona:<22} {asignado:>9.1f}h {completado:>9.1f}h {disponible:>9.1f}h {ratio*100:>6.0f}%  {estado}")

        total_asignado += asignado
        total_completado += completado

        if ratio > OVERLOAD_THRESHOLD:
            alertas.append(f"⚠️  {persona}: SOBRE-CARGADO ({ratio*100:.0f}% de capacity)")
        elif ratio > WARNING_THRESHOLD:
            alertas.append(f"⚡ {persona}: AL LÍMITE ({ratio*100:.0f}% de capacity)")

    print("  " + "-" * 68)
    print(f"  {'TOTAL EQUIPO':<22} {total_asignado:>9.1f}h {total_completado:>9.1f}h")

    if alertas:
        print("\n  ALERTAS:")
        for alerta in alertas:
            print(f"    {alerta}")

    # Resumen de items por estado
    estados: dict = {}
    for item in items:
        estado_item = item.get("estado", "Desconocido")
        estados[estado_item] = estados.get(estado_item, 0) + 1

    print("\n  ITEMS POR ESTADO:")
    for estado_item, count in sorted(estados.items()):
        barra = "█" * count
        print(f"    {estado_item:<15} {barra} ({count})")

    print("=" * 70 + "\n")


# ── MAIN ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Calculadora de capacidades del equipo para Azure DevOps / Scrum"
    )
    parser.add_argument("--items", default="/tmp/sprint-items.json",
                        help="JSON con los work items del sprint")
    parser.add_argument("--capacities", default=None,
                        help="JSON con las capacidades de Azure DevOps (opcional)")
    parser.add_argument("--sprint-start", default=None,
                        help="Fecha inicio sprint (YYYY-MM-DD)")
    parser.add_argument("--sprint-end", default=None,
                        help="Fecha fin sprint (YYYY-MM-DD)")
    parser.add_argument("--sprint-days-left", type=int, default=0,
                        help="Días restantes del sprint (para alertas)")
    parser.add_argument("--team-hours-per-day", type=float, default=TEAM_HOURS_PER_DAY,
                        help="Horas de trabajo por día (default: 8)")
    parser.add_argument("--focus-factor", type=float, default=FOCUS_FACTOR,
                        help="Factor de foco (default: 0.75)")
    parser.add_argument("--output-json", action="store_true",
                        help="Emitir resultado en JSON en lugar de tabla legible")

    args = parser.parse_args()

    # Cargar work items
    try:
        with open(args.items) as f:
            data = json.load(f)
            # Soportar formato directo (lista) o formato de API (objeto con .value)
            items = data if isinstance(data, list) else data.get("value", [])
    except FileNotFoundError:
        print(f"[ERROR] Fichero de items no encontrado: {args.items}", file=sys.stderr)
        print("Ejecuta primero: ./scripts/azdevops-queries.sh items > /tmp/sprint-items.json", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON inválido en {args.items}: {e}", file=sys.stderr)
        sys.exit(1)

    # Cargar capacidades (opcional)
    capacities_config = None
    if args.capacities:
        try:
            with open(args.capacities) as f:
                capacities_config = json.load(f)
        except Exception as e:
            print(f"[WARN] No se pudo cargar capacidades: {e}", file=sys.stderr)

    # Parsear fechas de sprint
    inicio_sprint = parse_date(args.sprint_start) if args.sprint_start else None
    fin_sprint = parse_date(args.sprint_end) if args.sprint_end else None

    if args.output_json:
        # Salida en JSON para pipes
        carga = calcular_carga_por_persona(items)
        resultado = {
            "sprint": {
                "inicio": str(inicio_sprint) if inicio_sprint else None,
                "fin": str(fin_sprint) if fin_sprint else None,
                "dias_restantes": args.sprint_days_left,
            },
            "carga_por_persona": carga,
        }
        if inicio_sprint and fin_sprint:
            for persona in carga:
                cap = calcular_capacity_persona(inicio_sprint, fin_sprint)
                carga[persona]["horas_disponibles"] = cap["horas_disponibles"]
                ratio = (carga[persona]["remaining_h"] + carga[persona]["completed_h"]) / cap["horas_disponibles"]
                carga[persona]["utilizacion_pct"] = round(ratio * 100, 1)
                carga[persona]["estado"] = semaforo(ratio)
        print(json.dumps(resultado, indent=2, ensure_ascii=False))
    else:
        generar_reporte(
            items=items,
            capacities_config=capacities_config,
            inicio_sprint=inicio_sprint,
            fin_sprint=fin_sprint,
            sprint_days_left=args.sprint_days_left,
        )


if __name__ == "__main__":
    main()
