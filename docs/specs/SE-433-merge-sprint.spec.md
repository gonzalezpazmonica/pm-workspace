---
status: PROPOSED
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

Que la afirmación «**lo autorizó un humano, con firma, sobre una lista concreta y tras ver la
revisión de agentes**» sea verdad y se compruebe mecánicamente. Un **merge-sprint** es una ventana
acotada en la que un ejecutor determinista (un script, sin LLM) mergea en serie una lista congelada
de PRs que la operadora autorizó antes con una firma que solo ella puede producir.

**Principio rector:** la autorización solo nace de la firma humana. Ninguna salida de un agente puede
añadir un PR, subir un tier permitido, prorrogar el sprint ni sustituir una revisión. Las salidas de
agentes (revisiones, el juez de cambios, la CI y el clasificador de riesgo) solo pueden **mantener o
restar**: dejar seguir un PR ya firmado, aparcarlo o parar el sprint. Esto aplica la línea roja de
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
operadora. Cualquier señal en GitHub o en disco es reproducible por un agente. El único factor que un
agente no puede producir es un secreto que no posee.

## Coherencia con Rule 8, SE-343 y SE-362

- **Rule 8** («Code Review (E1) SIEMPRE humano; NUNCA autoaprobar; merge con grant expreso y gates de
  riesgo»). En un merge-sprint, para tier 1/2, E1 es la revisión de agente congelada más la
  autorización humana firmada. Es el mismo estatus que hoy tiene el grant de SE-343 tras CI y gates,
  con un factor humano más fuerte. Ningún humano lee el diff de esos PRs: se dice así.
- **Tier 3 (SE-362: «revisión humana explícita del PR concreto»).** Por decisión expresa de la
  operadora, en un merge-sprint esa revisión es la firma de un manifiesto que lista el PR por número
  y con su `ack`, junto con una revisión de seguridad específica de un agente independiente del autor.
  **Esto modifica la lectura de SE-362 y de Rule 8 E1 para tier 3**: la operadora autoriza tras ver
  el resumen y las revisiones, no tras leer el código. Aprobar SE-433 es aceptar esa modificación; la
  enmienda textual se propone en §2.11.
- **Tier 4**: nunca entra en un merge-sprint (SE-362 exige doble humano).
- **SE-343**: el grant `merge` se unificará con este modelo de firma. La enmienda se propone en
  §2.11 y no se implementa en esta spec.

## Decisiones (operadora, 2026-10-04)

| # | Tema | Decisión |
|---|---|---|
| D1 | Factor de firma | Clave ed25519 local en `~/.savia`, cifrada con una passphrase que solo la operadora teclea por TTY. |
| D2 | Tier 3 | Entra en v1. Cada PR va listado por número en el manifiesto firmado, que actúa como revisión humana del PR concreto, y lleva además una revisión de seguridad específica. Tier 4 siempre queda fuera. |
| D3 | Commit de código posterior a la firma | Un agente juez independiente del autor del fix lo analiza. Si es seguro, el sprint sigue; si cambia el alcance o la seguridad, STOP para revisión humana. Fail-closed y todo en el ledger. El ejecutor verifica el veredicto, que solo puede mantener o parar (§2.7). |
| D4 | Revisor de otro modelo | No hace falta. Basta un revisor independiente del autor. |
| D5 | CI inestable | Sin reintento. El PR se aparca y se registra una tarea de causa raíz. |
| D6 | Auto-rebase | Se pausa para los PRs del manifiesto vigente. |
| D7 | SE-343 | El grant `merge` también exigirá firma con passphrase (enmienda propuesta, §2.11). |
| D8 | Límites por defecto | TTL de 12 h, 40 merges y 50 PRs por manifiesto. Configurables al firmar, dentro de los topes absolutos (§2.3). |
| D9 | `.confidentiality-signature` | Se admite como derivado en la equivalencia solo si el ejecutor repite la auditoría de confidencialidad sobre el nuevo head con resultado PASSED. |

## 2. Contrato técnico

### 2.1 Ciclo de vida — `scripts/merge-sprint.sh`

