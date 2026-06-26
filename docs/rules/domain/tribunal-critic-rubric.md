---
context_tier: L2
token_budget: 600
spec_ref: SE-201
---

# Tribunal Critic Rubric

> Default scoring rubric for `scripts/tribunal-critic.sh`.
> Total = 100 points across 4 dimensions of 25 each.
> Ref: SE-201 — Critic scoring cuantitativo en tribunales.

## Dimensiones (25 puntos cada una)

### 1. Correctness (25 pts)

Mide si el veredicto emite un juicio claro y sin contradicciones.

| Score | Criterio |
|---|---|
| 25 | Contiene PASS/FAIL explícito, sin bloqueantes sin resolver |
| 12 | Juicio implícito o parcial |
| 0 | Contiene CRITICAL, REJECT o bloqueantes sin resolver |

Señales positivas: `PASS`, `verdict: pass`, `✓`, `all pass`, `no blocker`.
Señales negativas: `CRITICAL`, `FAIL`, `REJECT`, `blocker`.

### 2. Completeness (25 pts)

Mide si el veredicto cubre las áreas relevantes del código.

| Score | Criterio |
|---|---|
| 25 | ≥3 áreas cubiertas |
| 16 | 2 áreas cubiertas |
| 8 | 1 área cubierta |
| 0 | Ninguna área identificada |

Áreas reconocidas:
- Seguridad / auth / credenciales
- Tests / cobertura / spec
- Performance / complejidad / latencia
- Errores / excepciones / edge cases / null
- API / interfaces / contratos / schema
- Logging / monitoring / tracing / métricas

### 3. Security (25 pts)

Mide si el veredicto aborda el análisis de seguridad.

| Score | Criterio |
|---|---|
| 25 | Menciona OWASP, CWE, injection, XSS, CSRF, o confirma "no security issues" |
| 16 | Menciona "security" con evaluación |
| 0 | No menciona seguridad en absoluto |

### 4. Spec Compliance (25 pts)

Mide si el veredicto referencia criterios de aceptación o specs.

| Score | Criterio |
|---|---|
| 25 | Cita `AC-N` o "acceptance criteria" explícitamente |
| 16 | Menciona `spec`, `SPEC-N`, `SE-N` o "acceptance" |
| 0 | No hay referencia a specs ni criterios |

## Rúbrica custom (--rubric)

Se puede pasar un fichero JSON con pesos alternativos:

```json
{
  "correctness": 40,
  "completeness": 20,
  "security": 30,
  "spec_compliance": 10
}
```

La suma debe ser 100. Si no es 100, el script usa los pesos como están
(el score final puede ser < 100 si la suma < 100).

## Feedback automático

Si una dimensión no alcanza su máximo, el script genera feedback descriptivo
incluido en el campo `feedback` del JSON de salida. Este feedback se pasa
como contexto adicional al re-convocar el tribunal (ciclo iterativo SE-201).

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `SAVIA_CRITIC_THRESHOLD` | `80` | Score mínimo para PASS |
| `SAVIA_CRITIC_MAX_ITERATIONS` | `3` | Ciclos máximos antes de escalar a humano |
