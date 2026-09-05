# Spec: AUDIT — Guardrail Principle Compliance Audit (NORMA→DISPARADOR→ENFORCEMENT)

**Task ID:**        SE-374
**PBI padre:**      n/a (workspace-internal quality initiative)
**Sprint:**         2026-09
**Fecha creación:** 2026-09-04
**Creado por:**     Savia (a petición explícita de Mónica)

**Developer Type:** agent-single
**Asignado a:**     claude-agent (con revisión humana de remediation)
**Estado:**         Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|-----------|-------|
| Agent effort | 90 min |
| Human effort | 4 h |
| Review effort | 30 min |
| Context risk | medium |
| Agent-capable | yes (auditoría) / no (remediación — propuestas solas) |
| Fallback | Si agente falla: humano necesita ~4h inventariando a mano |

---

## 1. Contexto y Objetivo

### Contexto

El análisis de un debate IA-IA (post LinkedIn, Luis Rodrigo Ortiz) destiló 4
lecciones sobre guardrails (guardadas en memoria, topic
`lesson/lecciones-guardrails-desde-análisis-deb`):

- **LEC-1 Gap de activación**: conocer una norma no garantiza detectar cuándo
  aplica. Las restricciones críticas deben vivir en enforcement, no en prosa.
- **LEC-2 Enforcement determinista**: norma y disparador solo reducen
  probabilidad. Para acciones "jamás permitidas", solo el bloqueo técnico
  determinista es garantía.
- **LEC-3 Evaluadores correlacionados**: jueces LLM de la misma familia de
  entrenamiento acuerdan por agreeableness estructural; sin diversidad de
  prompts/evidencia, el panel no verifica nada.
- **LEC-4 Teatro de consenso**: consenso forzado entre modelos con broker que
  exige acuerdo es escritura colaborativa, no verificación.

El workspace tiene ~123 hooks, 25+ reglas de dominio, CONSTITUCION con 20
artículos, 5 líneas rojas (L1-L5), 88 agentes con permission levels L0-L4 y
múltiples paneles de jueces. **Nadie ha verificado nunca que este sistema de
guardrails cumpla sus propios principios.**

### Objetivo

Inventario completo, clasificado y auditable de todos los guardrails del
workspace + matriz de cumplimiento contra principios declarados + informe de
gaps priorizado con propuestas de remediación (solo propuestas — autonomous-safety).

### Criterios de Aceptación del PBI (extracto)

- [ ] Todo guardrail inventariado con capa, principio que implementa y modo (block/warn/log)
- [ ] Toda prohibición "NUNCA/jamás" mapeada a ≥1 enforcement determinista o GAP-P0
- [ ] Toda línea roja L1-L5 con enforcement o gate humano documentado
- [ ] Informe de gaps con propuestas — sin ejecutar remediación sin aprobación humana

---

## 2. Contrato Técnico

### 2.1 Pipeline de auditoría

```
scripts/guardrail-audit.sh
    │
    ├─ FASE A: INVENTORY     → scripts/guardrail-inventory-parse.py
    │    fuentes:
    │      .claude/settings.json          (registro de hooks)
    │      .claude/hooks/*.sh             (implementación)
    │      .opencode/hooks/*.sh           (espejo)
    │      .opencode/agents/*.md          (permission L0-L4, guards)
    │      .claude/rules/*.md + docs/rules/domain/*.md  (normas)
    │      .claude/CONSTITUCION.md        (T3 prohibiciones)
    │      .claude/skills/*/SKILL.md      (guards de skill)
    │    salida: output/guardrail-audit/inventory.json
    │
    ├─ FASE B: CLASSIFY      → capa + principio + modo por entrada
    │    salida: inventory.json enriquecido (campo classification)
    │
    ├─ FASE C: COMPLIANCE    → cruces definidos en §3 (RN-01..RN-12)
    │    salida: output/guardrail-audit/compliance-matrix.md
    │
    ├─ FASE D: GAP REPORT    → hallazgos P0/P1/P2 + propuesta por gap
    │    salida: output/guardrail-audit/gap-report.md
    │
    └─ FASE E: SUMMARY       → output/guardrail-audit/README.md
         (resumen ejecutivo: totales, cobertura, top-5 gaps)
```

