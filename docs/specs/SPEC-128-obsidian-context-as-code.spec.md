# Spec: Obsidian Context-as-Code — Vault por proyecto con confidencialidad en frontmatter

> **NOTA DE FUSIÓN (2026-05-07)** — el hook `.opencode/hooks/vault-confidentiality-gate.sh`
> descrito en esta spec se ha **fusionado** con el hook de SPEC-PROJECT-UPDATE F1
> (`vault-frontmatter-gate.sh`). El hook canónico vivo es:
>
>     .opencode/hooks/vault-frontmatter-gate.sh
>
> Conserva todas las reglas de aislamiento de SPEC-128 (cross-project slug, N1-in-vault
> block, exenciones `PROJECT_TEMPLATE/`, `vault/.obsidian/`, `vault/README.md`) y
> añade el schema rico per-`entity_type` de SPEC-PROJECT-UPDATE (10 entity_types,
> `title` requerido, enums por tipo). Validación delegada a `scripts/vault-validate.py`.


**Task ID:**        WORKSPACE (no Azure DevOps task — workspace-level feature)
**PBI padre:**      N/A — internal tooling, gestión de Context-as-Code
**Sprint:**         2026-27 (current)
**Fecha creación:** 2026-05-06
**Creado por:**     Savia (sesión interactiva con Mónica)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimación:**     12h (3 slices × 4h)
**Estado:**         Pendiente

**Inspirado por:**  https://github.com/kepano/obsidian-skills (MIT, decisión: NO vendor — construimos propias B+C)
**Decisión arquitectónica registrada:**
- (D-1) Vault por proyecto, embebido en `projects/{slug}/vault/` (no vault global, no vault separado).
- (D-2) Sin vendor de kepano/obsidian-skills. Construimos skills propias adaptadas al stack pm-workspace.
- (D-3) Frontmatter `confidentiality: N1|N2|N3|N4|N4b` obligatorio en toda nota generada por agente. Hook bloquea exfiltración.
- (D-4) Pausa adaptación OpenCode (rama agent/spec-oc-04-opencode-native-20260506) hasta que esta spec esté implementada y commiteada.

---

## 1. Contexto y Objetivo

### 1.1 Problema

El workspace pm-workspace acumula contexto valioso disperso en formatos heterogéneos:
- Specs SDD (`projects/{slug}/specs/*.spec.md`)
- Outputs ad-hoc (`output/YYYYMMDD-*.md`)
- Reglas (`docs/rules/domain/*.md`)
- Memory canónica (`.claude/external-memory/`, `~/.savia/`)
- Resultados de digests (PDFs, DOCXs, transcripciones de reuniones)

Mónica (PM) necesita **navegar este contexto visualmente con grafos de enlaces, búsqueda full-text y backlinks**, no solo grep+Read. Obsidian ya está instalado en su máquina (Windows host, accesible desde WSL via `/mnt/c/`).

Los agentes Claude/OpenCode actualmente **no saben escribir notas Obsidian-flavored** (wikilinks `[[Note]]`, embeds `![[file]]`, callouts `> [!info]`, properties YAML). Tampoco saben **enlazar PBIs ↔ specs ↔ digests ↔ stakeholders** con backlinks navegables.

Riesgo crítico de confidencialidad: los proyectos privados (cualquier proyecto N4) no pueden filtrar datos de cliente al repositorio público ni a plugins de Obsidian que indexan en cloud (Smart Connections, Copilot, Obsidian Sync).

### 1.2 Objetivo

Construir el sistema **Context-as-Code (CaC)** sobre Obsidian:

1. **Skill `obsidian-vault-author`** — enseña a los agentes a escribir Markdown Obsidian-flavored correcto.
2. **Skill `obsidian-vault-navigator`** — enseña a los agentes a leer/buscar/seguir backlinks dentro de un vault.
3. **Skill `context-as-code`** — convenciones de organización: qué nota corresponde a qué entidad PM (PBI, sprint, stakeholder, decisión, riesgo).
4. **Agente `vault-curator`** — mantiene un vault por proyecto: indexa specs nuevas, propaga backlinks, detecta notas huérfanas.
5. **Hook anti-fuga** — `vault-confidentiality-gate.sh` valida frontmatter `confidentiality:` y bloquea writes que violen niveles.
6. **Plantilla `projects/{slug}/vault/`** — estructura inicial canónica (carpetas `00-Index/`, `10-PBIs/`, `20-Decisions/`, etc.).

