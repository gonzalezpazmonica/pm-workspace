# Spec: SE-303 — Intent-Based Agent Dispatch

**Task ID:**        SE-303
**PBI padre:**      SE-303 — Refactor del configurator con arquitectura micro-kernel de intents
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     python-developer + architect
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 150 min |
| Human effort | 8 h |
| Review effort | 60 min |
| Context risk | high |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 4h. Tocar el configurator es delicado. |

---

## 1. Contexto y Objetivo

Savia usa el **configurator** (agente fast, L1) para decidir que skill o agente
invocar ante cada intent del usuario. El modelo actual es un LLM que emite JSON
con la decision. Funciona, pero tiene limitaciones:

1. **No determinismo**: mismo intent puede producir distinta decision segun el sampling
2. **No trazabilidad**: no hay registro de por que se eligio skill X sobre skill Y
3. **No extensibilidad**: añadir una skill nueva requiere re-entrenar mentalmente al LLM
4. **Caja negra**: si el configurator falla, no hay fallback explicito
5. **Acoplamiento**: la logica de dispatch esta embebida en el prompt del agente

La arquitectura micro-kernel para traduccion de intents propone un modelo donde:
- Un **core** recibe intents (expectationVerb + expectationObject + expectationContexts)
- Un **catalogo de ILUs** (Intent Logic Units) mapea intents→acciones
- **Executioners** son los plugins que ejecutan (CLI, HTTP, gRPC)
- El core es deterministico; los ILUs son bibliotecas Python versionables

**Objetivo**: refactorizar el configurator de Savia para adoptar esta arquitectura:

```
Usuario: "analiza esta tabla de ventas"
  → Intent: {verb: "analyze", object: "tabular_data", contexts: ["sales"]}
  → Core classifier (deterministico): match contra catalogo de intents
  → ILU match: "tabular-intelligence" skill (score: 0.95)
  → Executioner: skill-loader invoca tabular-intelligence
  → Trace: {intent, match_scores, alternatives, decision_reason} → audit log
```

---

## 2. Contrato Tecnico

### 2.1 Modelo de Intent

```python
# scripts/intent-engine/models.py

from dataclasses import dataclass, field
from typing import List, Optional, Dict
from enum import Enum

class ExpectationVerb(str, Enum):
    CREATE = "create"
    READ = "read"
    UPDATE = "update"
    DELETE = "delete"
    ANALYZE = "analyze"
    GENERATE = "generate"
    DEPLOY = "deploy"
    REVIEW = "review"
    SEARCH = "search"
    EXECUTE = "execute"
    PLAN = "plan"
    MONITOR = "monitor"
    AUDIT = "audit"
    CONFIGURE = "configure"

class ExpectationObject(str, Enum):
    CODE = "code"
    TABULAR_DATA = "tabular_data"
    DOCUMENT = "document"
    SPRINT = "sprint"
    BACKLOG = "backlog"
    WORK_ITEM = "work_item"
    TEST = "test"
    SECURITY = "security"
    INFRASTRUCTURE = "infrastructure"
    MEETING = "meeting"
    MEMORY = "memory"
    ARCHITECTURE = "architecture"
    DEPLOYMENT = "deployment"
    COST = "cost"
    TEAM = "team"
    KNOWLEDGE = "knowledge"

@dataclass
class Intent:
    verb: ExpectationVerb
    object: ExpectationObject
    contexts: List[str] = field(default_factory=list)
    targets: Dict[str, str] = field(default_factory=dict)
    raw_prompt: str = ""

@dataclass
class IntentMatch:
    skill_name: str
    agent_name: Optional[str]
    score: float
    reason: str
    alternatives: List[tuple]  # [(skill_name, score), ...]
```

### 2.2 Catalogo de Intents (Intent Logic Units)

