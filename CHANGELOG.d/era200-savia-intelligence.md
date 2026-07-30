---
version_bump: minor
section: Added
---

### Added

- SE-276: Proactive skill suggestion engine (skill-suggest.sh) with silence mode, 500ms timeout, configurator integration

- SE-277: Multi-target skill distribution CLI (savia-skills.sh) + skills-manifest.json (136 skills)

- SE-278: Semantic skill quality pipeline with 8-dimension rubric, LLM judge, hash cache, batch evaluation

- SE-279: Scheduled monitoring detector framework (always-on-runner.sh) with 5 detectors and cron installer

- SE-280: SaviaVaults — Context Dome Server, MCP + A2A transports, git-backed storage, BM25 search, Ed25519 signing, 6-layer security sandbox

- SE-281: SaviaVaults gap corrections — multi-vault config, A2A auth, rate limiting, search index persistence

- SE-282: Savia Federate — cross-dome federation layer, registry, cache, A2A client, parallel search with merge/dedup/interleave

- SE-283: Savia Federate security hardening — circuit breaker, audit logger, content hash verification, TLS support

- SaviaVaults: 46 files, 90+ tests, 43 e2e passing, docs EN/ES

- Skills doctor: health check for drift, broken symlinks, orphans, maturity breakdown
