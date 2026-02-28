---
name: Telecommunications Sector Regulations
description: ePrivacy Directive, GDPR telecom provisions, BEREC guidelines, and NIS2 requirements for carriers and VoIP providers
context_cost: low
---

# Telecommunications Sector Regulatory Reference

## Applicable Regulations
- **ePrivacy Directive**: 2002/58/EC communication confidentiality and metadata
- **GDPR**: General Data Protection Regulation with telecom-specific provisions
- **BEREC Guidelines**: Net neutrality and traffic management
- **NIS2 Directive**: Network security for essential telecom operators

## Detection Markers

### Packages
- `telecom-*`, `voip-*`, `sip-*`, `asterisk-*`, `twilio-*`, `vonage-*`

### Entities
- Subscriber, Call, Message, CDR, Number, Network, SIM

### APIs
- `/api/calls`, `/api/messages`, `/api/subscribers`, `/api/cdr`

### Configuration Keys
- `TELECOM_*`, `CDR_*`, `VOIP_*`, `CARRIER_*`

## Compliance Checklist

- [ ] Communication confidentiality enforced (ePrivacy Art.5)
- [ ] Metadata retention per country-specific legal requirements
- [ ] Subscriber consent for data processing documented
- [ ] Location data only with explicit consent (ePrivacy Art.9)
- [ ] Lawful interception capability implemented per national law
- [ ] CDR retention policy (12-24 months typical)
- [ ] Traffic management transparency (net neutrality)
- [ ] Security measures notification to subscribers
- [ ] Breach notification to authority within 72 hours
- [ ] End-to-end encryption for messaging
- [ ] Subscriber access rights implementation
- [ ] Third-party SIM/number verification

## Common Violations

1. **Location Data Without Consent**: Tracking subscribers without explicit permission
2. **CDR Retention Exceeding Legal Limits**: Keeping call records longer than required
3. **No Subscriber Consent Management**: Processing without documented authorization
4. **Metadata Exposed in APIs**: CDR/metadata accessible via unsecured endpoints
5. **Missing E2E Encryption**: Unencrypted message transmission
6. **Traffic Discrimination**: Blocking/throttling without transparency
7. **Delayed Breach Notification**: Not reporting incidents within 72 hours
8. **SIM Swap Vulnerabilities**: Inadequate number authentication

## Cross-References

- **ePrivacy Art.5 & Art.9**: Fundamental provisions on communication secrecy
- **GDPR Art.82**: Liability for breaches applying to telecom operators
