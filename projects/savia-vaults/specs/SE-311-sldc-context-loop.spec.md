# Spec: SE-311 — SDLC Context Loop: cerrar el ciclo de conocimiento en Savia Flow

**Task ID:**        SE-311
**PBI padre:**      SE-311 — Savia Flow SDLC: contexto vivo (post-merge → cúpulas) + compuerta determinista de estándares
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-07
**Creado por:**     Savia (auditoria de Savia Flow contra el articulo de Ernesto Laura Mamani, 2026-08-04)

**Developer Type:** agent-team
**Asignado a:**     python-developer + bash/shell + frontend? (no) → python-developer + infra (CI)
**Estado:**         PROPOSED

**Decisiones de diseño (2026-08-07, propuestas para aprobacion):**

| Decision | Eleccion | Justificacion |
|---|---|---|
| Alcance | **2 slices**: S1 Context Loop (post-merge → cúpulas), S2 Standards Gate (diff final → validacion determinista) | Son los DOS gaps que el articulo identifica como los que "mas duelen" y que Savia no cierra hoy |
| Substrato | **SaviaVaults** (cúpulas N1-N4b, A2A `/share`, MCP `vault_write`) | Ya es el conocimiento centralizado/gobernado que el articulo pide ("estandares fuera de los repos, base viva") |
| Trigger post-merge | **Hook/gate en CI al mergear** + comando `/sldc-context-loop` manual | Cierra el ciclo automaticamente (articulo: "que se actualice sola al cerrar cada entrega"); el comando permite re-ejecutar |
| Generacion de conocimiento | **LLM resume el diff en notas con citacion** | Patron SE-310 2.9: fundamentacion con path de fuente; evita conocimiento inventado |
| S2 sobre el RESULTADO final | El gate corre sobre el **diff mergeado** (post-ediciones manuales), no en-loop | Articulo: "verificar el resultado tal como quedo, sin importar quien lo toco al final" |
| Confidencialidad | Notas al dome configurado (default `SaviaLabs`, N2); ADRs/decisiones N2; releases N1 | Reutiliza el gate de confidencialidad de SE-310 S0-H (endpoint↔nivel) |
| Dependencia del articulo | NO se adopta Spec Kit/OpenSpec/BMAD/AI-DLC | Savia ya tiene SDD + SaviaVaults + gates; se cierran los gaps sobre lo existente |

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 480 min (S1: 240, S2: 240) |
| Human effort | 20 h |
| Review effort | 60 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 10h |

---

## 1. Contexto y Objetivo

El articulo de Ernesto Laura Mamani (2026-08-04) analiza SDD (Spec Kit, OpenSpec,
BMAD, AI-DLC) y señala dos gaps que ninguna metodologia resuelve y que "en la
practica son los que mas duelen":

1. **Memoria de contexto**: si la documentacion de los sistemas no se actualiza
   automaticamente al cerrar cada entrega, el contexto que consumen los agentes
   se degrada release tras release. OpenSpec es el que mas se acerca (delta sync),
   pero cubre la especificacion, no la documentacion operativa/arquitectonica.
2. **Enforcement de estandares**: ninguna define bien que pasa cuando el agente
   no respeta los lineamientos. Spec Kit tiene "analyze" pero es revision asistida
   por el propio agente, no una compuerta determinista. Thoughtworks lo nombra
   "feedback sensors for coding agents" (Trial ring).

**Estado de Savia hoy (lo que ya existe y se reutiliza):**
- SDD + Savia Flow (dual-track, specs ejecutables, `docs/savia-flow/`).
- SaviaVaults (cupulas N1-N4b, A2A `/search /context /share`, MCP `vault_*`).
- Compuertas deterministicas: `commit-guardian`, `security-guardian`, PR Guardian,
  guards de plugin (`block-*`), quality gates (`07-quality-gates-autonomos.md`).
