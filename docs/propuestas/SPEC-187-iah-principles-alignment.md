---
spec_id: SPEC-187
title: Alineacion principios eticos Savia con marco IAH (Inteligencia Artificial Humanista)
status: IMPLEMENTED
tier: 1
priority: P1
effort: 3-4h
era: 200
wave: 1
deps: [SE-104]
unblocks: []
origin: active-user-2026-06-04
implemented_at: "2026-06-24"
inspiration: 10 principios esenciales de la IAH
timeline:
  - from: "2026-06-05"
    learned: "2026-06-05"
    value: "PROPOSED"
    source: "docs(spec): SPEC-187 IAH principles alignment proposal (#810)"
---

# SPEC-187 — Alineacion principios eticos Savia con marco IAH

> Estado: IMPLEMENTED · Tier 1 · P1 · Estimacion 3-4h · Era 200 · Wave 1

## Resumen

Los 13 principios eticos de Savia (`docs/rules/domain/savia-ethical-principles.md`) cubren la mayoria del marco IAH, pero quedan 4 gaps reales: sostenibilidad ambiental, pluralismo cultural, robustez tecnica y explicabilidad como derecho. Esta spec mapea el solapamiento, identifica gaps y propone 4 principios nuevos (§14-§17) + refinamiento de §3 y §4. NO duplica contenido existente.

## Motivacion

- Usuario aporta marco IAH (10 principios) que se usa cada vez mas como referencia publica.
- Auditar Savia contra IAH expone que faltan 4 principios o estan distribuidos sin consolidar.
- Alineacion explicita facilita comunicacion externa, contratos publicos y compliance regulatorio.
- Riesgo de NO alinear: incumplimiento de RFCs sectoriales que citen IAH (sanidad, educacion, AAPP).

## Analisis de alineamiento — matriz IAH ↔ Savia

| IAH | Principio | Mapeo Savia | Estado |
|---|---|---|---|
| 1 | Dignidad Humana Primero | §4 Dignidad humana, §13 criterio ultimo | COMPLETO |
| 2 | Agencia y Control Humano (HITL) | §3 Responsabilidad, L2, Rule #8 | PARCIAL — falta nombrar dominios criticos (salud/justicia/empleo) |
| 3 | Explicabilidad y Transparencia | §3 (trazabilidad) | PARCIAL — falta principio dedicado al derecho del usuario afectado |
| 4 | Equidad y Mitigacion de Sesgos | §4, equality-shield.md, Rule #23 | PARCIAL — falta obligacion ACTIVA de auditar/corregir |
| 5 | Privacidad por Diseno | §7, data-sovereignty.md, Rules #20/#20b | COMPLETO |
| 6 | Responsabilidad y Rendicion de Cuentas | §3, autonomous-safety.md | COMPLETO |
| 7 | Sostenibilidad y Eficiencia | nota lateral en §6 | GAP — sin principio dedicado |
| 8 | Diversidad Cultural y Pluralismo | §4 + §10 (parcial) | GAP — sin principio dedicado a lenguas minoritarias |
| 9 | Seguridad y Robustez Tecnica | distribuido en radical-honesty + Truth Tribunal | GAP — sin principio consolidado |
| 10 | Bien Comun y Florecimiento Humano | §13, §6 | COMPLETO |

**Gaps confirmados**: 4 nuevos principios necesarios + 2 refinamientos.

## Scope

### Anadir 4 principios nuevos a `savia-ethical-principles.md`

**§14 — Sostenibilidad ambiental y huella digital** (cubre IAH-7)
- Optimizacion energetica de modelos como criterio de diseno.
- Preferencia por infra de menor huella de carbono.
- Medicion y reporting cuando sea relevante (ej. cargas de inferencia en bucle).
- Reglas vinculadas: nueva skill `carbon-aware-scheduling` (futura), context-caching skill (reduce inferencia redundante).

**§15 — Pluralismo cultural y lenguas minoritarias** (cubre IAH-8)
- Savia respeta el idioma del perfil activo (preferences.md) y NO impone vision monocultural.
- Prohibicion de generar contenido que invisibilice identidades locales o reduzca diversidad linguistica a "ingles por defecto".
- Cuando un proyecto opera en lengua minoritaria (catalan, euskera, gallego, lenguas indigenas), Savia documenta y respeta.
- Reglas vinculadas: existente regla de idioma en CLAUDE.md ("Savia responde SIEMPRE en el idioma del perfil activo").

**§16 — Robustez tecnica frente a manipulacion** (cubre IAH-9)
- Comportamiento predecible frente a alucinaciones, prompt injection, envenenamiento de datos.
- Escalado a humano cuando se detectan inconsistencias internas o entradas adversariales.
- Reglas vinculadas: Truth Tribunal (factuality-judge, hallucination-judge), `adversarial-security` skill, Recommendation Tribunal (rule-violation-judge).

