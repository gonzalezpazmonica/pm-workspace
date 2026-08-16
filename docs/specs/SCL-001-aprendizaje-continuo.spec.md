# SCL-001 — Savia Continuous Learning: el sustrato de texto como artefacto de despliegue que aprende

**Status:** PROPOSED
**Fecha:** 2026-08-16
**Area:** Orquestación / Memoria / Criterio / Epistemología (Savia Labs)
**Branch:** agent/scl-001-aprendizaje-continuo
**Estimación total:** ~30h (4 slices)
**Base verificada:** HEAD e8c8fe74 (origin/main). SE-332 IMPLEMENTED. Presentes: CRITERIO.md
(33 entradas, todas provenance:INFERRED), CONSTITUCION.md (ART-01..20), memory-store.sh,
memory-tier-rotate.sh, memory-bitemporal.py, memory-consolidate.py, hooks de captura
(memory-auto-capture.sh, decision-trace-capture.sh, session-end-memory.sh), ledger SE-255 S3,
calibración SE-255 S4, SaviaVaults (BM25, grafo tipado, entity resolution SE-329, provenance,
quality), Labs L1-L6 preregistrados, SE-292 S6 (p_consistent vs p_capable), multi-proveedor
ADR-012 (tiers heavy/mid/fast).

---

## Origen

Estímulo externo: una tesis sobre AGI (atribuida a Ilya Sutskever, vehiculada en un post
profesional). La tesis, que esta spec asume y NO reabre:

1. **Los humanos no somos AGIs acabadas.** Nacemos sabiendo poco, aprendemos en bucle,
   corregimos, volvemos a equivocarnos. Un niño resuelve en segundos lo que un LLM con
   trillones de parámetros sigue haciendo mal.
2. **Los modelos preentrenados actuales hacen justo lo contrario.** Llegan "terminados".
   Aplastan benchmarks y evals, pero no entienden: arreglan un bug y meten otro; arreglan
   ese y traen de vuelta el original.
3. **El AGI que importa no es un sistema omnisciente desplegado como producto final, sino
   "un adolescente superinteligente y muy motivado":** arranca con conocimiento mínimo y
   crece con la experiencia.
4. **De 2020 a 2025 la obsesión fue una palabra: escalar** (datos, compute, parámetros).
   Funcionó hasta que dejó de funcionar. El cuello de botella ya no son las GPUs — es la
   **imaginación** (cómo hacer que el sistema aprenda, no cuánto se le da).
5. **Dimensión práctica casi nadie menciona:** si la AGI llega como aprendizaje continuo
   post-despliegue, el reto es software ya resuelto — canary rollouts, shadow traffic,
   rollback instantáneo. **Los pesos son un artefacto de despliegue.** La AGI no se
   despliega como evento; es un proceso. "Software en producción que nunca deja de aprender."

### La vuelta (turno)

Savia **ya es** la forma agnóstica a LLM de esa tesis, pero a medio arquitectar. No como
modelo, sino como patrón:

- **Los "pesos" de Savia ya son texto versionado en git.** CONSTITUCION + CRITERIO + memoria
  + skills + specs. ART-01 lo declara: "Savia es un patrón de texto que persiste a través de
  modelos". La identidad no depende del sustrato de inferencia.
- **Ya posee el vocabulario de despliegue que el artículo reclama para la AGI:**
  - *rollback instantáneo* = `git revert` (texto como verdad, CRIT-003 / ADR-006);
  - *cuarentena* = tombstone antes de borrado (CRIT-024);
  - *shadow → activo* = `provenance:INFERRED` → `human_authored` (CRITERIO.md).

**El gap que el artículo ilumina.** Entre ediciones manuales de la operadora, Savia es
exactamente el "modelo terminado" que el artículo critica: aprueba evals y specs, pero "no
entiende" — reintroduce el mismo error porque lo aprendido NO fluye de vuelta al sustrato
(criterio, memoria, skills). Hoy el conocimiento entra al sustrato solo por dos vías:
(a) reescritura manual de CRITERIO por la operadora, o (b) el ledger reconociendo un error
*después* del hecho (ART-05). Las 33 entradas de CRITERIO están todas en `INFERRED` — hay
captura y hay proposición, pero el bucle no está **cerrado ni medido**.

