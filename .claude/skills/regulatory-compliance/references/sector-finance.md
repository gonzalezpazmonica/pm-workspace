---
name: Finance Sector Regulations
description: PCI-DSS v4.0, PSD2, SOX, Basel III/IV, MiFID II compliance requirements
context_cost: low
---

# Finance Sector Regulations

## Applicable Regulations

- **PCI-DSS v4.0**: Payment security standards
- **PSD2**: Strong customer authentication
- **SOX**: Sarbanes-Oxley financial reporting
- **Basel III/IV**: Risk management and capital
- **MiFID II**: Financial instruments directive

## Detection Markers

### Packages
- stripe, braintree, adyen, plaid, wise-api
- openbanking-*

### Entities
- Transaction, Account, Payment, Card, Transfer, Ledger

### APIs
- /api/payments
- /api/accounts
- /api/transfers
- /api/transactions

### Configuration
- PCI_DSS_*
- PAYMENT_GATEWAY_*
- BANKING_API_*

## Compliance Checklist

- [ ] PAN/CVV never stored in plain text
- [ ] Card data tokenization mandatory
- [ ] TLS 1.2+ on all channels
- [ ] Transaction audit trail (7 years for SOX)
- [ ] Strong Customer Authentication (SCA) for payments >€30
- [ ] Segregation of duties implemented
- [ ] Fraud detection logging active
- [ ] ISO 20022 message format compliance
- [ ] Regulatory reporting in XBRL format
- [ ] Quarterly penetration testing

## Common Violations

- Credit card numbers in logs
- Missing tokenization for card data
- Audit trail gaps or incomplete records
- No SCA implementation
- Transaction data without encryption

## Risk Assessment

**Severity**: Critical
**Scope**: Payment processing, account management
**Impact**: Financial fraud, regulatory penalties, data breach
