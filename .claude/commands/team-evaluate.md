---
name: team-evaluate
description: >
  Ejecuta el cuestionario interactivo de evaluación de competencias para un
  programador del equipo. Genera el perfil de expertise que alimenta el algoritmo
  de asignación de tareas. Cumple con RGPD/LOPDGDD.
---

# Evaluación de Competencias

**Programador:** $ARGUMENTS

> Uso: `/team:evaluate "Laura Sánchez" --project GestiónClínica`
>
> Prerequisito obligatorio: la nota informativa RGPD debe estar firmada.
> Si no existe en `projects/{proyecto}/privacy/`, este comando se detiene.

---

## Protocolo

### 1. Leer la skill y referencias

- Leer `.claude/skills/team-onboarding/SKILL.md`
- Leer `.claude/skills/team-onboarding/references/questionnaire-template.md`
- Leer `.claude/skills/team-onboarding/references/expertise-mapping.md`

### 2. Verificar nota informativa RGPD (BLOQUEO)

Comprobar si existe `projects/{proyecto}/privacy/{nombre}-nota-informativa-*.md`.

- Si existe → continuar
- Si NO existe → **DETENER**. Informar:
  "La nota informativa RGPD es obligatoria antes de recoger datos de competencias
  (Art. 13 RGPD). Ejecuta `/team:privacy-notice "{nombre}" --project {proyecto}` primero."

### 3. Verificar contexto del proyecto

- Leer `projects/{proyecto}/CLAUDE.md` — para conocer los módulos del proyecto
- Leer `projects/{proyecto}/equipo.md` — para verificar si el miembro ya existe
- Leer `projects/{proyecto}/reglas-negocio.md` — para personalizar sección C (dominio)

Si el miembro ya tiene un perfil de expertise en equipo.md, informar:
"Este miembro ya tiene una evaluación del {fecha}. ¿Quieres actualizarla o crear una nueva?"

### 4. Personalizar sección C (dominio)

A partir de los módulos del proyecto (detectados en CLAUDE.md o en la estructura del source/),
generar la sección C del cuestionario con los módulos reales:

Ejemplo:
```
Sección C — Conocimiento del Dominio (GestiónClínica)
  C1: Módulo de Pacientes
  C2: Módulo de Citas
  C3: Módulo de Facturación
  C4: Integraciones externas
```

### 5. Ejecutar cuestionario interactivo

Presentar el cuestionario al usuario en bloques manejables. **No preguntar las 26 competencias de golpe.** Usar este flujo:

**Bloque 1 — Sección A: Técnico .NET (A1-A12)**

Para cada competencia, mostrar:
- Nombre y descripción
- Evidencia verificable (qué deberías poder hacer)
- Pedir: nivel (1-5) e interés (S/N)

Agrupar de 3 en 3 para no saturar:
- Primero A1-A3 (C#, Clean Arch, CQRS)
- Luego A4-A6 (EF Core, Validation, Unit Testing)
- Luego A7-A9 (Integration Testing, API, SQL)
- Finalmente A10-A12 (Security, SOLID, CI/CD)

**Bloque 2 — Sección B: Transversal (B1-B7)**

Todas juntas (son menos y más rápidas de evaluar).

**Bloque 3 — Sección C: Dominio (C1-Cn)**

Las competencias de dominio personalizadas para el proyecto.

### 6. Calcular perfil de expertise

Aplicar el algoritmo de `references/expertise-mapping.md`:

1. Calcular `expertise[módulo]` para cada módulo del proyecto
2. Identificar `growth_areas` (Interés=Sí AND Nivel<3)
3. Establecer `ultima_evaluacion` = fecha actual

### 7. Presentar resultado para calibración

Mostrar el perfil calculado al usuario y solicitar validación del Tech Lead:

```
═══ PERFIL DE COMPETENCIAS ═══

  Laura Sánchez — GestiónClínica

  Expertise por módulo:
    pacientes:     4.2  ████████░░  Experta
    citas:         3.1  ██████░░░░  Competente
    facturacion:   2.0  ████░░░░░░  Practicante
    testing:       4.5  █████████░  Experta
    integraciones: 2.8  █████░░░░░  Practicante

  Áreas de crecimiento: facturación, seguridad

  ¿El Tech Lead confirma estos niveles? (S/N/Ajustar)
```

Si hay ajustes, documentar el razonamiento del Tech Lead.

### 8. Guardar resultados

**a) Respuestas raw** (para auditoría RGPD):

Guardar en `projects/{proyecto}/evaluaciones/{nombre}-competencias-{fecha}.yaml`:
```yaml
evaluado: "Laura Sánchez"
fecha: "2026-02-26"
evaluador_tech_lead: "Carlos Mendoza"
secciones:
  A:
    A1: { nivel: 5, interes: false }
    A2: { nivel: 4, interes: false }
    # ...
  B:
    B1: { nivel: 4, interes: false }
    # ...
  C:
    C1: { nivel: 3, interes: true }
    # ...
ajustes_tech_lead:
  - competencia: A9
    original: 3
    ajustado: 2
    razon: "No ha trabajado con planes de ejecución en este proyecto"
```

**b) Perfil en equipo.md:**

Actualizar o añadir la entrada del miembro en `projects/{proyecto}/equipo.md` con:
- `expertise:` (por módulo)
- `growth_areas:` (lista)
- `ultima_evaluacion:` (fecha)

Respetar el formato existente de equipo.md. No borrar otros campos del miembro.

---

## Delegación

Delegar al agente `business-analyst` la calibración de las respuestas:
- Comparar la autoevaluación con evidencia observable (PRs del miembro en el proyecto, si hay histórico Git)
- Sugerir ajustes si hay discrepancia > ±1 nivel
- Documentar el razonamiento de cada ajuste

El `business-analyst` NO tiene la decisión final — es el Tech Lead quien confirma.

---

## Restricciones

- **BLOQUEO si no hay nota informativa RGPD firmada** — sin excepciones
- **No recoger métricas de productividad** — ni LOC, ni commits/día, ni velocidad de cierre (AEPD)
- **No mostrar niveles de otros miembros** — cada evaluación es individual y privada
- **No ejecutar fuera de horario laboral** — Art. 88 LOPDGDD (desconexión digital)
- **No usar como herramienta disciplinaria** — los datos son para asignación y formación, no para evaluación de rendimiento
- **Conservación:** respuestas raw 4 años tras fin de relación laboral, después eliminación definitiva
- Si el trabajador ejerce su derecho de oposición (Art. 21 RGPD), dejar de usar su perfil para asignación automática