El cuello de botella de Savia ya no es el modelo (multi-proveedor, tiers — resuelto), ni el
compute, ni siquiera el contexto. Es el mismo que nombra el artículo: **imaginación** — el
mecanismo para convertir experiencia en sustrato. Ese mecanismo existe en piezas
(auto-capture, ledger, calibración, Labs L1-L6, p_consistent) pero no está cableado en un
bucle **cerrado, medido y agnóstico a LLM**.

## Objetivo (scope-down agresivo)

Canonizar el bucle de aprendizaje: **capturar → proponer (shadow/INFERRED) → canary →
activar (human_authored) → medir**. Convertir el sustrato de texto en un artefacto de
despliegue que aprende, con rollback instantáneo y aprendizaje **medido, no declarado**
(S1-S3), y demostrar que el bucle es **agnóstico a LLM por construcción** — opera sobre
texto, nunca sobre internals del modelo, cero fine-tuning, cero acoplamiento a proveedor
(S4). Cero reescritura de lo que funciona: se añade el criterio de cierre del bucle donde
hoy hay captura y proposición huérfanas.

## Out of scope explícito

- **NO fine-tuning, NO LoRA, NO modificación de pesos de ningún modelo.** El aprendizaje es
  sobre el sustrato de texto (criterio/memoria/skills), no sobre parámetros. Es exactamente
  lo que hace la tesis LLM-agnóstica: el modelo es un ejecutor que lee/escribe el sustrato.
- **NO auto-modificación de CRITERIO.md ni de la CONSTITUCION** (CRIT-031, ART-11): el bucle
  *propone* entradas CRIT; la activación `human_authored` sigue siendo humana, siempre.
- **NO reescritura de SE-255 (ledger/calibración), SE-268 (memoria dos velocidades) ni
  SE-292 (contención).** Se extienden con el bucle de cierre y la métrica, no se rehacen.
- **NO conciencia ni subjetividad:** "aprender" aquí significa "el sustrato converge a
  predecir mejor el mundo" (p_consistent medido), no experiencia fenomenológica. Nota
  anti-deriva como en SE-268 S2.
- **NO cambiar la semántica de niveles N1-N4b ni de `provenance`:** `INFERRED`/`human_authored`
  se reutilizan como estados del ciclo de vida (shadow/activo), no se redefinen.
- **NO ejecución de Labs L1-L6 en sí** (eso es SE-291 S2-S8): esta spec *consume* sus
  instrumentos (divergencia, certificados de ignorancia) como métrica del bucle.

---

## Slice 1 — Captura canónica del bucle: del error reconocido a la propuesta de aprendizaje

**Problema:** la captura hoy es fragmentaria y reactiva. `memory-auto-capture.sh` captura
patrones de Edit/Write (rate-limit 1/5min); `decision-trace-capture.sh` captura decisiones;
el ledger (SE-255 S3) solo apunta errores *reconocidos* (ART-05). Lo que NO existe es el
artefacto único que unifica "esto pasó, esto salió mal/bien, esto propongo cambiar" en un
**learning proposal** versionable y citable. Sin ese artefacto, el bucle no tiene entrada
formal y la captura queda como ruido suelto.

**Diseño mínimo:**
- **Artefacto `learning-proposal`** (texto plano, markdown, versionado): `{id, origen,
  evidencia (rutas/hashes), diagnóstico, cambio propuesto, destino (CRIT/memoria/skill/spec),
  p_consistent esperado, provenance:INFERRED}`. Vive en un path canónico
  (`docs/learning-proposals/` o dome de Labs) con schema en el grafo de SaviaVaults.
