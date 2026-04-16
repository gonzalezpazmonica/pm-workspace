# Spec: Hooks-over-Prompts Audit — Borrar reglas que Claude ya cumple

**Task ID:**        SPEC-HOOKS-OVER-PROMPTS-AUDIT
**PBI padre:**      Context diet continuation (Era 165 follow-up)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: Anthropic best practices 2026)

**Developer Type:** human-with-agent
**Asignado a:**     Savia + Monica approval
**Estimacion:**     4h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-opus-4-6

---

## 1. Contexto y Objetivo

Anthropic best practices 2026 formaliza una regla que pm-workspace ya aplica
parcialmente: **"Si Claude ya hace X correctamente, borra la instruccion o
conviertela en hook"**. Era 165 (dieta CLAUDE.md 121->48 lineas) fue un
primer corte. Quedan 25 reglas criticas inline, 31 hooks y 200+ ficheros
en `docs/rules/domain/` cuyo ROI real no esta medido.

El coste es real: CLAUDE.md se reenvia CADA turno sin cache. Las reglas en
`@imports` tambien entran en el prompt base cada sesion. Cada linea que
Claude ya cumple sin instruccion es token desperdiciado per-turn, multiplicado
por todas las sesiones.

**Objetivo:** auditar sistematicamente las 25 reglas criticas + hooks activos
+ top 20 rules/domain mas cargadas, y aplicar el algoritmo:

1. **Regla + hook existente que la enforce** -> borrar regla (hook es autoridad)
2. **Regla sin hook pero Claude la cumple** -> borrar regla, medir sin ella
3. **Regla sin hook y Claude la olvida** -> crear hook, borrar regla
4. **Regla preferencia suave** -> mantener en CLAUDE.md (olvidar ok)

**Criterios de Aceptacion:**
- [ ] Matriz completa regla <-> hook <-> evidencia publicada
- [ ] Reduccion >=20% en lineas de CLAUDE.md + critical-rules-extended.md
- [ ] Zero regresiones en comportamiento (test con 20 comandos)
- [ ] Nuevos hooks creados para reglas "olvidables"
- [ ] Documento de decision publicado en docs/

---

## 2. Contrato Tecnico

### 2.1 Matriz de auditoria

Cada regla evaluada recibe una fila:

```
| ID regla | Fichero | Tipo | Hook existe | Claude cumple sin ella | Decision |
|----------|---------|------|-------------|------------------------|----------|
| R1       | CLAUDE  | seg  | SI          | SI (enforced)          | BORRAR   |
| R2       | CLAUDE  | cal  | NO          | SI (5/5 test)          | BORRAR   |
| R3       | CLAUDE  | seg  | NO          | NO (2/5 test)          | CREAR HOOK |
| R4       | CLAUDE  | pref | NO          | N/A                    | MANTENER |
```

### 2.2 Test de "Claude cumple sin la regla"

Para cada regla candidata, ejecutar 5 prompts relevantes con CLAUDE.md
modificado (regla eliminada temporalmente) y medir:

- Tasa de cumplimiento: 5/5 -> borrar / 4/5 -> mantener o crear hook
- Severidad del fallo: si falla, cual fue el impacto
- Determinismo: si Claude falla 1 de 5 veces, es olvido aleatorio -> hook

### 2.3 Comando de auditoria

```bash
# scripts/rule-audit.sh
# Usage: bash scripts/rule-audit.sh [--rule R1] [--all] [--dry-run]
#
# Options:
#   --rule ID      Audit solo una regla
#   --all          Audit las 25 reglas criticas
#   --dry-run      No modifica CLAUDE.md, solo reporta
#
# Output: matriz en output/audits/rule-audit-{fecha}.md
```

### 2.4 Scope del audit

**Incluido:**
- Reglas 1-25 de CLAUDE.md + critical-rules-extended.md
- Top 20 ficheros en `docs/rules/domain/` por tamaño
- Los 31 hooks activos en settings.json

**Excluido:**
- Reglas legales/compliance (AEPD, GDPR, PII) — siempre mantener
- Reglas de personalidad (savia.md, radical-honesty.md) — identidad
- Reglas inmutables de seguridad (autonomous-safety.md)
- Principios fundacionales (savia-foundational-principles.md)

### 2.5 Candidatos iniciales a borrar (hipotesis)

