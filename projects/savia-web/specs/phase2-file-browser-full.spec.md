# Spec: Savia Web — Full Workspace File Browser

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: file-browser-full
- status: pending
- developer_type: human
- depends: phase2-project-selector (project context determines root)

## Objective

Extend the current file browser so it can navigate the entire Savia workspace (`~/savia/`), not just relative to Bridge's working directory. The project selector determines the initial root, but the user can navigate up to the workspace root and across project boundaries.

## Current State

- `FileBrowserPage.vue` exists and works, navigating from `.` (Bridge CWD).
- Uses `GET /files?path=X` and `GET /files/content?path=X`.
- Navigation: flat list, ".. Up" button, click directory to enter, click file to view.
- No breadcrumb, no tree sidebar, no syntax highlighting, no search.

## Design

### Navigation model

```
Breadcrumb: Savia > projects > savia-web > src > pages > HomePage.vue
            ↑ clickable          ↑ clickable
```

Two navigation panels:
1. **Left panel — Directory tree** (collapsible sidebar, ~250px). Shows folder hierarchy. Click to navigate. Expand/collapse with chevrons.
2. **Right panel — Content area** (existing list + file viewer). Shows contents of selected directory or file.

### Root behavior per project selector

| Project selected | File browser root | Breadcrumb starts at |
|-----------------|-------------------|---------------------|
| Savia (workspace) | `~/savia/` | `Savia` |
| savia-web | `~/savia/projects/savia-web/` | `savia-web` |
| Any project | `~/savia/projects/{name}/` | `{name}` |

**Navigate up**: user can always go up to the workspace root (`~/savia/`) regardless of project context. Breadcrumb shows full path from Savia root.

### File viewer improvements

| Feature | Current | New |
|---------|---------|-----|
| Syntax highlighting | None (plain `<pre>`) | highlight.js (already a dependency via marked) |
| Line numbers | None | Gutter with line numbers |
| File size indicator | KB only | KB + line count |
| Markdown rendering | None | Rendered markdown for `.md` files (toggle raw/rendered) |
| Image preview | None | Inline preview for `.png`, `.jpg`, `.svg` |
| YAML frontmatter | Shown as text | Parsed and shown as key-value table |
| Search in file | None | Ctrl+F search bar within file viewer |
| Copy button | None | "Copy to clipboard" button in file header |

### Directory listing improvements

| Feature | Current | New |
|---------|---------|-----|
| Icons | Emoji (prohibited by NFR-07) | Lucide icons: Folder, FileText, FileCode, Image |
| Sort | None (server order) | Click column headers to sort by name/size/modified |
| Modified date | Not shown | Show relative time ("2h ago", "yesterday") |
| Hidden files | Shown | Toggle to show/hide dotfiles (`.git`, `.claude`, etc.) |
| Breadcrumb | Path as text | Clickable breadcrumb segments |

### Excluded paths

Never show contents of:
- `.git/` internals (objects, refs, etc.) — show `.git/` as a collapsed indicator only
- `node_modules/` — show as collapsed with item count
- `dist/`, `coverage/` — show as collapsed

## Bridge API changes

### Updated: `GET /files?path=X`

Add parameter `&root=workspace|project` to control resolution:
- `root=workspace` → path relative to `~/savia/`
- `root=project` → path relative to `projects/{selectedProject}/`

Add response fields:
```json
{
  "entries": [
    {
      "name": "src",
      "type": "directory",
      "size": 0,
      "modified": "2026-03-14T12:22:00Z",
      "children_count": 12
    },
    {
      "name": "CLAUDE.md",
      "type": "file",
      "size": 2835,
      "modified": "2026-03-14T12:22:00Z",
      "language": "markdown"
    }
  ],
  "breadcrumb": ["Savia", "projects", "savia-web", "src"],
  "absolute_path": "/home/monica/savia/projects/savia-web/src"
}
```

### Updated: `GET /files/content?path=X`

Add response field `language` (detected from extension) for syntax highlighting:
```json
{
  "content": "...",
  "language": "typescript",
  "lines": 42,
  "size": 1283
}
```

## Vue Components

```
src/pages/FileBrowserPage.vue        ← refactor: add tree sidebar + breadcrumb
src/components/files/
  FileTree.vue                       ← collapsible directory tree (left panel)
  FileTreeNode.vue                   ← single tree node (recursive)
  FileBreadcrumb.vue                 ← clickable breadcrumb path
  FileViewer.vue                     ← enhanced: syntax highlighting + markdown
  FileListItem.vue                   ← enhanced: Lucide icons + sort + modified
```

## Acceptance Criteria

- [ ] AC-1: File browser opens at project root when a project is selected
- [ ] AC-2: User can navigate up to `~/savia/` root from any project
- [ ] AC-3: Breadcrumb shows clickable path segments
- [ ] AC-4: Left panel shows collapsible directory tree
- [ ] AC-5: `.ts`/`.vue`/`.md`/`.yaml` files show syntax highlighting
- [ ] AC-6: `.md` files have toggle between rendered and raw view
- [ ] AC-7: `node_modules/` and `.git/` shown as collapsed indicators
- [ ] AC-8: Directory listing sortable by name, size, modified date
- [ ] AC-9: Lucide icons used for all file type indicators (no emoji)
- [ ] AC-10: Selecting "Savia (workspace)" in project selector shows root tree
