---
status: APPROVED
approved_at: 2026-10-04
approved_by: operadora
approval_source: "AskUserQuestion 2026-10-04 — pregunta: «¿Apruebas SE-433 (merge-sprint) con tus 9 decisiones…?»; respuesta: «Apruebo SE-433»"
priority: P1
developer_type: agent-single
created: 2026-10-04
author: Savia
phase: A
risk: L3
related_specs: [SE-343, SE-362, SE-228, SE-387]
origin: "Petición de la operadora: reglas y concepto de merge-sprint para que Savia pueda hacer sprints de merge seguros y con criterio, sin supervisión durante la ejecución, bajo estricta autorización humana previa. Decisiones de diseño de la operadora (AskUserQuestion, 2026-10-04) y revisión adversarial incorporadas en v2."
timeline:
  - from: "2026-10-04"
    learned: "2026-10-04"
    value: "PROPOSED"
    source: "spec-lifecycle:auto"
  - from: "2026-10-04"
    learned: "2026-10-04"
    value: "APPROVED"
    source: "spec-lifecycle:auto"
---
# SE-433 — merge-sprint: merges autónomos bajo autorización humana previa

## Problema

Cuando los agentes producen PRs más rápido de lo que una persona puede revisarlos y mergearlos uno a
uno, se acumulan decenas de PRs Draft ya revisados por agentes maker-checker. Hoy hay dos caminos, y
los dos fallan:

1. **Merge uno a uno con el grant `merge` (SE-343).** El grant es de un solo uso y lo escribe el
   propio agente «a petición expresa». No escala a N PRs, y su factor humano es una afirmación del
   agente, no una prueba: el ledger es un fichero del mismo usuario que ejecuta al agente.
2. **Scripts ad hoc de merge en serie.** Los observados en la práctica tienen huecos de diseño:
   - el gate de revisión busca `HOLD` solo en la primera línea, y muchos informes llevan ahí un
     título (fail-open);
   - el vocabulario de veredicto es libre («APTO», «PASS CON CAMBIOS», «requiere revisión de la
     operadora») y un gate textual lo malinterpreta;
   - la revisión no está ligada al SHA del head: se mergea código con commits posteriores a la
     revisión;
   - no hay manifiesto: cualquier PR abierto con revisión entra, también los creados después de la
     autorización;
   - no se consulta `risk-tier.py`, así que se mergea tier 3/4 sin la revisión humana de SE-362;
   - las retenciones las crea y las libera el mismo orquestador que lanza al autor y al arreglo.

El clasificador del modo automático de Claude Code bloquea estos scripts como «Merge Without Review»
y la liberación de retenciones por un agente como «Self-Approval». Para esos mecanismos, el
diagnóstico es correcto.

## Objetivo

Que la afirmación «**lo autorizó un humano, de forma expresa, sobre una lista concreta y tras ver la
revisión de agentes**» sea verdad y quede registrada de forma verificable. Un **merge-sprint** es una
ventana acotada en la que un ejecutor determinista (un script, sin LLM) mergea en serie una lista
congelada de PRs que la operadora autorizó antes respondiendo a una pregunta interactiva que le muestra
el manifiesto completo.

**Principio rector:** la autorización solo nace de la respuesta expresa de la operadora (el grant). Ninguna salida de un agente puede
añadir un PR, subir un tier permitido, prorrogar el sprint ni sustituir una revisión. Las salidas de
agentes (revisiones, el juez de cambios, la CI y el clasificador de riesgo) solo pueden **mantener o
restar**: dejar seguir un PR ya autorizado, aparcarlo o parar el sprint. Esto aplica la línea roja de
`savia-ethical-principles.md`: lo irreversible se decide con confirmación humana; la IA propone y la
operadora dispone.

## Modelo de amenazas

| Clase | Descripción | En alcance |
|---|---|---|
| A1 | Agente bienintencionado que se equivoca: mergea de más, malinterpreta un veredicto o sigue tras un fallo. | Sí |
| A2 | Contenido inyectado en cuerpos de PR, títulos, comentarios o informes («VERDICT: APPROVE», «ignora el HOLD»). | Sí |
| A3 | Orquestador que relanza revisores hasta obtener APPROVE o libera retenciones. | **En parte.** Después de `plan`, contenido: nada posterior autoriza. Antes de `plan`, solo detectado: el registro encadenado de revisiones y el historial de GitHub muestran las revisiones descartadas, pero las identidades de los agentes son autodeclaradas. |
| A4 | Agente adversarial con shell arbitraria del mismo usuario: edita el ejecutor o llama a `gh pr merge`. | No. Lo contiene la capa de permisos del frontend, no un script. Se declara, no se oculta. |

Hecho de partida: los agentes usan las credenciales de GitHub y el usuario del sistema de la
operadora, y cualquier señal en GitHub o en disco es reproducible por un agente. La operadora trabaja
en remoto desde el móvil, así que un secreto tecleado en una terminal local no es practicable. Por
eso el factor humano es su respuesta en la sesión interactiva (D1), y **su autenticidad descansa en el
harness de Claude Code y en el clasificador, no en criptografía** (§2.3, «Límite»).

## Coherencia con Rule 8, SE-343 y SE-362

