# Regla: NL Command Resolution
# ── Interpreta preguntas conversacionales, mapea a comandos con scoring ────

> Usada por `/nl-query`. Detecta, mapea, resuelve parámetros, propone ejecución.

---

## Flujo Principal

1. **Detectar**: ¿pregunta conversacional? (no comienza con `/`, es acción de negocio)
2. **Cargar**: catálogo de intenciones (intent-catalog.md)
3. **Mapear**: buscar patrón similar, obtener confianza base (70-95%)
4. **Score**: base + contexto (+0-5%) + historial (+0-3%)
5. **Decidir**:
   - ≥80%: ejecutar directo
   - 50-79%: confirmar
   - <50%: sugerir top 3 opciones
6. **Resolver parámetros**: proyecto, sprint, persona, flags
7. **Ejecutar**: correr comando
8. **Registrar**: guardar mapeo en memoria (concept: `nl-mapping`)

---

## Scoring

**Base** (catálogo): 70-95%
**Contexto bonus**: +0-5%
  - +2% si proyecto/sprint resueltos automáticamente
  - +2% si persona mencionada existe
  - +1% otro contexto relevante
**Historial bonus**: +0-3%
  - +3% si frase mapeada antes (memoria)
  - +0% primer uso
**Penalización**: -10-15% si ambigua/negación

---

## Decisión por Confianza

| Score | Acción |
|-------|--------|
| ≥ 80% | Ejecutar directamente (banner confirmatorio) |
| 50-79% | Mostrar mapeo, pedir "¿Ejecuto? [S/n]" |
| < 50% | Sugerir top 3 comandos, pedir aclaración |

---

## Parámetros (Orden de Preferencia)

**Proyecto**: workflow.md → projects.md → preguntar
**Sprint**: workflow.md → calendario → asumir actual
**Persona**: extraer de pregunta → validar equipo.md → preguntar
**Flags**: inferir de pregunta ("breve"→`--format brief`, "bloqueados"→`--blocked`)

---

## Validación Pre-Ejecución

✅ Comando existe en .claude/commands/
✅ Rol tiene permiso (verificar identity.md)
✅ No es destructivo O tiene confirmación explícita
✅ Parámetros son válidos

---

## Anti-Patterns (Restricciones)

> Compatible con Rule 17 (anti-improvisation): los comandos SOLO ejecutan lo que su .md define.

- **NUNCA** ejecutar `--delete|--drop|--destroy|--reset` sin confirmación
- **NUNCA** adivinar si confianza < 50%
- **NUNCA** ignorar permisos de rol
- **NUNCA** mapear a comando inexistente
- **NUNCA** improvisar si catálogo no cubre

---

## Recalibración

> Ver `confidence-protocol.md` para detalles de decay, recovery y periodic recalibration.

Cada resolución se registra automáticamente en `data/confidence-log.jsonl` (paso 8.5):

```bash
# Tras ejecución, registrar resultado
echo "{\"command\":\"...\",\"confidence\":$score,\"success\":true|false,\"timestamp\":\"$(date -Iseconds)\",\"pattern\":\"...\",\"band\":\"high|mid|low\"}" \
  >> data/confidence-log.jsonl
```

**Decay automático:** Si 3 o 5 fallos consecutivos del mismo patrón/comando, reducir confianza base.

**Recalibración mensual:** `bash scripts/confidence-calibrate.sh report`
- Computa accuracy por band y Brier score
- Sugiere ajustes si Brier > 0.2
- Ejemplo: "Band ≥80%: accuracy 65%, reduce base by 10%"

---

## Integración

Invocado por:
- `/nl-query` (principal)
- `/help` (sugerir cuando pregunta es conversacional)
- Cualquier comando si usuario hace pregunta en lugar de completar parámetros

Registra mapeos exitosos:
```bash
bash scripts/memory-store.sh save \
  --type "pattern" --concept "nl-mapping" \
  --title "'{pregunta}' → {comando}" \
  --content "Confianza: {score}% | Proyecto: {p} | Rol: {r}" \
  --topic "nl-patterns"
```

---

## Casos Especiales

| Caso | Solución |
|------|----------|
| Pregunta ambigua | Preguntar aclaración |
| Múltiples opciones equiprobables | Sugerir top 3 |
| Comando no existe pero similar sí | Sugerir alternativa |
| Parámetro no soportado | Ofercer sin parámetro o alternativa |
| Rol sin permiso | Indicar necesidad permisos |

Ver `intent-catalog.md` para patrones detallados.
