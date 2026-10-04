---
context_tier: L3
token_budget: 1600
spec: SE-433
status: PROPOSED
---

# merge-sprint — merges autónomos bajo autorización humana previa (SE-433)

> Apéndice de `autonomous-safety.md`. **PROPOSED**: hasta que la operadora apruebe SE-433 y exista
> `scripts/merge-sprint.sh`, ningún merge en serie es válido y rige el merge uno a uno
> (`autonomous-safety-merge-grant.md`).

## Principio

La autorización solo nace de la firma humana. Ninguna salida de un agente puede añadir un PR, subir
un tier, prorrogar el sprint ni sustituir una revisión. Las revisiones, el juez, la CI y el
clasificador de riesgo solo pueden **mantener o restar**: dejar seguir un PR ya firmado, aparcarlo o
parar el sprint. Lo irreversible se decide con confirmación humana (`savia-ethical-principles.md`).
Lo que se afirma es «lo autorizó un humano, con firma, sobre una lista concreta y tras ver las
revisiones de agentes». No se afirma que un humano haya leído el diff.

## Ciclo

1. `review-register`: cada revisión y cada veredicto de juez se registra en un registro encadenado,
   con espejo como comentario del PR.
2. `plan`: un agente prepara un borrador de manifiesto. No es de confianza.
3. `grant`: lo ejecuta solo la operadora, en su terminal y nunca en la sesión de un agente. Recalcula
   todo desde GitHub y `origin/main`, muestra un resumen determinista y firma con su clave ed25519
   cifrada con passphrase.
4. `run`: un ejecutor determinista mergea en serie, del PR más antiguo al más nuevo.
5. `report`: genera un informe local.

## Grant

```text
NUNCA   un agente emite, amplía, prorroga ni re-firma un grant de merge-sprint
NUNCA   tier 4 · consulta sin resolver · grant sin TTL, máximo ni tiers enumerados
SIEMPRE manifiesto congelado: PR, head SHA, ficheros, tier, todas las revisiones, blobs del
        ejecutor/clasificador/firmantes, checks obligatorios y workflows de main
SIEMPRE firma ssh-keygen -Y con clave cifrada por passphrase; clave pública leída de origin/main
SIEMPRE por defecto TTL 12 h, 40 merges, ≤ 50 PRs; topes absolutos TTL ≤ 24 h, parks ≤ 3
```

## Revisión

- Primera línea: `VERDICT: APPROVE|HOLD pr= sha= role=correctness|security tier= reviewer= author=
  p0= p1= p2= p2_blocking=`. Cualquier otra forma equivale a HOLD.
- `APPROVE` exige `p0=p1=p2_blocking=0`. El SHA es el del head firmado. El revisor es distinto del
  autor y del orquestador.
- Se recogen **todas** las revisiones registradas de cada PR y SHA: un solo HOLD lo excluye.
- Tier 1/2 necesita una APPROVE `correctness`. Tier 3 necesita además una APPROVE `security` y el
  número del PR tecleado al firmar.
- Basta con revisores independientes del autor; no hace falta que sean de otro modelo.

## Ejecución

```text
SIEMPRE ejecutor determinista; el LLM no decide un merge
SIEMPRE en serie; re-sync con main por merge (nunca rebase); auto-rebase pausado (etiqueta)
SIEMPRE checks obligatorios en verde sobre el SHA S; merge con --match-head-commit S
SIEMPRE tras cada merge, todos los workflows de main en success sobre ese SHA
NUNCA   force-push · revert automático · reintento de CI · PRs fuera del manifiesto
NUNCA   bajar un tier; los paths de gobernanza son tier 4
```

Equivalencia del head, comparando árboles (blob y modo):

- Se admiten sin juez:
  - un merge de `main`;
  - la regeneración de los artefactos SAM generados;
  - `.confidentiality-signature`, solo si la auditoría repetida sobre el nuevo head da PASSED.
- Cualquier otro cambio va al juez.

## Juez de cambios posteriores a la firma

