---
name: pbi-decompose
description: Decompose a PBI into granular technical tasks
---

---

# /pbi-decompose

Descompone un PBI en Tasks técnicas con estimaciones y propuesta de asignación inteligente.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **PBI & Backlog** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tools.md`
3. Adaptar output según `identity.rol`, `workflow.sdd_active` y disponibilidad de `tools.azure_devops`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/pbi-decompose {id} [--project {nombre}] [--dry-run]
```

- `{id}`: ID del work item en Azure DevOps (ej: `1234`)
- `--project`: Proyecto AzDO (default: `AZURE_DEVOPS_DEFAULT_PROJECT`)
- `--dry-run`: Solo muestra la propuesta, **no crea nada** en Azure DevOps (comportamiento por defecto)

## 3. Pasos de Ejecución

1. **Leer contexto** en este orden (Progressive Disclosure según la skill):
   - `CLAUDE.md` (raíz)
   - `projects/{proyecto}/CLAUDE.md`
   - `projects/{proyecto}/reglas-negocio.md`
   - `projects/{proyecto}/equipo.md`
   - `docs/politica-estimacion.md`
   - `docs/reglas-scrum.md`
   - `docs/flujo-trabajo.md`

2. **Invocar la skill** completa:
   → `.opencode/skills/pbi-decomposition/SKILL.md`

3. **Fase 1** — Analizar el PBI desde Azure DevOps (título, descripción, criterios de aceptación, SP, tags, links)

4. **Fase 2** — Inspeccionar el código fuente si aplica:
   ```bash
   # Buscar módulos relacionados
   find projects/{proyecto}/source/src -name "*.cs" | grep -i "{modulo}" | head -20
   # Detectar patrones arquitectónicos
   grep -r "IRequestHandler\|IMapper\|IRepository" projects/{proyecto}/source/src/ --include="*.cs" -l | head -5
   # Historial de contribuciones
   git -C projects/{proyecto}/source log --since="3 months ago" --format="%an" -- "src/**/{Modulo}*" | sort | uniq -c | sort -rn | head -5
   ```

5. **Fase 3** — Descomponer en Tasks siguiendo las categorías A/B/C/D/E de la skill

6. **Fase 4** — Estimar con factores de ajuste (complejidad × conocimiento × riesgo)

7. **Fase 5** — Calcular scores de asignación para cada task (ver `references/assignment-scoring.md`)

8. **Fase 6** — Presentar la propuesta en formato tabla con impacto en capacity antes de crear nada:

```
📋 PBI #{id}: {título} ({SP} SP)

   Módulos afectados: ...
   Capas: ...

   ┌────┬─────────────────────────────────────┬──────────┬──────┬──────────────┬────────────────┐
   │ #  │ Task                                │ Horas    │ Act. │ Asignado a   │ Developer Type │
   ├────┼─────────────────────────────────────┼──────────┼──────┼──────────────┼────────────────┤
   │ B1 │ ...                                 │ 2h       │ Dev  │ ...          │ human          │
   │ B3 │ ...                                 │ 4h       │ Dev  │ 🤖 agent     │ agent-single   │
   └────┴─────────────────────────────────────┴──────────┴──────┴──────────────┴────────────────┘

   Total: Xh (rango esperado para Y SP: A-Bh)

   📊 Impacto en capacity:
      Persona: Xh asignadas → Yh (+Zh) de Wh disponibles ✅/⚠️
```

9. Preguntar: **"¿Creo estas Tasks en Azure DevOps? ¿Quieres ajustar algo?"**

10. Tras confirmación → **Fase 7**: Crear Tasks + link jerárquico al PBI + comentario en el PBI + cambiar estado a "Committed"

## Ejemplo
```
/pbi-decompose 1234
/pbi-decompose 1234 --project ProyectoAlpha
/pbi-decompose 1234 --dry-run
```
