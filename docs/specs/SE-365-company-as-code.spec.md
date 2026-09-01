# SE-365 — Company as Code: Estándar Unificado de Entidades Organizacionales

**Status:** APPROVED (2026-09-01, operadora grant merge)
**Fecha:** 2026-09-01
**Área:** Arquitectura de conocimiento / Gobernanza / Organización
**Fuente de inspiración:** Company as Code (Rothmann, 42futures, 2025) + Anthropic AI-Native SDLC Playbook ("registros, no archivos")
**Criterio humano aplicable:** CRIT-001 (todo local, N3+ jamás a cloud)

> **Nota de renumeración**: este spec era originalmente SE-265 (borrador de Mónica).
> SE-265 ya estaba asignado a `SE-265-court-model-tiers` (fase previa). Se renumeró a
> **SE-365** para evitar colisión. El contenido es el mismo borrador, adaptado al estado
> real del workspace en 2026-09-01.

---

## 1. Motivación

Savia resuelve, para agentes IA, el problema que "Company as Code" plantea de forma
genérica: representar una organización como algo **versionable, consultable y gobernado
por criterio explícito**, en vez de como documentos estáticos dispersos. `CRITERIO.md`
y `CONSTITUCION.md` ya son una capa constitucional ejecutable.

Lo que falta es **generalizar el patrón**: un formato estándar para declarar las
*entidades* sobre las que el criterio opera — la empresa, sus proyectos, sus recursos.
Sin ese estándar, cada vault modela esta información ad hoc, rompiendo:

- la queryability entre vaults federados (SE-263)
- la capacidad de un agente de razonar sobre "qué proyectos dependen de qué recurso"
- la trazabilidad de auditoría (quién cambió qué relación organizacional, cuándo, por qué)

## 2. Alcance

**Dentro:**
- Formato de declaración de entidades (esquema, sintaxis, ubicación en el vault)
- Modelo de relaciones entre las tres capas (Company ↔ Projects ↔ Resources)
- Integración con la capa constitucional (CRITERIO.md como validador, no contenedor)
- Diseño del skill/agente `org-registrar`
- Reglas de gobernanza (qué escrituras requieren puerta humana)

**Fuera (specs derivadas):**
- UI low-code para stakeholders no técnicos
- Integraciones externas (Azure AD, GitLab issues) más allá de lectura de evidencia
- Extensión a robots/hardware

## 3. Principios de diseño

1. **Un vault, un grafo, tres capas.** Company, Projects y Resources son tres tipos de
   nodo en el mismo grafo, con relaciones internas y cruzadas.
2. **Markdown + frontmatter, no un DSL nuevo.** Cada entidad es un `.md` con frontmatter
   YAML tipado + cuerpo narrativo. Legibilidad humana, diffs limpios, cero parser propio.
3. **Relaciones por referencia, no por anidamiento.** Cada entidad referencia a otras por
   `id` estable (slug). El grafo se reconstruye indexando referencias.
4. **CRITERIO.md valida, no almacena.** Las entidades viven en su propio árbol
   (`/company/`, `/projects/`, `/resources/`); la capa constitucional solo valida.
5. **Escritura con puerta humana, lectura libre para agentes.** Cualquier agente lee y
   razona; toda escritura que cree/modifique/elimine pasa por confirmación humana.
6. **Compatible con federación (SE-263).** El formato se sincroniza vía A2A sin cambios;
   referencias cross-vault se cualifican con el id de instancia.
7. **Provenance (SE-352).** Cada entidad lleva `origin` (owner/agent) y `source` — el
   estándar de memoria de SE-352 aplica al grafo organizacional.

## 4. Estructura de directorios

> El grafo vive bajo `org/` (árbol SE-365 dedicado), separado de `projects/` de
> pm-workspace (que aloja vaults de proyectos con datos y está protegido por
> `protect-project-privacy`).

```
org/
├── company/
│   ├── _company.md              # nodo raíz: identidad de la organización
│   ├── roles/<role-slug>.md
│   ├── units/<unit-slug>.md
│   ├── people/<person-slug>.md
│   └── policies/<policy-slug>.md
├── projects/<project-slug>.md
└── resources/
    ├── infra/<resource-slug>.md
    ├── tools/<resource-slug>.md
    └── knowledge/<resource-slug>.md
```