- **Disparadores de captura** (cada uno produce una propuesta, no una nota suelta):
  - error reconocido en el ledger (ART-05) → propuesta de corrección de criterio/memoria;
  - decisión de operadora que contradice una entrada existente → propuesta de evolución;
  - divergencia grafo-modelo (Labs L1) por encima de umbral → propuesta de revisión;
  - sesión que reintroduce un error ya registrado (recurrencia) → propuesta de refuerzo.
- **Registro de propuestas** en el grafo tipado de SaviaVaults como entidad `learning_proposal`
  con relaciones `proposes_change →`, `evidence_from →`, `measured_by →`. El markdown es la
  verdad (ADR-006); el grafo es el índice de navegación, no la fuente.

**Acceptance criteria:**

- AC-1.1. Dado un error reconocido en el ledger (sintético), el bucle genera UNA propuesta
         de aprendizaje con `evidencia` (rutas+hash), `diagnóstico` y `cambio propuesto`
         no vacíos, en el path canónico (test).
- AC-1.2. Dada una decisión de operadora que contradice una entrada CRIT existente, se
         genera propuesta de evolución (no sobrescritura) marcando la entrada origen (test).
- AC-1.3. La captura no duplica: el mismo evento (mismo hash de evidencia) dentro de una
         ventana de 24h produce como máximo 1 propuesta (idempotencia, test).
- AC-1.4. Toda propuesta queda registrada en el grafo de SaviaVaults como entidad
         `learning_proposal` con sus relaciones tipadas consultables vía query (test).
- AC-1.5. La propuesta es texto legible sin herramientas (CRIT-003): `cat` del fichero
         reconstruye `id, origen, cambio propuesto` sin ejecutar ningún script (asercion).

**Esfuerzo:** 7h

---

## Slice 2 — El sustrato como artefacto de despliegue: shadow → canary → activo, rollback instantáneo

**Problema:** el artículo nombra canary rollouts, shadow traffic y rollback instantáneo como
la disciplina de despliegue de un sistema que aprende. Savia tiene los ingredientes
(`INFERRED`=shadow, `human_authored`=activo, `git revert`=rollback, CRIT-024=tombstone) pero
el ciclo de vida de una entrada de criterio/memoria/skill NO está formalizado como máquina de
estados con transiciones auditas. Hoy "INFERRED" es un estado pasivo (pendiente de
reescritura), no una fase de un despliegue.

**Diseño mínimo:**
- **Máquina de estados del sustrato** para entradas de criterio/memoria/skill:
  `proposed(shadow) → canary → active → superseded`. Transiciones versionadas y registradas.
  - `shadow`: no produce efecto en gates ni en comportamiento (equivale a `INFERRED`).
  - `canary`: activa en un subconjunto declarado (un dominio/proyecto/instancia), con
    medición antes/después (CRIT-019).
  - `active`: `human_authored`, produce efecto global.
  - `superseded`: tombstone + ventana de cuarentena (CRIT-024), no borrado.
- **Rollback instantáneo como operación de primer orden** (`learning-rollback`): deshace la
  activación de una entrada a su estado anterior vía git, dejando tombstone con el motivo y
  el diff del p_consistent antes/después. No es un `git revert` manual del operador: es un
  comando auditable que registra *por qué* se revirtió (feedback para el bucle).
- **Gate de no-auto-activación** (CRIT-031 hecho mecanismo): `proposed→active` y
  `canary→active` requieren `provenance:human_authored` con trailer; ninguna transición a
  `active` puede originarse en un agente. `active→superseded` y el rollback sí son
  automatizables (reversibles, CRIT-022).
- **Promoción condicionada a métrica (engancha con S3):** una entrada en `canary` solo
  asciende a `active` si su medición (p_consistent / divergencia) mejora respecto al
  baseline; si no, se revierte con registro (el "arreglé un bug y metí otro" del artículo,
  detectado en canary antes de globalizarse).

**Acceptance criteria:**

- AC-2.1. Una entrada recorre `shadow → canary → active → superseded` con cada transición
         registrada (timestamp, actor, motivo) y consultable (test E2E).