### 2.2 Schema de entrada de inventario (`inventory.json`)

```json
{
  "audit_id": "guardrail-audit",
  "generated_at": "2026-09-04T21:40:00Z",
  "workspace_commit": "sha256:{git rev-parse HEAD}",
  "content_fingerprint": "sha256:{deterministic hash del contenido}",
  "guardrails": [
    {
      "id": "hook:block-force-push",
      "type": "hook",
      "path": ".claude/hooks/block-force-push.sh",
      "mirrored_in": [".opencode/hooks/block-force-push.sh"],
      "registered_in_settings": true,
      "events": ["PreToolUse"],
      "mode": "block|warn|log|shadow",
      "layer": "NORMA|DISPARADOR|ENFORCEMENT|INFORMATIVO",
      "protects": ["regla/principio/artículo que implementa"],
      "principles": ["Rule#X", "ART-XX", "L1-L5", "LEC-1..4", "§1-§15"],
      "bypass_switch": "ENV_VAR|null",
      "bypass_documented": true,
      "parse_ok": true
    }
  ]
}
```

### 2.3 Reglas de clasificación de capa

| Capa | Criterio (verificable en el fichero del hook) |
|------|------------------------------------------------|
| ENFORCEMENT | El hook hace `exit != 0` / JSON decision `block|deny` que impide la acción |
| DISPARADOR | El hook inyecta contexto/obliga a evaluar una norma antes de continuar, sin bloquear por sí mismo |
| NORMA | Existe solo como texto (regla .md, artículo constitucional, frontmatter de agente) |
| INFORMATIVO | Log/telemetría sin efecto en el flujo |

---

## 3. Inputs / Outputs Contract

### Inputs

```
- .claude/settings.json            (hooks registrados; solo claves, NUNCA valores de secrets)
- .claude/hooks/*.sh               (123 ficheros)
- .opencode/hooks/*.sh             (espejo)
- .opencode/agents/*.md            (88 frontmatters: permission, tools)
- .claude/rules/, docs/rules/domain/*.md   (normas declaradas)
- .claude/CONSTITUCION.md          (T3: V-01..V-08)
- docs/rules/domain/savia-ethical-principles.md  (§1-§15, L1-L5)
- docs/rules/domain/critical-rules-extended.md   (Rules 9-25)
- docs/rules/domain/autonomous-safety.md         (gates, double opt-in)
- .claude/skills/*/SKILL.md        (Subagent Scope Guard, double opt-in)
```

### Outputs

```
output/guardrail-audit/
├── inventory.json          # Schema §2.2 — completo, determinista
├── compliance-matrix.md    # Matriz guardrail × principio (§3 RN-01..RN-12)
├── gap-report.md           # Gaps P0/P1/P2, cada uno con propuesta (NO ejecutada)
└── README.md               # Resumen ejecutivo ≤ 40 líneas
```

Formato de fila de gap (obligatorio, sin excepciones):

```markdown
| GAP-ID | Severidad | Guardrail | Principio violado | Evidencia (fichero:línea) | Propuesta |
```

---

## 4. Reglas de Negocio (cruces de cumplimiento)

Cada regla es una comprobación automática del pipeline. Sin "según corresponda".

