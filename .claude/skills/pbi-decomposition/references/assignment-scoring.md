# Scoring de Asignación — Referencia Detallada

> Fichero auxiliar de la skill `pbi-decomposition`. Explica el algoritmo de scoring con ejemplos numéricos para facilitar la comprensión y el debugging del agente.

## Fórmula Completa

```
score(persona, task) =
    0.40 × match_expertise(persona, task)
  + 0.30 × disponibilidad_normalizada(persona)
  + 0.20 × factor_equilibrio(persona, equipo)
  + 0.10 × factor_crecimiento(persona, task)
```

Los pesos son configurables por proyecto (ver `projects/{proyecto}/CLAUDE.md` → sección `assignment_weights`).

---

## Tabla de match_expertise

| Situación | Score |
|-----------|-------|
| Experto en el módulo exacto + Activity coincide con su rol | 1.0 |
| Conoce el módulo + Activity coincide | 0.8 |
| Experto en módulo similar + conoce el stack | 0.6 |
| Conoce el stack pero no el módulo | 0.4 |
| Junior, primera vez con este tipo de tarea | 0.2 |

---

## Ejemplo de Cálculo Completo

Equipo del sprint: María (Backend expert), Carlos (Backend), Ana (QA), Pedro (TL)

**Task**: `B3: Handler CreatePatientCommand` — 4h — Activity: Development

Estado del equipo al momento de asignar:

| Persona | Capacity | Carga | Libres | Módulo Patients |
|---------|---------|-------|--------|----------------|
| María | 48h | 28h | 20h | Experta (1.0) |
| Carlos | 48h | 35h | 13h | Conoce (0.8) |
| Ana | 30h | 18h | 12h | No (Activity=Testing, no Development) |
| Pedro (TL) | 42h | 40h | 2h | Experto (1.0), pero casi sin libres |

**Cálculos**:

```
# María
expertise     = 1.0
disponib.     = 20 / 20 (max del equipo) = 1.0
equilibrio    = 1 - (28/40) = 0.30
crecimiento   = 0.0 (ya es experta, no hay aprendizaje)

score(María) = 0.40×1.0 + 0.30×1.0 + 0.20×0.30 + 0.10×0.0 = 0.76

# Carlos
expertise     = 0.8
disponib.     = 13/20 = 0.65
equilibrio    = 1 - (35/40) = 0.125
crecimiento   = 0.5 (módulo que conoce pero no domina → aprendizaje)

score(Carlos) = 0.40×0.8 + 0.30×0.65 + 0.20×0.125 + 0.10×0.5 = 0.345

# Ana → DESCARTADA: Activity=Testing, restricción dura
score(Ana) = 0  (restricción dura: Activity no coincide)

# Pedro
expertise     = 1.0
disponib.     = 2/20 = 0.10
equilibrio    = 1 - (40/40) = 0.0
crecimiento   = 0.0

score(Pedro) = 0.40×1.0 + 0.30×0.10 + 0.20×0.0 + 0.10×0.0 = 0.43
```

**Resultado**: `→ Asignar a María (0.76)`. Segunda opción: Pedro (0.43) si María tuviera menos disponibilidad.

---

## Restricciones Duras — Checklist

Antes de calcular scores, filtrar candidatos que NO cumplen TODAS estas condiciones:

- [ ] `horas_libres >= horas_task` → Tiene capacidad suficiente
- [ ] `activity_persona incluye activity_task` → Su perfil encaja con la actividad
- [ ] `NOT (dias_off cubre todo el sprint)` → No está de vacaciones
- [ ] `NOT (solapamiento AND task.priority == 1)` → Si comparte con otro proyecto, solo tareas no críticas

Si ningún candidato pasa los filtros → alertar al PM y proponer opciones.

---

## Caso Especial: Code Review (Task E1)

1. Excluir al autor del código (Task B/C)
2. Ordenar candidatos:
   - Tech Lead primero (si el cambio es arquitectónico o de seguridad)
   - Developer con mayor expertise en el módulo (tras excluir al autor)
   - Developer con menos horas de code review asignadas este sprint
3. El reviewer no necesita Activity=Development — puede ser cualquier rol técnico

---

## Detección de Módulo Experto via Git

```bash
# Quién ha tocado más el módulo en los últimos 3 meses
git -C projects/{proyecto}/source log \
  --since="3 months ago" \
  --format="%an" \
  -- "src/**/{Modulo}*" "tests/**/{Modulo}*" \
  | sort | uniq -c | sort -rn | head -5

# Output esperado:
#   15 María García        ← Experta
#    8 Carlos Ruiz         ← Conoce
#    2 Pedro Torres        ← Ha tocado algo
```

Usar este dato para enriquecer `modulos_experta` y `modulos_conoce` del perfil, especialmente si `equipo.md` no tiene el dato actualizado.

---

## Personalización de Pesos por Contexto

| Contexto del equipo | expertise | availability | balance | growth |
|---------------------|-----------|-------------|---------|--------|
| Default (mixto) | 0.40 | 0.30 | 0.20 | 0.10 |
| Equipo junior (priorizar que aprenda de expertos) | 0.55 | 0.25 | 0.15 | 0.05 |
| Equipo senior con cross-training | 0.25 | 0.25 | 0.20 | 0.30 |
| Sprint crítico / bajo de velocity | 0.50 | 0.35 | 0.15 | 0.00 |
| Bug P1 en producción | 0.70 | 0.30 | 0.00 | 0.00 |

Configurar en `projects/{proyecto}/CLAUDE.md` bajo `assignment_weights:`.
