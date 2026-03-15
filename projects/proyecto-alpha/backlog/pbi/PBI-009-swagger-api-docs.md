---
id: "PBI-009"
title: "API Documentation with Swagger/OpenAPI"
state: "Resolved"
type: "User Story"
priority: "3-Medium"
assigned_to: "@eve"
story_points: 5
sprint: "Sprint 2026-04"
tags: [documentation, api, swagger, openapi]
specs: []
created: "2026-02-18"
updated: "2026-03-13"
---

## Descripcion

As a frontend developer I want interactive API documentation at /swagger so that I can explore endpoints, see request/response schemas, and test calls without Postman. Use Swashbuckle with XML comments and example values.

## Criterios de Aceptacion

- [x] Swagger UI available at /swagger in DEV and PRE environments
- [x] All endpoints documented with summary and response codes
- [x] Request/response examples included via XML comments
- [x] Swagger disabled in PRO environment
- [x] OpenAPI 3.0 spec downloadable as JSON

## Tasks

- [TASK-009-001](../tasks/TASK-009-001-swagger-setup.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-18 | @system | _created | — | — |
| 2026-03-10 | @eve | state | New | Active |
| 2026-03-13 | @eve | state | Active | Resolved |
