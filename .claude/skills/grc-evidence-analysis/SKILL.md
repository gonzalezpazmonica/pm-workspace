---
name: grc-evidence-analysis
description: Valida procedencia y suficiencia de pruebas GRC. Usar cuando se evalúan controles, se revisan evidencias o se detectan contradicciones.
metadata:
  savia.maturity: incomplete
  savia.category: governance
  savia.context: standalone
  savia.context_cost: low
  savia.priority: high
  savia.tags: grc,evidence,audit
---
# GRC Evidence Analysis

## Authoritative Paths

| Para | Lee |
|---|---|
| Esquema operativo y estados | `docs/grc/README.md` |
| Verificador local | `scripts/grc-audit.py` |
| Pruebas negativas | `tests/test_grc_audit.py` |

## Flujo

1. Conserva original y registra identificador, ruta relativa, SHA-256, custodio, captura, periodo de validez, clasificación y alcance.
2. Distingue existencia documental, diseño del control y eficacia operativa. La evidencia debe probar el aspecto exacto del requisito evaluado.
3. Registra método, resultado y revisor de la prueba. `VERIFIED` y `HIGH` representan validación externa al modelo; nunca los asignes solo por inferencia.
4. Cruza evidencias favorables y adversas del mismo control. Si se contradicen, reporta `INSUFFICIENT_EVIDENCE` hasta resolverlas.
5. Si caducan, usa `NEEDS_REVIEW`; jamás crees una no conformidad formal por mera expiración.

## Límites

El hash prueba integridad respecto al archivo leído, no autenticidad de origen ni eficacia. Protege las fuentes confidenciales fuera del repositorio público.
