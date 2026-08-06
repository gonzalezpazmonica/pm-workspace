# Spec: SE-309 — SaviaVaults Knowledge Governance

**Task ID:**        SE-309
**PBI padre:**      SE-309 — Decision records, provenance y conflict detection en SaviaVaults
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-06
**Creado por:**     Savia (analisis de repos graph-native y memory de agentes)

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 120 min |
| Human effort | 6 h |
| Review effort | 45 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 3h |

---

## 1. Contexto y Objetivo

Savia Vaults almacena conocimiento (domes) con git-backed storage, BM25 search,
wikilinks, federacion y firma Ed25519. Pero el conocimiento se guarda **sin
gobernanza**: no hay trazabilidad de por que se tomo una decision, no se detectan
hechos contradictorios, y las notas no distinguen "lo que se sabe" de "lo que se
decidio".

Dos arquitecturas de referencia aportan patrones directamente adoptables:

1. **Graph-native accountability** (semantica): cada decision es un objeto de
   primera clase (categoria, escenario, razonamiento, resultado, confianza),
   cada hecho tiene provenance W3C PROV-O (quien/cuando/fuente), y los hechos
   contradictorios se DETECTAN en lugar de sobreescribirse en silencio.

2. **Session memory retroactiva** (deja-vu): indexa historias de sesiones ya
   escritas a disco y las recalca automaticamente al inicio; las decisiones
   revertidas se marcan como "tried and rejected" con razon y fecha (nada se
   borra, la ultima marca gana).

**Objetivo**: añadir una capa de gobernanza a Savia Vaults:

1. **Decision records** — cada decision de configuracion/arquitectura se registra
   como nodo tipado con category, scenario, reasoning, outcome, confidence.
2. **Provenance tipado** — cada nota/facto lleva procedencia (quien, cuando,
   fuente, confidence) en el frontmatter, con validacion.
3. **Conflict detection** — hechos que se contradicen (mismo entity/property con
   valores distintos) se detectan y se señalan, nunca se sobreescriben en silencio.
4. **Decision states** — una decision puede marcarse rejected/accepted con razon
   y fecha; la ultima marca gana, nada se borra (patron deja-vu promote).

**Diferencia clave**: SaviaVaults es local-first y git-backed — no se copia el
stack Python de semantica ni el binario Go de deja-vu. Se adopta el PATRON como
extension ligera en TypeScript sobre el storage existente.

---

## 2. Contrato Tecnico

### 2.1 Modelo de Decision Record

```typescript
// projects/savia-vaults/src/knowledge/decision.ts

export interface DecisionRecord {
  id: string;                 // uuid
  category: string;           // "architecture" | "config" | "dependency" | ...
  scenario: string;           // que se estaba resolviendo
  reasoning: string;          // por que
  outcome: string;            // que se decidio
  confidence: number;         // 0.0 - 1.0
  entities: string[];         // entidades del grafo relacionadas
  decision_maker: string;     // quien (agente o humano)
  state: DecisionState;       // proposed | accepted | rejected
  state_reason?: string;      // por que se revirtio (si rejected)
  created_at: string;
  updated_at: string;
  provenance: ProvenanceRef;  // fuente de la decision
}

export type DecisionState = "proposed" | "accepted" | "rejected";

export interface ProvenanceRef {
  agent: string;              // quien la creo
  source: string;             // spec, nota, reunion, PR
  timestamp: string;
  confidence: number;
}
```

### 2.2 Frontmatter con Provenance

```yaml
# Nota SaviaVaults con provenance tipado
---
entity: {type: decision, id: dec-2026-08-001}
category: architecture
scenario: "Elegir capa para el scheduler de automatizaciones"
reasoning: "SE-304 requiere persistencia y concurrencia; script Python con store JSON"
outcome: "scripts/automations/ con TaskStore JSON"
confidence: 0.85
state: accepted
provenance:
  agent: savia
  source: "SE-304-automation-scheduler.spec.md"
  timestamp: "2026-08-04T10:00:00Z"
  confidence: 0.9
confidentiality: N2
---
```

