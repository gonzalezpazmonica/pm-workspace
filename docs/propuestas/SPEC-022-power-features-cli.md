# SPEC-022: Power Features CLI

> Status: **READY** · Fecha: 2026-03-22 · Score: 4.60
> Origen: Roadmap P4 — mejoras CLI de alto impacto para PM diario
> Impacto: Reduccion de friccion en flujos repetitivos

---

## Problema

Cuatro gaps en la experiencia CLI que generan friccion diaria:

1. **Sin control de presupuesto de contexto** — el PM no sabe cuanto contexto
   queda ni cuando compactar. Solo alertas reactivas.
2. **Compact pierde informacion** — /compact aplica filtro generico, no sabe
   que preservar segun el trabajo activo.
3. **Sin keybindings PM** — los atajos por defecto son genericos, no optimizados
   para flujo PM (sprint-status, my-sprint, board-flow).
4. **PRs sin contexto de proyecto** — al abrir un PR, Claude no carga
   automaticamente las reglas de negocio ni specs del proyecto.

---

## Solucion: 4 Features independientes

### F1. Autonomous Budget Guard

Script que monitoriza uso de contexto y actua:
- <50%: silencio (saludable)
- 50-70%: banner amarillo "Contexto al X%, considera /compact"
- 70-85%: banner rojo + auto-sugerencia de que preservar
- >85%: bloqueo suave — sugiere /compact antes de ejecutar comando pesado

Implementacion: mejora en `context-budget.md` + hook ligero.

### F2. Semantic Compact Filter

Al ejecutar /compact, en vez del filtro generico, Savia analiza:
- Que tarea esta activa (ultimo comando, ficheros tocados)
- Que decisiones se tomaron en la sesion
- Que errores se corrigieron
Genera un compact summary optimizado que preserva lo critico.

Implementacion: mejora de session-memory-protocol.md (SPEC-016).

### F3. PM Keybindings

Fichero de keybindings optimizado para PM:
- Ctrl+S: /sprint-status
- Ctrl+B: /board-flow
- Ctrl+M: /my-sprint
- Ctrl+D: /daily-routine
- Ctrl+P: /compact
Fichero: `~/.claude/keybindings.json`

### F4. PR Context Loader

Al crear un PR (push-pr.sh o manual), cargar automaticamente:
- reglas-negocio.md del proyecto
- specs vinculadas al branch
- equipo.md (para sugerir reviewers)
Mejora en push-pr.sh + regla de pre-PR.

---

## Fases

### Fase 1 (esta PR)
- [ ] F1: Budget Guard hook (mejora context-budget)
- [ ] F3: PM Keybindings template

### Fase 2
- [ ] F2: Semantic Compact Filter
- [ ] F4: PR Context Loader

## Tests

- Budget guard: simular niveles de contexto, verificar banners
- Keybindings: validar JSON schema
- Compact filter: verificar que preserva decisiones de sesion
- PR loader: verificar que carga ficheros del proyecto
