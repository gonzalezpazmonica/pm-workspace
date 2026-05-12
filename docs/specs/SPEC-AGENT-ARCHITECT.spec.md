# Spec: Agent Architect — Detección y descomposición de agentes monolíticos

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Higiene del catálogo de agentes
**Sprint:**         2026-30
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimación:**     8h (un slice)
**Estado:**         Pendiente

**Depende de:**     Rule #26 Language Boundaries
**Inspirado por:**  Genesis (danielmeppiel/genesis): "Markdown that steers an LLM is code. Design it before you write it." Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. El comando slash `/agent-architect` es un fichero markdown en `.opencode/commands/` interpretado como prompt. El prompt instruye al modelo (que actúa como el agente `agent-architect`) para invocar la tool Bash, que ejecuta el wrapper, que llama al analizador Python. El analizador devuelve señales estructuradas en JSON; el modelo las recibe y genera la propuesta de descomposición textual.

**Decisión arquitectónica registrada:**
- (D-1) Agent Architect es un detector + propositor, no un refactorizador automático. Genera propuestas; la implementación es siempre humana.
- (D-2) Las heurísticas de monolito son explícitas y configurables, NO black-box. Un humano puede entender y ajustar los umbrales.
- (D-3) La propuesta de descomposición se entrega como artefacto markdown con plan, contratos y diagrama. NO modifica el agente original.
- (D-4) El análisis es offline y local. No envía el contenido del agente a ningún servicio externo.
- (D-5) Las heurísticas se implementan en Python (parseo de markdown, conteo de líneas, detección de headers, análisis de frontmatter). Bash queda solo como envoltorio. Conforme a Rule #26.
- (D-6) **El analizador NO se expone como MCP server.** Su valor está acoplado al workspace concreto; analizar agentes de un workspace ajeno desde fuera no aporta. Si en el futuro se demuestra valor cross-workspace, se evaluará como Slice futuro.

---

## 1. Contexto y Objetivo

### 1.1 Problema

pm-workspace tiene 70 agentes especializados. La cantidad creció orgánicamente y algunos agentes han ido absorbiendo responsabilidades. Esto produce el patrón **agente monolito**.

Síntomas medibles:

1. **Longitud excesiva.** Un agente que pasa de las ~200 líneas de prompt empieza a ser ignorado parcialmente por el modelo (pérdida de atención sobre instrucciones).
2. **Múltiples responsabilidades.** Un agente que hace "review + fix + test + document" mezcla concerns que se beneficiarían de separación.
3. **Contradicciones internas.** Reglas añadidas en distintos momentos que se contradicen.
4. **Acoplamiento de tools.** Un agente que necesita 15+ tools probablemente está haciendo el trabajo de varios.
5. **Prompts anidados.** Un agente que pide al modelo que "se imagine que es un experto en X y luego también en Y" duplica la carga cognitiva.

Genesis ataca este problema en el momento del diseño (descompón antes de escribir). Lo que falta es un análisis sobre los agentes que **ya existen**: detectar cuáles son monolitos y proponer descomposiciones.

### 1.2 Objetivo

Construir Agent Architect: un comando + skill + agente especializado que:

1. **Analiza** un agente existente (o todos) según heurísticas explícitas.
2. **Detecta** señales de monolito y las cuantifica.
3. **Propone** una descomposición concreta: sub-agentes especializados + contratos entre ellos + diagrama.
4. **Entrega** la propuesta como artefacto markdown para revisión humana. NUNCA aplica cambios.

### 1.3 No-Goals

- ❌ NO se refactoriza automáticamente.
- ❌ NO se garantiza que toda detección sea correcta. Falsos positivos aceptables.
- ❌ NO se cubren skills, comandos ni hooks en este slice. Solo agentes.
- ❌ NO se introduce un score numérico tipo "salud del agente: 7/10". Las señales son cualitativas.
- ❌ NO se implementan heurísticas con awk/grep en bash.
- ❌ NO se expone como MCP server (decisión D-6).

---

## 2. Requisitos Funcionales

### 2.1 Heurísticas de detección

Cada heurística produce una señal cualificada (`info` | `warn` | `alert`) con evidencia textual:

