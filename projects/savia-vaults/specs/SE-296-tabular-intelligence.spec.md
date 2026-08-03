# Spec: SE-296 — Tabular Intelligence Agent + Skill

**Task ID:**        SE-296
**PBI padre:**      SE-296 — Analisis tabular nativo
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-02
**Creado por:**     Savia (analisis de articulo)

**Developer Type:** agent-single
**Asignado a:**     typescript-developer + python-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 60 min |
| Human effort | 3 h |
| Review effort | 20 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 1.5h |

---

## 1. Contexto y Objetivo

Savia opera con datos tabulares constantemente: sprints, backlogs, timesheets,
KPIs, metricas de equipo, informes financieros. El patron actual es volcar esos
datos como texto y pasarlos al LLM, lo cual:

1. **Destruye distribuciones**: "velocity: 32, 30, 28, 35" pierde media,
   varianza, tendencia cuando se tokeniza como texto.
2. **Es costoso en tokens**: una tabla de 200 filas x 10 columnas son ~4000
   tokens en texto plano. Como estadisticos son ~200 tokens.
3. **Es fragil**: cambiar el orden de filas altera la respuesta del LLM.

Objetivo: Añadir a Savia capacidad de razonamiento tabular nativo — detectar
cuando un problema es estadistico, procesarlo con herramientas adecuadas
(Python/pandas, scipy), y alimentar al LLM con **resumenes estadisticos**
en vez de datos brutos.

Inspirado en el principio "no fuerces datos tabulares por LLMs" del analisis
del articulo de Roberto Jara Peche (2026-08-02) y refinado con estudio de los
tres modelos lideres en TFMs:

- **TabPFN** (Prior Labs / U. Freiburg): zero-training philosophy — una pasada,
  sin entrenamiento. Arquitectura de atencion alternante fila/columna. Max 10K.
- **TabICL** (Inria/SODA, ICML 2025): procesamiento column-first en dos etapas.
  Escala a 500K muestras. Open source.
- **KumoRFM** (Kumo.AI/Snowflake): modelado relacional multi-tabla como grafo.
  SQL-like prompting. MCP server para agentes.

**Diferenciador de Savia**: los TFMs predicen. Savia necesita describir, detectar
patrones y resumir. No necesitamos un modelo fundacional — necesitamos estadistica
deterministica, exacta y explicable. La spec toma prestados tres patrones
arquitectonicos: zero-training (TabPFN), column-first (TabICL), MCP tool +
relational detection (KumoRFM).

---

## 2. Contrato Tecnico

### 2.1 Tabular Intelligence Skill

```markdown
# Skill: tabular-intelligence

Triggers: 'analiza esta tabla', 'metricas del sprint', 'tendencia de',
          'distribucion de', 'correlacion entre', 'KPIs', 'datos financieros'

Pipeline:
1. DETECT: identificar si el prompt contiene datos tabulares (CSV, JSON array,
   tabla markdown, referencia a Excel)
2. EXTRACT: extraer datos a estructura columnar (pandas DataFrame)
3. ANALYZE: computar estadisticos — media, mediana, std, min, max, quartiles,
   skewness, tendencia (regresion lineal simple), deteccion de outliers (IQR)
4. SUMMARIZE: generar resumen compacto para el LLM (~200 tokens max)
5. REASON: el LLM razona sobre el resumen estadistico, no sobre los datos brutos
```

### 2.2 Tabular Intelligence Agent

Agent `tabular-analyst` (mid tier):
- Recibe: ruta a fichero (CSV, XLSX) o datos inline
- Analiza: tipos de columna (numerica, categorica, datetime, texto)
- Computa: perfil estadistico completo
- Detecta: outliers, missing values, patrones temporales
- Output: informe estructurado + resumen LLM-friendly

### 2.3 Tipos

```typescript
interface ColumnProfile {
  name: string;
  type: 'numeric' | 'categorical' | 'datetime' | 'text';
  count: number;
  nulls: number;
  unique: number;
  // Numeric-only
  mean?: number;
  median?: number;
  std?: number;
  min?: number;
  max?: number;
  q25?: number;
  q75?: number;
  skewness?: number;
  outliers?: number;
  // Categorical-only
  topValues?: { value: string; count: number }[];
  // Datetime-only
  minDate?: string;
  maxDate?: string;
  trend?: 'up' | 'down' | 'stable';
  trendSlope?: number;
}

interface TabularSummary {
  rows: number;
  columns: number;
  profiles: ColumnProfile[];
  correlations?: { col1: string; col2: string; coefficient: number }[];
  tokenEstimate: { raw: number; summary: number; savings: number };
}
```

