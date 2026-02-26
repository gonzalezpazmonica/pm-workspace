## Onboarding de Nuevos Miembros

PM-Workspace incluye un flujo completo para incorporar programadores a un proyecto, reduciendo el tiempo de ramp-up de 4-8 semanas a 5-10 días. El proceso cumple con el RGPD/LOPDGDD.

### Flujo en 5 fases

```
Nuevo miembro se incorpora
    ↓
/team:privacy-notice "Nombre"     ← 1. Nota informativa RGPD (obligatoria)
    ↓                                   El trabajador lee y firma el acuse
/team:onboarding "Nombre"         ← 2. Contexto del proyecto + tour del código
    ↓                                   El mentor valida cada fase
  [Primera task asistida]          ← 3. Mentor asigna task B/C, pair con Claude
    ↓                                   Code Review humano obligatorio
/team:evaluate "Nombre"            ← 4. Cuestionario de competencias (8 dimensiones)
    ↓                                   Autoevaluación + calibración Tech Lead
  [Autonomía progresiva]           ← 5. Semanas 1-3 con supervisión decreciente
```

Las fases 3 y 5 son procesos humanos guiados por el mentor, no comandos.

### Fase 1 — Nota informativa RGPD

Antes de recoger cualquier dato del trabajador, la ley exige entregarle una nota informativa (Art. 13 RGPD). El comando `/team:privacy-notice "Nombre" --project MiProyecto` genera el documento a partir de una plantilla que incluye: responsable del tratamiento, finalidad (asignación de tareas y formación), base legal (interés legítimo), derechos del trabajador (acceso, rectificación, supresión, oposición, portabilidad).

El trabajador firma el acuse de recibo antes de continuar. Sin esta firma, `/team:evaluate` se bloquea.

### Fase 2 — Onboarding: contexto y tour del código

El comando `/team:onboarding "Nombre" --project MiProyecto` genera una guía personalizada que cubre:

- **Contexto inmediato**: arquitectura del proyecto, capas, módulos, patrones usados, convenciones del equipo, miembros y roles
- **Tour del codebase**: recorrido de un request de principio a fin (Controller → Handler → Repository → Entity), patrones con ejemplos reales del proyecto, estructura de tests, ubicación de specs SDD

La guía se guarda en `projects/{proyecto}/onboarding/{nombre}-guia.md`. El mentor revisa y ajusta antes de entregársela al nuevo miembro.

### Fase 3 — Primera task asistida (proceso humano)

El mentor asigna una task de complejidad B/C. El nuevo miembro la implementa con pair programming asistido por Claude. El Code Review es siempre humano en esta fase.

### Fase 4 — Evaluación de competencias

El comando `/team:evaluate "Nombre" --project MiProyecto` ejecuta un cuestionario interactivo en tres secciones: A (técnico del stack, 12 competencias), B (transversal, 7 competencias), C (dominio del proyecto, generado dinámicamente según los módulos).

Para cada competencia se recoge nivel (1-5) e interés (S/N). El agente `business-analyst` compara la autoevaluación con evidencia observable (PRs, historial Git) y sugiere ajustes. El Tech Lead co-firma el resultado final.

El perfil resultante se integra en `projects/{proyecto}/equipo.md` como campo `expertise` por módulo, alimentando el algoritmo de asignación de tareas.

### Fase 5 — Autonomía progresiva (proceso humano)

Semanas 1-3 con supervisión decreciente. Métricas de éxito: primer PR aprobado en ≤3 días, ≤3 rondas de review, confianza autoreportada ≥7/10 al día 5.

### Almacenamiento y privacidad

```
projects/{proyecto}/
├── privacy/         ← Notas informativas RGPD firmadas
├── onboarding/      ← Guías personalizadas
└── evaluaciones/    ← Respuestas raw (YAML) para auditoría
```

Los tres directorios están en `.gitignore` — nunca se suben al repositorio. Las respuestas raw se conservan 4 años tras fin de relación laboral y después se eliminan.

### Restricciones legales

- Nunca se recogen métricas de productividad individual (LOC, commits/día, velocidad de cierre)
- Los datos solo se usan para asignación de tareas y formación, nunca como herramienta disciplinaria
- Si el trabajador ejerce su derecho de oposición (Art. 21 RGPD), se deja de usar su perfil para asignación automática
- La evaluación no se ejecuta fuera de horario laboral (Art. 88 LOPDGDD, desconexión digital)