Reglas con hooks equivalentes que probablemente sobran inline:

- Rule 1 (NUNCA hardcodear PAT) -> hook `block-credential-leak.sh` YA enforza
- Rule 13 (NUNCA commit en main) -> hook pre-commit YA bloquea
- Rule 14 (CI local antes de push) -> hook `agent-hook-premerge.sh` YA valida
- Rule 11 (150 lineas max) -> hook `agent-hook-premerge.sh` YA valida

Estas son hipotesis, el audit debe confirmarlas con test real.

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| RAU-01 | Nunca borrar regla sin test de no-regression | Bug introducido |
| RAU-02 | Regla borrada debe tener hook equivalente O evidencia de cumplimiento | Comportamiento roto |
| RAU-03 | Borrado en PR dedicado, revisable por Monica | Cambios sin supervision |
| RAU-04 | Matriz publicada antes de cualquier borrado | Sin transparencia |
| RAU-05 | Reglas inmutables NUNCA se tocan (auto-safety, principles) | Corrupcion critica |
| RAU-06 | Cada borrado registrado en CHANGELOG con before/after count | Auditoria |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | Zero externas; solo bash + git + jq |
| Reversibilidad | Todo borrado revertible via git |
| Seguridad | Reglas inmutables protegidas por whitelist en el script |
| Testing | Test de comportamiento antes y despues |
| Aprobacion | Todo cambio pasa por PR con review humana |

---

## 5. Test Scenarios

### Audit dry-run completo

```
GIVEN   25 reglas criticas activas
WHEN    bash scripts/rule-audit.sh --all --dry-run
THEN    output/audits/rule-audit-20260411.md generado
AND     contiene matriz con decision por cada regla
AND     NO modifica CLAUDE.md
```

### Borrado con hook equivalente

```
GIVEN   Rule 1 (no hardcodear PAT) + hook block-credential-leak.sh activo
WHEN    audit detecta redundancia
THEN    decision = BORRAR
AND     test de no-regression pasa (PAT hardcoded sigue bloqueado)
```

### Regla que Claude olvida

```
GIVEN   regla X eliminada temporalmente
WHEN    10 prompts relevantes ejecutados
AND     2/10 fallan en cumplir regla X
THEN    decision = CREAR HOOK
AND     regla X NO se borra hasta que el hook exista
```

### Proteccion de reglas inmutables

```
GIVEN   intento de audit sobre autonomous-safety.md
WHEN    bash scripts/rule-audit.sh --rule AUTOSAFE-01
THEN    exit 1 con mensaje "regla inmutable, no auditar"
```

### Reduccion medible

```
GIVEN   audit completo con 8 reglas borradas
WHEN    CLAUDE.md + critical-rules-extended.md recontado
THEN    reduccion lineas >= 20%
AND     reduccion tokens por turno medible
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/rule-audit.sh | Orquestador del audit |
| Crear | scripts/rule-audit-test.sh | Runner de prompts test |
| Crear | tests/test-rule-audit.bats | Suite BATS |
| Crear | docs/audits/rule-audit-methodology.md | Documentar metodo |
| Modificar | CLAUDE.md | Borrar reglas redundantes (tras audit) |
| Modificar | docs/rules/domain/critical-rules-extended.md | Idem |
| Crear | .claude/hooks/{nuevo}.sh | Nuevos hooks para reglas "olvidables" |
| Modificar | CHANGELOG.md | Registrar dieta con metricas |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Reduccion CLAUDE.md | >=20% lineas | wc -l antes/despues |
| Reduccion tokens base | >=15% per turn | Medicion empirica |
| Zero regresiones | 100% | Test suite completa pasa |
| Hooks nuevos justificados | >=3 | Cubre "olvidables" |
| PR aprobado por Monica | 1 PR dedicado | gh pr list |

---

## Checklist Pre-Entrega

- [ ] scripts/rule-audit.sh funcional
- [ ] Matriz completa publicada en docs/audits/
- [ ] Al menos 5 reglas borradas con evidencia
- [ ] Al menos 2 hooks nuevos creados para reglas "olvidables"
- [ ] Test de no-regression verde
- [ ] CHANGELOG con before/after count
- [ ] PR dedicado en revision por Monica
- [ ] Tests BATS >=80 score
