# project-update — changelog y validaciones

## Validación 2026-04-30

- F0 graceful degrade: ✅ `probe_auth_per_account` parsea check-daemon-auth.sh; cuentas marcadas error → account_skip; resto continúa.
- F1 partial run: ✅ con auth caducada, mail+calendar+devops siguen produciendo outputs (5/13 jobs OK en validación).
- F2 transcript ingest: ✅ ingiere `**/*.vtt` + `**/*.transcript.txt` (recap-panel scrolling) recursivo.
- F3 radar consolidator: ✅ produce radar.md determinista, idempotente. Smoke contra Project Aurora extrae 30 action items consolidados de 6 digests rich.
- 61 tests pasando.

## Validación 2026-04-29

- Auth gate: ✅
- DevOps via wrapper: ✅ 822 work items, 69 PRs, 31 pipelines, 18 repos
- OneDrive recent (account1+account2): ✅
- SharePoint Recordings list: ✅ account1 70 recs / account2 6 recs (folder names difieren por locale: `Recordings` vs `Grabaciones` — persistido en mail-accounts.json)
- Teams transcript extraction: ✅ 5 VTTs digeridos previamente; pipeline confirmado para no-owner via Recap iframe.

## Roadmap pendiente

1. F3 análisis (script determinista que consolida F1+F2).
2. F4 sync con Gitea machine-local.
3. Wrappers idénticos a `project-update-devops.sh` para los demás sources si la firma de algún script cambia.
4. Fix proxy Shield: unmask de tool-args para que `Project Aurora` en mi código se traduzca al nombre real al ejecutar (independiente de este skill).