**Principio SDD:** Esta spec define QUÉ tiene que existir, qué interfaces y qué reglas. La implementación decide CÓMO (bash vs python, formato exacto del frontmatter, etc.) dentro de los límites marcados.

### 1.3 No-Goals (explícito)

- ❌ NO vendorizamos `kepano/obsidian-skills` (decisión D-2). No clonamos ese repo. Sí miramos su README como referencia conceptual.
- ❌ NO sincronizamos vaults entre máquinas. Cada vault vive en su `projects/{slug}/vault/` local.
- ❌ NO instalamos plugins Obsidian que envíen datos a cloud (Smart Connections, Copilot for Obsidian, Obsidian Sync para vaults N4+).
- ❌ NO tocamos el adaptación a OpenCode pendiente (rama `agent/spec-oc-04-opencode-native-20260506`) hasta cerrar esta spec.
- ❌ NO generamos un vault global del workspace pm-workspace en este slice. Solo vaults por proyecto.

---

## 2. Contrato Técnico

### 2.1 Estructura canónica del vault por proyecto

```
projects/{slug}/vault/
├── .obsidian/                         # Config Obsidian local (gitignored salvo workspace.json template)
│   ├── workspace.json
│   ├── app.json
│   └── community-plugins.json         # Lista vacía — sin plugins externos por defecto
├── 00-Index/
│   ├── README.md                      # Punto de entrada del vault
│   └── MOC-{slug}.md                  # Map of Content principal del proyecto
├── 10-PBIs/
│   └── PBI-{azureId}-{slug}.md        # Una nota por PBI activo
├── 20-Decisions/
│   └── DEC-{YYYYMMDD}-{slug}.md       # Architectural Decision Records
├── 30-Sprints/
│   └── Sprint-{YYYY-NN}.md            # Una nota por sprint con backlinks a PBIs
├── 40-Stakeholders/
│   └── {handle}.md                    # Una nota por persona (frontmatter N4 si cliente)
├── 50-Digests/
│   └── {YYYYMMDD}-{tipo}-{titulo}.md  # Salida de meeting-digest, pdf-digest, etc.
├── 60-Risks/
│   └── RISK-{YYYYMMDD}-{slug}.md
├── 70-Specs/
│   └── → symlink o referencia a ../specs/   # No duplicar; Obsidian sigue el link
└── 99-Inbox/
    └── *.md                            # Notas sin clasificar pendientes de curar
```

**Justificación de la numeración:** orden lexicográfico estable que coincide con el flujo PM (Index → trabajo activo PBI → decisiones que lo soportan → contenedor temporal sprint → personas → contexto digerido → riesgos → specs → inbox).

### 2.2 Frontmatter canónico (TODA nota generada por agente)

```yaml
---
confidentiality: N4               # OBLIGATORIO. Valores: N1|N2|N3|N4|N4b
project: proyecto-alpha                      # OBLIGATORIO. Slug del proyecto.
entity_type: pbi                  # OBLIGATORIO. Valores: pbi|decision|sprint|stakeholder|digest|risk|spec|moc|inbox
created: 2026-05-06               # OBLIGATORIO. ISO date.
updated: 2026-05-06               # OBLIGATORIO. ISO date. Auto-actualizado en cada write.
azure_id: 1314506                 # OPCIONAL. Si entity_type=pbi.
sprint: Sprint 27                 # OPCIONAL. Si la nota está vinculada a un sprint.
status: active                    # OPCIONAL. active|done|archived|superseded.
tags: [auth, backend]             # OPCIONAL. Tags para discovery.
related: ["[[PBI-1310495]]", "[[DEC-20260506-jwt-rotation]]"]  # OPCIONAL. Wikilinks explícitos.
source_agent: dotnet-developer    # OPCIONAL. Quién generó la nota (humano o agente).
---
```

**Validación obligatoria del hook:**
- `confidentiality` presente y ∈ {N1, N2, N3, N4, N4b}
- `project` presente y coincide con `projects/{slug}/`
- `entity_type` presente y ∈ enum
- Si `entity_type=pbi` → `azure_id` recomendado (warning si falta)

### 2.3 Reglas de confidencialidad (hook `vault-confidentiality-gate.sh`)