- Deteccion de drift: `claude-md-drift-check`, `spec-status-drift-audit`,
  `readme-drift-check`, reconciliation.

**Hueco real**: Savia detecta drift (`spec-status-drift-audit` avisa de specs
PROPOSED-implementadas) pero **no lo corrige**: al mergear un PR, nada alimenta
las cupulas (status de spec, ADRs, releases) → el conocimiento de los agentes
queda desactualizado. Y la validacion de estandares esta dispersa en la suite
BATS, sin una compuerta consolidada que verifique el resultado FINAL.

**Objetivo SE-311**: cerrar el ciclo de conocimiento de Savia Flow en dos slices:
- **S1 — Context Loop**: al mergear, el conocimiento vuelve a las cupulas
  automaticamente (spec→IMPLEMENTED, ADR, release, doc de sistema).
- **S2 — Standards Gate**: compuerta determinista que valida el diff final contra
  todos los estandares de la organizacion, sin importar quien lo toco al final.

---

## 2. Arquitectura

### 2.1 S1 — Context Loop (post-merge → cupulas)

```
PR MERGEADO (CI gate post-merge / /sldc-context-loop)
  │
  ├─ 1. DETECTAR qué artefactos toco el PR:
  │      • specs (projects/*/specs/SE-*.spec.md) → status a actualizar
  │      • decisiones (docs/propuestas/*, ADR) → nueva nota
  │      • CHANGELOG.d/* → release a consolidar
  │      • codigo (proyectos) → doc de sistema a refrescar (resumen)
  │
  ├─ 2. RESUMIR con LLM (grounded, citando fuentes):
  │      • spec: estado nuevo + criterios cumplidos (cita el spec)
  │      • ADR: decision + contexto + consecuencias (cita la fuente)
  │      • release: que se entrego + impacto (cita el changelog/diff)
  │
  ├─ 3. ALIMENTAR las cupulas via A2A POST /share (o MCP vault_write):
  │      • SaviaLabs/specs/<id>-status.md      (N2)
  │      • SaviaLabs/decisions/<fecha>-<id>.md  (N2)
  │      • SaviaLabs/releases/<version>.md      (N1)
  │
  └─ 4. VERIFICAR: /search encuentra la nota nueva (consume de la siguiente iteracion)
```

**Regla de fundamentacion (SE-310 2.9)**: toda nota generada cita los paths de
las fuentes que la originaron. El LLM NUNCA inventa contenido; si el diff no
permite afirmar algo, la nota lo omite.

### 2.2 S2 — Standards Gate (validacion determinista del resultado final)

```
CI (PR abierto, sobre el diff FINAL del merge, incl. ediciones manuales):
  ── standards-compliance-gate.sh ──
  ├─ File-size: docs/rules, comandos, agentes ≤150 lineas (excepciones documentadas)
  ├─ Skill catalog: skill-catalog-audit (fail=0; parsea YAML plegado)
  ├─ Agent schema: agents-opencode-convert --check (idempotente)
  ├─ Drift: claude-md-drift-check, readme-drift, spec-status-drift
  ├─ Reglas de la organizacion: CRITERIO.md / reglas de dominio (validacion de citacion)
  └─ Confidentiality: scan PII + firma (reutiliza el gate existente)
  ── VEREDICTO: PASS (mergeable) | FAIL (bloquea, con el check concreto)
```

**Diferencia con lo existente**: hoy estos checks viven dispersos en la suite
BATS (FULL) y algunos en guards pre-commit. S2 los consolida en UN comando
determinista, ejecutable en CI sobre el diff final y re-ejecutable a mano
(`--report`), de modo que un cambio manual post-agente NO pueda saltarse la
validacion de estandares de la organizacion.

### 2.3 Contratos

