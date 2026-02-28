---
name: Insurance Sector Regulations
description: Solvency II, IDD, GDPR, IFRS 17 compliance requirements
context_cost: low
---

# Insurance Sector Regulations

## Applicable Regulations

- **Solvency II**: EU 2009/138 capital and risk requirements
- **IDD**: Insurance Distribution Directive 2016/97
- **GDPR**: Policyholder data protection
- **IFRS 17**: Insurance contracts accounting

## Detection Markers

### Packages
- actuarial-*, solvency-*
- insurance-*, claims-*

### Entities
- Policy, Claim, Premium, Risk, Beneficiary, Underwriting, Reserve

### APIs
- /api/policies
- /api/claims
- /api/premiums
- /api/underwriting

### Configuration
- SOLVENCY_*
- IDD_*
- INSURANCE_*
- ACTUARIAL_*

## Compliance Checklist

- [ ] Policyholder data protection (GDPR)
- [ ] Suitability assessment before sale (IDD Art.30)
- [ ] Claims processing audit trail
- [ ] Reserve calculation documentation
- [ ] XBRL regulatory reporting (Solvency II)
- [ ] Product governance (IDD Art.25)
- [ ] Conflicts of interest management
- [ ] Risk modeling documentation
- [ ] Data quality for actuarial calculations
- [ ] Complaints handling procedure documented

## Common Violations

- No suitability assessment logged
- Claims without audit trail
- Missing XBRL regulatory reporting
- No product governance documentation
- Policyholder data without encryption

## Risk Assessment

**Severity**: Critical
**Scope**: Policy management, claims, capital
**Impact**: Solvency breach, regulatory action, consumer harm
