# Fixtures L28-F1 — ablation sandbox (deterministas)

- `rules.txt` — reglas del governor (allow build/test, deny deploy_remote).
- `trace-baseline.jsonl` — trace del recorder con 2 tool_exec observadas
  (build, test). ids fijos, sin timestamps.
- `verdict-grounded.json` — veredicto cuyas citas existen en el trace
  (grounding posible).
- `verdict-fabricated.json` — veredicto que cita `deploy_remote_staging`
  (nunca ejecutado: evidencia fabricada).

Los `args_fp` son fingerprints SE-151 reales (sha256 truncado a 16) de las
cadenas `--mode=release`, `--suite=unit`, `--env=staging`. Sin random, sin
red, sin reloj (CRIT-001). Ref: labs/roadmaps/l28-harness-engineering.md F1.
