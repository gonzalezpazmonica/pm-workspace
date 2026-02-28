---
name: Defense & Military Sector Regulations
description: ITAR, NIST SP 800-171, EAR, and NATO STANAG standards for controlled defense information and classified data
context_cost: low
---

# Defense & Military Sector Regulatory Reference

## Applicable Regulations
- **ITAR**: International Traffic in Arms Regulations (22 CFR 120-130)
- **NIST SP 800-171**: Protecting Controlled Unclassified Information (CUI)
- **EAR**: Export Administration Regulations
- **NATO STANAG**: Interoperability standards and security requirements

## Detection Markers

### Packages
- `security-classification-*`, `cui-*`, `itar-*`, `mil-std-*`

### Entities
- Asset, Classification, Clearance, Mission, Personnel, Inventory, Export

### APIs
- `/api/assets`, `/api/clearances`, `/api/missions`, `/api/inventory`

### Configuration Keys
- `ITAR_*`, `CUI_*`, `CLASSIFICATION_*`, `CLEARANCE_*`

### Middleware & Services
- ItarAccessFilter, CuiMarkingMiddleware, ClassificationFilter, ClearanceChecker

### Database & Schema
- assets, clearances, missions, personnel, exports, classifications, inventories

### Folder & Namespace Patterns
- Defense/, Military/, Classified/, CUI/, Security/, Export/

### Documentation & CI/CD
- ITAR, CUI, NIST 800-171, clearance, classified, export control, CMMC

## Compliance Checklist

- [ ] Access restricted to authorized persons only (ITAR §120.1)
- [ ] US person verification for all ITAR data access
- [ ] CUI marking on all controlled documents (NIST 800-171)
- [ ] Encryption FIPS 140-2 validated
- [ ] Multi-factor authentication mandatory
- [ ] Audit trail for all classified access
- [ ] Security assessment per NIST 800-171A
- [ ] Incident response plan documented
- [ ] Media protection and sanitization procedures
- [ ] Personnel security with background checks tracked
- [ ] Export control checks before data transfer
- [ ] Physical security integration
- [ ] Cryptographic key management
- [ ] System security plans documented

## Common Violations

1. **No ITAR Access Restriction**: Controlled data accessible to unauthorized persons
2. **CUI Without Proper Marking**: Controlled information unmarked or unidentified
3. **Non-FIPS Encryption**: Unapproved cryptographic algorithms
4. **No US Person Verification**: Foreign nationals accessing ITAR data
5. **Export Without License Check**: Data transferred without export control review
6. **Missing Security Assessments**: NIST 800-171A compliance not documented
7. **Inadequate Audit Logging**: Access not tracked or logged
8. **No Media Sanitization**: Decommissioned hardware not properly destroyed
9. **Personnel Security Gaps**: Clearances not tracked or verified
10. **Physical Security Failures**: Classified information in unsecured locations

## Cross-References

- **ITAR §125.4**: License requirements for technical data
- **NIST 800-171 Rev.2**: 14 security requirement families for CUI
- **EAR Part 730**: Technology transfer and deemed export
