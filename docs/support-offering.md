# Savia Support Offering — Six Services, Zero Licenses

## Principle

The code is MIT. Forever. The six offerings described here are
**services**, not license tiers. Nothing in this document gates a
feature, restricts a capability, or introduces a paid version of Savia
itself. Organizations that want to run Savia on their own, without
paying anyone, can do so. Organizations that want help can pay for
help. Those are the only two options.

This split is the only way to fund the project without violating the
seven foundational principles
(`.claude/rules/domain/savia-foundational-principles.md`). See
`LICENSE-ENTERPRISE.md` for the five licensing models that were
rejected and why.

## The six services

### 1. Professional support with SLA

**What it is.** A direct channel to the maintainers and a contracted
response time for issues, questions, and bug triage. Covers installation
problems, integration questions, operational incidents, and guidance on
upgrades.

**What it is NOT.** It is not a license to run Savia. You can run Savia
without ever contacting support. Support is for organizations that need
a guaranteed answer within a defined window — typically regulated
sectors where "I will ask the community" is not an acceptable fallback.

**Pricing model.** Annual contract, tiered by response time and channel
count. Not per-seat, not per-agent, not per-task.

### 2. Implementation and migration consulting

**What it is.** Hands-on help to deploy Savia in a complex organization:
architecture design, migration from existing PM tools, integration with
on-premise infrastructure, hardening for regulated environments, and
knowledge transfer to the internal team.

**Deliverables.** Architecture diagrams, migration plan, training
sessions, runbooks, and a documented handover. Everything produced
during the engagement becomes property of the client, under whatever
license they choose.

**Pricing model.** Fixed-scope engagements or daily rates. The project
scope is agreed before work starts and documented as an internal spec
following the standard spec protocol.

### 3. Certified training

**What it is.** Structured courses, workshops, and certification
programs for teams adopting Savia. Includes foundational courses on
the architecture, workshops on specific workflows (sprint management,
SDD pipeline, governance), and certification tracks for operators and
developers.

**Format.** On-site, remote, or self-paced. Materials are delivered to
the client and can be reused internally without restriction.

**Pricing model.** Per-course or per-seat for public courses. Private
courses are quoted as engagements.

### 4. Custom spec development

**What it is.** When an organization needs a capability that does not
exist in Savia and is too specific to justify an upstream contribution,
the maintainers can develop a custom module under contract. The work
follows the standard SDD protocol: spec → review → implementation →
tests → handover.

**Ownership.** The code is delivered under MIT, consistent with the
rest of Savia. The client keeps operational ownership; the upstream
project may later incorporate generalizable parts of the work (with
permission) if they would benefit the wider community.

**Pricing model.** Fixed-scope per spec. Price is a function of
complexity, not of how many times the client runs the code afterwards.

### 5. Sovereignty audits

**What it is.** A structured audit of an organization's Savia
deployment against the seven foundational principles, with specific
attention to data sovereignty (does `.md` remain the source of truth?),
vendor independence (can the organization eliminate the maintainers
tomorrow without losing data?), and compliance with sector regulations
(GDPR, HIPAA, DORA, AI Act, NIS2). Produces a written report with
findings, severity scoring, and remediation recommendations.

**When to use it.** Before a regulated production launch, after a
significant infrastructure change, or on a periodic schedule as part
of internal compliance programs.

**Pricing model.** Fixed-scope per audit, quoted based on deployment
size and regulatory scope.

### 6. Hardware reference integrations

**What it is.** For organizations that want to run Savia on their own
hardware for maximum sovereignty, this service delivers a turnkey
configuration: choice of hardware, installation, local model setup
(Ollama or equivalent), network isolation, backup strategy, and a
verified reference architecture. The goal is a working on-premise
installation where the organization never has to send data to any
external API for any Savia operation.

**Deliverables.** Hardware recommendation, installation scripts,
acceptance test suite, operational runbook, and one sovereignty audit
(see service 5) to certify the result.

**Pricing model.** Fixed-scope engagement per reference architecture.

## What is NOT on this list

Deliberately absent from the above:

- No "Enterprise Edition" license
- No per-agent fees
- No per-seat fees
- No per-task fees
- No hosted SaaS offering
- No paywalled features

Every one of these would violate at least one of the seven foundational
principles. `LICENSE-ENTERPRISE.md` explains each rejection in detail.

## How to engage

To inquire about any of the six services, open an issue on the upstream
repository with the label `services`. Sensitive conversations can move
to private channels after initial contact. Pricing is transparent
enough to decide whether to continue the conversation.
