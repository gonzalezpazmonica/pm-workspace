---
name: pbi-from-rules
description: Map business rules to PBIs with traceability matrix
allowed-tools: Bash, Read, Write, Task
---

# /pbi-from-rules

Mapea reglas de negocio (RN-XXX-NN) a PBIs en Azure DevOps. Identifica cobertura, análisis de brechas y propone nuevos PBIs con trazabilidad.

**Uso:**
```
/pbi-from-rules {proyecto}
/pbi-from-rules {proyecto} --dry-run
```

---

## 1. Banner inicial

Mostrar:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 /pbi-from-rules: {proyecto}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Verificar prerequisitos

- Proyecto existe: `projects/{proyecto}/CLAUDE.md`
- Reglas existen: `projects/{proyecto}/reglas-negocio.md`
- PAT válido: `cat $PAT_FILE` contiene PAT válido
- Azure DevOps configurado: `$AZURE_DEVOPS_ORG_URL` sin placeholders

Si falta → error explícito con sugerencias.

## 3. Invocar la skill

Delegar a `business-analyst` agente:

```bash
Skill: rules-traceability
Input: {proyecto}
Output: matriz RN↔PBI, análisis brechas, propuestas
```

La skill ejecuta las 7 fases. El agente devuelve:
- Matriz trazabilidad
- Análisis de gaps
- Propuestas de PBIs (SIN crear)

## 4. Mostrar resultados

Tabla resumen:

```
Resumen de Trazabilidad — {proyecto}

Total RNs: 15
RNs con cobertura completa: 8 (53%)
RNs con cobertura parcial: 4 (27%)
RNs sin cobertura: 3 (20%)

PBIs propuestos: 5
  - 3 simple rules → PBIs directas
  - 2 features → product-discovery (JTBD+PRD)
```

## 5. Preguntar confirmación

"¿Creo los 5 PBIs propuestos en Azure DevOps? ¿Quieres ajustar algo?"

Si NO → guardar propuestas en fichero y salir.

Si SÍ → Fase 6 (crear en Azure DevOps).

## 6. Crear PBIs

Crear en Azure DevOps mediante API. Cada PBI:
- Título, descripción, criterios de aceptación
- Tag: RN-XXX-NN
- Link del PBI padre (si aplica)

Mostrar progress: "Creando PBI X/5..."

## 7. Generar reporte

Guardar matriz a: `output/YYYYMMDD-traceability-{proyecto}.md`

## 8. Banner de cierre

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Matriz de trazabilidad — completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Reporte: output/YYYYMMDD-traceability-{proyecto}.md
💡 Siguiente: /pbi-prd para las features recomendadas
```

---

## Flags

- `--dry-run` — Solo mostrar propuestas, no crear nada en Azure DevOps (defecto)
- `--yes` — Crear PBIs sin confirmar

---

## Ejemplo

```
/pbi-from-rules sala-reservas
/pbi-from-rules sala-reservas --dry-run
/pbi-from-rules sala-reservas --yes
```
