---
name: pr-review
description: >
  Revisión multi-perspectiva de un Pull Request desde 5 ángulos: Business Analyst,
  Developer (code-reviewer), QA Engineer, Security, DevOps. Opcionalmente incluye
  verificación de cumplimiento de Spec SDD. Genera un informe consolidado con
  hallazgos priorizados y veredicto final.
---

# Revisión Multi-Perspectiva de Pull Request

**PR:** $ARGUMENTS

> Acepta: número de PR de Azure DevOps, URL de PR, o nombre de rama local.
> Si no se pasa argumento, usa la rama actual y compara contra `main`.

---

## Instrucciones generales

Ejecuta cada tarea en orden. Cada perspectiva genera hallazgos clasificados como:
- 🔴 **Bloqueante** — debe corregirse antes del merge
- 🟡 **Recomendado** — debería hacerse, no bloquea
- 🔵 **Nota** — sugerencia menor o informativa

**Principio clave:** cualquier mejora identificada como "para el futuro" debe
tratarse como mejora inmediata. No se difieren correcciones.

---

## Paso 0 — Obtener el diff

```bash
# Si es rama local
git diff main...HEAD --stat
git diff main...HEAD

# Si es PR de Azure DevOps
az repos pr show --id {PR_ID} --output json
```

Identificar: ficheros modificados, líneas añadidas/eliminadas, tipos de cambio.

---

## Tarea 1 — Perspectiva Business Analyst

**Objetivo:** Verificar que los cambios cumplen los criterios de aceptación del PBI.

Delegar al agente `business-analyst`:
- ¿Los cambios implementan lo que el PBI pide? ¿Ni más ni menos?
- ¿Los criterios de aceptación están cubiertos?
- ¿Hay reglas de negocio afectadas que no se hayan considerado?
- ¿El comportamiento en casos límite es el esperado?

Si hay Spec SDD asociada:
- ¿El código implementa exactamente el contrato de la spec?
- ¿Los ficheros creados/modificados son los indicados en la spec?

---

## Tarea 2 — Perspectiva Developer (Code Review)

**Objetivo:** Evaluar calidad de código, arquitectura y mantenibilidad.

Delegar al agente `code-reviewer` existente:
```
Prompt: Revisa los cambios del PR (git diff main...HEAD) aplicando las reglas de
        .claude/rules/csharp-rules.md. Prioriza: Vulnerabilities > Bugs > Code Smells.
        Incluye hallazgos Blocker, Critical y Major. Devuelve informe completo con
        veredicto: APROBADO, APROBADO_CON_CAMBIOS_MENORES o RECHAZADO.
```

Puntos adicionales no cubiertos por `code-reviewer`:
- ¿El código es fácil de entender para alguien que no lo escribió?
- ¿Hay oportunidades de simplificación evidentes?
- ¿Se han actualizado los comentarios XML si las firmas cambiaron?

---

## Tarea 3 — Perspectiva QA Engineer

**Objetivo:** Verificar cobertura de tests, edge cases y riesgo de regresión.

1. **Cobertura de tests:**
   ```bash
   dotnet test --filter "Category=Unit" --no-build --collect:"XPlat Code Coverage" 2>&1
   ```
   - ¿Los tests cubren los cambios del PR?
   - ¿Hay paths de código nuevos sin test?
   - ¿La cobertura está por encima de TEST_COVERAGE_MIN_PERCENT (80%)?

2. **Edge cases:**
   - ¿Se consideran: null, vacío, límites numéricos, concurrencia?
   - ¿Los tests de la Spec SDD (sección Test Scenarios) están implementados?

3. **Riesgo de regresión:**
   - ¿Los cambios afectan código existente que ya tiene tests?
   - ¿Se han ejecutado los tests de integración afectados?

---

## Tarea 4 — Perspectiva Security Engineer

**Objetivo:** Detectar vulnerabilidades de seguridad en los cambios.

Delegar al agente `security-guardian` para verificar:
- SQL injection (WIQL, ADO.NET directo)
- XSS en respuestas de API
- Secrets hardcodeados
- Insecure deserialization
- CORS mal configurado
- Missing `[Authorize]`
- Validación de inputs

Puntos adicionales:
- ¿Se han añadido dependencias NuGet con CVEs conocidos?
- ¿Los cambios afectan la superficie de autenticación/autorización?
- ¿Se exponen datos sensibles en logs o respuestas de error?

---

## Tarea 5 — Perspectiva DevOps

**Objetivo:** Evaluar impacto en build, deployment y monitorización.

1. **Pipeline CI/CD:**
   ```bash
   dotnet build --configuration Release 2>&1
   ```
   - ¿El PR compila sin warnings en Release?
   - ¿Se ha modificado el Jenkinsfile o docker-compose?
   - ¿Hay cambios que requieran actualizar configuración de K8s?

2. **Infraestructura:**
   - ¿Se necesitan nuevas variables de entorno?
   - ¿Hay cambios en connection strings o configuración de servicios?
   - ¿Se ha actualizado la documentación de deployment?

3. **Observabilidad:**
   - ¿Los nuevos endpoints tienen logging adecuado (Serilog)?
   - ¿Se han añadido métricas o traces de OpenTelemetry donde corresponde?

---

## Formato del informe consolidado

```markdown
## PR Review Multi-Perspectiva: [Título del PR]

### Resumen
- Ficheros modificados: N
- Líneas añadidas: +N / eliminadas: -N
- Specs SDD asociadas: [lista o N/A]

### 🔴 Bloqueantes (corregir antes del merge)
1. [PERSPECTIVA] [Problema] en [fichero:línea] → [solución]

### 🟡 Recomendados (no bloquean pero deberían hacerse)
1. [PERSPECTIVA] [Problema] en [fichero:línea] → [solución]

### 🔵 Notas
- [...]

### Veredicto por perspectiva
| Perspectiva | Veredicto | Hallazgos |
|---|---|---|
| Business Analyst | ✅/🟡/🔴 | N hallazgos |
| Developer | ✅/🟡/🔴 | N hallazgos |
| QA Engineer | ✅/🟡/🔴 | N hallazgos |
| Security | ✅/🟡/🔴 | N hallazgos |
| DevOps | ✅/🟡/🔴 | N hallazgos |

### Veredicto Final
- [ ] ✅ APROBADO — listo para merge
- [ ] 🟡 APROBADO CON CAMBIOS — corregir los amarillos y merge
- [ ] 🔴 RECHAZADO — corregir bloqueantes y repetir review
```

---

## Restricciones

- **No corriges el código** — señalas problemas y propones soluciones
- Las perspectivas Developer y Security delegan a los agentes existentes (`code-reviewer`, `security-guardian`)
- Si el PR toca código de Domain Layer, señalar que el Code Review E1 SIEMPRE es humano
- El informe se genera localmente — publicar en Azure DevOps solo si el humano lo confirma
