---
name: postmortem-training
description: Postmortem Training Skill
maturity: beta
category: "communication"
tags: ["postmortem", "heuristics", "incident", "learning"]
priority: "medium"
---

# Postmortem Training Skill

**name:** postmortem-training

**description:** Structured postmortem process focused on reasoning heuristics rather than just root cause.

## Purpose

Emphasizes the *journey* to diagnosis—the mental models, checks, and reasoning that led engineers to identify and resolve incidents.

## Template Sections

### 1. Timeline
When did we first notice? When did we understand severity?

### 2. Diagnosis Journey
- What did we check first?
- What hypothesis did we form?
- What data confirmed/denied it?
- Where did we get stuck?

### 3. Resolution
What actions fixed the issue?

### 4. Mental Model Update
What should the on-call engineer know next time?

### 5. Heuristic Extraction
If X happens → check Y metric first. Common cause: Z. Red herring: W.

### 6. Comprehension Gap Analysis
- AI-generated code involved?
- Pre-existing mental model?
- Was the model accurate or stale?
- What documentation would have helped?

### 7. Prevention
What would have caught this earlier?

## Storage

Postmortems stored at: `output/postmortems/YYYYMMDD-{incident-id}.md`

## Integration with Code Comprehension

- Link to code-comprehension-report if AI-generated code involved
- Reference specific functions/modules in gap analysis
- Update comprehension report if mental models were stale

## Mandatory Elements

- Timeline with timestamps
- At least 3 diagnostic steps
- Explicit heuristic(s) for next occurrence
- Comprehension gap assessment
- Prevention recommendation
