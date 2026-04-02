# Gap Analysis: savia-monitor vs savia-model-rust-desktop

> Measured: 2026-04-02

## Scoring: 0 absent | 1 partial | 2 compliant | 3 exemplary

## S1: Philosophy and Culture — Score: 1
CLAUDE.md documents stack but no philosophy section. No WHY Tauri over Electron.
**Fix:** Add philosophy. **1h | low**

## S2: Architecture Principles — Score: 1
Core-Shell exists implicitly (Rust backend + Vue frontend).
**Gap:** main.rs is 107 lines (model says <40). Background polling uses std::thread::spawn + std::thread::sleep instead of tokio async. CLAUDE.md lists 8 modules but only 2 exist (config.rs, shield.rs). No domain module separation.
**Fix:** Refactor main.rs, extract setup, align docs with reality. **16h | high**

## S3: Project Structure — Score: 1
Basic Tauri 2 structure. 5 Vue components + 1 composable + 1 store.
**Gap:** No types/ for shared Rust-TS types. No ts-rs. No Cargo workspace. No commands/ module. CLAUDE.md structure lies.
**Fix:** Create proper modules, add types/, align docs. **8h | high**

## S4: Code Patterns — Score: 1
Tauri commands decorated correctly. serde derive for serialization.
**Gap:** reqwest::blocking instead of async. unwrap() on icon loading. let _ = silently ignores errors (6 occurrences). No thiserror. No type sharing.
**Fix:** Async migration, thiserror, fix error handling. **12h | high**

## S5: Testing and Quality — Score: 0
Only 1 Vue store test file. Zero Rust tests. No E2E. No IPC tests. No coverage.
**Fix:** Add Rust + Vue + IPC tests. **16h | CRITICAL**

## S6: Security and Data Sovereignty — Score: 1
capabilities/default.json exists. Polls localhost only.
**Gap:** No CSP. No IPC validation. No code signing. reqwest without TLS config.
**Fix:** Add CSP, validate IPC, configure signing. **8h | high**

## S7: DevOps and Operations — Score: 0
No CI/CD. No cross-platform build. No auto-update. No crash reporting. No release profile optimizations.
**Fix:** CI pipeline, release profile, auto-update. **16h | high**

## S8: Anti-Patterns and Guardrails — Score: 0
main.rs 107 lines (model <40). blocking HTTP in async. let _ = silences errors (6x). std::thread::sleep for polling. No clippy CI. CLAUDE.md lists non-existent modules.
**Fix:** Fix all violations + clippy enforcement. **12h | high**

## S9: Agentic Integration — Score: 1
CLAUDE.md exists with basic docs.
**Gap:** No Layer Assignment Matrix. No SDD specs. No quality gates.
**Fix:** Add agentic section. **4h | medium**

## Summary

| Section | Score | % |
|---------|-------|---|
| 1. Philosophy | 1 | 33% |
| 2. Architecture | 1 | 33% |
| 3. Structure | 1 | 33% |
| 4. Code Patterns | 1 | 33% |
| 5. Testing | 0 | 0% |
| 6. Security | 1 | 33% |
| 7. DevOps | 0 | 0% |
| 8. Anti-Patterns | 0 | 0% |
| 9. Agentic | 1 | 33% |
| **TOTAL** | **6/27** | **22%** |

## Top 5 Actions
1. Add Rust + Vue tests (0 coverage) — CRITICAL — 16h
2. Refactor main.rs + async migration + error handling — HIGH — 16h
3. Add CI pipeline + release profile — HIGH — 16h
4. Fix anti-patterns + align CLAUDE.md with reality — HIGH — 12h
5. Add CSP + IPC validation + code signing — HIGH — 8h

**Effort to compliant (2): ~92h | To exemplary (3): ~140h**