### 2.3 Conflict Detection

```typescript
// projects/savia-vaults/src/knowledge/conflicts.ts

export interface Conflict {
  id: string;
  entityId: string;
  property: string;
  valueA: string;
  valueB: string;
  sourceA: string;    // nota donde se dice A
  sourceB: string;    // nota donde se dice B
  severity: "info" | "warning" | "critical";
  status: "open" | "resolved";
  resolution?: string;
}

export class ConflictDetector {
  /** Detecta hechos contradictorios: mismo (entity, property) con valores distintos. */

  detect(notes: Note[]): Conflict[] {
    // Agrupar por (entity.id, property)
    // Si 2+ notas dan valores distintos para el mismo (entity, property):
    //   → Conflict (NO sobreescritura silenciosa)
    // Severity por confidence de cada fuente y nivel de confidencialidad
  }

  resolve(conflictId: string, resolution: string): void {
    // Marca como resuelto con la resolucion
    // El conflicto queda en el historial (nada se borra)
  }
}
```

### 2.4 Decision States (patron deja-vu promote)

```typescript
// projects/savia-vaults/src/knowledge/decision-state.ts

export class DecisionStateManager {
  /** Patron "promote": decisiones marcadas accepted/rejected con razon y fecha.
   *  La ultima marca gana. Nada se borra. */

  promote(
    decisionId: string,
    state: DecisionState,
    reason: string,
    by: string,
  ): void {
    // 1. Lee la decision actual
    // 2. Aplica el nuevo estado + reason + timestamp
    // 3. Guarda version nueva (git commit)
    // 4. La historia queda intacta (git log muestra el cambio de estado)
  }

  getActive(decisionId: string): DecisionRecord {
    // Devuelve la decision con su estado vigente (ultima marca)
  }
}
```

### 2.5 CLI Extensions

```bash
# Nuevos comandos savia-vaults

# Registrar una decision
savia-vaults decision record \
  --category architecture \
  --scenario "..." \
  --reasoning "..." \
  --outcome "..." \
  --confidence 0.85

# Marcar decision como rejected/accepted con razon
savia-vaults decision promote <id> --state rejected --reason "..." --by savia

# Listar decisiones por categoria/estado
savia-vaults decision list [--category X] [--state Y]

# Detectar conflictos en el dome
savia-vaults conflict scan [--severity all]

# Resolver un conflicto
savia-vaults conflict resolve <conflict-id> --resolution "..."
```

---

## 3. Inputs/Outputs

### Inputs
- Notas existentes del dome (con entity id en frontmatter)
- Nuevas notas con provenance tipado
- Comandos CLI de decision/conflict

### Outputs
- Decision records (nodos tipo `decision` en el grafo)
- Reporte de conflictos (`savia-vaults conflict scan`)
- Git history con cada decision/estado/conflicto (auditable)

---

## 4. Constraints and Limits

- **Local-first**: todo via storage git-backed existente, sin deps externas
- **PROV-O completo no**: se adopta un subconjunto ligero de provenance (agent,
  source, timestamp, confidence) en frontmatter — no RDF/OWL
- **Sin razonamiento Rete/Datalog**: fuera de alcance (SaviaVaults no necesita
  un motor de reglas; la deteccion de conflictos es por emparejamiento exacto)
- **Conflict detection**: por (entity, property) con valores distintos — no
  similitud semantica (evita deps de embeddings)
- Backwards compatible: notas sin provenance siguen funcionando (provenance opcional)

---

## 5. Test Scenarios

1. **Decision record**: `decision record` crea nodo `decision` con todos los campos
2. **Decision list**: filtro por category/state devuelve las correctas
3. **Promote a rejected**: decision accepted → rejected con razon → git log muestra
   el cambio, la version anterior queda