```python
# scripts/sldc-context-loop.sh  (S1)
# Entrada: --base <ref> --head <ref>  (o detecta el merge desde CI)
# Salida: notas escritas a la cupula + resumen JSON
#   { notes: [{dome, path, status}], sources_cited: [paths], skipped: [] }

# scripts/standards-compliance-gate.sh  (S2)
# Entrada: --base <ref> --head <ref>  (diff final)
# Salida: --json { verdict, checks: [{name, status, details}] }
# Exit 0 = PASS, 1 = FAIL (con el check que fallo)
```

### 2.4 Configuracion

| Clave | Default | Descripcion |
|---|---|---|
| `sldc.vaults_enabled` | `true` | Activa el contexto loop hacia las cupulas |
| `sldc.write_dome` | `SaviaLabs` | Dome destino (defaultDome de savia-vaults.domes.json) |
| `sldc.specs_dir` | `projects/*/specs/` | Patron de specs a detectar |
| `sldc.llm_endpoint` | (reusa Ollama) | Para resumir el diff (mismo cerebro que el workspace) |
| `sldc.max_confidentiality` | `N2` | Nivel maximo de las notas (reutiliza gate SE-310 S0-H) |
| `sldc.gate_on_merge` | `true` | Hook de CI post-merge activo |
| `sldc.gate_checks` | `file-size,skill-audit,agent-schema,drift,rules,confid` | Checks de S2 habilitados |

---

## 3. Criterios de Aceptacion

- [ ] **AC-1 (S1)** — Tras mergear un PR que implementa una spec, la cupula
      contiene `specs/<id>-status.md` con estado IMPLEMENTED y criterios citados;
      `/search` la encuentra (consume listo para la siguiente iteracion).
- [ ] **AC-2 (S1)** — Un PR con ADR/decision genera `decisions/<fecha>-<id>.md`
      (N2) con decision+contexto+consecuencias y citacion de fuente.
- [ ] **AC-3 (S1)** — Un PR con CHANGELOG.d genera `releases/<version>.md` (N1)
      con resumen de lo entregado.
- [ ] **AC-4 (S1)** — Fallo del vault server o LLM → la nota NO se pierde: queda
      un pendiente local (`~/.savia/sldc-pending/`) y el comando puede re-ejecutar.
- [ ] **AC-5 (S2)** — `standards-compliance-gate.sh --json` valida el diff final
      y devuelve verdict PASS/FAIL con el check concreto que falla.
- [ ] **AC-6 (S2)** — Un cambio manual post-agente (edicion a mano) que viole
      un estandar (ej. doc >150 lineas, skill sin descripcion) → FAIL.
- [ ] **AC-7 (S2)** — Re-ejecutable a mano (`--report`) sin depender de CI.

---

## 4. Test Scenarios

1. **S1 spec**: repo de prueba con spec PROPOSED → PR la implementa → merge →
   `sldc-context-loop` genera la nota → `/search` la encuentra en el dome.
2. **S1 ADR**: PR con decision → nota decisions/ creada con citacion.
3. **S1 release**: PR con CHANGELOG.d → nota releases/ creada.
4. **S1 fallback**: vault server caido → nota queda pendiente local; re-ejecutar
   la envia (no se pierde).
5. **S1 fundamentacion**: el LLM fake recibe el diff y su nota cita los paths;
   un diff sin evidencia → la nota omite (no inventa).
6. **S2 PASS**: diff limpio → verdict PASS (exit 0).
7. **S2 FAIL file-size**: doc >150 lineas anadido a mano → FAIL con el check.
8. **S2 FAIL skill**: skill sin descripcion → FAIL.
9. **S2 FAIL drift**: CLAUDE.md counter roto → FAIL.
10. **S2 report**: `--report` genera fichero con secciones por check.

---

