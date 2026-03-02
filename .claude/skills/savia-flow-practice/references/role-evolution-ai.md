# Role Evolution — Roles en la Era AI

> Basado en [Kelman Celis: El Nuevo Mapa del Talento](https://medium.com/@kelmants/) — 6 categorías de roles que definen la era de la inteligencia artificial. Adaptado a Savia Flow.

## Las 6 categorías (Kelman Celis, 2026)

### 1. Estrategia y Liderazgo — IA a nivel directivo
Visión de negocio + comprensión profunda de lo que la IA puede (y no puede) hacer.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| Chief AI Officer (CAIO) | Flow Facilitator | Mónica (CEO/CTO) |
| AI Product Manager | AI Product Manager | Elena |
| Estratega Automatización | Flow Facilitator | Mónica (diseña qué automatizar vs. aumentar) |

### 2. Ingeniería y Desarrollo — La sala de máquinas
Construyen, integran y hacen funcionar los sistemas.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| Prompt Engineer | Todos (escriben prompts para Savia) | Elena (specs), Isabel (code prompts) |
| AI Engineer | Pro Builder (orquesta modelos via APIs) | Isabel (backend + API Gateway) |
| AI Agent Developer | Quien diseña agentes del test harness | Mónica (orquesta harness E2E) |
| Arquitecto Modelos | — (no aplica a equipos pequeños) | — |

### 3. Datos y Conocimiento — El combustible de la IA
Datos de alta calidad, relevantes y accesibles. Sin ellos, el mejor modelo es inútil.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| Curador de Datos / RLHF | Quien refina prompts basándose en feedback | Elena (ajusta specs por rework rate) |
| Ingeniero RAG | Context Engineer (priming docs, memory) | Mónica (CLAUDE.md, .priming/) |
| Sintetizador Datos Sintéticos | Mock engine del test harness | Automático (harness.sh mock) |

### 4. Confianza, Ética y Gobernanza — El marco legal
Control, responsabilidad y transparencia. Asegurar que la IA sea justa, legal y segura.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| Auditor Algoritmos | Quality Gates (Gate 4: security) | Elena (QA) + Mónica (review) |
| Especialista XAI | ai-confidence, ai-boundary commands | Mónica (configura límites) |
| Ético de IA | ai-safety-config, ai-audit-log | Equipo (retro incluye ética) |

### 5. Interacción y Creatividad — El factor humano
Cómo humanos y IA colaboran para resultados superiores.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| AI UX Designer | Quien diseña la interacción con Savia | Ana (front, UX de la app) |
| Copiloto Creativo | Augmented Builder con Claude Code | Ana + Isabel (pair con AI) |
| Behavioral AI Trainer | Quien ajusta tono/personalidad de Savia | Mónica (Savia persona: buhita) |

### 6. Mantenimiento y Evolución — El día después del lanzamiento
Un modelo no es estático; necesita cuidado constante.

| Rol industria | En Savia Flow | Quién en SocialApp |
|---|---|---|
| Model Farm Manager (drift) | flow-metrics --trend (detecta degradación) | Mónica (métricas semanales) |
| MLOps Engineer | CI/CD pipelines, quality gates automáticos | Isabel (infra) + GitHub Actions |

## Mapping equipo SocialApp

| Persona | Categorías Kelman | Savia Role |
|---|---|---|
| Mónica | 1 (Estrategia) + 3 (RAG/Priming) + 6 (Mantenimiento) | Flow Facilitator |
| Elena | 1 (AI PM) + 3 (Curación) + 4 (Auditoría) + 5 (Trainer) | AI PM + Quality Arch |
| Ana | 2 (Prompt Eng) + 5 (UX + Copiloto Creativo) | Pro Builder Front |
| Isabel | 2 (AI Engineer + Agent Dev) + 6 (MLOps) | Pro Builder Back + Arch |

## Madurez por categoría (L1-L4)

| Nivel | Indicador | Ejemplo SocialApp |
|---|---|---|
| L1 Puntual | <20% tareas con IA | Ana solo usa copilot para autocompletado |
| L2 Integrado | 20-50% con IA, workflow diario | Elena escribe specs con /flow-spec |
| L3 Orquestador | >50%, múltiples agentes | Mónica ejecuta 5+ comandos Savia/día |
| L4 AI-First | Specs ejecutables por agentes sin intervención | Harness E2E ejecuta 29 pasos autónomo |

## Gaps detectados → mejoras para Savia

| Gap (rol Kelman sin cubrir) | Mejora propuesta | Prioridad |
|---|---|---|
| Ingeniero RAG completo | `/knowledge-prime` — generar .priming/ desde código existente | Alta |
| Behavioral AI Trainer | `/savia-persona-tune` — ajustar tono/estilo por proyecto | Media |
| AI UX Designer | Integrar feedback visual (multimodal) en quality gates | Media |
| Sintetizador Datos | Mejorar mock engine con datos realistas por comando | Baja |
