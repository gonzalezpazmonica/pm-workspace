# Proyecto de Test — `sala-reservas`

El workspace incluye un **proyecto de test completo** (`projects/sala-reservas/`) que permite verificar todas las funcionalidades sin necesidad de conectarse a Azure DevOps real. Usa datos simulados (mock JSON) que imitan fielmente la estructura de la API de Azure DevOps.

## Qué es sala-reservas

Una aplicación sencilla de reserva de salas de reuniones: CRUD de salas (Sala) y CRUD de reservas por fecha (Reserva), sin login — el empleado introduce su nombre manualmente. Tecnología: .NET 8, Clean Architecture, CQRS/MediatR, EF Core.

**Equipo simulado:** 4 desarrolladores humanos (Tech Lead, Full Stack, Backend, QA) + 1 PM + equipo de agentes Claude.

El proyecto incluye dos specs SDD completas que sirven como referencia para testear el flujo de Spec-Driven Development:
- `AB101-B3-create-sala-handler.spec.md` — Command Handlers para el CRUD de Salas (agente opus)
- `AB102-D1-unit-tests-salas.spec.md` — 15 unit tests con xUnit + Moq (agente haiku)

## Ejecutar los tests del workspace

El script `scripts/test-workspace.sh` valida que el workspace esté correctamente configurado. Ejecuta 96 pruebas agrupadas en 9 categorías.

### Modo mock (sin Azure DevOps) — recomendado para empezar

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
```

Resultado esperado: **≥ 93/96 tests pasan**. Los fallos en modo mock son esperados y no indican problemas en el workspace:
- `az` (Azure CLI) no instalado en el entorno de test
- `node_modules` no existe — ejecuta `cd scripts && npm install` para instalar dependencias Node

### Modo real (con Azure DevOps configurado)

```bash
./scripts/test-workspace.sh --real
```

Requiere: PAT configurado, `az devops` instalado, constantes correctas en `CLAUDE.md`.

### Ejecutar una categoría específica

```bash
./scripts/test-workspace.sh --only structure    # Solo estructura de ficheros
./scripts/test-workspace.sh --only sdd          # Solo validación SDD
./scripts/test-workspace.sh --only capacity     # Solo capacity y fórmulas
./scripts/test-workspace.sh --only sprint       # Solo datos del sprint
./scripts/test-workspace.sh --only imputacion   # Solo imputaciones de horas
./scripts/test-workspace.sh --only report       # Solo generación de informes
./scripts/test-workspace.sh --only backlog      # Solo backlog y scoring
```

### Ver output detallado

```bash
./scripts/test-workspace.sh --mock --verbose
```

## Categorías de tests y qué validan

| Categoría | Tests | Qué verifica |
|-----------|-------|--------------|
| `prereqs` | 5 | Herramientas instaladas (jq, python3, node, az, claude CLI) |
| `structure` | 18 | Existencia de todos los ficheros del workspace |
| `connection` | 8 | Conectividad con Azure DevOps (solo `--real`) |
| `capacity` | 12 | Fórmulas de capacity, algoritmo de scoring de asignación |
| `sprint` | 14 | Datos del sprint, burndown, mock JSON válido |
| `imputacion` | 10 | Imputaciones de horas, registro de agentes |
| `sdd` | 15 | Specs, layer matrix, patrones de agente, algoritmo de conflictos |
| `report` | 8 | Generación de informes Excel/PPT |
| `backlog` | 6 | Backlog query, descomposición, scoring de asignación |

## Informe de resultados

Al terminar, el script genera automáticamente un informe Markdown en `output/test-report-YYYYMMDD-HHMMSS.md` con el resumen de resultados, los tests fallidos con la causa y las instrucciones de corrección.

## Estructura de los datos mock

Los ficheros en `projects/sala-reservas/test-data/` simulan respuestas reales de la API de Azure DevOps:

| Fichero | API simulada | Contenido |
|---------|-------------|-----------|
| `mock-workitems.json` | `GET /_apis/wit/wiql` | 3 PBIs + 12 Tasks con estados, asignaciones y tags SDD |
| `mock-sprint.json` | `GET /_apis/work/teamsettings/iterations` | Sprint 2026-04 con burndown de 10 días, velocity histórico |
| `mock-capacities.json` | `GET /_apis/work/teamsettings/iterations/{id}/capacities` | Capacidades de 5 miembros + imputaciones semana 1 |

---