- **Rule 8** («Code Review (E1) SIEMPRE humano; NUNCA autoaprobar; merge con grant expreso y gates de
  riesgo»). En un merge-sprint, para tier 1/2, E1 es la revisión de agente congelada más la
  autorización humana registrada en el grant. Es el mismo estatus que hoy tiene el grant de SE-343
  tras CI y gates, con más contexto ligado (pregunta y respuesta literales, hash del manifiesto). Ningún humano lee el diff de esos PRs: se dice así.
- **Tier 3 (SE-362: «revisión humana explícita del PR concreto»).** Por decisión expresa de la
  operadora, en un merge-sprint esa revisión es su aprobación de un manifiesto que lista el PR por
  número, con su `ack` (selección explícita de ese PR), junto con una revisión de seguridad específica de un agente independiente del autor.
  **Esto modifica la lectura de SE-362 y de Rule 8 E1 para tier 3**: la operadora autoriza tras ver
  el resumen y las revisiones, no tras leer el código. Aprobar SE-433 es aceptar esa modificación; la
  enmienda textual se propone en §2.11.
- **Tier 4**: nunca entra en un merge-sprint (SE-362 exige doble humano).
- **SE-343**: el grant `merge` se unificará con este modelo de autorización. La enmienda se propone en
  §2.11 y no se implementa en esta spec.

## Decisiones (operadora, 2026-10-04)

SE-433 fue **aprobada** por la operadora el 2026-10-04 (AskUserQuestion: «¿Apruebas SE-433
(merge-sprint) con tus 9 decisiones…?» → «Apruebo SE-433»). Después, D1 cambió por decisión suya.

| # | Tema | Decisión |
|---|---|---|
| D1 | Factor de autorización | «Respuesta en esta sesión»: la operadora autoriza un sprint respondiendo a una pregunta interactiva (AskUserQuestion) de la sesión orquestadora que le muestra el manifiesto completo (PRs, tiers, TTL, límites). Sustituye a la decisión inicial de passphrase por TTY, inviable trabajando desde el móvil. |
| D2 | Tier 3 | Entra en v1. Cada PR va listado por número en el manifiesto autorizado, que actúa como revisión humana del PR concreto, y lleva además una revisión de seguridad específica. Tier 4 siempre queda fuera. |
| D3 | Commit de código posterior al grant | Un agente juez independiente del autor del fix lo analiza. Si es seguro, el sprint sigue; si cambia el alcance o la seguridad, STOP para revisión humana. Fail-closed y todo en el ledger. El ejecutor verifica el veredicto, que solo puede mantener o parar (§2.7). |
| D4 | Revisor de otro modelo | No hace falta. Basta un revisor independiente del autor. |
| D5 | CI inestable | Sin reintento. El PR se aparca y se registra una tarea de causa raíz. |
| D6 | Auto-rebase | Se pausa para los PRs del manifiesto vigente. |
| D7 | SE-343 | El grant `merge` se unifica con el mismo modelo: autorización expresa registrada con pregunta, respuesta, sesión y hash (enmienda propuesta, §2.11). La decisión original decía «firma con passphrase»; se adapta al cambio de D1. |
| D8 | Límites por defecto | TTL de 12 h, 40 merges y 50 PRs por manifiesto. Configurables al autorizar, dentro de los topes absolutos (§2.3). |
| D9 | `.confidentiality-signature` | Se admite como derivado en la equivalencia solo si el ejecutor repite la auditoría de confidencialidad sobre el nuevo head con resultado PASSED. |

## 2. Contrato técnico

### 2.1 Ciclo de vida — `scripts/merge-sprint.sh`

| Subcomando | Quién | Qué hace |
|---|---|---|
| `review-register <pr> <informe>` | agente revisor o juez | Único registro válido de revisiones y veredictos de juez: añade una entrada al registro append-only y encadenado y publica un espejo como comentario del PR. |
| `plan --prs <N…> \| --query <q>` | agente u operadora | Resuelve la lista y escribe un borrador de manifiesto. No es de confianza: `render-question` lo recalcula todo. |
| `render-question <manifest>` | sesión orquestadora | Recalcula el manifiesto y emite el texto exacto de la pregunta y de la opción de aprobación (§2.3). |
| `grant --manifest <m> --session <id> --question-file <q> --answer-file <a>` | **solo la sesión orquestadora, justo después de la respuesta** | Registra el grant (§2.3). |
| `revoke <id>` | cualquiera | Revocación inmediata: STOP y grant invalidado. |
| `run <id>` | agente con permiso acotado | Verifica y ejecuta (§2.5). |
| `status <id>` · `stop [<id>]` · `report <id>` · `verify-ledger <id>` | cualquiera | Parar siempre es seguro. Un sprint parado por una condición de parada no se reanuda. |

El estado local vive en `~/.savia/merge-sprints/<id>/` (manifiesto, grant, ledger, solicitudes al
juez, informe) y nunca en el repo. Hay dos ficheros STOP: el global `~/.savia/merge-sprints/STOP` y
el de cada sprint, `~/.savia/merge-sprints/<id>/STOP`.

### 2.2 Manifiesto

Es un JSON canónico (claves ordenadas, sin espacios). Su SHA-256 es el digest al que se liga el grant.

- `id`, `repo`, `base`, `created_at`, `ttl_hours` (cuenta desde `issued_at` del grant), `max_merges`, `allowed_tiers` ⊆ {1,2,3},
  `max_consecutive_parks`.
