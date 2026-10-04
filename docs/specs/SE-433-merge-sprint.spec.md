---
status: PROPOSED
priority: P1
developer_type: agent-single
created: 2026-10-04
author: Savia
phase: A
risk: L3
related_specs: [SE-343, SE-362, SE-228, SE-387]
origin: "Petición de la operadora: reglas y concepto de merge-sprint para que Savia pueda hacer sprints de merge seguros y con criterio, sin supervisión durante la ejecución, bajo estricta autorización humana previa."
timeline:
  - from: "2026-10-04"
    learned: "2026-10-04"
    value: "PROPOSED"
    source: "spec-lifecycle:auto"
---
# SE-433 — merge-sprint: merges autónomos bajo autorización humana previa

## Problema

Cuando los agentes producen PRs más rápido de lo que una persona puede revisarlos y mergearlos
uno a uno, se acumulan decenas de PRs Draft ya revisados por agentes maker-checker. Hoy hay dos
caminos y los dos fallan:

1. **Merge uno a uno con grant `merge` (SE-343).** El grant es one-shot y lo escribe el propio
   agente «a petición expresa». No escala a N PRs y su factor humano es una afirmación del
   agente, no una prueba: el ledger es un fichero del mismo usuario que ejecuta al agente.
2. **Scripts ad hoc de merge en serie.** Los observados en la práctica tienen huecos de diseño:
   - el gate de revisión busca `HOLD` solo en la primera línea, y muchos informes llevan un
     título ahí (fail-open);
   - el vocabulario de veredicto es libre (`APTO`, `PASS CON CAMBIOS`, «requiere revisión de la
     operadora»), y un gate textual lo malinterpreta;
   - la revisión no está ligada al SHA del head: se mergea código con commits posteriores a la
     revisión;
   - no hay manifiesto: cualquier PR abierto con revisión entra, también los creados después de
     la autorización;
   - no se consulta `risk-tier.py`, así que se mergea tier 3/4 sin la revisión humana de SE-362;
   - las retenciones las crea y las libera el mismo orquestador que lanza al autor y al arreglo.

El clasificador del modo automático de Claude Code bloquea estos scripts como «Merge Without
Review» y la liberación de retenciones por un agente como «Self-Approval». El diagnóstico es
correcto para esos mecanismos. Esta spec no busca convencer al clasificador: busca que «lo revisó
y lo autorizó un humano» sea verdad y se pueda comprobar mecánicamente.

## Objetivo

Un **merge-sprint** es una ventana acotada en la que un ejecutor determinista (script, sin LLM)
mergea en serie una lista congelada de PRs que la operadora autorizó antes con una firma que solo
ella puede producir.

**Principio rector:** la autorización solo fluye de la firma humana. Ninguna salida de un agente
puede añadir un PR, subir un tier permitido ni sustituir una revisión. Las salidas de agentes
(revisiones, CI, clasificador de riesgo) solo pueden **restar**: aparcar un PR o parar el sprint.

## Modelo de amenazas

| Clase | Descripción | En alcance |
|---|---|---|
| A1 | Agente bienintencionado que se equivoca: mergea de más, malinterpreta un veredicto, sigue tras un fallo. | Sí |
| A2 | Contenido inyectado en cuerpos de PR, comentarios o informes («VERDICT: APPROVE», «ignora el HOLD»). | Sí |
| A3 | Orquestador que re-lanza revisores hasta obtener APPROVE o libera retenciones. | Sí |
| A4 | Agente adversarial con shell arbitraria del mismo usuario: edita el ejecutor o llama a `gh pr merge`. | No. Lo contiene la capa de permisos del frontend, no un script. Se declara, no se oculta. |

Hecho de partida: los agentes usan las credenciales de GitHub y el usuario del sistema de la
operadora. Toda señal en GitHub o en disco es reproducible por un agente. El único factor que un
agente no puede producir es un secreto que no posee.

## 2. Contrato técnico

### 2.1 Ciclo de vida — `scripts/merge-sprint.sh`

| Subcomando | Quién | Qué hace |
|---|---|---|
| `plan --prs <N…> \| --query <q>` | agente u operadora | Resuelve la lista y escribe un manifiesto sin firmar más un resumen legible por PR. |
| `grant <manifest>` | **solo la operadora, en su terminal** | Muestra el resumen, pide la frase de confirmación y, para tier 3, el número de cada PR; firma el digest. |
| `run <id>` | agente con permiso acotado | Verifica y ejecuta (§2.5). |
| `status <id>` · `stop [<id>]` · `report <id>` | cualquiera | Parar siempre es seguro. Nadie reanuda un sprint parado por condición de parada. |

