-- Template: attach audit trigger to a new table
-- Usage: replace <TABLE_NAME> with your target table
--
-- Prerequisites: audit-trigger.sql must have been applied first (creates
-- audit_log, audit_trigger_fn, and attach_audit procedure).
--
-- Reference: SPEC-SE-037 (docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md)
-- Doc: docs/rules/domain/savia-enterprise/audit-trigger-primitive.md

CALL attach_audit('<TABLE_NAME>'::regclass);
