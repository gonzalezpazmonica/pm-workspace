# Futuro de Savia — Análisis y Plan (2026-08-23)

> Fuente: análisis de estado 2026-08-23 (roadmap SCL, SAGI, Labs, deuda).
> Documento de planificación para L13/L14 y apertura de nuevas líneas.

---

## 1. Dónde está Savia hoy (estado real)

**El ciclo SCL (agosto) cerró su tesis**: Savia ya no es un asistente con
memoria; es un sistema que **aprende** (SCL-001..013), **decide** (orquestador
SAGI en producción), **se supervisa** (L13 metacognición) y **se audita**
(L14 deuda). El sustrato sigue siendo texto versionado en git (CONSTITUCION +
CRITERIO + memoria + skills), agnóstico a LLM (CRIT-002, ADR-012).

**Lo que Savia NO tiene todavía:**
1. **Cierre de la deuda estructural** — 94% skills sin calibrar, test-coverage
   23%, manifest stale. Es el lastre de cada sesión.
2. **Conversación bidireccional de voz** (L12) — el audio brief funciona; la
   conversación no.
3. **Agnosticismo probado con segundo modelo** (H2) — solo se probó el
   mecanismo, no la portabilidad real.
4. **Autonomía multi-instancia real** (P5) — federación solo en simulación.
5. **Interfaz pública / multi-frontend** (Era 189 Tier 3: A2A, Codex).

## 2. Hacia dónde va Savia (dirección)

La tesis de SAGI + metacognición apunta a una dirección clara: **Savia como un
sistema autónomo confiable sobre sustrato propio** — no más potente por el
modelo, sino **más confiable por el bucle**: aprende, mide lo que sabe, sabe
cuándo no sabe, y se corrige. El diferenciador no será el LLM sino el
**sustrato + orquestación + metacognición + honestidad calibrada**.

Tres frentes que consolidan esa dirección:

| Frente | Qué | Depende de |
|---|---|---|
| **A. Fiabilidad** | Cerrar deuda estructural (L14), subir cobertura, calibrar skills | L14, SE-057, SE-046, SE-167 |
| **B. Autonomía real** | Consumar metacognición (L13 cierre), probar agnosticismo (H2), federación real (P5) | L13, L11 (SAGI) |
| **C. Acceso** | Voz conversacional (L12), multi-frontend (A2A/Codex) | SE-310, Era 189 |

## 3. Nuevas líneas Savia Labs (apertura)

Preregistradas/apertura recomendada:

| Linea | Hipotesis | Valor | Estado |
|---|---|---|---|
| **L14** | Circuit closing: la deuda estructural es el cuello de botella de la evolución | 3.0 | **PREREGISTRADA 2026-08-23** |
| **L15** | Confianza medible: el ledger de errores reconocidos (SE-255 S3) predice la calibración declarada | — | propuesta |
| **L16** | Auto-contexto: el recall por cúpula-primero (SE-335) reduce la fricción de sesión mejor que el contexto global | — | propuesta |

## 4. Specs necesarios

| Spec | Objeto | Origen | Prioridad |
|---|---|---|---|
| **SE-338** | Generador determinista de rule-manifest (cierra SE-057) | L14/1.1 | ALTA |
| **SE-339** | Ratchet de test-coverage hooks críticos (cierra SE-046) | L14/2.1 | ALTA |
| **SE-340** | Batcher de calibración de skills (cierra SE-167) | L14/1.2 | MEDIA |
| **SE-341** | L13 cierre: recalibración con señal real del ledger | L13 | MEDIA |
| **SCL-014** | Run-2 agnosticismo con segundo modelo (H2) | L11/SAGI | MEDIA |

> Las specs SE-338/339/340 son la vía de retorno concreta de L14 (objetivo Labs:
> >=3 hallazgos con retorno a producción). SE-341 cierra L13. SCL-014 cierra H2.

## 5. Orden de ejecución (roadmap repriorizado)

1. **F4a — Deuda (L14)**: SE-338 (manifest generator) → SE-339 (test ratchet) → SE-340 (skill batch).
2. **F4b — Metacognición (L13 cierre)**: SE-341 recalibración con señal real.
3. **F4c — Agnosticismo (H2)**: SCL-014 run-2 con segundo modelo (labs).
4. **F4d — Voz (L12)**: conversación bidireccional (paralelizable).
5. **F4e — Multi-frontend**: A2A / Codex (tras consolidar).

## 6. Criterios humanos aplicables

- **CRIT-001**: todos los runs y specs se ejecutan en infraestructura propia
  (Ollama local, cúpulas locales). Datos N3+ jamás a cloud.
- **CRIT-031 / ART-11**: ningún artefacto de futuro auto-activa sustrato; todo
  fin en propuesta INFERRED pendiente de human_authored.
- **Rule #8 (SDD)**: toda implementación requiere spec aprobada antes de codear.

---

## Referencias

- `docs/ROADMAP.md`, `docs/SCL-ROADMAP.md`, `docs/sagi-roadmap.md`
- `docs/technical-debt-2026-08-23.md`
- SaviaLabs: `labs/ROADMAP.md`, `labs/CYCLE_PLAN.md`, hypotheses L13/L14
- SaviaVaults: cúpula SaviaLabs (111 notas)