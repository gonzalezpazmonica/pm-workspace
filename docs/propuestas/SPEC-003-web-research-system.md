---
id: SPEC-003
title: SPEC-003: Savia Web Research — Búsqueda web para resolver gaps de contexto
status: Proposed
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-003: Savia Web Research — Búsqueda web para resolver gaps de contexto

> Status: **DRAFT** · Fecha: 2026-03-21
> Inspirado en: FAIR-Perplexica (UB-Mannheim), autoresearch (Karpathy)

---

## Problema

Savia opera como sistema cerrado: solo conoce lo que está en el workspace,
en Azure DevOps, o en la memoria del usuario. Cuando encuentra un gap de
contexto (versión actual de una librería, API de un servicio externo,
best practice de un framework, CVE reciente), no puede resolverlo
autónomamente — depende de que el humano copie/pegue la información.

**Casos reales:**
- "¿Qué versión de EF Core soporta bulk operations?" → Savia no sabe
- "¿El SDK de Azure tiene rate limiting por defecto?" → necesita docs
- "¿Hay CVEs recientes para log4j 2.x?" → necesita NVD/GitHub Advisory
- "¿Cuál es la sintaxis de un workflow de GitHub Actions?" → necesita docs

## Solución

Sistema de 3 capas que permite a Savia buscar información pública en la
web cuando detecta un gap de contexto, con degradación graceful si no hay
conectividad.

---

## Arquitectura: 3 Capas de Búsqueda

```
Capa 1 — LOCAL (sin red, 0 tokens)
  Cache de búsquedas previas + docs offline pre-descargados
  Fuente: ~/.savia/web-cache/
  TTL: 7 días (configurable)

Capa 2 — CLAUDE TOOLS (con red, bajo coste)
  WebSearch + WebFetch nativos de Claude Code
  Fuente: herramientas built-in de Claude Code
  Sin dependencias externas

Capa 3 — SEARXNG (con red, auto-hosted, máxima privacidad)
  Instancia SearxNG local via Docker (opcional)
  API: GET /search?q={query}&format=json&engines={lista}
  Fuente: metasearch sobre 70+ motores
  Sin tracking, sin cookies, sin perfilado
```

### Flujo de resolución

```
Savia detecta gap de contexto
  ↓
¿Existe en cache local? (Capa 1)
  → Sí: usar cache, citar como [cache:{fecha}]
  → No ↓
¿Hay conexión a internet?
  → No: informar gap, sugerir /emergency-mode
  → Sí ↓
¿SearxNG disponible? (Capa 3)
  → Sí: buscar en SearxNG (más engines, más privacidad)
  → No ↓
Usar WebSearch/WebFetch de Claude Code (Capa 2)
  ↓
Parsear resultados → reranking por relevancia → cachear
  ↓
Inyectar en contexto con citación inline [web:{fuente}]
```

---

## Detección de Gaps

### Triggers automáticos (Savia detecta)

| Señal | Ejemplo | Acción |
|-------|---------|--------|
| Pregunta sobre versión | "¿qué versión de X...?" | Buscar release notes |
| API desconocida | "¿cómo se configura Y?" | Buscar documentación |
| CVE/seguridad | "¿es vulnerable Z?" | Buscar NVD + GitHub Advisory |
| Error sin contexto | Stack trace de librería externa | Buscar issue tracker |
| Comparativa | "¿X o Y para nuestro caso?" | Buscar benchmarks |
| Regulación | "¿cumple GDPR el servicio Z?" | Buscar compliance docs |

### Triggers manuales

```
/web-research "¿cómo funciona el rate limiter de Azure SDK?"
/web-research --engines arxiv,scholar "state of the art RAG 2026"
/web-research --cache-only "log4j CVE"
```

---

## Componentes

### 1. Detector de gaps (`scripts/web-research/gap-detector.py`)

Analiza el prompt actual buscando señales de gap:
- Preguntas sobre tecnologías externas al workspace
- Referencias a versiones, APIs o servicios no documentados localmente
- Patrones: "¿cómo...?", "¿cuál es...?", "¿existe...?", "¿es posible...?"

Devuelve: `{ needs_search: bool, query: str, category: str, engines: [] }`

### 2. Cache local (`~/.savia/web-cache/`)

```
~/.savia/web-cache/
├── index.json         ← hash(query) → {result, timestamp, source, ttl}
├── results/           ← JSON files por hash
└── docs/              ← docs offline pre-descargados (opcional)
```

