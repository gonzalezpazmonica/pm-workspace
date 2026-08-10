# SE-324 — Legacy Analysis: Tabular Intelligence gaps

> Agent note — 2026-08-07 · Analyst: Savia · Spec: `SE-324-tabular-intelligence.spec.md`

## Resumen

Auditoria de la entrega SE-296 (PRs #927, #933) contra el articulo origen de
Roberto Jara Peche. El nucleo (estadistica determinista, enforcement en 4
capas, zero dependencias) es solido y NO se modifica. Se confirman los tres
huecos declarados en la spec.

## Evidencia por hallazgo

### H1 — Excel no soportado

- `scripts/tabular-profile.py:197-207`: `read_data()` solo ramifica por
  extension `.json`; todo lo demas se intenta como CSV. Un `.xlsx` genera un
  `csv.DictReader` sobre bytes binarios → perfil basura o error silencioso.
- Frontmatter de la skill promete "CSV, Excel, tablas, metricas".
- Hook `pre-llm-tabular-detect.sh`: solo cuenta lineas CSV/markdown inline,
  no detecta rutas de fichero `.xlsx`.

### H2 — Sin deteccion relacional

- `main()` perfila una sola fuente (el ultimo argumento gana; los anteriores
  se descartan). No hay concepto de multiples tablas.
- `DOMAIN.md` atribuye el diferenciador a KumoRFM (grafo relacional) pero la
  implementacion no detecta claves compartidas.

### H3 — Citas desactualizadas

- `DOMAIN.md` menciona TabPFN, TabICL, KumoRFM pero NO TabFM (el modelo que
  titula el articulo origen, Google).
- `DOMAIN.md` y `SE-296...spec.md` atribuyen KumoRFM a "Kumo.AI/Snowflake";
  la atribucion vigente es Kumo.AI, adquirida por Nvidia (2026-06, $400M).

## Decisiones de diseno

1. **openpyxl como unica dependencia nueva (opcional).** Libreria estandar
   minima para XLSX sin pandas. Si falta → degradacion explicita
   "Excel no soportado en este entorno" (AC-1.4), nunca fallo silencioso.
   Lectura con `data_only=True` para valores calculados (AC-1.2).
2. **Formato de salida: retrocompatible.** Tabla unica → formato plano
   actual (`rows/columns/profiles/correlations/token_estimate`), que es el
   que consumen los tests SE-296 y el hook. Multiples tablas (xlsx multi-hoja
   o varios ficheros) → `{"tables": [...], "relations": [...]}`.
3. **Relaciones deterministas, sin inferencia semantica.** Candidato = mismo
   nombre de columna (normalizado a minusculas/trim) Y solape de valores > 0.
   `overlap_pct = |A∩B| / min(|A|,|B|)`. Tope de muestreo de valores unicos
   por columna (2000) para acotar coste (AC-2.4). Output ordenado → AC-2.3.
4. **Hook:** deteccion temprana de rutas `.xlsx` en el prompt ANTES del gate
   de lineas tabulares; se perfila el fichero y se sustituye por el perfil.

## Seguridad (gate pre-implementacion)

No toca auth, pagos, PII, APIs publicas ni infraestructura. Procesa datos
tabulares locales. Riesgo bajo → no se requiere security-review formal.
Nota: openpyxl lee formulas como valores calculados (no ejecuta macros);
`.xlsm` con macros queda fuera de alcance (solo `.xlsx`).

## Verificacion

- BATS nuevos `tests/bats/test-se324-tabular-excel.bats` (AC-1.1..1.4, AC-2.1..2.4).
- BATS SE-296 existentes deben pasar sin cambios.
- openpyxl es opcional: tests de lectura XLSX hacen `pip3 install openpyxl`
  si falta; tests de degradacion y relaciones (CSV) corren siempre.

## Pendiente documental

- `SE-296...spec.md` conserva la atribucion antigua de KumoRFM; queda fuera
  de alcance (documento historico), se corrige solo `DOMAIN.md` (AC-3.1).