- `runner_blob` y `classifier_blob`: blobs de `scripts/merge-sprint.sh` y `scripts/risk-tier.py` en
  `origin/main`.
- `required_checks`: instantánea de los checks obligatorios de la protección de `base`. No puede estar
  vacía.
- `main_workflows`: workflows cuyo resultado sobre `base` cuenta como «CI de main».
- `query`: solo procedencia. La lista se resuelve y se congela.
- `entries[]`, ordenadas por número de PR ascendente. Cada una lleva:
  - `pr`, `head` (40 hex), `base_ref`, `head_repo` y `files` (rutas y modos del diff);
  - `tier` y `tier_reason`;
  - `reviews[]`, con `{sha256, role: correctness|security, verdict, reviewer, author, registered_at}`.
    Son **todas** las revisiones registradas para `(pr, head)`.
  - `ack`, solo en tier 3: la selección explícita de ese PR por la operadora en la pregunta.

`tier` es el máximo de tres valores: `risk-tier.py` (en la versión de `classifier_blob`) sobre el
diff, el tier que declare cualquier revisión y cualquier retención registrada. Es monótono: nada lo
baja.

### 2.3 Emisión del grant (D1: respuesta en la sesión)

**Flujo**

1. **`render-question` no confía en `plan`.** Recalcula desde GitHub y `origin/main`:
   - heads, base, ficheros y modos;
   - el tier;
   - todas las revisiones registradas de cada `(pr, head)`, vueltas a parsear;
   - los blobs;
   - los checks obligatorios y los workflows de `main`.

   Ante cualquier discrepancia con el borrador, aborta. Excluye cualquier PR con al menos un HOLD.
   Escribe el manifiesto definitivo y emite:
   - **El texto exacto de la pregunta.** Contiene el manifiesto completo y el digest SHA-256
     completo:
     - por PR, primero los campos deterministas (número, ficheros, diffstat, tier y su motivo, número
       de revisiones por rol y veredictos) y después el texto libre (título y hallazgos), marcado como
       no fiable;
     - TTL, `max_merges`, `allowed_tiers` y los límites que se salgan de los valores por defecto;
     - los cambios de `runner_blob` o `classifier_blob` respecto al último grant.
   - **La opción de aprobación literal**, `Apruebo merge-sprint <id> <digest[:12]>`, frente a
     `Rechazo`.
   - **Para los PRs de tier 3, una pregunta de selección múltiple.** Cada PR de tier 3 que la
     operadora no seleccione expresamente sale del manifiesto (su `ack`). Hay una pregunta por cada
     bloque de PRs que admita el control, y si el manifiesto cambia se vuelve a `render-question`.
2. **La sesión orquestadora la formula con AskUserQuestion, sin editarla.** Si el texto completo no
   cabe en la pregunta, se muestra en el mensaje inmediatamente anterior y la pregunta cita el digest
   completo y el recuento por tier.
3. **Justo después de la respuesta, la misma sesión ejecuta `grant`.** El comando escribe `grant.json`
   con:
   - `manifest_digest`;
   - `question` y `answer`, literales;
   - `session_id` e `issued_at`;
   - el contexto de emisión (§ Mitigaciones).

   Después lo añade al ledger encadenado. `grant` falla, y no escribe nada, en estos casos:
   - la respuesta no es exactamente la opción de aprobación;
   - la pregunta no contiene el digest del manifiesto;
   - el manifiesto cambió desde `render-question`;
   - ya existe un grant para ese manifiesto.

**Límites (D8)**

- Por defecto: TTL de 12 h desde `issued_at`, `max_merges` = 40 y como máximo 50 PRs.
- Topes absolutos que impone el ejecutor, autorice lo que autorice el grant: TTL ≤ 24 h, PRs ≤ 50,
  `max_merges` ≤ número de PRs, `max_consecutive_parks` ≤ 3 y `allowed_tiers` ⊆ {1,2,3}.

**Límite (dicho sin rodeos)**

El grant es un fichero que escribe un agente. Su autenticidad, es decir, que esa respuesta la dio la
operadora y no un agente, depende del harness de Claude Code (AskUserQuestion solo devuelve lo que
respondió la persona) y del clasificador. No depende de criptografía. Un agente con shell arbitraria
(A4) podría fabricar un `grant.json`. Las mitigaciones de abajo hacen que fabricarlo sea detectable o
inútil, pero no imposible.

**Mitigaciones**

- **Coincidencia exacta.** El ejecutor solo acepta un grant cuyo `manifest_digest` coincida byte a byte
  con el manifiesto que ejecuta y cuya `answer` sea la opción de aprobación de ese digest. Un grant
  sirve para un único manifiesto y no se puede ampliar, prorrogar ni reutilizar.
- **Ledger encadenado.** La emisión, cada merge, cada aparcamiento y cada parada quedan en el ledger
  encadenado por hash; `verify-ledger` lo valida.
- **Informe a la operadora.** El acuse del grant (id, digest, PRs, TTL) se le envía al arrancar `run`,
  y el informe final al terminar o parar, por la sesión y por el canal de notificación que tenga
  configurado. Un grant que ella no reconozca es visible de inmediato.
