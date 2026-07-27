# SE-272 — Servicio gestionado: CAPEX/OPEX, KPIs verificables, solicitante agente, interoperabilidad y salida

**Status:** PROPOSED · **Fecha:** 2026-07-25 · **Branch:** agent/se272-servicio-gestionado
**Estimación:** ~48h (5 slices) · **Depende de:** SE-271, SE-267, SE-263

## Origen
Patrón de necesidad de clientes corporativos con plataforma agentica propia:
clasificación contable del trabajo, fin del T&M con KPIs verificables,
solicitante agente, interoperabilidad y garantía de salida.

**Verificado:** 10 scripts enterprise (billing-milestone, project-valuation,
sow-*, client-health-*, metrics-emitter, otel-collector). Cero CAPEX/OPEX.
Cero KPIs contractuales firmados.

## Slices
S1: CAPEX/OPEX (10h) — clasificación en origen + evidencia de capitalización
S2: KPIs verificables (12h) — catálogo firmado + antagonistas anti-Goodhart + cadena de custodia
S3: Solicitante agente (12h) — tipado por origen + SLA diferenciado + presupuesto
S4: Interoperabilidad A2A (8h) — card de plataforma externa + asimetría + allowlist
S5: Garantía de salida (6h) — paquete de salida + simulacro + purga

## Out of scope
NO ERP. NO Savia como plataforma del cliente. NO licenciamiento.
NO penalizaciones. NO métricas individuales.