4. **Promote gana**: 2 marcas → la ultima (accepted o rejected) es la vigente
5. **Conflict detection**: 2 notas con mismo (entity, property) valores distintos
   → conflict detectado, NO sobreescritura
6. **Conflict resolve**: resolver con resolucion → status resolved, historial intacto
7. **Sin conflictos**: notas consistentes → scan vacio
8. **Backwards compatible**: nota sin provenance → no rompe, se trata como sin ref
9. **Persistencia**: decisions sobreviven a re-instantacion de storage (git)
10. **Git audit**: cada decision/conflicto genera commit trazable

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/src/knowledge/decision.ts` | Tipos y DecisionRecord |
| `projects/savia-vaults/src/knowledge/conflicts.ts` | ConflictDetector + Conflict |
| `projects/savia-vaults/src/knowledge/decision-state.ts` | DecisionStateManager (promote) |
| `projects/savia-vaults/tests/unit/knowledge/decision.test.ts` | Tests decisions |
| `projects/savia-vaults/tests/unit/knowledge/conflicts.test.ts` | Tests conflictos |

### Modificar
| Fichero | Cambio |
|---|---|
| `projects/savia-vaults/src/cli/index.ts` | Añadir `decision record/list/promote` + `conflict scan/resolve` |
| `projects/savia-vaults/src/knowledge/index.ts` | Exportar nuevos modulos |
| `docs/ROADMAP.md` | Añadir SE-309 |

---

## 7. Codigo de Referencia

- **Graph-native accountability (semantica, MIT)**:
  - `context/context_graph.py` — `record_decision(category, scenario, reasoning,
    outcome, confidence, entities, decision_maker, metadata, valid_from, valid_until)`
  - `conflicts/` — ConflictDetector, ConflictResolver, SourceTracker
  - `provenance/` — W3C PROV-O (subconjunto: agent, source, timestamp, confidence)
  - `deduplication/` — entity dedup (fuera de alcance en v1)
  - Patron: cada decision es nodo de primera clase en el grafo
- **Session memory (deja-vu, MIT)**:
  - `internal/policy/policy.go` — decision states (describe_both_denied, filter_alias,
    precedence) — patron promote/reject con razon
  - `internal/sources/` — 17 harnesses de sesiones (fuera de alcance; Savia usa
    su propia memoria)
  - `internal/query/` — ranking hibrido (lexical + vector) — ya cubierto por BM25 de SaviaVaults
  - Patron: la ultima marca gana, nada se borra, estado + razon + fecha
- **SaviaVaults existente**:
  - `src/knowledge/graph.ts` — KnowledgeGraph con MENTIONS y entities tipadas
  - `src/storage/index.ts` — git-backed storage
  - `src/cli/index.ts` — comandos CLI
  - `projects/savia-vaults/specs/SE-307-okf-adapter.spec.md` — precedente de extension

---

## 8. Reglas de Negocio

1. Cada decision es un nodo `decision` en el grafo, con los 8 campos obligatorios
2. La deteccion de conflictos es por emparejamiento exacto (entity, property)
3. NUNCA se sobreescribe un hecho contradictorio — se registra un conflict
4. La ultima marca de estado (accepted/rejected) gana; el historial queda en git
5. Un decision rejected SIEMPRE lleva razon y fecha (auditoria)
6. Provenance es opcional pero recomendado — notas sin el siguen funcionando
7. Todo cambio genera commit git (trazable)
8. Sin deps externas nuevas (stdlib TypeScript + storage existente)

---

## 9. Estado de Implementacion

- [ ] S1: Tipos DecisionRecord + ProvenanceRef (decision.ts)
- [ ] S2: ConflictDetector (conflicts.ts)
- [ ] S3: DecisionStateManager promote (decision-state.ts)
- [ ] S4: CLI (decision record/list/promote + conflict scan/resolve)
- [ ] S5: Tests (decision, conflicts, states)
- [ ] S6: Documentacion + roadmap
