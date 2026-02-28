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

## Ejecución (5 pasos)

### Paso 1 — Leer informe de scan
Localizar el informe más reciente en `output/compliance/{proyecto}-scan-*.md`.
Extraer los hallazgos correspondientes a los IDs solicitados.
Verificar que cada ID existe y tiene auto-fix disponible.

Si un ID no tiene auto-fix, informar al usuario y sugerir generar Task manual:
```
RC-005 no tiene auto-fix disponible (requiere cambio arquitectónico).
→ Generar Task con: descripción, ficheros afectados, regulación, requisito.
```

### Paso 2 — Generar changeset
Para cada hallazgo con auto-fix, generar los cambios necesarios según la categoría:

**Cifrado (at-rest)**:
- Identificar campos sensibles sin cifrar
- Añadir decoradores/atributos de cifrado o middleware de cifrado transparente
- Generar migración DB si aplica

**Cifrado (in-transit)**:
- Configurar TLS en endpoints afectados
- Añadir headers de seguridad (HSTS, etc.)

**Audit trail**:
- Crear tabla/colección de audit log si no existe
- Añadir middleware/interceptor que registre: usuario, acción, timestamp, datos
- Configurar retención según normativa del sector

**Control de acceso (RBAC)**:
- Scaffolding de modelo de roles y permisos
- Añadir decoradores/middleware de autorización en endpoints afectados
- Generar seed de roles base del sector

**Consentimiento**:
- Crear modelo de consentimiento (tipo, fecha, revocación)
- Añadir endpoints de gestión de consentimiento
- Añadir check de consentimiento previo al procesamiento

**Trazabilidad**:
- Añadir campos de tracking (lote, origen, destino, timestamp)
- Crear endpoints de consulta de trazabilidad
- Implementar cadena de custodia (hash encadenado)

**Accesibilidad (WCAG)**:
- Añadir ARIA labels a formularios
- Corregir contraste de colores
- Añadir navegación por teclado
- Generar alt text para imágenes

### Paso 3 — Aplicar o previsualizar
- Si `--dry-run`: Mostrar diff de cada cambio propuesto sin aplicar
- Si normal: Aplicar cambios al código fuente

Mostrar resumen de cambios:
```
Aplicando RC-001 (cifrado PHI)...
  ✓ models/patient.ts — añadido @Encrypted en campos sensibles
  ✓ config/database.ts — habilitado TDE (Transparent Data Encryption)
  ✓ migrations/add_encryption.ts — nueva migración

Aplicando RC-003 (audit trail)...
  ✓ middleware/audit.ts — nuevo middleware de auditoría
  ✓ models/audit-log.ts — nuevo modelo
  ✓ config/audit.ts — configuración de retención
```

### Paso 4 — Re-verificar
Para cada hallazgo corregido, ejecutar de nuevo la verificación específica:
- Comprobar que el patrón requerido ahora existe en el código
- Verificar que no se han introducido nuevas violaciones

Reportar resultado:
```
Re-verificación:
  RC-001 [cifrado PHI]    → ✅ PASS (antes: FAIL)
  RC-003 [audit trail]    → ✅ PASS (antes: FAIL)
  RC-007 [RBAC]           → ❌ FAIL (fix parcial — falta middleware en 2 endpoints)
```

### Paso 5 — Actualizar informe
Actualizar el informe de scan con los resultados de la corrección.
Marcar hallazgos corregidos como FIXED.
Si algún fix fue parcial, mantener como FAIL con nota de progreso.

## Output

Stdout con changeset y resultado de re-verificación.
Informe de scan actualizado en `output/compliance/`.

## Notas
- Auto-fix genera código que debe ser revisado por el equipo.
- Los cambios NO se commitean automáticamente — el usuario decide cuándo.
- Si la re-verificación falla, el fix queda como parcial y se puede reintentar.
- Para hallazgos sin auto-fix, generar descripción detallada de Task manual.