| Origen (write) | Destino | Regla |
|---|---|---|
| `projects/{slug}/vault/**.md` con `confidentiality: N1` | OK siempre | — |
| `projects/{slug}/vault/**.md` con `confidentiality: N2-N4b` | OK dentro del vault | — |
| `projects/{slug}/vault/**.md` con `confidentiality: N4` | BLOQUEAR write a `docs/`, `output/`, raíz repo | exit 2 |
| Cualquier nota sin frontmatter `confidentiality:` | BLOQUEAR write | exit 2, mensaje "frontmatter incompleto" |
| Nota con `confidentiality: N4b` | Solo lectura por usuario activo (Mónica). Bloquear otros perfiles. | exit 2 |

**Integración con Savia Shield:** este hook se registra como Capa 1.5 del Shield (entre Regex Gate y NER), específico para writes con extensión `.md` dentro de paths `**/vault/**`.

### 2.4 Skill `obsidian-vault-author` — Interfaz

Path: `.opencode/skills/obsidian-vault-author/SKILL.md`

```yaml
---
name: obsidian-vault-author
description: Escribe notas Obsidian-flavored correctas (wikilinks, embeds, callouts, properties)
summary: |
  Enseña al agente la sintaxis específica de Obsidian Flavored Markdown.
  Wikilinks [[Note]], embeds ![[file.png]], callouts > [!info], properties YAML.
  Aplica reglas de Context-as-Code (frontmatter de confidencialidad, naming convention).
maturity: stable
context: fork
context_cost: low
agent: any
category: "context-as-code"
tags: ["obsidian", "markdown", "context-as-code", "vault"]
priority: "medium"
---
```

Contenido mínimo (referencias documentadas):
- Sintaxis wikilink: `[[NoteName]]`, `[[NoteName|alias]]`, `[[NoteName#Heading]]`, `[[NoteName#^block-id]]`
- Embeds: `![[image.png]]`, `![[note]]`, `![[note#section]]`
- Callouts: `> [!note]`, `> [!warning]`, `> [!danger]`, `> [!example]`
- Properties (frontmatter YAML, ya cubierto por §2.2)
- Block references: `^block-id` al final de un párrafo
- Tags: `#tag/subtag` inline o en frontmatter `tags:`
- Plantillas de creación por entity_type (PBI, Decision, Sprint, Stakeholder, Digest, Risk)

### 2.5 Skill `obsidian-vault-navigator` — Interfaz

Path: `.opencode/skills/obsidian-vault-navigator/SKILL.md`

Funciones que el agente debe saber ejecutar:
- `vault-list-notes <vault-path> [--entity-type=X] [--tag=Y]` — listado filtrado.
- `vault-find-backlinks <vault-path> <note-name>` — qué notas enlazan a una dada.
- `vault-find-orphans <vault-path>` — notas sin backlinks entrantes.
- `vault-search <vault-path> <query>` — full-text con ripgrep, respeta confidentiality del usuario activo.
- `vault-graph <vault-path> --depth=N --from=<note>` — exporta subgrafo en JSON Canvas.

Implementación: scripts bash en `scripts/vault/*.sh` (o python si hay parsing YAML complejo).

### 2.6 Skill `context-as-code` — Interfaz

Path: `.opencode/skills/context-as-code/SKILL.md`

Convenciones (qué entidad PM → qué tipo de nota Obsidian):

| Entidad PM | Path en vault | Naming | entity_type | Backlinks obligatorios |
|---|---|---|---|---|
| PBI Azure DevOps | `10-PBIs/` | `PBI-{azureId}-{slug-from-title}.md` | `pbi` | Sprint, Stakeholder asignado |
| Decisión arquitectónica | `20-Decisions/` | `DEC-{YYYYMMDD}-{slug}.md` | `decision` | PBI(s) afectados |
| Sprint | `30-Sprints/` | `Sprint-{YYYY-NN}.md` | `sprint` | Todos los PBIs del sprint |
| Persona | `40-Stakeholders/` | `{handle-or-slug}.md` | `stakeholder` | PBIs asignados |
| Digest reunión/PDF | `50-Digests/` | `{YYYYMMDD}-{tipo}-{titulo}.md` | `digest` | Stakeholders presentes, PBIs mencionados |
| Riesgo | `60-Risks/` | `RISK-{YYYYMMDD}-{slug}.md` | `risk` | PBIs/sprints en riesgo |

### 2.7 Agente `vault-curator` — Interfaz

Path: `.opencode/agents/vault-curator.md`

