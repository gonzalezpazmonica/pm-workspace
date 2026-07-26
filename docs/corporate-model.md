# Savia Corporate Model

> SE-271 S1. Criterio corporativo: se adopta, jamas se impone.
> Basado en CONSTITUCION.md (T1-T5), CRITERIO.md (CRIT-001 a CRIT-033),
> y SE-263 (identidad federativa de instancia).
> Capa inerte por defecto. Cuatro invariantes.

## 1. Adoption vs imposition

El criterio corporativo no se impone. Se **adopta** entrada por entrada,
con firma humana explicita por cada item. Una instancia Savia federada
recibe la oferta de un cuerpo corporativo; la operadora de cada instancia
decide que entradas adopta.

Adopcion implica que la entrada corporativa se convierte en criterio activo
de la instancia **dentro del alcance del encargo corporativo**. Fuera de ese
alcance, el criterio local prevalece.

## 2. Cuerpo de criterio corporativo

Un **corporate criterion body** (cuerpo) es un conjunto de entradas de
criterio firmadas criptograficamente, versionadas y publicadas por una
entidad corporativa federada. Cada entrada tiene la misma estructura base
que CRITERIO.md:

- `id` (CRIT-C00X)
- `ambito` (tecnicas, comunicacion, priorizacion, riesgo, delegacion, compliance)
- `principio`
- `dureza` (linea_roja | preferencia | estilo)
- `engagement_scope` (encargo al que aplica)
- `ejemplo`, `contraejemplo`
- `provenance` (corporate:vN, signature)
- `enforcement`
- `adopted_by` (instancias, con firma y timestamp)

## 3. Cuatro invariantes

### 3.1 Monotonicity (monotonia)

Un cuerpo corporativo solo **añade**. Nunca relaja, suaviza ni revierte:

- Jamas puede marcar como `preferencia` lo que el suelo etico declara `linea_roja`.
- Jamas puede eliminar o debilitar una restriccion existente en
  CONSTITUCION.md (T1-T5) o CRITERIO.md (CRIT-026, CRIT-027).
- La dureza de una entrada solo puede aumentar (`estilo` -> `preferencia`,
  `preferencia` -> `linea_roja`), nunca disminuir.
- Si el suelo etico prohibe algo, el cuerpo NO puede permitirlo.

La monotonicidad se verifica via `scripts/corporate-monotonicity-gate.sh`
antes de cualquier presentacion para adopcion.

### 3.2 Adoption linked to engagement

Una entrada corporativa solo esta activa cuando la instancia esta operando
bajo el encargo corporativo concreto al que pertenece. Sin encargo activo,
la entrada esta presente pero inerte.

El adoption ledger registra: instancia, entrada, encargo, firma humana,
timestamp.

### 3.3 Visibility without control

Una entidad corporativa puede ver el criterio adoptado por cada instancia
bajo su encargo. No puede modificarlo, revocarlo ni forzar actualizacion.
La operadora de cada instancia mantiene control exclusivo.

### 3.4 Local resilience

La caida del corporativo nunca bloquea la operacion de una instancia.
El criterio adoptado se cachea localmente en el adoption ledger de la
instancia. Una instancia opera con su ultimo estado conocido si la fuente
corporativa no responde.

## 4. Order of precedence

Cuando un criterio corporativo adoptado entra en conflicto con otro
criterio activo en la instancia, el orden de precedencia es:

1. **CONSTITUCION.md** — Articulos T1-T5. Inviolable.
2. **Suelo etico** — CRIT-026, CRIT-027. Inmunes a adopcion.
3. **Criterio corporativo adoptado** — Dentro de su engagement scope.
4. **Criterio personal** — CRITERIO.md de la instancia.

### Matriz de resolucion de conflictos

| Conflicto | Resolucion |
|---|---|
| Corporativo vs Constitucion | Gana Constitucion. Borrador rechazado. |
| Corporativo vs suelo etico | Gana suelo etico. Borrador rechazado. |
| Corporativo vs personal (dentro de encargo) | Gana corporativo adoptado. |
| Corporativo vs personal (fuera de encargo) | Gana personal. |
| Dos corporativos (mismo encargo) | Gana el de mayor dureza. En igualdad: mas reciente. |
| Dos corporativos (distinto encargo) | Aplica el del encargo activo. |

## 5. Corporate body card format

```json
{
  "body_id": "corp-<slug>",
  "name": "Nombre descriptivo",
  "version": "1.0.0",
  "issued_by": "<entidad emisora>",
  "engagement_scope": "<proyecto|cliente|departamento>",
  "issued_at": "ISO8601",
  "signature": "<firma criptografica>",
  "entries": ["CRIT-C001", "CRIT-C002"]
}
```

## 6. Related

- `CONSTITUCION.md` — Identidad y prohibiciones (T1-T5)
- `CRITERIO.md` — Criterio personal de la operadora (33 entradas)
- `SE-263` — Federacion de Savias, instancia.card.json
- `scripts/corporate-monotonicity-gate.sh`
- `scripts/corporate-adopt.sh`
- `scripts/corporate-body-validate.sh`
- `scripts/corporate-ledger-verify.sh`
