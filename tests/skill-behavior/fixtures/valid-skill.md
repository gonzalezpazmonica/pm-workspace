---
name: example-valid-skill
description: Use when you need to validate a process or review output for correctness. Invoke when someone asks for validation, audit, or review.
license: MIT
compatibility: opencode
---

# Example Valid Skill

This fixture demonstrates a well-formed skill file used in SE-147 validator tests.

## When to invoke

- User asks to validate something
- User requests an audit or review
- Output needs to be checked against criteria

## How to use

Describe your input and the skill will walk through each validation criterion.

## Output format

```
PASS  criterion-name
FAIL  criterion-name — reason
```

## References

- SE-147 skill-behavior tests
