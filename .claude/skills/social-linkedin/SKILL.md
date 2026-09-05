---
name: social-linkedin
description: >-
  Provider skill de LinkedIn para el agente social-networks (SE-385 MVP1).
  Import manual del export oficial, modelo neutral SocialArtifact, digests
  locales (themes/savia-history/writing-style) y status de capabilities.
  Jamás publica sin external-publish-gate + approval hash. Datos en
  ~/.savia/social/linkedin (local-first, CRIT-001).
---

# LinkedIn Provider Skill (MVP1 — read/import)

## Estado de capabilities (permission discovery, §43)

| Capability | Estado MVP1 | Origen del dato |
|---|---|---|
| read_profile | UNKNOWN | requiere API product aprobado |
| import_portability | REQUIRES_APPROVAL | EEA/CH + producto DMA (probe 2026-09-05) |
| import_manual | SUPPORTED | export ZIP oficial del propio miembro |
| read_posts | UNKNOWN vía API; SUPPORTED vía export | Snapshot API pendiente de producto |
| draft_local | SUPPORTED (fase 2) | local |
| publish_post | NOT_GRANTED | ninguna API product concede publish en MVP1 |
| edit/delete_post | NOT_GRANTED | gate independiente pendiente (L4) |
| analytics | NOT_AVAILABLE | fuera de MVP |

Error ante capability no concedida: `LINKEDIN_PERMISSION_NOT_GRANTED`.

## Uso

```bash
# Importar export oficial (ZIP descargado por la operadora)
python3 scripts/social-linkedin-import.py --zip ~/Downloads/linkedin-export.zip

# Status (capabilities + almacén local)
python3 scripts/social-linkedin-status.py

# Digests locales (themes, savia-history, writing-style)
python3 scripts/social-linkedin-digest.py
```

Almacén: `~/.savia/social/linkedin/{raw/,normalized/,derived/,receipts/,manifest.json}`.

## Garantías MVP1

- Provenance obligatoria por artefacto (provider, acquisition=manual_export,
  acquired_at, source_file, source_hash) — sin tokens jamás.
- Dedupe por (provider, provider_id) o content_hash — import idempotente.
- origin=untrusted: el contenido importado jamás se ejecuta ni promueve a
  memoria confiable sin trust-gate (memory-origin-gate).
- Solo SELF_AUTHORED alimenta writing-style.
- Posts NUNCA se inyectan completos en contexto: progressive disclosure
  (L0 índice → L1 digest → L2 fragmentos → L3 completo bajo demanda).
- Retention metadata por artefacto (manual_user_export: user_owned_source).
- Documentación pin: portability docs verificadas 2026-09-05
  (view li-dma-data-portability-2026-08, ms.date 2026-04-07). Revisar en
  `/social linkedin compliance-check` (próxima fase) o al implementar MVP2.

## Fuera de alcance MVP1

OAuth programático (el producto DMA usa OAuth Token Generator manual, solo
EEA/CH), publish/edit/delete, analytics, scraping (prohibido §40/41 SE-385).