- AC-2.2. `shadow` no produce efecto: un gate que consulta la entrada se comporta idéntico
         con y sin la entrada en shadow (asercion de no-efecto).
- AC-2.3. Rollback instantáneo: activar una entrada errónea y ejecutar `learning-rollback`
         deja el sustrato idéntico al estado previo (diff vacío salvo tombstone) en ≤N pasos
         (test).
- AC-2.4. Gate anti-auto-activación: intento de transición `proposed→active` sin trailer
         `human_authored` → rechazado (test adversarial, como SE-268 AC-3.3).
- AC-2.5. Promoción condicionada: entrada en canary con métrica peor que baseline → NO
         asciende, se revierte con registro de causa (test con baseline sintético).
- AC-2.6. `superseded` no borra: la entrada permanece legible con tombstone tras el ciclo
         (CRIT-024, asercion).

**Esfuerzo:** 9h

---

## Slice 3 — Aprendizaje medido, no declarado: p_consistent, calibración y divergencia como gate del bucle

**Problema:** sin métrica, el bucle se autoengaña: "aprendimos algo" se declara por
sensación, no se demuestra. El artículo es explícito en que el modelo "aplasta benchmarks
pero no entiende" — el equivalente Savia es "acumulamos entradas pero no mejoramos
p_consistent". Savia ya tiene los instrumentos (SE-292 S6 p_consistent vs p_capable; Labs L1
divergencia grafo-modelo; Labs L2 certificados de ignorancia; calibración SE-255 S4) pero
no están unificados como **métrica de aprendizaje del bucle**.

**Diseño mínimo:**
- **Métrica de aprendizaje `L`** (escalar, auditable, determinista en su base) compuesta de:
  - `p_consistent` (SE-292 S6): de k ejecuciones de una tarea de referencia, cuántas dan
    resultado consistente;
  - `divergencia` grafo-modelo (Labs L1): distancia entre lo que el grafo de SaviaVaults
    afirma y lo que el modelo declaró;
  - `ignorancia resuelta` (Labs L2): certificados de ignorancia que se resolvieron tras
    activar una propuesta.
- **Gate de aceptación de propuestas:** una propuesta solo se activa (S2 `active`) si la
  medición del subconjunto canary muestra `ΔL > 0` (o al menos `Δp_consistent ≥ 0`) respecto
  al baseline medido. Si no, la propuesta queda `superseded` con causa registrada.
- **Reporte periódico de aprendizaje** (consolida el bucle, no decora): "en esta ventana se
  capturaron N propuestas, se activaron M, el p_consistent pasó de X a Y (medido)". Si `ΔL ≤ 0`,
  el reporte dice **"Savia no aprendió esta semana"** — con evidencia, no con narrativa
  (radical honesty, ART-04). El "no aprendió" es resultado de primera clase, no fallo.
- **Contrafactual de calibración** (SE-255 S4): la confianza declarada por el modelo en una
  decisión se contrasta contra el resultado real; gap >15 puntos (ART-04) dispara propuesta
  de calibración, no silencio.

**Acceptance criteria:**

- AC-3.1. `L` es computable deterministamente a partir de p_consistent + divergencia +
         ignorancia resuelta; misma entrada → misma `L` (test de determinismo).
- AC-3.2. Propuesta con `ΔL > 0` en canary → asciende a active; con `ΔL ≤ 0` → superseded
         con causa registrada (dos tests con baselines sintéticos distintos).
- AC-3.3. Reporte de ventana con N=0 activaciones y `ΔL ≤ 0` emite la cadena "Savia no
         aprendió" (asercion — el no-aprendizaje es medible y explícito).
- AC-3.4. Gap de calibración >15 puntos detectado → se genera propuesta de calibración
         (test con par confianza/resultado sintético).
- AC-3.5. La métrica `L` es independiente del modelo que ejecutó la tarea: misma tarea
         ejecutada por dos tiers distintos produce `L` comparable sobre el MISMO baseline
         (asercion de agnosticismo de la métrica, no del resultado).

