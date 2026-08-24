# Spec: SE-342 — Capa de Inteligencia de Datos Local

**Task ID:**        SE-342
**PBI padre:**      SE-342 — Datos + IA sobre infraestructura propia
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-23
**Creado por:**     Savia (benchmark de plataforma lakehouse de referencia)

**Developer Type:** agent-team
**Asignado a:**     python-developer + typescript-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 20 h (5 slices) |
| Human effort | 24 h |
| Review effort | 2 h |
| Context risk | medium |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 12h (catálogo y monitor de calidad son los delicados) |

---

## 1. Contexto y Objetivo

La operadora pidió analizar qué hace una **plataforma lakehouse de referencia**
(plataforma comercial unificada de datos + IA, operada en la nube de terceros),
qué funciones de IA ofrece, cuáles de esas capacidades ya existen en Savia y
cuáles nos interesaría desarrollar. La instrucción es explícita: **no se cita la
marca en ningún documento o archivo de Savia** — esta spec la denomina
genéricamente "la plataforma de referencia".

El análisis completo (qué hace, stack de IA, mapeo contra Savia, gaps) está en
el §2. La conclusión operativa:

- Savia **ya cubre** el núcleo de datos + IA de la plataforma de referencia con
  stack 100 % local: ingestión/digestión, memoria y cúpulas, grafo de
  conocimiento, entrenamiento y despliegue de SLMs propios, embeddings, RAG
  híbrido, agentes orquestados y tribunales de calidad.
- Lo que la plataforma de referencia ofrece **y Savia no tiene** se reduce a
  cinco piezas de capa de datos/IA: catálogo de activos con lineage,
  experiment tracking, monitor de calidad de datos + feature store, gateway de
  modelos, y predicción asistida local. Todas construibles sobre sustrato propio
  (SQLite, git, Ollama/LocalAI, Unsloth, sentence-transformers, scikit-learn).

**Por qué NO se adopta la plataforma de referencia:** es cloud-managed y gestiona
los datos del cliente dentro de su perímetro. Eso viola **[CRIT-001]** — ante
opciones equivalentes gana la que mantiene los datos en infraestructura propia;
datos N3+ jamás salen a proveedor cloud, ni siquiera temporalmente o anonimizados
a mano — y la soberanía (ART-07, ART-17 de la Constitución). No hay opción
equivalente "autoalojada" de esa plataforma: su modelo de negocio ES la gestión
en su perímetro. Por tanto la decisión es desarrollar los equivalentes locales.

**Objetivo de esta spec:** cerrar los cinco gaps con slices incrementales,
cada uno con criterios de aceptación y esfuerzo, priorizados por valor y
dependencia. Cada slice mantiene la regla de cero fuga de datos (SE-093) y el
patrón local-first ya probado en SE-027/SE-296/SE-304/SE-280.

---

## 2. Análisis de la plataforma de referencia y mapeo contra Savia

### 2.1 Qué hace la plataforma de referencia

**Núcleo de datos (arquitectura "lakehouse"):** unifica lago de datos y warehouse
sobre formatos abiertos con transacciones ACID; computación distribuida;
motor de consulta SQL; BI conversacional (chatbot que responde a preguntas de
negocio sobre los datos); pipelines de datos declarativos con orquestación;
streaming y procesamiento transaccional-analítico en una sola copia; catálogo
unificado de datos con gobernanza, linaje y control de acceso; compartición de
datos entre organizaciones; y monitorización de calidad/drift de datos.

**Stack de IA (integrado en la misma plataforma):**