```yaml
---
name: vault-curator
model: fast
permission: L2
tools: Read,Glob,Grep,Bash,Write,Edit
description: |
  Mantiene un vault Obsidian por proyecto. Tareas:
  (a) Indexa specs nuevas creadas en projects/{slug}/specs/ generando notas en 70-Specs/.
  (b) Propaga backlinks: cuando se crea una nota nueva, escanea referencias y añade backlink en notas referenciadas.
  (c) Detecta notas huérfanas (sin backlinks entrantes) y las lista en 00-Index/MOC-{slug}.md.
  (d) Valida frontmatter en cada nota del vault, abre Issue si encuentra notas inválidas.
  Invocación: PROACTIVELY tras /weekly-report, /pbi-decompose, meeting-digest. También bajo demanda.
---
```

### 2.8 Hook `vault-confidentiality-gate.sh`

Path: `.opencode/hooks/vault-confidentiality-gate.sh`
Trigger: PreToolUse en `Edit|Write` cuando el destino matchea `**/vault/**.md`.

Pseudocódigo:
```bash
#!/usr/bin/env bash
# vault-confidentiality-gate.sh
set -euo pipefail
DEST="$1"; CONTENT="$2"

# 1. Validar que el path está dentro de un vault
[[ "$DEST" == */vault/* ]] || exit 0

# 2. Extraer frontmatter (entre --- ... ---)
FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' <<<"$CONTENT")

# 3. Validar campos obligatorios
for key in confidentiality project entity_type created updated; do
  grep -qE "^${key}:" <<<"$FRONTMATTER" || {
    echo "BLOCKED: vault note missing frontmatter key '${key}'" >&2
    exit 2
  }
done

# 4. Validar enum confidentiality
LEVEL=$(grep -E "^confidentiality:" <<<"$FRONTMATTER" | awk '{print $2}')
[[ "$LEVEL" =~ ^(N1|N2|N3|N4|N4b)$ ]] || {
  echo "BLOCKED: invalid confidentiality '${LEVEL}'" >&2
  exit 2
}

# 5. Validar que slug del project en frontmatter coincide con el path
PROJECT=$(grep -E "^project:" <<<"$FRONTMATTER" | awk '{print $2}')
[[ "$DEST" == */projects/${PROJECT}/vault/* ]] || {
  echo "BLOCKED: project '${PROJECT}' does not match path '${DEST}'" >&2
  exit 2
}

exit 0
```

### 2.9 Comando `/vault-init {slug}`

Path: `.opencode/commands/vault-init.md`

Acción: crea estructura `projects/{slug}/vault/` desde plantilla canónica (§2.1). Si ya existe, aborta con error. Crea README con backlinks a las MOC iniciales y frontmatter por defecto `confidentiality: N4` (asumiendo proyecto cliente; reescribible manualmente).

### 2.10 Comando `/vault-open {slug}`

Path: `.opencode/commands/vault-open.md`

Acción: abre Obsidian apuntando al vault del proyecto. En WSL invoca:
```bash
cmd.exe /c start "" "obsidian://open?path=$(wslpath -w projects/${slug}/vault)"
```
Si no es WSL, usa `xdg-open obsidian://open?path=...`.

---

## 3. Slices de Implementación

### Slice 1 — Plantilla de vault + frontmatter + hook (4h)

**Entregables:**
- `templates/vault/` — estructura canónica completa con notas placeholder
- `.opencode/hooks/vault-confidentiality-gate.sh`
- `.opencode/commands/vault-init.md`
- `docs/rules/domain/vault-frontmatter-spec.md` (regla: contenido §2.2)
- Test BATS: `tests/test-vault-confidentiality-gate.bats` (mín 8 cases: write válido N1/N4, missing key, invalid enum, project mismatch, fuera de vault → bypass, write a docs/ desde N4 → block, N4b solo usuario activo)
- Registro hook en `.claude/settings.json` (PreToolUse)

**Acceptance:**
- AC1.1: `/vault-init proyecto-alpha` crea estructura completa en `projects/proyecto-alpha/vault/`
- AC1.2: Escribir nota sin `confidentiality:` → hook bloquea con exit 2
- AC1.3: Escribir nota con `confidentiality: N4` y luego intentar copiar a `output/` → hook bloquea
- AC1.4: 8 tests BATS pasan

### Slice 2 — Skills author + navigator + comando open (4h)