| Subcomando | Quién | Qué hace |
|---|---|---|
| `review-register <pr> <informe>` | agente revisor o juez | Único registro válido de revisiones y veredictos de juez: añade una entrada al registro append-only y encadenado y publica un espejo como comentario del PR. |
| `plan --prs <N…> \| --query <q>` | agente u operadora | Resuelve la lista y escribe un borrador de manifiesto. No es de confianza: `grant` lo recalcula todo. |
| `grant <manifest>` | **solo la operadora, en su propia terminal** | Recalcula, muestra, pide confirmaciones y firma (§2.3). |
| `run <id>` | agente con permiso acotado | Verifica y ejecuta (§2.5). |
| `status <id>` · `stop [<id>]` · `report <id>` · `verify-ledger <id>` | cualquiera | Parar siempre es seguro. Un sprint parado por una condición de parada no se reanuda. |

El estado local vive en `~/.savia/merge-sprints/<id>/` (manifiesto, firma, ledger, solicitudes al
juez, informe) y nunca en el repo. Hay dos ficheros STOP: el global `~/.savia/merge-sprints/STOP` y
el de cada sprint, `~/.savia/merge-sprints/<id>/STOP`.

### 2.2 Manifiesto

Es un JSON canónico (claves ordenadas, sin espacios). El digest que se firma es su SHA-256.

- `id`, `repo`, `base`, `created_at`, `expires_at`, `max_merges`, `allowed_tiers` ⊆ {1,2,3},
  `max_consecutive_parks`.
- `runner_blob` y `classifier_blob`: blobs de `scripts/merge-sprint.sh` y `scripts/risk-tier.py` en
  `origin/main`.
- `signers_blob`: blob de `config/merge-sprint/allowed_signers` en `origin/main`.
- `required_checks`: instantánea de los checks obligatorios de la protección de `base`. No puede estar
  vacía.
- `main_workflows`: workflows cuyo resultado sobre `base` cuenta como «CI de main».
- `query`: solo procedencia. La lista se resuelve y se congela.
- `entries[]`, ordenadas por número de PR ascendente. Cada una lleva:
  - `pr`, `head` (40 hex), `base_ref`, `head_repo` y `files` (rutas y modos del diff);
  - `tier` y `tier_reason`;
  - `reviews[]`, con `{sha256, role: correctness|security, verdict, reviewer, author, registered_at}`.
    Son **todas** las revisiones registradas para `(pr, head)`.
  - `ack`, solo en tier 3: el número del PR tecleado por la operadora.

`tier` es el máximo de tres valores: `risk-tier.py` (en la versión de `classifier_blob`) sobre el
diff, el tier que declare cualquier revisión y cualquier retención registrada. Es monótono: nada lo
baja.

### 2.3 Emisión del grant

- **Factor (D1).** Firma con `ssh-keygen -Y sign -n savia-merge-sprint` y una clave ed25519 de la
  operadora en `~/.savia`, cifrada con passphrase y no cargada en `ssh-agent`. Se verifica con
  `ssh-keygen -Y verify` contra `config/merge-sprint/allowed_signers`, leído de `origin/main` y nunca
  del árbol de trabajo.
- **`grant` no confía en `plan`.** Recalcula desde GitHub y `origin/main`:
  - heads y base;
  - ficheros y modos;
  - el tier;
  - todas las revisiones registradas de cada `(pr, head)`, vueltas a parsear;
  - los blobs;
  - los checks obligatorios y los workflows de `main`.

  Ante cualquier discrepancia con el borrador, aborta sin firmar. Excluye cualquier PR con al menos
  un HOLD.
- **Resumen.** Lo genera `grant`, no `plan`. Por PR muestra primero los campos deterministas
  (ficheros, diffstat, tier y su motivo, número de revisiones por rol y veredictos). Después, el texto
  libre (título y hallazgos), marcado como no fiable. Resalta cualquier cambio de `runner_blob`,
  `classifier_blob` o `signers_blob` respecto al último grant.
- **Confirmaciones.**
  - Una frase `MERGE <n> PRs <id>`, que asegura deliberación pero no es un factor de seguridad.
  - Para cada PR de tier 3, teclear su número (`ack`).
  - Para cada límite fuera de los valores por defecto, teclear el valor.