### 2.4 MCP Tool: tabular_query (inspirado en KumoRFM MCP)

```typescript
// MCP tool expuesta via SaviaVaults
tool tabular_query {
  description: "Query tabular data with natural language. Returns stats, not predictions."
  parameters: {
    source: string       // path to CSV/XLSX/JSON or inline data
    question: string     // natural language: "trend de velocity", "outliers en bugs"
    max_rows?: number    // sample limit (default 10000)
  }
  returns: {
    answer: string       // human-readable statistical answer
    profile: TabularSummary  // structured profile
    confidence: "exact" | "sampled" | "estimated"
  }
}
```

### 2.5 Cross-Table Relationship Detection (inspirado en KumoRFM)

```typescript
interface CrossTableRelation {
  table_a: string;
  column_a: string;
  table_b: string;
  column_b: string;
  relation_type: "foreign_key" | "shared_values" | "temporal_dependency";
  confidence: number;  // 0-1, basado en solapamiento de valores
  unique_match_pct: number;
}
```

### 2.6 Pipeline de Analisis (actualizado)

```
CSV/XLSX/JSON → TabularIntelligence.detect()
  → TabularIntelligence.extract() → DataFrame
  → TabularIntelligence.analyze() → ColumnProfile[]
  → TabularIntelligence.summarize() → TabularSummary
  → LLM recibe resumen en vez de datos brutos
```

---

## 3. Reglas de Negocio

### RB-001: Deteccion automatica
Si el prompt contiene >5 filas de datos tabulares, activar tabular-intelligence
automaticamente. No esperar a que el usuario lo pida.

### RB-002: Routing por tipo de columna
- Columnas numericas → estadisticos descriptivos
- Columnas categoricas → distribucion de frecuencias (top N)
- Columnas datetime → tendencia temporal, estacionalidad
- Columnas texto → ignorar en analisis estadistico (pasan al LLM como metadata)

### RB-003: Token budget
El resumen estadistico no puede exceder 200 tokens. Si una tabla tiene >50
columnas, seleccionar las 20 mas informativas (mayor varianza, menor
correlacion entre si).

### RB-004: Zero hallucination on numbers
Los numeros en el resumen son EXACTOS (copiados del computo, nunca generados).
El LLM solo interpreta tendencias y patrones, no recalcula.

### RB-005: Large dataset handling
Si la tabla tiene >100k filas, usar muestreo estratificado (max 10k)
preservando distribucion de columnas categoricas.

---

## 4. Constraints and Limits

- Procesamiento local (Python/pandas), sin enviar datos a APIs externas
- Maximo 50MB por fichero
- Timeout: 30s para analisis completo
- Columnas de texto: max 100 chars por valor en resumen
- El LLM NUNCA recibe datos brutos — solo el resumen estadistico

---

## 5. Test Scenarios

### TC-001: Tabla de sprints
```
GIVEN tabla con columnas: sprint, velocity, bugs, team_size (10 filas)
WHEN tabular-intelligence analiza
THEN produce perfil con media/mediana/std de velocity y bugs
AND detecta tendencia de velocity (up/down/stable)
AND resumen < 200 tokens
```

### TC-002: Token savings
```
GIVEN tabla de 200 filas x 10 columnas (~4000 tokens en bruto)
WHEN se genera resumen estadistico
THEN tokenEstimate.summary < 200
AND tokenEstimate.savings > 90%
```

### TC-003: Large dataset sampling
```
GIVEN CSV con 500k filas
WHEN se analiza
THEN usa max 10k filas con muestreo estratificado
AND distribucion de categorias preservada (+-5%)
```

### TC-004: Mixed column types
```
GIVEN tabla con numeric(age, salary) + categorical(department) + datetime(hire_date)
THEN cada columna tiene el tipo correcto
AND age/salary tienen estadisticos numericos
AND department tiene top values
AND hire_date tiene tendencia temporal
```

