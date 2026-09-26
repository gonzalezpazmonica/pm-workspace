---
name: grc-framework-router
description: Selecciona marcos GRC y verifica vigencia. Usar cuando se prepara una auditoría, se compara normativa o se delimita aplicabilidad.
metadata:
  savia.maturity: incomplete
  savia.category: governance
  savia.context: standalone
  savia.context_cost: low
  savia.priority: high
  savia.tags: grc,frameworks,regulation
---
# GRC Framework Router

## Authoritative Paths

| Para | Lee |
|---|---|
| Contrato y límites | `docs/specs/SE-GRC-001-grc-auditor.spec.md` |
| Fuentes oficiales | `docs/grc/README.md` |
| Evaluador | `scripts/grc-audit.py` |

## Flujo

1. Obtén jurisdicción, sector, rol de la entidad, sistemas, datos, productos y periodo. Si falta un dato decisivo, marca aplicabilidad pendiente.
2. Clasifica cada marco como obligación regulatoria, compromiso contractual, certificación voluntaria o guía. Nunca conviertas una guía en ley.
3. Consulta fuente oficial vigente: identificador, edición, estado, publicación, efecto, URL y fecha de consulta. Para NIS2 comprueba transposición nacional; para reglamentos comprueba calendario y supuestos de aplicación.
4. Registra `frameworks[]` en el paquete. No inventes cláusulas ni copies estándares protegidos. Cada `requirements[]` necesita `source_ref` puntual revisado por persona competente.
5. Si el estado es incierto o la última verificación supera 90 días, detén la evaluación formal y renueva fuentes.

## Alcance actual

ENS, ISO/IEC 27001 y RGPD tienen prioridad de enrutamiento para el MVP. NIS2, CRA, DORA, IA, continuidad, proveedores y cloud quedan condicionados a contexto y fuente verificada; la presencia en el catálogo no afirma cobertura normativa completa.
