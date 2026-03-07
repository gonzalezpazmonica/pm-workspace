---
name: managed-content
description: Content management domain - markers, regeneration, validation
---

# Managed Content Domain

Handles structural patterns for auto-generated content lifecycle.

## Core Concepts

**Managed Section**: Block of auto-generated content delimited by markers. Timestamp indicates freshness.

**Marker Format**: XML-style comments with metadata:
```
<!-- managed-by: system | section: name | updated: ISO-8601 -->
```

**Safe Regeneration**: Content between markers may change; content outside markers is immutable.

## Related Skills

- pm-workflow: Workflow orchestration
- plugin-manager: Plugin system
- documentation: Content generation

## Related Rules

- managed-content: Enforcement and guidelines
