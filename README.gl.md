<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Galego** | [Castelán](README.md) | [English](README.en.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## O teu equipo de desenvolvemento merece unha PM que nunca dorme

Os sprints descontrolanse. O backlog medra sen priorizar. Os informes para direccion fanse a man. A debeda tecnica acumulase sen que ninguén a mida. Os axentes de IA xeran codigo sen specs nin tests.

**pm-workspace** resolve isto. E unha PM completa que vive dentro de Claude Code: xestiona sprints, descompon backlog, coordina axentes de codigo con specs executabeis, xera informes para direccion e vixia a debeda tecnica — na lingua que uses, cos datos protexidos na tua maquina.

---

## Comeza en 3 minutos

```bash
# 1. Instala
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Abre Claude Code no directorio
cd pm-workspace && claude

# 3. Savia saudate e preguntache o nome. Despois:
/sprint-status          # ← o teu primeiro comando
```

Savia adaptase a ti. Se es PM, mostrate sprints e capacidade. Se es developer, o teu backlog e specs. Se es CEO, portfolio e metricas DORA.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Que problemas resolve

| Problema | Sen pm-workspace | Con pm-workspace |
|---|---|---|
| Estado do sprint | Abrir Azure DevOps, filtrar, calcular | `/sprint-status` → dashboard completo |
| Informe para direccion | 2h en Excel/PowerPoint | `/ceo-report` → xerado con datos reais |
| Implementar feature | Pedir ao dev que interprete o ticket | `/spec-generate` → spec executabel → axente implementa → tests → PR |
| Debeda tecnica | "Xa o arranxaremos" | `/debt-analyze` → priorizado por impacto |
| Code review | Revisar a man 300 linhas | `/pr-review` → 3 perspectivas (seguridade, arquitectura, negocio) |
| Onboarding novo dev | 2 semanas lendo codigo | `/onboard` → guia personalizada + buddy IA |

---

## Ola, son Savia 🦉

Son a mouchiña que vive dentro de pm-workspace. Adaptome ao teu rol, a tua lingua e a tua forma de traballar. Funciono con Azure DevOps, Jira, ou 100% Git-native con Savia Flow.

**Quick-starts por rol:**

| Rol | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## O que hai dentro

**532 comandos · 64 axentes · 76 skills · 55 hooks · 16 linguaxes · 160 suites de test**

### Xestion de proxectos
Sprints, burndown, capacidade, dailies, retros, KPIs. Informes en Excel e PowerPoint. Prediccion con Monte Carlo. Facturacion e custos.

### Desenvolvemento con specs executabeis (SDD)
As tarefas convertense en specs. Os axentes implementan en 16 linguaxes (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) en worktrees illados. Code review automatico + revision humana obrigatoria.

### Seguridade e Code Review Court
SAST contra OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dinamico, SBOM, compliance en 12 sectores. Savia Shield: clasificacion local de datos con LLM on-premise, enmascaramento reversibel, sinatura criptografica de PRs. **Code Review Court**: 5 xuices especializados (correctness, architecture, security, cognitive, spec) revisan en paralelo con scoring 0-100 e gate de 400 LOC.

### Soberania de inferencia
Savia corre por defecto contra a API de Anthropic (calidade maxima). Cando a nube falla — cable caido, outage, cota esgotada, latencia inaceptable — hai duas opcions de continuidade, ambas sobre Ollama local con variantes de Gemma 4 seleccionadas segundo o teu hardware:

| Modo | Activacion | Cando usalo |
|---|---|---|
| **Emergency Mode** | Manual (`source ~/.pm-workspace-emergency.env` e reinicio de Claude Code) | Cando xa sabes que non hai nube e queres operar 100 % en local |
| **Savia Dual** | Automatica (proxy local en `127.0.0.1:8787`) | Por defecto: nube cando funciona, fallback transparente a local cando falla |

Emergency Mode substitue o upstream completo mediante variables de entorno. Savia Dual encamina cada peticion: Anthropic primeiro, Ollama de reserva en caso de erro de rede, HTTP 5xx, HTTP 429 (cota) ou timeout. Un circuit breaker evita martelar un upstream caido.

Ambas opcions deixan os teus datos dentro da tua maquina en modo local. A soberania de inferencia complementa a de datos: nube cando funciona, local cando non, sen perder continuidade nin calidade cando a nube esta dispoñible.

Docs: [Savia Dual](docs/savia-dual.md) · [Emergency Mode](docs/EMERGENCY.md) · Instaladores: `scripts/setup-savia-dual.{sh,ps1}`

### Memoria persistente
Texto plano (JSONL). Entity recall, busca semantica, continuidade entre sesions. Extraccion automatica de decisions antes de compactar. Personal Vault cifrado AES-256.

### Accesibilidade
Traballo guiado para persoas con discapacidade (visual, motora, TDAH, autismo, dislexia). Micro-tarefas, deteccion de bloqueos, reformulacion adaptativa.

### Intelixencia de codigo
Deteccion de arquitectura (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) que reducen a debeda cognitiva.

### Modos autonomos
Sprint nocturno, mellora de codigo, investigacion tecnica. Os axentes propoñen en ramas `agent/*` con PRs Draft — o humano sempre decide.

### Extensions
[Savia Mobile](projects/savia-mobile-android/README.md) (Android nativo) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + voz full-duplex)

---

## Estrutura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 532 comandos
│   ├── agents/         ← 64 axentes especializados
│   ├── skills/         ← 76 skills de dominio
│   ├── hooks/          ← 55 hooks deterministas
│   └── rules/          ← regras de contexto e linguaxe
├── docs/               ← guias por rol, escenario, sector
├── projects/           ← proxectos (git-ignorados por privacidade)
├── scripts/            ← validacion, CI, utilidades
├── zeroclaw/           ← hardware ESP32 + voz
└── CLAUDE.md           ← identidade e regras fundamentais
```

---

## Documentacion

| Seccion | Descricion |
|---|---|
| [Guia de inicio](docs/getting-started.md) | De cero a produtivo |
| [Fluxo de datos](docs/data-flow-guide-es.md) | Como se conectan as partes |
| [Confidencialidade](docs/confidentiality-levels.md) | 5 niveis (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Soberania de datos |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Comandos e axentes](docs/readme/12-comandos-agentes.md) | Referencia completa |
| [Guias por escenario](docs/guides/README.md) | Azure, Jira, startup, sanidade... |
| [Adopcion](docs/ADOPTION_GUIDE.md) | Paso a paso para consultoras |

---

## Principios

1. **O texto plano e a verdade** — .md e .jsonl. Se se perde a IA, os datos seguen lexibeis
2. **Privacidade absoluta** — os datos do usuario nunca saen da sua maquina
3. **O humano decide** — a IA propon, nunca merge nin deploy autonomo
4. **Apache 2.0 / MIT** — sen vendor lock-in, sen telemetria

---

## Contribuir

Le [CONTRIBUTING.md](CONTRIBUTING.md) e [SECURITY.md](SECURITY.md). PRs benvidos.

## Licenza

[MIT](LICENSE) — Creado por [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)