- **Límites (D8).**
  - Por defecto: `expires_at` = ahora + 12 h, `max_merges` = 40 y como máximo 50 PRs.
  - Topes absolutos que impone el ejecutor, firme lo que firme la operadora: TTL ≤ 24 h, PRs ≤ 50,
    `max_merges` ≤ número de PRs, `max_consecutive_parks` ≤ 3 y `allowed_tiers` ⊆ {1,2,3}.
- **Dónde no se ejecuta.** `grant` no se ejecuta en la sesión de un agente (tampoco con `!`): la frase
  y el resumen acabarían en la conversación. Un agente no puede emitir, ampliar, prorrogar ni
  re-firmar un grant, y cambiar un byte del manifiesto invalida la firma.

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
- Las revisiones se congelan antes de la firma. Una revisión posterior no autoriza nada, y una
  revisión modificada (hash distinto) aparca el PR. `run` vuelve a parsear cada revisión y no se
  limita a comprobar su hash.

### 2.5 Ejecutor

Precondiciones de `run`, todas fail-closed:

- firma válida;
- `now < expires_at`;
- `merged < max_merges`;
- topes absolutos respetados;
- sin fichero STOP;
- blobs del ejecutor, del clasificador y de los firmantes iguales a los firmados;
- checks obligatorios vivos ⊇ `required_checks` y no vacíos;
- lock exclusivo (un sprint por máquina).

Al arrancar, el ejecutor pone la etiqueta `merge-sprint:<id>` a cada PR del manifiesto para pausar el
auto-rebase (D6).

En la reconciliación tras una caída, se consulta la reserva F5 (SE-387) `pr.merge/<N>` de este grant:

- si el PR está MERGED con reserva `submitted`, es un merge propio sin registrar: se completa el
  ledger y se sigue;
- si está MERGED sin reserva de este grant, es un merge externo: anomalía y STOP.

Por cada entrada, en orden ascendente:

1. Revalidar firma, TTL, contador y STOP. Comprobar la CI de `main`. Si no está en verde: STOP.
2. Comprobar el PR:
   - si está cerrado y reabierto desde `plan`, o han cambiado su `baseRefName` o su `head_repo`,
     anomalía y STOP;
   - si el head cambió, pasar al paso 6.
3. Volver a parsear las revisiones y comprobar sus hashes. Si alguna cambió o hay un HOLD nuevo
   registrado para ese SHA, aparcar.
4. Recalcular el tier con el clasificador firmado. Si sube o queda fuera de `allowed_tiers`, aparcar.
5. Re-sync: merge de `origin/main` en la rama, nunca rebase ni force-push. Los conflictos solo en
   derivados (§2.6) se regeneran. Cualquier otro conflicto aparca el PR. Push con commit
   `agent(merge-sprint): …`: el push con las credenciales de la operadora dispara la CI.
6. Equivalencia (§2.6) entre el `head` firmado y el head actual:
   - si se cumple, fijar `S` = head actual;
   - si no, el PR pasa a `awaiting_judge` (§2.7) y se sigue con el siguiente.
7. Esperar, con plazo, los `required_checks` sobre `S`. Si en cualquier punto el head es distinto de
   `S`, aparcar.
   - Si un check está en rojo, aparcar con `ci_red`, sin reintento, y registrar una tarea de causa raíz
     en el informe y en `<id>/tasks/` (D5). Crear la tarea en una herramienta PM sigue requiriendo
     aprobación.
   - Si vence el plazo, aparcar con `ci_timeout`.
8. Último chequeo del fichero STOP. Después, `gh pr ready` y
   `gh pr merge --squash --match-head-commit S`. Si GitHub lo rechaza, aparcar.
9. Registrar en el ledger. Esperar la CI de `main` sobre el commit de merge:
   - cuenta solo si **todos** los `main_workflows` aplicables terminan en `success` sobre ese SHA exacto;
   - pending tras el plazo, ninguna ejecución, `cancelled`, `skipped` o rojo: STOP, sin revert.