| Capacidad de IA | Qué es |
|---|---|
| Entrenamiento de modelos | Fine-tuning y pre-training de LLMs sobre los datos del cliente |
| Experiment tracking | Registro de runs: parámetros, métricas, artefactos, comparación |
| Model registry | Ciclo de vida de modelos: versionado, promoción, deprecación |
| Feature store | Ingeniería de features versionados, reutilizables en entrenamiento y en producción |
| Model serving | Despliegue de modelos/LLMs como endpoints REST (real-time, streaming, batch) |
| AI gateway | Capa única de acceso a modelos con gobernanza, log de uso y payload |
| Foundation model APIs | Acceso a LLMs de terceros dentro del perímetro seguro |
| Vector search | Búsqueda vectorial para RAG sobre documentos propios |
| Agente de ciencia de datos | Agente autónomo que explora datos, construye y itera modelos |
| Framework de agentes | Entorno para construir, evaluar y desplegar agentes de IA |
| AutoML | Generación automática de modelos desde datos crudos |
| Meta-harness de agentes | Capa de interfaz común sobre agentes CLI de distintos modelos |

### 2.2 Equivalente en Savia

| # | Capacidad de la referencia | Equivalente en Savia (real, local) | Estado |
|---|---|---|---|
| 1 | Lakehouse (lago+warehouse ACID) | Cúpulas SaviaVaults (git-backed) + knowledge-graph (SQLite) + memoria | ✅ cubierto (escala local) |
| 2 | Computación distribuida | — | ➖ no relevante a escala Savia |
| 3 | Motor SQL / consulta | sqlite3/polars + `tabular-profile.py` (estadística determinista) | ✅ cubierto |
| 4 | BI conversacional / reporting | Informes (weekly/executive/KPI), `sprint-management`, `project-update`, chat savia-web | ✅ cubierto (sin dashboard en vivo) |
| 5 | Streaming / HTAP | — | ➖ sin fuentes de streaming |
| 6 | Pipelines declarativos | `automation-scheduler` (SE-304), pipeline de digestión (excel/pdf/word/ppt), `dag-scheduling` | 🟡 parcial: sin DAG de datos versionado |
| 7 | Catálogo unificado + lineage | knowledge-graph + vaults dispersos; niveles N1-N4b en reglas | 🔴 **GAP → S1** |
| 8 | Compartición de datos | Federación de cúpulas (SE-263, SE-282, SE-331) | ✅ cubierto |
| 9 | Monitor de calidad/drift de datos | `tabular-profile.py` puntual; `savia-monitor` (infra) | 🔴 **GAP → S3** |
| 10 | Seguridad agentic | security-* agents, `confidentiality-auditor`, `commit-guardian`, N1-N4b | ✅ cubierto |
| 11 | Entrenamiento de modelos | `slm-train.sh` (SE-027, Unsloth local, SFT/DPO, export GGUF→Ollama, zero egress) | ✅ cubierto |
| 12 | Experiment tracking | — (el registry guarda versiones finales, no runs) | 🔴 **GAP → S2** |
| 13 | Model registry | `slm-registry.sh` (register/list/show/promote/deprecate por proyecto) | ✅ cubierto (extiende en S2) |
| 14 | Feature store | — | 🔴 **GAP → S3** |
| 15 | Model serving | LocalAI/Ollama + `savia-dual` (failover) + `slm-deploy.sh` + `embedding-server.py` | ✅ cubierto |
| 16 | AI gateway | — (acceso directo a endpoints locales sin log unificado) | 🔴 **GAP → S4** |
| 17 | Foundation model APIs | `savia-dual` / `emergency-mode`, contratos multi-proveedor (SE-294) | ✅ cubierto |
| 18 | Vector search / RAG | `memory-vector.py` + `embedding-server.py` + SCL-005 (híbrido) + SE-143; vaults BM25 sin vector | 🟡 parcial → **S6 (opcional)** |
| 19 | Agente de ciencia de datos | `tabular-analyst` (describe; no predice); orquestador SAGI | 🟡 parcial → **S5** |
| 20 | Framework de agentes + evaluación | 83 agentes, courts/tribunals, `evaluations-framework`, `verification-lattice`, spec-judge | ✅ cubierto |
| 21 | AutoML | Estadística determinista (SE-296), sin generación de modelos | 🟡 parcial → **S5** |
| 22 | Meta-harness de agentes | El workspace Savia es el harness; orquestador SAGI + subagentes | ✅ cubierto |