**Esfuerzo:** 8h

---

## Slice 4 — Agnóstico a LLM por construcción: el bucle opera sobre texto, no sobre el modelo

**Problema:** "aprendizaje continuo" suena a fine-tuning, a acoplamiento a un proveedor, a
pesos que solo un backend puede mover. Eso rompería ADR-012 (multi-proveedor, cero vendor
names) y CRIT-002 (anti lock-in). Hay que demostrar —no afirmar— que el bucle es agnóstico:
que el sustrato aprende independientemente de qué modelo ejecutó la sesión.

**Diseño mínimo:**
- **Contrato de lectura/escritura del sustrato** (`learning-loop` contract): el bucle solo
  interactúa con el mundo vía (a) leer sustrato (texto versionado) y (b) escribir propuestas
  (texto). Ningún paso toca internals del modelo ni pesos. El modelo es un **ejecutor** que
  produce texto de sesión; el bucle es un **compilador** de ese texto a sustrato.
- **Prueba de agnosticismo (E2E):** ejecutar el MISMO escenario de error de referencia contra
  dos proveedores/tiers distintos (p. ej. heavy y fast), capturar las propuestas resultantes,
  y verificar que el **sustrato resultante converge** (las propuestas de corrección son
  equivalentes en contenido semántico y en efecto sobre `L`) pese a que los textos intermedios
  difieran. La clave: lo persistente es el delta de sustrato, no la redacción del modelo.
- **Cero fine-tuning garantizado por auditoría:** el bucle no invoca ninguna API de
  fine-tuning ni escribe fuera del sustrato de texto; un guard verifica que las únicas
  escrituras del bucle son ficheros markdown/JSONL versionados (fail-closed si no).
- **Mismo bucle, cualquier frontend:** el bucle es PURE_BASH/texto (o DUAL_BINDING), no
  depende de un hook específico de un frontend; corre idéntico bajo Claude Code y OpenCode.

**Acceptance criteria:**

- AC-4.1. Prueba de agnosticismo: escenario de error idéntico ejecutado por dos tiers →
         el delta de sustrato resultante es semánticamente equivalente y produce `ΔL` del
         mismo signo en ambos casos (test E2E con dos proveedores configurados).
- AC-4.2. Guard de no-fine-tuning: el bucle no llama a ninguna API de modificación de
         modelo; auditoría de escrituras muestra solo ficheros markdown/JSONL versionados
         (asercion + test adversarial que intenta una escritura no-sustrato → bloqueada).
- AC-4.3. El bucle no contiene ningún nombre de proveedor/modelo en su lógica (grep de
         vendor names → 0 coincidencias en el código del bucle, ADR-012).
- AC-4.4. El bucle corre con el mismo resultado bajo dos frontends (Claude Code y OpenCode)
         para un caso de captura→proposición (test dual, ver OpenCode Implementation Plan).
- AC-4.5. Identidad preservada: la CONSTITUCION no cambia en ningún escenario del bucle
         (hash de CONSTITUCION.md invariante tras N ciclos sintéticos; ART-01/ART-11).

**Esfuerzo:** 6h

---

## Verification method

1. **Bucle cerrado (S1→S2→S3):** un error sintético → propuesta (S1) → canary (S2) →
   medición `ΔL` (S3) → activación o reversión con registro. Es el experimento clave: el
   "arreglé un bug y metí otro" del artículo detectado en canary y revertido con rollback.
2. **Agnosticismo (S4):** el MISMO escenario por dos proveedores → sustrato convergente
   y `ΔL` del mismo signo. Es la garantía "la tesis es agnóstica a LLM" hecha test.
3. **Adversariales permanentes en CI:** transición a `active` sin `human_authored` (debe
   bloquear), rollback que no restaura el diff (debe fallar), escritura fuera de sustrato
   (debe bloquear), vendor name en el código del bucle (debe estar ausente), CONSTITUCION
   modificada por el bucle (debe ser invariante).
