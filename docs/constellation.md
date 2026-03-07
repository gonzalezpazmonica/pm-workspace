# Constellation Diagram — pm-workspace

> Visual map of all components and their relationships.
> Generated: 2026-03-07 · Era 87 · Stability Roadmap complete

## Component Overview

```
                          ┌─────────────────────────┐
                          │   🌳 SAVIA CORE         │
                          │   settings.json          │
                          │   CLAUDE.md              │
                          └────────┬────────────────┘
                                   │
              ┌────────────┬───────┼───────┬────────────┐
              ▼            ▼       ▼       ▼            ▼
     ┌────────────┐ ┌──────────┐ ┌────┐ ┌──────┐ ┌─────────┐
     │📝 Commands │ │🧠 Skills │ │🤖  │ │🛡️    │ │📏 Rules │
     │    454     │ │    67    │ │ 33 │ │  17  │ │   105   │
     │            │ │          │ │Agt │ │Hooks │ │ domain  │
     └─────┬──────┘ └────┬─────┘ └──┬─┘ └──┬───┘ └─────────┘
           │              │          │      │
           └──────┬───────┴──────────┘      │
                  │                          │
                  ▼                          ▼
     ┌─────────────────────────────────────────────────────┐
     │              🧪 QUALITY INFRASTRUCTURE              │
     │                                                     │
     │  Tests ─── Audit ─── Coverage ─── Security ─── Vuln │
     │   119      L0-L3      65%         0 findings   0    │
     │                                                     │
     │              🏥 Health: 84% (B)                     │
     └─────────────────────┬───────────────────────────────┘
                           │
                           ▼
     ┌─────────────────────────────────────────────────────┐
     │                  🔄 CI/CD Pipeline                  │
     │                                                     │
     │  Validate ──── BATS Tests ──── Markdown Lint        │
     │  (JSON,secrets) (audit,coverage,security,vuln)      │
     └─────────────────────────────────────────────────────┘
```

## Skills Maturity Distribution

```
  🟢 Stable (51)  ████████████████████████████████████████████░░░░░░  76%
  🟡 Beta    (2)  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   3%
  🔴 Alpha  (14)  ██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  21%
```

## Health Score Breakdown

```
  Skill completeness    ████████████████████ 98%  A
  Command completeness  ████████████████████ 100% A
  Maturity distribution ████████████████░░░░ 83%  B
  Test coverage         ███████░░░░░░░░░░░░░ 35%  F
  Security posture      ████████████████████ 100% A
  Documentation         ████████████████████ 100% A
  ─────────────────────────────────────────────────
  Overall               ████████████████░░░░ 84%  B
```

## Stability Roadmap (Eras 79–87)

```
  Era 79  ✅ BATS Testing ─────────┐
  Era 80  ✅ Test Quality ──────────┤
  Era 81  ✅ Coverage Metrics ──────┤
  Era 82  ✅ Security Hardening ────┤──→ Quality Infrastructure
  Era 83  ✅ Maturity Levels ───────┤
  Era 84  ✅ Discoverability ───────┤
  Era 85  ✅ Mock Mode ─────────────┤
  Era 86  ✅ Vulnerability Scanner ─┤
  Era 87  ✅ Strategic Vision ──────┘
```

## Key Relationships

- **Commands → Skills**: Commands invoke skill logic for complex operations
- **Commands → Agents**: Commands delegate to specialized agents for multi-step tasks
- **Hooks → Commands**: PreToolUse hooks validate and gate command execution
- **Skills → Agents**: Skills define context for agent specialization
- **Tests → Hooks**: BATS test suites validate hook behavior
- **CI → Testing**: All quality scripts run in GitHub Actions pipeline
- **Health → All**: Dashboard aggregates signals from every component category

---

*Generado por Savia — pm-workspace v2.58.0*