- Key: SHA256 del query normalizado (lowercase, trim, stop words removed)
- TTL por categoría: docs=7d, versions=1d, CVE=12h, general=3d
- Max size: 50MB (LRU eviction)
- Formato: `{ query, results[], source, timestamp, ttl, tokens_est }`

### 3. Motor de búsqueda (`scripts/web-research/search.py`)

```python
def search(query, engines=None, max_results=5):
    # 1. Check cache
    cached = cache.get(query)
    if cached and not expired(cached):
        return cached

    # 2. Try SearxNG if configured
    if searxng_available():
        results = searxng_search(query, engines, max_results)
    # 3. Fallback to Claude Code WebSearch
    else:
        results = None  # signal to use WebSearch tool

    # 4. Cache results
    if results:
        cache.set(query, results)
    return results
```

### 4. Reranker (`scripts/web-research/rerank.py`)

Inspirado en FAIR-Perplexica: reordena resultados por relevancia.

```python
def rerank(query, results, threshold=0.3, top_k=5):
    # Scoring heurístico (sin embeddings, zero-dependency):
    # - Título contiene keywords del query: +0.3
    # - URL de fuente autoritativa (docs oficiales, GitHub): +0.2
    # - Snippet contiene respuesta directa: +0.3
    # - Recency (último año): +0.1
    # - Engine de origen (arxiv > scholar > general): +0.1
    scored = [(r, score(query, r)) for r in results]
    return [r for r, s in sorted(scored, reverse=True) if s > threshold][:top_k]
```

### 5. Formateador de contexto (`scripts/web-research/formatter.py`)

Convierte resultados en contexto inyectable para el LLM:

```markdown
## Web Research: "{query}"
Fuentes consultadas: {engines} · {timestamp}

1. **{title}** — {url}
   {snippet relevante, max 3 líneas}

2. **{title}** — {url}
   {snippet relevante}

Confianza: {alta|media|baja} · Cache: {hit|miss} · TTL: {expiry}
```

Max tokens: 500 por búsqueda (configurable).

### 6. Citación inline

En las respuestas, Savia cita con notación `[web:N]`:

```
Azure SDK incluye rate limiting por defecto desde v12.0 [web:1].
El límite es configurable via RetryOptions [web:1][web:2].

---
📚 [web:1] docs.microsoft.com/azure-sdk-retry · 2026-03-15
📚 [web:2] github.com/Azure/azure-sdk-for-net/issues/28834 · 2026-01-10
```

---

## Configuración

```toml
# En pm-config.local.md o CLAUDE.local.md

# ── Web Research ──────────────────────────────────────────
WEB_RESEARCH_ENABLED        = true
WEB_RESEARCH_AUTO_DETECT    = true     # detectar gaps automáticamente
WEB_RESEARCH_CONFIRM        = true     # pedir confirmación antes de buscar
WEB_RESEARCH_MAX_RESULTS    = 5
WEB_RESEARCH_MAX_TOKENS     = 500      # tokens máx por búsqueda inyectados
WEB_RESEARCH_CACHE_DIR      = "$HOME/.savia/web-cache"
WEB_RESEARCH_CACHE_MAX_MB   = 50
WEB_RESEARCH_DEFAULT_TTL    = "3d"

# SearxNG (opcional, más privacidad, más engines)
SEARXNG_URL                 = ""       # vacío = no usar SearxNG
SEARXNG_ENGINES_DEFAULT     = "google,duckduckgo,bing,brave"
SEARXNG_ENGINES_ACADEMIC    = "arxiv,google scholar,pubmed,semantic scholar"
SEARXNG_ENGINES_CODE        = "github,stackoverflow,gitlab"
SEARXNG_ENGINES_SECURITY    = "cve,nvd"
```

---

## Integración con el ecosistema existente

### Con tech-research-agent

El tech-research-agent actual usa WebFetch/WebSearch de forma ad-hoc.
Con este sistema, usaría el search engine unificado:

```
/tech-research "alternativas a EF Core"
  → gap-detector clasifica: comparativa técnica
  → search(query, engines=["github","stackoverflow","docs"])
  → rerank por relevancia
  → inyectar en contexto del agente investigador
  → informe con citaciones [web:N] verificables
```

### Con nl-query (mejora P1 de FAIR-Perplexica)

