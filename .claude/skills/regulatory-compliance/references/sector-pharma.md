---
name: Pharmaceutical Sector Regulations
description: GxP compliance, FDA 21 CFR Part 11, EU Annex 11, and EMA guidelines for drug manufacturing and clinical trials
context_cost: low
---

# Pharmaceutical Sector Regulatory Reference

## Applicable Regulations
- **GxP Standards**: GMP (Good Manufacturing Practice), GCP (Good Clinical Practice), GLP (Good Laboratory Practice)
- **FDA 21 CFR Part 11**: Electronic records and electronic signatures
- **EU Annex 11**: Computerised systems validation
- **EMA Guidelines**: European Medicines Agency requirements

## Detection Markers

### Packages
- `pharma-*`, `gxp-*`, `clinical-trial-*`, `drug-*`

### Entities
- Drug, ClinicalTrial, Batch, Formulation, AdverseEvent, Validation, Protocol

### APIs
- `/api/trials`, `/api/batches`, `/api/drugs`, `/api/adverse-events`

### Configuration Keys
- `GXP_*`, `FDA_*`, `ANNEX11_*`, `PHARMA_*`

## Compliance Checklist

- [ ] Audit trails automatic, read-only, timestamped (21 CFR 11.10(e))
- [ ] System validation documented (Annex 11 §4)
- [ ] Electronic signatures with identity verification (21 CFR 11.100)
- [ ] Data integrity ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate)
- [ ] Change control with approval workflows
- [ ] User access management with training records
- [ ] Batch record integrity maintained
- [ ] Adverse event reporting enabled
- [ ] Backup/restore procedures validated
- [ ] Records readable throughout retention period

## Common Violations

1. **Editable Audit Trails**: Audit logs that allow modification or deletion
2. **Missing System Validation**: No documented validation evidence
3. **E-signatures Without Identity Verification**: Signatures not tied to unique identifiers
4. **No Change Control Workflow**: Changes made without approval trail
5. **Batch Records Without Integrity Checks**: No data integrity verification
6. **Insufficient Access Controls**: User permissions not properly managed
7. **No Adverse Event Tracking**: Unreported safety incidents

## Cross-References

- **FDA 21 CFR Part 11**: Shared with food-agriculture sector for electronic records requirements
- **ALCOA+ Principles**: Applied across all regulated industries handling electronic records
