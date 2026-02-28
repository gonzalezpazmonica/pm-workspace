---
name: Energy & Utilities Sector Regulations
description: NERC CIP, NIS2 Directive, and IEC 62351 standards for power system security and grid operations
context_cost: low
---

# Energy & Utilities Sector Regulatory Reference

## Applicable Regulations
- **NERC CIP**: Critical Infrastructure Protection standards (CIP-002 to CIP-014)
- **NIS2 Directive**: EU 2022/2555 network and information security
- **IEC 62351**: Power systems security standards

## Detection Markers

### Packages
- `scada-*`, `modbus-*`, `iec61850-*`, `smart-grid-*`, `nerc-*`

### Entities
- Grid, Meter, Asset, Substation, Generator, SCADA, Outage

### APIs
- `/api/grid`, `/api/meters`, `/api/assets`, `/api/outages`

### Configuration Keys
- `NERC_*`, `NIS2_*`, `SCADA_*`, `GRID_*`

## Compliance Checklist

- [ ] MFA required for all remote access (CIP-005)
- [ ] Critical patches applied within 35 days (CIP-007)
- [ ] Supply chain security controls implemented (CIP-013)
- [ ] Incident reporting within 72 hours (NIS2 Art.23)
- [ ] BES Cyber Systems identified and documented (CIP-002)
- [ ] Access management with authorization levels (CIP-004)
- [ ] Security monitoring and alerting enabled (CIP-007)
- [ ] Configuration change management process (CIP-010)
- [ ] Quarterly vulnerability assessments
- [ ] Annual recovery plan testing (CIP-009)
- [ ] Physical security measures in place
- [ ] Incident response plan documented

## Common Violations

1. **No MFA on Remote Access**: Single-factor authentication on critical systems
2. **Unpatched Systems**: Critical vulnerabilities not remediated timely
3. **Missing Supply Chain Verification**: Third-party risks not assessed
4. **No Incident Response Plan**: Unpreparedness for security events
5. **SCADA Without Authentication**: Legacy systems lacking access controls
6. **No Configuration Baseline**: Changes not tracked or verified
7. **Inadequate Monitoring**: Security events not detected or logged
8. **Insufficient Backup Testing**: Recovery procedures untested

## Cross-References

- **CIP-005 & CIP-007**: Core controls for grid security
- **NIS2 Timeline**: Aligned with EU digital infrastructure requirements
