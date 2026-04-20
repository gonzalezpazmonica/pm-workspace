---
spec_id: SPEC-085
title: Savia Web Phase 1 — Modelo de datos completo (PBI history + tasks)
status: PROPOSED
origin: Auditoria 2026-04-07 (L-003)
severity: Baja
effort: ~6h agente
---

# SPEC-085: Savia Web — Modelo de datos completo

## Problema

La aplicacion web de Savia funciona pero carece del modelo de datos
completo: no tiene entidades para historial de PBIs ni para tasks.
Esto limita la capacidad del dashboard web para mostrar datos de sprint.

## Solucion

1. Definir entidades `PbiHistory` y `Task` en el schema de datos
2. Implementar endpoints CRUD para ambas entidades
3. Conectar con el backend de Savia Flow (git-based)
4. Crear vistas basicas en el dashboard web

## Criterios de aceptacion

- [ ] Entidades PbiHistory y Task definidas con campos minimos
- [ ] API endpoints operativos (GET, POST, PATCH)
- [ ] Dashboard muestra historial de PBIs del sprint activo
- [ ] Tests unitarios para cada endpoint
- [ ] Documentacion de la API actualizada
