---
name: /drift-check
description: Audita reglas CLAUDE.md vs. estado real del repo. Detecta divergencias, archivos huérfanos, tests faltantes y patrones de PII.
developer_type: all
agent: task
context_cost: high
---

# /drift-check — Auditoría de Convergencia Repo

> 🦉 Savia vigila que las reglas y realidad no se desalineen.

Ejecuta auditoría paralela en dos frentes: reglas vs. arquivos y estructura vs. integridad.

---

## Sintaxis

```bash
/drift-check [--project NOMBRE] [--format md|yaml] [--strict]
```

- `--project`: Proyecto a auditar (default: pm-workspace)
- `--format`: Salida (default: md)
- `--strict`: Fallar en warnings (no solo errores)

---

## Flujo de Ejecución

### Agente 1 — Auditoría de Reglas (paralelo)

1. Leer `CLAUDE.md` → extraer todas las reglas explícitas
2. Por cada regla:
   - ¿Existe enforcement? (test, hook, linter)
   - ¿Se cumple en todos los ficheros afectados?
   - ¿Hay excepciones documentadas?
3. Flag: reglas sin enforcement → "unguarded"
4. Listar ficheros script/ violando límite de 150 líneas
5. Escanear PII patterns en ficheros versionados

### Agente 2 — Auditoría de Estructura (paralelo)

1. Listar todos los scripts/ → verificar si tienen tests correspondientes
2. Listar todas las docs → verificar si están referenciadas en CLAUDE.md o comandos
3. Detectar ficheros huérfanos (sin referencia)
4. Verificar existencia de ficheros declarados en CLAUDE.md
5. Comprobar coherencia de versiones (CHANGELOG ↔ tags)

---

## Output

Fichero: `output/drift-report-YYYYMMDD.md`

Secciones:
- **Nuevos Issues**: hallazgos no visto antes
- **Recurrentes**: problemas persistentes desde último reporte
- **Resueltos**: issues cerrados desde última auditoría
- Tabla de enforcement por regla
- Ficheros huérfanos / duplicados
- PII detectado (si hay)
- Recomendaciones de corrección

Guardar histórico en `output/drift-reports/`

---

## Banner y Progreso

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 /drift-check — Auditoría de Convergencia
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Agente 1/2 — Auditando reglas...
📋 Agente 2/2 — Auditando estructura...
✅ Análisis completo
📄 Reporte: output/drift-report-20260303.md
```

---

## Resultado

- Score de convergencia 0-100 (100 = perfecto)
- Top 3 riesgos críticos
- Acciones recomendadas priorizado
- Siguientes pasos si hay drift crítico
