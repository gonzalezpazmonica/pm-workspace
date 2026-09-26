# SE-GRC-001 — GRC Auditor

**Estado:** MVP implementado; ampliaciones propuestas. **Fecha:** 2026-09-26.

## Objetivo y decisiones de diseño

Savia debe preparar evaluaciones GRC reproducibles a partir de requisitos, controles y evidencias, con hallazgos borrador y riesgos propuestos. La prueba verificable es la unidad de trabajo. Se prohíbe inferir certificación, aceptación de riesgo o conclusión jurídica definitiva desde el resultado.

La propuesta original abarca 29 skills, múltiples marcos y conectores. Una declaración de cobertura completa sería engañosa: no hay aquí corpus licenciado ni integraciones externas ni reglas de aplicabilidad jurídica por sector. El MVP separa el núcleo determinista de los futuros adaptadores. Los marcos entran como referencias verificadas y requisitos identificados por un auditor; el motor no fabrica obligaciones.

## Contrato del MVP

Entrada: JSON local con `scope` (id, systems, owner), `frameworks` (id, version, status, official_source, last_verified), `controls` (id, title, system_scope), `requirements` (id, framework, control, source_ref, applicability) y `evidence`. Cada evidencia exige id, título, ruta fuente, tipo, custodio, fechas, SHA-256, clasificación, marcos, controles, sistemas, confianza, estado de verificación y resultado de prueba. Ver ejemplo en `docs/grc/README.md`.

Salida: `PRELIMINARY_GRC_ASSESSMENT` con matriz, provenance, hallazgos borrador, riesgos propuestos y resumen ejecutivo. Estados: `COMPLIANT`, `NON_COMPLIANT`, `NOT_APPLICABLE`, `NOT_ASSESSED`, `INSUFFICIENT_EVIDENCE`, `NEEDS_REVIEW`; `PARTIALLY_COMPLIANT` reservado para metodología de pruebas parciales posterior. `COMPLIANT` describe solo el control probado dentro del alcance/periodo y sigue siendo preliminar.

La verificación normativa local vence a 90 días. Este umbral es una política operativa de frescura, no una prescripción legal. Antes de auditoría formal la persona auditora confirma vigencia y aplicabilidad en la fuente oficial. El hash detecta alteración del fichero local; no demuestra autenticidad ni validez material.

## Reglas invariantes

- Ninguna evidencia inventada o sin fichero/hash válido. Ningún estado `COMPLIANT` con prueba no verificada, baja confianza, caducada o contradictoria.
- La falta de evidencia produce `INSUFFICIENT_EVIDENCE`. Una evidencia caducada produce `NEEDS_REVIEW`, sin no conformidad automática.
- Una prueba adversa verificada genera hallazgo **borrador** con IDs de evidencia y riesgo **propuesto**. La severidad final y el tratamiento los decide una persona.
- El motor rechaza certificar, firmar legalmente, aceptar riesgos, cerrar hallazgos, aprobar políticas o alterar el estado oficial.
- NIS2 exige comprobar transposición nacional; guías y buenas prácticas nunca se presentan como obligaciones legales. Normas protegidas solo se referencian mediante metadatos y mappings propios.

## Criterios de aceptación y verificación

1. Paquete válido con prueba favorable verificada: matriz trazada, provenance y resumen preliminar.
2. Prueba adversa: hallazgo y riesgo propuestos, ambos ligados al requisito.
3. Faltan alcance, fuente o referencia: evaluación rechazada o marcada insuficiente.
4. Referencia obsoleta, vieja o evidencia alterada: error explícito.
5. Contradicción y caducidad: sin conformidad automática.
6. Acción reservada: error sin cambio de estado.

Ejecutar `python3 -m unittest tests/test_grc_audit.py -v`. Quedan pendientes pruebas de razonamiento del agente sobre confusión de credenciales, obligación frente a guía, copyright y confianza lingüística; el motor no procesa lenguaje natural ni puede garantizar estos cuatro casos por sí solo.

## OpenCode Implementation Plan

**Bindings:** `.opencode/agents/grc-auditor.md`; tres skills `.claude/skills/grc-*`; `scripts/grc-audit.py`; `tests/test_grc_audit.py`; documentación. **Portabilidad:** Python 3 estándar, local, sin red ni dependencias externas. **Evolución:** catálogo de requisitos revisado, mappings versionados, pruebas de eficacia por tipo de control, adaptadores de ENS/ISO/RGPD y después NIS2, CRA, DORA, IA, cloud, Microsoft 365 y proveedores. Los conectores de continuous compliance necesitan diseño de permisos y almacenamiento privado antes de implementarse.
