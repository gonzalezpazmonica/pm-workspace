# SPEC-SE-005 — Sovereign Deployment

> **Prioridad:** P0 · **Estima:** 6 días · **Tipo:** despliegue soberano

## Objetivo

Hacer que Savia Enterprise se pueda desplegar **100% on-premise, air-gap ready,
sin llamadas salientes a ninguna API de proveedor**. El cliente opera con
modelos locales (Ollama, vLLM, llama.cpp), datos locales y audit trail local.
Modo "sovereign" es opt-in pero de primera clase, no un workaround.

## Principios afectados

- #1 Soberanía del dato (no hay dato que salga del cliente)
- #2 Independencia del proveedor (sin dependencia de API externa)
- #4 Privacidad absoluta (reforzada con air-gap)

## Diseño

### Modos de despliegue

```
┌──────────────┬─────────────┬──────────────┬─────────────┐
│ Modo         │ LLM         │ Red exterior │ Datos salen │
├──────────────┼─────────────┼──────────────┼─────────────┤
│ cloud        │ Anthropic   │ Sí           │ Sí (API)    │
│ hybrid       │ Anthropic   │ Sí (mask)    │ Enmascarado │
│ sovereign    │ Ollama      │ No           │ No          │
│ air-gap      │ Ollama      │ No (bloqueo) │ No          │
└──────────────┴─────────────┴──────────────┴─────────────┘
```

Configuración por tenant: `tenants/{slug}/deployment.yaml`:

```yaml
mode: sovereign
llm:
  provider: ollama
  host: http://localhost:11434
  models:
    agent: qwen2.5:32b
    mid: qwen2.5:7b
    fast: qwen2.5:3b
network:
  egress_allowed: false
  allowed_hosts: []
```

### Network guard

Hook `network-egress-guard.sh` intercepta cualquier intento de llamada
saliente cuando `mode: sovereign` o `mode: air-gap`. Bloqueo a nivel hook,
no a nivel firewall (capa adicional).

### LLM provider abstraction

Adaptador unificado para runtimes LLM locales:
- **Ollama** (default, ya parcialmente integrado vía Savia Shield)
- **vLLM** (alta concurrencia)
- **llama.cpp** (edge, hardware limitado)
- **LocalAI** (drop-in OpenAI-compatible)

### Sovereign-ready agents

Algunos agentes Opus no funcionan bien con modelos locales <70B. Marcar
agentes con `sovereign_compatible: true|partial|false` en frontmatter.
Si `mode: sovereign` y el agente es `false`, degradar a modelo mayor o
escalar a humano.

### Hardware reference

Documentar configuraciones validadas:
- **Framework Desktop (Ryzen AI MAX+ 395, 128 GB)** — Qwen 32B cómodo
- **Mac Studio M2 Ultra (192 GB)** — Qwen 72B cómodo
- **Workstation Linux 2× RTX 4090** — Llama 70B, vLLM

## Criterios de aceptación

1. Modo `sovereign` configurable por tenant
2. Hook `network-egress-guard.sh` bloquea egress no autorizado
3. Savia arranca, hace spec + implementación + review usando solo Ollama local
4. Documentado `sovereign_compatible` en los 46 agentes
5. Benchmark público: Savia en Ryzen AI MAX+ 395, Claude Core vs Qwen 32B
6. Guía "Savia en air-gap" en inglés con pasos reproducibles

## Out of scope

- Hardware específico comercial
- Modelos propios entrenados por Savia

## Dependencias

- SE-001, SE-002

## Impacto estratégico

Palanca directa para el mercado de soberanía digital (IPCEI-AI, KPMG,
Informe Draghi). Perfiles como OpenNebula encajan brutalmente con esta
capacidad.