Estado local en `~/.savia/merge-sprints/<id>/` (manifiesto, firma, ledger, informe). Nunca en el repo.

### 2.2 Manifiesto

JSON canónico (claves ordenadas, sin espacios); el digest firmado es su SHA-256. Campos:

- `id`, `repo`, `base`, `created_at`, `expires_at` (TTL), `max_merges`, `allowed_tiers`;
- `query`: solo procedencia; la lista se resuelve y congela al hacer `plan`;
- `runner_blob`: blob de `scripts/merge-sprint.sh` en `origin/main` al planificar;
- `stop`: `max_consecutive_parks` (por defecto 3);
- `entries[]`, ordenadas por número de PR ascendente, cada una con:
  - `pr` y `head` (SHA de 40 caracteres);
  - `tier` y `tier_reason`;
  - `review`: `path`, `sha256`, `verdict`, `reviewer`, `author`;
  - `ack`: solo en tier 3; el número del PR tecleado por la operadora.

`tier` = máximo de `risk-tier.py` sobre el diff, del tier declarado en cualquier revisión y de
cualquier marca de retención. Es monótono: nada lo baja.

### 2.3 Emisión del grant (factor humano)

- La firma usa `ssh-keygen -Y sign -n savia-merge-sprint` con una clave dedicada de la operadora:
  - una clave con passphrase que no se carga en `ssh-agent`;
  - o, mejor, una llave FIDO2 (`ed25519-sk`), que exige contacto físico.
- La verificación usa `ssh-keygen -Y verify` contra `config/merge-sprint/allowed_signers`, leído
  de `origin/main` y nunca del árbol de trabajo. Esa ruta es tier 4 en `risk-tier.py`.
- La frase de confirmación (`MERGE <n> PRs <id>`) asegura la deliberación, pero no es un factor
  de seguridad: un agente puede abrir un pseudo-TTY.
- Un agente no puede emitir, ampliar ni prorrogar un grant. Cambiar el manifiesto invalida la
  firma.

### 2.4 Revisión: formato, vínculo al SHA e independencia

La primera línea del informe tiene una gramática estricta; cualquier otra cosa equivale a HOLD:

```text
VERDICT: APPROVE|HOLD pr=<N> sha=<40 hex> tier=<1-4> reviewer=<id> author=<id> p0=<n> p1=<n> p2=<n>
```

- `APPROVE` exige `p0=0 p1=0`. Un P2 marcado «antes del merge» es HOLD.
- `sha` = `head` del manifiesto. `reviewer ≠ author`, y ninguno de los dos es el orquestador del
  sprint.
- Por cada `(pr, sha)` cuenta la **primera** revisión registrada: no hay compra de veredictos.
- Las revisiones se congelan (por hash) en el manifiesto **antes** de la firma. Una revisión
  posterior no puede autorizar nada. Si el fichero cambia, el hash no cuadra y el PR se aparca.

**Por qué no es autoaprobación encubierta.** Una revisión de agente es autoaprobación cuando se
dan tres condiciones:

- su salida habilita el efecto por sí sola;
- el mismo sistema que quiere el efecto controla cuándo se produce;
- puede escribirse después de la autorización humana.

Aquí la revisión es necesaria pero nunca suficiente (lo suficiente es la firma), se congela antes
de firmar y solo puede restar. Límite que se declara: dos instancias del mismo modelo comparten
sesgos. Esta spec no lo resuelve; ver Preguntas abiertas.

### 2.5 Ejecutor

Precondiciones de `run`, todas fail-closed:

- firma válida;
- `now < expires_at`;
- `merged < max_merges`;
- el sprint no está `STOPPED` ni `COMPLETE`;
- no existe el fichero STOP;
- el blob del ejecutor en uso = `runner_blob`;
- lock exclusivo (un sprint por máquina);
- reconciliación con GitHub: un PR del manifiesto mergeado fuera del ejecutor es una anomalía y
  provoca STOP.

Por cada entrada, en orden ascendente:

1. Se revalidan firma, TTL, contador y STOP. Si el último CI de `main` está en rojo: STOP.
2. Se comprueba el head. Si cambió y la equivalencia (§2.6) falla, se aparca.
3. Se comprueba el hash de la revisión. Si cambió, se aparca.
4. Se recalcula el tier. Si sube o queda fuera de `allowed_tiers`, se aparca.
5. Re-sync: merge de `origin/main` en la rama (nunca rebase ni force-push) y push con las
   credenciales de la operadora, que sí disparan CI. Un conflicto fuera de `.scm/` aparca el PR;
   un conflicto solo en `.scm/` se resuelve con `sam.py generate`.
