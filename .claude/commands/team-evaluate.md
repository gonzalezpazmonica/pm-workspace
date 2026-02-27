---
name: team-evaluate
description: >
  Evaluación interactiva de competencias de un programador.
  Genera perfil de expertise para el algoritmo de asignación. Cumple RGPD.
---

# Evaluación de Competencias

**Programador:** $ARGUMENTS

> Uso: `/team-evaluate "Laura Sánchez" --project GestiónClínica`
> Prerequisito: nota informativa RGPD firmada.

## Protocolo

### 1. Leer contexto
- `.claude/skills/team-onboarding/SKILL.md`
- `projects/{proyecto}/CLAUDE.md` (módulos)
- `projects/{proyecto}/equipo.md` (perfil existente)
- `projects/{proyecto}/reglas-negocio.md` (para personalizar sección C)

### 2. Verificar RGPD (BLOQUEO)
Comprobar `projects/{proyecto}/privacy/{nombre}-nota-informativa-*.md`.
Si no existe → DETENER → sugerir `/team-privacy-notice`.

### 3. Personalizar sección C (dominio)
Generar competencias de dominio a partir de los módulos reales del proyecto.

### 4. Cuestionario interactivo
Presentar en bloques (no las 26 competencias de golpe):
- **Bloque A** (Técnico .NET, A1-A12): grupos de 3 → nivel 1-5 + interés S/N
- **Bloque B** (Transversal, B1-B7): todas juntas
- **Bloque C** (Dominio, C1-Cn): personalizadas

### 5. Calcular perfil
- `expertise[módulo]` por módulo del proyecto
- `growth_areas`: Interés=Sí AND Nivel<3
- Presentar resultado visual → validación del Tech Lead

### 6. Delegación
Agente `business-analyst` calibra respuestas comparando con evidencia (PRs, histórico Git). Sugiere ajustes si discrepancia > ±1 nivel. Tech Lead tiene decisión final.

### 7. Guardar resultados
- **Raw**: `projects/{proyecto}/evaluaciones/{nombre}-competencias-{fecha}.yaml`
- **Perfil**: actualizar en `projects/{proyecto}/equipo.md`

## Restricciones

- **BLOQUEO sin nota RGPD** — sin excepciones
- **No métricas de productividad** — ni LOC, ni commits/día (AEPD)
- **No mostrar niveles de otros** — evaluación individual y privada
- **No fuera de horario laboral** — Art. 88 LOPDGDD
- **No uso disciplinario** — solo para asignación y formación
- **Conservación**: 4 años tras fin de relación, después eliminación
- Si derecho de oposición (Art. 21 RGPD) → dejar de usar perfil para asignación automática
