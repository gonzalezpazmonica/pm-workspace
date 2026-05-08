---
name: feasibility-probe-domain
description: Domain knowledge for feasibility validation of SDD specs
---

# Por que existe esta skill

Antes de planificar un sprint, no hay forma objetiva de saber si una spec es trivial o imposible para el modelo actual. Las estimaciones se basan en intuicion, no en evidencia. El probe genera datos reales intentando construir un prototipo acotado en tiempo.

## Conceptos de dominio

- **Feasibility score**: Porcentaje de requisitos resueltos por el modelo en tiempo acotado (0-100)
- **Blocking section**: Requisito que el modelo no pudo resolver — necesita descomposicion o investigacion
- **Trivial section**: Requisito resuelto sin friccion en menos de 1 minuto
- **Budget**: Limite duro de tiempo/tokens. No es sugerencia, es hard stop
- **Probe**: Intento acotado de implementacion, no una implementacion real

## Reglas de negocio

- RN-PROBE-01: El probe NUNCA despliega ni persiste fuera de /tmp
- RN-PROBE-02: Dependencias externas se mockean, nunca se llaman
- RN-PROBE-03: El score refleja logro real, no potencial estimado
- RN-PROBE-04: El budget es un hard limit — el probe termina limpiamente al alcanzarlo

## Relacion con otras skills

- **Upstream**: spec-driven-development (spec aprobada)
- **Downstream**: sprint-management (estimacion), pbi-decomposition (si score < 80)
- **Paralelo**: model-upgrade-audit (consume datos historicos del probe)

## Decisiones clave

- Sonnet como modelo del probe (no Opus) — el probe mide lo que haria un agente developer tipico
- Score pesimista: partial cuenta 50%, no 75% — mejor subestimar que sobreestimar
- Directorio temporal con cleanup — zero side effects garantizado
