# Spec: Savia Web — Subproject Support

## Metadatos
- project: savia-web
- phase: 4 — Subprojects
- feature: subproject-detection-and-navigation
- status: pending
- developer_type: human
- depends: phase2-project-selector

## Objective

Enable savia-web to detect and navigate projects with subprojects (like `trazabios_main` which contains `trazabios/`, `trazabios-vass/`, `trazabios-pm/`). When a project has subprojects, the UI shows them as a hierarchical group. When it doesn't, behavior remains unchanged.

## Current State

- Bridge `GET /projects` scans `projects/` flat — every directory becomes a peer `ProjectInfo`.
- `trazabios_main/`, `trazabios/`, `trazabios-vass/`, and `trazabios-pm/` all appear as 4 separate, unrelated projects in the selector.
- No concept of parent/child relationship between projects.
- `ProjectSelector.vue` renders a flat `<select>` dropdown.

## Problem

The trazabios umbrella pattern (and future similar projects) creates confusion:
1. User sees 4 entries that are really 1 project with 3 confidentiality levels.
2. Selecting `trazabios_main` gives agent-level artifacts (CLAUDE.md, digests/) that humans shouldn't navigate directly.
3. No way to understand the hierarchy without prior knowledge.

## Design

### Detection: How to identify subprojects

A project directory is an **umbrella** (has subprojects) if:
1. It contains a `CLAUDE.md` at its root (all projects do), AND
2. It contains **at least one immediate subdirectory** that:
   - Is a real directory (not dotfile, not `output/`, not `digests/`, not `agent-memory/`, not `.agent-maps/`, not `.human-maps/`)
   - Contains its own `README.md` OR has a `.git` directory (independent repo)
   - Has a name that is a variation of the parent (e.g., parent `trazabios_main` → child `trazabios`, `trazabios-pm`, `trazabios-vass`)

**Excluded directories** (never subprojects): names starting with `.`, `output`, `digests`, `agent-memory`, `specs`, `backlog`, `repos`, `docs`.

**Simplified heuristic**: A subdirectory is a subproject if it has its own `README.md` AND does NOT match the excluded list above.

### API Changes: Bridge `GET /projects`

#### New fields in `ProjectInfo`

```typescript
export interface ProjectInfo {
  id: string
  name: string
  path: string
  hasClaude: boolean
  hasBacklog: boolean
  health: string
  // NEW fields:
  parentId: string | null       // null = top-level, "trazabios_main" = child
  children: string[]            // IDs of subprojects (empty if leaf)
  confidentiality: string | null // label from confidentiality.md if exists
}
```

#### New Bridge behavior

1. Scan `projects/` as before.
2. For each directory, check if it's an umbrella (has qualifying subdirectories).
3. If umbrella:
   - The umbrella itself is returned with `children: ["trazabios", "trazabios-pm", "trazabios-vass"]`.
   - Each child is returned with `parentId: "trazabios_main"`.
   - Children that would normally appear as top-level peers are now nested.
4. If not umbrella: unchanged (`parentId: null, children: []`).

**Confidentiality label extraction**: If the umbrella has a `confidentiality.md`, parse it for a table with columns `Nivel | Directorio | Visible para`. Map each child's directory name to its confidentiality label.

#### Example response

```json
[
  {"id": "_workspace", "name": "Savia (workspace)", "path": ".", "parentId": null, "children": [], "confidentiality": null, ...},
  {"id": "trazabios_main", "name": "TrazaBios", "path": "projects/trazabios_main", "parentId": null, "children": ["trazabios", "trazabios-vass", "trazabios-pm"], "confidentiality": null, ...},
  {"id": "trazabios", "name": "trazabios", "path": "projects/trazabios_main/trazabios", "parentId": "trazabios_main", "children": [], "confidentiality": "N4-SHARED", ...},
  {"id": "trazabios-vass", "name": "trazabios-vass", "path": "projects/trazabios_main/trazabios-vass", "parentId": "trazabios_main", "children": [], "confidentiality": "N4-VASS", ...},
  {"id": "trazabios-pm", "name": "trazabios-pm", "path": "projects/trazabios_main/trazabios-pm", "parentId": "trazabios_main", "children": [], "confidentiality": "N4b-PM", ...},
  {"id": "savia-web", "name": "savia-web", "path": "projects/savia-web", "parentId": null, "children": [], "confidentiality": null, ...}
]
```

### Frontend Changes

#### 1. `ProjectInfo` type update (`types/bridge.ts`)

Add `parentId`, `children`, `confidentiality` fields.

#### 2. Project store (`stores/project.ts`)

New computed properties:

```typescript
// Top-level projects only (for selector rendering)
const topLevel = computed(() =>
  projects.value.filter(p => p.parentId === null)
)

// Children of a given project
function childrenOf(parentId: string): ProjectInfo[] {
  return projects.value.filter(p => p.parentId === parentId)
}

// The effective project for data queries:
// If selected is an umbrella (has children), use the first child as default context.
// If selected is a leaf or standalone, use it directly.
const effective = computed(() => {
  const sel = selected.value
  if (!sel) return null
  if (sel.children.length > 0) {
    // Umbrella selected — use first child as default data source
    return projects.value.find(p => p.id === sel.children[0]) ?? sel
  }
  return sel
})
```

#### 3. ProjectSelector component (`components/ProjectSelector.vue`)

Replace flat `<select>` with a grouped dropdown:

```
[▾ TrazaBios > trazabios          ]
   ├─ Savia (workspace)
   ├─ TrazaBios                    ▾
   │    ├─ trazabios        (N4-SHARED)
   │    ├─ trazabios-vass   (N4-VASS)
   │    └─ trazabios-pm     (N4b-PM)
   ├─ savia-web
   └─ proyecto-alpha
```

Implementation:
- Use `<optgroup>` for umbrella projects with `label` = project display name.
- Children rendered as `<option>` inside the `<optgroup>`.
- Standalone projects rendered as `<option>` outside any group.
- Confidentiality label shown in parentheses after subproject name.
- When user selects the umbrella header itself (the `<optgroup>` is not selectable in native `<select>`), auto-select its first child.

**Alternative** (if `<optgroup>` UX is insufficient): Replace `<select>` with a custom dropdown component that supports:
- Collapsible groups
- Click on umbrella name = expand/collapse
- Click on subproject = select it
- Visual indent for children

Decision: Start with `<optgroup>` (simpler, accessible by default). Upgrade to custom dropdown in a follow-up if UX feedback requires it.

#### 4. Display name for umbrella projects

The umbrella directory name often has a suffix like `_main`. Clean it for display:
- `trazabios_main` → `TrazaBios`
- Rule: strip `_main`, `_umbrella`, `-main` suffixes. Title-case the result.
- If a `claude-{name}.md` exists at umbrella root, extract project name from its first `# heading`.

#### 5. Breadcrumb / context indicator

When a subproject is selected, the TopBar shows: `TrazaBios > trazabios (N4-SHARED)` next to the health dot. This makes it clear which level the user is viewing.

### Data flow when subproject is selected

All stores that use `projectStore.selectedId` for data fetching continue to work:
- `selectedId` = the subproject ID (e.g., `"trazabios"`)
- Bridge resolves the path correctly (e.g., `projects/trazabios_main/trazabios`)
- File browser shows files from the subproject directory
- Backlog reads from subproject's `backlog/` if it exists
- Reports scope to the subproject

### Projects without subprojects

Zero changes to behavior. `parentId: null, children: []` — the selector renders them as flat entries exactly as before.

## Files to modify

### Bridge (Python)
- `scripts/savia-bridge.py` — `GET /projects` handler (lines ~2270-2300):
  - Add subproject detection logic
  - Add `parentId`, `children`, `confidentiality` fields
  - Parse `confidentiality.md` if present

### Frontend (TypeScript/Vue)
- `src/types/bridge.ts` — Add new fields to `ProjectInfo`
- `src/stores/project.ts` — Add `topLevel`, `childrenOf`, `effective` computed
- `src/components/ProjectSelector.vue` — Grouped dropdown with `<optgroup>`
- `src/components/AppTopBar.vue` — Show breadcrumb when subproject selected

### Tests
- `src/__tests__/stores/project.test.ts` — Test subproject grouping, effective project resolution
- `scripts/tests/test_bridge_endpoints.py` — Test umbrella detection, confidentiality parsing

## Acceptance Criteria

1. **Detection**: Bridge correctly identifies `trazabios_main` as umbrella with 3 children.
2. **Flat projects unchanged**: Projects without subprojects (e.g., `savia-web`) render and behave identically to before.
3. **Selector groups**: Umbrella projects show as `<optgroup>` with children indented and labeled with confidentiality level.
4. **Selection persists**: Selecting a subproject stores `"trazabios"` (not `"trazabios_main"`) in localStorage. Reloading restores the selection.
5. **Data scoping**: File browser, backlog, and reports scope to the selected subproject's directory.
6. **Breadcrumb**: TopBar shows `TrazaBios > trazabios` when a subproject is active.
7. **No regression**: All existing 228 unit tests pass. All 150 E2E tests pass.

## Edge Cases

- **Umbrella with no qualifying children**: Treated as regular project (no grouping).
- **Deeply nested subprojects** (sub-sub): Not supported in v1. Only 1 level of nesting.
- **Child directory without README.md or .git**: Excluded from subproject detection.
- **Umbrella selected directly** (e.g., via stale localStorage): Auto-redirect to first child.
- **New subproject added while app is open**: Detected on next `projectStore.load()` (page refresh or project creation).

## Out of Scope

- Access control based on confidentiality level (future: role-based visibility of N4b-PM subprojects).
- Creating subprojects from the UI (manual directory structure for now).
- Drag-and-drop reordering of subprojects.
