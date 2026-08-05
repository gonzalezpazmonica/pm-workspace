# Spec: SE-301 — Agent Security Graph

**Task ID:**        SE-301
**PBI padre:**      SE-301 — Analisis de seguridad del grafo de agentes
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     python-developer + typescript-developer + security-guardian
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 120 min |
| Human effort | 6 h |
| Review effort | 45 min |
| Context risk | medium |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 3h (reglas de seguridad son criticas) |

---

## 1. Contexto y Objetivo

Savia tiene 83 agentes con capacidades heterogeneas: lectura/escritura de ficheros,
ejecucion bash, delegacion entre agentes (Task tool), acceso a memoria compartida
(L0-L3), manejo de datos confidenciales (N1-N4b), y conexion a Azure DevOps.
Actualmente **no existe analisis de rutas de ataque** entre agentes.

El patron de analisis de grafos de capacidad (BloodHound-style) modela arquitecturas
multi-agente como un grafo tipado de capacidades y ejecuta 17+ reglas para detectar
rutas de ataque desde input no confiable hasta datos sensibles o acciones externas.
Este modelo es directamente aplicable al ecosistema Savia:

| Patron de grafo | Equivalente Savia |
|---|---|
| `agent` node | `.opencode/agents/*.md` — 83 agentes |
| `input` node (trust_level) | Perfil activo + prompt del usuario |
| `data_asset` node (sensitivity) | Niveles N1-N4b + ficheros de config (PAT, secrets) |
| `output` node (boundary) | Azure DevOps, git push, API externas |
| `tool` node | Bash, Write, Edit, Task (delegacion) |
| `capability` edges | read, write, bash, edit, glob, grep, task, webfetch |
| `delegateTo` edge | Task tool → subagente |
| `readMemory` / `writeMemory` | sistema de memoria L0-L3 |
| `control` node | permission_level L0-L4, autonomous-safety gates |
| `executeCode` | bash: true |

**Objetivo**: construir un analizador de seguridad del grafo de agentes Savia que:
1. Extraiga automaticamente el grafo de agentes desde `.opencode/agents/*.md` + reglas
2. Ejecute reglas de deteccion de rutas de ataque (patrones establecidos + Savia-specificas)
3. Produzca un informe `.savia/security/agent-graph.md` con findings, scores y controles recomendados
4. Se ejecute como hook pre-commit o comando `/security-review agents`

**Diferencia clave**: las herramientas existentes analizan arquitecturas externas via YAML.
Savia analiza su **propio** grafo de agentes desde los ficheros de configuracion reales.

---

## 2. Contrato Tecnico

### 2.1 Extraccion del Grafo de Agentes

```python
# scripts/extract-agent-graph.py
# Lee .opencode/agents/*.md, .claude/settings.json, docs/rules/domain/*.md
# y produce un JSON con el grafo de agentes Savia

def extract_agent_graph() -> AgentGraph:
    """
    Returns:
        AgentGraph con:
        - nodes: List[AgentNode|InputNode|DataAssetNode|OutputNode|ToolNode|MemoryNode|ControlNode]
        - edges: List[CapabilityEdge]
    """
    agents = parse_agent_frontmatter(".opencode/agents/*.md")
    rules = parse_constraints("docs/rules/domain/")
    settings = parse_settings(".claude/settings.json")
    memory_levels = parse_memory_config("docs/memory-system.md")

    nodes = []
    edges = []

    for agent in agents:
        nodes.append(AgentNode(
            id=agent.name,
            name=agent.name,
            properties={
                "permission_level": agent.permission_level,  # L0-L4
                "model": agent.model,  # heavy|mid|fast
                "autonomous": agent.name in AUTONOMOUS_AGENTS,
                "maxSteps": agent.maxSteps
            }
        ))

        for tool, enabled in agent.tools.items():
            if enabled:
                tool_node_id = f"tool:{agent.name}:{tool}"
                nodes.append(ToolNode(id=tool_node_id, ...))
                if tool == "bash":
                    edges.append(CapabilityEdge(
                        source=agent.name, target=tool_node_id,
                        capability="executeCode",
                        properties={"sandbox_enabled": False}
                    ))
                elif tool == "write":
                    edges.append(CapabilityEdge(
                        source=agent.name, target=tool_node_id,
                        capability="modifyResource"
                    ))
                elif tool == "task":
                    edges.append(CapabilityEdge(
                        source=agent.name, target=tool_node_id,
                        capability="delegateTo"
                    ))
                ...

    # N1-N4b data assets
    for level in ["N1","N2","N3","N4a","N4b"]:
        nodes.append(DataAssetNode(
            id=f"data:{level}",
            sensitivity=level_to_sensitivity(level),
            properties={...}
        ))

    # External outputs
    nodes.append(OutputNode(id="output:azure_devops", boundary="external"))
    nodes.append(OutputNode(id="output:git_push", boundary="external"))

    return AgentGraph(nodes=nodes, edges=edges)
```

