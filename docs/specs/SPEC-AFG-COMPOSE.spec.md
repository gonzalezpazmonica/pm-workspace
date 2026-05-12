# Spec: Agentic Flow Graph Compose — Per-phase model routing dentro del grafo

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Agentic Flow Graph (extensión)
**Sprint:**         2026-29 (post SPEC-AFG Slice 4)
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     4h (un slice)
**Estado:**         Pendiente

**Depende de:**     SPEC-AGENTIC-FLOW-GRAPH (Slices 1-3 en main), Rule #26 Language Boundaries
**Inspirado por:**  Patrón `sdd-orchestrator-{name}` de Gentle-AI (Gentleman-Programming/gentle-ai). Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. Los comandos slash (`/flow-run`, `/flow-profile-validate`) son ficheros markdown en `.opencode/commands/` que OpenCode interpreta como prompts. Los prompts instruyen al modelo para invocar la tool Bash, que ejecuta wrappers en `scripts/`, que a su vez invocan Python. La cadena completa: usuario → OpenCode → modelo → tool Bash → wrapper bash → subprocess Python → resultado.

**Decisión arquitectónica registrada:**
- (D-1) Profiles de flujo se declaran en `.scm/profiles/{profile}.yaml`, separados de los `.flow.yaml`. Un mismo flujo se ejecuta con cualquier profile sin modificar el grafo.
- (D-2) El profile reasigna **tiers** (heavy/mid/fast). NO modelos concretos. **OpenCode hace la resolución tier→modelo** según su configuración. Savia nunca elige el modelo; OpenCode sí.
- (D-3) Profiles son composicionales sobre la declaración del nodo. Un nodo declara su tier mínimo aceptable; el profile puede subirlo o bajarlo dentro de los límites declarados.
- (D-4) Auditoría obligatoria: cada ejecución registra qué profile se usó y qué tier final se resolvió por nodo (NO el modelo, eso es responsabilidad de OpenCode loguearlo si quiere).
- (D-5) Resolver implementado en Python (lectura YAML, matching de patrones, cálculo de tier final, validación de floor/ceiling). Bash invoca el resolver y consume su output JSON. Conforme a Rule #26.
- (D-6) **El resolver Python se expone también como MCP server** (`savia-profile-resolver`). Esto permite que cualquier frontend compatible con MCP, no solo OpenCode, lo invoque. Reutilización futura sin reescribir.
- (D-7) Ortogonalidad con SDD orchestrator de Gentle-AI: el SDD orchestrator gestiona fases SDD (design/implement/review/...) con modelos asignados. Los profiles de AFG gestionan tiers de nodos en grafos arbitrarios. No compiten; coexisten.

---

## 1. Contexto y Objetivo

### 1.1 Problema

El SPEC-AGENTIC-FLOW-GRAPH (AFG) declara nodos con tier estático: un nodo `kind: agent` invoca su agente con el tier que el agente tiene asignado globalmente en la configuración de OpenCode. Esto provoca dos efectos no deseables en flujos largos:

1. **Coste constante alto.** Un flujo de 20 nodos con agentes tier `heavy` ejecuta 20 invocaciones a modelo grande, aunque la mitad sean tareas triviales (parseo, formateo, agregación) que un tier `fast` resolvería con calidad equivalente.
2. **Imposibilidad de exploración barata.** Cuando se prototipa un flujo nuevo, no hay forma de ejecutarlo en modo "barato" para validar la topología antes de pagar la versión cara.

Gentle-AI resuelve algo parecido en su SDD orchestrator con profiles `cheap`, `premium` y custom, pero limitado a un workflow fijo (las 6 fases SDD). En AFG queremos lo mismo aplicado a *cualquier* grafo declarado.

### 1.2 Objetivo

Permitir que un mismo `.flow.yaml` se ejecute con distintos profiles que reasignan los tiers de sus nodos, sin modificar el grafo:

```
/flow-run code-review-court --profile cheap     # todo a fast salvo nodos críticos
/flow-run code-review-court --profile premium   # todo a heavy
/flow-run code-review-court                     # tiers declarados en el grafo (default)
```

OpenCode, al ejecutar cada nodo, recibe el tier ya resuelto y aplica su configuración tier→modelo (Anthropic para heavy, DeepSeek para mid, etc., según preferencias del usuario).

### 1.3 No-Goals

