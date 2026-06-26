## SPEC-073 — Query Keyword Expansion (2026-06-24)

### Added
- `scripts/query-keyword-expand.py`: Stdlib-only query expansion for pre-search recall improvement
  - CamelCase splitting: authService → [auth, service, authservice]
  - snake_case splitting: auth_service → [auth, service]
  - Acronym map: ADO→Azure DevOps, KG→Knowledge Graph, JWT→JSON Web Token, + 14 more
  - Domain synonyms: auth↔[authentication, login, jwt, ...], spec↔[specification, requirement, ...]
  - Simple ES/EN stemming (no external deps)
  - Output JSON: `{original, expanded, synonyms, search_terms}`
  - CLI: `--query "text"` → JSON to stdout; empty query → graceful exit 0
- `tests/scripts/test_query_keyword_expand.py`: 33 pytest tests

### Tests
- 33/33 passing — CamelCase/snake_case split, auth synonyms, ADO/KG acronyms,
  all 4 output fields, search_terms non-empty, empty query graceful, synonyms non-empty
