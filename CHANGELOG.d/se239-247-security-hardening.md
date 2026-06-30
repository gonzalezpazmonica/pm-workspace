## SE-239..SE-247 — Security Hardening Suite

Suite defensiva inspirada en análisis de AKCodez/hackingtool-plugin (183 tools).
9 specs, 12 scripts, 8 skills nuevos, 4 reglas de dominio, 108 tests BATS.

P1 implementados: SE-239 (git history secrets), SE-241 (IaC scan),
SE-242 (TLS/headers), SE-244 (dependency scan), SE-247 (pre-push gate).

P2 implementados: SE-240 (mobile APK), SE-243 (attack surface mapping),
SE-245 (dynamic web testing), SE-246 (network recon).

Todas las herramientas activas requieren fichero de autorización explícita.
Todas las herramientas tienen fallback Docker cuando no están instaladas nativamente.
Zero herramientas ofensivas — solo auditoría y análisis defensivo.
