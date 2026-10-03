---
layer: peripheral
name: prospectiva-basica
description: "Prospectiva sistemica local: micro-MICMAC (variables motrices vs dependientes) y micro-MACTOR (actores, alianzas, divergencias, zona de acuerdo). Usar cuando se analiza un sistema con variables interdependientes, se priorizan palancas de accion, o se mapean actores y conflictos. Triggers: 'micmac', 'mactor', 'analisis estructural', 'variables motrices', 'zona de acuerdo'."
metadata:
  savia.maturity: "incomplete"
  savia.context: "standalone"
  savia.context_cost: "low"
  savia.category: "analysis"
  savia.tags: "prospectiva, foresight, micmac, mactor, sistemas"
  savia.priority: "low"
  savia.loop_level: "L1"
  savia.trigger_keywords: "micmac, mactor, prospectiva, variables motrices, analisis estructural"
---

# Prospectiva Básica

Base de skill generada en L30-F1. Análisis estructural 100% local
(stdlib Python, sin red, determinista — CRIT-001).

## Authoritative Paths

| Recurso | Path |
|---|---|
| Micro-MICMAC | `scripts/micmac.py` |
| Micro-MACTOR | `scripts/mactor.py` |
| Fixtures de referencia | `tests/fixtures/l30-prospectiva/` |
| Tests | `tests/test-prospectiva-basica.bats`, `tests/test_micmac.py`, `tests/test_mactor.py`, `tests/bats/test-l30-prospectiva.bats` |
| Preregistro | `labs/roadmaps/l30-prospectiva-sistemica.md` (no versionado en este repo) |

## MICMAC — qué variables mover

1. Define 4-20 variables del sistema (nombres únicos) y su matriz de
   influencias directas: enteros 0 = nada, 1 = débil, 2 = media, 3 = fuerte
   (`scale_max` opcional, por defecto 3). Filas influyen a columnas. La
   diagonal debe ser 0 (una variable no se influye a sí misma). Una matriz
   toda a cero se rechaza.
2. Ejecuta: `python3 scripts/micmac.py --matrix sistema.json [--json out.json]`
3. Cálculo (clasificación indirecta de Godet): `S_k = M + M² + … + M^k` en
   enteros exactos. Se detiene cuando el orden de influencia, el de
   dependencia y los cuadrantes se repiten 2 potencias seguidas, cuando `M^k`
   se anula (sistema acíclico) o en `k = 30` con `converged: false` (pasa en
   estructuras periódicas con variables pegadas al eje: interpreta esas
   variables con cautela). `influence` y `dependence` son % del total de
   `S_k`; `direct_*` es la clasificación sobre la matriz directa.
4. Lee cuadrantes (ejes = media; igual a la media cuenta como alto):
   - **Motriz** (influye mucho, depende poco): palanca de acción prioritaria.
   - **Dependiente** (recibe, no influye): indicador de resultado, no palanca.
   - **Enlace** (ambos altos): inestable — amplifica tanto riesgos como mejoras.
   - **Autónomo** (ambos bajos): irrelevante para el sistema actual.

## MACTOR — quién se mueve y con quién

Simplificación de MACTOR: sin matriz de influencias entre actores (MID) ni
escala -3..+3; posiciones continuas en 0..1.

1. Define 2-6 actores (nombres únicos) y al menos un eje en `axes`, con
   `positions` (0..1 por eje, obligatoria), `stake` (0..1, cuánto les importa
   cada eje; por defecto 0.5) y `power` (0..1; por defecto 0.5). El poder
   total no puede ser 0.
2. Ejecuta: `python3 scripts/mactor.py --actors actores.json [--threshold 0.7]`
3. Lee: `pairs[].divergence` (distancia de posiciones ponderada por el stake
   común, `min` de ambos stakes por eje; `null` si no comparten ningún eje
   que les importe), `divergences` (divergencia ≥ 0.5), `alliances`
   (convergencia = 1 − divergencia ≥ umbral, 0..1), `agreement_zone`
   (centroide ponderado por poder + `spread` = máx − mín de posiciones por eje).

## Salida y códigos

JSON determinista (claves ordenadas, sin timestamps) por stdout y, con
`--json`, el mismo contenido a fichero. Exit 0 ok · 2 entrada inválida,
argumentos inválidos o salida no escribible · 1 `--self-test` fallido.

## Límites declarados (honestidad de método)

- El encuadre de variables y actores es **input humano**: el método no
  sustituye el juicio de quien define la matriz (R4 del preregistro).
- Análisis estático: no adapta el sistema; complementar con vigilancia (V4).
- Una sola corrida no valida nada: las predicciones se backtestean (L30-F3).

## Related

- Roadmap: `labs/roadmaps/l30-prospectiva-sistemica.md` (F2: caso real, F3: backtesting)
- Mapa de verificación: `docs/harness-map.md` (L28)