- ❌ NO se permite que un profile sobrescriba modelos concretos. La capa de resolución modelo está en OpenCode.
- ❌ NO se introduce planificación dinámica (modelos elegidos en tiempo de ejecución según presupuesto consumido). El profile se resuelve antes del primer nodo.
- ❌ NO se modifica el formato de `.flow.yaml`. Solo se añade un fichero nuevo de profile.
- ❌ NO se implementa el resolver en bash + yq. Va en Python (Rule #26).
- ❌ NO se reemplaza el SDD orchestrator de Gentle-AI. Coexiste.

---

## 2. Requisitos Funcionales

### 2.1 Estructura de un profile

```yaml
# .scm/profiles/cheap.yaml
profile_id: cheap
description: Ejecución barata para exploración y prototipado.
default_tier: fast
overrides:
  - nodes_matching: { kind: agent, tags: [reviewer] }
    tier: mid
  - nodes_matching: { id_pattern: "judge-*" }
    tier: mid
constraints:
  max_cost_usd: 0.50
  max_duration_minutes: 10
```

### 2.2 Declaración de límites por nodo en `.flow.yaml`

Extensión retrocompatible: cada nodo puede declarar `tier_floor` y `tier_ceiling`.

```yaml
nodes:
  - id: aggregate-final-verdict
    kind: skill
    invoke: score-aggregator
    tier: heavy           # default
    tier_floor: mid       # un profile NO puede bajar este nodo a fast
    tier_ceiling: heavy   # ni subirlo
```

### 2.3 Resolución del tier final

Algoritmo (implementado en `scripts/lib/profile_resolver.py`):

1. Tier base = `tier` declarado en el nodo, o `default_tier` del profile si el nodo no lo declara.
2. Aplicar overrides del profile que matcheen el nodo (primer match gana).
3. Recortar al rango `[tier_floor, tier_ceiling]` del nodo. Violación → error explícito, NO coerción silenciosa.
4. Resultado registrado en la traza JSONL antes de invocar el nodo.

### 2.4 Arquitectura de la herramienta

Conforme a Rule #26 y al contexto de ejecución OpenCode:

**Comando slash — `.opencode/commands/flow-profile-validate.md`** (markdown, no código):
- Describe al modelo cómo invocar el validador.
- Instruye al modelo a usar la tool Bash con argumentos limpios.
- Explica cómo presentar el output al usuario.

**Wrapper bash — `scripts/flow-profile-resolve.sh`** (≤ 15 líneas):
- Recibe `<flow-file> <profile-file>` como argumentos.
- Invoca `python3 scripts/lib/profile_resolver.py --flow <f> --profile <p>`.
- Devuelve JSON resuelto a stdout, propaga código de salida.

**Lógica Python — `scripts/lib/profile_resolver.py`:**
- Carga flow YAML y profile YAML con `pyyaml`.
- Aplica matching de overrides (kind, tags, id_pattern con regex).
- Aplica orden total entre tiers (`fast < mid < heavy`).
- Valida floor/ceiling, falla con mensaje claro si profile viola límites.
- Devuelve mapeo nodo→{tier_final, tier_source} en JSON.
- Tiene `--help` útil con ejemplos.

**MCP server — `scripts/lib/profile_resolver_mcp.py`:**
- Expone la misma lógica como MCP server local.
- Tools expuestas: `resolve_profile(flow, profile) → mapping`, `validate_profile(profile) → diagnostics`, `list_profiles() → ids`.
- Permite que otro frontend o herramienta compatible con MCP invoque el resolver sin pasar por la tool Bash.

### 2.5 Comandos slash en OpenCode

| Comando | Acción |
|---|---|
| `/flow-profile-list` | Lista profiles disponibles en `.scm/profiles/` |
| `/flow-profile-validate {flow} {profile}` | Muestra el plan de tiers resuelto sin ejecutar |
| `/flow-run {flow} --profile {profile}` | Ejecuta el flujo con profile (extensión del comando AFG) |

Cada uno es un `.opencode/commands/*.md` que el modelo lee y ejecuta vía tool Bash.

### 2.6 Traza enriquecida

El JSONL añade un evento `profile.resolved` al inicio con el mapeo nodo→tier_final, y cada `node.start` incluye `tier_final` y `tier_source` (`declared` | `profile_default` | `profile_override`). La inserción la hace el motor AFG vía el wrapper Python correspondiente.

---

## 3. No se modifica

- Schema actual de `.flow.yaml` (sólo extensión retrocompatible con campos opcionales).
- Configuración tier→modelo de OpenCode. Es responsabilidad del usuario y vive fuera de Savia.
- Motor de ejecución de AFG (sólo se añade el resolver de profile como pre-step).
- SDD orchestrator de Gentle-AI.

---

## 4. Criterios de Aceptación

- [ ] Resolver implementado en Python con tests pytest. Bash limita su rol a invocación.
- [ ] Profiles `cheap.yaml` y `premium.yaml` provistos como ejemplos en el repo.
- [ ] `/flow-run code-review-court --profile cheap` ejecuta y registra `profile.resolved` con todos los jueces en `mid`.
- [ ] Profile que intenta poner un nodo bajo su `tier_floor` rechazado con error claro (no coerción silenciosa).
- [ ] Comparativa medida: `code-review-court` con profile `cheap` vs default. Documentar coste y latencia. Acceptance: coste < 30% del default, latencia ≤ 120% del default.
- [ ] MCP server `savia-profile-resolver` funcional, registrable en cualquier frontend compatible.
- [ ] Tests pytest: 10 casos cubriendo resolución, overrides, floor/ceiling, regex matching de id_pattern.
- [ ] Tests bats: 2 casos cubriendo invocación del wrapper bash.
- [ ] `/flow-profile-validate code-review-court cheap` muestra plan completo.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/profile_resolver.py`
- `scripts/lib/profile_list.py`
- `scripts/lib/profile_resolver_mcp.py`
- `tests/python/test_profile_resolver.py`
- `tests/python/fixtures/profiles/`
- `tests/python/fixtures/flows/`

**Crear (Bash — envoltorios):**
- `scripts/flow-profile-resolve.sh` (≤ 15 líneas)
- `scripts/flow-profile-list.sh` (≤ 10 líneas)
- `tests/flow-profile-wrapper.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/commands/flow-profile-list.md`
- `.opencode/commands/flow-profile-validate.md`

**Crear (datos y schemas):**
- `.scm/profiles/cheap.yaml`
- `.scm/profiles/premium.yaml`
- `schemas/profile.schema.json`

**Modificar:**
- `.opencode/commands/flow-run.md`: añadir soporte `--profile`.
- `scripts/flow-run.sh`: invocar resolver Python como pre-step.
- `schemas/flow.schema.json`: añadir `tier_floor`, `tier_ceiling` opcionales.
- `docs/agentic-flow-graph.md`: sección "Profiles".
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `pyyaml` (ya presente en entorno de desarrollo). MCP SDK Python si se publica el server (`mcp` package). Sin dependencias nuevas significativas.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Profile mal configurado degrada calidad sin avisar.** Un usuario ejecuta `cheap` en un flujo crítico y obtiene resultados peores. | `tier_floor` por nodo. Un nodo crítico declara su mínimo y el profile no puede bajarlo. La responsabilidad de declarar floor está en quien escribe el flow. |
| **Explosión de profiles.** Cada cliente o consultor crea su profile y se vuelve inmanejable. | Convención: `.scm/profiles/` versionado, `profiles.local/` ignorado por git para profiles personales. |
| **Coste real difícil de predecir antes de ejecutar.** | `flow-profile-validate` muestra plan, pero no estimación de coste. Slice futuro opcional: integración con quota guard para estimar coste por profile. |
| **Regex de `id_pattern` mal escrita captura más de lo esperado.** | Tests con casos canónicos. Validador `flow-profile-validate` muestra qué nodos matcheó cada override antes de ejecutar. |
| **Configuración tier→modelo de OpenCode incompleta.** Un usuario usa profile `cheap` pero su OpenCode no tiene tier `fast` configurado. | El resolver no detecta esto (es responsabilidad de OpenCode). Documentar el prerrequisito: tener heavy/mid/fast configurados en OpenCode antes de usar profiles. |

---

## 7. Impacto en Roadmap

- Habilita uso de AFG en exploración rápida sin penalización económica.
- Pre-requisito implícito de cualquier flujo en producción a escala.
- Conecta con SPEC-FLOW-OBSERVABILITY: las trazas con `tier_source` permitirán análisis de coste por profile en herramientas OTel.
- El MCP server `savia-profile-resolver` queda disponible para cualquier frontend futuro, no solo OpenCode.
- La lib `profile_resolver.py` queda reutilizable como motor de resolución de prioridades aplicable a otros contextos.