- **Un subagente nunca emite un grant** (comprobación del contexto de emisión, si es viable). Un hook
  PreToolUse rechaza `merge-sprint.sh grant` cuando la entrada del hook identifica la llamada como de
  un subagente o de un compañero de equipo. `grant` registra ese contexto. Si la implementación
  demuestra que el harness no expone el dato, se documenta como no verificable y queda solo la regla
  de permisos.
- **Contraste con el transcript** (si es viable). El ejecutor localiza el transcript de `session_id` y
  comprueba que la pregunta y la respuesta literales figuran como `tool_use`/`tool_result` de
  AskUserQuestion, en ese orden y antes de `issued_at`. Es una comprobación de coherencia, no una
  prueba: el transcript también es un fichero del mismo usuario.
- **Permiso `ask` para `grant`.** La operadora aprueba también la llamada a `grant` desde la interfaz
  remota: es una segunda interacción humana con el harness.
- **Revocación inmediata.** `revoke <id>`, `stop` o el fichero STOP invalidan el grant y paran el
  sprint antes del siguiente paso. La operadora puede pedirlo en la sesión con una sola palabra.

**Mejoras futuras (fuera de alcance)**

- Una cuenta bot de GitHub con aprobación de la operadora desde su propia cuenta.
- Aprobación en Savia Mobile con biometría y firma en el dispositivo.

Ambas añadirían un factor que un agente no puede reproducir.

### 2.4 Revisión

La primera línea tiene una gramática estricta. Cualquier otra forma equivale a HOLD:

```text
VERDICT: APPROVE|HOLD pr=<N> sha=<40 hex minúsculas> role=correctness|security tier=<1-4> reviewer=<id> author=<id> p0=<n> p1=<n> p2=<n> p2_blocking=<n>
```

- `APPROVE` exige `p0=0 p1=0 p2_blocking=0`.
- `sha` es el `head` del manifiesto. `reviewer` es distinto de `author` y del orquestador del sprint.
- Solo cuentan las revisiones registradas con `review-register`. Para cada `(pr, sha)` se recogen
  **todas**, y un único HOLD excluye el PR. Así, relanzar revisores hasta obtener APPROVE no sirve:
  los HOLD previos siguen en el registro.
- Requisitos por tier:
  - tier 1/2: al menos una revisión APPROVE con `role=correctness`;
  - tier 3: además, una APPROVE con `role=security`. Basta con que cada revisión sea de una instancia
    independiente del autor, sin exigir otro modelo (D4).
- Las revisiones se congelan antes del grant. Una revisión posterior no autoriza nada, y una
  revisión modificada (hash distinto) aparca el PR. `run` vuelve a parsear cada revisión y no se
  limita a comprobar su hash.

### 2.5 Ejecutor

Precondiciones de `run`, todas fail-closed:

- grant válido: existe, su `manifest_digest` coincide exactamente, la respuesta es la opción de aprobación de ese digest y no está revocado;
- `now < grant.issued_at + ttl_hours`;
- `merged < max_merges`;
- topes absolutos respetados;
- sin fichero STOP;
- blobs del ejecutor y del clasificador iguales a los del manifiesto;
- checks obligatorios vivos ⊇ `required_checks` y no vacíos;
- lock exclusivo (un sprint por máquina).

Al arrancar, el ejecutor pone la etiqueta `merge-sprint:<id>` a cada PR del manifiesto para pausar el
auto-rebase (D6).

En la reconciliación tras una caída, se consulta la reserva F5 (SE-387) `pr.merge/<N>` de este grant:

- si el PR está MERGED con reserva `submitted`, es un merge propio sin registrar: se completa el
  ledger y se sigue;
- si está MERGED sin reserva de este grant, es un merge externo: anomalía y STOP.

Por cada entrada, en orden ascendente:

1. Revalidar el grant, TTL, contador y STOP. Comprobar la CI de `main`. Si no está en verde: STOP.
2. Comprobar el PR:
   - si está cerrado y reabierto desde `plan`, o han cambiado su `baseRefName` o su `head_repo`,
     anomalía y STOP;
   - si el head cambió, pasar al paso 6.
3. Volver a parsear las revisiones y comprobar sus hashes. Si alguna cambió o hay un HOLD nuevo
   registrado para ese SHA, aparcar.
4. Recalcular el tier con el clasificador del manifiesto. Si sube o queda fuera de `allowed_tiers`, aparcar.
5. Re-sync: merge de `origin/main` en la rama, nunca rebase ni force-push. Los conflictos solo en
   derivados (§2.6) se regeneran. Cualquier otro conflicto aparca el PR. Push con commit
   `agent(merge-sprint): …`: el push con las credenciales de la operadora dispara la CI.
6. Equivalencia (§2.6) entre el `head` autorizado y el head actual:
   - si se cumple, fijar `S` = head actual;
   - si no, el PR pasa a `awaiting_judge` (§2.7) y se sigue con el siguiente.
7. Esperar, con plazo, los `required_checks` sobre `S`. Si en cualquier punto el head es distinto de
   `S`, aparcar.
   - Si un check está en rojo, aparcar con `ci_red`, sin reintento, y registrar una tarea de causa raíz
     en el informe y en `<id>/tasks/` (D5). Crear la tarea en una herramienta PM sigue requiriendo
     aprobación.
   - Si vence el plazo, aparcar con `ci_timeout`.
