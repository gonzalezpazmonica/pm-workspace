---
name: Healthcare Sector Regulations
description: HIPAA, HL7/FHIR, GDPR Article 9, EU MDR compliance requirements
context_cost: low
---

# Healthcare Sector Regulations

## Applicable Regulations

- **HIPAA**: §164.312 (security), §164.530 (privacy)
- **HL7/FHIR**: Health Level 7 interoperability standards
- **GDPR Article 9**: Special category data (health)
- **EU MDR**: Medical device regulation

## Detection Markers

### Packages
- hl7-fhir-r4, hapi-fhir, fhirpath
- hipaa-*, medplum

### Entities
- Patient, MedicalRecord, Diagnosis, Prescription, Appointment

### APIs
- /api/patients
- /api/encounters
- /api/observations

### Configuration
- FHIR_SERVER_URL
- HIPAA_MODE
- EHR_*

### Middleware & Services
- AuditMiddleware, ConsentMiddleware, PhiProtection, HipaaFilter

### Database & Schema
- patients, medical_records, prescriptions, diagnoses, encounters, phi_audit_log

### Folder & Namespace Patterns
- Healthcare/, Clinical/, PHI/, FHIR/, EHR/

### Documentation & CI/CD
- HIPAA, PHI, medical, clinical, patient privacy

## Compliance Checklist

- [ ] PHI encryption at-rest (AES-256 minimum)
- [ ] TLS 1.2+ for all transmissions
- [ ] Audit trail on all PHI access events
- [ ] RBAC with minimum necessary access principle
- [ ] Patient consent management system
- [ ] Right to access records implementation
- [ ] Breach notification process documented
- [ ] BAA with all third parties
- [ ] FHIR format for interoperability
- [ ] Medical device data integrity (EU MDR)

## Common Violations

- Unencrypted patient data in database
- No audit log on record access
- PHI in logs or error messages
- Missing consent before processing
- Hardcoded credentials for EHR integration

## Risk Assessment

**Severity**: Critical
**Scope**: Direct patient care systems
**Impact**: Privacy violations, regulatory fines, patient trust
