---
id: "phase2.5-markdown-editor"
title: "Markdown Editor for Project Files"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Markdown Editor

## Objetivo

In-browser markdown editor for managing project .md files: business rules, team, stakeholders, CLAUDE.md, specs, PBIs. WYSIWYG and raw mode. Save via Bridge.

## Requisitos Funcionales

### RF-01: Editor Modes

- **Raw mode**: textarea with monospace font, line numbers
- **WYSIWYG mode**: rich toolbar (bold, italic, headings, lists, links, code, tables)
- Toggle between modes preserving content
- Live preview panel (split view: editor | preview)

### RF-02: File Operations

- Open any .md file from file browser (click "Edit" button)
- Save via Bridge PUT `/files/content` endpoint
- Auto-save draft to localStorage every 30s
- Unsaved changes indicator (dot on tab/title)
- Confirm before navigating away with unsaved changes

### RF-03: Toolbar

- Bold, Italic, Strikethrough
- H1, H2, H3 headings
- Bullet list, Numbered list, Checklist
- Link, Image (URL input)
- Code inline, Code block
- Table insert (rows x cols picker)
- Horizontal rule
- Undo/Redo

### RF-04: Key Files Quick Access

- Sidebar or dropdown listing important project files:
  - `CLAUDE.md`, `reglas-negocio.md`, `equipo.md`
  - `backlog/pbi/` directory listing
  - `specs/` directory listing

## Criterios de Aceptacion

- [ ] Can open, edit, and save .md files
- [ ] WYSIWYG and raw modes work
- [ ] Auto-save draft prevents data loss
- [ ] Toolbar actions insert correct markdown syntax
- [ ] Bridge PUT endpoint saves file content
- [ ] Unsaved changes warning on navigation