**Veredicto:** 15 de 22 capacidades ya están cubiertas con stack local. Los cinco
gaps reales (S1-S4 + S5) son la oportunidad de desarrollo.

---

## 3. Objetivo — slices propuestos

Orden de implementación por dependencia (S1 es la base de lineage de S2/S3):

### Slice 1 — Catálogo de activos de datos local (SaviaCatalog) [ALTA, 6h]

**Diseño:** extensión de `scripts/knowledge-graph.py` con un catálogo de activos
de datos por proyecto: datasets (ficheros digeridos y su hash), features, modelos
(registrados por `slm-registry.sh`), informes generados, y cúpulas. Cada activo
tiene nivel de confidencialidad N1-N4b (regla `context-placement-confirmation`)
y registra **lineage**: dataset → digestión → features → modelo → informe. Es el
equivalente local del catálogo unificado, sobre SQLite + git, sin ningún flujo a
cloud.

**Criterios de aceptación:**
- AC-1.1. `savia-catalog.sh register` indexa un dataset (path, hash, tamaño,
  nivel N, fuente) y `show` devuelve su ficha.
- AC-1.2. Lineage consultable: dado un modelo registrado, se listan los datasets
  de entrenamiento y los informes que lo consumen (un hop, determinista).
- AC-1.3. Nivel de confidencialidad obligatorio en `register`: un dataset sin
  nivel N declarado se rechaza.
- AC-1.4. Test BATS: registrar dataset→feature→modelo→informe produce un grafo
  de 4 nodos y 3 aristas consistentes con el CSV esperado.
- AC-1.5. No se añade ninguna dependencia de red ni proveedor externo.

**Esfuerzo:** 6h

### Slice 2 — Experiment tracking local + lineage de modelo [ALTA, 4h]

**Diseño:** extensión de `slm-registry.sh` con registro de **runs**: cada
entrenamiento (SFT/DPO) anota params (base model, epochs, lr, tokens), métricas
(final_loss, eval) y artefactos (GGUF path) junto con el dataset de origen
tomado del catálogo S1. El manifest pasa de "versión final" a "historial de
runs + versión promovida". Equivalente local de experiment tracking + registry
integrado con lineage.

**Criterios de aceptación:**
- AC-2.1. `slm-registry.sh run log --project X` crea un run con params/métricas
  y lo enlaza al dataset del catálogo S1.
- AC-2.2. `slm-registry.sh runs compare --project X` compara 2+ runs con métricas
  en tabla plana (determinista).
- AC-2.3. `promote` solo acepta un run con `final_loss` y dataset de origen
  presentes; en caso contrario falla con mensaje claro.
- AC-2.4. Test BATS: log de 3 runs + promote del mejor (por métrica explícita)
  → manifest correcto y `show` consistente.
- AC-2.5. Compatibilidad hacia atrás: manifests de `slm-registry.sh` existentes
  siguen leyéndose (migración sin pérdida).

**Esfuerzo:** 4h

### Slice 3 — Monitor de calidad de datos local + Feature Store [ALTA, 6h]

**Diseño:** dos piezas sobre la capa determinista ya probada (SE-296):

1. **Monitor de calidad:** `tabular-profile.py` gana subcomando `monitor` que
   persiste un baseline por dataset (freshness, completeness, tipos, range,
   perfil) y detecta drift en ejecuciones posteriores (schema change, missing
   > umbral, valores fuera de rango, anomalías IQR). Alertas a
   `automation-scheduler` como tarea programada.
2. **Feature store local:** registro de features versionadas (nombre, dataset
   origen, fórmula/derivación, nivel N) reutilizables entre informes y modelos.
   Persistencia en el catálogo S1.

**Criterios de aceptación:**
- AC-3.1. `monitor init` sobre un dataset guarda baseline; una mutación real del
  fixture (columna nueva, 20 % missing) → `monitor check` la reporta con diff.