`CRITERIO.md` / `CONSTITUCION.md` permanecen en la raíz, sin cambios de ubicación.

## 5. Esquema de entidad (frontmatter común)

```yaml
---
id: <slug único en el vault>
type: role | unit | person | policy | project | resource
name: <nombre legible>
status: active | deprecated | proposed
owner: <id de person o unit>
relations:
  - { type: <RelationType>, target: <id> }
created: <ISO date>
updated: <ISO date>
origin: owner | agent                    # SE-352 provenance
source: [human | agent:<nombre>]         # quién declaró la entidad
---

<cuerpo libre en markdown: contexto, notas, historia>
```

### 5.1 Company as Code

Nodos: `role`, `unit`, `person`, `policy`.

```yaml
---
id: role-arquitecto-soluciones
type: role
name: "Arquitecto/a de Soluciones"
responsibilities:
  - "Diseño de arquitectura hexagonal/DDD"
relations:
  - { type: BelongsToUnit, target: unit-consultoria }
---
```

```yaml
---
id: policy-soberania-datos
type: policy
name: "Soberanía de datos"
enforcement: mandatory
implements_criterio: CRITERIO#soberania-datos
relations:
  - { type: AppliesTo, target: unit-consultoria }
---
```

`implements_criterio` es el puente explícito entre una política operativa y el principio
constitucional que la justifica — permite responder "¿qué políticas implementan qué
principio?" con una consulta.

### 5.2 Projects as Code

```yaml
---
id: project-savia-federacion
type: project
name: "Federación multi-instancia Savia"
status: active
owner: person-monica
relations:
  - { type: ImplementsSpec, target: SE-263 }
  - { type: UsesResource, target: resource-gitlab-homelab }
  - { type: OwnedByUnit, target: unit-savia-core }
milestones:
  - { name: "Protocolo A2A sobre VPN", status: done }
---
```

Se integra con pm-workspace/SDD: un `project` referencia sus specs (`ImplementsSpec`)
sin duplicar contenido — la fuente de verdad sigue siendo el repo de specs.

### 5.3 Resources as Code

```yaml
---
id: resource-gitlab-homelab
type: resource
category: infra | tool | knowledge | credential-ref
name: "GitLab auto-hospedado"
relations:
  - { type: UsedByProject, target: project-savia-federacion }
  - { type: GovernedByPolicy, target: policy-soberania-datos }
sensitivity: internal | restricted    # nunca "secret" — credenciales nunca viven en el vault
---
```

**Regla explícita**: `resources` documenta la *existencia y relaciones*, nunca
credenciales ni secretos — coherente con CRIT-001.

## 6. Tipos de relación (vocabulario controlado)

| Relación | Dominio → Rango | Semántica |
|---|---|---|
| `BelongsToUnit` | person/role → unit | pertenencia jerárquica |
| `ManagedBy` | person → person | reporta a |
| `AppliesTo` | policy → unit/role/project | alcance de una política |
| `ImplementsCriterio` | policy → CRITERIO entry | trazabilidad constitucional |
| `ImplementsSpec` | project → spec (SE-XXX) | trazabilidad técnica |
| `UsesResource` / `UsedByProject` | project ↔ resource | dependencia operativa (inversa) |
| `OwnedByUnit` | project/resource → unit | responsabilidad organizacional |
| `GovernedByPolicy` | resource → policy | qué política rige ese recurso |

El vocabulario es extensible pero controlado: nuevas relaciones se proponen como entrada
a esta spec, no se inventan libremente (para que las queries sigan siendo fiables).

## 7. Skill/agente: `org-registrar`

**Responsabilidades:**
- **Lectura/consulta:** responder "¿qué proyectos usan este recurso?", "¿qué políticas
  aplican a esta unidad?", "¿qué pasaría si desactivo este recurso?" (impact analysis)
- **Validación:** verificar contra CRITERIO.md que una entidad/relación nueva no viola
  un principio inmutable
- **Escritura mediada:** prepara el diff, lo presenta, lo aplica solo tras confirmación
- **Consistencia referencial:** comprobar que el `target` existe y el tipo de relación es
  válido para el par de tipos
