---
spec_id: SPEC-099
title: gitagent Export Adapter — Make pm-workspace Agents Portable
status: PROPOSED
origin: open-gitagent/gitagent analysis (2026-04-15)
severity: Alta
effort: ~16h (2 días)
priority: baja
---

# SPEC-099: gitagent Export Adapter

## Problema

Los 56 agentes especializados de pm-workspace viven en formato propio
(`.claude/agents/{name}.md` con frontmatter Claude Code-específico). No son
exportables a otros frameworks (OpenAI Assistants, CrewAI, Cursor, Lyzr).

`open-gitagent/gitagent` (2.7k★, MIT, v0.2.0 abril 2026) propone un estándar
git-native con adapters bidireccionales. Si gitagent gana adopción como THE
standard de definición de agentes portable, los agentes de pm-workspace
quedan en silo Claude Code.

Adicionalmente, gitagent formaliza patrones que pm-workspace ya implementa
de forma implícita (segregation of duties, identity, manifesto único). Adoptar
parcialmente su vocabulario aumenta credibilidad enterprise sin perder
diferenciación.

## Solucion

Adapter unidireccional **pm-workspace → gitagent v0.1.0** que toma un agente
nuestro y genera la estructura gitagent equivalente:

```
.claude/agents/architect.md
       ↓ (adapter)
output/gitagent-export/architect/
├── agent.yaml          # manifesto compilado
├── SOUL.md             # identidad (extraída de description + body)
├── RULES.md            # restricciones (extraídas del body + autonomous-safety)
├── DUTIES.md           # segregation (mapeado desde permission_level)
├── skills/             # links simbólicos a skills consumidos
└── README.md           # generado: cómo usarlo en cada framework
```

## Mapeo

| pm-workspace | gitagent | Estrategia |
|--------------|----------|-----------|
| `frontmatter.name` | `agent.yaml: name` | Directo |
| `frontmatter.description` | `agent.yaml: description` + primera línea SOUL | Split |
| `frontmatter.tools` | `agent.yaml: tools` | Directo |
| `frontmatter.token_budget` | `agent.yaml: limits.context_tokens` | Renombrar |
| `frontmatter.permission_level` (L0-L4) | `DUTIES.md` policy | Tabla equivalencias |
| Body markdown | Split entre `SOUL.md` (qué/quién) y `RULES.md` (qué SI/NO) | Heurística por encabezados |
| Skills referenciadas | `skills/` con symlinks | Detectar `@.claude/skills/` |
| `agent.activation` (Task tool) | `agent.yaml: activation.framework_hints` | Mapeo |

### Permission levels → DUTIES

```yaml
# L0 Observer
duties:
  must_never: [write_files, execute_bash]
  must_always: [read_only]
# L3 Developer
duties:
  must_never: [merge_pr, deploy_prod, destroy_data]
  must_always: [create_branch_agent_*, request_human_review]
  conflicts_with: [code_reviewer_role, security_judge_role]
```

### SOUL.md template

```markdown
# {agent.name}

## Who I am
{frontmatter.description}

## My role
{first paragraph of body}

## My values
- Radical honesty (Rule #24 of pm-workspace)
- {extracted from body if present}

## How I communicate
{tone derived from agent type — opus → analytical, sonnet → executor, haiku → terse}
```

## Comando nuevo

```bash
/agent-export {agent-name} [--target gitagent] [--out output/gitagent-export/]
/agent-export --all                        # exporta los 56 agentes
/agent-export --validate {dir}             # valida contra JSON schema gitagent v0.1.0
```

## Validación

- JSON schema oficial gitagent v0.1.0 (descargable de su repo)
- Tests BATS por cada agente exportado: estructura presente, frontmatter parseable, links válidos
- CI gate: si modifico un agente nuestro, el export sigue siendo válido (regression)

## Reglas de negocio

- **GA-EXP-01**: NO modificar agentes pm-workspace nativos para acomodar gitagent (export es derivado, no fuente)
- **GA-EXP-02**: SOUL.md NUNCA contiene PII de equipo o cliente (regla #20 sigue aplicando)
- **GA-EXP-03**: Skills referenciadas se incluyen como symlinks, no copias (single source of truth)
- **GA-EXP-04**: Si un agente tiene `permission_level` no mapeable, exportar con `DUTIES.md: review_required: true` y warning
- **GA-EXP-05**: Output va a `output/gitagent-export/` (gitignored), nunca al repo principal

## Bidireccional (futuro, fuera de scope)

Import gitagent → pm-workspace queda fuera del scope inicial. Razones:
- Riesgo de degradar agentes nuestros si importamos gitagent menos rigurosos
- Foco: defensa (export) primero, ofensa (import + composición) después

## Acceptance criteria

- [ ] `/agent-export architect` genera estructura gitagent válida en <5s
- [ ] `/agent-export --all` genera 56 directorios sin errores en <2 min
- [ ] `/agent-export --validate output/gitagent-export/architect` pasa contra JSON schema oficial
- [ ] Documentación: README.md por agente exportado explica cómo usarlo en Claude/OpenAI/Cursor
- [ ] BATS suite cubre 5 agentes representativos (uno por permission_level)
- [ ] CI gate añadido: si .claude/agents/*.md cambia, regenerar export y validar
- [ ] Documentado en docs/agents-portability.md

## Métricas de éxito

- Cobertura: 56/56 agentes exportables sin warnings
- Latencia: <100ms por agente
- Adopción comunidad: tracker en GitHub Discussions de pm-workspace

## Out of scope

- Import gitagent → pm-workspace (futura iteración, requiere análisis riesgos)
- Adapters a OpenAI Assistants directamente (gitagent ya los provee)
- Reescribir agentes nativos en estructura gitagent (NO migración, sólo export)
- Publicación de cada agente exportado como repo individual en GitHub

## Justificación estratégica

**Defensiva:** si gitagent se convierte en estándar de facto (trayectoria 2.7k★
en 6 meses sugiere posibilidad), los agentes pm-workspace quedan aislados.
Adapter export es seguro de adoptar gitagent desde el día uno sin reescribir.

**Ofensiva:** publicar nuestros 56 agentes en formato gitagent es el mayor
asset comunitario que podemos liberar. Otros frameworks pueden consumirlos.
Posicionamiento: pm-workspace = orquestación + PM, gitagent = estándar de
definición. Complementarios, no competidores.

**Compliance:** adoptar `DUTIES.md` formaliza segregation of duties que ya
hacemos implícito. Útil para clientes con FINRA/SEC/Fed/AEPD (vertical-finance,
aepd-compliance ya existen — esto los refuerza).

## Referencias

- [open-gitagent/gitagent](https://github.com/open-gitagent/gitagent)
- [gitagent SPECIFICATION.md v0.1.0](https://github.com/open-gitagent/gitagent/blob/main/spec/SPECIFICATION.md)
- agent-permission-levels.md (mapeo a DUTIES)
- autonomous-safety.md (reglas que codifica DUTIES)
- agents-catalog.md (los 56 agentes a exportar)
