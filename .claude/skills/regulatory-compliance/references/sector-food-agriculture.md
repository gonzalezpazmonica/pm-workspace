---
name: Food & Agriculture Sector Regulations
description: FSMA 204, FDA 21 CFR Part 11, EU 178/2002 traceability and records requirements
context_cost: low
---

# Food & Agriculture Sector Regulations

## Applicable Regulations

- **FSMA 204**: Food traceability rule
- **FDA 21 CFR Part 11**: Electronic records requirements
- **EU 178/2002**: General food law traceability

## Detection Markers

### Packages
- food-traceability, gs1-*
- opentracing, barcode-*

### Entities
- Product, Batch, Supplier, Allergen, Ingredient, Recall, Lot

### APIs
- /api/products
- /api/batches
- /api/suppliers
- /api/recalls

### Configuration
- FSMA_*
- FDA_*
- GS1_*
- TRACEABILITY_*

### Middleware & Services
- TraceabilityMiddleware, AllergenCheckFilter, RecallNotifier

### Database & Schema
- products, batches, lots, suppliers, allergens, ingredients, recall_events

### Folder & Namespace Patterns
- Traceability/, FoodSafety/, SupplyChain/, QualityControl/

### Documentation & CI/CD
- FSMA, HACCP, food safety, traceability, allergen, GS1

## Compliance Checklist

- [ ] KDE/CTE capture per FSMA 204
- [ ] Traceability lot codes (TLC) assigned
- [ ] One-step-forward/one-step-back traceability
- [ ] Allergen declaration management
- [ ] Electronic records with digital signatures (21 CFR 11)
- [ ] Supplier verification documentation
- [ ] Recall capability within 24 hours
- [ ] Batch/lot tracking through supply chain
- [ ] Temperature monitoring records maintained
- [ ] Expiry date management system

## Common Violations

- No lot tracking implemented
- Missing supplier links in chain
- No allergen cross-reference system
- Records without digital signatures
- No recall procedure coded into system

## Risk Assessment

**Severity**: Critical
**Scope**: Production, distribution, recall
**Impact**: Food safety, public health, product recalls
