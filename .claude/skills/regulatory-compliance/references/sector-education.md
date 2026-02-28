---
name: Education Sector Regulations
description: FERPA, COPPA, CIPA, and GDPR provisions protecting student data and privacy for educational institutions
context_cost: low
---

# Education Sector Regulatory Reference

## Applicable Regulations
- **FERPA**: Family Educational Rights and Privacy Act (20 USC §1232g)
- **COPPA**: Children's Online Privacy Protection Act (15 USC §6501-6506)
- **CIPA**: Children's Internet Protection Act
- **GDPR**: General Data Protection Regulation with children's data provisions (Art.8)

## Detection Markers

### Packages
- `edtech-*`, `lms-*`, `school-*`, `student-*`, `canvas-api`, `moodle-*`

### Entities
- Student, Grade, Course, Enrollment, Teacher, Guardian, Transcript, Assignment

### APIs
- `/api/students`, `/api/grades`, `/api/courses`, `/api/enrollments`

### Configuration Keys
- `FERPA_*`, `COPPA_*`, `LMS_*`, `SCHOOL_*`

## Compliance Checklist

- [ ] Student records access restricted per authorization (FERPA §99.30)
- [ ] Parental consent obtained for children under 13 (COPPA)
- [ ] Verifiable parental consent mechanism implemented
- [ ] Directory information opt-out enabled
- [ ] Students 18+ can access own records independently
- [ ] Third-party data sharing agreements in place
- [ ] Data minimization principles applied for minors
- [ ] Age verification system implemented
- [ ] Content filtering enabled (CIPA compliance)
- [ ] Annual FERPA notification to parents
- [ ] De-identification procedures for research use
- [ ] Data breach notification to parents documented
- [ ] Staff training on FERPA requirements

## Common Violations

1. **Unrestricted Student Data Access**: Records viewable without proper authorization
2. **No Parental Consent for Minors**: Processing children's data without permission
3. **Third-party Analytics Tracking Minors**: Sharing with marketing platforms
4. **Missing Age Verification**: No mechanism to verify student age
5. **Student PII in URLs/Logs**: Sensitive data exposed in requests
6. **Directory Information Not Opt-out Ready**: No privacy controls for listed information
7. **No Data Sharing Agreements**: Third-parties lacking contractual protections
8. **Insufficient Content Filtering**: CIPA non-compliance in school networks

## Cross-References

- **FERPA §99.37**: Breach notification procedures
- **COPPA Verifiable Consent**: Specific mechanisms (email plus confirmation, credit card)
- **GDPR Art.8**: Age of digital consent in EU (typically 13-16 years)