## 5. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/specs/SE-311-sldc-context-loop.spec.md` | Esta spec |
| `scripts/sldc-context-loop.sh` | S1: detecta artefactos + LLM resume + alimenta cupulas |
| `scripts/standards-compliance-gate.sh` | S2: compuerta consolidada determinista |
| `tests/bats/test-sldc-context-loop.bats` | BATS S1 (fakes LLM/vaults) |
| `tests/bats/test-standards-compliance-gate.bats` | BATS S2 |
| `.claude/commands/sldc-context-loop.md` | Comando manual + CI |

### Modificar

| Fichero | Cambio |
|---|---|
| `.github/workflows/ci.yml` | Invocar `standards-compliance-gate.sh` en CI (reemplaza checks dispersos) |
| `docs/savia-flow/07-quality-gates-autonomos.md` | Documentar el gate consolidado |
| `docs/savia-flow/` (indice) | Referencia a SE-311 |

---

## 6. Roadmap de Implementacion

### S1 — Context Loop
- [ ] Detectar artefactos del diff (specs/ADRs/changelog)
- [ ] LLM resume grounded + citacion (reutiliza VaultContext/OpenAICompatible de Sonora)
- [ ] Alimentar cupulas via A2A /share + pendiente local en fallo
- [ ] `/sldc-context-loop` + hook CI post-merge

### S2 — Standards Gate
- [ ] Consolidar checks (file-size, skill-audit, agent-schema, drift, rules, confid)
- [ ] `--json` verdict + `--report`
- [ ] Integrar en CI (diff final)

### S3 — Verificacion end-to-end
- [ ] Un PR real de spec → merge → nota en la cupula → consumida por un agente
- [ ] Suite BATS verde + typecheck

---

## 7. Alineacion con el articulo (trazabilidad)

| Propuesta/Gap del articulo | Como lo cubre SE-311 |
|---|---|
| Gap 1: memoria de contexto / auto-update al cerrar cada entrega | S1: post-merge → cupulas (spec/ADR/release), la doc vive |
| Gap 2: enforcement de estandares determinista | S2: compuerta consolidada sobre el diff FINAL (incluye ediciones manuales) |
| Prop 2: estandares fuera de los repos | SaviaVaults ya lo es; S1 alimenta esa base viva |
| Prop 5: cerrar el ciclo (doc auto-actualizada) | S1 (mismo proposito) |
| Prop 6: operacion/incidentes con contexto | Al cerrar el ciclo, la operacion tiene contexto fresco (consecuencia, igual que en el articulo) |
| Thoughtworks "feedback sensors / loop engineering" | S2 = verificar el resultado fuera de loop (el caso que el articulo dice que el loop no ve) |

---

## 8. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Comando `/sldc-context-loop` | `.claude/commands/` | `.opencode/commands/` (symlink) |
| Scripts `scripts/sldc-*.sh`, `standards-compliance-gate.sh` | `scripts/` compartidos | `scripts/` compartidos |
| CI `.github/workflows/ci.yml` | Shared | Shared |
| BATS | Ruta compartida | Selector dinamico |

### Portability classification
- [x] **PURE_BASH** — logica en bash/python scripts + CI; sin bindings de frontend; corre identico en cualquier motor.

### Verification protocol
- [ ] Funciona en runtime OpenCode (scripts compartidos, CI agnostica)
- [ ] Tests cubren ambos paths (BATS + pytest); SKIP justificado para vault server real

---

## 9. Riesgos y mitigaciones

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| LLM resume con alucinacion | Media | Notas incorrectas en la cupula | Regla de fundamentacion (citacion obligatoria) + omitir sin evidencia |
| Vault server caido al mergear | Baja | Conocimiento perdido | Pendiente local + re-ejecucion (AC-4) |
| S2 muy lento en CI (muchos checks) | Media | CI lenta | Solo los checks relevantes al diff (seleccion por ficheros) |
| Duplicidad con guards existentes | Media | Redundancia | S2 consolida y documenta; no duplica, orquesta |
| Drift de contadores recurrente | Media | S2 FAIL constante | S2 marca el check concreto; se corrige puntual (como SE-310 hygiene) |