```yaml
# scripts/intent-engine/catalogs/skill-catalog.yaml
# Cada ILU mapea un patron intent → skill/agent con scores

catalog:
  - intent:
      verb: ANALYZE
      object: TABULAR_DATA
    matches:
      - skill: tabular-intelligence
        agent: null
        score: 0.95
        reason: "Specialized statistical profiling. Best for structured data."
      - skill: tabular-intelligence
        agent: tabular-analyst
        score: 0.90
        reason: "Same as above, but with dedicated agent."
      - skill: enterprise-analytics
        agent: null
        score: 0.70
        reason: "For enterprise KPIs. Overkill for general tabular data."

  - intent:
      verb: REVIEW
      object: CODE
    matches:
      - skill: null
        agent: code-reviewer
        score: 0.95
        reason: "Primary code review agent. Quality gate pre-merge."
      - skill: consensus-validation
        agent: null
        score: 0.80
        reason: "Multi-judge validation. Use for architecture-level review."

  - intent:
      verb: GENERATE
      object: TEST
    matches:
      - skill: null
        agent: test-architect
        score: 0.90
        reason: "Test design and generation across 16 language packs."
      - skill: null
        agent: test-engineer
        score: 0.85
        reason: ".NET specialized. Use when project is C#."

  - intent:
      verb: DEPLOY
      object: INFRASTRUCTURE
    matches:
      - skill: null
        agent: infrastructure-agent
        score: 0.90
        reason: "Infrastructure management. Terraform, Azure, AWS, GCP."
      - skill: null
        agent: terraform-developer
        score: 0.85
        reason: "Terraform-specific. Use when IaC is Terraform."

  - intent:
      verb: SEARCH
      object: KNOWLEDGE
    matches:
      - skill: savia-vaults
        agent: null
        score: 0.92
        reason: "Federated search across all knowledge domes."
      - skill: savia-memory
        agent: memory-agent
        score: 0.85
        reason: "Persistent memory search. Use for user-specific data."

  # ... (catalogo completo cubriendo los 123 skills y 83 agentes)
```

### 2.3 Core Engine (micro-kernel)

```python
# scripts/intent-engine/core.py

import yaml
from typing import List
from dataclasses import dataclass

@dataclass
class DispatchDecision:
    intent: Intent
    primary_match: IntentMatch
    alternatives: List[IntentMatch]
    trace: dict
    llm_override: Optional[IntentMatch] = None  # LLM puede sugerir alternativa

class IntentEngine:
    """
    Micro-kernel deterministico para dispatch de intents.

    Flujo:
    1. LLM extrae Intent del prompt (verb + object + contexts)
    2. Core consulta el catalogo de ILUs (deterministico)
    3. Si hay match exacto (>0.85 score): dispatch directo
    4. Si hay match ambiguo (2+ matches con score similar): pedir confirmacion
    5. Si no hay match: pasar a LLM para decision (fallback)
    6. Registrar trace en audit log
    """

    def __init__(self, catalog_path: str = "scripts/intent-engine/catalogs/skill-catalog.yaml"):
        with open(catalog_path) as f:
            self.catalog = yaml.safe_load(f)["catalog"]

    def classify(self, intent: Intent) -> List[IntentMatch]:
        """Deterministic: busca matches en el catalogo por verb+object."""
        matches = []
        for rule in self.catalog:
            rule_intent = rule["intent"]
            if (rule_intent["verb"] == intent.verb.value and
                rule_intent["object"] == intent.object.value):
                for match in rule["matches"]:
                    matches.append(IntentMatch(**match))
        return sorted(matches, key=lambda m: m.score, reverse=True)

    def dispatch(self, intent: Intent) -> DispatchDecision:
        matches = self.classify(intent)
        if not matches:
            return DispatchDecision(
                intent=intent,
                primary_match=None,
                alternatives=[],
                trace={"status": "NO_MATCH", "fallback": "llm"}
            )
        primary = matches[0]
        alternatives = matches[1:4]
        return DispatchDecision(
            intent=intent,
            primary_match=primary,
            alternatives=alternatives,
            trace={"status": "MATCHED", "num_matches": len(matches)}
        )

    def needs_confirmation(self, decision: DispatchDecision) -> bool:
        """Si el top-2 tienen score similar (<0.1 diff), pedir confirmacion."""
        if len(decision.alternatives) > 0:
            gap = decision.primary_match.score - decision.alternatives[0].score
            return gap < 0.1
        return False
```

### 2.4 Integracion con Configurator existente

```python
# Modificacion en .opencode/agents/configurator.md
# El configurator delega la clasificacion deterministica al IntentEngine
# y solo usa LLM como fallback o para desambiguar

def configurator_dispatch(prompt: str) -> DispatchDecision:
    # Fase 1: LLM extrae Intent (ligero, solo clasificacion)
    intent = llm_extract_intent(prompt)  # → Intent(verb, object, contexts)

    # Fase 2: Core deterministico busca en catalogo
    decision = engine.dispatch(intent)

    # Fase 3: Si hay match claro → dispatch directo
    if decision.primary_match and not engine.needs_confirmation(decision):
        log_audit(decision)
        return decision

    # Fase 4: Si hay ambiguedad o no match → LLM decide
    if engine.needs_confirmation(decision):
        llm_choice = llm_disambiguate(prompt, decision)
        decision.llm_override = llm_choice

    # Fase 5: Si no hay match → LLM propone nuevo (y se registra para añadir al catalogo)
    if not decision.primary_match:
        suggestion = llm_suggest_new_intent(prompt)
        log_catalog_gap(intent, suggestion)

    return decision
```

