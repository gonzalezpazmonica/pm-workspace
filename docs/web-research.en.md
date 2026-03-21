# Savia Web Research — Documentation

> Web search system to resolve context gaps. Inspired by [FAIR-Perplexica](https://github.com/UB-Mannheim/FAIR-Perplexica).

## What it is

Savia Web Research lets Savia search public information on the web when it detects missing context: library documentation, versions, CVEs, best practices, technical comparisons.

## Architecture: 3 Layers

```
Layer 1 — LOCAL CACHE (~/.savia/web-cache/)
  No network. TTL by category. LRU eviction at 50MB.

Layer 2 — SEARXNG (Docker auto-start)
  Private metasearch. 70+ engines. Port 8888.
  Starts automatically when needed.

Layer 3 — CLAUDE WEBSEARCH (fallback)
  Native Claude Code tools.
  Used only when Docker unavailable.
```

## Usage

```bash
/web-research "how to configure CORS in ASP.NET 8?"
/web-research "recent CVEs for log4j"
/web-research --cache-only "Entity Framework bulk"
/web-research --cache-stats
/web-research --cache-clear
/web-research --searxng-status
```

## Components

| Module | Function |
|--------|----------|
| `cache.py` | Local cache with TTL (docs=7d, cve=12h, versions=1d) |
| `sanitizer.py` | Strips PII, projects, emails, IPs before searching |
| `rerank.py` | Reorders results by heuristic relevance |
| `formatter.py` | Generates inline citations `[web:N]` |
| `gap_detector.py` | Detects context gaps in user questions |
| `suggestions.py` | Suggests follow-up commands post-execution |
| `searxng.py` | Docker auto-start, API search, health check |
| `search.py` | 3-layer orchestrator: cache → SearxNG → WebSearch |

## Privacy

- Queries sanitized before leaving the machine
- SearxNG doesn't track, no cookies, no profiling
- Local cache in `~/.savia/` (gitignored)
- NEVER searches for client, project, or team data

## SearxNG Docker

SearxNG starts automatically when using `/web-research` if Docker is installed. Works on Linux, macOS, and Windows (Docker Desktop/WSL2).

The `savia-searxng` container listens on `127.0.0.1:8888` (localhost only).

Cross-platform support:
- Detects `docker compose` (v2 plugin) and `docker-compose` (standalone)
- Uses `shell=True` on Windows for PATH resolution
- Health check with 30s startup timeout

## Gap Detection

Savia automatically detects when a question is about external public information vs internal project management:

| Question | Type | Action |
|----------|------|--------|
| "what version of React...?" | External gap | Suggests `/web-research` |
| "how is the sprint going?" | Internal | Runs `/sprint-status` |
| "are there CVEs in log4j?" | External gap | Suggests `/web-research` |

## Follow-up Suggestions

After each command, Savia suggests 2-3 contextual follow-up commands. 10 command families covered: sprint, audit, spec, security, web-research, debt, backlog, review, pr-review.

## Configuration

In `web-research-config.md`:

```
WEB_RESEARCH_ENABLED   = true
WEB_RESEARCH_CONFIRM   = true
WEB_RESEARCH_MAX_TOKENS = 500
SEARXNG_URL            = ""     # empty = auto-start Docker
```

## Tests

```bash
bats tests/test-web-research.bats
python3 -m scripts.web-research cache-stats
python3 -m scripts.web-research sanitize "test query"
python3 -m scripts.web-research classify "CVE log4j"
```
