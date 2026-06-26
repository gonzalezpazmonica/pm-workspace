---
name: Justice & Legal Sector Regulations
description: Judicial data protection, chain of custody, case management, GDPR for proceedings
context_cost: low
---

# Justice & Legal Sector Regulations

## Applicable Regulations

- **Judicial Data Protection**: LOPJ (Spain), EU Directive 2016/680
- **Chain of Custody**: Evidence requirements
- **Case Management Standards**: Procedural rules
- **GDPR**: Legal proceedings and sensitive data

## Detection Markers

### Packages
- legal-*, case-management, court-*
- evidence-*

### Entities
- Case, Evidence, Ruling, Party, Hearing, Sentence, Lawyer, Judge

### APIs
- /api/cases
- /api/evidence
- /api/hearings
- /api/rulings

### Configuration
- COURT_*
- JUDICIAL_*
- EVIDENCE_*

### Middleware & Services
- ChainOfCustodyMiddleware, EvidenceIntegrityFilter, CaseAccessLogger

### Database & Schema
- cases, evidence, hearings, rulings, parties, sentences, legal_documents

### Folder & Namespace Patterns
- Legal/, Court/, Judicial/, CaseManagement/, Evidence/

### Documentation & CI/CD
- judicial, court, evidence integrity, chain of custody, legal privilege

## Compliance Checklist

- [ ] Evidence chain of custody (immutable log)
- [ ] Case confidentiality by access level
- [ ] Judicial data isolation from other systems
- [ ] Anonymization in published rulings
- [ ] Digital evidence integrity (hash verification)
- [ ] Access logging for all case data
- [ ] Retention per judicial requirements
- [ ] Party notification tracking system
- [ ] Secure communication channels
- [ ] Legal professional privilege protection

## Common Violations

- Editable evidence records
- No hash verification on evidence
- Case data accessible without authorization
- Missing access logs
- No anonymization in exports

## Risk Assessment

**Severity**: Critical
**Scope**: Case management, evidence handling
**Impact**: Case dismissal, legal liability, justice system integrity