Cuando `/nl-query` no puede resolver un comando:
```
Usuario: "¿cómo configuro CORS en ASP.NET 8?"
  → nl-query: confianza <50%, no es un comando pm-workspace
  → Detectar: pregunta técnica externa
  → web-research: buscar documentación
  → Responder con citación + sugerir volver al workspace
```

### Con source-tracking

Las búsquedas web se citan con tipo `web:`:
```markdown
📚 Fuentes:
- web:docs.microsoft.com/aspnet/cors — CORS en ASP.NET 8
- rule:template-separation.md — Regla de separación
```

### Con emergency-mode

Si `WEB_RESEARCH_ENABLED=true` pero no hay red:
```
⚠️ Sin conexión — búsqueda web no disponible.
   Cache local: 23 resultados almacenados.
   ¿Buscar en cache? [S/n]
```

### Con context-budget

Cada búsqueda consume ~500 tokens del budget. El sistema respeta:
- Si contexto >70%: comprimir resultados a 200 tokens (solo top 2)
- Si contexto >85%: solo cache, no buscar online
- Si contexto >95%: desactivar web-research

---

## Seguridad y privacidad

### Qué se busca

SOLO información pública: documentación, APIs, versiones, CVEs, benchmarks,
best practices, stack overflow, GitHub issues.

### Qué NUNCA se busca

```
NUNCA → Datos del proyecto del cliente en la web
NUNCA → Nombres de personas del equipo
NUNCA → Código propietario del workspace
NUNCA → Credenciales, tokens, URLs internas
NUNCA → Información de la empresa del usuario
```

### Sanitización pre-búsqueda

Antes de enviar cualquier query a la web:
1. Eliminar nombres de proyecto (de CLAUDE.local.md)
2. Eliminar nombres de personas (de equipo.md)
3. Eliminar URLs internas
4. Eliminar cualquier dato que matchee PII patterns
5. Si queda una query vacía después de sanitizar → abortar

### SearxNG como capa de privacidad

Si SearxNG está configurado:
- Las queries van a la instancia local, NO directamente a Google
- SearxNG no mantiene logs por defecto
- El usuario controla completamente qué engines se usan
- No se envían cookies ni headers de tracking

---

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/web-research {query}` | Búsqueda manual con citación |
| `/web-research --engines {lista}` | Búsqueda con engines específicos |
| `/web-research --cache-only` | Solo cache local, sin red |
| `/web-research --cache-clear` | Limpiar cache |
| `/web-research --cache-stats` | Estadísticas de cache |
| `/web-research --setup-searxng` | Guía para instalar SearxNG local |

---

## Degradación graceful (4 niveles)

| Nivel | Condición | Capacidad |
|-------|-----------|-----------|
| **Full** | Internet + SearxNG | 70+ engines, máxima privacidad |
| **Standard** | Internet, sin SearxNG | WebSearch/WebFetch de Claude Code |
| **Cache** | Sin internet, cache existe | Resultados previos (TTL ignorado) |
| **Offline** | Sin internet, sin cache | Informar gap, sugerir docs offline |

---

## Métricas

- Cache hit rate (objetivo: >60% tras 1 semana de uso)
- Queries por sesión (media, P95)
- Tokens consumidos por búsqueda (media, max)
- Fuentes más consultadas (top 10)
- Gaps no resueltos (queries sin resultados útiles)

---

## Implementación incremental

### Fase 1 — Cache + WebSearch/WebFetch (1 sesión)

- Cache local en `~/.savia/web-cache/`
- Wrapper sobre WebSearch/WebFetch nativos de Claude Code
- Comando `/web-research` básico
- Citación inline `[web:N]`
- Sanitización pre-búsqueda
- Integración con context-budget

### Fase 2 — Gap detection automático (1 sesión)

- Detector de gaps en el flujo conversacional
- Confirmación antes de buscar (configurable)
- Integración con nl-query
- Sugerencias post-búsqueda (patrón FAIR-Perplexica)

### Fase 3 — SearxNG opcional (1 sesión)

- Docker compose para SearxNG local
- Script de setup guiado
- Engines por categoría (code, academic, security, general)
- Reranker heurístico
- Fallback automático a Capa 2 si SearxNG no responde

### Fase 4 — Integración profunda (continuo)

- tech-research-agent usa search engine unificado
- Pre-warm de cache para dependencias del proyecto
- Alertas proactivas de CVEs para dependencies
- /evaluate-repo enriquecido con datos web
