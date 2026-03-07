# Postmortem Training Skill

**name:** postmortem-training

**description:** Structured postmortem process focused on reasoning heuristics rather than just root cause. Inspired by Emilio Carrión's insight: postmortems should train "how we arrived at the diagnosis" not just "what failed".

## Purpose

This skill emphasizes the *journey* to diagnosis—the mental models, checks, and reasoning that led engineers to identify and resolve incidents. By documenting the diagnostic process, we build collective debugging heuristics that accelerate future incident response.

## Template Sections

### 1. Timeline
When did we first notice something was wrong? At what point did we understand the severity? Include all key observations and state changes.

### 2. Diagnosis Journey
Step-by-step reasoning process:
- **What did we check first?** (initial hypotheses)
- **What hypothesis did we form?** (mental model at each stage)
- **What data confirmed/denied it?** (evidence, logs, metrics)
- **Where did we get stuck?** (cognitive dead ends, misleading signals)

### 3. Resolution
What actions fixed the issue? Timeline of fixes. Did we fix the symptom or root cause?

### 4. Mental Model Update
What should the on-call engineer know next time they encounter this? What mental model was missing or incorrect?

### 5. Heuristic Extraction
If this type of issue recurs, what should we check first?
- If X happens → check Y metric first
- Common cause is usually Z
- Red herring: W (seems related but isn't)

### 6. Comprehension Gap Analysis
- Was this in AI-generated code? Which model?
- Was there a pre-existing mental model of this system?
- Was the model accurate or stale?
- What documentation or comments would have helped?

### 7. Prevention
What would have caught this earlier?
- Monitoring gap?
- Design flaw?
- Missing test coverage?
- Documentation gap?

## Storage

Postmortems stored at: `output/postmortems/YYYYMMDD-{incident-id}.md`

Example: `output/postmortems/20260307-auth-timeout-001.md`

## Integration with Code Comprehension

- Link incident to code-comprehension-report if AI-generated code involved
- Reference specific functions/modules in comprehension gap analysis
- Update comprehension report if mental models were stale
- Tag incidents by comprehension risk: high/medium/low

## Mandatory Elements

- Timeline with timestamps
- At least 3 diagnostic steps in journey
- Explicit heuristic(s) for next occurrence
- Comprehension gap assessment (even if "no AI code involved")
- Prevention recommendation
