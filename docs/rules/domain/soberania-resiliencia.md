---
context_tier: L2
token_budget: 700
---

# Regla: Hoja de ruta de soberanía y resiliencia (L26 · SE-344)

> Línea Savia Evolution (Labs L26, validada 2026-08-27). CRIT-001 rector.

## Principios

1. **Soberanía de datos**: egress N3+ a proveedor cloud = 0, siempre
   (CRIT-001). Los datos N3+ jamás salen del workspace, ni siquiera temporal
   ni "anonimizados a mano".
2. **Soberanía de inferencia**: el asistente debe poder operar con
   infraestructura propia (modelos locales + savia-dual como failover).
3. **Resiliencia de criterio**: externalizar el juicio con consecuencia
   verificada (FxC / fronemas) y conservar práctica deliberada — no atrofiar
   el criterio al automatizar.

## Hoja de ruta operativa

| Paso | Acción | Estado |
|---|---|---|
| 1 | Soberanía de datos: CRIT-001 + N-levels + destilación FxC | ✅ activo |
| 2 | Soberanía de inferencia: savia-dual (failover local) + PMA como banco de pruebas (SE-347) | ⚠️ parcial — falta modelo local ≥8B usable |
| 3 | Resiliencia de criterio: cúpula Fronesia + loop `fronema.py train` (predict→reveal→calibrate) | ✅ SE-344 implementado |
| 4 | Anti-atrofia: práctica deliberada preservada — al automatizar una decisión, designar ventanas donde la operadora conserva la ejecución | pendiente (con E4) |

## Métricas de impacto (medibles en el workspace)

- **Egress N3+** = 0 (audit savia-gates).
- **Coste por tarea** con enrutamiento SE-346: objetivo -40%.
- **Calidad de decisión**: % de fronemas con consecuencia verificada ≥80%.
- **Integridad**: readiness-check 0 FAIL · cobertura crítica 100%.

## Referencias

- L26: `labs/research/l26-evolution-20260827.md` · `labs/hypotheses/l26-savia-evolution.md`
- FxC: `docs/rules/domain/fronesis-destilacion.md` · `docs/specs/SE-344-*.spec.md`
- SE-346 (enrutamiento) · savia-dual · sovereignty-auditor
