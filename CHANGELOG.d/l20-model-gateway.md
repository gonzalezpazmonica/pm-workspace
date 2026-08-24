---
version_bump: patch
section: Added
---

### Added

- **L20 Gateway de modelos local (SE-342 S4)** — `scripts/model-gateway.py`:
  - Endpoint unico local `/v1/chat/completions` (proxy a Ollama/LocalAI) y
    `/v1/embeddings` (proxy al embedding-server local) — zero data egress
    (CRIT-001), solo localhost.
  - Log de uso JSONL (`output/agent-runs/gateway-usage.jsonl`): timestamp,
    tipo, llamante, status, latencia y payload **redactado** (campos N3+
    sustituidos por `sha256:...`, nunca en claro).
  - Redacción determinista recursiva (dicts listas), configurable via
    `SAVIA_GW_REDACT_KEYS`.
  - Rate-limit por llamante (token bucket, `SAVIA_GW_RATELIMIT`, por defecto
    30 rpm) y `/health` que reporta alcanzabilidad de runtimes locales.
  - 10 tests BATS (redacción, determinismo, rate-limit, health).

### Fixed

- `operator-grant.sh list` (SE-343): el listado marcaba `valid=no` en grants
  vigentes (comparacion string vs exit code); ahora usa el exit code real de
  `check_scope`.