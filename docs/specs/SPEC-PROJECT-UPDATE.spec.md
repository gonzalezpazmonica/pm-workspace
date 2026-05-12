# SPEC-PROJECT-UPDATE — Knowledge Management completo del PM

> **Spec macro** — absorbe SPEC-128 (Obsidian Context-as-Code) y la extiende con auto-digest semantico cross-source, captura de conversaciones IA, grafo de entidades y RAG opcional.
>
> Sustituye: `docs/specs/SPEC-128-obsidian-context-as-code.spec.md` (queda archivada con cabecera SUPERSEDED).

**Task ID:**          SPEC-PROJECT-UPDATE
**PBI padre:**        Savia PM Core — sistema integral de Knowledge Management del proyecto
**Sprint:**           2026-19 (start) — multi-sprint (3+ sprints estimados)
**Fecha creacion:**   2026-05-07
**Confidencialidad:** N1 publico (codenames-only)
**Creado por:**       Savia (sesion interactiva con la PM activa)

**Developer Type:**   agent-team (multiples slices, agentes diferentes por fase)
**Asignado a:**       claude-agent-team
**Estado:**           Pendiente — Fase 1 lista para arrancar

**Effort Estimation (Dual Model):**

| Dimension       | Value |
|-----------------|-------|
| Agent effort    | ~30 h (cross fase) |
| Human effort    | ~80 h cross fase |
| Review effort   | ~6 h (1h por slice) |
| Context risk    | high (toca confidencialidad, vault, hooks, agentes nuevos) |
| Agent-capable   | partial — Fase 1-3 yes, Fase 4-6 mixed |
| Fallback        | Humano necesita ~3 sprints desde cero |

**Inspirado por:**
- `kepano/obsidian-skills` (MIT) — referencia conceptual, no vendor (D-2)
- Workflow PARA + Atomic Notes (Tiago Forte / Andy Matuschak)
- LangChain RAG patterns + Smart Connections plugin (referencia, NO se instala)

**Decisiones arquitectonicas registradas:**

- (D-1) **Vault por proyecto** embebido en `projects/{slug}_main/{slug}-{username}/vault/`. NO vault global, NO vault separado.
- (D-2) **Sin vendor** de skills externas. Construimos propias.
- (D-3) **Frontmatter `confidentiality: N1|N2|N3|N4|N4b` obligatorio** en TODA nota generada. Hook bloquea exfiltracion.
- (D-4) **Bottom-up**: vault primero, despues consumidores. Cada fase entrega valor visible.
- (D-5) **Una spec macro** (esta) absorbe SPEC-128. SPEC-128 queda SUPERSEDED.
- (D-6) **Auto-digest semantico cross-source** (mails, Teams chats, VTTs, OneDrive/SP files, DevOps work items, conversaciones OpenCode/Claude) con agentes especializados por fuente.
- (D-7) **Username dinamico**: rutas usan `{slug}-{username}` resuelto desde perfil activo, no hardcoded.
- (D-8) **Captura de conversaciones IA** post-Stop hook con detector de slug por contexto. Si no hay slug claro, persiste en personal vault N3.
- (D-9) **Time-box F1 sigue siendo < 15 min**. Auto-digest cross-source se ejecuta en fase F2 separada (`/project-update {slug} --enrich`) o asincronamente fuera del path critico.
- (D-10) **Pausa adaptacion OpenCode** (rama agent/spec-oc-04-opencode-native-20260506) hasta cerrar Fase 1-2 de esta spec.

---

## 1. Contexto y Objetivo

### 1.1 Problema

Savia ya recolecta de 13+ fuentes (DevOps, mail, Teams chats, Teams transcripts, OneDrive, SharePoint, calendar, git) via `scripts/project-update.py` — F1 100% determinista, paralelizado, robusto. Pero el resultado se queda **plano**:

- F2 produce esqueletos VTT, no digest semantico rico.
- F3 produce un radar markdown plano, sin entidades enlazadas.
- F4 hace append idempotente a `PENDING.md`. Fin.
- **No existe** capa de Knowledge Management: ni vault Obsidian-flavored, ni grafo de entidades, ni embeddings, ni linking cruzado, ni captura de conversaciones IA.

La PM acumula contexto valiosisimo que vive disperso, sin frontmatter consistente, sin wikilinks, sin backlinks. La consecuencia practica:

- No puede preguntar "que reuniones tocaron PBI X" sin grep manual.
- No puede ver el grafo del proyecto en Obsidian.
- Las decisiones de las sesiones IA se evaporan tras cerrar la sesion.
- Mails y chats Teams se quedan en formato crudo sin sintesis.

### 1.2 Objetivo

Convertir `/project-update {slug}` en el **sistema completo de Knowledge Management del PM**. Resultado por proyecto:

1. Un **vault Obsidian-flavored** en `projects/{slug}_main/{slug}-{username}/vault/` con estructura canonica (`00-Index/`, `10-PBIs/`, `20-Decisions/`, `30-Sprints/`, `40-Stakeholders/`, `50-Digests/`, `60-Risks/`, `70-Specs/`, `80-Sessions/`, `99-Inbox/`).
2. **Frontmatter canonico** en cada nota con `confidentiality`, `project`, `entity_type`, `created`, `updated`, etc. Hook bloquea writes invalidos.
3. **Wikilinks `[[...]]`** propagados automaticamente al detectar entidades conocidas (PBIs, personas, decisiones, sprints).
4. **Auto-digest semantico** post-F1 sobre TODAS las fuentes (no solo VTTs):
   - Reuniones (`meeting-digest` agent, ya existe)
   - Mails (`email-digest` agent, NUEVO)
   - Teams chats (`teams-chat-digest` agent, NUEVO)
   - OneDrive/SP files (extender `pdf-digest`/`word-digest`/`excel-digest` ya existentes)
   - DevOps work items con descripcion larga (`devops-item-digest` agent, NUEVO)
5. **Captura de conversaciones IA** post-Stop hook -> `vault/80-Sessions/YYYYMMDD-HHMM-{topic}.md` con frontmatter + decisiones extraidas + transcript completo.
6. **Grafo de entidades** persistente en `projects/{slug}_main/{slug}-{username}/.graph/` con nodos (PBI, Decision, Meeting, Email, ChatThread, Person, Risk, Spec, Session, File) y aristas (MENTIONED_IN, DECIDED_AT, DERIVED_FROM, BLOCKS, ASSIGNED_TO, etc).
7. **Embeddings + RAG** opcional sobre el corpus del vault del proyecto (namespace `{slug}`), reutilizando `memory-vector.py`.
8. **MOC (Map of Content)** auto-generado en `00-Index/MOC-{slug}.md` con grafo Mermaid + indice de entidades + huerfanas detectadas.

Hito de exito: ejecutar `/project-update {slug}` (F1, < 15 min) seguido de `/project-update {slug} --enrich` (F2-F5, asincronamente) y obtener:

- Vault navegable en Obsidian con grafo conectado.
- Backlinks completos PBI <-> reunion <-> decision <-> persona.
- Sintesis ejecutiva LLM en `00-Index/MOC-{slug}.md`.
- `PENDING.md` actualizado idempotentemente.
- Alertas accionables (deadlines, action items abiertos, reuniones sin digerir, riesgos).

