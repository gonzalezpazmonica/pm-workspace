---
name: pbi-from-rules-report
description: Generate traceability matrix report without creating PBIs
allowed-tools: Bash, Read, Write, Task
---

# /pbi-from-rules-report

Genera la matriz de trazabilidad RN↔PBI sin crear nuevos PBIs. Solo análisis y reporte.

**Uso:**
```
/pbi-from-rules-report {proyecto}
```

---

## Ejecución

1. **Banner**: `🔍 /pbi-from-rules-report: {proyecto}`

2. **Verificar prerequisitos**: igual que `/pbi-from-rules`

3. **Invocar skill**: reglas-traceability con modo report-only

4. **Mostrar matriz** en chat (máx 20 líneas):
```
RN-001-01 (Autenticación) → PBI #302, #305 | Completa
RN-001-02 (Registro) → PBI #302 | Parcial
RN-002-01 (Reservar sala) → — | NINGUNA
...
```

5. **Guardar reporte completo**: `output/YYYYMMDD-traceability-{proyecto}.md`

6. **Banner final**: ruta del reporte

No se crean PBIs. Solo lectura.

---

## Ejemplo

```
/pbi-from-rules-report sala-reservas
```