| Heurística | `info` | `warn` | `alert` |
|---|---|---|---|
| Longitud de prompt | < 200 líneas | 200-400 | > 400 |
| Número de responsabilidades distintas (verbos imperativos en headers) | 1-2 | 3-4 | ≥ 5 |
| Tools requeridas | ≤ 5 | 6-10 | > 10 |
| Contradicciones internas detectadas | 0 | 1-2 | ≥ 3 |
| Profundidad máxima de roleplay anidado | 0 | 1 | ≥ 2 |
| Cobertura de tests del agente (si existe) | > 70% | 30-70% | < 30% |
| Última modificación significativa | < 30 días | 30-180 días | > 180 días con ≥ 3 alerts |

Un agente con ≥ 2 alerts es candidato a descomposición.

### 2.2 Arquitectura

Conforme a Rule #26 y al contexto OpenCode:

**Comando slash — `.opencode/commands/agent-architect.md`** (markdown, no código):
- Describe al modelo que invoque al agente especializado `agent-architect`.
- El agente `agent-architect` lee el target, llama al wrapper bash vía tool Bash, recibe señales JSON, genera propuesta.

**Agente — `.opencode/agents/agent-architect.md`** (markdown, no código):
- Frontmatter con tools requeridas (Read, Bash, Write).
- Prompt que orquesta: leer agente target, invocar analizador, generar propuesta usando plantilla estricta.

**Skill — `.opencode/skills/agent-monolith-detector/SKILL.md`** (markdown):
- Documenta cómo invocar el analizador y cómo interpretar las señales.
- Incluida en el prompt del agente cuando se necesita.

**Wrapper bash — `scripts/agent-architect.sh`** (≤ 20 líneas):
- Recibe `<agent-id|--all>` como argumento.
- Invoca `python3 -m agent_architect.cli <args>`.
- Devuelve JSON estructurado a stdout.

**Módulo Python — `scripts/lib/agent_architect/`:**
- `__init__.py`
- `cli.py` — punto de entrada con argparse.
- `parser.py` — parsea markdown del agente, extrae frontmatter, headers, listas de tools.
- `heuristics.py` — implementa cada heurística como función pura sobre el AST.
- `detector.py` — agrega resultados, aplica thresholds desde YAML, devuelve estructura de señales.
- `report.py` — genera reportes (individual y agregado) en markdown.
- `requirements.txt` — `pyyaml`, `markdown-it-py` o `mistune`.

### 2.3 Output: Reporte de análisis

Para `--all`:

```markdown
# Agent Architect — Reporte 2026-05-09

## Candidatos a descomposición (≥ 2 alerts)

| Agente | Líneas | Responsabilidades | Tools | Contradicciones | Última mod |
|---|---|---|---|---|---|
| code-judge-correctness | 467 alert | 6 alert | 12 alert | 0 | 12 días |
| pr-coordinator | 423 alert | 5 alert | 8 warn | 2 warn | 45 días |

## Análisis individuales

[detalle por agente con evidencia textual extraída]
```

### 2.4 Output: Propuesta de descomposición

Para `/agent-architect <agent-id>` con ≥ 2 alerts, el agente `agent-architect` genera (vía LLM con plantilla estricta) un artefacto:

```markdown
# Propuesta de descomposición — code-judge-correctness

## Diagnóstico
[Síntomas detectados con citas textuales del agente original]

## Descomposición propuesta
Tres sub-agentes con responsabilidades disjuntas:

### 1. logic-judge
- Responsabilidad única: detectar errores lógicos en el diff.
- Tools requeridas: Read, Grep.
- Contrato de salida: `{ findings: [{file, line, severity, description}] }`.

### 2. test-coverage-judge
[...]

### 3. correctness-arbiter
[...]

## Diagrama de orquestación
[Mermaid]

## Encaje en SPEC-AGENTIC-FLOW-GRAPH
[Si AFG está en main, propuesta de .flow.yaml para orquestar los tres]

## Plan de migración
[Pasos concretos con tests de regresión]

## Riesgos
[Riesgos de la descomposición y cómo mitigar]
```

El analizador Python NO genera la propuesta textual. Solo entrega señales estructuradas. El modelo, actuando como agente `agent-architect`, redacta la propuesta basándose en las señales y en el contenido del agente original.

### 2.5 Configurabilidad de umbrales

Los umbrales viven en `.opencode/agent-architect-thresholds.yaml` y son ajustables. Carga y validación en Python.

### 2.6 Comando slash `/agent-architect`

