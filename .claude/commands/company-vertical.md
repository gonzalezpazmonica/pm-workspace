---
name: company-vertical
description: Detectar y configurar la vertical de la empresa — regulaciones, frameworks y mejores prácticas del sector
developer_type: all
agent: task
context_cost: medium
---

# /company-vertical

> 🦉 Savia adapta pm-workspace a las necesidades de tu industria.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre, rol
- `company/identity.md` — sector de la empresa
- `company/vertical.md` — vertical actual (si existe)

---

## Subcomandos

- `/company-vertical detect` — detectar vertical desde el contexto del proyecto
- `/company-vertical configure {sector}` — configurar vertical manualmente
- `/company-vertical regulations` — listar regulaciones aplicables
- `/company-vertical best-practices` — mejores prácticas PM del sector

---

## Flujo

### Paso 1 — Detectar o confirmar vertical

Analizar `company/identity.md` y proyectos activos para inferir sector.

Verticales soportadas (ampliando v0.37.0):

```
Verticales con compliance específico:
├─ healthcare — HIPAA, HL7 FHIR, FDA 21 CFR Part 11
├─ finance — SOX, Basel III, MiFID II, PCI DSS
├─ legal — GDPR, eDiscovery, legal hold
├─ education — FERPA, accesibilidad educativa
├─ government — FedRAMP, NIST 800-53
└─ defense — ITAR, CMMC

Verticales con frameworks PM:
├─ construction — PMBOK heavy, Earned Value
├─ manufacturing — Lean, Six Sigma, ISO 9001
├─ retail — seasonal planning, demand forecasting
├─ media — creative workflows, content calendars
├─ logistics — supply chain, just-in-time
└─ energy — safety-critical, ISO 55000
```

### Paso 2 — Configurar regulaciones

```
📋 Regulaciones detectadas para {sector}

  Obligatorias:
  ├─ {reg1} — {descripción breve}
  └─ {reg2} — {descripción breve}

  Recomendadas:
  ├─ {reg3} — {descripción breve}
  └─ {reg4} — {descripción breve}

  ¿Activar compliance automático? [S/n]
```

### Paso 3 — Adaptar mejores prácticas

Cargar frameworks PM específicos del sector:
- Ceremonias adaptadas (ej: healthcare necesita review de PHI)
- Métricas específicas (ej: finanzas necesita audit trail)
- Templates de documentación del sector

### Paso 4 — Guardar en vertical.md

Actualizar `.claude/profiles/company/vertical.md`.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: company_vertical
sector: "healthcare"
regulations: ["HIPAA", "HL7_FHIR", "FDA_21CFR11"]
frameworks: ["Agile_Healthcare", "Lean_Clinical"]
compliance_active: true
```

---

## Restricciones

- **NUNCA** dar consejo legal sobre cumplimiento normativo
- **NUNCA** garantizar compliance — solo asistir y documentar
- Siempre recomendar validación con departamento legal
- Las regulaciones se actualizan: Savia avisa si detecta cambios
