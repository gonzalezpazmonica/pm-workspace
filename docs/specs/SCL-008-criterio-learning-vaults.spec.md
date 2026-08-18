# SCL-008 - Acoplamiento seguro de Criteria, Continuous Learning y SaviaVaults

**Status:** APPROVED -> IMPLEMENTED (2026-08-17)
**Fecha:** 2026-08-17
**Area:** Criterio / Memoria / Epistemología / SaviaVaults / Hooks
**Base:** `origin/pr-971` (SCL-001/002/003/004/006)
**Developer Type:** agent-single
**Estimación:** agente 4h / revisión humana 45min / fallback humano 8h
**Context risk:** medium

---

## 1. Contexto y objetivo

SCL-002 persiste propuestas `INFERRED` en learning y SCL-003 las inyecta
en cada prompt relevante con una instrucción imperativa. Eso contradice el
contrato de SCL-001: `INFERRED` y `proposed` son sombra, sin efecto en gates ni
comportamiento. También deja a `CRITERIO.md` fuera del circuito efectivo.

Esta spec define un límite único de autoridad:

```text
Continuous Learning propone -> SaviaVaults persiste/recupera
                            -> sombra mide coincidencias
CRITERIO.md human_authored  -> autoriza influencia
```

Al finalizar, ninguna propuesta podrá cambiar comportamiento por haber sido
capturada, persistida, federada o recuperada. Solo una entrada activa de
`CRITERIO.md`, escrita por la operadora, podrá aparecer como criterio aplicable.

## 2. Contrato técnico

### 2.1 Autoridad y estados

| Artefacto | Provenance | Lifecycle | Efecto permitido |
|---|---|---|---|
| Learning proposal | `INFERRED` | `proposed` | Persistir, buscar y registrar `shadow_hit`; nunca inyectar texto |
| Learning proposal | cualquiera | `canary` | Ninguno en esta spec; estado rechazado para recall efectivo |
| Learning proposal | cualquiera | `active` | Ninguno por sí sola; requiere `criterion_id` activo verificable |
| Criterio | `human_authored` | implícitamente activo en `CRITERIO.md` | Inyectar como contexto informativo citable |
| Criterio | `INFERRED` | propuesta en `CRITERIO.md` | Sin efecto; no inyectar |

`CRITERIO.md` no recibe escrituras de ningún script de SCL. SaviaVaults es
almacenamiento e índice, no fuente de autoridad. Un `human_trailer` en una
learning proposal no sustituye la existencia de una entrada `CRIT-XXX`
`human_authored` en `CRITERIO.md`.

### 2.2 Interfaz de recall

```bash
bash scripts/learning-recall.sh \
  --query <string-no-vacío> \
  [--top <entero-1..20>] \
  [--min-score <número>=0] \
  [--mode shadow|effective] \
  [--criterio <path>] \
  [--vault <path>] \
  [--json]
```

Defaults: `--top 5`, `--min-score 5`, `--mode shadow`,
`--criterio "$ROOT/CRITERIO.md"`.

Exit codes: `0` operación válida con 0..N hits; `2` input inválido; `3`
dependencia o path ausente. El hook seguirá convirtiendo cualquier error en
passthrough con exit `0`.

### 2.3 Output JSON

```json
{
  "query": "evitar hardcodear credenciales",
  "mode": "effective",
  "effective_hits": [
    {
      "proposal_id": "LP-20260817-a1b2c3d4",
      "criterion_id": "CRIT-034",
      "score": 42.5,
      "principle": "Las credenciales se resuelven desde un vault local."
    }
  ],
  "shadow_hits": 2,
  "rejected_hits": 1
}
```

`principle` se extrae de `CRITERIO.md`, nunca del cuerpo de la propuesta ni del
snippet BM25. El output de texto solo imprime `effective_hits`. `shadow_hits`
y `rejected_hits` son contadores, no contenido para el modelo.

### 2.4 Enlace de trazabilidad

El schema `learning_proposal` añade `criterion_id`, opcional y restringido a
`^CRIT-[0-9]{3}$`. Persistencia y federación conservan ese campo. Una propuesta
es efectiva solo si se cumplen simultáneamente:

1. `target: criterio`.
2. `lifecycle: active`.
3. `provenance: human_authored`.
4. `criterion_id: CRIT-XXX` presente.
5. La entrada `CRIT-XXX` existe en `CRITERIO.md`.
6. Esa entrada contiene exactamente `provenance: human_authored`.

Fallar cualquiera de las seis condiciones clasifica el resultado como sombra o
rechazado y prohíbe inyectar su texto.

### 2.5 Log de recall

Cada consulta añade una línea JSONL con:

```json
{"ts":"ISO-8601","query_hash":"sha256","mode":"shadow","effective_hits":0,"shadow_hits":2,"rejected_hits":0,"proposal_ids":["LP-..."]}
```

El log no guarda el prompt ni el principio completo. `proposal_ids` se ordena y
deduplica. La misma consulta puede registrar otra observación; no crea ni
modifica propuestas.

### 2.6 Contrato del hook dual

Cuando existen criterios efectivos, el hook emite un único objeto JSON:

```json
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<criterios autorizados>"}}
```

Sin criterios efectivos no emite stdout. El parser de entrada acepta tanto el
campo Claude Code `content` como el campo OpenCode `prompt_text`; nunca usa el
payload JSON completo como query. `savia-gates` traduce
`hookSpecificOutput.additionalContext` a `injectedContext`; no existe un segundo
hook ni una reimplementación TypeScript del recall. Para este registro, el
bridge interpreta `timeout: 5000` como milisegundos y aplica un hard cap de
5000 ms; no vuelve a multiplicarlo por 1000.

## 3. Reglas de negocio

| ID | Regla | Resultado ante incumplimiento |
|---|---|---|
| RN-01 | Captura, persistencia, federación y recall nunca escriben `CRITERIO.md` | Test falla y cambio se bloquea |
| RN-02 | `INFERRED` o `proposed` nunca produce `effective_hits` ni stdout para contexto | Se registra solo `shadow_hit` |
| RN-03 | `canary` no influye mientras esta spec no defina autoría humana verificable para el subconjunto | Se registra como rechazado |
| RN-04 | `active` sin criterio `human_authored` enlazado no influye | Se registra como rechazado |
| RN-05 | El texto efectivo procede exclusivamente de la entrada enlazada en `CRITERIO.md` | Se descarta el hit |
| RN-06 | Federación fuerza `INFERRED` + `proposed`, aunque el origen remoto declare otro estado | Importación rechazada o normalizada a sombra |
| RN-07 | Persistencia es idempotente por `id` + `evidence_hash` y conserva `criterion_id` | Exit 1 `ALREADY`, una nota |
| RN-08 | El hook es fail-open operativo y fail-closed de autoridad | Exit 0 sin contexto ante error |
| RN-09 | El log usa hash del query y no almacena texto del prompt | Test de privacidad falla |
| RN-10 | `--mode shadow` nunca emite contexto, incluso para criterios aprobados | Solo telemetría |
| RN-11 | Claude Code y OpenCode consumen el mismo output JSON del hook | Falla test de paridad; no se duplica binding |

## 4. Constraints and limits

- Timeout del hook: máximo 5s; presupuesto interno de recall: 4s.
- Máximo 3 criterios efectivos inyectados por prompt; deduplicados por
  `criterion_id` y ordenados por score descendente.
- El parser acepta solo el formato actual de entradas `CRIT-XXX` de
  `CRITERIO.md`; no introduce YAML parser ni dependencias nuevas.
- No se instala `sentence_transformers`, `hnswlib` ni búsqueda vectorial.
- No se autoedita `CRITERIO.md`, `.claude/CONSTITUCION.md` ni ningún ledger.
- No se confía en frontmatter remoto para elevar provenance o lifecycle.
- El comportamiento debe ser determinista con los mismos vault, criterio,
  query, top y min-score.

## 5. Test scenarios

### TS-01 - Propuesta inferida relevante permanece en sombra

Given una nota BM25 relevante con `INFERRED`, `proposed`, `target: criterio`
When se ejecuta recall `effective`
Then `effective_hits=[]`, `shadow_hits=1` y el hook no emite `additionalContext`.

### TS-02 - Criterio humano enlazado sí se recupera