- **Generación de vista humana:** renderizar el grafo como resumen legible

**Fuera:** no decide política ni criterio — solo administra la representación.

## 8. Gobernanza y puerta humana

| Acción | Requiere confirmación humana |
|---|---|
| Consultar/leer el grafo | No |
| Proponer una nueva entidad | Sí (el agente prepara, el humano aprueba) |
| Modificar relaciones existentes | Sí |
| Eliminar una entidad | Sí, con verificación de impacto previa |
| Vincular `policy` a CRITERIO.md | Sí — es modificación de alcance constitucional |

## 9. Compatibilidad con federación (SE-263)

Cada vault mantiene su sub-grafo. Referencias cross-vault se resuelven con el mecanismo
de context domes; el `id` se cualifica con el id de instancia
(`instancia-b:resource-gitlab-homelab`).

## 10. Integración con specs ya implementadas (estado 2026-09-01)

| Spec | Aporte a SE-365 |
|---|---|
| SE-352 (trust-gated memory) | `origin`/`source` en el frontmatter de entidades |
| SE-355 (audit ledger) | cada escritura al grafo emite receipt `enforced` |
| SE-363 (records-not-files) | patrón: Markdown = vista, JSONL/índice = dato consultable |
| SE-362 (risk-tiering) | la escritura de entidades se clasifica por tier (T1 docs / T3 políticas) |
| SE-258 (identidad) | `owner`/`person` validados contra los activos de identidad |
| SE-263 (federación) | referencias cross-vault cualificadas |

## 11. Fases de implementación

1. **Fase 0 — Esquema y vocabulario.** Cerrar frontmatter mínimo y vocabulario (esta spec).
2. **Fase 1 — Company as Code.** Modelar roles/unidades/personas/políticas del propio
   workspace como piloto, con puente `ImplementsCriterio`.
3. **Fase 2 — Projects as Code.** Integrar con pm-workspace: cada spec activa obtiene su
   nodo `project`, sin duplicar contenido.
4. **Fase 3 — Resources as Code.** Catalogar infraestructura local (GitLab homelab, etc.).
5. **Fase 4 — `org-registrar`.** Implementar el skill/agente (lectura primero, escritura mediada después).

## 12. Criterios de aceptación

- **AC-0** Frontmatter común validado por `org-registrar validate` (test con fixture)
- **AC-1** Vocabulario de relaciones cerrado: relación no listada → WARN + rechazo
- **AC-2** Consistencia referencial: `target` inexistente → error
- **AC-3** Entidad con `origin: owner` + `source: human` es la única que puede declarar
  políticas; `agent` puede proponer (marca `proposed`)
- **AC-4** Escritura mediada: el skill prepara diff y requiere confirmación (exit 2 sin ella)
- **AC-5** Grafo indexado consultable ("qué proyectos usan recurso X") en <2s
- **AC-6** CRITERIO.md intacto (la capa valida, no almacena)
- **AC-7** Sin regresión: suite SE-363/355/352 verde

## 13. Preguntas abiertas (decididas en implementación)

- `org-registrar` como skill invocado bajo demanda (decidido: skill, no agente con ciclo de vida)
- `type: team` entre `unit` y `project` (aplazado — Savia Flow lo define por separado)
- Vocabulario de relaciones versionado como sección de esta spec (decidido: sección 6)

## Validación (ejecutada en esta sesión)

- `scripts/org-registrar.py`: valida frontmatter común, vocabulario de relaciones cerrado,
  consistencia referencial, origin/source (SE-352), sensitivity nunca secret; 6 pytest + 5 bats verdes
- Grafo piloto: 5 entidades en `org/` (unit-savia-core, person-monica, policy-soberania-datos,
  resource-gitlab-homelab, project-savia-federacion) — validadas OK
- Skill `org-registrar` (peripheral, governance) creado; SCM + SKILLS.md + rules INDEX regenerados

## Referencias

- Company as Code: Rothmann, 42futures, 2025
- Savia: CRITERIO.md, SE-258, SE-263, SE-352, SE-355, SE-362, SE-363
- CRIT-001 · `autonomous-safety.md`