| # | Regla de auditoría | Detección | Severidad si falla |
|---|--------------------|-----------|--------------------|
| RN-01 | Todo guardrail inventariado tiene `layer` clasificada por §2.3 | Campo vacío/ambiguo en inventory | P1 |
| RN-02 | Toda prohibición "NUNCA/jamás" en reglas/CONSTITUCION mapea a ≥1 hook con `mode: block` | Grep de prohibiciones sin enforcement asociado | **P0** |
| RN-03 | Cada línea roja L1-L5 tiene enforcement determinista O gate humano documentado como inasequible técnicamente | Cruce L1-L5 × inventory | **P0** |
| RN-04 | Hook registrado en settings.json cuyo fichero no existe | Registro sin fichero | **P0** |
| RN-05 | Hook presente en disco pero no registrado en ningún evento | Fichero huérfano | P2 |
| RN-06 | Hook con `mode: warn/log/shadow` que protege una prohibición "jamás" | Cruce modo × RN-02 | P1 (escala a P0 si la norma es L1-L5 o T3) |
| RN-07 | Panel de jueces LLM donde todos comparten familia de modelo sin medidas de diversidad documentadas (LEC-3) | Fronmatter de jueces × docs de orquestadores | P1 |
| RN-08 | Todo `bypass_switch` (env var de override) tiene uso legítimo documentado + rastro de auditoría | Cruce env vars × docs | P1 |
| RN-09 | Espejo `.claude/hooks/` vs `.opencode/hooks/` sin drift | Diff de directorios | P2 |
| RN-10 | Toda skill autónoma (L2+) implementa double opt-in y Subagent Scope Guard | Cruce skills × SKILL.md guards | **P0** |
| RN-11 | Agente con permiso L4 sin justificación de por qué necesita ese nivel | Frontmatter sin campo de justificación | P2 |
| RN-12 | La auditoría NO modifica ningún fichero fuente — toda salida es propuesta (autonomous-safety, ART-03) | Invariante del pipeline | **P0** (violación = abort) |

Máximo 12 reglas. Referencias:
```
→ docs/rules/domain/savia-ethical-principles.md (§1-§15, L1-L5)
→ .claude/CONSTITUCION.md (ART-01..ART-20)
→ docs/rules/domain/autonomous-safety.md (double opt-in, SE-332, SE-146)
→ memoria: lesson/lecciones-guardrails-desde-análisis-deb (LEC-1..LEC-4)
```

---

## 5. Constraints and Limits

### Seguridad y soberanía

| Aspecto | Requirement |
|---|---|
| Lectura de secrets | PROHIBIDO leer valores de `pm-config.local.md`, PAT files, preferencias privadas. Solo presencia/ausencia de claves |
| Escritura | Solo en `output/guardrail-audit/` y `scripts/guardrail-*.{sh,py}` |
| Red | No requiere red. Todo local |
| Modificación de fuentes | PROHIBIDA — RN-12. La auditoría es read-only sobre guardrails |
| PII | El informe no incluye datos personales (nombres en configs → redactar a `[REDACTED]`) |

### Performance

| Métrica | Límite | Crítico |
|---|---|---|
| Runtime total | ≤ 60 s | Sí |
| Memory | ≤ 200 MB | No |
| Determinismo | 2 runs sobre el mismo commit → `content_fingerprint` idéntico | Sí |

### Compatibilidad

| Elemento | Constraint |
|---|---|
| Runtime | bash + python3 stdlib (sin deps nuevas — autonomous-safety: no instalar dependencias) |
| Salida | JSON válido parseable con `jq` + Markdown CommonMark |

---

## 6. Test Scenarios

### Happy Path
```
Scenario: Auditoría completa sobre workspace actual
  Given el workspace en el commit actual con 123 hooks y reglas vigentes
  When se ejecuta `bash scripts/guardrail-audit.sh`
  Then se generan los 4 ficheros de salida en output/guardrail-audit/
  And inventory.json lista ≥100 hooks con layer, mode y principles no vacíos
  And compliance-matrix.md contiene una fila por cada RN-01..RN-12
  And el comando termina con exit 0 en ≤60s
```

