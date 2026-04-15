---
spec_id: SPEC-104
title: Tagged PDF output for compliance-sensitive reports (legal, healthcare)
status: Proposed
origin: opendataloader-pdf accessibility pipeline (2026-04-15)
severity: Media
effort: ~4h (bloqueado hasta opendataloader Q2 2026)
---

# SPEC-104: Tagged PDF Output for Compliance Reports

## Problema

Cuando Savia genera reportes en PDF (via LibreOffice, weasyprint o similar):
- `ceo-report`, `compliance-report`, `governance-report`, `stakeholder-report`
- Contratos, informes legales (`vertical-legal`)
- Documentación clínica (`vertical-healthcare`)

Estos PDFs NO son Tagged PDFs. Fallan validaciones:
- **EU Accessibility Act** (entrada en vigor 2025)
- **PDF/UA-1, PDF/UA-2** (ISO 14289)
- **WCAG 2.2 AA** para contenido digital
- **Section 508** (US)

Remediación manual: $50-200 por documento. No escala.

## Solucion

Cuando opendataloader-pdf libere auto-tagging (anunciado Q2 2026):

1. Pipeline de generación de reports añade paso final "tagify":
   ```
   markdown/html → PDF → opendataloader auto-tag → Tagged PDF
   ```

2. Validar con veraPDF antes de entregar:
   ```bash
   verapdf --flavour ua1 output/ceo-report.pdf
   ```

3. Comandos afectados reciben flag `--accessible`:
   - `/ceo-report --accessible`
   - `/compliance-report --accessible`
   - `/governance-report --accessible`
   - `/report-executive --accessible`

4. Verticals legal/healthcare: `--accessible` default true en
   `vertical-legal`, `vertical-healthcare`.

## Criterios de aceptacion

- [ ] `scripts/pdf-tagify.sh` wrapper sobre opendataloader auto-tag
- [ ] Integración con pipeline de generación de reports
- [ ] Validación automática veraPDF post-tagify
- [ ] Flag `--accessible` en los 4 comandos de reports
- [ ] Default `--accessible=true` en verticals legal/healthcare
- [ ] Tests BATS >= 8 casos (con PDF samples)
- [ ] Documentación en `.claude/rules/languages/` o `docs/accessibility.md`

## Restricciones

- **TAG-01**: Bloqueado hasta opendataloader publique auto-tagging (Q2 2026)
- **TAG-02**: veraPDF no debe ejecutarse contra PDFs de cliente N4 sin consentimiento (metadata puede exponer datos)
- **TAG-03**: Solo reports generados por Savia son tagificados; PDFs externos NO se modifican

## Dependencias

- SPEC-102 (opendataloader integration) — blocker directo
- Release opendataloader Q2 2026 con auto-tagging — blocker externo

## Out of scope

- PDF/UA enterprise export (es add-on propietario de opendataloader)
- Migración de PDFs históricos ya entregados
- WCAG 2.2 audit de HTML/web (otro dominio)

## Justificacion

EU Accessibility Act entra en vigor 2025 con multas hasta 500K€ por
producto no conforme. Clientes enterprise en legal/healthcare/banking
necesitan evidencia de Tagged PDFs para:
- Auditorías públicas de accesibilidad (AEPD, MITIC, AEPD-equivalentes)
- Procurement público (requiere PDF/UA en muchas AAPP)
- Compliance interno de grandes corporaciones

Automatizar la generación ahorra el coste de remediación manual ($50-200/doc)
y elimina el gap entre "compliance en prosa" y "compliance medible".

## Referencias

- [PDF/UA ISO 14289](https://www.iso.org/standard/64599.html)
- [EU Accessibility Act](https://ec.europa.eu/social/main.jsp?catId=1202)
- [opendataloader accessibility pipeline](https://opendataloader.org/docs/pdf-ua)
- [Well-Tagged PDF spec](https://pdfa.org/wtpdf/)
- [veraPDF validator](https://verapdf.org/)
