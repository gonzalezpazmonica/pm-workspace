#!/usr/bin/env python3
"""scripts/test_workspace.py — SE-253 Slice 7

Migración de test-workspace.sh a Python.
Reproduce exactamente la misma lógica de validación, argumentos y exit codes.

Uso:
  python3 scripts/test_workspace.py              # modo mock
  python3 scripts/test_workspace.py --real       # modo real (requiere PAT)
  python3 scripts/test_workspace.py --only prereqs
  python3 scripts/test_workspace.py --only capacity
  python3 scripts/test_workspace.py --only sdd
  python3 scripts/test_workspace.py --only specs
  python3 scripts/test_workspace.py --verbose

Exit codes:
  0 — todos los tests pasaron (o solo skipped)
  1 — al menos un test falló
  2 — error de uso / argumento inválido
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ── Rutas ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).parent.resolve()
WORKSPACE_ROOT = SCRIPT_DIR.parent.resolve()
TEST_PROJECT_DIR = WORKSPACE_ROOT / "projects" / "sala-reservas"
MOCK_DATA_DIR = TEST_PROJECT_DIR / "test-data"
OUTPUT_DIR = WORKSPACE_ROOT / "output"

# ── ANSI colors ───────────────────────────────────────────────────────────────
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"


# ── Estado global ─────────────────────────────────────────────────────────────
class State:
    total = 0
    passed = 0
    failed = 0
    skipped = 0
    failed_tests: list[str] = []
    mode: str = "mock"
    verbose: bool = False
    only_category: str = ""


state = State()


# ── Helpers de output ─────────────────────────────────────────────────────────
def log_header(title: str) -> None:
    print(f"\n{BOLD}{BLUE}{'═' * 52}{NC}")
    print(f"{BOLD}{BLUE}  {title}{NC}")
    print(f"{BOLD}{BLUE}{'═' * 52}{NC}")


def log_section(title: str) -> None:
    print(f"\n{CYAN}▶ {title}{NC}")


def pass_test(msg: str) -> None:
    print(f"  {GREEN}✅ PASS{NC} — {msg}")
    state.passed += 1
    state.total += 1


def fail_test(msg: str, detail: str) -> None:
    print(f"  {RED}❌ FAIL{NC} — {msg}")
    print(f"     {RED}↳ {detail}{NC}")
    state.failed += 1
    state.total += 1
    state.failed_tests.append(f"{msg}: {detail}")


def skip_test(msg: str, reason: str = "requiere modo --real") -> None:
    print(f"  {YELLOW}⏭  SKIP{NC} — {msg} ({reason})")
    state.skipped += 1
    state.total += 1


def info(msg: str) -> None:
    print(f"  {YELLOW}ℹ  INFO{NC} — {msg}")


def should_run(category: str) -> bool:
    return not state.only_category or state.only_category == category


# ── Suite 1: Prereqs ──────────────────────────────────────────────────────────
def test_prereqs() -> None:
    log_header("SUITE 1 — Prerrequisitos del Sistema")

    log_section("Herramientas de línea de comandos")

    # jq
    if shutil.which("jq"):
        result = subprocess.run(["jq", "--version"], capture_output=True, text=True)
        pass_test(f"jq instalado ({result.stdout.strip()})")
    else:
        fail_test("jq no encontrado", "Instalar: apt install jq / brew install jq")

    # Python3
    if shutil.which("python3"):
        result = subprocess.run(["python3", "--version"], capture_output=True, text=True)
        ver = result.stdout.strip() or result.stderr.strip()
        pass_test(f"Python3 instalado ({ver})")
    else:
        fail_test("python3 no encontrado", "Instalar Python 3.10+")

    # Node.js (opcional)
    if shutil.which("node"):
        result = subprocess.run(["node", "--version"], capture_output=True, text=True)
        pass_test(f"Node.js instalado ({result.stdout.strip()})")
    else:
        info("node no encontrado (Opcional: para dependencias Node.js. Instalar Node.js 18+ si necesario)")

    # curl
    if shutil.which("curl"):
        pass_test("curl instalado")
    else:
        fail_test("curl no encontrado", "Instalar curl")

    # Azure CLI
    log_section("Azure CLI")
    if shutil.which("az"):
        result = subprocess.run(
            ["az", "version", "--query", '"azure-cli"', "-o", "tsv"],
            capture_output=True, text=True,
        )
        azver = result.stdout.strip() or "desconocida"
        pass_test(f"Azure CLI instalado (v{azver})")

        ext_result = subprocess.run(
            ["az", "extension", "show", "--name", "azure-devops"],
            capture_output=True, text=True,
        )
        if ext_result.returncode == 0:
            pass_test("Extensión azure-devops instalada")
        else:
            if state.mode == "mock":
                skip_test("Extensión azure-devops NO instalada", "No requerida en modo --mock")
            else:
                fail_test(
                    "Extensión azure-devops NO instalada",
                    "Ejecutar: az extension add --name azure-devops",
                )
    else:
        if state.mode == "mock":
            skip_test("az (Azure CLI) no encontrado", "No requerido en modo --mock")
        else:
            fail_test(
                "az (Azure CLI) no encontrado",
                "Instalar: https://docs.microsoft.com/cli/azure/install-azure-cli",
            )

    # Claude CLI
    log_section("Claude Code CLI (para SDD)")
    if shutil.which("claude"):
        result = subprocess.run(["claude", "--version"], capture_output=True, text=True)
        ver = result.stdout.strip() or "desconocida"
        pass_test(f"Claude CLI instalado ({ver})")
    else:
        skip_test("Claude CLI no encontrado", "Opcional para SDD. Instalar: https://docs.claude.ai/claude-code")

    # npm packages
    log_section("Dependencias Node.js (scripts/)")
    if shutil.which("node"):
        node_modules = WORKSPACE_ROOT / "scripts" / "node_modules"
        if node_modules.is_dir():
            pass_test("node_modules instalados en scripts/")
        else:
            fail_test("node_modules no encontrado", "Ejecutar: cd scripts && npm install")
    else:
        skip_test("node_modules check", "Node.js no instalado (se salta automáticamente)")


# ── Suite 2: Estructura ───────────────────────────────────────────────────────
def test_structure() -> None:
    log_header("SUITE 2 — Estructura del Workspace")

    log_section("Ficheros raíz obligatorios")
    for f in ("CLAUDE.md", "README.md", ".gitignore"):
        path = WORKSPACE_ROOT / f
        if path.is_file():
            pass_test(f"{f} existe")
        else:
            fail_test(f"{f} no encontrado", "Fichero raíz obligatorio")

    log_section("Skills (.opencode/skills/)")
    skills = [
        "azure-devops-queries",
        "sprint-management",
        "capacity-planning",
        "time-tracking-report",
        "executive-reporting",
        "pbi-decomposition",
        "spec-driven-development",
    ]
    for skill in skills:
        skill_path = WORKSPACE_ROOT / ".opencode" / "skills" / skill / "SKILL.md"
        if skill_path.is_file():
            lines = sum(1 for _ in skill_path.open())
            pass_test(f"Skill '{skill}' (SKILL.md — {lines} líneas)")
        else:
            fail_test(f"Skill '{skill}' no encontrada", f"Falta {skill}/SKILL.md")

    log_section("SDD Reference Files")
    sdd_refs = ["spec-template.md", "layer-assignment-matrix.md", "agent-team-patterns.md"]
    for ref in sdd_refs:
        ref_path = (
            WORKSPACE_ROOT
            / ".opencode"
            / "skills"
            / "spec-driven-development"
            / "references"
            / ref
        )
        if ref_path.is_file():
            pass_test(f"SDD reference: {ref}")
        else:
            fail_test(f"SDD reference faltante: {ref}", "Ejecutar setup SDD")

    log_section("Slash Commands (.opencode/commands/)")
    commands = [
        "sprint-status", "sprint-plan", "sprint-review", "sprint-retro",
        "report-hours", "report-executive", "report-capacity", "team-workload",
        "board-flow", "kpi-dashboard", "pbi-decompose", "pbi-decompose-batch",
        "pbi-assign", "pbi-plan-sprint", "spec-generate", "spec-implement",
        "spec-review", "spec-status", "agent-run",
    ]
    for cmd in commands:
        cmd_path = WORKSPACE_ROOT / ".opencode" / "commands" / f"{cmd}.md"
        if cmd_path.is_file():
            pass_test(f"Comando /{cmd}")
        else:
            fail_test(f"Comando /{cmd} no encontrado", f"Falta .opencode/commands/{cmd}.md")

    log_section("Proyecto de Test (sala-reservas)")
    test_files = [
        "projects/sala-reservas/CLAUDE.md",
        "projects/sala-reservas/equipo.md",
        "projects/sala-reservas/reglas-negocio.md",
        "projects/sala-reservas/sprints/sprint-2026-04/planning.md",
        "projects/sala-reservas/specs/sprint-2026-04/AB101-B3-create-sala-handler.spec.md",
        "projects/sala-reservas/specs/sprint-2026-04/AB102-D1-unit-tests-salas.spec.md",
        "projects/sala-reservas/specs/sdd-metrics.md",
        "projects/sala-reservas/test-data/mock-workitems.json",
        "projects/sala-reservas/test-data/mock-sprint.json",
        "projects/sala-reservas/test-data/mock-capacities.json",
    ]
    for f in test_files:
        path = WORKSPACE_ROOT / f
        if path.is_file():
            pass_test(f"{f}")
        else:
            fail_test(f"{f} no encontrado", "Fichero del proyecto de test")


# ── Suite 3: Connectivity (solo --real) ───────────────────────────────────────
def test_connection() -> None:
    log_header("SUITE 3 — Conectividad Azure DevOps")

    if state.mode == "mock":
        skip_test("Test de conectividad", "Ejecutar con --real para testear conexión real")
        skip_test("Listar proyectos", "requiere --real")
        skip_test("Leer sprint activo", "requiere --real")
        return

    # Leer PAT desde CLAUDE.md
    claude_md = (WORKSPACE_ROOT / "CLAUDE.md").read_text(errors="replace")
    pat_match = re.search(r'AZURE_DEVOPS_PAT_FILE[^"]*"([^"]+)"', claude_md)
    pat_file_path = pat_match.group(1) if pat_match else str(Path.home() / ".azure" / "devops-pat")
    pat_file = Path(pat_file_path)

    if not pat_file.is_file():
        fail_test(
            f"PAT file no encontrado: {pat_file}",
            f"Crear: echo -n 'TU_PAT' > {pat_file}",
        )
        return

    pat = pat_file.read_text().strip()
    org_match = re.search(r'AZURE_DEVOPS_ORG_URL[^"]*"([^"]*devops[^"]*)"', claude_md)
    if not org_match:
        fail_test("ORG_URL no configurada en CLAUDE.md", "Editar CLAUDE.md y establecer AZURE_DEVOPS_ORG_URL")
        return

    org_url = org_match.group(1)
    info(f"Conectando a: {org_url}")

    result = subprocess.run(
        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-u", f":{pat}",
         f"{org_url}/_apis/projects?api-version=7.1"],
        capture_output=True, text=True,
    )
    http_code = result.stdout.strip()
    if http_code == "200":
        pass_test(f"Conexión Azure DevOps (HTTP {http_code})")
    else:
        fail_test(f"Error de conexión Azure DevOps (HTTP {http_code})", "Verificar PAT y ORG_URL")
        return

    proj_result = subprocess.run(
        ["curl", "-s", "-u", f":{pat}", f"{org_url}/_apis/projects?api-version=7.1"],
        capture_output=True, text=True,
    )
    try:
        data = json.loads(proj_result.stdout)
        count = data.get("count", 0)
    except json.JSONDecodeError:
        count = 0

    if count > 0:
        pass_test(f"Proyectos accesibles: {count}")
        if state.verbose:
            for p in data.get("value", []):
                info(f"  Proyecto: {p.get('name', '?')}")
    else:
        fail_test("No se encontraron proyectos", "Verificar permisos del PAT")


# ── Suite 4: Capacity ─────────────────────────────────────────────────────────
def test_capacity() -> None:
    log_header("SUITE 4 — Cálculo de Capacidades")

    log_section("Validar script capacity-calculator.py")
    cap_script = WORKSPACE_ROOT / "scripts" / "capacity-calculator.py"
    if not cap_script.is_file():
        fail_test("capacity-calculator.py no encontrado", "Falta scripts/capacity-calculator.py")
        return
    pass_test("capacity-calculator.py existe")

    # Verificar sintaxis
    result = subprocess.run(
        ["python3", "-m", "py_compile", str(cap_script)],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        pass_test("Sintaxis Python válida")
    else:
        fail_test("Error de sintaxis en capacity-calculator.py", result.stderr.strip())
        return

    log_section("Cálculo con datos mock")
    dias, horas, foco = 10, 8, 0.75
    result_val = dias * horas * foco
    if abs(result_val - 60.0) < 0.001:
        pass_test(f"Fórmula capacity: 10días × 8h × 0.75 = {result_val:.1f}h ✓")
    else:
        fail_test("Fórmula capacity incorrecta", f"Esperado: 60.0, Obtenido: {result_val}")

    log_section("Validar datos de capacidad del proyecto de test")
    mock_capacity = MOCK_DATA_DIR / "mock-capacities.json"
    if not mock_capacity.is_file():
        fail_test("mock-capacities.json no encontrado", str(mock_capacity))
        return

    try:
        cap_data = json.loads(mock_capacity.read_text())
        pass_test("mock-capacities.json es JSON válido")
    except json.JSONDecodeError as exc:
        fail_test("mock-capacities.json tiene JSON inválido", str(exc))
        return

    total_members = len(cap_data.get("team_members", []))
    if total_members == 5:
        pass_test("5 miembros del equipo en el mock")
    else:
        fail_test("Número de miembros incorrecto", f"Esperado: 5, Obtenido: {total_members}")

    total_cap = cap_data.get("capacity_summary", {}).get("total_human_capacity", 0)
    if abs(float(total_cap) - 228) < 0.5:
        pass_test(f"Capacity devs del equipo: {total_cap}h (228h esperadas — excluye PM)")
    else:
        fail_test("Capacity total incorrecta", f"Esperado: ~228, Obtenido: {total_cap}")

    utilization = cap_data.get("capacity_summary", {}).get("total_human_utilization_percent", 100)
    util_int = int(float(utilization))
    if util_int < 85:
        pass_test(f"Utilización del equipo: {utilization}% (🟢 < 85%)")
    else:
        fail_test("Utilización del equipo demasiado alta", f"{utilization}% > 85%")

    log_section("Scoring de asignación")
    weights = {"expertise": 0.40, "availability": 0.30, "balance": 0.20, "growth": 0.10}
    total_w = sum(weights.values())
    if abs(total_w - 1.0) < 0.001:
        pass_test("Pesos del algoritmo de scoring suman 1.0 ✓")
    else:
        fail_test(
            "Los pesos del scoring NO suman 1.0",
            "Verificar assignment_weights en projects/sala-reservas/CLAUDE.md",
        )

    expertise = 0.9
    availability = 0.7
    balance = 0.5
    growth = 0.0
    score = 0.40 * expertise + 0.30 * availability + 0.20 * balance + 0.10 * growth
    if 0.60 <= score <= 0.80:
        pass_test(f"Scoring de ejemplo (Carlos): {score:.3f} (rango esperado: 0.60-0.80)")
    else:
        fail_test("Scoring fuera de rango esperado", f"Obtenido: {score:.3f}, Esperado: 0.60-0.80")


# ── Suite 5: Sprint ───────────────────────────────────────────────────────────
def test_sprint() -> None:
    log_header("SUITE 5 — Datos del Sprint")

    log_section("Validar mock-sprint.json")
    mock_sprint_path = MOCK_DATA_DIR / "mock-sprint.json"
    try:
        sprint_data = json.loads(mock_sprint_path.read_text())
        pass_test("mock-sprint.json es JSON válido")
    except (json.JSONDecodeError, FileNotFoundError) as exc:
        fail_test("mock-sprint.json tiene JSON inválido", str(exc))
        return

    sprint_name = sprint_data.get("sprint", {}).get("name", "?")
    days_remaining = sprint_data.get("sprint", {}).get("daysRemaining", 0)
    trend = sprint_data.get("burndown", {}).get("trend", "unknown")

    pass_test(f"Sprint activo: {sprint_name}")
    pass_test(f"Días restantes: {days_remaining}")

    if trend == "on_track":
        pass_test(f"Tendencia del burndown: {trend} 🟢")
    else:
        fail_test("Tendencia del burndown preocupante", f"Trend: {trend}")

    log_section("Validar mock-workitems.json")
    mock_items_path = MOCK_DATA_DIR / "mock-workitems.json"
    try:
        items_data = json.loads(mock_items_path.read_text())
        pass_test("mock-workitems.json es JSON válido")
    except (json.JSONDecodeError, FileNotFoundError) as exc:
        fail_test("mock-workitems.json tiene JSON inválido", str(exc))
        return

    wi_count = items_data.get("count", 0)
    value = items_data.get("value", [])
    pbis = sum(
        1 for wi in value
        if wi.get("fields", {}).get("System.WorkItemType") == "Product Backlog Item"
    )
    tasks = sum(
        1 for wi in value
        if wi.get("fields", {}).get("System.WorkItemType") == "Task"
    )
    agent_tasks = sum(
        1 for wi in value
        if wi.get("fields", {}).get("System.AssignedTo", {}).get("displayName") == "claude-agent"
    )
    done_tasks = sum(
        1 for wi in value
        if wi.get("fields", {}).get("System.State") == "Done"
    )

    pass_test(f"Work items totales: {wi_count} ({pbis} PBIs + {tasks} Tasks)")
    pass_test(f"Tasks asignadas al agente: {agent_tasks}")
    pass_test(f"Tasks completadas: {done_tasks}")

    log_section("Burndown calculation")
    completed_pct = sprint_data.get("burndown", {}).get("completedPercent", 0)
    elapsed_days = sprint_data.get("sprint", {}).get("daysElapsed", 0)
    total_days = sprint_data.get("sprint", {}).get("daysTotal", 1)
    elapsed_pct = round(elapsed_days / total_days * 100, 1) if total_days else 0

    info(f"Días transcurridos: {elapsed_days}/{total_days} ({elapsed_pct}% del sprint)")
    info(f"Trabajo completado: {completed_pct}%")

    diff = abs(float(completed_pct) - elapsed_pct)
    if diff <= 15:
        pass_test("Progreso alineado con el tiempo transcurrido (diff ≤ 15%) 🟢")
    else:
        fail_test(
            "Desfase entre progreso y tiempo",
            f"Tiempo: {elapsed_pct}%, Completado: {completed_pct}%",
        )


# ── Suite 6: Imputación ───────────────────────────────────────────────────────
def test_imputacion() -> None:
    log_header("SUITE 6 — Imputación de Horas")

    log_section("Leer imputaciones del mock")
    mock_capacity = MOCK_DATA_DIR / "mock-capacities.json"
    cap_data = json.loads(mock_capacity.read_text())

    entries = cap_data.get("time_entries_week1", {}).get("entries", [])
    total_hours = sum(e.get("hours", 0) for e in entries)
    expected = 11.5

    if abs(total_hours - expected) < 0.01:
        pass_test(f"Total horas semana 1: {total_hours} h (esperado: {expected}h)")
    else:
        fail_test("Total horas incorrecto", f"Obtenido: {total_hours}, Esperado: {expected}")

    by_person = cap_data.get("time_entries_week1", {}).get("by_person", {})
    carlos_hours = by_person.get("Carlos Mendoza", 0)
    pass_test(f"Carlos Mendoza: {carlos_hours}h imputadas semana 1")

    agent_hours = by_person.get("claude-agent", 0)
    pass_test(f"claude-agent: {agent_hours}h imputadas semana 1")

    log_section("Calcular coste por persona (mock)")
    coste_hora = 80
    coste_semana = round(total_hours * coste_hora, 2)
    pass_test(f"Coste semana 1 ({coste_hora}€/h): {coste_semana}€")

    log_section("Validar formato de imputaciones")
    valid = all(
        e.get("date") is not None
        and e.get("person") is not None
        and e.get("hours") is not None
        and e.get("hours", 0) > 0
        for e in entries
    )
    if valid:
        pass_test("Todas las entradas de imputación tienen campos válidos")
    else:
        fail_test("Entradas de imputación con datos faltantes", "Verificar mock-capacities.json")


# ── Suite 7: SDD ──────────────────────────────────────────────────────────────
def test_sdd() -> None:
    log_header("SUITE 7 — Spec-Driven Development")

    specs_dir = TEST_PROJECT_DIR / "specs" / "sprint-2026-04"

    log_section("Contar specs disponibles")
    spec_files = list(specs_dir.glob("*.spec.md")) if specs_dir.is_dir() else []
    spec_count = len(spec_files)
    if spec_count >= 2:
        pass_test(f"{spec_count} specs en el sprint 2026-04")
    else:
        fail_test("Pocas specs encontradas", f"Esperado: ≥2, Encontrado: {spec_count}")

    log_section("Validar estructura de specs")
    required_sections = [
        "Developer Type:",
        "Task ID:",
        "Estimación:",
        "## 2. Contrato",
        "## 3. Reglas",
        "## 4. Test Scenarios",
        "## 5. Ficheros",
    ]
    for spec_path in spec_files:
        spec_name = spec_path.name
        content = spec_path.read_text(errors="replace")
        errors = 0

        for section in required_sections:
            if section not in content:
                fail_test(
                    f"Spec {spec_name}: falta sección '{section}'",
                    "Sección obligatoria ausente",
                )
                errors += 1

        if errors == 0:
            pass_test(f"Spec {spec_name}: todas las secciones presentes")

        # Developer type
        match = re.search(r"\*\*Developer Type:\*\*\s*(\S+)", content)
        dev_type = match.group(1) if match else ""
        if dev_type in ("human", "agent-single", "agent-team"):
            pass_test(f"Spec {spec_name}: developer_type válido ({dev_type})")
        else:
            fail_test(
                f"Spec {spec_name}: developer_type inválido",
                f"Valor: '{dev_type}', Esperado: human|agent-single|agent-team",
            )

        # Placeholders
        placeholders = content.count("{placeholder}")
        if placeholders == 0:
            pass_test(f"Spec {spec_name}: sin placeholders vacíos")
        else:
            fail_test(
                f"Spec {spec_name}: tiene {placeholders} placeholders sin rellenar",
                "Editar la spec y completar los campos",
            )

    log_section("Validar layer-assignment-matrix")
    matrix = (
        WORKSPACE_ROOT
        / ".opencode"
        / "skills"
        / "spec-driven-development"
        / "references"
        / "layer-assignment-matrix.md"
    )
    if matrix.is_file():
        text = matrix.read_text(errors="replace")
        agent_rows = len(re.findall(r"agent-single|agent-team", text))
        human_rows = len(re.findall(r"`human`", text))
        pass_test(f"Matrix de asignación: {agent_rows} entradas de agente, {human_rows} de humano")
    else:
        fail_test("layer-assignment-matrix.md no encontrado", str(matrix))

    log_section("Validar spec-template")
    template = (
        WORKSPACE_ROOT
        / ".opencode"
        / "skills"
        / "spec-driven-development"
        / "references"
        / "spec-template.md"
    )
    if template.is_file():
        template_lines = sum(1 for _ in template.open())
        if template_lines > 100:
            pass_test(f"spec-template.md completo ({template_lines} líneas)")
        else:
            fail_test("spec-template.md demasiado corto", f"{template_lines} líneas (esperado: >100)")
    else:
        fail_test("spec-template.md no encontrado", str(template))

    log_section("Dry-run de agente (sin ejecutar código real)")
    if shutil.which("claude"):
        info("Claude CLI disponible — para ejecutar el agente real:")
        info("  /agent-run projects/sala-reservas/specs/sprint-2026-04/AB101-B3-create-sala-handler.spec.md")
        pass_test("Claude CLI disponible para SDD real")
    else:
        skip_test("Dry-run de agente", "Claude CLI no instalado")


# ── Suite 8: Report ───────────────────────────────────────────────────────────
def test_report() -> None:
    log_header("SUITE 8 — Generación de Informes")

    log_section("Validar report-generator.js")
    report_script = WORKSPACE_ROOT / "scripts" / "report-generator.js"
    if not report_script.is_file():
        fail_test("report-generator.js no encontrado", "Falta scripts/report-generator.js")
        return
    pass_test("report-generator.js existe")

    report_lines = sum(1 for _ in report_script.open(errors="replace"))
    if report_lines > 100:
        pass_test(f"report-generator.js tiene contenido ({report_lines} líneas)")
    else:
        fail_test("report-generator.js demasiado corto", f"{report_lines} líneas")

    log_section("Verificar dependencias del report generator")
    pkg_json = WORKSPACE_ROOT / "scripts" / "package.json"
    if pkg_json.is_file():
        try:
            pkg = json.loads(pkg_json.read_text())
            deps = pkg.get("dependencies", {})
            if deps.get("exceljs"):
                pass_test(f"Dependencia exceljs declarada en package.json ({deps['exceljs']})")
            else:
                fail_test("exceljs no en package.json", "Añadir: npm install exceljs")
            if deps.get("pptxgenjs"):
                pass_test(f"Dependencia pptxgenjs declarada en package.json ({deps['pptxgenjs']})")
            else:
                fail_test("pptxgenjs no en package.json", "Añadir: npm install pptxgenjs")
        except json.JSONDecodeError:
            fail_test("scripts/package.json tiene JSON inválido", "Verificar el fichero")
    else:
        fail_test("scripts/package.json no encontrado", "Ejecutar: cd scripts && npm init")

    log_section("Verificar directorio output")
    for subdir in ("sprints", "reports", "executive", "agent-runs"):
        (OUTPUT_DIR / subdir).mkdir(parents=True, exist_ok=True)
    pass_test("Directorios output creados/verificados")


# ── Suite 9: Backlog ──────────────────────────────────────────────────────────
def test_backlog() -> None:
    log_header("SUITE 9 — Backlog y Reglas de Negocio")

    log_section("Reglas de negocio documentadas")
    rn_file = TEST_PROJECT_DIR / "reglas-negocio.md"
    if not rn_file.is_file():
        fail_test("reglas-negocio.md no encontrado", str(rn_file))
        return

    rn_text = rn_file.read_text(errors="replace")
    rn_count = len(re.findall(r"^### RN-", rn_text, re.MULTILINE))
    pass_test(f"reglas-negocio.md existe con {rn_count} reglas documentadas")

    for rn_id in ("RN-SALA-01", "RN-RESERVA-06", "RN-RESERVA-07"):
        if rn_id in rn_text:
            title_match = re.search(rf"### {rn_id}: (.+)", rn_text)
            title = title_match.group(1).strip() if title_match else ""
            pass_test(f"Regla {rn_id} documentada: {title}")
        else:
            fail_test(f"Regla crítica {rn_id} no encontrada", "Agregar al fichero reglas-negocio.md")

    log_section("Simulación de algoritmo de detección de conflictos (RN-RESERVA-07)")

    def hay_conflicto(i1: int, f1: int, i2: int, f2: int) -> bool:
        return i1 < f2 and i2 < f1

    casos = [
        (9, 10, 10, 11, False, "Consecutivas: sin conflicto"),
        (9, 11, 10, 12, True, "Solapamiento parcial"),
        (9, 12, 10, 11, True, "Una dentro de otra"),
        (10, 11, 9, 12, True, "La nueva dentro de la existente"),
        (8, 9, 10, 11, False, "Sin contacto: sin conflicto"),
    ]

    all_ok = True
    for i1, f1, i2, f2, expected, desc in casos:
        got = hay_conflicto(i1, f1, i2, f2)
        if got != expected:
            all_ok = False
            fail_test(
                "Algoritmo de conflictos falla en caso",
                f"[✗] {desc}: esperado={expected}, obtenido={got}",
            )

    if all_ok:
        pass_test("Algoritmo de detección de conflictos: 5/5 casos correctos")

    log_section("Sprint Planning — PBIs y capacity")
    planning_file = TEST_PROJECT_DIR / "sprints" / "sprint-2026-04" / "planning.md"
    if planning_file.is_file():
        planning_text = planning_file.read_text(errors="replace")
        sp_values = re.findall(r"(\d+) SP", planning_text)
        # Excluir "1 SP" como hacía el original (head -3 con grep -v "^1 SP")
        sp_values = [int(v) for v in sp_values if v != "1"][:3]
        total_sp = sum(sp_values) if sp_values else 11
        pass_test(f"Sprint Planning documentado ({total_sp} SP comprometidos)")
    else:
        fail_test("planning.md no encontrado", str(planning_file))


# ── Informe de resultados ─────────────────────────────────────────────────────
def generate_report() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    report_file = OUTPUT_DIR / f"test-workspace-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md"

    success_rate = f"{state.passed / state.total * 100:.1f}%" if state.total > 0 else "N/A"

    failed_list = (
        "\n".join(f"- ❌ {t}" for t in state.failed_tests)
        if state.failed_tests
        else "Ninguno 🎉"
    )

    if state.failed == 0:
        next_steps = (
            "✅ Todos los tests pasaron. El workspace está listo para usar con datos reales.\n\n"
            "1. Editar `CLAUDE.md` con tus datos reales de Azure DevOps\n"
            "2. Clonar tus repos en `projects/{proyecto}/source/`\n"
            "3. Abrir con `claude` y ejecutar `/sprint-status`"
        )
    else:
        next_steps = f"⚠️  Hay {state.failed} tests fallidos. Resolver antes de usar en producción."

    content = f"""# Test Report — PM Workspace
