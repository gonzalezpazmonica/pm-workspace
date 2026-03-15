---
id: "PBI-005"
title: "Export Reports to Word and PDF"
state: "Active"
type: "User Story"
priority: "2-High"
assigned_to: "@bob"
story_points: 8
sprint: "Sprint 2026-04"
tags: [reporting, export, pdf, docx, backend]
specs: []
created: "2026-02-22"
updated: "2026-03-13"
---

## Descripcion

As a manager I want to export any report as Word (.docx) or PDF so that I can share it with stakeholders who do not have access to the application. Use QuestPDF for PDF and OpenXml SDK for Word generation on the server side.

## Criterios de Aceptacion

- [ ] POST /api/v1/reports/{id}/export?format=pdf returns PDF binary
- [ ] POST /api/v1/reports/{id}/export?format=docx returns Word binary
- [ ] Exported documents include company logo header and page numbers
- [ ] Tables and charts render correctly in both formats
- [ ] Export job queued via background worker for large reports

## Tasks

- [TASK-005-001](../tasks/TASK-005-001-pdf-generation.md)
- [TASK-005-002](../tasks/TASK-005-002-docx-generation.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-22 | @system | _created | — | — |
| 2026-03-10 | @bob | state | New | Active |