**Entregables:**
- `.opencode/skills/obsidian-vault-author/SKILL.md` (+ references si necesario)
- `.opencode/skills/obsidian-vault-navigator/SKILL.md`
- `scripts/vault/vault-list.sh`, `vault-backlinks.sh`, `vault-orphans.sh`, `vault-search.sh`
- `.opencode/commands/vault-open.md`
- Test BATS: `tests/test-vault-navigator.bats` (mín 5 cases: list por entity_type, backlinks de nota con 3 referenciantes, orphan correcto, search respeta confidentiality, vault inexistente → error claro)

**Acceptance:**
- AC2.1: Agente carga skill author y genera nota PBI con frontmatter correcto + 2 wikilinks + 1 callout en una pasada
- AC2.2: `bash scripts/vault/vault-backlinks.sh projects/proyecto-alpha/vault PBI-1310495` lista correctamente notas que referencian
- AC2.3: `vault-open proyecto-alpha` abre Obsidian apuntando al vault (Windows host)

### Slice 3 — Skill context-as-code + agente vault-curator (4h)

**Entregables:**
- `.opencode/skills/context-as-code/SKILL.md` (convenciones §2.6)
- `.opencode/agents/vault-curator.md` (+ frontmatter completo)
- Update `AGENTS.md` y `SKILLS.md` (auto-regenerados por hook si está activo)
- Update `CLAUDE.md` lazy reference table → añadir entry "Context-as-Code vault" → `.opencode/skills/context-as-code/SKILL.md`
- Test BATS: `tests/test-vault-curator.bats` (mín 4 cases: indexa spec nueva, propaga backlink, detecta huérfana, valida frontmatter inválido)

**Acceptance:**
- AC3.1: Crear `projects/proyecto-alpha/specs/SPEC-T04-test.md` y luego invocar `vault-curator` → genera nota en `70-Specs/` con backlink desde MOC
- AC3.2: Mover una nota PBI sin actualizar referencias → curator detecta y reporta
- AC3.3: Lazy-reference añadido a CLAUDE.md verificable con grep

---

## 4. Riesgos y Mitigaciones

| ID | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | Plugins Obsidian envían contenido N4 a cloud (Smart Connections, Copilot) | Media | Crítico | Spec §1.3 prohíbe instalación; documentar en `docs/rules/domain/vault-frontmatter-spec.md`; community-plugins.json con lista vacía como template |
| R2 | Mónica activa Obsidian Sync por error en vault N4 | Baja | Crítico | Documentar prohibición en README del vault; warning visible en frontmatter del MOC |
| R3 | Hook `vault-confidentiality-gate.sh` bloquea writes legítimos por bug | Media | Medio | Suite BATS exhaustiva en Slice 1; gate solo aplica a `**/vault/**` (resto del repo no afectado) |
| R4 | Backlinks rotos al renombrar notas | Alta | Bajo | Obsidian renombra wikilinks automáticamente al renombrar (feature nativa); curator detecta los que se escapen |
| R5 | Vault crece sin control y degrada UX | Media | Bajo | Archivar a `99-Archive/` notas con `status: archived`; curator reporta tamaño en MOC |
| R6 | Frontmatter parsing falla con YAML edge cases (multilinea, listas anidadas) | Media | Medio | Usar `python3 -c "import yaml"` en hook si bash regex no basta; documentar limitaciones |
| R7 | Conflicto path Windows/WSL al abrir Obsidian | Alta | Bajo | `wslpath -w` para conversión; documentar en vault-open.md |

---

## 5. Testing Strategy

### 5.1 Unitario (BATS)

Total mínimo: **17 casos** (8 hook + 5 navigator + 4 curator)

### 5.2 Integración (manual)

Checklist post-Slice 3:
- [ ] `/vault-init proyecto-alpha` → estructura creada, README abre
- [ ] Escribir un PBI manual con `vault-author` skill cargada → frontmatter completo
- [ ] `/vault-open proyecto-alpha` → Obsidian abre el vault
- [ ] En Obsidian: Graph view muestra nodos conectados
- [ ] Click en wikilink `[[Sprint-2026-27]]` navega correctamente
- [ ] Backlinks panel de Obsidian muestra referenciantes
- [ ] Crear nota inválida (sin frontmatter) → hook bloquea visiblemente

### 5.3 Confidencialidad (Red Team)

