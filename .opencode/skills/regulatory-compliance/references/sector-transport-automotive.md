---
name: Transport & Automotive Sector Regulations
description: UNECE R155/R156, ISO/SAE 21434 cybersecurity engineering, and EU type approval standards for vehicle security
context_cost: low
---

# Transport & Automotive Sector Regulatory Reference

## Applicable Regulations
- **UNECE R155**: Vehicle cybersecurity management system requirements
- **UNECE R156**: Software updates for vehicles
- **ISO/SAE 21434**: Road vehicles cybersecurity engineering standard
- **EU Type Approval**: Vehicle homologation and certification

## Detection Markers

### Packages
- `autosar-*`, `can-bus-*`, `obd-*`, `vehicle-*`, `ota-update-*`, `v2x-*`

### Entities
- Vehicle, ECU, Firmware, Update, Diagnostic, CAN, OBD

### APIs
- `/api/vehicles`, `/api/firmware`, `/api/updates`, `/api/diagnostics`

### Configuration Keys
- `UNECE_*`, `ISO21434_*`, `OTA_*`, `ECU_*`, `AUTOSAR_*`

### Middleware & Services
- SecureBootVerifier, OtaSigningMiddleware, SbomTracker, VulnMonitor

### Database & Schema
- vehicles, ecus, firmware_versions, ota_updates, diagnostics, can_messages

### Folder & Namespace Patterns
- Automotive/, Vehicle/, ECU/, Firmware/, OTA/, Telematics/

### Documentation & CI/CD
- UNECE R155, R156, ISO 21434, automotive cybersecurity, SBOM, OTA, TARA

## Compliance Checklist

- [ ] CSMS certification completed (R155 Art.7)
- [ ] TARA risk assessment per ISO 21434
- [ ] Secure boot with cryptographic verification
- [ ] OTA update signing and verification (R156)
- [ ] Software version tracking per vehicle
- [ ] Vulnerability monitoring and PSIRT established
- [ ] Supply chain cybersecurity requirements
- [ ] Penetration testing before type approval
- [ ] Incident detection and response capability
- [ ] Post-production monitoring implemented
- [ ] Software Bill of Materials (SBOM) per component
- [ ] Rollback capability for failed updates
- [ ] CAN bus authentication and encryption
- [ ] Diagnostic interface access controls

## Common Violations

1. **No Secure Boot**: Firmware loaded without cryptographic verification
2. **Unsigned OTA Updates**: Over-the-air patches without signature verification
3. **Missing SBOM**: No software component inventory
4. **No Vulnerability Monitoring**: Undetected security issues in deployed vehicles
5. **Firmware Without Version Tracking**: Update history not maintained
6. **Missing TARA Assessment**: Risk assessment not documented
7. **No Rollback Capability**: Failed updates cannot be reversed
8. **Unencrypted CAN Bus**: Vehicle network without encryption
9. **Open Diagnostic Interfaces**: OBD ports without access controls
10. **No Incident Response**: Security events not handled
11. **Supply Chain Gaps**: Third-party component risks not assessed
12. **No Post-production Monitoring**: Released vehicles not tracked for issues

## Cross-References

- **ISO 21434 Threat Categories**: V2X, wireless, diagnostics, supply chain
- **UNECE R155 Timeline**: Phased implementation beginning 2024
- **NIST Cybersecurity Framework**: Alignment with identify, protect, detect, respond
