---
id: SE-061
title: SE-061 — Scrapling as adaptive research backend
status: IMPLEMENTED
origin: output/research/scrapling-20260421.md
author: Savia
priority: Alta (Tier 3 champion)
effort: M 21h total (4 slices)
gap_link: Research agents bloqueados en sites Cloudflare/JS-heavy
approved_at: "2026-04-22"
applied_at: "2026-04-22"
batches: [14, 15, 16, 17, 22]
expires: "2026-05-21"
---

# SE-061 — Scrapling as adaptive research backend

## Purpose

Nuestros agentes de investigación (`tech-research-agent`, skill `web-research`, `scripts/web-research.sh`) fallan silenciosamente en sites con Cloudflare Turnstile / DataDome, y tienen adaptación cero a cambios de DOM. `Scrapling` (BSD-3, 38K★, Python) aporta:

1. **Adaptive selectors** — similarity-based re-location cuando cambia el DOM
2. **Anti-bot bypass nativo** — Cloudflare Turnstile, DataDome, Akamai, Kasada, Incapsula
3. **MCP server nativo** (`scrapling[ai]`) — integración directa con Claude Code
4. **Async + Spider framework** — batch research escalable
5. **Performance** — 784x BeautifulSoup en benchmarks

Cost of inaction: research agents siguen ciegos a fuentes gated; cada cambio de DOM rompe scripts silenciosamente.

## Scope

### Slice 1 — Probe (S, 4h)

`scripts/scrapling-probe.sh`:
- Python ≥ 3.10 check
- `pip show scrapling` availability
- Chromium availability (opt-in)
- Disk free para browser install
- Output VIABLE / NEEDS_INSTALL / BLOCKED
- BATS tests ≥ 15, score ≥ 80

### Slice 2 — Core wrapper (M, 8h)

`scripts/scrapling-fetch.sh`:
- Wrapper sobre Scrapling parser-only (sin Chromium required)
- Input: URL + optional CSS selector
- Output: extracted text + metadata (status, redirected_url, title)
- Fallback a curl/WebFetch si Scrapling no disponible
- `--json` / `--stealth` / `--timeout` flags
- BATS tests ≥ 20, score ≥ 85

### Slice 3 — Research agent integration (M, 6h)

- `skill: tech-research-agent` consulta `scrapling-fetch.sh` cuando WebFetch devuelve 403/429/503 o contenido vacío
- `skill: web-research` usa Scrapling para extraction post-SearXNG en URLs resultantes
- Fallback robusto si Scrapling no instalado
- Documentado en `docs/rules/domain/research-stack.md` (nuevo)

### Slice 4 — MCP server opt-in (S, 3h)

- Registro en `.claude/mcp.json` de `scrapling[ai]` MCP (opt-in, no default)
- Documentado en `docs/rules/domain/security-scanners.md` como MCP auditado
- Verificado por `scripts/mcp-security-audit.sh` (MCP-01..MCP-11)

## Acceptance criteria

- **Slice 1 PASS**: `scrapling-probe.sh --json` devuelve `verdict` válido en repo sin Scrapling instalado
- **Slice 2 PASS**: `scrapling-fetch.sh https://example.com` devuelve contenido con fallback a curl si Scrapling ausente
- **Slice 3 PASS**: `tech-research-agent` documentado para fallback a Scrapling, opt-in
- **Slice 4 PASS**: `.claude/mcp.json` contiene entry con `description`, sin `autoApprove`
- Zero egress en Slice 1/2 core (no llama a terceros salvo URL del usuario)
- BSD-3 licencia compatible documentada
- `scripts/mcp-security-audit.sh` pasa en Slice 4

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Scraping viola ToS del site | Media | Alto | Documentar robots.txt respect flag, opt-in only |
| Chromium install pesado ~500MB | Alta | Bajo | Slice 1-2 usan core sin browser; opt-in `[fetchers]` |
| Dependencia externa de terceros | Media | Medio | Fallback a curl siempre disponible |
| Maintainer único (1 issue abierto) | Baja | Medio | Pinnear versión; monitorizar upstream activity |
| Legal GDPR/ToS | Baja | Alto | Solo uso research legítimo, documentado en rule |

## Referencias

- Research: `output/research/scrapling-20260421.md`
- Repo: github.com/D4Vinci/Scrapling (BSD-3)
- SE-056 Python SBOM — add scrapling dep si se adopta
- SE-058 MCP audit — valida entry post-Slice 4
- `.opencode/skills/tech-research-agent/`
- `scripts/web-research.sh`
