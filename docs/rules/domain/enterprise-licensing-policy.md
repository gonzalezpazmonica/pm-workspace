---
context_tier: L3
spec: SE-008
status: IMPLEMENTED
token_budget: 900
---

# Enterprise Licensing Policy

> Reference: SPEC-SE-008 — Licensing and Distribution Strategy

## License Model: MIT Unified

All Savia Enterprise components use MIT license. No exceptions.

| Component | License |
|-----------|---------|
| Savia Core | MIT |
| Savia Enterprise modules | MIT |
| MCP servers (SE-003) | MIT |
| Adapters (SE-004) | MIT |
| Documentation | CC-BY-4.0 |

The code is MIT — forever. Monetization is via services, not license restrictions.

## Rejected Models

| Model | Reason |
|-------|--------|
| Open Core + Enterprise commercial | Incentive to move features to closed side (violates principle 2) |
| BSL (Business Source License) | Vendor lock-in, incompatible with principles |
| AGPL | Forces clients to publish their code — impossible in banking contexts |
| SaaS hosted | Savia managing client data (violates principles 1 and 4) |
| Pay-per-agent | Incentive to limit Core capabilities (violates principle 7) |

## Permitted Monetization (Services, Not License)

1. Professional support — SLA, direct channel, issue prioritization
2. Implementation consulting — architecture, migration, training
3. Certified training — courses, workshops, certifications
4. Custom development — client-specific specs, with spec published
5. Sovereign audits — compliance AI Act, NIS2, DORA
6. Hardware reference integration — on-premise turnkey configuration

All of the above are services. The code remains MIT.

## Trademark Policy

- "Savia" and "Savia Enterprise" are project names
- Forks permitted with a different name
- Attribution use always permitted
- Packaging the code as a closed product under a different name is not permitted
- Commercial service "Savia Enterprise Support" (if monetized) is a separate service offering

## Dependency Compatibility

Permitted in Savia Enterprise components:
- MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC
- CC-BY-4.0 (documentation only)
- MPL-2.0 (file-level copyleft, compatible)

Not permitted:
- GPL-2.0, GPL-3.0 — copyleft incompatible with MIT distribution
- AGPL-3.0 — network use disclosure incompatible with sovereign deployment
- SSPL — not OSI-approved
- BSL — vendor lock-in

## Distribution Channels

- GitHub — source of truth, signed releases
- Anthropic Marketplace Skills — compatible components
- MCP Registry — SE-003 MCP servers
- npm / NuGet — SE-004 adapters
- Container registry — sovereign-ready images

## Governance

- Core maintainer: active user (docs/active-user.md)
- Optional technical committee if more than 5 active maintainers
- CLA not required (MIT does not need it)
- Code of Conduct: Contributor Covenant (CODE_OF_CONDUCT.md)
- Technical decisions: RFC process in docs/propuestas/

## Verification

Run scripts/enterprise/commercial-terms-check.sh to verify compliance with this policy.

## Related

- SPEC-SE-008 docs/propuestas/savia-enterprise/SPEC-SE-008-licensing-distribution.md
- scripts/enterprise/license-generator.sh
- scripts/enterprise/commercial-terms-check.sh
