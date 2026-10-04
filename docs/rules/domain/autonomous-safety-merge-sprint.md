---
context_tier: L3
token_budget: 1400
spec: SE-433
status: PROPOSED
---

# merge-sprint — merges autónomos bajo autorización humana previa (SE-433)

> Apéndice de `autonomous-safety.md`. **PROPOSED**: hasta que la operadora apruebe SE-433 y exista
> `scripts/merge-sprint.sh`, ningún merge en serie es válido y rige la regla de merge uno a uno
> (`autonomous-safety-merge-grant.md`).

## Principio

La autorización solo fluye de la firma humana. Ninguna salida de un agente puede añadir un PR,
subir un tier ni sustituir una revisión. Las salidas de agentes (revisiones, CI, clasificador de
riesgo) solo pueden **restar**: aparcar un PR o parar el sprint. La IA propone; la operadora
dispone una vez, antes, por escrito y con firma; un script determinista ejecuta.

## Ciclo

1. `plan`: un agente prepara un manifiesto: lista congelada de PRs con head SHA, tier y el hash
   del informe de revisión.
2. `grant`: solo la operadora, en su terminal. Lee el resumen y firma el digest del manifiesto con
   su clave (passphrase o llave FIDO2).
3. `run`: el ejecutor mergea en serie, del PR más antiguo al más nuevo, lo que la firma cubre.
4. `report`: un informe local con los merges, los PRs aparcados y el motivo de fin.

## Grant

```text
NUNCA   un agente emite, amplía, prorroga ni re-firma un grant de merge-sprint
NUNCA   un grant sin TTL, sin máximo de merges, sin tiers enumerados o con consulta sin resolver
SIEMPRE manifiesto congelado: PRs explícitos con head SHA y hash de revisión
SIEMPRE firma con un factor que el agente no posee; la frase tecleada sola no basta
SIEMPRE clave pública verificada desde origin/main, nunca desde el árbol de trabajo
```

## Revisión

- La primera línea es `VERDICT: APPROVE|HOLD pr=<N> sha=<40 hex> tier=<n> reviewer=<id>
  author=<id> p0=<n> p1=<n> p2=<n>`. Cualquier otra forma equivale a HOLD.
- `APPROVE` exige `p0=0 p1=0`. Un P2 marcado «antes del merge» es HOLD.
- El SHA de la revisión es el del head del manifiesto. Revisor ≠ autor ≠ orquestador del sprint.
- Por cada PR y SHA cuenta la primera revisión registrada: no se re-lanzan revisores hasta obtener
  APPROVE.
- La revisión se congela antes de la firma. Una revisión posterior no autoriza nada. Una revisión
  modificada aparca el PR.

## Ejecución

```text
SIEMPRE ejecutor determinista (script); el LLM no decide un merge
SIEMPRE en serie, del PR más antiguo al más nuevo; re-sync con main por merge, nunca rebase
SIEMPRE checks obligatorios en verde sobre el SHA exacto; merge con --match-head-commit
SIEMPRE tras cada merge, CI de main en verde antes del siguiente
NUNCA   force-push · revert automático · reintento de CI · PRs fuera del manifiesto
NUNCA   bajar un tier: el tier es el máximo de risk-tier, de las revisiones y de las retenciones
```

Cambios admitidos en el head tras la firma, verificados mecánicamente:

- merge de `main` sin conflicto fuera de `.scm/`;
- regeneración de `.scm/`.

Cualquier otro cambio aparca el PR y exige una nueva firma.

| Evento | Acción |
|---|---|
| CI roja del PR, conflicto real, head movido, revisión cambiada, tier elevado, merge rechazado | Aparcar y seguir |
| `main` roja tras un merge | Parar |
| Firma inválida, manifiesto alterado, ejecutor distinto, merge externo de un PR del manifiesto | Parar (anomalía) |
| Máximo de merges, TTL, fichero STOP, 3 aparcamientos seguidos | Parar |

Parar siempre es seguro y cualquiera puede hacerlo. Un sprint parado por una condición de parada
no se reanuda: hace falta una firma nueva.

## Tier 3/4

- **Tier 3.** Cuenta como «revisión humana explícita del PR concreto» (SE-362) cuando la entrada
  firmada lleva el `ack` que la operadora produce tecleando el número del PR tras ver su resumen.
  Exige además:
  - dos revisiones independientes: corrección, y seguridad sin el cuerpo del PR;
  - como máximo 3 PRs de tier 3 por sprint;
  - CI de `main` en verde tras cada merge de tier 3.
- **Tier 4.** Fuera de merge-sprint: con una operadora única no hay el doble humano que exige
  SE-362.

## Auditoría

Ledger local append-only y encadenado por hash. Cada merge registra:

- el id del grant y el digest del manifiesto;
- el PR y su tier;
- el SHA firmado y el SHA mergeado, con el tipo de equivalencia;
- el hash de la revisión;
- los ids de CI y los checks obligatorios;
- el commit de merge y el CI de `main`;
- las horas.

Al terminar, informe para la operadora. Nada de esto se versiona en el repo.

## Permiso en el frontend

Lo concede la operadora en sus settings, nunca un agente:

- **allow** solo `bash scripts/merge-sprint.sh run|status|stop|plan`;
- **deny** `gh pr merge`, `merge-sprint.sh grant` y la edición del ejecutor y de
  `config/merge-sprint/`.

El permiso por sí solo no mergea: sin un manifiesto firmado y vigente, `run` termina con error. No
es eludir el clasificador. Es la operadora quien concede, acotado y auditable, un único camino que
se niega a actuar sin su firma.

## Límite declarado

Un agente con shell arbitraria del mismo usuario puede saltarse cualquier script. Contra eso
protegen los permisos del frontend, no esta regla. Revisores del mismo modelo comparten sesgos: la
revisión de agente es una condición necesaria, no una garantía.

## Referencias

- Spec: `docs/specs/SE-433-merge-sprint.spec.md`
- `autonomous-safety.md` · `autonomous-safety-merge-grant.md` (SE-343) · `maker-checker-protocol.md`
- `scripts/risk-tier.py` (SE-362) · reservas F5 (SE-387)