- AC-3.2. Umbrales configurables por dataset (freshness días, completeness %);
  por defecto: freshness 7d, completeness 95 %.
- AC-3.3. `feature register` + `feature list` versionado; una feature reutilizada
  en dos informes aparece con lineage a ambos.
- AC-3.4. Sin fuga: los datos nunca salen del proceso local (mismo aislamiento
  que SE-093).
- AC-3.5. Test BATS: baseline→mutación→detección, y registro/reuso de feature.

**Esfuerzo:** 6h

### Slice 4 — Gateway de modelos local [MEDIA, 3h]

**Diseño:** capa única de acceso a modelos locales (Ollama/LocalAI +
`embedding-server.py` + SLMs desplegados) con: registro de uso (modelo, llamante,
tokens/tiempo), **redacción de payloads** (campos N3+ nunca se loguean — se
sustituyen por hash), límites por llamante (rate-limit local), y un endpoint
único tipo API proxy para que skills/agentes no hablen con el runtime directo.
Equivalente local del AI gateway.

**Criterios de aceptación:**
- AC-4.1. Un cliente que llama a `/v1/chat` vía el gateway recibe la respuesta del
  runtime local y el uso queda registrado en JSONL.
- AC-4.2. Payload con campo marcado N3+ se loguea redactado (hash), nunca en
  claro (verificación con grep sobre el log).
- AC-4.3. Límite por llamante configurable: excedido → 429 con cabecera
  de reintento.
- AC-4.4. Test BATS: uso registrado, redacción verificada, rate-limit respeta.

**Esfuerzo:** 3h

### Slice 5 — Predicción asistida local (tabular-analyst predict) [MEDIA, 5h]

**Diseño:** `tabular-analyst` extiende su modo "describe" con un modo "predict"
opcional: dado un dataset y una columna objetivo, entrena un modelo local
(scikit-learn, árbol/bosque/regresión según tipo), reporta métricas de
validación y guarda el artefacto en el catálogo S1 con lineage. **Nunca**
instala TFMs (se reafirma la decisión de SE-296), nunca envía datos fuera. El
resultado es un informe de viabilidad predictiva (¿hay señal?, ¿qué columnas
importan?), no un servicio en producción.

**Criterios de aceptación:**
- AC-5.1. Dataset fixture con target numérico → informe con RMSE/R² de
  validación cruzada y top-5 features por importancia.
- AC-5.2. Target categórico → precisión macro + matriz de confusión en el
  informe.
- AC-5.3. El modelo y su informe quedan registrados en el catálogo S1 con
  lineage al dataset (sin esto, el slice falla).
- AC-5.4. Columna objetivo ausente o dataset con <50 filas → respuesta
  explícita de no-viabilidad, sin entrenar.
- AC-5.5. Determinista en semilla fija: mismo dataset → mismo informe.

**Esfuerzo:** 5h

### Slice 6 — Vector store unificado en cúpulas (RAG sobre documentos) [BAJA, opcional, 4h]

**Diseño:** extiende SaviaVaults con índice vectorial local (por defecto el mismo
`embedding-server.py`) en modo híbrido BM25+vector sobre las notas de cúpula,
para RAG sobre documentos completos (no solo memoria del sistema). No es nuevo
motor: es la consolidación de SCL-005/SE-143 dentro del vault.

**Criterios de aceptación:**
- AC-6.1. `vault search --hybrid "consulta"` devuelve resultados fusionados
  BM25+vector con puntuación combinada determinista.
- AC-6.2. Índice vectorial versionado y reconstruible (`vault index --rebuild`).
- AC-6.3. Las notas de nivel N3+ no se embeben fuera de la cúpula local.

**Esfuerzo:** 4h (opcional, se decide en aprobación)

---

## 4. Fuera de alcance

- **NO** se adopta la plataforma de referencia ni ningún servicio cloud-managed
  de datos/IA (CRIT-001).
- **NO** streaming ni procesamiento transaccional-analítico: Savia no tiene
  fuentes de streaming hoy; cuando existan se revisa.