- **Prefiltro determinista.** Antes de consultar al juez, provoca STOP cualquier delta que:
  - toque ficheros fuera de los firmados;
  - toque paths de tier 3 o de gobernanza;
  - suba el tier;
  - añada o borre ficheros;
  - elimine tests;
  - cambie binarios o modos;
  - supere 200 líneas.
- **Veredicto.** Primera línea: `JUDGE: SAFE|STOP pr= from= to= judge= fix_author= scope= security=
  reason=`. El juez es distinto del autor del fix, del autor original y del orquestador. Ante la
  duda, STOP.
- **Comprobación del ejecutor.** El ejecutor verifica el formato, los SHA, la independencia y la
  unicidad. Un veredicto `SAFE` solo deja seguir al PR, con CI nueva. `STOP` detiene el sprint para
  revisión humana.

| Evento | Acción |
|---|---|
| CI roja del PR (con tarea de causa raíz), conflicto real, revisión cambiada o HOLD nuevo, tier elevado, merge rechazado | Aparcar (vuelve a Draft) y seguir |
| CI de `main` no verde tras un merge (rojo, pending, ausente, cancelled, skipped) | Parar |
| Firma inválida, manifiesto o blobs alterados, merge externo, base cambiada, checks reducidos | Parar (anomalía) |
| Juez `STOP`, veredicto inválido o fuera de plazo | Parar |
| Máximo de merges, TTL, fichero STOP, 3 aparcamientos seguidos | Parar |

Parar siempre es seguro. Un sprint parado por una condición de parada no se reanuda sin una firma
nueva.

## Tier 3/4

- **Tier 3.** Por decisión de la operadora, la firma del manifiesto que lista el PR por número es la
  revisión humana del PR concreto (SE-362), junto con una revisión de seguridad de un agente
  independiente. Esto modifica la lectura de SE-362 y de Rule 8 E1 para tier 3. Ningún humano lee el
  diff.
- **Tier 4.** Nunca entra. Incluye el ejecutor, `risk-tier.py`, `config/merge-sprint/`, la
  configuración de permisos de Claude Code y OpenCode, las reglas `autonomous-safety*`, `CLAUDE.md`,
  `AGENTS.md`, los principios éticos, la honestidad radical y `.github/workflows/`.

## Auditoría

El ledger local es append-only y está encadenado por hash; se valida con `verify-ledger`. Cada merge
registra el grant y el digest del manifiesto, el tier, el SHA firmado, el mergeado y el tipo de
equivalencia, la referencia al juez, los hashes de las revisiones, los ids de CI y los checks
obligatorios, el commit de merge, la CI de `main` y las horas.

Al final se genera un informe para la operadora. Nada de esto se versiona.

## Permiso en el frontend

Lo concede la operadora en sus settings, nunca un agente:

- **Allow** solo `bash scripts/merge-sprint.sh run|status|stop|plan|review-register|verify-ledger`.
- **Deny**:
  - `gh pr merge`;
  - `merge-sprint.sh grant`;
  - la edición del ejecutor, de `risk-tier.py` y de `config/merge-sprint/`.

Sin un manifiesto firmado y vigente, `run` termina con error. No elude el clasificador: es la
operadora quien concede un único camino, acotado y auditable.

## Límite declarado

Un agente con shell arbitraria del mismo usuario puede saltarse cualquier script; lo contienen los
permisos del frontend, no esta regla. El revisor, el revisor de seguridad y el juez son instancias del
mismo modelo y comparten sesgos. Las identidades de los agentes son autodeclaradas: el registro
encadenado detecta que alguien compre veredictos antes de `plan`, pero no lo impide.

## Referencias

- Spec: `docs/specs/SE-433-merge-sprint.spec.md`
- Reglas: `autonomous-safety.md` · `autonomous-safety-merge-grant.md` (SE-343) ·
  `maker-checker-protocol.md`
- Scripts: `scripts/risk-tier.py` (SE-362) · reservas F5 (SE-387)
