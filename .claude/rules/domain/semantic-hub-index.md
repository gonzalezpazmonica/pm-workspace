---
name: semantic-hub-index
description: Índice de dependencias entre reglas, comandos y agentes — topología de red semántica
auto_load: false
paths: []
---

# Semantic Hub Index

> 🦉 Savia conoce su propia topología. Este índice mapea las conexiones.

---

## Qué es un Hub

Un hub es una regla de dominio referenciada por ≥5 comandos o agentes. Los hubs son puntos
críticos de la arquitectura: si cambian, afectan a muchos consumidores.

---

## Hubs Identificados (auditoría v0.44.0)

### Tier 1 — Hub (≥5 refs)

| Regla | Refs | Consumidores |
|---|---|---|
| `messaging-config.md` | 6 | inbox-check, inbox-start, nctalk-search, notify-nctalk, notify-whatsapp, whatsapp-search |

### Tier 2 — Near-Hub (3-4 refs)

| Regla | Refs | Consumidores |
|---|---|---|
| `azure-repos-config.md` | 4 | repos-branches, repos-list, repos-pr-create, repos-pr-review |
| `role-workflows.md` | 3 | daily-routine, health-dashboard, profile-onboarding |

### Tier 3 — Paired (2 refs)

| Regla | Refs | Consumidores |
|---|---|---|
| `pm-config.md` | 2 | repos-pr-list, spec-driven-development |
| `environment-config.md` | 2 | azure-pipelines, spec-driven-development |
| `community-protocol.md` | 2 | contribute, feedback |

---

## Reglas No Referenciadas (dormant)

Reglas que existen pero no están referenciadas explícitamente por ningún comando o agente.
Estas reglas se cargan bajo demanda por `@` o son consultadas implícitamente.

Total: 25 reglas dormant de 41 totales (61%)

Esto NO significa que sean inútiles — muchas son cargadas por `@.claude/rules/domain/X`
en la conversación. Pero no tienen dependencias formales en el código.

---

## Recomendaciones

### Para hubs (Tier 1)

1. **Minimizar tamaño**: Un hub se carga muchas veces → cada token cuenta
2. **Estabilizar**: Cambios en un hub afectan a muchos consumidores → PR review obligatorio
3. **Extraer transversal**: Si un hub mezcla config específica y genérica → separar

### Para near-hubs (Tier 2)

1. **Monitorizar**: Si crecen a ≥5 refs → promover a hub y aplicar reglas de Tier 1
2. **Agrupar consumidores**: Si todos los consumidores son del mismo dominio → no separar

### Para reglas dormant

1. **Auditar anualmente**: ¿Siguen siendo relevantes?
2. **Documentar activación**: Añadir en qué contextos se cargan por `@`
3. **Candidatas a merge**: Si dos reglas dormant cubren el mismo dominio → fusionar

---

## Métricas de red

| Métrica | Valor |
|---|---|
| Total reglas dominio | 41 |
| Reglas activamente referenciadas | 16 (39%) |
| Reglas dormant | 25 (61%) |
| Hubs (≥5 refs) | 1 |
| Near-hubs (3-4 refs) | 2 |
| Paired (2 refs) | 3 |
| Isolated (1 ref) | 10 |
| Densidad de conexiones | Baja — topología estrella por dominio |

## Topología actual

La red tiene forma de **estrellas aisladas** más que de mundo pequeño:
cada grupo funcional (messaging, repos, roles) tiene su hub local,
pero no hay conexiones transversales entre grupos.

Para evolucionar hacia mundo pequeño:
- Crear "puentes" entre dominios (ej: role-workflows ↔ messaging-config para alertas por rol)
- Extraer patrones comunes a reglas compartidas

---

## Comando de mantenimiento

`/hub-audit` — recalcular este índice (planificado para futuras versiones)

Última auditoría: v0.44.0 (2026-03-01)
