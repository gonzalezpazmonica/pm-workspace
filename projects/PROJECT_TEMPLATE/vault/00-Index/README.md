---
confidentiality: N4
project: PROJECT_TEMPLATE
entity_type: moc
created: 2026-05-06
updated: 2026-05-06
status: active
tags: [index, moc]
---

# Vault — {{PROJECT_NAME}}

> [!warning] Confidencialidad
> Este vault contiene datos N4 (proyecto cliente) por defecto.
> NO instalar plugins de Obsidian que envien datos a cloud (Smart Connections, Copilot for Obsidian, Obsidian Sync).
> Los plugins community-installed se mantienen vacios. Ver `community-plugins.json`.

## Como usar este vault

- Open Obsidian → "Open another vault" → seleccionar esta carpeta
- O ejecutar desde terminal: `/vault-open {{PROJECT_SLUG}}`

## Mapas de contenido (MOC)

- [[MOC-{{PROJECT_SLUG}}]] — punto de entrada principal
- [[10-PBIs/]] — backlog activo (un fichero por PBI)
- [[20-Decisions/]] — Architectural Decision Records
- [[30-Sprints/]] — vista por sprint
- [[40-Stakeholders/]] — personas implicadas
- [[50-Digests/]] — resumenes de reuniones, PDFs, transcripciones
- [[60-Risks/]] — riesgos y mitigaciones
- [[70-Specs/]] — referencia a specs SDD del proyecto
- [[99-Inbox/]] — notas sin clasificar pendientes de curar

## Reglas de Context-as-Code

Toda nota DEBE tener frontmatter con:
- `confidentiality:` (N1|N2|N3|N4|N4b)
- `project:` (slug del proyecto)
- `entity_type:` (pbi|decision|sprint|stakeholder|digest|risk|spec|moc|inbox)
- `created:` y `updated:` (ISO date)

El hook `vault-confidentiality-gate.sh` valida estos campos en cada write.
Ver: `docs/rules/domain/vault-frontmatter-spec.md`
