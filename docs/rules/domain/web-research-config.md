# Web Research — Configuration and Protocol

> Savia puede buscar en la web para resolver gaps de información pública.
> Privacidad: queries sanitizadas. Offline-first: cache local.

## Configuración

```
WEB_RESEARCH_ENABLED        = true
WEB_RESEARCH_AUTO_DETECT    = true
WEB_RESEARCH_CONFIRM        = true
WEB_RESEARCH_MAX_RESULTS    = 5
WEB_RESEARCH_MAX_TOKENS     = 500
WEB_RESEARCH_CACHE_DIR      = "$HOME/.savia/web-cache"
WEB_RESEARCH_CACHE_MAX_MB   = 50
```

## Cuándo buscar automáticamente

Si `WEB_RESEARCH_AUTO_DETECT=true`, Savia detecta gaps en la conversación:

| Señal | Categoría | Engines preferidos |
|-------|-----------|-------------------|
| "¿qué versión de X...?" | versions | docs oficiales |
| "¿cómo se configura X?" | docs | docs oficiales, stackoverflow |
| "¿es vulnerable X?" | cve | NVD, GitHub Advisory |
| Error de librería externa | code | stackoverflow, github issues |
| "¿X o Y para nuestro caso?" | general | benchmarks, comparativas |

Si `WEB_RESEARCH_CONFIRM=true`, Savia pregunta antes de buscar:
```
🌐 Necesito buscar en la web: "{query sanitizada}"
   Categoría: {docs|cve|versions|code|general}
   ¿Busco? [S/n]
```

## Sanitización obligatoria

ANTES de cualquier búsqueda, ejecutar:
```bash
python3 -m scripts.web-research sanitize "{query}"
```

Se eliminan: nombres de proyecto, personas del equipo, emails, IPs internas,
URLs de Azure DevOps, connection strings. Si el query queda vacío → abortar.

## Citación

Resultados web se citan con `[web:N]` inline y footer:
```
Azure SDK incluye retry por defecto [web:1].
📚 [web:1] learn.microsoft.com/azure-sdk-retry
```

## Integración con context-budget

| Contexto | Comportamiento |
|----------|---------------|
| <70% | Inyectar hasta 500 tokens de resultados |
| 70-85% | Comprimir a 200 tokens (top 2 resultados) |
| 85-95% | Solo cache, no buscar online |
| >95% | Desactivar web-research |

## Degradación

| Nivel | Condición | Acción |
|-------|-----------|--------|
| Full | Internet OK | WebSearch + cache |
| Cache | Sin internet | Resultados previos (TTL ignorado) |
| Offline | Sin internet, sin cache | Informar gap |

## Cache

- Ubicación: `~/.savia/web-cache/`
- TTL: docs=7d, versions=1d, cve=12h, code=3d, general=3d
- Max: 50MB con LRU eviction
- CLI: `python3 -m scripts.web-research cache-stats|cache-clear`