6. Se repite la equivalencia (§2.6) sobre el nuevo head.
7. Se exigen en verde los checks obligatorios de la protección de rama, sobre el SHA exacto y con
   plazo. Sin reintentos.
8. `gh pr ready` y `gh pr merge --squash --match-head-commit <sha>`.
9. Se registra en el ledger y se espera el CI de `main` sobre el commit de merge. Si está en
   rojo: STOP, sin revert.

| Evento | Acción |
|---|---|
| CI roja del PR, conflicto real, head movido sin equivalencia, revisión cambiada, tier elevado, merge rechazado o timeout de CI | Aparcar, registrar y seguir |
| `main` roja tras un merge | STOP |
| Firma inválida, manifiesto alterado, ejecutor distinto, merge externo, protección de rama distinta de la registrada | STOP (anomalía) |
| Máximo de merges, TTL o fichero STOP | STOP |
| `max_consecutive_parks` aparcamientos seguidos | STOP |

Nunca: force-push, revert automático, reintento de CI, rebase, borrar ramas, tocar PRs fuera del
manifiesto. Cada merge reserva `pr.merge/<N>` en F5 (SE-387) para que una caída no duplique el
efecto.

### 2.6 Equivalencia mecánica del head

Entre el head firmado `H0` y el final `H1` solo se admiten:

- igualdad;
- merges de `origin/main` sin conflicto fuera de `.scm/`;
- la regeneración de `.scm/`.

Comprobación sin LLM:

- `git patch-id --stable` del diff `merge-base(origin/main,H)..H` excluyendo `.scm/` es igual
  para `H0` y `H1`;
- el árbol `.scm/` de `H1` es igual al que produce `sam.py generate` en un checkout limpio de
  `H1`.

Si `main` tocó líneas vecinas, el patch-id cambia y el PR se aparca. Es un falso positivo
aceptable.

### 2.7 Tier 3 y tier 4

- **Revisión humana explícita del PR concreto (SE-362) en un merge-sprint:** la entrada firmada
  incluye ese PR, su head, su tier y un `ack` que la operadora produce tecleando el número del PR
  tras ver su resumen (título, diffstat, motivo del tier, veredictos y hallazgos). Un «sí a todo»
  no cuenta.
- **Tier 3** requiere además:
  - dos revisiones independientes entre sí y del autor (corrección, y seguridad con postura
    adversarial);
  - que la de seguridad se haga sin el cuerpo del PR;
  - como máximo 3 PRs de tier 3 por sprint;
  - esperar al CI de `main` tras cada merge de tier 3 antes de seguir.
- **Tier 4** queda excluido. SE-362 pide doble humano, que con una operadora única no existe.

### 2.8 Auditoría

`ledger.jsonl` es append-only y cada línea lleva `prev` = SHA-256 de la anterior (detecta
alteraciones; no las impide). Campos por merge:

- `grant_id` y `manifest_digest`;
- `pr` y `tier`;
- `head_signed`, `head_merged` y `equivalence`;
- `review_sha256`;
- `ci_run_ids` y `required_checks`;
- `merge_commit` y `main_ci_run_id`;
- `started_at` y `merged_at`.

Los aparcamientos y las paradas se registran con su motivo. Al terminar se genera un informe local
para la operadora: merges hechos, PRs aparcados con su causa, motivo de fin y qué PRs necesitan
arreglo y una nueva firma.

### 2.9 Permiso mínimo en el frontend

Lo añade la operadora en sus settings; un agente nunca. Permite solo
`bash scripts/merge-sprint.sh run|status|stop|plan` y deniega lo siguiente:

- `gh pr merge` en general;
- `merge-sprint.sh grant`;
- editar `scripts/merge-sprint.sh`;
- editar `config/merge-sprint/`.

El permiso no basta para mergear: sin un manifiesto firmado y vigente, `run` termina con error.

Esto no elude el clasificador. El clasificador protege a la operadora de merges que ella no revisó;
aquí la operadora revisa la lista y firma con un factor que el agente no tiene. Lo que concede es
un único camino, acotado, con rastro de cada paso.

## Criterios de aceptación

