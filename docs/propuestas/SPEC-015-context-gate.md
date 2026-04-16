# SPEC-015: Context Gate for Skill Auto-Activation

> Status: **IMPLEMENTED** · Fecha: 2026-03-22 · Implementado: 2026-03-22
> Origen: Fabrik-Codek — context gate heuristic
> Impacto: Eliminar scoring innecesario en prompts triviales

---

## Problema

skill-auto-activation.md evalúa 79 skills contra cada prompt del usuario,
incluso cuando el prompt es trivialmente clasificable ("hola", "/sprint-status",
"si"). El scoring consume tokens y a veces sugiere skills irrelevantes en
contextos obvios.

Fabrik-Codek resuelve esto con un "Context Gate": heurística rápida que
decide si el RAG/scoring debe ejecutarse. Si no, lo salta completamente.

---

## Diseño

### Clasificación rápida pre-scoring

Antes de ejecutar el scoring de skill-auto-activation, aplicar:

```
1. Es un slash command directo? (/sprint-status, /help)
   → SKIP scoring — el comando ya es explícito

2. Es un saludo/despedida? (hola, adios, gracias, ok, si, no, vale)
   → SKIP scoring — no hay skill relevante

3. Es una respuesta a pregunta de Savia? (contexto: Savia preguntó algo)
   → SKIP scoring — la respuesta es para el flujo actual

4. Es una corrección simple? (no eso no, cambia X por Y, para)
   → SKIP scoring — acción directa, no skill

5. Tiene < 5 palabras y no contiene sustantivos técnicos?
   → SKIP scoring — demasiado corto para inferir skill

6. Ninguno de los anteriores
   → PROCEED con scoring normal
```

### Implementación como fast-path

No es un hook ni un script — es una regla de comportamiento que se añade
a `skill-auto-activation.md` como paso 0:

```markdown
## Paso 0 — Context Gate (fast-path)

ANTES de evaluar skills, verificar si el prompt es trivialmente clasificable.
Si cumple alguna condición de bypass → NO evaluar skills, responder directamente.

Condiciones de bypass:
1. Prompt empieza con `/` (slash command explícito)
2. Prompt es <= 4 palabras sin sustantivos tecnicos
3. Prompt es respuesta a pregunta previa de Savia
4. Prompt es confirmación/negación simple (si, no, ok, vale, cancelar)
5. Focus mode activo y prompt no cambia de tema
```

### Métricas de efectividad

Tracking en `context-tracker-hook.sh`:
- Prompts que pasan el gate vs los que lo saltan
- Falsos negativos: prompts que saltaron el gate pero necesitaban skill
- Target: >= 30% de prompts saltan el gate sin falsos negativos

---

## Implementación

### Fase única (< 1 sprint)

1. Actualizar `docs/rules/domain/skill-auto-activation.md` con Paso 0
2. Añadir tracking de gate decisions en context-tracker
3. Medir durante 2 semanas
4. Ajustar condiciones si hay falsos negativos

---

## Criterios de aceptación

- [ ] >= 30% de prompts saltan el scoring de skills
- [ ] 0 falsos negativos en 50 sesiones de prueba
- [ ] Latencia percibida no cambia (gate es instantáneo)
- [ ] Slash commands NUNCA disparan sugerencia de skill
- [ ] Saludos NUNCA disparan sugerencia de skill

---

## Ficheros afectados

- `docs/rules/domain/skill-auto-activation.md` — añadir Paso 0

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| Gate demasiado agresivo, salta prompts que necesitan skill | Empezar conservador (solo 5 condiciones), expandir con datos |
| Prompt ambiguo: "security" — es saludo o es tema? | Solo bypass si cumple TODAS las condiciones, no parcial |