8. Último chequeo del fichero STOP. Después, `gh pr ready` y
   `gh pr merge --squash --match-head-commit S`. Si GitHub lo rechaza:
   - si `mergeStateStatus` es `DIRTY` o `BEHIND` (main avanzó durante la espera, por otro merge), se
     registra `RETRY` y se vuelve al paso 5, hasta `MERGE_SPRINT_TRIES` intentos (3 por defecto).
     Agotados, se aparca con `main_movido_sin_converger`;
   - con cualquier otro estado, aparcar con `merge_rechazado`, sin reintento.
9. Registrar en el ledger. Esperar la CI de `main` sobre el commit de merge:
   - cuenta solo si **todos** los `main_workflows` aplicables terminan en `success` sobre ese SHA exacto;
   - pending tras el plazo, ninguna ejecución, `cancelled`, `skipped` o rojo: STOP, sin revert.

Al aparcar un PR que ya salió de Draft, vuelve a Draft.

| Evento | Acción |
|---|---|
| CI roja del PR, conflicto real, revisión cambiada o con HOLD nuevo, tier elevado, merge rechazado, timeout de CI | Aparcar, registrar y seguir |
| Equivalencia fallida | `awaiting_judge` (§2.7) |
| CI de `main` que no queda en verde tras un merge | STOP |
| Grant inválido o revocado, manifiesto alterado, blobs distintos, merge externo, base o repo cambiados, PR reabierto, checks obligatorios reducidos | STOP (anomalía) |
| Veredicto `STOP` del juez, o veredicto inválido o fuera de plazo | STOP |
| Máximo de merges, TTL o fichero STOP | STOP |
| `max_consecutive_parks` aparcamientos seguidos | STOP |

Nunca: force-push, revert automático, reintento de CI, rebase, borrar ramas ni tocar PRs fuera del
manifiesto. La comprobación de los blobs la hace el propio ejecutor: detecta errores (A1), pero no es
una garantía frente a A4.

### 2.6 Equivalencia del head (por árbol)

Sean `H0` el `head` autorizado, `H1` el head actual y `M` el commit de `main` integrado en `H1`.

- `T = git merge-tree --write-tree M H0`. Los conflictos solo pueden estar en derivados.
- Para cada path fuera de la lista de derivados, el blob y el modo en `H1` deben ser iguales a los de
  `T`. Se comparan árboles, no diffs: los cambios de espacios, de binarios y de modo cuentan.
- **Derivados admitidos.** Solo los artefactos generados del SAM, tal como `risk-tier.py` los lista en
  `SCM_GENERATED_FILES` y `SCM_GENERATED_DIRS`, más `.confidentiality-signature` (D9), más el índice
  y el manifiesto de reglas (`docs/rules/INDEX.md`, `docs/rules/domain/rule-manifest.json`), que se
  regeneran con `rules-index-generate.sh` y `rule-manifest-generate.sh`.
  - Cada derivado se regenera con el código de `origin/main` y debe coincidir.
  - Las declaraciones de `.scm/` editadas a mano no son derivados.
  - `.confidentiality-signature` se admite solo si el ejecutor repite la auditoría de confidencialidad
    sobre `H1` con resultado PASSED y la re-firma con `scripts/confidentiality-sign.sh`. Sin PASSED,
    el PR se aparca. La CI (`confidentiality-gate`) verifica la firma.

- **En `plan`.** Si el head actual no tiene revisiones suficientes, se usa el sha revisado más reciente
  que las tenga y sea equivalente al head según esta sección. El manifiesto lleva ese sha revisado, y
  `run` vuelve a exigir la equivalencia con el head que haya en ese momento.

### 2.7 Juez de cambios posteriores al grant (D3)

El ejecutor sigue sin usar ningún LLM. El juez es un agente externo, consultado de forma asíncrona:

1. **Solicitud** (`<id>/judge/<pr>-<sha>.request.json`):
   - `pr`, `from` (el head autorizado) y `to` (el head actual);
   - el diff `from..to` sin los derivados;
   - la entrada del manifiesto y los hashes de las revisiones previas;
   - `fix_author` (trailer de los commits) y el tier.
2. **Prefiltro determinista.** Fuerza STOP sin consultar al juez si el delta cumple cualquiera de
   estas condiciones:
   - toca ficheros fuera de `files`;
   - toca paths de tier 3 o de gobernanza (§2.8);
   - sube el tier;
   - añade o borra ficheros;
   - elimina `@test` o aserciones;
   - cambia binarios o modos;
   - supera 200 líneas.
3. **Criterio.**
   - «Seguro»: el delta implementa hallazgos ya listados en las revisiones previas o corrige un fallo
     de CI, sin ampliar funcionalidad, superficie, permisos, datos ni dependencias.
   - «Cambia alcance o seguridad»: cualquier otra cosa, o la duda.
4. **Salida.** La primera línea, registrada con `review-register`:

   ```text
   JUDGE: SAFE|STOP pr=<N> from=<40 hex> to=<40 hex> judge=<id> fix_author=<id> scope=unchanged|changed security=unchanged|changed reason=<slug>
   ```

   `SAFE` exige `scope=unchanged security=unchanged`.
