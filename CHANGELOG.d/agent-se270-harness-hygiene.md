---
version_bump: minor
section: Changed
---
- **Skills**: skills-lint.sh validates 137 skills for description quality; skill-creator.sh generates proper skill scaffolding; skills-tier-audit.sh classifies skills as core/extended; collision and overlap detection.
- **Agents**: 81/81 agents now have maxSteps (fast:8, mid:15, heavy:declared) and permission.task with allowlists; agent invocation graph generated; depth limit enforcement.
- **Hooks**: hook-type-audit.sh classifies 109 handlers; hook-matcher-audit.sh identifies 27 broad matchers; hook-assignment-rule.sh documents hook allocation criteria; latency budget framework.
- **Memory**: memory-write-gate.sh validates entries before write (stability, cross-task, confidence); memory-decay.py applies time-based confidence decay; memory-prune.sh archives low-confidence entries with tombstone; conflict resolution with human priority.
- **Context**: context-compaction-policy.sh declares survivors/droppable/protected items; context-jit-lint.sh detects preloading patterns; context-erosion-detect.sh monitors context collapse symptoms.
