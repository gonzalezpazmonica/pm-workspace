---
id: "phase2.5-markdown-viewer"
title: "Enhanced Markdown Viewer — LinkedIn-style"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Enhanced Markdown Viewer

## Objetivo

Improve the file browser markdown rendering to match LinkedIn article quality: proper tables, images, links, code blocks with syntax highlighting, indentation, and spacing.

## Requisitos Funcionales

### RF-01: Table Rendering

- Proper HTML tables with borders, striped rows, header styling
- Responsive: horizontal scroll on narrow viewports
- Aligned columns matching markdown alignment (`:---`, `:---:`, `---:`)

### RF-02: Image Support

- Render `![alt](url)` as `<img>` with max-width: 100%
- Lazy loading (`loading="lazy"`)
- Click to open full size in new tab

### RF-03: Link Handling

- External links open in new tab (`target="_blank"`)
- Internal `.md` links navigate within file browser
- Link styling: primary color, underline on hover

### RF-04: Code Blocks

- Syntax highlighting via highlight.js (already installed)
- Language detection from fenced code block (```js, ```python, etc.)
- Copy button on code blocks
- Line numbers for blocks > 5 lines

### RF-05: Typography (LinkedIn-style)

- Headings: clear hierarchy with spacing (h1 > h2 > h3)
- Paragraphs: 1.6 line-height, comfortable reading width (max 720px)
- Lists: proper indentation, bullet/numbered styling
- Blockquotes: left border accent, italic
- Horizontal rules: subtle separator
- YAML frontmatter: render as styled metadata card (not raw text)

## Criterios de Aceptacion

- [ ] Tables render with borders and header row
- [ ] Images display inline with lazy loading
- [ ] Code blocks have syntax highlighting and copy button
- [ ] Links open correctly (external vs internal)
- [ ] Typography matches professional article style
- [ ] YAML frontmatter displays as metadata card
- [ ] Dark mode renders correctly