### TC-005: Outlier detection
```
GIVEN columna numerica con valores [10,12,11,13,10,500,11,12]
THEN detecta 500 como outlier (IQR method)
AND lo reporta en el resumen
```

### TC-006: Cross-table FK detection
```
GIVEN tabla A con columna "user_id" y tabla B con columna "id" (80% solapamiento)
WHEN se analizan ambas
THEN detecta relacion foreign_key entre A.user_id y B.id
AND confidence > 0.8
```

### TC-007: MCP tabular_query natural language
```
GIVEN tabla de sprints con columnas sprint, velocity, bugs
WHEN tabular_query("¿cual es la tendencia de velocity en los ultimos sprints?")
THEN answer contiene "tendencia: up/down/stable"
AND answer contiene valores numericos exactos
AND confidence es "exact"
```

### TC-009: Pre-LLM hook detects and profiles
```
GIVEN prompt con tabla markdown de 10 filas x 5 columnas
WHEN pre-llm-tabular-detect.sh analiza el prompt
THEN detecta datos tabulares (>5 filas)
AND ejecuta tabular-profile.py
AND sustituye la tabla por perfil estadistico en el prompt
AND el prompt resultante NO contiene la tabla original
```

### TC-010: Self-audit warns on bypass
```
GIVEN turno donde el LLM recibio tabla de 20 filas
AND tabular-profile.py NO fue ejecutado
WHEN tabular-self-audit.sh analiza el turno
THEN emite WARN: "datos tabulares detectados sin perfil estadistico"
AND registra en audit log
```

### TC-011: Self-audit escalates on repetition
```
GIVEN 3 turnos consecutivos con bypass detectado
WHEN tabular-self-audit.sh analiza
THEN emite BLOCK: "patron de bypass detectado. Usa tabular_query."
AND exit code != 0
```
```
GIVEN cualquier dataset tabular
WHEN se ejecuta tabular-profile.py
THEN no descarga pesos de modelo
AND no entrena ningun modelo
AND no requiere GPU
AND tiempo de ejecucion < 5s para <10K filas
```

---

## 6. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `.opencode/skills/tabular-intelligence/SKILL.md` | Skill definition |
| `.opencode/skills/tabular-intelligence/DOMAIN.md` | Domain knowledge |
| `.opencode/agents/tabular-analyst.md` | Agent definition |
| `scripts/tabular-profile.py` | Python script: analisis estadistico |
| `scripts/tabular-cross-table.py` | Python script: deteccion FK entre tablas |
| `scripts/tabular-summarize.sh` | Bash wrapper: detecta + extrae + resume |
| `scripts/tabular-mcp-tool.sh` | MCP tool wrapper: query NL + devuelve stats |
| `scripts/tabular-self-audit.sh` | Post-turno: verifica que se uso la herramienta |
| `.opencode/hooks/pre-llm-tabular-detect.sh` | Hook: detecta tablas en prompt, inyecta perfil |
| `.opencode/hooks/post-turn-tabular-audit.sh` | Hook: self-audit de uso de herramienta |
| `tests/test-tabular-profile.bats` | BATS tests |
| `tests/test-tabular-cross-table.bats` | Cross-table tests |
| `tests/test-tabular-enforcement.bats` | Enforcement: deteccion, routing, self-audit |

### Modificar

| Fichero | Cambio |
|---|---|
| `SKILLS.md` | Añadir tabular-intelligence |
| `docs/RESOLVER.md` | Añadir routing |

---

## 10. Integration & Enforcement Architecture

El riesgo no es que la herramienta no funcione — es que Savia la ignore.
Cuatro capas de enforcement progresivo garantizan que los datos tabulares
nunca lleguen crudos al LLM.

### Capa 1: Deteccion automatica en prompt (Pre-LLM Hook)

```
Usuario pregunta → Hook pre-LLM analiza el prompt
  → ¿Contiene >5 lineas de datos tabulares?
    NO  → pasa directo al LLM
    SI  → inyecta instruccion: "Usa tabular_query para analizar estos datos.
           NO interpretes los datos tu mismo. Adjunto perfil estadistico."
         → ejecuta tabular-profile.py contra los datos
         → reemplaza datos brutos por perfil estadistico en el prompt
         → el LLM solo ve el resumen, nunca los datos crudos
```