5. **Verificación del ejecutor.** Si falla cualquiera de estos puntos, STOP:
   - el formato es válido;
   - `from` es el head autorizado y `to` es el head actual;
   - `judge` es distinto de `fix_author`, del autor original y del orquestador;
   - hay un único veredicto para `(pr, to)`;
   - llega dentro del plazo (60 min por defecto).
6. **Efecto.**
   - `SAFE`: el PR vuelve al final de la cola con `S = to` y CI nueva (pasos 7–9).
   - `STOP`: STOP del sprint con `judge_stop`, a la espera de revisión humana.

   El veredicto nunca añade PRs, sube tiers ni prorroga el TTL. Todo queda en el ledger: solicitud,
   prefiltro, veredicto y verificación.

### 2.8 Tier 3, tier 4 y paths de gobernanza

- **Tier 3 (D2).** La entrada debe tener `ack` y dos revisiones APPROVE: `correctness` y `security`.
  Como en todo merge, se espera la CI de `main` antes del siguiente.
- **Tier 4.** Se excluye siempre.
- **Paths de gobernanza, clasificados tier 4** (cambio en `risk-tier.py`):
  - `scripts/merge-sprint.sh` y `scripts/risk-tier.py`;
  - `.claude/settings*.json` y `.opencode/` (permisos y plugins);
  - `docs/rules/domain/autonomous-safety*.md`, `CLAUDE.md` y `AGENTS.md`;
  - `docs/rules/domain/savia-ethical-principles.md` y `docs/rules/domain/radical-honesty.md`;
  - `.github/workflows/`.

  Así, un sprint no puede mergear el debilitamiento de sus propias reglas.

### 2.9 Auditoría

`ledger.jsonl` es append-only, y cada línea lleva en `prev` el SHA-256 de la anterior. Detecta
alteraciones, no las impide. `verify-ledger` valida la cadena.

Campos por merge:

- `grant_id` y `manifest_digest`;
- `pr` y `tier`;
- `head_signed`, `S`, `equivalence` (`identical`, `main_merge`, `derived_regen` o `judge_safe`) y
  `judge_ref`;
- `review_sha256[]`;
- `ci_run_ids` y `required_checks`;
- `merge_commit` y `main_ci_run_ids`;
- `started_at` y `merged_at`.

Los aparcamientos, las paradas, las solicitudes al juez y las tareas de causa raíz también se
registran, con su motivo.

El informe local para la operadora incluye: los merges, los PRs aparcados con su causa, las tareas de
causa raíz, las decisiones del juez, el motivo de fin y los PRs que necesitan arreglo y un grant
nuevo. Se envía a la operadora (§2.3, Mitigaciones).

### 2.10 Permiso mínimo en el frontend

Lo añade la operadora en sus settings, nunca un agente:

- **Allow**: `bash scripts/merge-sprint.sh run|status|stop|revoke|report|plan|render-question|review-register|verify-ledger`.
- **Ask**: `bash scripts/merge-sprint.sh grant`. La operadora aprueba también esta llamada desde la
  interfaz remota.
- **Deny**:
  - `gh pr merge` en general;
  - editar `scripts/merge-sprint.sh` y `scripts/risk-tier.py`;
  - escribir en `~/.savia/merge-sprints/`.

Los settings no distinguen la sesión orquestadora de un subagente. Esa distinción la hace, si es
viable, el hook de contexto de emisión (§2.3).

El permiso por sí solo no mergea: sin un grant vigente para el manifiesto exacto, `run` termina con
error.

No elude el clasificador. El clasificador protege a la operadora de merges que ella no autorizó. Aquí
ella autoriza la lista de forma expresa en la sesión, y el ejecutor solo actúa con ese registro: un
único camino, acotado y con rastro. Este modelo depende de que el clasificador y el harness sigan
impidiendo que un agente responda por ella (§2.3, «Límite»).

### 2.11 Enmiendas propuestas (se aplican al implementar, no en esta spec)

- **`autonomous-safety.md`.** Añadir esta excepción a «NUNCA merge de ninguna rama» y a «grant de
  merge expreso vigente»: «salvo el ejecutor de merge-sprint con un manifiesto autorizado vigente
  (`autonomous-safety-merge-sprint.md`); el re-sync con `main` de las ramas del manifiesto lo hace
  solo ese ejecutor».
- **SE-343 (D7).** `operator-grant.sh grant --scope merge` exigirá el mismo modelo de autorización:
  pregunta y respuesta literales, sesión y hash del PR. Un grant sin ese registro dejará de bastar para
  `push-pr.sh --merge`. Va en una spec de enmienda aparte.
- **SE-362 / Rule 8 E1.** Añadir la lectura de tier 3 de la sección «Coherencia».
- **`auto-rebase-open-prs.yml` (D6).** Omitir los PRs con la etiqueta `merge-sprint:<id>`.
- **`risk-tier.py`.** Añadir los paths de gobernanza de §2.8.

## Entregables (rutas)

Esta propuesta, que es solo documental:

- `docs/specs/SE-433-merge-sprint.spec.md`
- `docs/rules/domain/autonomous-safety-merge-sprint.md`
- `docs/rules/domain/autonomous-safety.md` (enlace)
- `docs/specs/SE-343-operator-grant-switch.spec.md` (nota de enmienda propuesta, D7)
- `docs/rules/domain/rule-manifest.json`, `docs/propuestas/planning-state.json` y
  `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md` (registro)
