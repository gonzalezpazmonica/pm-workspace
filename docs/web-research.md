# Savia Web Research — Documentación

> Sistema de búsqueda web para resolver gaps de contexto. Inspirado en [FAIR-Perplexica](https://github.com/UB-Mannheim/FAIR-Perplexica).

## Qué es

Savia Web Research permite a Savia buscar información pública en la web cuando detecta que le falta contexto: documentación de librerías, versiones, CVEs, best practices, comparativas técnicas.

## Arquitectura: 3 Capas

```
Capa 1 — CACHE LOCAL (~/.savia/web-cache/)
  Sin red. TTL por categoría. LRU eviction a 50MB.

Capa 2 — SEARXNG (Docker auto-start)
  Metasearch privado. 70+ engines. Puerto 8888.
  Se levanta solo cuando se necesita.

Capa 3 — CLAUDE WEBSEARCH (fallback)
  Herramientas nativas de Claude Code.
  Se usa solo si Docker no disponible.
```

## Uso

```bash
/web-research "¿cómo configuro CORS en ASP.NET 8?"
/web-research "CVE recientes para log4j"
/web-research --cache-only "Entity Framework bulk"
/web-research --cache-stats
/web-research --cache-clear
/web-research --searxng-status
```

## Componentes

| Módulo | Función |
|--------|---------|
| `cache.py` | Cache local con TTL (docs=7d, cve=12h, versions=1d) |
| `sanitizer.py` | Elimina PII, proyectos, emails, IPs antes de buscar |
| `rerank.py` | Reordena resultados por relevancia heurística |
| `formatter.py` | Genera citaciones inline `[web:N]` |
| `gap_detector.py` | Detecta gaps de contexto en preguntas del usuario |
| `suggestions.py` | Sugiere follow-up commands post-ejecución |
| `searxng.py` | Auto-start Docker, API search, health check |
| `search.py` | Orquestador 3 capas: cache → SearxNG → WebSearch |

## Privacidad

- Queries sanitizadas antes de salir de la máquina
- SearxNG no trackea, no guarda cookies, no perfila
- Cache local en `~/.savia/` (gitignored)
- NUNCA se buscan datos del cliente, proyecto o equipo

## SearxNG Docker

SearxNG se levanta automáticamente al usar `/web-research` si Docker está instalado. Funciona en Linux, macOS y Windows (Docker Desktop/WSL2).

```bash
# Ver estado
/web-research --searxng-status

# Detener manualmente
python3 -c "from scripts... import searxng; searxng.stop()"
```

El contenedor `savia-searxng` escucha en `127.0.0.1:8888` (solo localhost).

## Gap Detection

Savia detecta automáticamente cuando una pregunta es sobre información pública externa vs gestión interna del proyecto:

| Pregunta | Tipo | Acción |
|----------|------|--------|
| "¿qué versión de React...?" | Gap externo | Sugiere `/web-research` |
| "¿cómo va el sprint?" | Interno | Ejecuta `/sprint-status` |
| "¿hay CVEs en log4j?" | Gap externo | Sugiere `/web-research` |
| "/board-flow" | Interno | Ejecuta directamente |

## Follow-up Suggestions

Después de cada comando, Savia sugiere 2-3 comandos de follow-up:

```
✅ /sprint-status completado
💡 Siguientes pasos:
   → /board-flow (ver cuellos de botella)
   → /risk-predict (predicción de completitud)
   → /team-workload (balance de carga)
```

## Configuración

En `web-research-config.md`:

```
WEB_RESEARCH_ENABLED   = true
WEB_RESEARCH_CONFIRM   = true    # pedir confirmación antes de buscar
WEB_RESEARCH_MAX_TOKENS = 500   # máx tokens inyectados en contexto
SEARXNG_URL            = ""      # vacío = auto-start Docker
```

## Tests

```bash
# Tests BATS
bats tests/test-web-research.bats

# Tests Python directos
python3 -m scripts.web-research cache-stats
python3 -m scripts.web-research sanitize "test query"
python3 -m scripts.web-research classify "CVE log4j"
```