### Capa 2: RESOLVER.md routing (Intencion → Skill)

```yaml
# docs/RESOLVER.md — OVERRIDE section
tabular-intelligence:
  triggers:
    - "analiza (esta|los|las) (tabla|datos|csv|excel|metricas)"
    - "tendencia de"
    - "distribucion de"
    - "correlacion entre"
    - "outlier"
    - "perfil estadistico"
    - "resumen de datos"
  skill: tabular-intelligence
  agent: tabular-analyst
  priority: high
  auto_activate: true
```

### Capa 3: Agentes que exigen datos perfilados

Los agentes que trabajan con datos (business-analyst, controlling-kpi-analyst,
finance-cash-flow-analyst) reciben en su prompt de sistema:

```
ANTES de analizar cualquier dato numerico o tabular, invoca SIEMPRE
la herramienta tabular_query. El analisis directo de datos tabulares
sin perfil estadistico previo esta prohibido. Si recibes un perfil
estadistico, INTERPRETALO — nunca recalcules numeros.
```

### Capa 4: Self-audit post-turno

```bash
# scripts/tabular-self-audit.sh
# Se ejecuta tras cada turno. Detecta si el LLM recibio datos tabulares
# sin pasar por el perfil estadistico.

1. Escanea el prompt del turno en busca de datos tabulares (>5 filas)
2. Verifica si tabular-profile.py fue invocado durante el turno
3. Si datos detectados y herramienta NO usada → WARN en self-audit
4. Si patron se repite 3+ turnos → bloquea y exige usar la herramienta
```

### Diagrama de flujo completo

```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIO / AGENTE                          │
│  "analiza la tendencia de velocity en estos datos: [CSV]"   │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │  CAPA 1: Pre-LLM Hook   │
              │  Detecta >5 filas?      │
              │  Extrae + perfil +      │
              │  sustituye datos brutos │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  CAPA 2: Configurator   │
              │  Routing RESOLVER.md    │
              │  → tabular-intelligence │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  CAPA 3: Agent Prompt   │
              │  "Usa tabular_query"    │
              │  LLM recibe perfil      │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  CAPA 4: Self-audit     │
              │  ¿Se uso la herramienta?│
              │  NO → WARN / BLOCK      │
              └─────────────────────────┘
```

---

## 7. Estado de Implementacion

| Slice | Estado | Descripcion |
|---|---|---|
| S1: Python core | Pendiente | `tabular-profile.py` con pandas |
| S2: Skill | Pendiente | SKILL.md + DOMAIN.md |
| S3: Agent | Pendiente | Agente tabular-analyst |
| S4: Integration | Pendiente | Bash wrapper + RESOLVER routing |
| S5: Tests | Pendiente | BATS tests |

---

## 8. Checklist Pre-Entrega

- [ ] `tabular-profile.py` genera JSON con perfiles de columna correctos
- [ ] Detecta tipos de columna automaticamente
- [ ] Resumen < 200 tokens para tablas de cualquier tamano
- [ ] Muestreo estratificado para >100k filas
- [ ] Outlier detection via IQR
- [ ] Correlacion entre columnas numericas
- [ ] Tendencia temporal para columnas datetime

---

## 9. Criterios de Aceptacion

- [ ] AC1: Skill `tabular-intelligence` registrada y funcional
- [ ] AC2: Agente `tabular-analyst` produce informe estructurado
- [ ] AC3: Ahorro de tokens >90% vs pasar datos brutos al LLM
- [ ] AC4: Numeros en resumen son exactos (zero hallucination)
- [ ] AC5: Routing automatico cuando el prompt contiene datos tabulares
- [ ] AC6: MCP tool `tabular_query` acepta preguntas en lenguaje natural
- [ ] AC7: Zero-training: sin descarga de modelos, sin GPU, sin entrenamiento
- [ ] AC8: Deteccion de relaciones cross-table entre CSVs (FK detection)
- [ ] AC9: Pre-LLM hook detecta >5 filas tabulares y sustituye por perfil
- [ ] AC10: Self-audit detecta cuando NO se uso la herramienta y emite WARN
- [ ] AC11: Agentes de datos (business-analyst, KPI, finance) exigen perfil en su prompt
