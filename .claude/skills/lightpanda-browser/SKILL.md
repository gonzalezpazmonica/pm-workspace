---
name: lightpanda-browser
description: Usar cuando se necesita navegacion web headless avanzada (JS-heavy sites, SPAs, extraccion markdown de URLs, web scraping que requiere renderizado JS). Triggers: 'navega a', 'extrae contenido de', 'scrapea', 'renderiza esta pagina', 'dump markdown', 'web automation', 'headless browser'.
maturity: experimental
context: project
category: tool
priority: medium
tags: [browser, headless, web, scraping, markdown, mcp, automation, lightpanda]
---

# lightpanda-browser

Navegador headless optimizado para IA. 9x mas rapido y 16x menos RAM que Chrome.
Escrito en Zig. AGPL-3.0 — solo como herramienta externa, nunca bundled.

## Cuando usar Lightpanda vs alternativas

| Escenario | Usar | Por que |
|---|---|---|
| SPA / React / Vue / Angular | Lightpanda | Ejecuta JS completo |
| Infinite scroll / lazy load | Lightpanda | `--wait-selector` + `--wait-ms` |
| HTML estatico simple | curl + regex | Mas ligero, sin dep externa |
| PDF / captura de pantalla | Playwright | Lightpanda no renderiza graficos |
| Formularios / login | Lightpanda agent mode | Navegacion interactiva |

## Instalacion (externo, no bundled)

```bash
# Linux x86_64
curl -L -o ~/.local/bin/lightpanda \
  https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-linux
chmod +x ~/.local/bin/lightpanda

# Docker
docker run -d --name lightpanda -p 127.0.0.1:9222:9222 lightpanda/browser:nightly
```

## Operaciones principales

### 1. Dump a markdown (uso mas frecuente)

```bash
lightpanda fetch --dump markdown --obey-robots \
  --wait-until networkidle0 \
  --timeout 30 \
  "https://example.com"
```

### 2. CDP server + Puppeteer/Playwright

```bash
lightpanda serve --host 127.0.0.1 --port 9222
# Luego conectar con puppeteer.connect({ browserWSEndpoint: "ws://127.0.0.1:9222" })
```

### 3. MCP server (integracion con SaviaVaults)

```bash
lightpanda mcp --port 9223
# Sesiones aisladas por Mcp-Session-Id header
# Herramientas: navigate, click, type, extract, screenshot, execute
```

### 4. Agent mode (navegacion por lenguaje natural)

```bash
lightpanda agent --task "top story on news.ycombinator.com"
lightpanda agent --no-llm  # REPL basico sin LLM
```

## Patron de integracion con Savia

```bash
# Patron: usar si existe, fallback si no
if command -v lightpanda &>/dev/null; then
  lightpanda fetch --dump markdown --obey-robots --timeout 30 "$URL"
else
  python3 scripts/scrapling-fetch.py "$URL"  # fallback existente
fi
```

## Anti-patrones

- NO usar Lightpanda para HTML estatico (curl basta)
- NO esperar renderizado grafico (no tiene motor de renderizado)
- NO bundear el binario (AGPL-3.0 incompatible con MIT)
- NO usar en modo `agent` para tareas simples (el LLM añade latencia)
- NO olvidar `--obey-robots` en produccion

## Limitaciones conocidas

- Beta: algunos sitios pueden fallar
- Sin CORS implementado aun (issue #2015)
- Sin renderizado grafico (solo headless)
- Sin binario nativo Windows (usar WSL2)
- Telemetry activado por defecto (desactivar con LIGHTPANDA_DISABLE_TELEMETRY=true)