### 1.3 No-goals (explicito)

- NO sincronizamos vaults entre maquinas (cada vault local).
- NO instalamos plugins Obsidian que envien datos cloud (Smart Connections, Copilot for Obsidian, Obsidian Sync para vaults N4+).
- NO vendorizamos `kepano/obsidian-skills`. Solo referencia conceptual.
- NO tocamos rama `agent/spec-oc-04-opencode-native-20260506` hasta cerrar Fase 1-2.
- NO generamos un vault global del workspace pm-workspace. Solo vaults por proyecto.
- NO escribimos en sistemas externos (DevOps, Outlook, Teams, SP). Read-only.
- NO ejecutamos LLMs en F1 (path critico < 15 min). LLMs solo en F2 (enrich) y F4 (sintesis).
- NO hardcodeamos username en paths. Resolver dinamicamente desde perfil activo.

### 1.4 Criterios de Aceptacion globales

- [ ] AC-G1: `/project-update {slug}` invocable desde Savia CLI (Claude Code y OpenCode) sin pasar por `python scripts/...` directo.
- [ ] AC-G2: Argumento `slug` obligatorio. Validado antes de ejecutar.
- [ ] AC-G3: Soporta flags `--only`, `--skip`, `--skip-auth`, `--dry-run`, `--workers N`, `--enrich`, `--rag`.
- [ ] AC-G4: Tras `/project-update {slug} && /project-update {slug} --enrich`, el vault Obsidian del proyecto contiene notas Obsidian-flavored con frontmatter canonico, wikilinks navegables, MOC actualizado.
- [ ] AC-G5: Cero hardcode de nombres reales (Rule #20). Cero hardcode de username.
- [ ] AC-G6: Confidentiality scan no detecta filtracion de vault N4 a repo publico.
- [ ] AC-G7: Funciona en runtime OpenCode y Claude Code (regla `spec-opencode-implementation-plan`).
- [ ] AC-G8: Re-ejecutar `/project-update {slug}` 2x no duplica notas, action items, ni nodos en el grafo.
- [ ] AC-G9: Si falta config (`~/.azure/projects/*.json`, `~/.savia/mail-accounts.json`), mensaje accionable y rc != 0.
- [ ] AC-G10: Conversaciones IA con slug detectado se persisten a `vault/80-Sessions/`. Sin slug claro -> personal vault N3.
- [ ] AC-G11: Time-box F1 < 15 min se mantiene. F2 enrich corre asincronamente o bajo demanda.

---
## 2. Resumen de Fases (Slices)

| Fase | Nombre | Entregable | Estimacion | Agente | Bloquea a |
|------|--------|------------|------------|--------|-----------|
| **F1** | Vault & Frontmatter | Vault layout, hook bloqueador, frontmatter validator, plantillas | ~12h | python-developer + tech-writer | F2,F3,F4,F5,F6 |
| **F2** | Refactor F2/F3 escriben al vault | meeting-digest output -> `vault/50-Digests/`, radar -> `vault/00-Index/` | ~10h | python-developer | F4 |
| **F3** | Captura conversaciones IA | Hook Stop -> `vault/80-Sessions/{date}-{topic}.md` con detector slug | ~14h | typescript-developer + python-developer | F4 |
| **F4** | Auto-digest semantico cross-source | 4 agentes nuevos (`email-digest`, `teams-chat-digest`, `devops-item-digest`, `file-digest`) + skill orchestrator | ~24h | python-developer + agent-team | F5 |
| **F5** | Grafo de entidades | `.graph/nodes.jsonl`, `.graph/edges.jsonl`, MOC Mermaid auto-generado | ~16h | python-developer | F6 |
| **F6** | RAG + Sintesis ejecutiva | Embeddings vault, busqueda semantica, sintesis LLM en MOC | ~12h | python-developer | — |
| **F7** | Sprint Status Report (opt-in por proyecto) | Informe ejecutivo de sprint hacia direccion: PBIs/Bugs por squad, % completion, regresion, semaforos | ~8h | python-developer | — |

Total estimado: **~96h agente + ~26h humano review** distribuido en 3-4 sprints.

Modo de entrega: cada Fase es un PR independiente con su propio `.review.crc` (Code Review Court).

---

## 3. Fase 1 — Vault & Frontmatter (slice critico)

### 3.1 Objetivo de Fase 1

Crear el contenedor que el resto del sistema rellenara. Sin esto, F2-F6 no tienen donde escribir. Time-boxed a ~12h agente para entrega rapida (1 sprint).

### 3.2 Entregable

```
projects/
  {slug}_main/                      # ya existe (privado, gitignored)
    {slug}-{username}/              # ya existe — username dinamico
      vault/                        # NUEVO en Fase 1
        00-Index/
          MOC-{slug}.md             # Map of Content (placeholder F1, contenido F4-F6)
        10-PBIs/                    # carpeta vacia, F2/F4 la llenan
        20-Decisions/               # carpeta vacia, F3/F4 la llenan
        30-Sprints/                 # carpeta vacia, F2 la llena
        40-Stakeholders/            # carpeta vacia, F4 la llena
        50-Digests/                 # carpeta vacia, F2/F4 la llenan
        60-Risks/                   # carpeta vacia, F4 la llena
        70-Specs/                   # carpeta vacia, F4 la llena
        80-Sessions/                # carpeta vacia, F3 la llena
        99-Inbox/                   # capture-anything, F4 lo organiza
        .obsidian/                  # config minima Obsidian (NO plugins cloud)
          app.json
          appearance.json
          core-plugins.json
        templates/                  # plantillas locales del vault
          PBI.md
          Decision.md
          Meeting.md
          Person.md
          Risk.md
          Session.md
        README.md                   # como navegar el vault
```

### 3.3 Frontmatter canonico

Campos obligatorios en TODA nota generada:

```yaml
---
confidentiality: N1|N2|N3|N4|N4b   # OBLIGATORIO. Hook bloquea si falta
project: {slug}                     # OBLIGATORIO
entity_type: pbi|decision|meeting|person|risk|spec|session|digest|moc|inbox
title: "..."
created: 2026-05-07T10:00:00+02:00
updated: 2026-05-07T10:00:00+02:00
tags: [...]                         # opcional
aliases: [...]                      # opcional
---
```

Campos por entity_type:

- **pbi**: `pbi_id`, `state`, `assignee`, `sprint`, `parent_feature`, `closed_at?`
- **decision**: `decision_id` (`DEC-{slug}-NNN`), `decided_at`, `decided_by`, `supersedes?`, `superseded_by?`
- **meeting**: `meeting_id`, `meeting_date`, `attendees: []`, `transcript_source`, `digest_status: pending|done`
- **person**: `email?`, `role`, `team`, `external: bool`
- **risk**: `risk_id`, `severity: low|medium|high|critical`, `status: open|mitigated|accepted|closed`, `owner`
- **spec**: `spec_id`, `status: pending|approved|implemented`, `linked_pbis: []`
- **session**: `session_date`, `frontend: claude-code|opencode`, `model`, `topics: []`, `outcome?`
- **digest**: `source: meeting|email|chat|file|devops`, `source_id`, `digested_at`, `digest_agent`
- **moc**: (sin extras, solo MOC del proyecto)
- **inbox**: `captured_from?`

### 3.4 Hook bloqueador de exfiltracion

Reusar patron `data-sovereignty-gate.sh`. Nuevo hook en `.opencode/hooks/vault-frontmatter-gate.sh`:

```
trigger:    PreToolUse on (Write|Edit|MultiEdit)
condition:  ruta destino contiene `/vault/` Y termina en `.md`
checks:
  1. Si confidentiality:N4|N4b y destino es path no-N4 -> BLOCK
  2. Si frontmatter ausente o malformado -> BLOCK
  3. Si entity_type ausente o invalido -> BLOCK
  4. Si project != slug del path -> BLOCK
exit:       2 si BLOCK, 0 si OK
mensaje:    accionable, con linea y campo problematico
```

### 3.5 Validador en Python

Nuevo: `scripts/vault-validate.py`:

- Funciones puras `parse_frontmatter(text) -> dict`, `validate_frontmatter(fm, entity_type) -> list[error]`.
- Reusable desde hook (subprocess), tests, y skills.
- Tests en `tests/scripts/test_vault_validate.py`: 1 caso por entity_type valido + 1 invalido por campo obligatorio.

### 3.6 Plantillas (`vault/templates/*.md`)

Una por entity_type con frontmatter pre-rellenado y placeholders documentados. Generadas por `scripts/vault-init.py` (siguiente).

### 3.7 Inicializador del vault

Nuevo: `scripts/vault-init.py {slug}`:

- Resuelve `username` desde `.claude/profiles/active-user.md` (campo `active_slug`).
- Crea estructura `projects/{slug}_main/{slug}-{username}/vault/...` si no existe.
- Copia plantillas.
- Genera `README.md` con explicacion de carpetas.
- Genera `00-Index/MOC-{slug}.md` placeholder con frontmatter `entity_type: moc`.
- Idempotente: si ya existe, no sobrescribe nada.
- Output JSON en stdout: `{"status":"created"|"exists","path":"..."}`.

### 3.8 Integracion con `/project-update`

`scripts/project-update.py` invoca `vault-init.py` en F0 (auth gate) tras validar slug y antes de F1. Si vault ya existe, no-op.

### 3.9 Criterios de Aceptacion Fase 1

- [ ] AC-1.1: `python scripts/vault-init.py {slug}` crea estructura completa con plantillas.
- [ ] AC-1.2: Re-ejecutar 2x es no-op (idempotente).
- [ ] AC-1.3: Hook `vault-frontmatter-gate.sh` bloquea write sin frontmatter en `vault/*.md`.
- [ ] AC-1.4: Hook bloquea write con `confidentiality:N4` en path no-N4.
- [ ] AC-1.5: Tests `pytest tests/scripts/test_vault_validate.py` pasan (>= 12 casos).
- [ ] AC-1.6: Test BATS hook: simular write con frontmatter invalido -> exit 2.
- [ ] AC-1.7: `username` se resuelve dinamicamente desde perfil activo (no hardcoded).
- [ ] AC-1.8: `vault-init.py` falla con mensaje accionable si no hay perfil activo.
- [ ] AC-1.9: Confidentiality scan: nada del vault llega a repo publico (vault va bajo `projects/{slug}_main/` que ya esta gitignored).
- [ ] AC-1.10: Plantillas validan contra `vault-validate.py` (auto-test: cada template valida OK con sus placeholders).

### 3.10 Reuso explicito de codigo existente

- Hook gate: copia parametrizada de `data-sovereignty-gate.sh`.
- Frontmatter parser: reusar libreria `python-frontmatter` si ya esta en deps; si no, parser minimo en `vault-validate.py` (~40 LOC).
- `username` resolver: reusar logica de `scripts/savia-env.sh`.
- Path conventions: reusar constantes de `pm-config.local.md`.

### 3.11 Riesgos Fase 1

- **R-1**: Si ya hay datos en `projects/{slug}_main/{slug}-{username}/` con otra estructura, vault podria colisionar. Mitigacion: `vault-init.py` solo crea bajo subcarpeta `vault/`, nunca toca hermanas.
- **R-2**: Hook activo en TODO el workspace puede ser ruidoso. Mitigacion: condicionar trigger a paths que matcheen `*/vault/*.md`.
- **R-3**: Plantillas pueden quedar desincronizadas con validador. Mitigacion: AC-1.10 (auto-test).

### 3.12 Quality Gate Vault (binary checklist + LLM-as-judge)

Inspirado por el patron `species/eval/` de Emilio Carrion (product-blueprints),
formalizado en `SPEC-SPECIES-EVAL`. Aplica como quality gate POST-F1 a cualquier
nota generada o editada bajo `vault/`.

#### 3.12.1 Binary checklist (deterministic)

Toda nota `vault/**/*.md` aprobada por el hook frontmatter-gate DEBE pasar ademas:

- [ ] BQ-1: Frontmatter valido (ya cubierto por `vault-frontmatter-gate.sh`).
- [ ] BQ-2: `confidentiality` coherente con path (`projects/`/`tenants/` -> N4/N4b).
- [ ] BQ-3: Slug del frontmatter == slug del path (`projects/{slug}_main/...`).
- [ ] BQ-4: Wikilinks `[[...]]` resolubles dentro del propio vault (sin dangling).
- [ ] BQ-5: Auto-managed sections (si las hay) tienen marcadores BEGIN/END intactos.
- [ ] BQ-6: Sin PII fuera de N4/N4b (ningun email/telefono real en notas N1/N2).
- [ ] BQ-7: `created` <= `updated`; ambas en formato ISO `YYYY-MM-DD`.

Implementacion: `scripts/vault-quality.py {slug} [--fix-safe]`. Exit 0 si OK,
1 si falla, 2 si error de runtime. Reutiliza `vault-validate.py` para BQ-1.

#### 3.12.2 LLM-as-judge (semantic)

Para notas tipo `digest`, `meeting`, `decision`, `pbi` con cuerpo > 200 chars,
el agente `coherence-judge` (ya existe) emite veredicto sobre:

- [ ] LQ-1: El titulo refleja el contenido (no clickbait, no generico).
- [ ] LQ-2: Las secciones canonicas estan presentes para el `entity_type`.
- [ ] LQ-3: Action items declarados tienen owner y due date (o explicitamente NULL).
- [ ] LQ-4: Sin contradicciones internas (fechas, nombres, decisiones).
- [ ] LQ-5: Wikilinks apuntan a entidades reales del grafo (cuando F5 este live).

Score 0-5. Threshold de paso: >= 4. Output append-only en
`output/vault-quality/{slug}/{date}.jsonl`.

#### 3.12.3 Cuando se ejecuta

- **Pre-commit (hook ligero)**: solo BQ-1..BQ-7 sobre staged. <2s por fichero.
- **Post-`/project-update --enrich`**: full sweep BQ + LQ sobre vault entero del slug.
- **CI nightly**: full sweep + reporte diff vs noche anterior.

#### 3.12.4 Criterios de Aceptacion §3.12

- [ ] AC-1.12.1: `vault-quality.py {slug}` ejecuta BQ-1..BQ-7 y reporta JSON.
- [ ] AC-1.12.2: Hook pre-commit `vault-quality-pre.sh` bloquea commit si BQ falla.
- [ ] AC-1.12.3: LLM-as-judge solo se invoca con `--llm` (cost-controlled), reusa `coherence-judge`.
- [ ] AC-1.12.4: Reporte agregado en `output/vault-quality/{slug}/latest.md` con
       conteos de pass/fail por bucket BQ y LQ.
- [ ] AC-1.12.5: Integrado con `SPEC-SPECIES-EVAL` (no duplica logica: vault-quality
       implementa la familia "vault" del eval universal).

---
## 4. Fase 2 — Refactor F2/F3 escriben al vault

### 4.1 Objetivo

Sin tocar la logica determinista de `project-update.py` F1, redirigir las salidas semanticas existentes (digest VTT, radar) al vault Fase 1.

### 4.2 Cambios

| Componente | Antes | Despues |
|------------|-------|---------|
| `meetings_auto_digest.py` | Output: `projects/{slug}_main/{slug}-{username}/meetings/{date}-digest.md` | Output: `vault/50-Digests/meeting-{date}-{topic}.md` con frontmatter `entity_type: digest, source: meeting` |
| Radar consolidado | `projects/{slug}_main/{slug}-{username}/reports/radar/PENDING.md` | Mantener PENDING.md (idempotente) PERO escribir tambien `vault/00-Index/MOC-{slug}.md` con seccion auto-managed |
| Roadmap (F2-bis si se entrega) | (no existe aun) | `vault/30-Sprints/sprint-{YYYY-NN}.md` |

### 4.3 Auto-managed sections (managed-content skill)

MOC tendra secciones delimitadas por marcadores reusando skill `managed-content`:

```markdown
<!-- AUTO-MANAGED:radar START -->
... contenido regenerado por F3 ...
<!-- AUTO-MANAGED:radar END -->

<!-- AUTO-MANAGED:graph START -->
... mermaid del grafo (F5) ...
<!-- AUTO-MANAGED:graph END -->
```

### 4.4 Wikilinks automaticos

Al escribir digest, post-procesar texto buscando entidades conocidas:
- PBIs (`AB#NNNN` -> `[[PBI-NNNN]]`)
- Personas registradas en `vault/40-Stakeholders/` (matcheo por nombre completo o alias)
- Specs (`SPEC-XXX` -> `[[SPEC-XXX]]`)

Funcion pura `wikilinkify(text, registry) -> text` reusable.

### 4.5 Criterios de Aceptacion Fase 2

- [ ] AC-2.1: Tras `/project-update {slug}`, los digests viven en `vault/50-Digests/` con frontmatter valido.
- [ ] AC-2.2: MOC contiene seccion radar auto-managed actualizada.
- [ ] AC-2.3: Wikilinks `[[PBI-NNNN]]` aparecen en digest cuando texto menciona AB#NNNN.
- [ ] AC-2.4: Re-ejecutar 2x no duplica notas ni rompe wikilinks.
- [ ] AC-2.5: PENDING.md sigue funcionando (compat retro).

---

## 5. Fase 3 — Captura conversaciones IA

### 5.1 Objetivo

Persistir cada sesion Claude Code u OpenCode como nota Obsidian-flavored al cerrar la sesion. Sin esto, las decisiones de las conversaciones IA se evaporan.

### 5.2 Hook Stop / SessionEnd

**Claude Code:**
- Hook `SessionEnd` (Stop) en `.claude/settings.json` -> ejecuta `scripts/capture-session.sh`.

**OpenCode:**
- Plugin TS en `.opencode/plugin/capture-session.ts` -> mismo `scripts/capture-session.sh` via shell.

### 5.3 `scripts/capture-session.sh`

Pseudocodigo:
```bash
1. Detectar slug:
   - cwd matches projects/{slug}_main/* -> slug=match
   - active project en ~/.savia/active-project.txt -> slug=valor
   - branch git matches project/{slug} -> slug=match
   - keywords del transcript matchean ~/.azure/projects/*.json `_codename` -> slug=match
   - Si nada matchea -> slug="" (personal)

2. Resolver username desde .claude/profiles/active-user.md

3. Construir path:
   - Si slug != "": vault/80-Sessions/{YYYYMMDD-HHMM}-{topic-slug}.md
   - Si slug == "": ~/.savia/personal-vault/sessions/{YYYYMMDD-HHMM}-{topic-slug}.md
                    (N3 personal, fuera del repo)

4. Extraer del transcript:
   - Topic (LLM small call O primer user message O cwd repo)
   - Decisiones explicitas ("decidimos", "vamos a", "queda fijado")
   - Action items ("hay que", "TODO", "pending")
   - Files tocados (grep tool calls)
   - Specs creadas/modificadas

5. Escribir nota con frontmatter:
   confidentiality: N4 si slug detectado, N3 si personal
   entity_type: session
   project: {slug} | "personal"
   session_date, frontend, model, topics, outcome
```

### 5.4 Detector de topic

- Llamada LLM rapida (haiku) sobre primeros 500 chars de la conversacion: "Resume en 5 palabras el tema principal."
- Fallback si LLM no disponible: primer user message truncado a 50 chars + slugify.

### 5.5 Criterios de Aceptacion Fase 3

- [ ] AC-3.1: Cerrar sesion en Claude Code dentro de `projects/{slug}_main/...` crea nota en `vault/80-Sessions/`.
- [ ] AC-3.2: Cerrar sesion sin slug detectable crea nota en `~/.savia/personal-vault/sessions/`.
- [ ] AC-3.3: Frontmatter completo y valido (pasa hook gate Fase 1).
- [ ] AC-3.4: Transcript se trocea en seccion "Decisions", "Action Items", "Files Touched", "Topics".
- [ ] AC-3.5: Mismo flujo OpenCode (plugin TS o shell wrapper).
- [ ] AC-3.6: Si LLM no disponible, fallback determinista funciona.
- [ ] AC-3.7: Hook nunca bloquea cierre de sesion (errors -> log, no exit != 0).

---

## 6. Fase 4 — Auto-digest semantico cross-source

### 6.1 Objetivo

Llevar el patron `meeting-digest` a TODAS las fuentes que F1 ya recolecta. Resultado: cada item de mail, chat Teams, file OneDrive/SP, work item DevOps con descripcion no trivial, queda digerido en `vault/50-Digests/`.

### 6.2 Agentes nuevos

Cada agente sigue el patron de `meeting-digest`: contrato YAML estricto, output frontmatter + secciones canonicas.

| Agente | Input | Output | Modelo | Estimacion |
|--------|-------|--------|--------|------------|
| `email-digest` | Lista de mails (json `inbox-check.py`) | `vault/50-Digests/email-{date}-{from}.md` por hilo | mid | ~6h |
| `teams-chat-digest` | Hilos chat Teams | `vault/50-Digests/chat-{date}-{thread}.md` por hilo | mid | ~6h |
| `devops-item-digest` | Work items con `Description` > 200 chars | `vault/50-Digests/devops-{id}.md` | fast | ~4h |
| `file-digest` (orchestrator) | OneDrive/SP files | Delega a `pdf-digest`/`word-digest`/`excel-digest`/`pptx-digest` ya existentes con output forzado a `vault/50-Digests/` | — | ~4h |

### 6.3 Skill orchestrator

Nuevo: `.opencode/skills/project-enrich/SKILL.md` (mirror `.claude/skills/`):

```
trigger: comando /project-update {slug} --enrich
flow:
  1. Lee outputs F1 (~/.savia/project-update-tmp/{slug}/*.json|raw)
  2. Para cada fuente, invoca agente correspondiente en paralelo (max --workers N)
  3. Cada agente escribe a vault/50-Digests/ con frontmatter
  4. Reusa `data-sovereignty-gate` para confidentiality
  5. Genera resumen ejecutivo en vault/00-Index/MOC-{slug}.md (seccion auto-managed)
```

### 6.4 Reuso explicito

- `meeting-digest`, `pdf-digest`, `word-digest`, `excel-digest`, `pptx-digest`, `visual-digest` -> ya existen, parametrizar output dir.
- `savia-narrative` -> usar para resumen ejecutivo cross-source.
- BERTopic / reranker -> usar para deduplicar action items entre fuentes.

### 6.5 Criterios de Aceptacion Fase 4

- [ ] AC-4.1: `/project-update {slug} --enrich` digiere mails, chats, files, work items en paralelo.
- [ ] AC-4.2: Cada digest tiene frontmatter valido y wikilinks a entidades conocidas.
- [ ] AC-4.3: Action items de TODAS las fuentes aparecen consolidados en MOC seccion auto-managed.
- [ ] AC-4.4: Time-box: enrich completo < 30 min para proyecto medio (50 mails, 30 chats, 20 files, 100 WI).
- [ ] AC-4.5: Re-ejecutar es idempotente (no duplica digests).

### 6.6 Deliverable obligatorio: `spec-gaps.md`

Cada agente de F4 (`email-digest`, `teams-chat-digest`, `devops-item-digest`,
`file-digest`) DEBE producir, ademas de su digest principal, un reporte de gaps
en `output/spec-gaps/{slug}/F4-{agent}-{date}.md` con:

- **Inputs no procesables**: items que el agente vio pero no pudo digerir
  (formato no soportado, encriptado, > size limit, idioma inesperado).
- **Frontmatter incompleto**: campos que el agente no pudo inferir y dejo `TBD`.
- **Wikilinks dangling**: referencias a entidades que aun no existen en vault.
- **Confidentiality ambigua**: items donde el clasificador (Savia Shield Layer 2)
  devolvio AMBIGUOUS.
- **Action items huerfanos**: detectados pero sin owner identificable.
- **Hipotesis pendientes**: heuristicas que el agente aplico pero no puede
  validar sin contexto humano (marcar `[NEEDS-HUMAN-REVIEW]`).

Formato YAML+markdown estricto. Consumido por F5 (graph-build) para evitar crear
nodos basura, y por la sintesis ejecutiva F6 para pintar "estado de salud del
digest" en el MOC.

#### 6.6.1 Criterios de Aceptacion §6.6

- [ ] AC-4.6: Cada agente F4 escribe su `spec-gaps.md` aunque no haya gaps
       (output vacio explicito, NO ausencia del fichero).
- [ ] AC-4.7: Gaps con > 24h sin resolverse aparecen en MOC seccion
       "## Gaps pendientes" auto-managed.
- [ ] AC-4.8: El reporte agregado de la sesion `/project-update --enrich`
       enlaza a TODOS los `spec-gaps.md` generados.

---

## 7. Fase 5 — Grafo de entidades

### 7.1 Objetivo

Modelo de grafo persistente para queries cross-entidad ("que reuniones tocaron PBI X", "que decisiones bloquean PBI Y", "que riesgos asignados a persona Z").

### 7.2 Storage

`projects/{slug}_main/{slug}-{username}/.graph/`:
- `nodes.jsonl` — un JSON por linea: `{"id":"PBI-1234","type":"pbi","title":"...","path":"vault/10-PBIs/...","fm":{...}}`
- `edges.jsonl` — `{"from":"meeting-2026-05-07","to":"PBI-1234","type":"MENTIONED_IN","weight":1}`

### 7.3 Builder

Nuevo: `scripts/graph-build.py {slug}`:
- Escanea vault entero.
- Extrae nodos por frontmatter `entity_type`.
- Extrae aristas por wikilinks `[[...]]` y campos especificos (`linked_pbis`, `attendees`, `supersedes`).
- Idempotente: regenera ambos jsonl.
- Reusa `knowledge-graph` skill.

### 7.4 Mermaid auto-generado

Seccion auto-managed en MOC con grafo Mermaid limitado a top-N nodos por degree centrality (evitar grafos ilegibles).

### 7.5 Criterios de Aceptacion Fase 5

- [ ] AC-5.1: `graph-build.py {slug}` produce nodes.jsonl + edges.jsonl validos.
- [ ] AC-5.2: MOC contiene Mermaid actualizado.
- [ ] AC-5.3: Query "personas mencionadas en N reuniones" funciona via simple jq.
- [ ] AC-5.4: Detecta huerfanas (nodos sin aristas) y las lista en MOC.

### 7.6 Deliverable obligatorio: `spec-gaps.md` del grafo

`graph-build.py` produce ademas de `nodes.jsonl`/`edges.jsonl` un reporte en
`output/spec-gaps/{slug}/F5-graph-{date}.md` con:

- **Nodos huerfanos**: sin aristas entrantes ni salientes (potencial dead data).
- **Aristas dangling**: wikilinks `[[X]]` donde X no existe como nodo.
- **Tipos inconsistentes**: nodos referenciados como tipo distinto al declarado
  en su frontmatter.
- **Ciclos sospechosos**: ciclos `supersedes` (decision A supersedes B supersedes A).
- **Clusters aislados**: subgrafos desconectados del grafo principal del proyecto.
- **Centralidad anomala**: nodos con degree > 3*media (posible nodo basura tipo
  "varios" o "general").

Idempotente. Re-ejecutar regenera el reporte completo. Consumido por la sintesis
ejecutiva F6 y por `vault-quality.py` (LQ-5).

#### 7.6.1 Criterios de Aceptacion §7.6

- [ ] AC-5.5: `graph-build.py {slug}` siempre produce `spec-gaps.md` (vacio
       explicito si no hay gaps).
- [ ] AC-5.6: Nodos huerfanos > 7 dias se listan en MOC seccion "## Vault Health".
- [ ] AC-5.7: Aristas dangling bloquean BQ-4 de `vault-quality.py`.

---

## 8. Fase 6 — RAG + Sintesis ejecutiva

### 8.1 Objetivo

Busqueda semantica sobre el vault del proyecto + sintesis ejecutiva LLM en MOC.

### 8.2 Hybrid RAG (tree index + reasoning + embeddings)

Inspirado por PageIndex / VectifyAI: en lugar de RAG puramente vectorial,
explotamos la **jerarquia natural del vault** como tree index y combinamos
con retrieval reasoning-based.

#### 8.2.1 Tree index (deterministic, free)

El vault YA es un arbol semantico (`00-Index/`, `10-PBIs/`, `20-Decisions/`,
`30-Meetings/`, `40-Risks/`, `50-Digests/`, ...). `scripts/vault-tree-index.py`
genera `projects/{slug}_main/{slug}-{username}/.rag/tree.json`:

```json
{
  "root": "vault",
  "children": [
    {"path": "10-PBIs", "title": "PBIs", "summary": "...", "children": [...]},
    {"path": "30-Meetings", "title": "Meetings", "summary": "...", "children": [...]}
  ]
}
```

Cada nodo lleva un `summary` (<= 200 chars) generado por `savia-narrative` desde
los frontmatter de sus hojas. Idempotente, regenerable en O(n).

#### 8.2.2 Reasoning-based retrieval

Comando `/project-search {slug} "query"` ejecuta:

1. **Tree walk** (sin embeddings): un agente `vault-navigator` (nuevo, modelo
   `mid`) navega `tree.json` decidiendo en cada nivel que ramas explorar segun
   la query. Output: lista de `path`s candidatos.
2. **Embedding rerank** (solo sobre candidatos): `memory-vector.py` con
   namespace `project-{slug}` reordena los path candidatos por similitud
   semantica del `query` vs el contenido completo de la nota.
3. **LLM final pick**: `coherence-judge` selecciona top-5 del rerank y los
   anota con razon de relevancia.

#### 8.2.3 Embeddings (rol secundario)

- Reusar `memory-vector.py` con namespace `project-{slug}`.
- Indexar SOLO al final de `--enrich`, no en cada commit.
- Embeddings = soporte al rerank, NO el primer hop. Esto reduce coste y latencia
  ~10x para vaults pequenos/medianos donde el tree walk basta.

#### 8.2.4 Criterios de Aceptacion Hybrid RAG

- [ ] AC-6.1.1: `vault-tree-index.py {slug}` produce `tree.json` valido y
       summaries < 200 chars.
- [ ] AC-6.1.2: `/project-search {slug} "query"` ejecuta tree-walk antes de
       embeddings (verificable en logs).
- [ ] AC-6.1.3: En vaults < 100 notas, tree-walk solo (sin embeddings) acierta
       en top-5 para queries triviales (smoke test).
- [ ] AC-6.1.4: En vaults > 500 notas, hybrid (tree + embed rerank) supera a
       embeddings puros en eval de 20 queries gold (medido offline).

### 8.3 Sintesis ejecutiva

Agente `executive-reporting` (ya existe) genera seccion auto-managed `## Sintesis Ejecutiva` en MOC con:
- 3-5 bullets de estado del proyecto
- Top 3 riesgos abiertos
- Top 3 decisiones recientes
- Action items criticos sin owner

### 8.4 Criterios de Aceptacion Fase 6

- [ ] AC-6.1: `/project-search {slug} "query"` devuelve top-5 notas con score.
- [ ] AC-6.2: MOC tiene `## Sintesis Ejecutiva` actualizada.
- [ ] AC-6.3: Sintesis evita citar nombres reales si confidentiality mixta (codenames-only).

---
## 8bis. Fase 7 — Sprint Status Report (opt-in por proyecto, ejecutivo)

### 8bis.1 Objetivo

Generar un informe ejecutivo de sprint dirigido a direccion del cliente. Una unica copia por sprint que se sobrescribe en cada ejecucion (mismo sprint -> mismo fichero). Cambia de fichero al cambiar de sprint.

Alcance: **opt-in por proyecto**. Cada proyecto que quiera activar F7 declara sus constantes en `.claude/rules/pm-config.local.md` (gitignored). El mecanismo es project-agnostic; los datos concretos de cada proyecto viven fuera del repo publico.

### 8bis.2 Trigger

Hook condicional al final de `/project-update --enrich`:
- Si el slug del proyecto activo aparece en la constante `F7_ENABLED_PROJECTS` (lista separada por comas en `pm-config.local.md`) -> ejecutar generador F7.
- En cualquier otro slug -> skip silencioso.

No hay flag dedicado en MVP. La ejecucion es automatica tras enrich.

### 8bis.3 Fuentes de datos (reuso, sin nuevas dependencias)

- Azure DevOps WIQL: PBIs y Bugs del area `PROJECT_{SLUG}_AZDO_DEMAND_AREAPATH`, iteration `PROJECT_{SLUG}_AZDO_DEMAND_ITERATION` (suele ser `@CurrentIteration`).
- Snapshots Excel externos opcionales (reuso de SPEC-IA01 cuando aplique): el proyecto declara `PROJECT_{SLUG}_F7_EXTERNAL_SNAPSHOTS` con la ruta. Si vacio -> seccion omitida.
- Squads: lista de `PROJECT_{SLUG}_SQUADS` para agrupacion. Si `default` -> inferir de tags/AreaPath.
- Estados: `PROJECT_{SLUG}_DONE_STATES` y `PROJECT_{SLUG}_IN_PROGRESS_STATES`.

Todas las constantes `PROJECT_{SLUG}_*` viven en `pm-config.local.md` (gitignored). El spec publico solo define el contrato de nombres, no valores reales.

### 8bis.4 Output

Ruta canonica (reuso D-1 vault):
```
projects/{slug}_main/{slug}-{user}/vault/00-Index/sprint-status-{sprint}.md
```

Patron de nombre: constante `PROJECT_{SLUG}_F7_FILENAME` con `{sprint}` substituido por sprint actual. Mismo sprint -> sobreescribe. Cambio de sprint -> nuevo fichero (el anterior queda como historico en el vault).

Frontmatter obligatorio (D-3):
```yaml
---
confidentiality: N4
entity_types: [sprint_report, executive]
project: {slug}
sprint: {sprint_id}
generated_at: {iso8601}
---
```

### 8bis.5 Estructura del informe (Markdown puro, sin embeds)

```markdown
# Sprint Status — {sprint_id}

## Resumen ejecutivo
- % completion global: {pct}%
- Items completados: {done} / {total}
- Items en curso: {in_progress}
- Items bloqueados: {blocked}
- Semaforo: verde / ambar / rojo (criterios §8bis.6)

## Por squad
### {squad_name}
| Item | Tipo | Estado | Title | Asignado |
| AB#XXXX | PBI | Done | ... | ... |

## Regresion
Items con token configurable `PROJECT_{SLUG}_F7_REGRESSION_TOKEN` en title (case-insensitive, match parcial).
- AB#XXXX — {title} — {state}

## Items abiertos en fuente externa (opcional)
Solo si `PROJECT_{SLUG}_F7_EXTERNAL_SNAPSHOTS` definido. Snapshot mas reciente: {snapshot_date}
- {row_summary} — estado: {state}

## Cambios respecto sprint anterior
- Items movidos de iteration: {list}
- Items anadidos durante sprint (alcance creciente): {list}
```

Sin imagenes, sin charts. Markdown puro para que direccion lo lea directamente o lo paste en email.

### 8bis.6 Logica de semaforo

- verde: % completion >= 80% y bloqueados == 0.
- ambar: % completion entre 50-80% o 1-2 bloqueados.
- rojo: % completion < 50% o 3+ bloqueados o regresion sin avance >= 14 dias.

Umbrales configurables via `PROJECT_{SLUG}_F7_THRESHOLD_*` si el proyecto necesita criterios distintos.

### 8bis.7 Implementacion

`scripts/project-update-f7.py` (modulo invocado desde `project-update.py` cuando slug esta en `F7_ENABLED_PROJECTS` y `--enrich` activo).

Reuso explicito:
- `scripts/azure-devops-query.sh` (helper WIQL existente) para listar items.
- Parser snapshots externos opcional: si `PROJECT_{SLUG}_F7_EXTERNAL_PARSER` apunta a un modulo Python (ej. parser SPEC-IA01 reusable), F7 lo importa. Si vacio, seccion omitida.
- `vault-validate.py`: validacion frontmatter del output.

### 8bis.8 Criterios de Aceptacion Fase 7

- [ ] AC-7.1: Ejecutar `/project-update {slug} --enrich` con slug en `F7_ENABLED_PROJECTS` genera/sobreescribe `vault/00-Index/sprint-status-{sprint}.md`.
- [ ] AC-7.2: Frontmatter `confidentiality: N4` valida con `vault-validate.py`.
- [ ] AC-7.3: Cambio de sprint genera fichero nuevo, no toca el anterior.
- [ ] AC-7.4: Ejecutar en slug NO incluido en `F7_ENABLED_PROJECTS` -> no genera fichero F7 (skip silencioso, no consume DevOps API).
- [ ] AC-7.5: Items con token `PROJECT_{SLUG}_F7_REGRESSION_TOKEN` aparecen en seccion dedicada.
- [ ] AC-7.6: Snapshot externo opcional se reusa (no re-descarga). Si snapshots vacio o `PROJECT_{SLUG}_F7_EXTERNAL_SNAPSHOTS` no definido -> seccion omitida con nota.
- [ ] AC-7.7: Semaforo coherente con metricas (test contrafactual: forzar % y bloqueados, verificar color).
- [ ] AC-7.8: Hook condicional verifica `F7_ENABLED_PROJECTS` ANTES de invocar F7 (no consume DevOps API en proyectos no opt-in).

### 8bis.9 No-goals Fase 7

- No genera PowerPoint ni Excel (Markdown puro).
- No envia el informe por email/Teams (la PM lo distribuye manualmente).
- No genera para proyectos no incluidos en `F7_ENABLED_PROJECTS` (opt-in explicito).
- No archiva fichero anterior automaticamente (queda en el vault, busqueda semantica F6 lo encuentra).
- No define valores concretos por proyecto en spec publico — todos viven en `pm-config.local.md` (gitignored).

### 8bis.10 Riesgos Fase 7

- R-7.1: Squad inference por tags inconsistente. Mitigacion: si `PROJECT_{SLUG}_SQUADS == "default"` y no hay tags -> agrupar como "Sin squad".
- R-7.2: Snapshot externo desactualizado. Mitigacion: avisar en informe con warning visible si timestamp > umbral configurable.
- R-7.3: Iteration mismatch entre demand board y development board. Mitigacion: log explicito del filtro WIQL aplicado.
- R-7.4: Fuga de codename de proyecto en spec publico. Mitigacion: este spec usa solo `{slug}` placeholder; constantes concretas viven en `pm-config.local.md` gitignored.

---
## 9. Slash command `/project-update`

### 9.1 Wrapper delgado

`.opencode/commands/project-update.md` (mirror `.claude/commands/`):
```yaml
---
description: Knowledge Management completo del proyecto activo
argument-hint: <slug> [--only=...] [--skip=...] [--skip-auth] [--dry-run] [--workers=N] [--enrich] [--rag]
---
```
Body: invoca `python scripts/project-update.py "$@"` y propaga rc.

### 9.2 Flags

| Flag | Default | Efecto |
|------|---------|--------|
| `slug` | obligatorio | Codename proyecto |
| `--only=devops,mail,...` | (none) | Restringe fuentes |
| `--skip=...` | (none) | Excluye fuentes |
| `--skip-auth` | false | Salta F0 (debug) |
| `--dry-run` | false | F1 sin escrituras |
| `--workers=N` | auto | Paralelismo F1 |
| `--enrich` | false | Activa F2-F6 (LLM, fuera de path critico) |
| `--rag` | false | Re-indexa embeddings tras enrich |
| `--all-alerts` | false | Incluye MEDIUM+LOW (default solo CRITICAL+HIGH) |

### 9.3 Banner UX (Rule #15)

```
== /project-update {slug} ==
F0 auth gate: OK (4 daemons)
F1 collect: 8/8 sources OK (12.4s)
F2 vault refresh: 24 digests OK (idempotent)
F3 sessions captured: 2 (today)
F4 enrich: skipped (use --enrich)
F5 graph: 142 nodes, 387 edges
F6 RAG: skipped (use --rag)
output: projects/{slug}_main/{slug}-monica/vault/
```

---

## 10. Estructura de archivos creados / modificados

### 10.1 Creados

```
docs/specs/SPEC-PROJECT-UPDATE.spec.md           (esta spec)
scripts/vault-init.py                            (F1)
scripts/vault-validate.py                        (F1)
scripts/capture-session.sh                       (F3)
scripts/graph-build.py                           (F5)
.opencode/hooks/vault-frontmatter-gate.sh        (F1)
.opencode/skills/project-enrich/SKILL.md         (F4)
.opencode/agents/email-digest.md                 (F4)
.opencode/agents/teams-chat-digest.md            (F4)
.opencode/agents/devops-item-digest.md           (F4)
.opencode/agents/file-digest.md                  (F4)
.opencode/plugin/capture-session.ts              (F3 OpenCode)
.opencode/commands/project-update.md             (F1) — si no existe ya
tests/scripts/test_vault_validate.py             (F1)
tests/scripts/test_capture_session.py            (F3)
tests/scripts/test_graph_build.py                (F5)
tests/bats/test_vault_frontmatter_gate.bats      (F1)
docs/rules/domain/vault-frontmatter.md           (F1) — regla canonica
docs/rules/domain/ai-session-capture.md          (F3)
```

### 10.2 Modificados

```
scripts/project-update.py                        (F1: invocar vault-init en F0)
scripts/meetings_auto_digest.py                  (F2: output a vault/50-Digests/)
scripts/project-update-analyze.py                (F2: tambien escribe MOC)
.claude/settings.json                            (F1: registrar hook + F3 SessionEnd)
.opencode/agents/meeting-digest.md               (F2: parametrizar output dir)
docs/specs/SPEC-128-obsidian-context-as-code.spec.md  (cabecera SUPERSEDED)
AGENTS.md / SKILLS.md                            (auto-regen tras F4)
```

### 10.3 Archivados

```
docs/specs/archive/SPEC-128-obsidian-context-as-code.spec.md   (SUPERSEDED por esta spec)
```

---

## 11. Plan de testing

### 11.1 Unit tests

- `test_vault_validate.py`: 12+ casos (1 OK + 1 fail por entity_type x 2 campos obligatorios).
- `test_capture_session.py`: detector de slug (cwd, branch, profile, fallback).
- `test_graph_build.py`: vault sintetico -> nodes/edges esperados.

### 11.2 BATS tests

- `test_vault_frontmatter_gate.bats`: 6 casos (frontmatter valido OK, falta confidentiality BLOCK, N4 a path no-N4 BLOCK, etc.).

### 11.3 Integracion E2E

- `tests/e2e/test_project_update_full.sh`: vault vacio -> `/project-update {slug}` -> assert estructura -> `/project-update {slug} --enrich` (con LLM mock) -> assert digests.

### 11.4 Confidentiality scan

- `bash scripts/confidentiality-scan.sh` debe pasar tras cualquier commit de esta spec.

---

## 12. OpenCode Implementation Plan (Rule spec-opencode-implementation-plan)

### 12.1 Classification

`runtime: dual` — Funciona en Claude Code Y OpenCode.

### 12.2 Diferencias por runtime

| Aspecto | Claude Code | OpenCode |
|---------|-------------|----------|
| Hook PreToolUse | `.claude/settings.json` `hooks.PreToolUse` | `.opencode/plugin/*.ts` o shell wrapper |
| SessionEnd | `hooks.Stop` | `.opencode/plugin/capture-session.ts` |
| Slash command | `.claude/commands/project-update.md` | `.opencode/commands/project-update.md` (mirror) |
| Tools llamadas | nativas (write/edit/read) | nativas OpenCode (mismas APIs) |
| Frontmatter validator | subprocess `python scripts/vault-validate.py` | mismo |

### 12.3 Tests por runtime

- Tests unit Python: corren igual.
- BATS hooks: corren igual (bash).
- E2E: variable `$RUNTIME` selecciona path.

### 12.4 Riesgos especificos OpenCode

- Tool-healing puede bloquear `write` (visto en sesion 2026-05-07). Workaround: `bash` heredoc. Deuda tecnica anotada en `SPEC-TOOL-HEALING-FIX`.
- Plugin TS necesita `bun` runtime instalado.

---

## 13. Riesgos globales y mitigaciones

| ID | Riesgo | Severidad | Mitigacion |
|----|--------|-----------|------------|
| R-G1 | Vault crece sin limite (mails/chats acumulados) | medium | Carpeta `99-Inbox/` con TTL 90 dias. F4 archiva digest viejos a `archive/{YYYY-MM}/`. |
| R-G2 | Hook frontmatter ralentiza writes | low | Validador <50ms (regex + yaml parse). Sin LLM. |
| R-G3 | Detector slug en F3 falsos positivos | medium | Conservador: si duda, usa personal vault N3. Loggea decision para tuning. |
| R-G4 | Embeddings F6 caros | low | Opt-in (`--rag`). Solo se invoca si la PM lo pide. |
| R-G5 | Conflicto con plugins Obsidian del usuario | low | `.obsidian/core-plugins.json` solo activa core local. Usuario puede sobrescribir. |
| R-G6 | Sincronizacion entre maquinas | n/a | Fuera de scope (no-goal). |
| R-G7 | Adopcion: PM no abre Obsidian | medium | MOC + sintesis ejecutiva accesibles via `cat` o `/project-search` sin abrir Obsidian. |

---

## 14. Dependencias

### 14.1 Internas (workspace)

- `scripts/savia-env.sh` — resolver username, paths.
- `scripts/data-sovereignty-gate.sh` — patron a copiar.
- `.opencode/skills/managed-content/` — secciones auto-managed.
- `.opencode/skills/savia-recall`, `knowledge-graph`, `meeting-digest`, `savia-narrative`, `executive-reporting`, `pm-radar` — reuso.
- `scripts/memory-vector.py` — embeddings F6.

### 14.2 Externas

- Python 3.10+, `python-frontmatter` (opcional, fallback parser propio), `pyyaml`.
- Obsidian (humano lo usa para visualizar; opcional).
- Claude Code o OpenCode runtime.

### 14.3 Sin dependencia de

- Plugins Obsidian de terceros (Smart Connections, Copilot for Obsidian, Sync).
- `kepano/obsidian-skills` (NO se vendoriza; solo referencia).
- LLMs externos (RAG y sintesis pueden usar local via savia-dual).

---

## 15. Plan de entrega

### Sprint 2026-19 (start)
- Fase 1 completa (vault + frontmatter + hook + validator + plantillas + init)
- Spec SPEC-128 marcada SUPERSEDED y movida a archive/
- PR independiente con `.review.crc`

### Sprint 2026-20
- Fase 2 (refactor F2/F3 escriben al vault) + Fase 3 (captura conversaciones IA)
- 2 PRs

### Sprint 2026-21
- Fase 4 (4 agentes nuevos + skill orchestrator)
- 1 PR

### Sprint 2026-22
- Fase 5 (grafo) + Fase 6 (RAG + sintesis)
- 2 PRs

Cada PR pasa por Code Review Court (E1 humano obligatorio, autonomous-safety).

---

## 16. Anexo A — Mapping con SPEC-128 (auditoria)

Toda capacidad SPEC-128 esta absorbida:

| SPEC-128 capacidad | SPEC-PROJECT-UPDATE seccion |
|--------------------|------------------------------|
| Vault layout `00-Index/` etc | §3.2 (Fase 1) |
| Frontmatter `confidentiality` obligatorio | §3.3, §3.4 |
| Hook bloqueador exfiltracion | §3.4 (Fase 1) |
| Skills propias author/navigator | §6.3 (Fase 4 orchestrator) + §8.2 (Fase 6 search) |
| NO vendor `kepano/obsidian-skills` | §1.3 (no-goals D-2) |
| Pausa rama `agent/spec-oc-04-...` | §1 (D-10) |
| Vault por proyecto, no global | §1 (D-1) |

Confirmado: ningun gap. SPEC-128 puede archivarse SUPERSEDED.

---

## 17. Anexo B — Decisiones pendientes (a resolver antes de Fase 4)

- [ ] **DEC-PEND-1**: Granularidad email-digest: por mensaje individual O por hilo completo. Recomendacion Savia: por hilo (menos ruido, mas contexto).
- [ ] **DEC-PEND-2**: Quien escribe el grafo: builder centralizado (F5) O cada agente al escribir su digest. Recomendacion Savia: builder centralizado (idempotencia).
- [ ] **DEC-PEND-3**: TTL `99-Inbox/` (30/60/90 dias). Recomendacion Savia: 90 dias.
- [ ] **DEC-PEND-4**: Deduplicacion action items cross-source: BERTopic clustering O LLM dedup. Recomendacion Savia: BERTopic primero, LLM solo si clusters > 5 items.

---

## 18. Anexo C — Deuda tecnica detectada durante drafting

| ID | Spec | Descripcion |
|----|------|-------------|
| TD-1 | `SPEC-TOOL-HEALING-FIX` | Tools `write`/`read` bloqueadas por tool-healing en OpenCode v1.14 con paths absolutos validos. Bloquea generacion de specs largas. Workaround: bash heredoc. Borrador en `/tmp/savia-tech-debt/SPEC-TOOL-HEALING-FIX.spec.md`. |

---

## 19. Anexo D — Glosario

- **Vault**: directorio Obsidian-flavored con notas markdown + frontmatter + carpeta `.obsidian/`.
- **MOC**: Map of Content — nota indice.
- **Frontmatter**: bloque YAML al inicio de un .md entre `---`.
- **Wikilink**: enlace `[[Otra Nota]]` que Obsidian resuelve por nombre.
- **Confidentiality N1-N4b**: niveles de la regla `context-placement-confirmation` (N1 publico, N4b PM-only).
- **Slug**: codename del proyecto. Ejemplo: `aurora`, `beacon`, `ironclad`.
- **F0-F6**: fases del pipeline `/project-update`.

