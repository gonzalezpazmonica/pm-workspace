---
name: Public Administration Sector Regulations
description: ENS, eIDAS, WCAG 2.1 AA, EIF, EU Accessibility Act 2025 compliance
context_cost: low
---

# Public Administration Sector Regulations

## Applicable Regulations

- **ENS**: Esquema Nacional de Seguridad (Spain)
- **eIDAS**: Electronic identification and trust
- **WCAG 2.1 AA**: Web accessibility standards
- **EIF**: European Interoperability Framework
- **EU Accessibility Act 2025**: Digital accessibility mandate

## Detection Markers

### Packages
- cl@ve, autofirma, @idena
- wcag-*, pa11y, axe-core, gov-*

### Entities
- Citizen, Procedure, Document, Certificate, Notification, Registry

### APIs
- /api/procedures
- /api/citizens
- /api/notifications
- /api/registry

### Configuration
- ENS_LEVEL
- EIDAS_*
- WCAG_*
- GOV_*

## Compliance Checklist

- [ ] ENS security level compliance (basic/medium/high)
- [ ] eIDAS electronic signatures (QES for high assurance)
- [ ] WCAG 2.1 Level AA all public pages
- [ ] Semantic HTML + ARIA labels
- [ ] Keyboard navigation support
- [ ] Multi-language support
- [ ] Interoperability APIs (EIF)
- [ ] Open data format exports
- [ ] Digital certificate authentication
- [ ] Transparent processing (GDPR Art.13-14)
- [ ] Notification audit trail

## Common Violations

- No WCAG compliance assessment
- Forms without ARIA labels
- Missing keyboard navigation
- No eIDAS integration
- ENS security not categorized
- PDFs not accessible

## Risk Assessment

**Severity**: High
**Scope**: Citizen services, public procedures
**Impact**: Access denial, legal non-compliance, discrimination