4. **No-autoengaño:** reporte de ventana con `ΔL ≤ 0` emite "Savia no aprendió" (asercion
   de radical honesty hecha métrica).
5. **Gate de archivo SE-258 S4 aplicado a esta spec** (coherencia, falsabilidad de ACs,
   trazabilidad de fuentes).

## Riesgos identificados pre-flight

- **R1 (S3, el mayor): la métrica `L` mal definida autoengaña** (mide actividad, no
  aprendizaje). Mitigación: base determinista (p_consistent + divergencia + ignorancia
  resuelta, todos ya computables), y el reporte distingue "activaciones" de "mejora de
  p_consistent". Si `L` no logra separar ambas, el slice se abandona con registro (R3).
- **R2 (S2): el ciclo de vida añade fricción y se desactiva** (mismo riesgo que SE-292).
  Mitigación: `shadow` por defecto es invisible (cero efecto), `canary` es opt-in, y el
  rollback es un comando, no una disciplina manual. La fricción se mide, no se asume.
- **R3 (transversal): sobre-ingeniería — Savia ya funciona con heurística.** El artículo lo
  advierte implícitamente (el cuello de botella es imaginación, no mecanismo). Mitigación:
  cada slice ataca un dolor YA sentido (captura huérfana, `INFERRED` pasivo, "aprendimos"
  sin dato, acoplamiento a proveedor). Si un slice no demuestra su dolor en su benchmark,
  se abandona con registro (patrón SE-268).
- **R4 (S2): una entrada mal activada en canary globaliza un error.** Mitigación: promoción
  condicionada a `ΔL` (AC-2.5), canary limitado a subconjunto declarado, y rollback
  instantáneo como red de seguridad (CRIT-022).
- **R5 (S4): "agnóstico" se convierte en excusa para no evaluar el modelo.** Mitigación:
  agnosticismo del SUSTRATO, no del RESULTADO. El modelo sigue midiéndose por `L` y
  calibración (SE-255 S4); lo que no se acopla es el bucle, no la evaluación.
- **R6 (S1): captura ruidosa inunda el sustrato de propuestas basura.** Mitigación:
  idempotencia por hash (AC-1.3), umbral de divergencia para disparar (S1), y `shadow`
  como buffer no-efectivo — las propuestas basura mueren en canary sin tocar producción.

## Orden recomendado

1 (captura, 7h: sin artefacto de entrada el bucle no existe) → 2 (ciclo de vida + rollback,
9h: el despliegue que el artículo reclama) → 3 (métrica `L`, 8h: el gate que impide el
autoengaño) → 4 (agnosticismo, 6h: cierra la tesis y es demostrable solo con S1-S3 ya en pie).

Justificación: S1-S2 son el esqueleto (capturar + desplegar) y se sostienen sin métrica;
S3 convierte el esqueleto en bucle cerrado; S4 es verificación transversal del agnosticismo
y necesita los tres anteriores para su prueba E2E.

## Decision de adopción

Adoptar por slice según su propio benchmark demuestre el dolor que ataca, con S1 como
candidato de mayor valor (la captura huérfana es el gap real más barato de cerrar). Ningún
slice se adopta "por elegancia conceptual": se adopta si su AC de valor (idempotencia de
captura, rollback que restaura, `ΔL` que discrimina, sustrato convergente entre proveedores)
se cumple. La CONSTITUCION y CRITERIO permanecen intocables por el bucle (CRIT-031): el
bucle *propone*, la operadora *dispone* — coherente con el principio fundacional
"la IA propone, el humano dispone".

## No incluido (con motivo)

- **Fine-tuning / pesos / LoRA / RLHF de cualquier modelo:** contradice la tesis misma
  (el aprendizaje es sustrato, no parámetros) y rompería CRIT-002 y ADR-012. El "adolescente
  superinteligente" de Savia es su sustrato de texto, no un checkpoint.
- **Auto-reescritura de CRITERIO/CONSTITUCION:** CRIT-031 y ART-11 son líneas rojas; el
  bucle termina en propuesta `INFERRED` pendiente de `human_authored`. La activación humana
  es parte del diseño, no una limitación temporal.