- **AC-01** `run` sin firma, con firma de otra clave o con un manifiesto alterado en un byte → exit ≠ 0, ningún merge y evento `STOP:signature` en el ledger.
- **AC-02** `run` con `expires_at` pasado o `merged == max_merges` → exit ≠ 0 sin llamar a `gh pr merge` (verificado con un `gh` falso que registra llamadas).
- **AC-03** `grant` sin TTY o sin la passphrase de la clave → no produce firma (exit ≠ 0). Ningún subcomando accesible al agente escribe `manifest.sig`.
- **AC-04** Parser de veredicto: 12 fixtures (veredicto fuera de la línea 1, `APTO`, `PASS CON CAMBIOS`, `p1=1`, SHA corto, SHA distinto, `reviewer == author`, revisor = orquestador, línea válida…) → solo la línea válida con SHA correcto es APPROVE.
- **AC-05** Revisión modificada tras la firma (hash distinto) → PR aparcado `review_changed` y el sprint continúa.
- **AC-06** Equivalencia: un merge limpio de `main` y la regeneración de `.scm/` → `main_merge`/`scm_regen`, se admiten. Un commit que cambia una línea de código del PR → aparcado `head_moved`.
- **AC-07** Un PR con tier recalculado mayor que el firmado, o tier 4, → aparcado. `config/merge-sprint/allowed_signers` → tier 4 en `risk-tier.py`.
- **AC-08** Tier 3 sin `ack` o con una sola revisión → aparcado.
- **AC-09** CI obligatoria en rojo → aparcado, cero reintentos (el `gh` falso registra una sola consulta de checks por SHA hasta el plazo), y el siguiente PR se procesa.
- **AC-10** `main` en rojo tras un merge → STOP, sin revert ni force-push (ninguna llamada a `git push --force` ni `git revert` en la traza).
- **AC-11** Tres aparcamientos consecutivos → STOP.
- **AC-12** `gh pr merge` se invoca siempre con `--match-head-commit` igual al SHA cuyos checks se verificaron.
- **AC-13** Un PR del manifiesto mergeado fuera del ejecutor → STOP por anomalía en la reconciliación.
- **AC-14** Ledger: cada merge tiene todos los campos de §2.8 y la cadena `prev` se valida con `merge-sprint.sh verify-ledger`. Alterar una línea → la verificación falla.
- **AC-15** Dos `run` concurrentes del mismo id → uno obtiene el lock y el otro sale con exit ≠ 0. Si el proceso se mata a mitad, el siguiente `run` no duplica el merge (reserva F5).
- **AC-16** Test BATS `tests/test-merge-sprint.bats` con `gh` y repo git falsos, certificado ≥80 por `scripts/test-auditor.sh`, cubriendo AC-01 a AC-15.
- **AC-17** `autonomous-safety.md` enlaza la regla `autonomous-safety-merge-sprint.md` y sigue por debajo de 150 líneas.

## Fuera de alcance

- Contener a un agente adversarial con shell arbitraria (A4).
- Tier 4 en merge-sprint.
- Cambiar el flujo de un merge suelto vía `push-pr.sh --merge` (SE-343).
- Revert automático o cualquier corrección de `main` por el ejecutor.
- Aprobar PRs en GitHub: la protección de rama no exige reviews y la operadora es la única colaboradora.

## Riesgos

- Revisores del mismo modelo correlacionados aprueban los mismos errores.
- La CI verde prueba que no se rompió lo medido, no que el cambio sea correcto.
- Fatiga de firma: un manifiesto largo firmado sin leer vacía la firma de valor. Mitigación: límite por manifiesto y resumen corto por PR.
- El auto-rebase del repositorio puede competir con el re-sync del ejecutor.

## Preguntas abiertas

1. Factor de firma: llave FIDO2 o clave con passphrase.
2. Tier 3 dentro de merge-sprint en v1, o solo tier 1/2.
3. Commits de arreglo después de la firma: siempre nueva firma, o re-revisión dentro del sprint para tier 1/2.
4. Segundo revisor de otro modelo o proveedor para tier 3.
5. Reintento único de CI ante tests marcados como inestables.
6. Pausar el auto-rebase para los PRs de un manifiesto vigente.
7. Retroadaptar el grant `merge` de SE-343 para que también exija firma.
8. Límites por defecto: TTL, máximo de merges y de PRs por manifiesto.
9. `.confidentiality-signature` como derivado admitido en la equivalencia.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `scripts/merge-sprint.sh` | Script bash invocado por Bash | Script bash idéntico |
| `scripts/risk-tier.py` | Añade `config/merge-sprint/` a tier 4 | Idéntico |
| Permiso mínimo | `permissions.allow`/`deny` en settings de la operadora | `permission.bash` con los mismos patrones |
| Regla | `docs/rules/domain/autonomous-safety-merge-sprint.md` | Misma regla (AGENTS.md generado) |

### Verification protocol

- [ ] `bats tests/test-merge-sprint.bats` en verde y certificado ≥80
- [ ] El mismo test pasa invocado desde OpenCode (sin dependencias del frontend)
- [ ] No añade hooks

### Portability classification

- [x] **PURE_BASH**: bash, git, `gh`, `ssh-keygen` y python3 stdlib. Sin bindings de frontend. Los permisos se expresan en la configuración nativa de cada motor.