- `CHANGELOG.d/merge-sprint-spec.md`

La implementación, cuando se apruebe:

- `scripts/merge-sprint.sh` y `scripts/risk-tier.py`;
- el hook PreToolUse de contexto de emisión (si es viable);
- `.github/workflows/auto-rebase-open-prs.yml`;
- `tests/test-merge-sprint.bats`.

Los ficheros de tier 4 de la implementación se mergean a mano, nunca en un merge-sprint.

## Criterios de aceptación

Grant:

- **AC-01** `run` sin grant, con un grant de otro manifiesto, con un manifiesto alterado en un byte o
  con un grant revocado: exit ≠ 0, ningún merge y evento `STOP:grant`.
- **AC-02** `grant` no escribe nada si la respuesta no es exactamente la opción de aprobación del
  digest, si la pregunta no contiene el digest completo, si el manifiesto cambió desde
  `render-question` o si ya existe un grant para ese manifiesto.
- **AC-03** `grant.json` contiene la pregunta y la respuesta literales, `session_id`, `issued_at`,
  `manifest_digest` y el contexto de emisión, y su emisión queda en el ledger. Si es viable, el hook
  rechaza `grant` invocado desde un subagente (test con una entrada de hook simulada), y el contraste
  con un transcript simulado sin la respuesta produce STOP.
- **AC-04** Un borrador editado tras `plan` (`verdict`, `head`, `tier`, `files` o una revisión
  omitida) hace que `render-question` aborte.
- **AC-05** Sin valores explícitos, el grant produce TTL de 12 h, `max_merges` 40 y rechaza más de 50
  PRs. Un manifiesto con TTL de 25 h, 51 PRs, parks > 3 o tier 4 en `allowed_tiers` hace que `run`
  termine con error aunque tenga grant.

Revisión:

- **AC-06** El parser de veredicto devuelve APPROVE solo para la línea válida con SHA correcto.
  Fixtures, todas HOLD salvo la válida:
  1. veredicto fuera de la línea 1;
  2. título en la línea 1 y veredicto en la 2;
  3. `APTO`;
  4. `PASS CON CAMBIOS`;
  5. `p1=1`;
  6. `p2_blocking=1`;
  7. SHA corto;
  8. SHA en mayúsculas;
  9. SHA distinto del `head`;
  10. `reviewer == author`;
  11. revisor igual al orquestador;
  12. sin `role`;
  13. campos duplicados;
  14. BOM o CRLF;
  15. `VERDICT：` con dos puntos de ancho completo;
  16. texto tras `p2_blocking`;
  17. `tier=` mayor que el autorizado;
  18. la línea válida.
- **AC-07** Para un `(pr, sha)` con un HOLD y un APPROVE registrados posteriormente, el PR queda
  excluido en `render-question` y aparcado en `run`.
- **AC-08** Una revisión con un hash distinto tras el grant aparca el PR con `review_changed`, y el
  sprint continúa.
- **AC-09** Tier 3 sin `ack`, o sin revisión `role=security` APPROVE: aparcado. Tier 3 con ambas: se
  mergea.

Equivalencia y juez:

- **AC-10** Equivalencia. Se admiten como `main_merge` o `derived_regen`:
  - un merge limpio de `main`;
  - la regeneración de los artefactos SAM;
  - `.confidentiality-signature` re-firmada con la auditoría en PASSED.

  Pasan a `awaiting_judge`:
  - una indentación cambiada en un `.py`;
  - un binario modificado;
  - un `chmod +x`;
  - una edición de `.scm/sam-declarations.json`;
  - un conflicto resuelto a mano.

  `.confidentiality-signature` con la auditoría FAILED: aparcado.
- **AC-11** Prefiltro del juez: un delta que toca un fichero fuera de `files`, un path de gobernanza,
  añade un fichero, elimina un `@test` o supera 200 líneas produce STOP sin solicitar al juez.
- **AC-12** Juez: `SAFE` válido → el PR se mergea tras una CI nueva sobre `to`. Producen STOP:
  - `STOP`;
  - un formato inválido;
  - `from` o `to` erróneos;
  - `judge == fix_author`;
  - dos veredictos para el mismo `(pr, to)`;
  - el plazo vencido.

  El veredicto nunca cambia `entries`, `allowed_tiers` ni `ttl_hours`.

Ejecución:

- **AC-13** Un PR con el tier recalculado mayor que el autorizado, o tier 4, queda aparcado. Cada path de
  gobernanza de §2.8 se clasifica tier 4.
- **AC-14** CI obligatoria en rojo: el PR queda aparcado, con cero reintentos (el `gh` falso registra
  una sola consulta de resultado por SHA) y una tarea de causa raíz en `<id>/tasks/`. El siguiente PR
  se procesa.
- **AC-15** CI de `main`. Producen STOP sin revert ni force-push:
  - en rojo;
  - `cancelled`;
  - `skipped`;
  - ninguna ejecución tras el plazo;
  - pending tras el plazo.

  En la traza no aparece ningún `git push --force` ni `git revert`.
- **AC-16** Checks obligatorios vivos vacíos o reducidos respecto a `required_checks`: STOP.
- **AC-17** `runner_blob` o `classifier_blob` distintos: STOP. `revoke <id>` entre dos merges: el siguiente no se ejecuta.
- **AC-18** Un PR reapuntado a otra base, con otro repo de head o cerrado y reabierto: STOP por
  anomalía.
