---
id: SE-320
title: "SE-320 — Dependency Doctor: validación de pins y constraints del manifest"
status: PROPOSED
priority: baja
---

# SE-320 — Dependency Doctor: validación de pins y constraints del manifest

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Dependencies / Supply chain / CI
**Branch sugerida:** `agent/se320-dependency-doctor`
**Estimacion total:** ~16h (3 slices)
**Inspiracion:** `Shubhamsaboo/awesome-llm-apps` → agent_skills/dependency-doctor

---

## Contexto y evidencia (2026-08-09)

El skill `dependency-doctor` de awesome-llm-apps valida un manifest de
dependencias contra: pins de stdlib, backports obsoletos, entradas sin pin,
constraints duplicadas y releases yanked.

Savia tiene `dependency-scanner` (Trivy fs → SBOM + CVEs) e
`iac-security-scanner` (Trivy config). Ambos detectan *vulnerabilidades
conocidas*, pero **no validan la higiene del manifest**:

- un `package.json` con rango `^1.2.3` sin lockfile commitado,
- un `requirements.txt` con entrada sin pin (`requests`),
- constraints duplicadas o en conflicto en `pyproject.toml`/`Cargo.toml`,
- stdlib backport añadido a `requirements` (p. ej. `typing-extensions` con
  Python que ya lo incluye).

**El hueco.** Trivy responde "¿hay CVEs?"; nadie responde "¿el manifest está
bien formado y pinned?". El gap es de higiene de supply chain, no de CVE.

---

## Objetivo

Implementar `scripts/dependency-doctor.sh` que valida la higiene de manifests
(Node, Python, Go, Rust, Ruby, C#) en el workspace y proyectos: pins, stdlib
backports, duplicados, conflictos y releases yanked (vía registry check
offline/opt-in).

---

## Out of scope

- NO sustituir Trivy (CVE scanning) — es complementario.
- NO instalar dependencias ni modificar manifests: solo reportar.
- NO hacer análisis de grafo de dependencias transitivas (eso es SBOM/Trivy).

---

## Diseno

### S1 — Validación de pins

`scripts/dependency-doctor.sh check --manifest <path>`:
- package.json: exige lockfile presente (package-lock.json/pnpm-lock/yarn.lock);
  warning en rangos sin pin exacto para prod deps.
- requirements.txt/pyproject.toml: entradas sin `==` → WARN (dev deps
  permitidas con rango).
- Cargo.toml/go.mod/Gemfile/*.csproj: comprueba duplicados y conflictos.

### S2 — stdlib backports y duplicados

- detecta backports de stdlib innecesarios (p. ej. `typing-extensions` con
  Python ≥3.10, `dataclasses` con ≥3.7) usando la versión del runtime
  declarada en el proyecto,
- detecta constraints duplicadas o mutuamente excluyentes en el mismo manifest.

### S3 — Integración

- Nuevo check en `pr-plan-gates.sh` (G18, warning no-blocking) y job CI
  `Dependency Doctor` con `continue-on-error: true` inicial.
- Reporte JSON + resumen en PR body.
- Telemetría SE-313: evento `depdoctor.verdict` con counts por categoría.

---

## Criterios de aceptacion

### AC-S1: Pins

- [ ] AC-S1.1: package.json sin lockfile → WARN y detalle.
- [ ] AC-S1.2: requirements.txt con entrada sin `==` → WARN listando la línea.

### AC-S2: Backports y duplicados

- [ ] AC-S2.1: `typing-extensions` con Python ≥3.10 → WARN backport innecesario.
- [ ] AC-S2.2: constraint duplicada en pyproject → WARN.
- [ ] AC-S2.3: dos constraints excluyentes → ERROR (o WARN según severidad).

### AC-S3: Integración

- [ ] AC-S3.1: G18 documentado y ejecutable desde `pr-plan-gates.sh`.
- [ ] AC-S3.2: CI job no bloquea (report-only) en primera versión.
- [ ] AC-S3.3: `depdoctor.verdict` en `output/telemetry-events.jsonl`.
- [ ] AC-S3.4: fixtures de test cubren los 4 tipos de manifest.

---

## Ref

- `Shubhamsaboo/awesome-llm-apps` → `agent_skills/dependency-doctor`
- `.opencode/skills/dependency-scanner/SKILL.md` (Trivy), `scripts/pr-plan-gates.sh`
