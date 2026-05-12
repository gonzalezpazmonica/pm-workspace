# CHECKPOINT.md — Plantilla

> Persistir en `meetings/{tema}/CHECKPOINT.md` o `output/pptx-{slug}/CHECKPOINT.md`.
> Actualizar tras cada fase y tras cada 2-3 slides renderizados.

```markdown
# Checkpoint — {Tema PPT}

> Estado: {F0/F1/F2/F3/F4/F5}
> Última actualización: YYYY-MM-DD HH:MM
> Score actual: NN/100 (objetivo ≥95)

## Decisiones congeladas

1. Ángulo narrativo: ...
2. Audiencia: ...
3. Profundidad técnica: ...
4. Datos cliente: anonimizar SÍ/NO
5. Idioma: es / en / ...

## Fases

### F0 · Setup y assets — [DONE / IN PROGRESS / TODO]
- [ ] Carpeta de trabajo creada
- [ ] PPTX referencia extraído
- [ ] Paleta documentada
- [ ] Logos cliente (navy + white)
- [ ] Iconos renderizados (lista en assets/icons/)
- [ ] Imágenes stock descargadas

### F1 · Guion textual — [DONE / IN PROGRESS / TODO]
- [ ] OCR de notas (si aplica)
- [ ] Transcripción consolidada
- [ ] Ángulos narrativos extraídos
- [ ] Relaciones notas↔features
- [ ] guion-ppt.md redactado
- [ ] **Aprobación humana del guion**

### F2 · Render PPTX — [DONE / IN PROGRESS / TODO]
- presentation_id MCP: `{slug}-v1`
- Slides renderizados:
  - [ ] Slide 1 — Portada
  - [ ] Slide 2 — Problema
  - [ ] Slide 3 — Tesis
  - [ ] Slide 4 — Pilar 1
  - [ ] Slide 5 — Pilar 2
  - [ ] Slide 6 — Pilar 3
  - [ ] Slide 7 — Resumen pilares
  - [ ] Slide 8 — Prueba/caso
  - [ ] Slide 9 — Encaje
  - [ ] Slide 10 — Filosofía
  - [ ] Slide 11 — Cierre

### F3 · Autocrítica (Radical Honesty) — [DONE / IN PROGRESS / TODO]
- Score actual: NN/100
- Findings CRITICAL: N
- Findings HIGH: N
- Findings MEDIUM: N

### F4 · Iteración — [DONE / IN PROGRESS / TODO]
- Iteración 1: NN→NN
- Iteración 2: NN→NN
- ...

### F5 · Entrega — [DONE / TODO]
- [ ] PPTX final ubicado en: `...`
- [ ] Score ≥95 verificado
- [ ] Resumen ejecutivo entregado a usuario

## Blockers / Open Questions

- ...

## Notas para próxima sesión

- ...
```

## Reglas de mantenimiento

- Actualizar tras cada fase completa.
- Actualizar tras cada 2-3 slides renderizados.
- Si se interrumpe sesión: dejar CHECKPOINT en estado coherente.
- Si se retoma: leer CHECKPOINT primero, luego SPEC.md, luego guion.
