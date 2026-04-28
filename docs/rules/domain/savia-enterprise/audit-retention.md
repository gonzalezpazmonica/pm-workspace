# Regla: Audit Log Retention Policy

> **Era 232** — Savia Enterprise. Retention finita por categoría regulatoria. **Append-only NO significa infinito**: GDPR Art. 30, ISO-42001 Annex A y derecho mercantil EU obligan ventanas de retention definidas y purga periódica. Esta política es obligatoria — `audit-purge.sh` se niega a correr si este doc no existe.

## Categorías y ventanas

| Categoría | Tablas (ejemplos) | Retention | Justificación regulatoria |
|---|---|---|---|
| **Compliance evidence** | `compliance_events`, `iso_evidence`, `audit_certifications` | **5 years** | ISO-42001 Annex A — audit retention mínimo |
| **Billing / financial** | `billing_invoices`, `subscriptions`, `transactions`, `tax_records` | **10 years** | EU commercial + tax law (varía por país; 10 años es el max común) |
| **Project / contract** | `projects`, `contracts`, `slas` | **10 years** | Mismo régimen comercial; coherencia con billing |
| **Agent activity / session** | `agent_sessions`, `agent_runs`, `agent_traces` | **90 days** | Operacional; nada personal — retention corta evita acumulación inútil |
| **User actions on personal data** | `user_profiles`, `user_consents`, `personal_settings` | **3 years** | GDPR Art. 30 + Recital 82 — accountability mínima sin sobre-retención |
| **API keys / authentication** | `api_keys`, `jwt_revocations`, `failed_logins` | **2 years** | Forensics security; suficiente para investigaciones post-incident sin retener tokens cargados de PII |
| **System / DB schema** | `schema_migrations`, `db_versions` | **forever (no purge)** | Auditable trail del schema histórico — no contiene PII, valor archivado |

## Reglas operativas

### 1. Purga sólo por categoría

`audit-purge.sh --before <date> --table <name>` purga UNA tabla a la vez. NUNCA purga `WHERE 1=1`. El script extrae la categoría de la tabla por mapping en este doc; si la tabla no está mapeada, REFUSES con mensaje "tabla no clasificada en audit-retention.md".

### 2. Confirm flag obligatorio

El script REFUSES sin `--confirm`. Pre-purge calcula count y muestra:

```
Pre-purge: 12,438 rows in audit_log WHERE table_name='agent_sessions' AND created_at < '2026-01-28'
Category: Agent activity / session
Retention: 90 days (per audit-retention.md)

Confirm with --confirm to proceed.
```

### 3. Logging post-purge

Cada purga escribe a `output/audit-purge-log/YYYY-MM-DD.log` con:
- Timestamp
- Operator (env `USER` + `current_setting('savia.user_id')`)
- Table + count + cutoff date
- Categoría aplicada
- Retention policy hash (sha256 de este doc al momento de la purga)

El hash permite forensics: "¿qué política regía en el momento de esta purga?".

### 4. Retention nunca se acorta retroactivamente

Si esta política se actualiza para acortar una ventana (e.g., 5 → 3 años), las rows con created_at anteriores al cambio mantienen la retention vieja. El cambio aplica solo a rows posteriores al cambio del doc. Esto evita purgar evidencia que cuando se generó tenía promesa de retention más larga.

### 5. Retention nunca se alarga unilateralmente sin GDPR DPIA

Alargar retention requiere DPIA documentado (Data Protection Impact Assessment). El skill `legal-compliance` tiene el template.

## Casos especiales

### Datos personales bajo GDPR Article 17 (Right to Erasure)

Si un usuario ejerce su derecho al olvido, el `audit_log` para sus rows puede mantenerse SIN PII identificable: el script `audit-anonymize.sh` (futuro, post Era 232) sustituirá `user_id` y campos `_row` derivados por hashes irreversibles, manteniendo el record para forensics pero sin identificar.

NO está implementado en este Slice — es trabajo futuro.

### Litigation hold

Si una autoridad judicial impone hold sobre datos, la categoría afectada NO se purga hasta que el hold expira. El script consulta `docs/legal/litigation-holds.md` (si existe) y refuses purgar tablas listadas.

NO está implementado en este Slice — es trabajo futuro.

### Tablas de hipertabla / particionadas

Para `audit_log` muy grande, partitioning por mes (extension `pg_partman`) acelera la purga: drop partition completa en lugar de DELETE row-by-row. Recomendación operacional para >100M rows; no obligatorio.

## Referencias

- SPEC-SE-037 — spec madre
- `audit-trigger-primitive.md` — reglas del trigger
- `scripts/enterprise/audit-purge.sh` — implementación del purge
- ISO/IEC 42001:2023 Annex A.7 — audit retention
- GDPR Art. 5(1)(e) — storage limitation principle
- GDPR Art. 30 — records of processing
- GDPR Recital 82 — accountability records
