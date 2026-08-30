# SE-351 — Verificación binaria de PoCs en el pipeline pentest (lección CyberGym)

**Status:** APPROVED (implementation-ready)
**Fecha:** 2026-08-30
**Área:** Security / Pentesting pipeline
**Fuente de aprendizaje:** CyberGym (sunblaze-ucb/cybergym, arXiv 2506.02548) — ver `output/research/cybergym-20260830.md`
**Criterio humano aplicable:** CRIT-001 (datos en infraestructura propia, N3+ jamás a cloud)

---

## 1. Objetivo

Cerrar el gap de **verificación binaria** en el pipeline `pentester` de Savia: hoy la
Fase 4 clasifica `EXPLOITED` por **juicio del propio agente** sobre el output del target.
CyberGym demuestra que el veredicto de explotación debe ser **binario, reproducible e
independiente del agente**: ejecutar el PoC contra el target vulnerable y exigir un
**señal observable verificada programáticamente** (exit code ≠ 0, patrón en output, etc.)
antes de promover un hallazgo a L3. "Facts, not claims" (patrón FxC): la evidencia la
produce el programa, no la narrativa del agente.

## 2. Contexto y problema

### 2.1 Estado actual de Savia

- `pentester` agent: pipeline de 5 fases; Fase 4 (Exploitation) consume colas JSON de
  Fase 3, intenta payloads y clasifica `EXPLOITED` / `ATTEMPTED_FAILED` / `SKIPPED`.
- Política "no exploit, no report": solo hallazgos L3 se reportan. Pero la clasificación
  L3 depende del **análisis del agente** del output del comando — no hay verificación
  programática reproducible.
- `security-auditor` (L1) revisa hallazgos del Red/Blue Team con métodos propios, pero
  tampoco re-ejecuta el PoC contra un oráculo.

### 2.2 Lección CyberGym

CyberGym ejecuta el PoC del agente contra el binario `-vul` y `-fix`:
éxito = crash en `-vul` (exit≠0) que NO crash en `-fix`. El veredicto lo produce el
**programa**, no el LLM. Además añade: masking de IDs (anti-leak), egreso restringido
(firewall), final-submission metric, cost reporting. Este spec adopta el núcleo:
**verificación binaria reproducible** para el pipeline pentest.

### 2.3 Gap concreto

Un hallazgo `EXPLOITED` hoy es una afirmación del agente. Con SE-351 pasa a ser una
**afirmación + verificación programática**: el PoC se re-ejecuta contra un oráculo
(configurable por target: exit code, patrón regex, o comparación pre/post) y solo si
pasa se promueve a L3. El agente ya no puede auto-validarse.

## 3. Propuesta

Componente transversal: **`scripts/poc-verify.sh`** — verificador binario de PoCs
independiente del LLM. Invocable por el `pentester` agent (Fase 4), por `security-auditor`
(verificación independiente) y por scripts de prueba.

### 3.1 Qué hace

- Recibe: (a) el PoC (fichero o comando), (b) el target (comando de ejecución o endpoint),
  (c) el oráculo de éxito (JSON/YAML).
- Ejecuta el PoC contra el target en sandbox aislado (`network_mode="none"` si Docker).
- Evalúa el oráculo **programáticamente**: exit code, patrón en stdout/stderr, o ambos.
- Devuelve `VERDICT: VERIFIED|NOT_VERIFIED|TIMEOUT|ERROR` con exit code:
  0 = VERIFIED, 1 = NOT_VERIFIED, 124 = TIMEOUT, 2 = error de uso, 3 = error de infra.
- Escribe un **recibo JSON** (`output/security/poc-verify-{timestamp}.json`) con el PoC,
  el comando, el output acotado, el veredicto y el hash — auditable y reproducible.
- **CRIT-001**: todo local, sin red al proveedor. El PoC se ejecuta en entorno controlado
  del workspace (Docker local o comando local), nunca contra producción sin autorización.

### 3.2 Qué NO hace

- No decide si una vulnerabilidad es explotable por sí solo — verifica que un PoC produce
  la señal esperada. La interpretación (¿es una vuln real?) la hace el pentester/auditor.
- No sustituye el juicio humano ni el `security-auditor`.
- No ejecuta nada contra producción (reglas por entorno del skill pentesting §4).
- No reemplaza el masking/egreso de CyberGym (fuera de scope — ver §7).

### 3.3 Oráculo (formato)

```json
{
  "name": "verify-lfi",
  "target": {
    "type": "command",           // command | docker | http
    "command": "php -r 'include $_GET[\"f\"];' -- {poc}",
    "docker_image": null,        // si type=docker
    "timeout_secs": 10,
    "network": "none"            // sandbox: none | host
  },
  "oracle": {
    "mode": "exit_code_nonzero", // exit_code_nonzero | regex | combined
    "expected_exit": 1,          // solo si mode=exit_code_nonzero
    "regex": "root:x:0",         // solo si mode=regex|combined
    "require_all": true          // combined: exit≠0 Y regex
  }
}
```

### 3.4 Integración con el pipeline pentest (Fase 4)

Regla en el skill pentesting: un hallazgo solo se marca `EXPLOITED` (y pasa a L3) si
`poc-verify.sh` devuelve `VERIFIED` contra el oráculo del target. `ATTEMPTED_FAILED`
si `NOT_VERIFIED`. El recibo JSON se adjunta al hallazgo como evidencia reproducible.
`security-auditor` puede re-ejecutar el verificador para confirmar/desmentir hallazgos.