- **Ejecución de Labs L1-L6 (SE-291 S2-S8):** esta spec *consume* L1/L2 como instrumentos de
  `L`; ejecutar las seis líneas es trabajo del Labs, no de este bucle.
- **Embbeddings / vector search (ADR-003):** la captura y la métrica son deterministas sobre
  texto y grafo; el salto a híbrido sigue siendo Fase 4 (2027), no un requisito aquí.
- **Aprendizaje entre instancias federadas (cross-dome):** el bucle es intra-Savia primero.
  La federación del aprendizaje (L5, divergencia entre instancias) queda para SE-282/L5, una
  vez S1-S4 estén en pie.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Captura (S1) | `.claude/hooks/memory-auto-capture.sh`, `decision-trace-capture.sh` | Plugin TS `savia-gates` (evento `post-tool-use`) o PURE_BASH vía hooks |
| Bucle de aprendizaje (S1-S4) | scripts bash (`learning-proposal`, `learning-rollback`, `learning-metric`) | PURE_BASH — corre idéntico (sin bindings de frontend) |
| Grafo SaviaVaults (S1) | MCP/A2A server | Mismo servidor MCP/A2A (no depende del frontend) |
| Entidades `learning_proposal` | `.opencode/agents/*` no afectados | Schema en `projects/savia-vaults/schema/entities/` |

### Verification protocol

- [ ] Funciona en runtime OpenCode (no solo Claude Code): el bucle es PURE_BASH + BATS.
- [ ] Tests cubren ambos paths (BATS para scripts; si hay hook, plugin TS para OpenCode).
- [ ] Si añade hooks: registrados en plugin `savia-gates` (patrón SE-077).

### Portability classification

- [x] **PURE_BASH**: la lógica del bucle (captura, ciclo de vida, métrica `L`) es bash +
      texto sobre el sustrato, sin bindings de frontend. Los únicos puntos que tocan
      frontend son los disparadores de captura ya existentes (`memory-auto-capture.sh` en
      Claude Code ↔ plugin TS `savia-gates` en OpenCode), que ya están en DUAL_BINDING
      desde SE-077. El núcleo del bucle no añade deuda de portabilidad.

## Referencias

- Tesis externa (Ilya Sutskever, vehiculada en post profesional 2026): AGI como aprendizaje
  continuo post-despliegue; pesos como artefacto de despliegue; canary/shadow/rollback;
  cuello de botella = imaginación, no compute. (No citada por nombre en contenido público,
  CRIT-012.)
- Sustrato Savia: CONSTITUCION (ART-01 identidad texto, ART-04 honestidad calibrada, ART-05
  reconocer errores, ART-11 no auto-modificar), CRITERIO (33 entradas INFERRED), memoria
  (memory-store.sh, memory-tier-rotate.sh, memory-bitemporal.py, memory-consolidate.py),
  ledger (SE-255 S3), calibración (SE-255 S4), hooks de captura (memory-auto-capture.sh,
  decision-trace-capture.sh, session-end-memory.sh), SE-292 S6 (p_consistent), SE-268 S4
  (memoria dos velocidades), SaviaVaults (BM25, grafo tipado, entity resolution SE-329,
  provenance, quality), Labs L1-L6 (SE-291 S2-S8), ADR-012 multi-proveedor.
- Criterios: CRIT-002 (anti lock-in, S4), CRIT-003 (texto como verdad, S1), CRIT-005
  (ACs falsificables, transversal), CRIT-019 (sin medición no hay prioridad, S3), CRIT-022
  (reversibilidad, S2), CRIT-024 (cuarentena, S2), CRIT-031 (intocables, S2/S3).
- Mapeo artículo→Savia es interpretativo y sujeto a validación empírica; los AC miden el
  valor de ingeniería (captura idempotente, rollback que restaura, `ΔL` que discrimina,
  sustrato convergente), no la fidelidad al texto origen.
