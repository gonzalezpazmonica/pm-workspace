# Backlog Structure for Savia Flow

## Overview: Two Backlogs, One Goal

The Exploration backlog feeds the Production backlog through validated, executable specifications. This structure separates discovery work from delivery work while maintaining a clear handoff protocol.

---

## Exploration Backlog

**Purpose**: Discover outcomes, validate hypotheses, write executable specifications

### Items
- Outcomes to discover (linked to OKRs)
- Hypotheses to validate
- Specifications being written
- Technical opportunity investigations

### States
- **Proposed**: New idea awaiting triage
- **Discovery**: Research in progress
- **Spec-Writing**: Creating the 5-component spec
- **Spec-Ready**: Ready for handoff to production
- **Handed Off**: Moved to production (archive)

### Owner
**Elena** (AI Product Manager) prioritizes and reviews specs

### Priority Formula
```
Score = (Impact × Urgency) ÷ Effort
```
Score each factor 1–5 (5 = high impact/urgency, low effort)

### WIP Limit
- **Elena**: 3 exploration items max + 2 gate reviews max

### Sources
- Strategic OKRs and key results
- User feedback and support tickets
- Metrics anomalies and performance gaps
- Technology opportunities and tech debt

---

## Production Backlog

**Purpose**: Execute spec-ready work, build features, validate outcomes

### Items
- User Stories from Spec-Ready items
- Implementation Tasks
- Production bugs and hotfixes
- Post-deployment validation work

### States
- **Ready**: Awaiting builder capacity
- **In Progress**: Active development
- **Gate-Review**: Quality, security, performance validation
- **Deployed**: Live in production
- **Validating**: Monitoring success metrics

### Owner
- **la usuaria** (Flow Facilitator): Assigns work, unblocks, facilitates
- **Ana & Isabel** (Builders): Execute tasks

### Priority Rules
1. **Spec-Ready first**: All spec-ready items before any drafts
2. **Business value**: Highest user impact and revenue opportunity
3. **Risk**: Fix high-risk bugs before low-risk features
4. **Dependencies**: Unblock dependent teams/items

### WIP Limits Per Person
- **Ana** (Front-end): 2 building items max
- **Isabel** (Back-end): 2 building items max
- **la usuaria**: No WIP limit (facilitation role)

### Sources
- Only Spec-Ready items from Exploration backlog
- Production bugs found in gates
- Hotfixes from production incidents

---

## Handoff Rules: Exploration → Production

### Spec-Ready Checklist
Before marking an item "Spec-Ready", verify:

- [ ] **Outcome defined**: Linked to Epic/OKR with clear problem statement
- [ ] **Success metrics**: 3–5 KPIs with baseline and target values
- [ ] **Functional spec complete**: Detailed flows, Given/When/Then scenarios
- [ ] **Technical constraints listed**: Stack, performance, security, dependencies
- [ ] **DoD checklist filled**: Testing strategy, quality gates, accessibility

### Handoff Process
1. Elena tags item as `spec-ready`
2. la usuaria reviews and approves handoff
3. Item moves from Area Path `Exploration` → `Production`
4. Item state changes to `Ready` in production backlog
5. Ana or Isabel picks up in next sprint

### Guard Rail
**ONLY items tagged `spec-ready` can enter Production.** Reject incomplete specs.

---

## Dependency Management

### Cross-Track Dependencies
**Problem**: A production item needs input from exploration (e.g., architecture decision)

**Solution**: Tag the production item `needs-exploration` and create a work item link to the exploration issue. la usuaria coordinates resolution before work can proceed.

### Cross-Person Dependencies
**Problem**: Ana needs Isabel's API before starting front-end development.

**Solution**: Create a dependency link in Azure DevOps. Isabel marks API task as `blocks:{Ana's-item-id}`. Prioritize the blocking item.

### Cross-Project Dependencies
**Problem**: This feature depends on another team's API release.

**Solution**: Use portfolio dependencies in Azure DevOps. Add to gate review: "API release v2.1 completed".

---

## Backlog Health Metrics

### Exploration Health
- **Spec-Ready Buffer**: ≥3 items ready for production handoff at all times
  - Prevents production team starvation
  - Allows sprint planning flexibility
  
- **Conversion Rate**: ~60% of exploration capacity should convert to spec-ready within 2 weeks
  - Example: If Elena spends 60% time on discovery, ~36% should graduate to spec-ready

### Production Health
- **Gate-Review Bottleneck**: ≤2 items in gate-review at any time
  - If >2, add another reviewer or reduce incoming items
  - Gate-review should take <2 days per item

- **Cycle Time**: Track time from "Building" → "Deployed"
  - Target: ≤5 days for average item
  - Alert if >10 days

### Team Health Signals
- **No WIP overages**: Ana and Isabel stay at or below limits
- **Spec quality**: <5% rework rate due to incomplete specs
- **Deployment frequency**: ≥2 deployments per week
- **Outcome validation**: ≥80% of deployed items tracked for success metrics