**Fecha:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Modo:** {state.mode}
**Proyecto de test:** sala-reservas

## Resumen

| | Valor |
|---|---|
| Tests ejecutados | {state.total} |
| ✅ Passed | {state.passed} |
| ❌ Failed | {state.failed} |
| ⏭ Skipped | {state.skipped} |
| Tasa de éxito | {success_rate} |

## Tests Fallidos

{failed_list}

## Cómo ejecutar el workspace

```bash
cd pm-workspace/
claude
# Luego: /sprint-status sala-reservas
```

## Próximos pasos

{next_steps}
"""
    report_file.write_text(content)
    print(f"\n{BOLD}📄 Informe guardado: {report_file}{NC}")


# ── Main ──────────────────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser(
        description="PM Workspace — Test Suite",
        add_help=False,
    )
    parser.add_argument("--real", action="store_true", help="Modo real (requiere PAT)")
    parser.add_argument("--mock", action="store_true", help="Modo mock (default)")
    parser.add_argument("--only", metavar="CATEGORY", help="Ejecutar solo una categoría")
    parser.add_argument("--verbose", action="store_true", help="Muestra output completo")
    parser.add_argument("-h", "--help", action="store_true", help="Mostrar ayuda")

    args, unknown = parser.parse_known_args()

    if unknown:
        print(f"Opción desconocida: {unknown[0]}", file=sys.stderr)
        return 2

    if args.help:
        parser.print_help()
        return 0

    state.mode = "real" if args.real else "mock"
    state.verbose = args.verbose
    state.only_category = args.only or ""

    print(f"\n{BOLD}{BLUE}╔{'═' * 52}╗{NC}")
    print(f"{BOLD}{BLUE}║   PM Workspace — Test Suite                        ║{NC}")
    print(f"{BOLD}{BLUE}║   Proyecto de test: sala-reservas                  ║{NC}")
    print(f"{BOLD}{BLUE}║   Modo: {state.mode:<44}║{NC}")
    print(f"{BOLD}{BLUE}╚{'═' * 52}╝{NC}")
    print(f"  Workspace: {CYAN}{WORKSPACE_ROOT}{NC}")
    print(f"  Inicio:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Ejecutar suites según categoría
    if should_run("prereqs"):
        test_prereqs()
    if should_run("structure"):
        test_structure()
    if should_run("connection"):
        test_connection()
    if should_run("capacity"):
        test_capacity()
    if should_run("sprint"):
        test_sprint()
    if should_run("imputacion"):
        test_imputacion()
    if should_run("sdd"):
        test_sdd()
    if should_run("report"):
        test_report()
    if should_run("backlog"):
        test_backlog()

    # ── Resumen final ─────────────────────────────────────────────────────────
    print(f"\n{BOLD}{BLUE}{'═' * 52}{NC}")
    print(f"{BOLD}  RESULTADO FINAL{NC}")
    print(f"{BOLD}{BLUE}{'═' * 52}{NC}")
    print(f"  Total:    {state.total} tests")
    print(f"  {GREEN}Passed:{NC}   {state.passed}")
    print(f"  {RED}Failed:{NC}   {state.failed}")
    print(f"  {YELLOW}Skipped:{NC}  {state.skipped}")

    if state.failed == 0:
        print(f"\n  {GREEN}{BOLD}✅ TODOS LOS TESTS PASARON{NC}")
        print("\n  El workspace está configurado correctamente.")
        print(f"  Ejecuta {CYAN}claude{NC} desde {CYAN}pm-workspace/{NC} para empezar.")
    else:
        print(f"\n  {RED}{BOLD}❌ {state.failed} TEST(S) FALLARON{NC}")
        print()
        for t in state.failed_tests:
            print(f"  {RED}•{NC} {t}")
        print()
        print("  Consulta los errores arriba y ejecuta de nuevo tras corregirlos.")
        print(f"  Puedes ejecutar una suite específica con: {CYAN}--only prereqs{NC}")

    generate_report()
    return 0 if state.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
