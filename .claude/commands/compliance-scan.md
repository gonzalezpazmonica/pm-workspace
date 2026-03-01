---
name: compliance-scan
description: Escanear código fuente contra regulaciones del sector — detección automática, verificación y reporte
developer_type: all
agent: architect
context_cost: medium
---

# /compliance-scan {path} [--sector SECTOR] [--strict] [--lang es|en]

> Detecta el sector regulatorio del proyecto, carga las normativas aplicables y verifica el cumplimiento del código fuente.

---

## Parámetros

- `{path}` — Ruta del proyecto a escanear (default: proyecto actual)
- `--sector SECTOR` — Forzar sector (saltar detección): healthcare, finance, food, justice, public-admin, insurance, pharma, energy, telecom, education, defense, transport
- `--strict` — Incluir hallazgos MEDIUM y LOW (default: solo CRITICAL y HIGH)
- `--lang` — Idioma del informe: `es` (default) o `en`. Detectar de CLAUDE.md si existe.

## Prerequisitos

Cargar skill: `@.claude/skills/regulatory-compliance/SKILL.md`

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Governance** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar idioma y nivel de detalle según `preferences.language` y `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Ejecución (7 pasos)

### Paso 4 — Verificar proyecto
Comprobar que `{path}` existe y es accesible. Identificar lenguaje principal y estructura.

### Paso 5 — Detectar sector (si no se forzó con --sector)
Ejecutar algoritmo de 5 fases del SKILL.md:

1. **Domain Models (35%)**: Modelos, schemas, migraciones, DTOs, interfaces, enums del sector
2. **Naming & Routes (25%)**: Rutas API, controladores, servicios, repositorios, carpetas, namespaces
3. **Dependencies (15%)**: Package managers por imports específicos del sector
4. **Configuration (15%)**: .env, config/, appsettings, docker-compose — claves sectoriales + connection strings
5. **Infrastructure & Docs (10%)**: README, docs/, CI/CD, terraform — menciones a regulaciones

Calcular score por sector (0-100):
- **≥55%** → Proceder automáticamente con sector detectado
- **25-54%** → Preguntar al usuario mostrando top 3 sectores con porcentajes
- **<25%** → Preguntar con opción **"No regulado (saltar validación)"**

Si el usuario elige "No regulado", terminar con mensaje informativo sobre GDPR/LOPDGDD genérico.

### Paso 6 — Cargar regulaciones
Leer `references/sector-{name}.md` del sector confirmado.
Si multi-sector (varios >55%), cargar todos los aplicables.

### Paso 7 — Escanear código
Para cada regulación en el checklist del sector:
- Buscar implementación de cada requisito en el código fuente
- Verificar patrones de cifrado, audit trails, control de acceso, trazabilidad
- Identificar datos sensibles sin protección adecuada
- Comprobar formatos estándar del sector
- Verificar credenciales no hardcodeadas

### Paso 8 — Clasificar hallazgos
Asignar severidad según la matriz del SKILL.md:
- **CRITICAL**: Riesgo de breach, multa, ilegalidad directa
- **HIGH**: Control de seguridad/auditoría ausente
- **MEDIUM**: Mejora recomendada (solo con --strict)
- **LOW**: Best practice (solo con --strict)

### Paso 9 — Asignar IDs y acciones
Cada hallazgo recibe un ID (formato: `RC-{NNN}`).
Marcar cada hallazgo con: `[AUTO-FIX]` o `[MANUAL]` según disponibilidad de corrección automática.

### Paso 10 — Calcular score y generar informe

**Fórmula de compliance score**: `Score = (requisitos cumplidos / total requisitos) × 100`

## Output

Guardar en: `output/compliance/{proyecto}-scan-{fecha}.md` (fecha obligatoria en nombre)

```markdown
# Compliance Scan — {proyecto}

**Sector**: {sector} ({score}% confianza)
**Fecha**: {ISO date}
**Compliance Score**: {X}% ({cumplidos}/{total} requisitos)

## Detección de sector
| Fase | Peso | Score | Señales encontradas |
|------|------|-------|---------------------|
| Domain Models | 35% | X | {entidades} |
| Naming & Routes | 25% | X | {rutas, controllers} |
| Dependencies | 15% | X | {paquetes} |
| Configuration | 15% | X | {keys} |
| Infra & Docs | 10% | X | {menciones} |

## Resumen
| Severidad | Count | Auto-fix | Manual |
|-----------|-------|----------|--------|
| CRITICAL  | N     | N        | N      |
| HIGH      | N     | N        | N      |

## Hallazgos

### RC-001 [CRITICAL] [AUTO-FIX] {Regulación} §{artículo} — {descripción}
**Ficheros afectados**: {lista}
**Requisito**: {qué exige la norma}
**Estado actual**: {qué se encontró en el código}
**Acción**: `/compliance-fix RC-001`

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
- Usar mismo idioma (--lang) en scan, fix y report para consistencia.