**§17 — Explicabilidad como derecho** (cubre IAH-3)
- Toda decision automatizada que afecte a una persona genera explicacion en lenguaje accesible (no solo logs tecnicos).
- El usuario afectado tiene derecho a saber: que datos se usaron, que criterios pesaron, quien es responsable humano final.
- Reglas vinculadas: `radical-honesty.md` (sin cajas negras), `decision-trees/` (rationale por agente), nueva obligacion en outputs criticos.

### Refinar 2 principios existentes

**§3 Responsabilidad** — anadir parrafo:
> "En dominios criticos (salud, justicia, empleo, educacion, finanzas personales), Savia NUNCA actua sin supervision humana explicita, incluso si el usuario tiene permisos. La responsabilidad legal NO se delega."

**§4 Dignidad humana** — anadir parrafo:
> "Savia tiene obligacion ACTIVA de auditar sus propias salidas para detectar sesgos por genero, raza, edad, religion, identidad, orientacion sexual o contexto socioeconomico. La pasividad ('no he programado sesgos') no exime: la auditoria periodica es parte del principio."

### Actualizar tabla de integracion (linea 252-266)

Anadir 4 filas:
| §14 Sostenibilidad | nueva regla `carbon-awareness.md` | metricas energeticas en outputs criticos |
| §15 Pluralismo cultural | regla idioma CLAUDE.md, perfil tone.md | respeto idioma + identidad local |
| §16 Robustez tecnica | Truth Tribunal + Recommendation Tribunal | jueces, escalado anomalias |
| §17 Explicabilidad | rationale obligatorio en outputs criticos | decision-trees, radical-honesty |

### Actualizar protocolo de conflicto (linea 232-246)

Jerarquia actual: `dignidad > verdad > eficiencia`.
Anadir nota: cuando entren los principios IAH-7 (sostenibilidad) o IAH-8 (pluralismo) en conflicto con eficiencia, prevalecen IAH-7/IAH-8. Sostenibilidad y diversidad estan POR ENCIMA de eficiencia.

## Out of scope

- NO se modifican las 5 lineas rojas inmutables (L1-L5). Los 4 principios nuevos NO requieren nueva linea roja.
- NO se duplican los 13 principios existentes. Solo se anaden los 4 gaps reales.
- NO se cambia la voz descriptiva ("Savia hace X").

## Acceptance criteria

1. `docs/rules/domain/savia-ethical-principles.md` contiene §14, §15, §16, §17 con la misma estructura (Principio + Fundamento + Aplicabilidad + Reglas vinculadas).
2. §3 y §4 incluyen los parrafos de refinamiento.
3. La tabla de integracion (linea 252) tiene 17 filas (eran 13).
4. La tabla del preambulo y el indice (si existe) reflejan los nuevos principios.
5. Test BATS `tests/test-ethical-principles-iah-coverage.bats` valida:
   - Existen secciones §14, §15, §16, §17.
   - Las palabras clave IAH ("sostenibilidad", "lenguas minoritarias", "robustez tecnica", "explicabilidad") aparecen al menos una vez cada una.
   - §3 menciona "salud, justicia, empleo" en el parrafo de dominios criticos.
   - §4 menciona "auditar" como obligacion activa.
6. CHANGELOG.md entry: `### Anadido — SPEC-187 — Alineacion IAH`.
7. ROADMAP.md actualizado con SPEC-187 en estado IMPLEMENTED post-merge.
8. Confidentiality signature firmada tras edicion.

## Tests

### Test 1 — Cobertura IAH (BATS)

`tests/test-ethical-principles-iah-coverage.bats`:

```bash
@test "savia-ethical-principles contiene 17 principios numerados" {
  count=$(grep -cE '^## [0-9]+\.' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -ge 17 ]
}

@test "principio 14 cubre sostenibilidad" {
  grep -A 30 '^## 14\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'sostenibilidad|huella|carbono|energia'
}

@test "principio 15 cubre pluralismo cultural" {
  grep -A 30 '^## 15\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'lengua|cultura|identidad local|pluralismo'
}

@test "principio 16 cubre robustez tecnica" {
  grep -A 30 '^## 16\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'robustez|alucina|prompt injection|envenenamiento'
}

@test "principio 17 cubre explicabilidad como derecho" {
  grep -A 30 '^## 17\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'explicabilidad|caja negra|lenguaje accesible'
}

@test "principio 3 menciona dominios criticos salud-justicia-empleo" {
  grep -A 50 '^## 3\.' docs/rules/domain/savia-ethical-principles.md | grep -qE 'salud.*justicia.*empleo|salud, justicia, empleo'
}

@test "principio 4 incluye obligacion activa de auditar sesgos" {
  grep -A 50 '^## 4\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'obligacion activa|auditar|auditoria periodica'
}

@test "tabla de integracion incluye 17 principios" {
  count=$(grep -cE '^\| §[0-9]+' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -ge 17 ]
}

@test "lineas rojas siguen siendo 5 (no se anaden)" {
  count=$(grep -cE '^\| \*\*L[0-9]\*\*' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -eq 5 ]
}
```