Al aparcar un PR que ya salió de Draft, vuelve a Draft.

| Evento | Acción |
|---|---|
| CI roja del PR, conflicto real, revisión cambiada o con HOLD nuevo, tier elevado, merge rechazado, timeout de CI | Aparcar, registrar y seguir |
| Equivalencia fallida | `awaiting_judge` (§2.7) |
| CI de `main` que no queda en verde tras un merge | STOP |
| Firma inválida, manifiesto alterado, blobs distintos, merge externo, base o repo cambiados, PR reabierto, checks obligatorios reducidos | STOP (anomalía) |
| Veredicto `STOP` del juez, o veredicto inválido o fuera de plazo | STOP |
| Máximo de merges, TTL o fichero STOP | STOP |
| `max_consecutive_parks` aparcamientos seguidos | STOP |

Nunca: force-push, revert automático, reintento de CI, rebase, borrar ramas ni tocar PRs fuera del
manifiesto. La comprobación de los blobs la hace el propio ejecutor: detecta errores (A1), pero no es
una garantía frente a A4.

### 2.6 Equivalencia del head (por árbol)

Sean `H0` el `head` firmado, `H1` el head actual y `M` el commit de `main` integrado en `H1`.

- `T = git merge-tree --write-tree M H0`. Los conflictos solo pueden estar en derivados.
- Para cada path fuera de la lista de derivados, el blob y el modo en `H1` deben ser iguales a los de
  `T`. Se comparan árboles, no diffs: los cambios de espacios, de binarios y de modo cuentan.
- **Derivados admitidos.** Solo los artefactos generados del SAM, tal como `risk-tier.py` los lista en
  `SCM_GENERATED_FILES` y `SCM_GENERATED_DIRS`, más `.confidentiality-signature` (D9).
  - Cada derivado se regenera con el código de `origin/main` y debe coincidir.
  - Las declaraciones de `.scm/` editadas a mano no son derivados.
  - `.confidentiality-signature` se admite solo si el ejecutor repite la auditoría de confidencialidad
    sobre `H1` con resultado PASSED y la re-firma con `scripts/confidentiality-sign.sh`. Sin PASSED,
    el PR se aparca. La CI (`confidentiality-gate`) verifica la firma.

### 2.7 Juez de cambios posteriores a la firma (D3)

El ejecutor sigue sin usar ningún LLM. El juez es un agente externo, consultado de forma asíncrona:

1. **Solicitud** (`<id>/judge/<pr>-<sha>.request.json`):
   - `pr`, `from` (el head firmado) y `to` (el head actual);
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
   - `from` es el head firmado y `to` es el head actual;
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
  - `scripts/merge-sprint.sh`, `scripts/risk-tier.py` y `config/merge-sprint/`;
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
causa raíz, las decisiones del juez, el motivo de fin y los PRs que necesitan arreglo y una nueva
firma.

### 2.10 Permiso mínimo en el frontend

Lo añade la operadora en sus settings, nunca un agente:

- **Allow**: solo `bash scripts/merge-sprint.sh run|status|stop|plan|review-register|verify-ledger`.
- **Deny**:
  - `gh pr merge` en general;
  - `merge-sprint.sh grant`;
  - editar `scripts/merge-sprint.sh`, `scripts/risk-tier.py` y `config/merge-sprint/`.

El permiso por sí solo no mergea: sin un manifiesto firmado y vigente, `run` termina con error.

No elude el clasificador. El clasificador protege a la operadora de merges que ella no autorizó; aquí
ella autoriza la lista con un factor que el agente no tiene y concede un único camino, acotado y con
rastro.

### 2.11 Enmiendas propuestas (se aplican al implementar, no en esta spec)

- **`autonomous-safety.md`.** Añadir esta excepción a «NUNCA merge de ninguna rama» y a «grant de
  merge expreso vigente»: «salvo el ejecutor de merge-sprint con un manifiesto firmado vigente
  (`autonomous-safety-merge-sprint.md`); el re-sync con `main` de las ramas del manifiesto lo hace
  solo ese ejecutor».
