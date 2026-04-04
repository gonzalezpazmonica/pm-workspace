<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Catala** | [Espanyol](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## El teu equip de desenvolupament mereix una PM que mai no dorm

Els sprints es descontrolen. El backlog creix sense prioritzar. Els informes per a direccio es fan a ma. El deute tecnic s'acumula sense que ningu el mesuri. Els agents d'IA generen codi sense specs ni tests.

**pm-workspace** resol aixo. Es una PM completa que viu dins de Claude Code: gestiona sprints, descompon backlog, coordina agents de codi amb specs executables, genera informes per a direccio i vigila el deute tecnic — en l'idioma que facis servir, amb les dades protegides a la teva maquina.

---

## Comenca en 3 minuts

```bash
# 1. Instal·la
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Obre Claude Code al directori
cd pm-workspace && claude

# 3. Savia et saluda i et pregunta el nom. Despres:
/sprint-status          # ← la teva primera comanda
```

Savia s'adapta a tu. Si ets PM, et mostra sprints i capacitat. Si ets developer, el teu backlog i specs. Si ets CEO, portfolio i metriques DORA.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Quins problemes resol

| Problema | Sense pm-workspace | Amb pm-workspace |
|---|---|---|
| Estat del sprint | Obrir Azure DevOps, filtrar, calcular | `/sprint-status` → dashboard complet |
| Informe per a direccio | 2h a Excel/PowerPoint | `/ceo-report` → generat amb dades reals |
| Implementar feature | Demanar al dev que interpreti el ticket | `/spec-generate` → spec executable → agent implementa → tests → PR |
| Deute tecnic | "Ja ho arreglarem" | `/debt-analyze` → prioritzat per impacte |
| Code review | Revisar a ma 300 linies | `/pr-review` → 3 perspectives (seguretat, arquitectura, negoci) |
| Onboarding nou dev | 2 setmanes llegint codi | `/onboard` → guia personalitzada + buddy IA |

---

## Hola, soc Savia 🦉

Soc la mussola que viu dins de pm-workspace. M'adapto al teu rol, al teu idioma i a la teva forma de treballar. Funciono amb Azure DevOps, Jira, o 100% Git-native amb Savia Flow.

**Quick-starts per rol:**

| Rol | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Que hi ha dins

**508 comandes · 48 agents · 89 skills · 48 hooks · 16 llenguatges · 93 suites de test**

### Gestio de projectes
Sprints, burndown, capacitat, dailies, retros, KPIs. Informes en Excel i PowerPoint. Prediccio amb Monte Carlo. Facturacio i costos.

### Desenvolupament amb specs executables (SDD)
Les tasques es converteixen en specs. Els agents implementen en 16 llenguatges (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) en worktrees aillats. Code review automatic + revisio humana obligatoria.

### Seguretat
SAST contra OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dinamic, SBOM, compliance en 12 sectors. Savia Shield: classificacio local de dades amb LLM on-premise, emmascarament reversible, signatura criptografica de PRs. Emergency Watchdog: fallback automatic a LLM local (Gemma 4 / Qwen) si cau internet.

### Memoria persistent
Text pla (JSONL). Entity recall, cerca semantica, continuitat entre sessions. Extraccio automatica de decisions abans de compactar. Personal Vault xifrat AES-256.

### Accessibilitat
Treball guiat per a persones amb discapacitat (visual, motora, TDAH, autisme, dislexia). Micro-tasques, deteccio de bloquejos, reformulacio adaptativa.

### Intel·ligencia de codi
Deteccio d'arquitectura (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) que redueixen el deute cognitiu.

### Modes autonoms
Sprint nocturn, millora de codi, investigacio tecnica. Els agents proposen en branques `agent/*` amb PRs Draft — l'huma sempre decideix.

### Extensions
[Savia Mobile](projects/savia-mobile-android/README.md) (Android natiu) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + veu full-duplex)

---

## Estructura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 comandes
│   ├── agents/         ← 48 agents especialitzats
│   ├── skills/         ← 89 skills de domini
│   ├── hooks/          ← 48 hooks deterministes
│   └── rules/          ← regles de context i llenguatge
├── docs/               ← guies per rol, escenari, sector
├── projects/           ← projectes (git-ignorats per privacitat)
├── scripts/            ← validacio, CI, utilitats
├── zeroclaw/           ← hardware ESP32 + veu
└── CLAUDE.md           ← identitat i regles fonamentals
```

---

## Documentacio

| Seccio | Descripcio |
|---|---|
| [Guia d'inici](docs/getting-started.md) | De zero a productiu |
| [Flux de dades](docs/data-flow-guide-es.md) | Com es connecten les parts |
| [Confidencialitat](docs/confidentiality-levels.md) | 5 nivells (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Sobirania de dades |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Comandes i agents](docs/readme/12-comandos-agentes.md) | Referencia completa |
| [Guies per escenari](docs/guides/README.md) | Azure, Jira, startup, sanitat... |
| [Adopcio](docs/ADOPTION_GUIDE.md) | Pas a pas per a consultores |

---

## Principis

1. **El text pla es la veritat** — .md i .jsonl. Si es perd la IA, les dades segueixen llegibles
2. **Privacitat absoluta** — les dades de l'usuari mai surten de la seva maquina
3. **L'huma decideix** — la IA proposa, mai merge ni deploy autonom
4. **Apache 2.0 / MIT** — sense vendor lock-in, sense telemetria

---

## Contribuir

Llegeix [CONTRIBUTING.md](CONTRIBUTING.md) i [SECURITY.md](SECURITY.md). PRs benvinguts.

## Llicencia

[MIT](LICENSE) — Creat per [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)
