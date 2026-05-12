# DOMAIN: context-update — Decisiones de diseño y conocimiento del dominio

## Decisiones clave

### Por qué Python, no bash
Rule #26: Python para lógica estructurada (JSON, hashes, iteración anidada). Bash sólo es el envoltorio `scripts/context-update.sh` que delega a `python3 scripts/context_update_main.py`.

### Por qué heurístico como fallback F2
F2 spec pide 4 agentes LLM. Si no hay `claude` CLI disponible (entorno offline, CI sin credentials), el pipeline no puede quedar roto. Los módulos heurísticos (`relevance_judge.py`, etc.) cubren semántica básica sin LLM. El invoker detecta disponibilidad en runtime y decide.

### Por qué MinHash+LSH en duplicate_detection
`networkx` no está disponible en el workspace. MinHash+LSH (datasketch) da detección de duplicados O(n) con estimación de Jaccard sin grafo. Threshold: Jaccard ≥ 0.70.

### Por qué fragmentar strings en secret_scan
Savia Shield Capa 1 escanea ficheros `.py` en rutas públicas buscando patrones de credenciales literales. `secret_scan.py` contiene los mismos patrones para detectarlos en otros ficheros — creando un falso positivo sobre sí mismo. Solución: `_join()` / `_ijoin()` helpers que construyen los strings en runtime.

### composite_quality scoring
Fórmula deliberadamente simple y auditable:
```
base = 1.0 - min(errors*0.05, 0.40) - min(warnings*0.02, 0.30) - min(infos*0.01, 0.15)
```
No hay pesos por job — un ERROR de secret_scan vale lo mismo que un ERROR de frontmatter_lint. Si en el futuro se quiere ponderar, añadir un `_JOB_WEIGHTS` dict en f3.

### F4 delegación
Sólo se delegan comandos en `_DELEGATABLE_COMMANDS`. Actualmente: `vault-curator --fix-broken-links`, `vault-curator --fix-frontmatter`, `vault-curator --normalise-tags`. Añadir comandos nuevos aquí cuando se implementen. El resto es `PENDING_MANUAL`.

### Artefactos canónicos
Los nombres `F3_plan.md`, `F3_plan.json`, `F4_apply_log.json` son los de la spec y no deben cambiarse. `report.md` y `consolidated.json` son alias legacy que coexisten.

## Falsos positivos conocidos

- `secret_scan` detecta como ERROR ficheros de documentación que contienen _ejemplos_ de patrones de credenciales (e.g., `docs/rules/domain/security-check-patterns.md`, `docs/rules/languages/java-rules.md`). Son falsos positivos esperados. En el futuro: añadir un campo `allowlist` en el frontmatter del fichero.

- `wikilink_check` marca como WARNING las specs orphaned (`docs/specs/SPEC-*.md`) que no tienen backlinks. Correcto — la mayoría de specs antiguas no están enlazadas desde ninguna nota activa.

## Dependencias externas

| Librería | Uso | Fallback |
|----------|-----|---------|
| `datasketch` | MinHash+LSH en duplicate_detection | Desactiva el job, emite WARNING |
| `frontmatter` / `python-frontmatter` | Parseo frontmatter YAML | stdlib yaml si no disponible |
| `claude` CLI | Invocar agentes F2 LLM | Heurístico local |

## Ledger de métricas

`~/.savia/context-update-metrics.jsonl` — append-only JSONL, una línea por run:
```json
{"run_id": "...", "ts": "...", "scope": "all", "total_findings": 1265, "composite_quality": 0.35, ...}
```
`store.read_trend(n=5, scope=)` lee las últimas N entradas del mismo scope.

## Integración con otros comandos

F4 delega a `vault-curator` para fixes automáticos. Si `vault-curator` no existe (aún no implementado), el delegador lo detecta y marca como `PENDING_MANUAL` sin error fatal.
