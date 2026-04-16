# Equipo — Proyecto Beta

> Equipo más reducido que Alpha. Actualizar disponibilidad antes de cada sprint.

## Miembros del Equipo

### Laura Martínez — Developer Full Stack
```
Email:              laura.martinez@empresa.com
AzureDevOps alias:  laura.martinez@empresa.com
Rol:                Developer Full Stack (Blazor + .NET)
Especialización:    .NET 8, Blazor Server, Azure SQL
Horas/día:          8
Capacidad sprint:   60h
```

### Carlos Sánchez — Developer / QA
```
Email:              carlos.sanchez@empresa.com
AzureDevOps alias:  carlos.sanchez@empresa.com
Rol:                Developer Backend + QA
Especialización:    .NET, xUnit, testing automatizado
Horas/día:          8
Capacidad sprint:   60h
```

---

## Festivos y Vacaciones

> Compartidos con Proyecto Alpha (mismo calendario laboral).

### Vacaciones individuales
```
Laura Martínez:  Sin vacaciones planificadas en Q1
Carlos Sánchez:  Sin vacaciones planificadas en Q1
```

---

## Capacity por Sprint (estimada)

| Sprint | Laura | Carlos | Total |
|--------|-------|--------|-------|
| 2026-04 (02/03-13/03) | 60h | 60h | 120h |
| 2026-05 (16/03-27/03) | 60h | 60h | 120h |
| 2026-06 (30/03-10/04) | 60h | 45h* | 105h |

*Carlos tiene 2 días de asunto propio pendiente de confirmar.

---

## Agentes Claude — Developer Virtuales (SDD)

> En Proyecto Beta (precio fijo, equipo de 2), los agentes Claude son especialmente críticos.
> Permiten multiplicar la capacity efectiva del equipo sin incrementar costes de personal.

### claude-agent-opus — Implementador Principal
```
ID (Azure DevOps tag):  dev:agent
Modelo:                 claude-opus-4-7
Rol:                    Developer virtual — código de producción
Coste estimado:         ~$0.60-1.20 por spec
```

**Prioridad de uso en Beta:**
- MUY ALTA — el equipo es de 2 personas, los agentes son esenciales para cumplir el scope
- Maximizar uso en Application Layer (handlers, queries, validators)
- Usar en Infrastructure cuando hay ejemplos claros en el código

**Limitaciones específicas de Beta:**
- Azure AD B2C: siempre humano (Laura tiene más experiencia, evitar errores de seguridad)
- Blazor Server: usar agente solo si hay componentes de referencia existentes
- Migraciones de Azure SQL: siempre humano (riesgo de datos en precio fijo)

---

### claude-agent-haiku — Tester
```
ID (Azure DevOps tag):  dev:agent-fast
Modelo:                 claude-haiku-4-5-20251001
Rol:                    Tests unitarios, validators, DTOs
Coste estimado:         ~$0.02-0.05 por spec de tests
```

**En Beta, priorizar haiku para:**
- Todos los unit tests de Application (ahorro máximo)
- DTOs y Records (totalmente mecánico)
- Validators FluentValidation

---

## Capacity Total con Agentes (Proyecto Beta)

| Sprint | Laura | Carlos | 🤖 Agentes | Total efectivo |
|--------|-------|--------|-----------|----------------|
| 2026-04 | 60h | 60h | ~35h estimadas | ~155h efectivas |
| 2026-05 | 60h | 60h | ~35h estimadas | ~155h efectivas |
| 2026-06 | 60h | 45h | ~35h estimadas | ~140h efectivas |

> **Nota precio fijo:** El uso de agentes es la principal palanca para proteger el margen.
> Objetivo: ≥ 70% de tasks técnicas repetitivas delegadas a agentes.
> Toda spec de agente tiene ROI positivo si elimina > 1h de trabajo humano (coste tokens ≈ $0.60-1.20).

## Política de Agentes en Beta

```yaml
# Regla especial Beta: maximizar agentización para proteger márgenes
agente_prioritario: true
objetivo_agentizacion: "70% de tasks técnicas"
budget_tokens_por_sprint: "Máx $20 USD en tokens Claude"
aprobacion_requerida: "Tech Lead (Laura) antes de lanzar agent-team"
coste_max_por_spec: "$2.00 USD (si supera, usar agent-single)"
```