### 2.2 Reglas de Deteccion (35 rules: 17 estandar + 18 Savia-specificas)

#### Patrones estandar (directamente aplicables)

| Rule | Pattern | Severity |
|------|---------|----------|
| FH-001 | Input no confiable → agente lee datos high/critical → send externo sin approval | critical |
| FH-002 | Input no confiable alcanza read sobre activo high/critical | high |
| FH-003 | Input no confiable → send externo sin approval gate | high |
| FH-006 | Input no confiable → fetchWeb sin contentValidation → output externo sin approval | high |
| FH-007 | Cadena multi-agente (3+) sin intermediate controls | high |
| FH-010 | Input no confiable → executeCode en tool con sandbox_enabled=false | high |
| FH-011 | Input no confiable → modify/delete sobre activo medium+ sin approval ni rollback | high |
| FH-014 | Agente low-trust/full-auto delega a trusted-core sin scoped delegation | high |
| FH-016 | Code execution tool sin sandbox | critical |

#### Savia-specificas (nuevas)

| Rule | Pattern | Severity |
|------|---------|----------|
| SV-001 | Agente con bash accede a PAT_FILE | critical |
| SV-002 | Agente autonomous (L4) sin humanInTheLoop en accion destructiva | critical |
| SV-003 | Agente escribe en N3+ y output_boundary=external sin approval | critical |
| SV-004 | Agente lee N4a/N4b y delega a agente con output externo | critical |
| SV-005 | Agente con write:true modifica CLAUDE.md/CONSTITUCION.md sin PR humano | high |
| SV-006 | Delegacion en cadena >3 niveles sin gate intermedio | high |
| SV-007 | Agente fast model con bash:true y input no confiable | high |
| SV-008 | Memoria L3 compartida entre agentes con distinto trust_level | medium |
| SV-009 | Agente con accesso Azure DevOps y sin PAT_FILE filter | high |
| SV-010 | Agente con glob:true + write:true en raiz del workspace | medium |
| SV-011 | Dos agentes autonomous colaboran sin maker-checker gate | high |
| SV-012 | Agente con webfetch accede a URL sin allowlist | medium |
| SV-013 | Agente publica en output/external y escribe en memoria L2+ compartida | high |
| SV-014 | Skill autonomous invocada sin double-optin (SPEC-186) | high |
| SV-015 | Agente modifica .opencode/agents/*.md (auto-modificacion) | critical |
| SV-016 | Agente con task:true delega sin scope restriction a heavy model | medium |
| SV-017 | Agente con permission L3+ y herramienta de escritura en docs/rules/ | high |
| SV-018 | Ciclo de delegacion: A→B→A (delegacion circular) | high |

### 2.3 Motor de Analisis

```python
# scripts/analyze-agent-graph.py
import networkx as nx
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class Finding:
    rule_id: str
    title: str
    severity: str  # critical, high, medium, low, info
    score: float   # 0-10
    path: List[str]  # node IDs on the attack path
    description: str
    recommended_controls: List[str]
    owasp_agentic: List[str]
    mitre_atlas: List[str]

def analyze_graph(graph: AgentGraph) -> List[Finding]:
    """
    Pipeline:
    1. Construir DiGraph con NetworkX
    2. Encontrar todos los nodos input con trust_level=untrusted
    3. Encontrar todos los nodos output con boundary=external
    4. Para cada regla: ejecutar path/pattern query en el grafo
    5. Para cada finding: calcular score (base_severity + sensitivity_weight + ...)
    6. Ordenar por score descendente
    """
    G = build_nx_graph(graph)
    untrusted_inputs = find_nodes_by_property(G, "trust_level", "untrusted")
    external_outputs = find_nodes_by_property(G, "boundary", "external")
    sensitive_assets = find_nodes_by_property(G, "sensitivity", ["high", "critical"])

    findings = []
    for rule in RULES:
        matches = rule.detect(G, untrusted_inputs, external_outputs, sensitive_assets)
        for match in matches:
            score = compute_score(rule, match, G)
            findings.append(Finding(
                rule_id=rule.id,
                severity=score_to_severity(score),
                score=score,
                path=match.path,
                ...
            ))
    return sorted(findings, key=lambda f: f.score, reverse=True)
```

### 2.4 Scoring (modelo estandar de severity + sensitivity + controls)

```
score = base_severity_value
      + data_sensitivity_weight    # N4b=+2.0, N4a=+1.5, N3=+1.0, N2=+0.5, N1=+0
      + external_reach_weight      # external_output=+1.5, local=0
      + control_absence_weight     # sin approval gate=+1.0, sin sandbox=+1.5
      + reversibility_penalty      # no reversible=+1.0
      + agent_count_weight         # >3 agentes en path=+0.5, >5=+1.0
      + autonomy_weight            # autonomous agent=+1.0, full_auto=+1.5
      - existing_controls_credit   # permission L0=-1.0, L1=-0.5, HITL presente=-1.5
```

Clamped to [0, 10]. Severity bands: >=9 critical, >=7 high, >=4 medium, >=2 low, else info.

---

## 3. Inputs/Outputs

### Input

- `.opencode/agents/*.md` — 83 ficheros de definicion de agentes (frontmatter YAML)
- `.claude/settings.json` — configuracion de hooks, permisos, modelos
- `docs/rules/domain/autonomous-safety.md` — reglas de seguridad autonoma
- `docs/memory-system.md` — definiciones de niveles de memoria
- `docs/rules/domain/context-placement-confirmation.md` — niveles N1-N4b
- `CLAUDE.md` + `AGENTS.md` + `SKILLS.md` — reglas criticas, delegacion

### Output

- `.savia/security/agent-graph.json` — grafo completo (nodos + edges) en formato IR
- `.savia/security/agent-graph.md` — informe markdown con:
  - Resumen ejecutivo (total findings, criticos, altos)
  - Tabla de findings ordenada por score
  - Grafo de ataque para los 3 findings mas criticos (Mermaid)
  - Controles recomendados por finding
  - Mapa de calor: agentes x nivel de riesgo
- `output/security/agent-graph-{date}.json` — export para CI/CD

---

## 4. Constraints and Limits

- Max depth de path analysis: 8 hops (estandar de la industria)
- Todos los paths se computan deterministicamente (NetworkX all_simple_paths con cutoff)
- Las reglas son YAML (catalogo) + Python (deteccion) — separacion declarativa/operacional
- El script NUNCA modifica nada — es read-only
- Debe ejecutarse en <5s para no bloquear hooks pre-commit
- Cache del grafo en `.savia/security/.cache/` para evitar re-parseo si no hay cambios

---

## 5. Test Scenarios

1. **Smoke test**: extraer grafo de 83 agentes — verificar que todos los nodos y edges existen
2. **FH-001 detection**: simular path input→agent(bash)→PAT_FILE→azure_devops — debe detectar critical
3. **SV-001 detection**: agente con bash:true + acceso a PAT_FILE — debe detectar critical
4. **SV-008 detection**: dos agentes comparten L3 memory con distinto trust_level — debe detectar medium
5. **SV-015 detection**: agente con write:true y path a `.opencode/agents/` — debe detectar critical
6. **False positive check**: agente con permission L0 + bash:true — no debe generar FH-010 (sin input path)
7. **Performance**: 83 agentes, 400+ edges — analisis completo en <5s
8. **Determinismo**: dos ejecuciones identicas producen el mismo output (hash verificable)
9. **Cache invalidation**: modificar un .md de agente → cache se invalida → re-analisis
10. **Edge cases**: 0 agentes (error graceful), 1000 agentes (perf dentro de limites)

---

## 6. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `scripts/extract-agent-graph.py` | Extraccion del grafo desde .opencode/agents/ |
| `scripts/analyze-agent-graph.py` | Motor de analisis (NetworkX + reglas) |
| `scripts/catalogs/agent-rules.yaml` | Catalogo de 35 reglas (17 FH + 18 SV) |
| `scripts/catalogs/agent-capabilities.yaml` | Mapeo tool→capability para Savia |
| `scripts/catalogs/agent-controls.yaml` | Catalogo de controles recomendados |
| `tests/test_agent_graph_extraction.py` | Tests de extraccion |
| `tests/test_agent_graph_analysis.py` | Tests de reglas y scoring |
| `tests/fixtures/agent-graph-fixture.json` | Fixture de grafo para tests |
| `.savia/security/.gitkeep` | Directorio de seguridad |

### Modificar

| Fichero | Cambio |
|---|---|
| `.claude/settings.json` | Añadir hook pre-commit `agent-security-check.sh` |
| `CLAUDE.md` | Añadir referencia en lazy-loading |

---

## 7. Codigo de Referencia

- **BloodHound-style capability graph pattern**: modelo de grafo tipado para analisis de rutas de ataque en arquitecturas multi-agente
  - FastAPI + NetworkX + Pydantic v2 para el backend de analisis
  - Reglas declarativas en YAML con deteccion en Python (separacion concerns)
  - `core/rules/path_rules.py` — deteccion de rutas de ataque con NetworkX
  - `core/rules/node_rules.py` — deteccion de patrones en nodos individuales
  - `core/rules/scoring.py` — sistema de scoring (base_severity + sensitivity + controls)
  - `core/graph/traversal.py` — consultas de grafo con max_depth=8
  - `catalogs/rules.yaml` — reglas declarativas con metadata
  - `catalogs/capabilities.yaml` — catalogo de capacidades neutrales (sin sensitivity en el nombre)
  - `catalogs/controls.yaml` — catalogo de controles con effect: total|partial
  - `core/controls/simulator.py` — simulacion what-if de controles
- **BloodHound (inspiracion original)**: modelo de grafo de AD para ciberseguridad
- **Savia existente**: `scripts/extract-domain-entities.py` — patron similar de extraccion desde ficheros

---

## 8. Reglas de Negocio

1. El analisis es deterministico — mismos inputs → mismos findings
2. Las reglas son versionadas en `scripts/catalogs/agent-rules.yaml` (git)
3. Nuevas reglas se añaden sin modificar codigo (driver declarativo)
4. El score nunca excede 10.0 ni baja de 0.0
5. Un finding es "attack" si explota un path input→output; "hygiene" si es missing control
6. Los controles recomendados son sugerencias — no se aplican automaticamente
7. El informe debe ser comprensible por un humano no tecnico (resumen ejecutivo)
8. Si el grafo no se puede extraer (malformed agents), el script falla con mensaje claro
9. NUNCA se bloquea un commit por hygiene findings (solo attack findings critical/high)
10. La whitelist de falsos positivos se mantiene en `.savia/security/false-positives.yaml`

---

## 9. Estado de Implementacion

- [ ] S1: Extraccion del grafo de agentes (extract-agent-graph.py)
- [ ] S2: Catalogo de reglas estandar (FH-001..FH-018) adaptadas a Savia
- [ ] S3: Catalogo de reglas Savia-specificas (SV-001..SV-018)
- [ ] S4: Motor de analisis con NetworkX (analyze-agent-graph.py)
- [ ] S5: Sistema de scoring
- [ ] S6: Generacion de informe markdown con grafo Mermaid
- [ ] S7: Hook pre-commit (.claude/settings.json)
- [ ] S8: Tests unitarios y de integracion
- [ ] S9: Documentacion (README en .savia/security/)

---

## 10. Checklist Pre-Entrega

- [ ] Todos los 83 agentes se parsean correctamente (sin excepciones)
- [ ] Las 35 reglas tienen al menos un test
- [ ] Scoring produce valores en [0, 10]
- [ ] Informe markdown renderiza correctamente en GitHub
- [ ] Grafo Mermaid funcional (sin errores de sintaxis)
- [ ] Hook pre-commit no ralentiza >5s
- [ ] Cobertura de tests >80%
- [ ] Codigo sin dependencias externas mas alla de NetworkX y PyYAML (stdlib)
- [ ] Licencia compatible: solo patron arquitectonico, no codigo copiado
- [ ] Documentado en AGENTS.md y SKILLS.md

---

## 11. Security Review Notes

> A completar por security-guardian antes de implementacion.

- **Riesgo**: El propio analizador lee todos los ficheros de configuracion de agentes. Si se compromete, expone el grafo completo de seguridad. Mitigacion: readonly, sin output externo, solo escribe en .savia/security/.
- **AGPL-3.0 compliance**: Solo se toma inspiracion arquitectonica (patrones, catalogo de reglas). No se copia codigo fuente. El output es MIT.
- **OWASP Agentic Top 10**: Este spec implementa defensa contra T1-T6 al hacerlos detectables.
