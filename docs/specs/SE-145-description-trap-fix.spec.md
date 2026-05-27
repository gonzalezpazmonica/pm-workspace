---
id: SE-145
title: "Description Trap Fix — Rewrite skill and agent descriptions as trigger-only"
status: APPROVED
created: 2026-05-26
author: savia
branch: feature/SE-145-description-trap-fix
---

# SE-145 — Description Trap Fix

## Problem

When a skill's `description:` field summarizes its internal workflow, the model
follows the description instead of reading the full SKILL.md. This is the
**Description Trap**: the model shortcuts execution by relying on the summary
embedded in the description.

Discovered via investigation of `obra/superpowers` pattern behaviour.

## Solution

All skill and agent `description:` fields must be **trigger-only**: they describe
WHEN to activate the skill/agent, not WHAT it does or HOW it works.

**Rule**: max 1 sentence, starts with "Usar cuando:" or equivalent activation
context. Zero process summary, zero workflow description.

## Scope

- **98 skills** in `.opencode/skills/*/SKILL.md`
- **65 agents** in `.opencode/agents/*.md`

## Acceptance Criteria

- [ ] AC-1: No description contains process keywords (pipeline, genera, extrae,
  convenes, orquesta, detecta, calcula) without a trigger context prefix.
- [ ] AC-2: Every description answers "when should I use this?" not "what does
  this do?".
- [ ] AC-3: All modified files pass `grep "^description:" | grep -v "Usar cuando\|Use when\|Usar post\|Usar al\|Usar antes\|Usar una"` returning zero matches for the modified set.
- [ ] AC-4: The branch `feature/SE-145-description-trap-fix` contains all changes.
- [ ] AC-5: SKILLS.md and AGENTS.md auto-regenerate indexes reflect new descriptions.

## Modified Skills (98)

adversarial-security, agent-code-map, agent-file-map, ai-labor-impact,
android-autonomous-debugger, architecture-intelligence, ast-comprehension,
ast-quality-gate, azure-devops-queries, azure-pipelines, backlog-git-tracker,
banking-architecture, capacity-planning, caveman, client-profile-manager,
codebase-map, code-comprehension-report, codegraph, code-improvement-loop,
company-messaging, consensus-validation, context-caching,
context-interview-conductor, context-optimized-dev, context-rot-strategy,
context-task-classifier, cost-management, dag-scheduling, developer-experience,
devops-validation, diagram-generation, diagram-import, doc-quality-feedback,
ecosystem-watcher, emergency-mode, enterprise-analytics, enterprise-onboarding,
evaluations-framework, executive-reporting, feasibility-probe,
governance-enterprise, grill-me, human-code-map, knowledge-graph,
legal-compliance, managed-content, meeting-transcript-extract, memvid-backup,
model-upgrade-audit, mutation-audit, nuclei-scanning, onboarding-dev,
orgchart-import, overnight-sprint, pbi-decomposition, pentesting,
performance-audit, personal-vault, pr-agent-judge, product-discovery,
project-update, prompt-optimizer, rbac-management, reflection-validation,
regulatory-compliance, reranker, resource-references, risk-scoring,
rules-traceability, savia-dual, savia-flow-practice, savia-hub-sync,
savia-identity, savia-memory, savia-school, scaling-operations,
scheduled-messaging, skill-evaluation, smart-calendar, smart-routing,
sovereignty-auditor, spec-driven-development, sprint-management,
tdd-vertical-slices, team-coordination, team-onboarding, tech-research-agent,
test-architect, tier3-probes, time-tracking-report, topic-cluster,
verification-lattice, voice-inbox, web-research, weekly-report,
wellbeing-guardian, workspace-integrity, zoom-out

## Modified Agents (65)

architect, architecture-judge, azure-devops-operator, business-analyst,
calibration-judge, cobol-developer, code-reviewer, cognitive-judge,
coherence-judge, coherence-validator, commit-guardian, completeness-judge,
compliance-judge, confidentiality-auditor, correctness-judge, court-orchestrator,
dev-orchestrator, diagram-architect, dotnet-developer, excel-digest,
factuality-judge, feasibility-probe, fix-assigner, frontend-developer,
frontend-test-runner, go-developer, hallucination-fast-judge, hallucination-judge,
infrastructure-agent, java-developer, legal-compliance, meeting-confidentiality-judge,
meeting-digest, meeting-risk-analyst, memory-agent, memory-conflict-judge,
mobile-developer, model-upgrade-auditor, pdf-digest, pentester, php-developer,
pptx-digest, pr-agent-judge, python-developer, recommendation-tribunal-orchestrator,
reflection-validator, ruby-developer, rule-violation-judge, rust-developer,
sdd-spec-writer, security-attacker, security-auditor, security-defender,
security-guardian, security-judge, source-traceability-judge, spec-judge,
tech-writer, terraform-developer, test-architect, test-engineer, test-runner,
truth-tribunal-orchestrator, typescript-developer, word-digest

## References

- Superpowers pattern: `obra/superpowers`
- Rule: descriptions are activation signals, not documentation