### Casos de Error
```
Scenario: Hook registrado sin fichero (RN-04)
  Given settings.json que referencia ".claude/hooks/hook-fantasma.sh"
  And el fichero no existe en disco
  When se ejecuta la auditoría
  Then gap-report.md contiene GAP con severidad P0
  And la evidencia cita settings.json:<línea> del registro huérfano

Scenario: Prohibición "NUNCA" sin enforcement (RN-02)
  Given una regla con "NUNCA → Hacer X" que no mapea a ningún hook block
  When se ejecuta la auditoría
  Then gap-report.md contiene GAP P0 con la regla como evidence
  And la propuesta sugiere hook PreToolUse con exit≠0 (no sugerir "recordar al modelo")

Scenario: Linea roja sin protección (RN-03)
  Given una L1-L5 sin hook enforcement ni gate humano documentado
  When se ejecuta la auditoría
  Then gap-report.md la marca P0 y escala el hallazgo al README top-5
```

### Edge Cases
```
Scenario: Hook warn-mode protegiendo prohibición jamás (RN-06)
  → Detectado como P1; si la norma es L1-L5 o T3 → P0

Scenario: Drift de espejo (RN-09)
  → Fichero en .claude/hooks/ ausente en .opencode/hooks/ → P2 con lista exacta

Scenario: Juez LLM con familia de modelo compartida (RN-07)
  → Panel íntegro deepseek-v4-flash sin medidas de diversidad → P1 con LEC-3 como referencia

Scenario: Frontmatter de agente no parseable
  → Entrada con parse_ok:false, clasificada P1, NUNCA silenciosamente omitida

Scenario: Determinismo
  → Dos runs sobre el mismo commit producen content_fingerprint idéntico
  → Si difieren → bug del pipeline, P0 del propio auditor
```

---

## 7. Ficheros a Crear / Modificar

### Crear (nuevos)
```
scripts/guardrail-audit.sh                  # Orquestador FASES A-E (bash)
scripts/guardrail-inventory-parse.py        # Parser inventario → inventory.json (python3 stdlib)
output/guardrail-audit/                     # Directorio de salida (generado)
docs/specs/SPEC-SE-374-GUARDRAIL-PRINCIPLE-AUDIT.spec.md  # Esta spec
```

### Modificar (existentes)
```
Ninguno. La auditoría no toca guardrails existentes (RN-12).
```

### NO tocar
```
.claude/settings.json, .claude/hooks/*, .opencode/hooks/*,
.opencode/agents/*, docs/rules/**, .claude/CONSTITUCION.md
```

---

## 8. Código de Referencia

Patrones existentes a seguir:
```
→ scripts/skill-maturity-audit.sh       (auditoría con salida markdown + kanban)
→ scripts/workspace-integrity / drift   (comparación de estado declarado vs real)
→ scripts/content-fingerprint           (hash determinista de contenido)
→ scripts/anti-adulation/evaluate_sycophancy.py  (python3 stdlib, sin deps)
```

---

## 9. Configuración de Entorno

```bash
PROJECT_DIR="/home/monica/savia"
# Verificación post-ejecución:
bash scripts/guardrail-audit.sh
jq '.guardrails | length' output/guardrail-audit/inventory.json   # ≥100
test -f output/guardrail-audit/gap-report.md
```

Sin variables de entorno externas. Sin red. Sin secrets.

---

## 10. Estado de Implementación

