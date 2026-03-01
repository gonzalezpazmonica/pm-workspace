---
name: compliance-fix
description: Aplicar corrección automática a hallazgos de compliance y re-verificar
developer_type: all
agent: architect
context_cost: high
---

# /compliance-fix {issue-ids} [--dry-run]

> Aplica correcciones automáticas a los hallazgos identificados por `/compliance-scan` y re-verifica que la corrección resuelve el incumplimiento.

---

## Parámetros

- `{issue-ids}` — Uno o más IDs de hallazgo (formato: `RC-001 RC-003 RC-007`)
- `--dry-run` — Mostrar qué cambios se harían sin aplicarlos

## Prerequisitos

- Debe existir un informe previo de `/compliance-scan` en `output/compliance/`
- Cargar skill: `@.claude/skills/regulatory-compliance/SKILL.md`
- Cargar referencia del sector: `@.claude/skills/regulatory-compliance/references/sector-{detected}.md`

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Governance** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar idioma y nivel de detalle según `preferences.language` y `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Ejecución (5 pasos)

### Paso 4 — Leer informe de scan
Localizar el informe más reciente en `output/compliance/{proyecto}-scan-*.md`.
Extraer los hallazgos correspondientes a los IDs solicitados.
Verificar que cada ID existe y tiene marca `[AUTO-FIX]`.

Si un ID tiene marca `[MANUAL]`, informar al usuario y sugerir generar Task:
```
RC-005 requiere corrección manual (cambio arquitectónico).
→ Generar Task con: descripción, ficheros afectados, regulación, requisito.
```

### Paso 5 — Generar changeset
Para cada hallazgo con auto-fix, generar cambios según categoría (ver SKILL.md §Auto-Fix Templates):

- **Cifrado (at-rest)**: Servicio de cifrado + atributos en campos sensibles + config de claves
- **Cifrado (in-transit)**: Configurar TLS en endpoints + headers de seguridad (HSTS)
- **Audit trail**: Modelo de log + servicio + middleware interceptor + config de retención
- **Control de acceso (RBAC)**: Modelo de roles + middleware de autorización + seed de roles
- **Consentimiento**: Modelo + endpoints de gestión + check previo al procesamiento
- **Trazabilidad**: Campos de tracking + endpoints de consulta + hash encadenado
- **Accesibilidad (WCAG)**: ARIA labels + contraste + navegación por teclado

### Paso 6 — Aplicar o previsualizar

Indicar modo de ejecución al inicio del informe: `**Modo**: APLICADO` o `**Modo**: DRY-RUN`

- Si `--dry-run`: Mostrar diff de cada cambio propuesto sin aplicar
- Si normal: Aplicar cambios al código fuente

Incluir **sección de configuración requerida** con claves exactas para appsettings/env:
```
## Configuración requerida
- `Jwt:Key` — Clave HS256 (mínimo 32 caracteres)
- `Encryption:Key` — Clave AES-256 (Base64, 256 bits)
Añadir a appsettings.json antes de despliegue.
```

### Paso 7 — Re-verificar
Para cada hallazgo corregido, ejecutar de nuevo la verificación específica.
Incluir **ejemplo de salida** (sample output) para cada fix verificado:

```
Re-verificación:
  RC-001 [cifrado PHI]    → ✅ PASS (ejemplo: SSN cifrado = "AQz3k2M5...")
  RC-003 [audit trail]    → ✅ PASS (ejemplo: {"userId":"dr.smith","action":"READ",...})
  RC-007 [RBAC]           → ❌ FAIL (fix parcial — falta middleware en 2 endpoints)
```

### Paso 8 — Actualizar informe y calcular nuevo score
Actualizar el informe de scan con los resultados. Marcar hallazgos corregidos como FIXED.
Recalcular score: `Nuevo score = (requisitos cumplidos + fixes PASS) / total × 100`

## Output

Guardar en: `output/compliance/{proyecto}-fix-{fecha}.md`
Actualizar: `output/compliance/{proyecto}-scan-{fecha}.md` (marcar FIXED)

## Notas
- Auto-fix genera código que debe ser revisado por el equipo.
- Los cambios NO se commitean automáticamente — el usuario decide cuándo.
- Si la re-verificación falla, el fix queda como parcial y se puede reintentar.
- Para hallazgos `[MANUAL]`, generar descripción detallada de Task manual.
- Usar mismo idioma que el scan para consistencia.