---

## 3. Inputs/Outputs

### Inputs
- Prompt del usuario (texto libre)
- Catalogo de intents (`scripts/intent-engine/catalogs/skill-catalog.yaml`)
- Catalogo de skills (`SKILLS.md`) y agentes (`AGENTS.md`)
- Reglas de confianza (para desambiguacion)
- Memoria del usuario (para personalizacion de scores)

### Outputs
- `DispatchDecision` con primary_match + alternatives + trace
- `output/intent-audit.jsonl` — registro de todas las decisiones
- `output/intent-gaps.jsonl` — intents sin match (para mejorar el catalogo)

---

## 4. Constraints and Limits

- La clasificacion deterministica debe completarse en <50ms
- El LLM solo se invoca para extraer Intent (verb+object) o desambiguar — nunca para la decision completa
- El catalogo de intents es YAML versionado en git → cambios via PR
- Cada decision se registra en audit log con timestamp, intent, matches, y decision final
- El configurator actual (LLM puro) se mantiene como fallback si el IntentEngine no esta disponible
- La migracion es incremental: se empieza con 20 intents mas comunes, se expande progresivamente

---

## 5. Test Scenarios

1. **Match exacto**: "analiza esta tabla de ventas" → verb=ANALYZE, object=TABULAR_DATA → tabular-intelligence (score 0.95)
2. **Match multiple**: "genera tests para la API" → verb=GENERATE, object=TEST → test-architect vs test-engineer → gap >0.1 → dispatch directo
3. **Ambiguo**: "analiza el codigo" → ANALYZE+CODE → 2+ matches con gap <0.1 → pedir confirmacion al LLM
4. **No match**: "dibuja un diagrama de la oficina" → no match en catalogo → LLM sugiere → log gap
5. **Determinismo**: mismo prompt 100 veces → mismo Intent + mismos matches (sin LLM)
6. **Rendimiento**: 1000 consultas/sec al catalogo (dict lookup)
7. **Catalogo vacio**: fallback a LLM puro (comportamiento actual)
8. **Catalogo malformado**: error claro, no crash silencioso

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `scripts/intent-engine/core.py` | Micro-kernel deterministico |
| `scripts/intent-engine/models.py` | Modelos Intent, IntentMatch, DispatchDecision |
| `scripts/intent-engine/catalogs/skill-catalog.yaml` | Catalogo de intents (123 skills x 83 agentes) |
| `scripts/intent-engine/catalogs/generate-catalog.py` | Generador automatico desde SKILLS.md + AGENTS.md |
| `tests/test_intent_dispatch.py` | Tests unitarios |
| `tests/fixtures/intent-catalog-fixture.yaml` | Fixture reducido para tests |

### Modificar
| Fichero | Cambio |
|---|---|
| `.opencode/agents/configurator.md` | Integrar IntentEngine como primera capa |
| `docs/RESOLVER.md` | Mapear intents al catalogo |

---

## 7. Codigo de Referencia

- **Micro-kernel architecture pattern**: Core + ILU catalog + Executioners
  - Intent model: expectationVerb + expectationObject + expectationContexts + expectationTargets
  - Mermaid-based architecture docs
  - Multiple branch development strategy
- **Savia existente**:
  - `.opencode/agents/configurator.md` — dispatch actual (LLM-based)
  - `docs/RESOLVER.md` — tabla de resolucion intent→skill/agent (SE-160)
  - `scripts/smart-routing.sh` — enrutamiento de comandos
  - `docs/rules/domain/resolver-protocol.md` — protocolo de resolucion

---

## 8. Estado de Implementacion

- [ ] S1: Modelo de Intent (verbs, objects, contexts)
- [ ] S2: Generador automatico de catalogo (desde SKILLS.md + AGENTS.md)
- [ ] S3: Core deterministico (classify + dispatch)
- [ ] S4: Integracion con configurator (primera capa, fallback LLM)
- [ ] S5: Audit log (intent-audit.jsonl)
- [ ] S6: Gap detection (intents sin match → propuestas de nuevas skills)
- [ ] S7: Tests
- [ ] S8: Documentacion
