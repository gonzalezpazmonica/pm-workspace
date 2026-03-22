# SPEC-012: L0/L1/L2 Progressive Loading for Skills and Rules

> Status: **COMPLETE** · Fecha: 2026-03-22 · Phase 1+2: 2026-03-22 (82/82 skills)
> Origen: OpenViking (volcengine) — filesystem-based context tiering
> Impacto: -40-60% tokens en carga de skills

---

## Problema

pm-workspace tiene 79 skills. Cuando skill-auto-activation detecta relevancia,
carga el SKILL.md completo (~100-300 tokens). En sesiones con multiples comandos,
los skills acumulados saturan el contexto. La regla context-health.md ya dice
"cargar solo SKILL.md, no references", pero es insuficiente.

OpenViking demostro que tiered loading (L0/L1/L2) reduce tokens un 80% en
su benchmark con OpenClaw. Aplicamos el mismo principio.

---

## Diseno

### Tres niveles por skill

| Nivel | Contenido | Tokens | Cuando se carga |
|-------|-----------|--------|-----------------|
| L0 | `name` + `description` del frontmatter | ~10-15 | Siempre disponible (ya existe) |
| L1 | Resumen de 5 lineas: que hace, cuando usarlo, output esperado | ~40-60 | Al identificar comando/skill relevante |
| L2 | SKILL.md completo + references si necesario | ~100-500 | Solo durante ejecucion del skill |

### Formato L1

Nuevo campo `summary` en el frontmatter de cada SKILL.md:

```yaml
---
name: pbi-decomposition
description: "Descomponer PBIs en Tasks tecnicas"
summary: |
  Descompone un PBI en tasks granulares con estimacion en horas.
  Input: PBI con acceptance criteria. Output: lista de tasks con
  asignacion sugerida. Usa architect para layer assignment y
  business-analyst para criterios. Min 3 tasks por PBI.
---
```

### Flujo de carga

```
1. Session start → L0 de todos los skills (catalog: ~1200 tokens total)
2. Usuario escribe prompt → skill-auto-activation evalua contra L0
3. Si score >= 70% → cargar L1 del skill candidato (~50 tokens)
4. Si el comando requiere el skill → cargar L2 (SKILL.md completo)
5. Tras ejecucion del comando → descartar L2, mantener L1 en contexto
```

### Aplicacion a rules

Las 41 rules de dominio siguen el mismo patron:

| Nivel | Contenido | Ejemplo |
|-------|-----------|---------|
| L0 | Nombre + 1 linea | "equality-shield: Igualdad activa en asignaciones" |
| L1 | 3-5 lineas clave | "6 sesgos a bloquear. Test contrafactico obligatorio." |
| L2 | Fichero completo | equality-shield.md (50+ lineas) |

L0 de rules ya existe implicitamente en CLAUDE.md (lista de reglas criticas).
L1 se genera como indice compacto.

---

## Implementacion

### Fase 1 — Generar L1 para top 20 skills (1 sprint)

1. Para cada skill en `.claude/skills/*/SKILL.md`:
   - Leer SKILL.md
   - Generar campo `summary` de 5 lineas (puede hacerlo tech-writer)
   - Escribir en frontmatter
2. Actualizar `skill-auto-activation.md` para usar L1 antes de L2
3. Actualizar `context-map.md` para documentar los 3 niveles

### Fase 2 — Generar L1 para rules (1 sprint)

1. Crear `docs/rules-index-L1.md` con 1-3 lineas por regla
2. Este fichero se carga en vez de las reglas individuales
3. Reglas completas se cargan solo cuando un comando las referencia con @

### Fase 3 — Automatizar generacion de L1 (1 sprint)

1. Hook PostToolUse en Write de SKILL.md → regenerar summary
2. Comando `/headroom-apply` incluye generacion de L1 faltantes
3. Validacion en `validate-commands.sh`: warn si skill sin summary

---

## Criterios de aceptacion

- [ ] Top 20 skills tienen campo `summary` en frontmatter
- [ ] skill-auto-activation usa L1 para decidir, no L2
- [ ] Token consumption medido antes/despues en 5 sesiones tipo
- [ ] Reduccion >= 30% en tokens de skills por sesion
- [ ] Ningun skill se carga a L2 sin ser ejecutado

---

## Ficheros afectados

- `.claude/skills/*/SKILL.md` — anadir campo summary
- `.claude/rules/domain/skill-auto-activation.md` — actualizar protocolo
- `.claude/rules/domain/context-map.md` — documentar L0/L1/L2
- `.claude/rules/domain/context-health.md` — actualizar regla de carga

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| L1 desactualizado vs L2 | Hook de regeneracion automatica |
| Summary mal generado pierde info clave | Review humano de top 20 |
| Overhead de mantener 3 niveles | L0 ya existe, L1 es 5 lineas, coste minimo |

---

## Referencias

- OpenViking L0/L1/L2: github.com/volcengine/OpenViking
- context-map.md, skill-auto-activation.md, context-health.md
