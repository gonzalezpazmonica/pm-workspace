# Spec: SE-324 — Tabular Intelligence: soporte Excel, deteccion relacional y correccion de citas

**Task ID:**        SE-324
**PBI padre:**      SE-296 — Analisis tabular nativo (extension, no reescritura)
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-07
**Creado por:**     Savia (auditoria de SE-296 contra el articulo original)

**Developer Type:** agent-single
**Asignado a:**     python-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 5 h |
| Human effort | 10 h |
| Review effort | 40 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 5h |

---

## 1. Origen

Auditoria de SE-296 (mergeado #927, #933) contra el articulo de Roberto Jara
Peche que lo origino. El nucleo es solido — estadistica determinista en Python
puro, enforcement en cuatro capas, zero dependencias — y no se toca. Se
encontraron tres huecos concretos entre lo prometido y lo entregado.

## 2. Hallazgos

1. **Excel no soportado pese a declararse.** El frontmatter de la skill
   promete "CSV, Excel, tablas, metricas" como triggers; `tabular-profile.py`
   solo lee CSV/TSV/JSON. Un `.xlsx` real falla silenciosamente o no se
   detecta.
2. **Sin deteccion relacional.** Es el diferenciador que el propio DOMAIN.md
   atribuye a KumoRFM (grafo relacional vs. aplanar en CSV) y que SE-296
   deliberadamente no cubrio. Multiples hojas de un Excel o varios CSV con
   claves compartidas se perfilan por separado, sin detectar la relacion.
3. **Citas desactualizadas.** DOMAIN.md no menciona TabFM (Google, el modelo
   que da titulo al articulo origen) y atribuye KumoRFM a "Kumo.AI/Snowflake"
   cuando la adquisicion por Nvidia (junio 2026, $400M) hace esa atribucion
   la vigente hoy.

## 3. Objetivo

Cerrar los tres huecos sin tocar el nucleo de enforcement ya probado.

### Slice 1 — Soporte de Excel (.xlsx)

**Diseno:** extension de `tabular-profile.py` con lectura de `.xlsx` via
`openpyxl` (unica dependencia nueva, justificada: es la libreria estandar
minima para XLSX sin pandas). Deteccion de multiples hojas; cada hoja se
perfila como tabla independiente en esta capa, con su nombre de hoja en el
resultado. El hook `pre-llm-tabular-detect.sh` extiende su heuristica de
deteccion a rutas de fichero `.xlsx` ademas del contenido inline.

**Criterios de aceptacion:**
- AC-1.1. `.xlsx` con 3 hojas produce un perfil por hoja, cada uno con su
  nombre.
- AC-1.2. Fichero `.xlsx` con formulas → valores calculados leidos, no la
  formula como texto.
- AC-1.3. Test BATS: perfil de un `.xlsx` de fixture coincide en cifras con
  el mismo dato en CSV equivalente.
- AC-1.4. openpyxl declarado como dependencia opcional: su ausencia degrada
  a "Excel no soportado en este entorno" en vez de fallar sin explicacion.

**Esfuerzo:** 4h

### Slice 2 — Deteccion relacional basica

**Diseno:** cuando se perfilan multiples tablas en la misma invocacion
(varias hojas de un Excel, o varios CSV pasados juntos), `tabular-profile.py`
detecta columnas candidatas a clave compartida por coincidencia de nombre y
solape de valores (no inferencia semantica, deterministico). El perfil
resultante anade una seccion `relations` con los pares de tabla-columna
candidatos y el porcentaje de solape. **No se construye un grafo ni se
modela como KumoRFM**: es deteccion de candidatos para que el LLM sepa que
dos tablas se relacionan antes de razonar sobre ellas por separado, que es
el problema concreto que el articulo senala.

**Criterios de aceptacion:**
- AC-2.1. Dos tablas de fixture con columna `id_cliente` compartida →
  relacion detectada con solape medido.
- AC-2.2. Dos tablas sin columnas relacionables → seccion `relations` vacia,
  no forzada.
- AC-2.3. Deterministico: mismo par de tablas → mismo resultado.
- AC-2.4. Coste declarado: la deteccion es O(n*m) sobre valores unicos, con
  tope de filas de muestreo para no volverse cara en tablas grandes.

**Esfuerzo:** 4h

### Slice 3 — Correccion de citas

**Diseno:** `DOMAIN.md` actualizado: TabFM (Google, hibrido de TabPFN+TabICL,
junio 2026) anadido como referencia principal junto a TabPFN y TabICL;
atribucion de KumoRFM corregida a Kumo.AI, adquirida por Nvidia (2026-06).

**Criterios de aceptacion:**
- AC-3.1. DOMAIN.md menciona los tres modelos del articulo origen (TabFM,
  TabICL, KumoRFM) con atribucion vigente.
- AC-3.2. CHANGELOG.d con entrada de correccion documental.

**Esfuerzo:** 2h

## 4. Fuera de alcance

- NO se instala TabPFN/TabICL/TabFM ni sus pesos: la decision de SE-296 de no
  adoptar TFMs literales se mantiene y se reafirma.
- NO se construye grafo relacional completo ni PQL: la deteccion de S2 es
  deliberadamente minima, suficiente para el caso de uso de Savia (describir,
  no predecir).
- NO se tocan los hooks de enforcement de las capas 2-4 de SE-296: siguen
  funcionando sobre el nucleo existente.

---

## 5. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/specs/SE-324-tabular-intelligence.spec.md` | Esta spec |
| `tests/bats/test-se324-tabular-excel.bats` | BATS tests (AC-1.x, AC-2.x) |
| `tests/fixtures/tabular/ventas.csv` | Fixture CSV equivalente |
| `tests/fixtures/tabular/ventas_one.xlsx` | Fixture xlsx 1 hoja (AC-1.3) |
| `tests/fixtures/tabular/ventas_multi.xlsx` | Fixture xlsx 3 hojas (AC-1.1, AC-2.x) |
| `tests/fixtures/tabular/formulas.xlsx` | Fixture xlsx con formula + valor cacheado (AC-1.2) |
| `tests/fixtures/tabular/clientes.csv` | Fixture relacion (AC-2.1) |
| `tests/fixtures/tabular/pedidos.csv` | Fixture relacion (AC-2.1) |
| `tests/fixtures/tabular/generate_fixtures.py` | Generador determinista de fixtures xlsx |
| `CHANGELOG.d/se324-tabular-intelligence.md` | Entrada de correccion documental (AC-3.2) |

### Modificar

| Fichero | Cambio |
|---|---|
| `scripts/tabular-profile.py` | Lectura `.xlsx` (openpyxl, opcional), multi-tabla, `relations` |
| `.claude/hooks/pre-llm-tabular-detect.sh` | Deteccion de rutas `.xlsx` en el prompt |
| `.claude/skills/tabular-intelligence/DOMAIN.md` | Citas TabFM + KumoRFM/Nvidia (AC-3.1) |
| `.opencode/skills/tabular-intelligence/DOMAIN.md` | Idem (copia del frontend) |

---

## 6. Criterios de Aceptacion Finales

- [ ] AC-1.1 a AC-1.4 (Slice 1): Excel por hoja, formulas calculadas,
      fixture BATS, degradacion explicita
- [ ] AC-2.1 a AC-2.4 (Slice 2): relations determinista, vacia si no hay,
      coste acotado
- [ ] AC-3.1 a AC-3.2 (Slice 3): DOMAIN.md con TabFM + KumoRFM/Nvidia,
      CHANGELOG.d presente
- [ ] Tests SE-296 existentes (`tests/test-tabular-profile.bats`,
      `tests/test-tabular-enforcement.bats`) siguen pasando sin cambios