```
/agent-architect <agent-id>           # Analiza un agente concreto + propuesta
/agent-architect --all                # Analiza los 70 agentes y produce ranking
/agent-architect --threshold alert    # Solo lista agentes con ≥ 2 alerts
```

---

## 3. No se modifica

- Ningún agente existente.
- Sistema de carga de agentes de OpenCode.
- SPEC-AGENTIC-FLOW-GRAPH.
- Memoria persistente.

---

## 4. Criterios de Aceptación

- [ ] Heurísticas implementadas en Python con tests pytest cubriendo cada una.
- [ ] `/agent-architect --all` produce reporte para los 70 agentes en < 60 segundos.
- [ ] Al menos 1 agente real del repo identificado como candidato; propuesta revisable.
- [ ] La propuesta incluye: diagnóstico con citas, descomposición con contratos, diagrama, plan de migración, riesgos.
- [ ] Umbrales configurables vía YAML sin modificar código.
- [ ] Tests pytest: 12 casos cubriendo cada heurística.
- [ ] Tests bats: 2 casos cubriendo el wrapper bash.
- [ ] Documentación: `docs/agent-architect.md`.
- [ ] El propio agente `agent-architect` pasa su propio análisis (no es monolito).

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/agent_architect/__init__.py`
- `scripts/lib/agent_architect/cli.py`
- `scripts/lib/agent_architect/parser.py`
- `scripts/lib/agent_architect/heuristics.py`
- `scripts/lib/agent_architect/detector.py`
- `scripts/lib/agent_architect/report.py`
- `scripts/lib/agent_architect/requirements.txt`
- `tests/python/test_agent_architect_parser.py`
- `tests/python/test_agent_architect_heuristics.py`
- `tests/python/test_agent_architect_detector.py`
- `tests/python/fixtures/agents/`

**Crear (Bash — envoltorios):**
- `scripts/agent-architect.sh` (≤ 20 líneas)
- `tests/agent-architect-wrapper.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/commands/agent-architect.md`
- `.opencode/agents/agent-architect.md`
- `.opencode/skills/agent-monolith-detector/SKILL.md`

**Crear (datos y plantillas):**
- `.opencode/agent-architect-thresholds.yaml`
- `templates/agent-decomposition-template.md`
- `docs/agent-architect.md`

**Modificar:**
- `docs/rules/domain/agents-catalog.md`: añadir entrada para `agent-architect`.
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `pyyaml`, librería de parseo markdown (`markdown-it-py` o `mistune`).

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Falsos positivos crean ruido.** Agentes legítimamente complejos (orchestrators) marcados como monolitos. | Whitelist en `thresholds.yaml`: agentes etiquetados como `kind: orchestrator` ven sus umbrales relajados x2. |
| **Falsos negativos: monolitos invisibles.** | Heurísticas conservadoras intencionalmente. Agent Architect complementa, no reemplaza, la revisión humana periódica. |
| **Propuestas de descomposición pobres.** El modelo genera descomposiciones genéricas. | La plantilla obliga a citas textuales como evidencia. Sin evidencia concreta, la propuesta se rechaza por validador Python. |
| **Sobre-descomposición.** Propuesta divide en 5 cuando 2 hubieran bastado. | El reporte incluye sección "alternativa simple" con la mínima descomposición justificable. El humano elige. |
| **Mantenimiento de heurísticas.** Pueden quedar obsoletas. | Configurables y explícitas en YAML. Revisión trimestral recomendada. |
| **Parseo de markdown frágil.** Algún agente usa formato no estándar. | Tests con fixtures de cada formato real presente en el repo. Errores de parseo se reportan claramente, no silenciosos. |

---

## 7. Impacto en Roadmap

- **Higiene continua.** Agent Architect ejecutado mensualmente como parte de un cron de mantenimiento detecta deuda agéntica antes de afectar el rendimiento.
- **Onboarding más limpio.** Un nuevo colaborador puede ejecutar `/agent-architect --all` y entender qué agentes son frágiles antes de modificarlos.
- **Datos para roadmap.** El ranking de candidatos a descomposición es input para priorizar refactors.
- **Patrón replicable.** El mismo patrón (heurísticas explícitas + propositor + revisión humana) puede extenderse a skills y comandos en iteraciones futuras, reutilizando el parser Python.
- **Reutilización.** El módulo `agent_architect.parser` queda disponible para otros analizadores futuros (skill auditor, command-redundancy-detector, etc.).
