# SPEC-OC-01 — Savia Shield OpenCode Adaptation

**Date:** 2026-06-24

## SPEC-OC-01 — Savia Shield OpenCode Adaptation

Guards que protegen datos en sesiones OpenCode ya existían en .opencode/plugins/guards/;
este entry cierra los gaps de diagnóstico, documentación y verificabilidad.

### scripts/savia-shield-check.sh (new)

Verifica el estado del Savia Shield para sesiones OpenCode.
- Detecta los 8 componentes críticos: data-sovereignty-gate, data-sovereignty-audit,
  sovereignty-patterns, block-credential-leak, context-sanitize-input,
  savia-foundation-wired, block-credential-leak-wired, doc
- Reporta shield_status: active | partial | inactive con exit codes 0/1/2
- Flag --json produce JSON parseable para integración con otros scripts
- Soporta SAVIA_WORKSPACE_DIR y fallback chain CLAUDE_PROJECT_DIR / OPENCODE_PROJECT_DIR / git root

### docs/rules/domain/savia-shield-opencode.md (new)

Documentación operativa del Savia Shield bajo OpenCode v1.14:
- Tabla de capas activas (guards TS vs bash hooks)
- Qué datos protege: N1-N4b, tipos de credencial bloqueados
- Cómo activar (automático via plugin) y variables de entorno opcionales
- Verificación con savia-shield-check.sh
- Diferencias respecto a Claude Code
- Diagnóstico de problemas comunes

### tests/bats/test-spec-oc-01-shield.bats (new)

10 tests BATS — todos PASS:
- Script existe y es ejecutable
- --json produce JSON válido
- Campos shield_status, components, missing presentes
- context-sanitize-input aparece como componente cuando existe
- data-sovereignty-gate detectado como componente
- savia-foundation-wired detectado
- shield_status active cuando todos los componentes presentes
- Secciones requeridas en la doc
- Tabla comparativa OpenCode vs Claude Code en doc