## 4. Decisiones (preguntas cerradas)

| Pregunta | Decisión | Justificación |
|---|---|---|
| ¿Verificador por target o genérico? | **Genérico con oráculo configurable** | Un script, N targets; el oráculo se define por target en `rules/poc-verify/` |
| ¿Dónde corre el PoC? | Docker local con `network_mode="none"` si hay imagen; si no, comando local con timeout | CRIT-001 + aislamiento (lección `run_container` de CyberGym) |
| ¿Exit code solo o con regex? | **Ambos** (`exit_code_nonzero`, `regex`, `combined`) | No todos los targets crashean; algunos dan señal en output |
| ¿Integrar en Fase 4? | Sí, como gate de `EXPLOITED` | Cierra el gap de auto-reporte |
| ¿Migrar `security-auditor` a re-verificar? | Sí, invocable | Revisión independiente |
| ¿Adoptar masking/egreso de CyberGym? | **No** en esta spec | Specs separadas (ver §7) — mantener PR pequeño |

## 5. Ficheros

| Acción | Path |
|---|---|
| CREATE | `docs/specs/SE-351-poc-verify.spec.md` |
| CREATE | `scripts/poc-verify.sh` |
| CREATE | `rules/poc-verify/README.md` (documenta formato de oráculos) |
| CREATE | `rules/poc-verify/example.json` (oráculo de ejemplo) |
| CREATE | `tests/test-se-351-poc-verify.bats` |
| MODIFY | `.claude/skills/pentesting/SKILL.md` (Fase 4: gate `poc-verify`) |
| MODIFY | `.opencode/agents/pentester.md` (mención del gate binario) |
| MODIFY | `.opencode/agents/security-auditor.md` (re-verificación) |
| CREATE | `CHANGELOG.d/se351-poc-verify.md` |

## 6. Criterios de aceptación

- AC-1: `poc-verify.sh verify --oracle <json> --poc <file>` con oráculo `exit_code_nonzero`
  y PoC que crashea → `VERDICT: VERIFIED` (exit 0).
- AC-2: mismo oráculo, PoC que no crashea → `VERDICT: NOT_VERIFIED` (exit 1).
- AC-3: oráculo `regex` que matchea el output → VERIFIED; que no matchea → NOT_VERIFIED.
- AC-4: oráculo `combined` (exit≠0 Y regex) requiere ambos; falla si solo uno se cumple.
- AC-5: timeout del target → `VERDICT: TIMEOUT` (exit 124) con output acotado.
- AC-6: `--poc` inexistente → error de uso (exit 2); infra falla (docker no disponible) → exit 3.
- AC-7: escribe recibo JSON en `output/security/poc-verify-{timestamp}.json` con hash del PoC.
- AC-8: recibo NO contiene el output completo del PoC (solo primeros N bytes — anti-leak de datos N3+).
- AC-9: sin red salvo target local/Docker `network=none`; cero llamadas a proveedor (CRIT-001).
- AC-10: skill pentesting Fase 4 requiere `VERIFIED` para marcar `EXPLOITED`; recibo se adjunta al hallazgo.
- AC-11: suite BATS ≥ 15 tests (validación local; bats en CI).
- AC-12: `security-auditor` puede invocar `poc-verify.sh` para confirmar/desmentir un hallazgo.

## 7. Fuera de scope (specs futuras)

- **Masking de IDs anti-leak** para benchmarks internos (ofuscar IDs de tareas de evaluación).
- **Egreso restringido** para skills autónomos (red interna sin salida salvo allowlist — Squid).
- **Final-submission metric** en evaluaciones de agents (evitar any-of).
- **Integración con CyberGym real** (descargar el benchmark de 240GB y correr evaluaciones).

## 8. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| spec | `docs/specs/SE-351-poc-verify.spec.md` | lectura directa |
| script | `scripts/poc-verify.sh` (bash + python3 heredoc) | invocación bash directa |
| tests | `tests/test-se-351-poc-verify.bats` | bats runner (CI) |
| skill | `.claude/skills/pentesting/SKILL.md` | skill registry |
| agents | `.opencode/agents/pentester.md`, `security-auditor.md` | agent registry |
| rules | `rules/poc-verify/*` | lectura directa |

### Verification protocol

- [x] Funciona en runtime OpenCode (bash puro, sin bindings de frontend)
- [x] Smoke test local de cada modo de oráculo (ver §9)
- [ ] Tests bats ejecutados en CI

### Portability classification

- [x] **PURE_BASH** — lógica en bash/python3 heredoc; corre idéntico en Claude Code y OpenCode.

## 9. Validación (ejecutada en esta sesión)

```
# exit_code_nonzero: PoC que crashea (exit 1) → VERIFIED
bash scripts/poc-verify.sh verify --oracle rules/poc-verify/example.json \
  --poc <(printf 'boom') 2>&1

# regex: PoC cuyo output matchea → VERIFIED
# NOT_VERIFIED: PoC inofensivo
# TIMEOUT: comando que duerme > timeout
```

## Referencias

- `output/research/cybergym-20260830.md` — análisis completo de CyberGym
- `https://github.com/sunblaze-ucb/cybergym` — Apache 2.0, arXiv 2506.02548
- `.opencode/skills/pentesting/SKILL.md` — pipeline Shannon, Fase 4, proof levels
- `.opencode/agents/pentester.md` — "no exploit, no report"
- `docs/rules/domain/autonomous-safety.md` — entornos controlados, autorización
- CRIT-001 (criterio operadora) — datos N3+ jamás a proveedor cloud
