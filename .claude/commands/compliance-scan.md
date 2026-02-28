---
name: compliance-scan
description: Escanear código fuente contra regulaciones del sector — detección automática, verificación y reporte
developer_type: all
agent: architect
context_cost: medium
---

# /compliance-scan {path} [--sector SECTOR] [--strict]

> Detecta el sector regulatorio del proyecto, carga las normativas aplicables y verifica el cumplimiento del código fuente.

---

## Parámetros

- `{path}` — Ruta del proyecto a escanear (default: proyecto actual)
- `--sector SECTOR` — Forzar sector (saltar detección): healthcare, finance, food, justice, public-admin, insurance, pharma, energy, telecom, education, defense, transport
- `--strict` — Incluir hallazgos MEDIUM y LOW (default: solo CRITICAL y HIGH)

## Prerequisitos

Cargar skill: `@.claude/skills/regulatory-compliance/SKILL.md`

## Ejecución (7 pasos)

### Paso 1 — Verificar proyecto
Comprobar que `{path}` existe y es accesible. Identificar lenguaje principal y estructura.

### Paso 2 — Detectar sector (si no se forzó con --sector)
Ejecutar algoritmo de 4 fases del SKILL.md:

1. **File patterns (40%)**: Buscar modelos de dominio, schemas, migraciones, DTOs con entidades del sector
2. **Dependencies (30%)**: Analizar package managers por imports específicos del sector
3. **Naming (20%)**: Escanear rutas API, controladores, servicios, tablas por nomenclatura sectorial
4. **Config (10%)**: Buscar variables de entorno y ficheros de configuración sectoriales

Calcular score por sector (0-100):
- **≥60%** → Proceder automáticamente con sector detectado
- **30-59%** → Preguntar al usuario mostrando top 3 sectores con porcentajes
- **<30%** → Preguntar con opción **"No regulado (saltar validación)"**

Si el usuario elige "No regulado", terminar con mensaje informativo sobre GDPR/LOPDGDD genérico.

### Paso 3 — Cargar regulaciones
Leer `references/sector-{name}.md` del sector confirmado.
Si multi-sector (varios >60%), cargar todos los aplicables.

### Paso 4 — Escanear código
Para cada regulación en el checklist del sector:
- Buscar implementación de cada requisito en el código fuente
- Verificar patrones de cifrado, audit trails, control de acceso, trazabilidad
- Identificar datos sensibles sin protección adecuada
- Comprobar formatos estándar del sector

### Paso 5 — Clasificar hallazgos
Asignar severidad según la matriz del SKILL.md:
- **CRITICAL**: Riesgo de breach, multa, ilegalidad directa
- **HIGH**: Control de seguridad/auditoría ausente
- **MEDIUM**: Mejora recomendada (solo con --strict)
- **LOW**: Best practice (solo con --strict)

### Paso 6 — Asignar IDs y acciones
Cada hallazgo recibe un ID (formato: `RC-{NNN}`).
Determinar si tiene auto-fix disponible (ver plantillas en SKILL.md).

### Paso 7 — Generar informe

## Output

Guardar en: `output/compliance/{proyecto}-scan-{fecha}.md`

```markdown
# Compliance Scan — {proyecto}

**Sector**: {sector} ({score}% confianza)
**Fecha**: {ISO date}
**Compliance Score**: {X}%

## Resumen
| Severidad | Count |
|-----------|-------|
| CRITICAL  | N     |
| HIGH      | N     |
| MEDIUM    | N     |
| LOW       | N     |

## Hallazgos

### RC-001 [CRITICAL] {Regulación} §{artículo} — {descripción}
**Ficheros afectados**: {lista}
**Requisito**: {qué exige la norma}
**Estado actual**: {qué se encontró en el código}
**Acción**: `/compliance-fix RC-001` (auto-fix disponible)

### RC-002 [HIGH] {Regulación} — {descripción}
**Ficheros afectados**: {lista}
**Acción**: Generar Task para corrección manual

## Regulaciones verificadas
- [x] {Regulación A} — {N} de {M} requisitos OK
- [ ] {Regulación B} — {N} de {M} requisitos OK

## Siguientes pasos
- Auto-fix: `/compliance-fix RC-001 RC-003`
- Informe ejecutivo: `/compliance-report {path}`
- Re-scan tras correcciones: `/compliance-scan {path}`
```

## Notas
- El scan NO modifica código. Solo analiza y reporta.
- Los IDs RC-XXX son estables para referencia en `/compliance-fix`.
- Si el proyecto usa IA, considerar también `/ai-risk-assessment` para EU AI Act.
