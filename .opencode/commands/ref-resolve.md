---
name: ref-resolve
description: Resolve and preview resource references
---

---

# /ref-resolve — Manually Resolve and Preview Resource Reference

## Description
Manually resolve a resource reference and show its content. Useful for debugging and previewing what a reference would include.

## Usage
```
/ref-resolve {reference}
```

## Parameters
- **reference** — Full @ reference to resolve (e.g., @project:savia, @spec:ERA-67)

## Output
Shows resolved content with:
- **Reference** — The @ pattern that was resolved
- **Status** — Success or error
- **Content preview** — First 20 lines of resolved content
- **Full content** — Saved to file for large results

## Error Handling
- Unknown reference → Warning with suggestion
- Unresolvable reference → Error with reason
- Timeout → Warning, partial content if available

## Output Location
- Small content: displayed in chat
- Large content: saved to `output/resource-references/{type}-{id}.md`

## Related
- `/ref-list` — List all available references
- `resource-references` skill — Full documentation
