# AST Quality Gate — Contexto de Dominio

## Por qué existe esta skill

Los LLMs generan código que compila pero falla en producción: async sin await,
catch vacíos que silencian errores, null dereferences, N+1 queries en loops.
Los revisores humanos los detectan tarde. Esta skill detecta los 5 patrones
de error LLM más frecuentes y 7 criterios universales de calidad en < 30s,
antes de que el código llegue a PR.

## Conceptos de dominio

- **Quality Gate (QG)** — Criterio binario de calidad con ID normalizado QG-01..QG-12. Cada gate tiene severidad: error (bloquea), warning (advisory), info (métrica).
- **Meta-analizador** — Orquestador que detecta el lenguaje, invoca la herramienta nativa apropiada, ejecuta Semgrep, y normaliza ambos outputs a JSON unificado.
- **Unified JSON** — Formato estándar `{meta, score, issues[], summary}` que abstracts las diferencias entre ESLint JSON, SARIF, Ruff JSON, Cargo JSON, etc.
- **LLM anti-pattern** — Error sistemático que los LLMs cometen con frecuencia estadísticamente alta: async misuse, empty catch, null deref sin check, magic numbers, N+1 queries.
- **Herramienta nativa** — Linter/analizador que usa el AST real del compilador del lenguaje (Roslyn para C#, TypeScript Compiler API para TS, go/analysis para Go). Máxima precisión, cero false positives en detecciones de tipo.

## Reglas de negocio que implementa

- **RN-AST-01**: Gates QG-01, QG-03, QG-05, QG-09, QG-12 son bloqueantes — ningún código con estos errores puede llegar a PR.
- **RN-AST-02**: El análisis es siempre no-destructivo — solo lee, nunca modifica código.
- **RN-AST-03**: Si la herramienta nativa no está instalada, Semgrep es fallback obligatorio (cobertura parcial, notificado).
- **RN-AST-04**: Output siempre a `output/quality-gates/` nunca en conversación (regla output-first).
- **RN-AST-05**: Score < 60 bloquea merge hasta corrección humana o override explícito.

## Relación con otras skills

**Upstream:** `spec-driven-development` genera el código que esta skill verifica. Se invoca en Fase 4 (Validate) del dev-session-protocol como validador paralelo.

**Downstream:** `code-comprehension-report` usa el resultado del gate para documentar failure heuristics reales del código. `code-review-rules` usa el score como input para el veredicto de PR.

**Paralelo:** `coherence-validator` verifica spec↔implementación; `ast-quality-gate` verifica calidad del código en sí mismo. Ambos corren en paralelo en Fase 4.

## Decisiones clave

- **3 capas, no 1** — Herramienta nativa (precisión), Semgrep (cobertura), LSP (semántica). Ninguna cubre el 100% sola; las 3 en capas sí.
- **Semgrep como denominador común** — Una sola regla YAML puede aplicar a 8+ lenguajes. Reduce 16 configuraciones a 1 fichero mantenible.
- **JSON unificado** — Abstrae la heterogeneidad de formatos (ESLint, SARIF, Ruff, SpotBugs XML) en un contrato estable que los agentes consumen sin conocer el lenguaje.
- **Async hook** — El gate corre en background (async: true) para no bloquear la velocidad de edición del agente. Solo bloquea el commit (Stop hook).
