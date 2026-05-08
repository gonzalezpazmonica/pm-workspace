# Savia Shield — Inventory (Fase 0 / T2 de SPEC-SH-AUDIT-01)

**Fecha de generación:** 2026-04-30
**Ejecutado por:** Savia (T2 del spec SPEC-SH-AUDIT-01-shield-leak-closure)
**Branch:** projects/Project Aurora
**Estado:** Inventario inicial — base para Fase 1 (vector inventory)

---

## 0. Propósito

Listar exhaustivamente los componentes que forman el sistema de anonimización (Savia Shield) y soberanía cognitiva (Savia Dual / Sovereignty) para que la Fase 1 del spec pueda construir la matriz canónica de vectores de leak.

Este fichero **NO contiene findings ni veredictos**. Es solo el inventario de superficie. La auditoría real empieza en Fase 1.

---

## 1. Scripts ejecutables (`scripts/`)

### 1.1 Núcleo Python (1.667 LOC)

| Fichero | LOC | Rol declarado |
|---|---|---|
| `scripts/savia-shield-proxy.py` | 407 | Layer 0 — proxy HTTP entre Claude Code y Anthropic API. Enmascara request, desenmascara response. Variable `ANTHROPIC_BASE_URL` |
| `scripts/savia-shield-daemon.py` | 364 | Layer 6 — daemon supervisor del proxy y de los demás daemons del shield |
| `scripts/shield-ner-daemon.py` | 184 | Layer 1.5 — daemon que mantiene Presidio + spaCy cargados en memoria para NER fast-path |
| `scripts/shield-ner-scan.py` | 219 | Layer 1.5 — scanner one-shot NER para detectar PII no cubierta por regex |
| ~~`scripts/sovereignty-mask.py`~~ | ~~493~~ | ~~Layer 1 — masker~~ **REMOVED 2026-05-05** |

### 1.2 Núcleo shell (282 LOC)

| Fichero | LOC | Rol |
|---|---|---|
| `scripts/savia-shield-status.sh` | 114 | Reporta estado de las 8 capas — exit codes 0/1/2 |
| ~~`scripts/sovereignty-mask.sh`~~ | ~~91~~ | ~~Wrapper shell del masker~~ **REMOVED 2026-05-05** |
| `scripts/pre-commit-sovereignty.sh` | 77 | Layer 3 — gate pre-commit para evitar leaks en commits |

### 1.3 Otros scripts shield-related

| Fichero | Rol |
|---|---|
| `scripts/savia-shield-setup.sh` | Setup inicial del shield (instala deps, genera certs proxy si HTTPS) |
| `scripts/sovereignty-switch.sh` | Layer 5 — toggle on/off del shield |
| `scripts/sovereignty-benchmark.sh` | Benchmark perf del shield |
| `scripts/sovereignty-ops.sh` | Operaciones admin (limpiar caches, rotar logs) |
| `scripts/sovereignty-pack.sh` | Empaquetado del estado del shield para travel/backup |
| `scripts/masked-digest.sh` | Wrapper para digerir documentos con masker activo |
| `scripts/masked-unmask.sh` | Wrapper para desenmascarar documentos cifrados con masker |
| `scripts/shield-ner-hook.sh` | Hook helper que invoca el NER scanner |
| `scripts/shield-ner-allowlist.txt` | Allowlist de términos que el NER ignora (false-positive prevention) |

### 1.4 Tests existentes

| Fichero | LOC | Cobertura declarada |
|---|---|---|
| `scripts/test-equality-shield.sh` | 92 | Equality shield (regla `equality-shield.md`) |
| `scripts/test-sovereignty-audit.sh` | 91 | Auditoría de soberanía |

**Hallazgo preliminar (sin auditar): NO hay tests específicos para los vectores B-XX (UI transparency) que reporta la PM.** La suite existente parece centrada en el equality shield (tema distinto) y en la auditoría de soberanía (otra cosa). Esto es coherente con el síntoma reportado: si nadie testea el desenmascarado en UI, los leaks Dirección B no se detectan.

---

## 2. Hooks (`.opencode/hooks/`)

| Fichero | Tipo | Rol |
|---|---|---|
| `.opencode/hooks/shield-autostart.sh` | SessionStart | Arranca el shield al inicio de sesión si está habilitado |
| `.opencode/hooks/data-sovereignty-gate.sh` | PreToolUse | Bloquea tool calls que violen política de soberanía |
| `.opencode/hooks/data-sovereignty-audit.sh` | PostToolUse | Audita y loggea ejecuciones |

**Hallazgo preliminar:** los hooks existentes operan a nivel de "soberanía" (qué puede salir del local). NO hay hook explícito que **transforme** el output de tools (Read/Bash/Grep) **antes de mostrarlo al usuario**. El spec SH-AUDIT-01 propone añadir `shield-output-unmask.sh` como PostToolUse — esto es probablemente la pieza que falta.

---

## 3. Skills (`.opencode/skills/`)

| Skill | Rol |
|---|---|
| `.opencode/skills/savia-dual` | Inference sovereignty — fallback transparente (LocalAI vs Anthropic) |
| `.opencode/skills/sovereignty-auditor` | Audit cognitivo — diagnóstico |

**Hallazgo preliminar:** NO existe skill `savia-shield/` aunque hay un comando `/savia-shield`. El comando probablemente delega directamente a los scripts. La auditoría puede crear (Fase 4) una skill canónica que documente reglas RN-01..RN-14.

---

## 4. Slash commands (`.opencode/commands/`)

| Comando | Rol |
|---|---|
| `/savia-shield` | Activar/desactivar/configurar el shield |
| `/savia-dual` | Configurar inference sovereignty |
| `/sovereignty-audit` | Auditoría cognitiva |
| `/confidentiality-check` | Auditoría pre-PR de confidencialidad |
| `/credential-scan` | Escanear historial git por credenciales |

