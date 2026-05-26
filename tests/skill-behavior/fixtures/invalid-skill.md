---
name: example-invalid-skill
description: This skill executes a multi-step pipeline that generates reports, runs analysis workflows, and produces output artifacts automatically.
license: MIT
compatibility: opencode
---

# Example Invalid Skill — Description Trap

## When to invoke

This fixture intentionally violates the Description Trap rule (SE-145).
The frontmatter `description` above describes the internal process instead of
the trigger condition. It contains forbidden process-summary words:
executes, pipeline, generates, runs, workflows, produces.

A correct description should answer: "WHEN should I invoke this skill?"
not "WHAT does this skill do internally?"