Given una propuesta `human_authored`, `active`, `criterion_id: CRIT-034`
And `CRIT-034` existe con `provenance: human_authored`
When se ejecuta recall `effective`
Then hay un hit con `criterion_id=CRIT-034`
And su `principle` coincide byte a byte con `CRITERIO.md`.

### TS-03 - Active falso no eleva autoridad

Given una nota `active` sin `criterion_id`, o enlazada a un criterio `INFERRED`
When se ejecuta recall `effective`
Then no hay hit efectivo y `rejected_hits=1`.

### TS-04 - Canary no influye

Given una propuesta `canary` con score superior al umbral
When se ejecuta cualquier modo
Then nunca aparece en `effective_hits` ni stdout contextual.

### TS-05 - Shadow mide sin influir

Given una propuesta aprobada y otra inferida, ambas relevantes
When se ejecuta `--mode shadow`
Then `effective_hits=[]`, `shadow_hits=2` y stdout contextual está vacío.

### TS-06 - Federación hostil queda en sombra

Given una nota remota que declara `human_authored`, `active` y `CRIT-034`
When se importa
Then la copia local queda `INFERRED`, `proposed`, conserva trazabilidad de
origen y no produce hit efectivo.

### TS-07 - Privacidad del log

Given query `credencial-secreta-no-persistir`
When termina recall
Then el JSONL contiene su SHA-256 y no contiene el texto original.

### TS-08 - Dependencia ausente

Given SaviaVaults CLI o `CRITERIO.md` ausente
When corre el hook
Then termina en menos de 5s, exit 0 y sin contexto.

### TS-09 - Idempotencia y trazabilidad

Given una propuesta con `criterion_id: CRIT-034`
When se persiste dos veces y se importa dos veces
Then existe una nota por `id` + `evidence_hash`, ambas segundas llamadas
devuelven `ALREADY`, y el enlace se conserva sin elevar provenance.

### TS-10 - Invariante de archivos fundacionales

Given hashes previos de `CRITERIO.md` y `.claude/CONSTITUCION.md`
When corren captura, persistencia, federación y recall
Then ambos hashes permanecen iguales.

### TS-11 - Paridad del hook dual

Given el mismo prompt y fixtures autorizados
When Claude Code envía `content` y OpenCode envía `prompt_text`
Then ambas ejecuciones consultan exactamente el texto del prompt y producen el
mismo `hookSpecificOutput.additionalContext`
And `savia-gates` lo añade una sola vez a `output.parts`.

## 6. Slices y ficheros

### Slice 1 - Filtro de autoridad y telemetría

Modificar:

- `scripts/learning-recall.sh`: modos, clasificación y log privado.
- `.claude/hooks/learning-recall-hook.sh`: usar `effective`, quitar instrucciones
  derivadas de propuestas, parsear ambos payloads y emitir el JSON canónico.
- `tests/test-scl-003-recall.bats`: sustituir expectativas inseguras y cubrir
  TS-01..05, TS-07 y TS-08.

### Slice 2 - Trazabilidad persistente y federación hostil

Modificar:

- `projects/savia-vaults/schema/entities/learning_proposal.yaml`: añadir
  `criterion_id` y corregir descripción de la cúpula a learning.
- `scripts/learning-proposal.sh`: aceptar `--criterion-id CRIT-XXX` solo con
  `--target criterio`; siempre crea `INFERRED/proposed`.
- `scripts/learning-persist.sh`: conservar `criterion_id`.
- `scripts/learning-federate.sh`: conservar enlace, pero forzar estado sombra.
- `tests/test-scl-002-cupula.bats`: cubrir TS-06 y TS-09.

### Slice 3 - Binding dual, política y regresión E2E

Crear:

- `tests/test-scl-008-criterio-authority.bats`: TS-10 y E2E de autoridad.

Modificar:

- `.claude/settings.json`: corregir el registro roto
  `.opencode/hooks/learning-recall-hook.sh` para apuntar al único hook canónico,
  `.claude/hooks/learning-recall-hook.sh`.
- `tests/structure/test-opencode-savia-gates-plugin.bats`: verificar que
  `chat.message` despacha `UserPromptSubmit`, que el bridge carga el registro
  canónico y que no existe un segundo binding de recall.