```markdown
**Estado:** Implementada (pendiente de revisión humana de remediación)

**Último update:** 2026-09-05
**Actualizado por:** Savia (agente, autorización expresa de Mónica: "Implementa ... pr y merge")

### Log de implementación
- scripts/guardrail-inventory-parse.py — FASES A+B: inventario (663 entradas:
  119 hooks · 6 gates estructurales · 88 agentes · 313 normas+constitución ·
  135 skills) y hallazgos RN-01..RN-12 (python3 stdlib).
- scripts/guardrail-audit.sh — orquestador FASES A-E + invariante RN-12
  (git status antes/después, abort exit 2 si toca fuentes).
- Validación §6: happy path ✓ (exit 0, 1s, 4 ficheros), determinismo ✓
  (fingerprint sha256:17d0f0bd… estable en 2 runs y entre ejecuciones),
  sandbox /tmp con hook fantasma (RN-04 P0 @ settings.json:línea ✓),
  NUNCA sin pared (RN-02 P0 ✓), warn sobre línea roja (RN-06 escala P0 ✓),
  frontmatter roto (RN-01 P1, sin omisión silenciosa ✓), drift espejo (P2 ✓).
- Resultado (instantánea 2026-09-05, commit previo al PR): P0=241 · P1=6 ·
  P2=8. Lectura clave: RN-02 78/318 prohibiciones con pared determinista;
  RN-03 L4 sin gate enlazado; RN-07 paneles truth-tribunal y coherence-court
  mono-familia (LEC-3). Informes en output/guardrail-audit/ (gitignored,
  regenerables con `bash scripts/guardrail-audit.sh`).
- Sin remediación ejecutada (autonomous-safety, ART-03). Sin lectura de
  valores de secrets. Sin PII en informes (verificado por grep).

### Blockers
- (ninguno)
```

---

## 11. Checklist Pre-Entrega

### Implementación
- [ ] Los 2 scripts creados siguen §7 exactamente
- [ ] inventory.json valida contra schema §2.2 (jq parseable)
- [ ] Los 12 cruces RN-01..RN-12 implementados y verificables en compliance-matrix.md
- [ ] Todos los scenarios de §6 tienen resultado observable
- [ ] Runtime ≤60s, determinista (fingerprint estable en 2 runs)
- [ ] Cero escrituras fuera de output/guardrail-audit/ y scripts/guardrail-*
- [ ] gap-report.md: cada gap tiene evidencia fichero:línea y propuesta — cero gaps "a criterio del dev"

### Específico para agente
- [ ] No se modificó ningún guardrail existente
- [ ] No se leyeron valores de secrets (solo presencia de claves)
- [ ] Las propuestas de remediación quedan como PROPUESTAS — ninguna ejecutada
- [ ] Hallazgos P0 elevados al top del README.md

---

## 12. Notas para el Revisor

```
1. El valor de esta auditoría está en RN-02/RN-03/RN-06: ¿cada "jamás" tiene
   una pared determinista? (LEC-2). Las capas NORMA/DISPARADOR son
   probabilísticas por diseño — el informe debe distinguirlas claramente
   para no vender norma por enforcement.

2. RN-07 es la lección menos obvia (LEC-3): los paneles de jueces de este
   workspace (Court, Tribunal) usan mayoritariamente deepseek-v4-flash.
   La auditoría debe señalarlo como riesgo de correlación estructural,
   no como defecto individual de cada juez.

3. Al completar, evaluar: repetición 2+ → documentar como skill
   (guardrail-audit) según Rule #6. No crear la skill en esta task.

4. Este audit NO valida el contenido ético de los principios (eso lo hace
   la revisión trimestral de savia-ethical-principles.md); valida que la
   arquitectura de guardrails los IMPLEMENTE.
```

---

## 13. Iteration & Convergence Criteria

Spec lista para implementar cuando:
- [x] Inputs: ficheros fuente concretos y rutas exactas (§3)
- [x] Reglas: 12 cruces en tabla, cada uno con severidad definida (§4)
- [x] Tests: happy + error + edge con Given/When/Then (§6)
- [x] Constraints: seguridad, performance y determinismo cuantificados (§5)
- [x] Ficheros: lista exacta crear/modificar/no-tocar (§7)
- [x] **APROBACIÓN HUMANA** — Mónica confirma el alcance antes de implementar
  (autorización registrada 2026-09-05: "Implementa docs/specs/SPEC-SE-374-GUARDRAIL-PRINCIPLE, pr y merge")

NO empezar implementación sin la aprobación de la operadora (Rule #8, ART-03).