---

## 5. Configuración en `.claude/settings.json`

Hooks registrados (3 referencias):

- `shield-autostart.sh` — SessionStart
- `data-sovereignty-gate.sh` — PreToolUse
- `data-sovereignty-audit.sh` — PostToolUse

**Hallazgo preliminar:** consistente con §2. NO hay PostToolUse para Read/Grep/Bash/etc. que desenmascare output. Esto es probablemente la causa raíz del síntoma reportado por la PM.

---

## 6. Reglas de dominio (`docs/rules/domain/`)

| Fichero | LOC | Tema |
|---|---|---|
| `docs/rules/domain/data-sovereignty.md` | 145 | Política de soberanía de datos |
| `docs/rules/domain/equality-shield.md` | 68 | Equality shield (no relacionado con anonimización) |

**Falta:** una regla canónica sobre transparencia anon ↔ real para conversación vs persistencia. SPEC-SH-AUDIT propone crearla en `docs/rules/domain/shield-vectors.md`.

---

## 7. Glossaries (mapping real ↔ anon)

Localizados via glob `projects/*/GLOSSARY*.md`:

| Path | Proyecto | Estado |
|---|---|---|
| `projects/Project Aurora_main/Project Aurora/GLOSSARY.md` | Project Aurora | Existe (en submódulo) |

**Hallazgo preliminar:** solo 1 glossary localizado en el workspace. El proxy busca patrones `projects/*/GLOSSARY.md`, `projects/*/*/GLOSSARY.md`, y legacy `GLOSSARY-MASK.md`. Si el usuario opera con otros proyectos sensibles sin glossary propio, el shield depende solo de regex + NER — riesgo de falsos negativos altos para esos proyectos.

---

## 8. Audit logs (referenciados en código, no committed)

Según headers de los scripts:

- `proxy-audit.jsonl` — generado por `savia-shield-proxy.py`. Ubicación esperada: `~/.savia/` (gitignored).
- `ner-scan-audit.jsonl` — generado por `shield-ner-scan.py`. Mismo lugar.

**Por verificar en Fase 1:** que la ubicación real sea efectivamente `~/.savia/` y no algún directorio que pudiera leakear.

---

## 9. Comandos en git history últimos 30 días

```
b3b2cc04  feat(shield): deterministic status + retry, daemon hardening, sovereignty tests
cef894fd  fix(shield): plug 3 leak vectors + clean mask-map for Project Aurora
8f4a3c05  feat: batch 61 — OpenCode sovereignty rule + SE-077/SE-078 specs + G12 gate (#705)
```

3 commits en el área shield/sovereignty en el periodo. El más reciente añade tests, status determinista y daemon hardening — tema distinto al leak Dirección B reportado por la PM. El anterior cierra "3 leak vectors" (no documenta cuáles ni si eran A o B).

**Hallazgo preliminar:** la cadena de fixes del shield ha sido reactiva (cerrar vectores cuando se descubren) en lugar de exhaustiva (enumerar todos los vectores y testar uno por uno). Esto es exactamente lo que SPEC-SH-AUDIT-01 propone corregir.

---

## 10. Vectores conocidos pre-auditoría (sin verificar)

Resumido del header de la PM (2026-04-29):

> "a veces el nombre real, a veces el anonimizado, cuando se supone que es un proceso que debería de ser transparente para mi"

Síntoma puro de Dirección B (anon visible en UI cuando debería verse real). NO hay reportes específicos de Dirección A (real-name leak en artefacto persistido). La Fase 1 debe construir tests para AMBAS direcciones — la ausencia de reportes A no significa que no haya leaks A.

---

## 11. Resumen ejecutivo del inventario

| Categoría | Cantidad | LOC aprox. |
|---|---|---|
| Scripts Python núcleo | 5 | 1.667 |
| Scripts shell núcleo | 3 | 282 |
| Scripts shell auxiliares | 9 | (no contados) |
| Hooks `.opencode/hooks/` | 3 | (no contados) |
| Skills | 2 | (savia-dual + sovereignty-auditor) |
| Slash commands | 5 | (definitions) |
| Tests existentes | 2 | 183 (no relacionados con leaks Dirección B) |
| Reglas de dominio | 2 | 213 |
| Glossaries | 1 | (en submódulo Aurora) |

**Total LOC scripts shield/sovereignty:** ~1.949 (núcleo) + auxiliares no contados.

---

## 12. Acciones siguientes (handoff a Fase 1)

1. **Leer en profundidad** los 3 scripts más relevantes para Dirección B:
   - `savia-shield-proxy.py` (Layer 0 — donde debería desenmascarar respuestas)
   - ~~`sovereignty-mask.py`~~ (Layer 1 — **REMOVED 2026-05-05**, L4 Proxy has internal masking)
   - `savia-shield-status.sh` (referencia de las 8 capas)
2. **Mapear flujo**: tool call → hook PreToolUse → tool exec → hook PostToolUse → render UI. Identificar dónde DEBERÍA estar el unmask y verificar si está.
3. ~~**Linter del glossary**: ejecutar `python sovereignty-mask.py --glossary-lint`~~ **OBSOLETE** (sovereignty-mask.py removido)
4. **Capturar sesión real**: 1 hora de uso normal con `proxy-audit.jsonl` verbose. Detectar dónde ocurren los leaks observables.
5. Construir `audit/shield/vectors.md` (Fase 1, T4 del spec) con la tabla canónica.

---

*Generado por Savia siguiendo SPEC-SH-AUDIT-01 §6 Fase 0/T2.*
*Sin findings de auditoría — solo inventario. Los findings vienen en Fase 1 y siguientes.*