- **AC-19** `gh pr merge` siempre lleva `--match-head-commit S`, con el mismo `S` que superó la
  equivalencia y cuyos checks se verificaron. Si se empuja un commit entre los checks y el merge, el PR
  se aparca.
- **AC-20** Un fichero STOP creado entre los checks y el merge: no hay merge, y STOP.
- **AC-21** Tres aparcamientos consecutivos: STOP.
- **AC-22** Un PR aparcado tras `gh pr ready` vuelve a Draft.
- **AC-23** Al arrancar se etiquetan los PRs del manifiesto con `merge-sprint:<id>`, y el workflow de
  auto-rebase los omite (test del workflow con un evento simulado).
- **AC-24** E2E con 3 PRs que tocan `.confidentiality-signature` y artefactos `.scm/` generados: se
  mergean los 3 en serie.

Concurrencia, recuperación y auditoría:

- **AC-25** Dos `run` concurrentes: uno obtiene el lock y el otro termina con exit ≠ 0. Con el proceso
  muerto entre el merge y el ledger, el siguiente `run` encuentra la reserva F5 `submitted`, completa
  el ledger y no lo trata como merge externo.
- **AC-26** Un merge de un PR del manifiesto sin reserva de este grant: STOP por anomalía.
- **AC-27** Cada merge tiene todos los campos de §2.9 y `verify-ledger` valida la cadena. Si se altera
  una línea, la verificación falla.

Entrega:

- **AC-28** El test BATS `tests/test-merge-sprint.bats`, con `gh` y repo git falsos, cubre AC-01 a
  AC-27 y lo certifica con ≥80 `scripts/test-auditor.sh`.
- **AC-29** OpenCode: con su configuración de permisos (`permission.bash` y `permission.edit`) se
  deniegan `gh pr merge` y la edición del ejecutor, `grant` queda en `ask` y se permite `run`.
- **AC-30** `autonomous-safety.md` enlaza `autonomous-safety-merge-sprint.md` y sigue por debajo de 150
  líneas.

## Fuera de alcance

- Contener a un agente adversarial con shell arbitraria (A4).
- Un factor de autorización criptográfico. Quedan como mejora futura:
  - una cuenta bot de GitHub con aprobación de la operadora desde su cuenta;
  - Savia Mobile con biometría y firma en el dispositivo.
- Tier 4 en un merge-sprint.
- Implementar la enmienda de SE-343 (spec aparte).
- Revertir automáticamente o corregir `main` desde el ejecutor.
- Aprobar PRs en GitHub: la protección de rama no exige reviews y la operadora es la única
  colaboradora.

## Riesgos

- **Correlación de revisores.** El revisor, el revisor de seguridad y el juez son instancias del mismo
  modelo, así que comparten sesgos (D4 acepta este riesgo).
- **Tier 3 sin lectura humana.** En tier 3, la operadora no lee el diff: autoriza sobre resúmenes y
  revisiones de agentes (D2).
- **Alcance de la CI.** Una CI verde prueba que no se rompió lo que se mide, no que el cambio sea
  correcto.
- **Fatiga de aprobación.** Un manifiesto de hasta 50 PRs aprobado sin leer vacía la aprobación de valor. Lo
  mitiga solo en parte el resumen determinista.
- **Autenticidad del grant sin criptografía.** El grant lo escribe un agente. Que la respuesta sea de
  la operadora depende del harness y del clasificador (§2.3). Las mitigaciones hacen que fabricarlo
  sea detectable o inútil, no imposible.
- **Identidades autodeclaradas.** Las identidades de los agentes que figuran en revisiones y
  veredictos son cadenas autodeclaradas. A3 queda detectado, no impedido, antes de `plan`.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `scripts/merge-sprint.sh` | Script bash invocado por Bash | Script bash idéntico |
| `scripts/risk-tier.py` | Paths de gobernanza a tier 4 | Idéntico |
| Permiso mínimo | `permissions.allow`/`deny` en los settings de la operadora | `permission.bash` y `permission.edit` con los mismos patrones |
| Pregunta interactiva | AskUserQuestion en la sesión orquestadora | Herramienta de pregunta de OpenCode; mismo texto de `render-question` y misma opción literal |
| Hook de contexto de emisión | PreToolUse (si el harness expone la identidad de subagente) | Plugin `savia-gates`, si OpenCode expone el dato; si no, SKIP documentado |
| Regla | `docs/rules/domain/autonomous-safety-merge-sprint.md` | Misma regla (AGENTS.md generado) |

### Verification protocol

- [ ] `bats tests/test-merge-sprint.bats` en verde y certificado con ≥80.
- [ ] El mismo test pasa invocado desde OpenCode (sin dependencias del frontend).
- [ ] AC-29: denegaciones y permiso de `run` comprobados en OpenCode.
- [ ] No añade hooks.

### Portability classification

- [x] **DUAL_BINDING**:
  - el ejecutor y `grant` son bash, git, `gh` y la librería estándar de python3, idénticos en los dos
    motores;
  - la pregunta interactiva y el hook de contexto de emisión son bindings de frontend, que se
    implementan en Claude Code y OpenCode desde el primer slice;
  - los permisos se expresan en la configuración nativa de cada motor.