- **NO** computación distribuida tipo Spark: escala innecesaria para el volumen
  de Savia (SQLite + git cubren).
- **NO** dashboard BI en vivo multi-usuario: se cubre con informes y chat
  savia-web.
- **NO** instalación de TFMs (TabPFN/TabICL/Kumo) ni AutoML de terceros:
  reafirma la decisión de SE-296 (describir y, ahora, predecir con estadística
  y modelos clásicos locales, nunca datos fuera).

---

## 5. Priorización y dependencias

```
S1 Catálogo (lineage base) ──► S2 Experiment tracking
                          └──► S3 Monitor de calidad + features
S4 Gateway de modelos      (independiente, paralelizable)
S5 Predicción asistida     (depende de S1 para lineage de artefactos)
S6 Vector en cúpulas       (opcional, independiente)
```

Orden sugerido: **S1 → S3 → S2 → S4 → S5**, con S6 a decisión de la operadora.
Racional: S1 da el sustrato de lineage; S3 cierra el riesgo de datos podridos
(coste más alto de no hacerlo); S2 da el ciclo de vida de modelos; S4 y S5
añaden valor de uso sin dependencias fuertes.

---

## 6. Cumplimiento CRIT-001 y reglas

- **[CRIT-001]:** todos los slices corren en infraestructura propia — SQLite,
  git, Ollama/LocalAI, Unsloth, sentence-transformers, scikit-learn. Ningún dato
  (incluido N1-N2) sale del workspace; los N3+ nunca, ni temporalmente ni
  anonimizados a mano (SE-093 zero-leak, ART-17).
- **Sin nombres comerciales:** la plataforma de referencia se denomina en toda
  esta spec "la plataforma lakehouse de referencia". No se cita su marca en
  ningún fichero de Savia (decisión de confidencialidad de la operadora).
- **Rule #8 (SDD):** ningún slice se implementa sin esta spec APPROVED.
- **Soberanía (ART-07):** todo lo nuevo es auditable localmente; el derecho al
  olvido se ejecuta sin dependencia de proveedores cloud.

---

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `savia-catalog.sh` (S1) | `scripts/savia-catalog.sh` | Script bash idéntico (PURE_BASH) |
| `slm-registry.sh` (S2) | extensión de script existente | Script bash idéntico |
| `tabular-profile.py monitor` (S3) | extensión de script existente | Script python idéntico |
| Gateway de modelos (S4) | `scripts/model-gateway.py` | Script python idéntico |
| `tabular-analyst predict` (S5) | agente `.opencode/agents/` | Lee desde AGENTS.md generado |
| Vector en cúpulas (S6) | `savia-vaults` skill + MCP | MCP server existente |

### Verification protocol

- [ ] Funciona en runtime OpenCode (no solo Claude Code)
- [ ] Tests BATS por slice cubren ambos paths (S1-S4, S6) o marcan SKIP justificado (S5 agente)
- [ ] Si añade hooks: registrados en plugin `savia-gates`

### Portability classification

- [x] **PURE_BASH** para S1-S4 y S6: lógica en scripts bash/python sin bindings
  de frontend; corren idéntico en cualquier motor. S5 es DUAL_BINDING (agente
  registrado en AGENTS.md, ya cubierto por SE-078). Justificado: el núcleo de
  datos es tooling local, no frontend.

---

## Referencias

- SE-027 (entrenamiento SLM local), SE-296/SE-324 (tabular intelligence),
  SE-304 (automation scheduler), SE-280..SE-331 (savia-vaults),
  SE-093 (zero-leak), SE-263/SE-282/SE-331 (federación), SCL-005 (embeddings
  híbridos), SE-143 (vector search), SE-294 (multi-proveedor).
- Análisis de estado 2026-08-23: `docs/savia-future-analysis-2026-08-23.md`.
- Criterios humanos: CRIT-001 (infraestructura propia), regla
  `context-placement-confirmation` (N1-N4b), `spec-opencode-implementation-plan`.
