# Checklist de Onboarding — Día a Día

Checklist para el **mentor** y el **nuevo miembro**. Cada fase tiene un criterio de paso verificable. El mentor firma cada checkpoint antes de avanzar.

---

## Día 1 — Mañana: Contexto (Fase 1)

**Responsable:** PM + Mentor

- [ ] Nota informativa RGPD entregada y firmada (`/team-privacy-notice`)
- [ ] Accesos configurados: Azure DevOps, repositorio Git, CI/CD, canales de comunicación
- [ ] `/context-load` ejecutado en presencia del nuevo miembro
- [ ] Claude explica la arquitectura general del proyecto
- [ ] Mentor complementa con contexto que Claude no tiene (decisiones históricas, deuda técnica conocida, relaciones con el cliente)

**Criterio de paso:** el nuevo miembro puede dibujar el diagrama de capas del proyecto sin ayuda y nombrar los 3-5 módulos principales.

**Firma del mentor:** _________________ Fecha: _________

---

## Día 1 — Tarde: Navegación del Código (Fase 2)

**Responsable:** Nuevo miembro (con Claude) + Mentor

- [ ] Tour guiado del codebase con Claude: entry point → Controller → Handler → Repository → DB
- [ ] Revisar un ejemplo real de cada patrón del proyecto (Command, Query, Validator, Entity Config)
- [ ] Identificar dónde viven los tests y ejecutar `dotnet test` por primera vez
- [ ] Revisar las convenciones del equipo: naming, estructura de carpetas, estilo de commits

**Criterio de paso:** el nuevo miembro puede explicar el flujo completo de un endpoint al mentor, identificando qué clase interviene en cada capa.

**Firma del mentor:** _________________ Fecha: _________

---

## Días 2-3: Primera Task Asistida (Fase 3)

**Responsable:** Mentor (asigna) + Nuevo miembro (implementa)

- [ ] Mentor selecciona una task de complejidad B o C (validator, DTO, unit test, query handler sencillo)
- [ ] Nuevo miembro trabaja con patrón "Pausa y Resuelve": intentar solo 15-20 min → comparar con sugerencia de Claude
- [ ] PR creado con descripción clara del cambio
- [ ] Code Review pasado (puede requerir varias rondas — es esperable)
- [ ] PR mergeado a la rama del sprint

**Criterio de paso:** PR aprobado por el Tech Lead. El nuevo miembro puede explicar cada línea de su código.

**Firma del mentor:** _________________ Fecha: _________

---

## Día 3: Cuestionario de Competencias (Fase 4)

**Responsable:** PM + Nuevo miembro + Tech Lead

- [ ] Verificar que la nota informativa RGPD está firmada
- [ ] Ejecutar `/team-evaluate {nombre} --project {proyecto}`
- [ ] Nuevo miembro responde las secciones A (técnico), B (transversal), C (dominio)
- [ ] Tech Lead revisa y calibra las respuestas (ajustar si discrepancia > ±1 nivel)
- [ ] Ambos confirman el perfil final
- [ ] Perfil registrado en `equipo.md` con `expertise` y `growth_areas`

**Criterio de paso:** perfil completo en `equipo.md`, consensuado entre el trabajador y el Tech Lead.

**Firma del Tech Lead:** _________________ Fecha: _________

---

## Días 4-10: Autonomía Progresiva (Fase 5)

**Responsable:** Mentor (supervisa) + Nuevo miembro (ejecuta)

### Semana 1 (días 4-5)
- [ ] Tasks de capa Application con spec SDD (el contrato elimina ambigüedad)
- [ ] Mentor revisa TODOS los PRs (no solo E1)
- [ ] Participación activa en la Daily Standup

### Semana 2 (días 6-10)
- [ ] Tasks de capas variadas (Application + Infrastructure)
- [ ] Mentor revisa PRs con menor detalle (solo comentarios estructurales)
- [ ] Primer intento de descomponer una task sin spec

### Semana 3+ (post-onboarding)
- [ ] Flujo normal del equipo
- [ ] Mentor disponible bajo demanda (no revisión obligatoria de todos los PRs)
- [ ] Encuesta de confianza día 15 (objetivo: ≥ 7/10)

**Criterio de paso (día 10):** el nuevo miembro puede tomar una task del sprint sin spec SDD y resolverla de forma autónoma.

**Firma del mentor:** _________________ Fecha: _________

---

## Notas para el Mentor

1. **No comparar con Claude.** El objetivo es que el nuevo miembro aprenda, no que produzca. Si Claude da la respuesta perfecta, el valor educativo es bajo — fomentar el patrón "Pausa y Resuelve".

2. **Ajustar el ritmo.** Si el nuevo miembro avanza más rápido, acelerar. Si necesita más tiempo en Fase 2, no hay problema — mejor 1 día extra entendiendo la arquitectura que 2 semanas debuggeando por no entenderla.

3. **Documentar bloqueos.** Si algo tarda más de lo esperado, anotarlo. Esos bloqueos son inputs para mejorar la documentación del proyecto y las specs SDD.

4. **Feedback bidireccional.** Al final del día 5 y del día 10, dedicar 15 minutos a: ¿qué fue útil? ¿qué faltó? ¿qué cambiarías del proceso?