Casos que DEBEN fallar:
- Intentar `cp projects/proyecto-alpha/vault/10-PBIs/PBI-1310495.md output/` con N4 → hook bloquea
- Intentar `git add projects/proyecto-alpha/vault/` (vault entero gitignored por proyectos N4) — verificar `.gitignore`
- Generar digest N4 y intentar referenciarlo desde una nota N1 — curator detecta cross-level reference

---

## 6. Ficheros a Crear / Modificar

### Crear
- `docs/specs/SPEC-128-obsidian-context-as-code.spec.md` (este fichero)
- `templates/vault/` (estructura completa)
- `.opencode/hooks/vault-confidentiality-gate.sh`
- `.opencode/commands/vault-init.md`
- `.opencode/commands/vault-open.md`
- `.opencode/skills/obsidian-vault-author/SKILL.md`
- `.opencode/skills/obsidian-vault-navigator/SKILL.md`
- `.opencode/skills/context-as-code/SKILL.md`
- `.opencode/agents/vault-curator.md`
- `scripts/vault/vault-list.sh`
- `scripts/vault/vault-backlinks.sh`
- `scripts/vault/vault-orphans.sh`
- `scripts/vault/vault-search.sh`
- `docs/rules/domain/vault-frontmatter-spec.md`
- `tests/test-vault-confidentiality-gate.bats`
- `tests/test-vault-navigator.bats`
- `tests/test-vault-curator.bats`

### Modificar
- `.claude/settings.json` — registrar hook PreToolUse
- `CLAUDE.md` — añadir lazy reference a `.opencode/skills/context-as-code/SKILL.md`
- `AGENTS.md` — auto-regenerado al añadir vault-curator (hook Stop existente)
- `SKILLS.md` — auto-regenerado al añadir 3 skills nuevas
- `.gitignore` — añadir `projects/*/vault/` (excepto `projects/PROJECT_TEMPLATE/vault/` que sí se versiona como referencia)

### NO tocar (alcance explícito)
- Rama `agent/spec-oc-04-opencode-native-20260506` queda intacta hasta que esta spec se commitee
- `pm-config.local.md` (ya actualizado a Sprint 27 fuera de esta spec)
- Cualquier código de proyectos cliente

---

## 7. Criterios de Aceptación globales

- [ ] AC1.1 - AC1.4 (Slice 1) verificados
- [ ] AC2.1 - AC2.3 (Slice 2) verificados
- [ ] AC3.1 - AC3.3 (Slice 3) verificados
- [ ] 17 tests BATS pasan en local (`bash tests/run-all.sh`)
- [ ] Confidentiality scan no detecta filtración del vault de un proyecto N4 al repo público
- [ ] CHANGELOG.md actualizado con entry "Context-as-Code: Obsidian vault per project (SPEC-128)"
- [ ] Code review humano (E1) aprobado — Mónica revisa antes de merge

---

## 8. Referencias

- Inspiración conceptual: https://github.com/kepano/obsidian-skills (MIT)
- Obsidian Flavored Markdown: https://help.obsidian.md/obsidian-flavored-markdown
- JSON Canvas spec: https://jsoncanvas.org/
- Reglas internas:
  - `docs/rules/domain/data-sovereignty.md` (Savia Shield, niveles N1-N4b)
  - `docs/rules/domain/zero-project-leakage.md` (Rule companion #20)
  - `docs/rules/domain/file-output-summary.md` (regla creada en sesión previa)
  - `docs/rules/domain/autonomous-safety.md` (Rule #25, no merges autónomos)
- Skills relacionadas:
  - `.opencode/skills/spec-driven-development/SKILL.md`
  - `.opencode/skills/savia-identity/SKILL.md`

---

## 9. Notas para el Reviewer (Mónica)

Decisiones que conviene revisar antes de merge:

1. **¿Vault gitignored por defecto?** Propuesta: sí para `projects/{slug}/vault/` salvo PROJECT_TEMPLATE. Alternativa: versionar vaults N1-N3 y solo gitignorear N4+. Implica hook adicional que distinga.
2. **¿Plantilla de vault en `templates/vault/` o en `projects/PROJECT_TEMPLATE/vault/`?** Propuesta segunda opción para consistencia con resto de templates de proyecto.
3. **¿Comando `/vault-init` requiere proyecto existente?** Propuesta: sí; aborta si `projects/{slug}/` no existe.
4. **¿`vault-curator` corre en hook automático o solo bajo demanda?** Propuesta inicial: bajo demanda en este spec; auto-trigger en spec posterior si demuestra valor.
