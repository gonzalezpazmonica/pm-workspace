---
spec_id: SPEC-108
title: Agent Self-Improvement Loop + Sentry Root Cause Pipeline
status: PROPOSED
origin: Analysis of Rakuten QA case study (claude.com/customers/rakuten-qa, 2026-04-16)
severity: Media
effort: ~16h (2 sprints — self-improvement hook + Sentry RCA pipeline)
related_specs:
  - SPEC-106 (Truth Tribunal — validates RCA output reliability)
  - SPEC-107 (Cognitive Debt — complementary, human-side mitigation)
related_rules:
  - .claude/rules/domain/self-improvement.md (Rule #21)
  - .claude/rules/domain/agent-memory-isolation.md
  - .claude/rules/domain/postmortem-policy.md
  - .claude/rules/domain/adversarial-security.md
---

# SPEC-108: Agent Self-Improvement Loop + Sentry Root Cause Pipeline

## Origen

Rakuten QA case study (2026-04) documenta dos patrones que pm-workspace
puede adoptar sobre infraestructura existente:

1. **Agent memory cross-session para auto-mejora**: agentes que aprenden
   de sus fallos y actualizan su propia memoria persistente.
2. **Production exception agent**: investigacion automatica de excepciones
   con root cause analysis distribuido a no-tecnicos.

pm-workspace tiene los componentes pero no el cableado:

| Componente existente | Gap |
|---|---|
| `agent-memory-isolation.md` (3 niveles) | Agentes no escriben en su propia memoria tras fallos |
| `self-improvement.md` (Rule #21, lessons.md) | Solo captura correcciones humanas, no fallos de agentes |
| `post-tool-failure-log.sh` (PostToolUseFailure) | Registra fallos pero no los convierte en lecciones |
| `/sentry-bugs` + `/sentry-health` | Solo importa alertas; no genera root cause analysis |
| `/error-investigate` | Manual, solo tech-lead |
| `code-comprehension.md` + `/comprehension-report` | Mental models existen pero no se consultan en RCA |
| SPEC-106 Truth Tribunal | Valida informes; puede validar RCA auto-generado |

## Parte 1 — Agent Self-Improvement Feedback Loop

### Problema

Cuando un agente falla (test-runner encuentra un patron recurrente de
fallo, code-reviewer rechaza el mismo anti-pattern 3 veces,
dotnet-developer genera codigo que no compila), el conocimiento muere
con la sesion. El proximo agente del mismo tipo repite el error.

### Solucion

Extender `post-tool-failure-log.sh` para que, cuando un agente falla
N veces con el mismo patron, escriba una leccion en su
`public-agent-memory/{agent}/MEMORY.md` automaticamente.

### Mecanica

```
PostToolUseFailure hook detecta fallo
  ↓
Incrementar contador en ~/.savia/agent-failures/{agent}-{pattern-hash}.count
  ↓
Si contador >= 3 (mismo patron, diferentes sesiones):
  ↓
  Extraer leccion: "pattern X falla por Y. Solucion: Z."
  ↓
  Escribir en public-agent-memory/{agent}/MEMORY.md (append)
  ↓
  Resetear contador
```

### Que es un "patron"

Hash de: `agent_type` + `error_class` (primeras 2 lineas del error,
normalizadas: sin timestamps, sin paths absolutos, sin hashes).

```bash
pattern_hash() {
  local agent="$1" error="$2"
  local normalized
  normalized=$(echo "$error" | head -2 | sed 's|/home/[^ ]*/||g; s|[0-9a-f]\{7,\}||g; s|[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}||g')
  echo -n "${agent}:${normalized}" | sha256sum | cut -c1-12
}
```

### Formato de leccion auto-generada

```markdown
## Auto-learned: {fecha}
Pattern: {normalized error, 1 linea}
Cause: {inferido del contexto del fallo — solo si disponible}
Fix: {accion correctiva — solo si el patron se resolvio en alguna sesion}
Source: auto (3+ failures, pattern hash {hash})
```

### Restricciones

- **SELF-01**: la leccion se escribe en `public-agent-memory/` SOLO si
  no contiene datos de proyecto (N4) ni datos personales (N3). Si el
  error contiene paths de proyecto, sanitizar antes de persistir.
- **SELF-02**: max 30 lecciones auto-generadas por agente (FIFO).
- **SELF-03**: lecciones auto-generadas se marcan con
  `Source: auto (...)` para distinguirlas de lecciones humanas.
- **SELF-04**: un humano puede borrar cualquier leccion auto-generada
  sin consecuencias (el contador se reseteo al escribir).
- **SELF-05**: si `SAVIA_HOOK_PROFILE=minimal`, esta funcionalidad no
  corre. Solo en `standard`/`strict`.

### Ficheros afectados

| Fichero | Cambio |
|---|---|
| `.claude/hooks/post-tool-failure-log.sh` | Extender con pattern-hash + counter + auto-lesson |
| `~/.savia/agent-failures/` | Nuevo directorio para contadores (gitignored) |
| `public-agent-memory/{agent}/MEMORY.md` | Destino de lecciones auto-generadas |

## Parte 2 — Sentry Root Cause Analysis Pipeline

### Problema

Cuando Sentry reporta un error, el tech-lead ejecuta `/sentry-bugs`
para importar la alerta. El analisis de root cause es manual. Si el
componente tiene un `/comprehension-report`, nadie lo consulta. El
analisis puede contener alucinaciones que nadie verifica.

### Solucion

Pipeline automatico:

```
Sentry alerta (via /sentry-bugs o /sentry-health)
  ↓
Auto-generar draft de root cause analysis (RCA)
  ↓
Enriquecer con comprehension-report del componente si existe
  ↓
Truth Tribunal valida el RCA (SPEC-106)
  ↓
Si PUBLISHABLE: entregar RCA al tech-lead
Si ITERATE: regenerar con feedback del tribunal
Si ESCALATE: escalar a humano con contexto completo
```

### Mecanica

Nuevo comando: `/sentry-rca <sentry-issue-id>`

1. **Extraer**: obtener stack trace + contexto de Sentry via MCP/API
2. **Localizar**: mapear stack trace a ficheros del repo (grep, git blame)
3. **Contexto**: si existe `.truth.crc` o comprehension report del
   componente afectado, cargar como contexto
4. **Generar**: invocar agente `error-investigator` (L1, Sonnet) con
   stack trace + ficheros + contexto
5. **Validar**: pasar el draft por `/report-verify` (Truth Tribunal)
6. **Entregar**: si PUBLISHABLE, guardar en
   `output/rca/YYYYMMDD-{sentry-id}.md`
7. **Iterar**: si ITERATE, regenerar con findings del tribunal (max 3)

### Output: RCA report

```markdown
---
report_type: audit
sentry_issue: {id}
generated_at: {ISO}
tribunal_verdict: PUBLISHABLE
---

# Root Cause Analysis — {sentry issue title}

## Stack trace resumen
{3-5 lineas clave}

## Componente afectado
{fichero:linea, modulo, ultimo cambio (git blame)}

## Causa raiz
{analisis concreto — que falla, por que, desde cuando}

## Impacto
{que usuarios/flujos se ven afectados}

## Remediacion propuesta
{fix concreto con ejemplo de codigo si aplica}

## Mental model (si existe comprehension-report)
{referencia al report existente + gaps detectados}
```

### Restricciones

- **RCA-01**: el RCA draft SIEMPRE pasa por Truth Tribunal antes de
  entregarse. Nunca se entrega un RCA sin `verdict: PUBLISHABLE` o
  aceptacion humana explicita de `CONDITIONAL`.
- **RCA-02**: el agente de analisis es L1 (read-only). No modifica
  codigo, no ejecuta fixes, no crea PRs.
- **RCA-03**: si Sentry no esta configurado (`SENTRY_CONNECTOR_ENABLED
  = false`), el comando informa y sale. No falla.
- **RCA-04**: datos de stack trace son N4 (proyecto). El RCA se guarda
  en `output/rca/` (gitignored).

### Ficheros nuevos

| Fichero | Descripcion |
|---|---|
| `.claude/commands/sentry-rca.md` | Comando `/sentry-rca` |
| `.claude/agents/error-investigator.md` | Agente L1 Sonnet para RCA (si no existe) |

### Ficheros existentes a consultar (no modificar)

| Fichero | Uso |
|---|---|
| `.claude/commands/sentry-bugs.md` | Patron de integracion Sentry |
| `.claude/commands/sentry-health.md` | Metricas Sentry del proyecto |
| `.claude/commands/error-investigate.md` | Comando manual existente |
| `.claude/skills/code-comprehension-report/SKILL.md` | Mental models |

## Criterios de aceptacion

### Parte 1 — Agent Self-Improvement
- [ ] Hook `post-tool-failure-log.sh` extendido con pattern-hash + counter
- [ ] Leccion auto-generada al alcanzar 3 fallos del mismo patron
- [ ] Leccion sanitizada (sin paths N4, sin datos personales)
- [ ] Max 30 lecciones auto-generadas por agente (FIFO)
- [ ] BATS test con score auditor certificado

### Parte 2 — Sentry RCA Pipeline
- [ ] Comando `/sentry-rca <id>` funcional
- [ ] RCA draft pasa por Truth Tribunal automaticamente
- [ ] Output en `output/rca/YYYYMMDD-{id}.md`
- [ ] Enriquecimiento con comprehension-report si existe
- [ ] BATS test con score auditor certificado

## Plan por fases

### Sprint 1 (~8h) — Agent Self-Improvement
- [ ] Extender `post-tool-failure-log.sh`
- [ ] Pattern-hash + counter en `~/.savia/agent-failures/`
- [ ] Auto-lesson writer con sanitizacion
- [ ] BATS test

### Sprint 2 (~8h) — Sentry RCA Pipeline
- [ ] Comando `/sentry-rca`
- [ ] Agente `error-investigator` (si no existe)
- [ ] Integracion con Truth Tribunal
- [ ] BATS test + CHANGELOG

## Riesgos

| Riesgo | Mitigacion |
|---|---|
| Lecciones auto-generadas de baja calidad | Marcadas como `Source: auto`, revisables por humano. Max 30, FIFO. |
| Pattern-hash colisiona patrones distintos | Hash de 12 chars sobre 2 lineas normalizadas. Riesgo bajo. |
| RCA alucina root cause | Truth Tribunal obliga a PUBLISHABLE antes de entregar. Si alucina, ITERATE. |
| Sentry no configurado en el proyecto | RCA-03: salida limpia, no fallo. |
| Stack traces filtran datos sensibles | RCA-04: output en N4, gitignored. |

## Decisiones pendientes

1. **Umbral de repeticion**: 3 fallos propuesto. Alternativa: 5 (mas
   conservador, menos ruido).
2. **Leccion con o sin "Fix"**: si el patron se resolvio alguna vez,
   incluir el fix. Si no, solo documentar el pattern + cause. El fix
   requiere cruzar con sesiones exitosas — mas complejo.
3. **Sentry MCP vs API directa**: si el MCP connector esta activo,
   usarlo. Si no, `curl` con API key. Default propuesto: MCP primero,
   fallback a curl.

## Referencias

- Rakuten QA case study: claude.com/customers/rakuten-qa
- Agent memory: `.claude/rules/domain/agent-memory-isolation.md`
- Self-improvement: `.claude/rules/domain/self-improvement.md`
- Truth Tribunal: SPEC-106
- Comprehension: `.claude/rules/domain/code-comprehension.md`