- `scripts/opencode-plugin/savia-gates/lib/shell-bridge.ts`: extraer
  `hookSpecificOutput.additionalContext` del JSON canónico sin alterar la
  semántica fail-open y normalizar el timeout en milisegundos con cap de 5s para
  este hook.
- `docs/rules/domain/scl-001-learning-loop.md`: contrato corregido de sombra,
  recall efectivo y autoridad de Criteria.
- `docs/specs/SCL-003-recall-operativo.spec.md`: nota de supersesión parcial por
  SCL-008, sin reescribir sus AC históricos.

### No tocar

- `CRITERIO.md`.
- `.claude/CONSTITUCION.md`.
- `install.sh`, `install.ps1`.
- AI Literacy y EU AI Act.
- SCL-005 y dependencias de embeddings.

## 7. Verification protocol

```bash
bats tests/test-scl-002-cupula.bats
bats tests/test-scl-003-recall.bats
bats tests/test-scl-008-criterio-authority.bats
bats tests/structure/test-opencode-savia-gates-plugin.bats
bash scripts/criterio-validate.sh
bash scripts/hooks-integrity-check.sh
```

Verificación manual obligatoria antes de review:

1. Ejecutar un prompt que coincide solo con una propuesta `INFERRED`: cero
   contexto inyectado y `shadow_hits>=1` en log.
2. Ejecutar un prompt que coincide con una propuesta activa enlazada a un
   criterio humano de fixture: contexto con `CRIT-XXX`, sin texto de proposal.
3. Comparar SHA-256 de `CRITERIO.md` y `.claude/CONSTITUCION.md` antes/después.

## 8. Seguridad y revisión

- Riesgo principal: prompt injection persistente vía propuesta federada.
  Mitigación: nunca inyectar snippet de Vaults; resolver texto desde Criteria.
- Riesgo de elevación: editar frontmatter a `active/human_authored`.
  Mitigación: enlace obligatorio a entrada humana independiente.
- Riesgo de privacidad: guardar prompts completos en `recall.jsonl`.
  Mitigación: `query_hash` únicamente.
- Requiere `security-guardian` y code review humano antes de merge.

## 9. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Recall core | `scripts/learning-recall.sh` | Mismo script PURE_BASH |
| Prompt hook | `.claude/hooks/learning-recall-hook.sh`, registrado en `.claude/settings.json` | El mismo registro, despachado por `scripts/opencode-plugin/savia-gates/index.ts` mediante `chat.message` -> `UserPromptSubmit` |
| Vault/schema | `projects/savia-vaults/` | Mismos artefactos y CLI |

### Verification protocol

- [ ] Runtime Claude Code inyecta solo criterios autorizados.
- [ ] Runtime OpenCode inyecta el mismo conjunto de IDs para el mismo fixture.
- [ ] Tests cubren ambos payloads, el JSON canónico y fail-open por timeout.
- [ ] Existe un solo registro de recall y OpenCode lo consume mediante el bridge
  existente de `savia-gates`.

### Portability classification

- [x] **DUAL_BINDING**: core y hook PURE_BASH; Claude Code lo ejecuta desde
  `UserPromptSubmit` y OpenCode desde el bridge `chat.message` existente. No se
  considera completada sin verificar ambos frontends.

## 10. Out of scope

- Escribir, reescribir, aprobar o asignar IDs dentro de `CRITERIO.md`.
- Convertir learning proposals en gates bloqueantes.
- Definir protocolo de canary humano; hasta entonces canary no influye.
- Federación A2A remota (SCL-007).
- Embeddings híbridos (SCL-005 bloqueada).
- AI Literacy, inventario EU AI Act e instaladores integrales: requieren specs
  independientes por tener contratos regulatorios y superficies de fallo propias.

## 11. Approval

Aprobación humana explícita recibida el 2026-08-17: `I approve SCL-008.`

## Referencias

- `CRITERIO.md` y `.claude/CONSTITUCION.md` ART-03/08/10/11/15.
- `docs/specs/SCL-001-aprendizaje-continuo.spec.md`.
- `docs/specs/SCL-002-cupula-aprendizaje.spec.md`.
- `docs/specs/SCL-003-recall-operativo.spec.md`.
- `docs/rules/domain/scl-001-learning-loop.md`.
- `scripts/learning-{proposal,persist,federate,recall,lifecycle}.sh`.