### Test 2 — Lint estructural

Validar con `markdownlint` que no se rompe el formato y que el diff hash de confidentiality se actualiza.

## Riesgos

| Riesgo | Probabilidad | Mitigacion |
|---|---|---|
| Inflar el documento mas alla de lo legible | media | Mantener cada principio nuevo en <50 lineas, mismo molde de los existentes |
| Conflicto con SE-104 (foundation original) | baja | SE-104 declara extensible; esta spec es extension, no reescritura |
| Cambios rompen tests existentes (test-savia-ethical-principles si existe) | media | Inspeccionar tests/ antes de tocar el archivo; ajustar si necesario |
| Regla de idioma en CLAUDE.md ya cubre §15 parcialmente — sensacion de duplicacion | baja | El principio §15 es marco etico de POR QUE; CLAUDE.md es regla operativa COMO. Distinto nivel |
| Nueva regla `carbon-awareness.md` (§14) no existe aun | media | Proponer creacion en SPEC futuro, NO bloqueante para esta spec — el principio se aplica antes de la regla operativa |

## Plan de implementacion (OpenCode)

### Slice 1 — Anadir 4 principios + refinar 2 (1.5h)
1. Editar `docs/rules/domain/savia-ethical-principles.md`:
   - Anadir secciones `## 14.`, `## 15.`, `## 16.`, `## 17.` con estructura (Principio + Fundamento + Aplicabilidad + Reglas vinculadas).
   - Anadir parrafo final en §3 (dominios criticos).
   - Anadir parrafo final en §4 (auditoria activa).
   - Actualizar tabla de integracion (anadir 4 filas §14-§17).
   - Anadir nota en protocolo de conflicto sobre IAH-7/IAH-8 vs eficiencia.
2. Validar drift-check de CLAUDE.md (no afecta counters).

### Slice 2 — Tests BATS (1h)
1. Crear `tests/test-ethical-principles-iah-coverage.bats` con 9 tests del Acceptance Criteria.
2. Ejecutar local: `bats tests/test-ethical-principles-iah-coverage.bats`.
3. Asegurar set -uo pipefail en linea ≤5 si fuera script (no aplica, es .bats).

### Slice 3 — Doc + sign + push (0.5h)
1. CHANGELOG.md: entrada `### Anadido — SPEC-187`.
2. ROADMAP.md: entrada en Active Stack PROPOSED.
3. `bash scripts/confidentiality-sign.sh sign`.
4. Commit + push (rama `feature/spec-187-iah-principles-alignment`).
5. Crear PR Draft con AUTONOMOUS_REVIEWER.

### Slice 4 — Court of Review post-IMPLEMENTED (1h)
1. Marcar status IMPLEMENTED en frontmatter.
2. Verificar BATS local 9/9.
3. Esperar CI verde.
4. Esperar revision humana (E1 SDD obligatorio).

## Archivos afectados

- `docs/rules/domain/savia-ethical-principles.md` (edit, +200 lineas estimadas)
- `tests/test-ethical-principles-iah-coverage.bats` (nuevo)
- `CHANGELOG.md` (edit, 1 entrada)
- `docs/ROADMAP.md` (edit, 1 entrada Active Stack)
- `.confidentiality-signature` (auto re-firma)

## No afecta

- 5 lineas rojas L1-L5 (inmutables).
- 13 principios existentes en su sustancia (solo refinamiento de §3 y §4).
- Rules operativas tecnicas (autonomous-safety, radical-honesty, equality-shield, data-sovereignty).
- Codigo del workspace (es solo documentacion + tests).

## Open questions

1. ¿Se crea YA la regla `carbon-awareness.md` (§14) o se posterga a spec separada?
   **Recomendacion**: posterga. El principio etico se aplica sin regla operativa. La regla nace cuando hay caso de uso concreto.

2. ¿Refleja los principios IAH-7 y IAH-8 en jerarquia de conflicto (`dignidad > verdad > eficiencia`)?
   **Recomendacion**: si. Anadir nota: `sostenibilidad > eficiencia` y `pluralismo > eficiencia` son corolarios.

3. ¿Se renumeran las lineas rojas si se anade L6 en futuro?
   **Recomendacion**: no se anade L6 ahora. Si futuro spec lo requiere, las lineas rojas siguen siendo inmutables hasta entonces.

## Trazabilidad

- Origen: peticion del usuario activo (2026-06-04).
- Fuente IAH: 10 principios esenciales de la Inteligencia Artificial Humanista.
- Documento base: `docs/rules/domain/savia-ethical-principles.md` (SE-104).
- Vinculacion: amplia el corpus etico fundacional sin reemplazarlo.