- **SE-343 (D7).** `operator-grant.sh grant --scope merge` exigirá la misma firma con passphrase. Un
  grant escrito por un agente dejará de bastar para `push-pr.sh --merge`. Spec de enmienda aparte.
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
  `docs/propuestas/LOG.md` (registro)
- `CHANGELOG.d/merge-sprint-spec.md`

La implementación, cuando se apruebe:

- `scripts/merge-sprint.sh`, `scripts/risk-tier.py` y `config/merge-sprint/allowed_signers`;
- `.github/workflows/auto-rebase-open-prs.yml`;
- `tests/test-merge-sprint.bats`.

Los ficheros de tier 4 de la implementación se mergean a mano, nunca en un merge-sprint.

## Criterios de aceptación

Firma y grant:

- **AC-01** `run` sin firma, con firma de otra clave o con un manifiesto alterado en un byte: exit ≠ 0,
  ningún merge y evento `STOP:signature`.
- **AC-02** `allowed_signers` se lee de `origin/main`. Si el árbol de trabajo tiene otra clave pública,
  una firma hecha con la clave del árbol se rechaza.
- **AC-03** `grant` sin TTY o sin la passphrase no produce firma. Ningún subcomando accesible al agente
  escribe `manifest.sig`.
- **AC-04** Un borrador editado tras `plan` (`verdict`, `head`, `tier`, `files` o una revisión
  omitida) hace que `grant` aborte sin firmar.
- **AC-05** `grant` sin valores explícitos produce TTL de 12 h, `max_merges` 40 y rechaza más de 50
  PRs. Un manifiesto con TTL de 25 h, 51 PRs, parks > 3 o tier 4 en `allowed_tiers` hace que `run`
  termine con error aunque esté firmado.

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
  17. `tier=` mayor que el firmado;
  18. la línea válida.
- **AC-07** Para un `(pr, sha)` con un HOLD y un APPROVE registrados posteriormente, el PR queda
  excluido en `grant` y aparcado en `run`.
- **AC-08** Una revisión con un hash distinto tras la firma aparca el PR con `review_changed`, y el
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

  El veredicto nunca cambia `entries`, `allowed_tiers` ni `expires_at`.

Ejecución:

- **AC-13** Un PR con el tier recalculado mayor que el firmado, o tier 4, queda aparcado. Cada path de
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
- **AC-17** `runner_blob`, `classifier_blob` o `signers_blob` distintos: STOP.
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
  deniegan `gh pr merge`, `merge-sprint.sh grant` y la edición del ejecutor, y se permite `run`.
- **AC-30** `autonomous-safety.md` enlaza `autonomous-safety-merge-sprint.md` y sigue por debajo de 150
  líneas.

## Fuera de alcance

- Contener a un agente adversarial con shell arbitraria (A4).
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
- **Fatiga de firma.** Un manifiesto de hasta 50 PRs firmado sin leer vacía la firma de valor. Lo
  mitiga solo en parte el resumen determinista.
- **Identidades autodeclaradas.** Las identidades de los agentes que figuran en revisiones y
  veredictos son cadenas autodeclaradas. A3 queda detectado, no impedido, antes de `plan`.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `scripts/merge-sprint.sh` | Script bash invocado por Bash | Script bash idéntico |
| `scripts/risk-tier.py` | Paths de gobernanza a tier 4 | Idéntico |
| Permiso mínimo | `permissions.allow`/`deny` en los settings de la operadora | `permission.bash` y `permission.edit` con los mismos patrones |
| Regla | `docs/rules/domain/autonomous-safety-merge-sprint.md` | Misma regla (AGENTS.md generado) |

### Verification protocol

- [ ] `bats tests/test-merge-sprint.bats` en verde y certificado con ≥80.
- [ ] El mismo test pasa invocado desde OpenCode (sin dependencias del frontend).
- [ ] AC-29: denegaciones y permiso de `run` comprobados en OpenCode.
- [ ] No añade hooks.

### Portability classification

- [x] **PURE_BASH**: usa bash, git, `gh`, `ssh-keygen` y la librería estándar de python3, sin bindings
  de frontend. Los permisos se expresan en la configuración nativa de cada motor.
