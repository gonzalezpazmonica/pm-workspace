<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Portugues** | [Espanhol](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Catala](README.ca.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## A sua equipa de desenvolvimento merece uma PM que nunca dorme

Os sprints descontrolam-se. O backlog cresce sem priorizar. Os relatorios para a direcao sao feitos a mao. A divida tecnica acumula-se sem que ninguem a meca. Os agentes de IA geram codigo sem specs nem testes.

**pm-workspace** resolve isto. E uma PM completa que vive dentro do Claude Code: gere sprints, decompoe backlog, coordena agentes de codigo com specs executaveis, gera relatorios para a direcao e vigia a divida tecnica — no idioma que usar, com os dados protegidos na sua maquina.

---

## Comece em 3 minutos

```bash
# 1. Instale
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Abra o Claude Code no diretorio
cd pm-workspace && claude

# 3. A Savia cumprimenta-o e pergunta o seu nome. Depois:
/sprint-status          # ← o seu primeiro comando
```

A Savia adapta-se a si. Se e PM, mostra sprints e capacidade. Se e developer, o seu backlog e specs. Se e CEO, portfolio e metricas DORA.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Que problemas resolve

| Problema | Sem pm-workspace | Com pm-workspace |
|---|---|---|
| Estado do sprint | Abrir Azure DevOps, filtrar, calcular | `/sprint-status` → dashboard completo |
| Relatorio para a direcao | 2h no Excel/PowerPoint | `/ceo-report` → gerado com dados reais |
| Implementar feature | Pedir ao dev que interprete o ticket | `/spec-generate` → spec executavel → agente implementa → testes → PR |
| Divida tecnica | "Vamos resolver depois" | `/debt-analyze` → priorizado por impacto |
| Code review | Rever a mao 300 linhas | `/pr-review` → 3 perspetivas (seguranca, arquitetura, negocio) |
| Onboarding novo dev | 2 semanas a ler codigo | `/onboard` → guia personalizado + buddy IA |

---

## Ola, eu sou a Savia 🦉

Sou a corujinha que vive dentro do pm-workspace. Adapto-me ao seu papel, ao seu idioma e a sua forma de trabalhar. Funciono com Azure DevOps, Jira, ou 100% Git-native com Savia Flow.

**Quick-starts por papel:**

| Papel | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## O que ha la dentro

**532 comandos · 64 agentes · 76 skills · 55 hooks · 16 linguagens · 160 suites de teste**

### Gestao de projetos
Sprints, burndown, capacidade, dailies, retros, KPIs. Relatorios em Excel e PowerPoint. Previsao com Monte Carlo. Faturacao e custos.

### Desenvolvimento com specs executaveis (SDD)
As tarefas convertem-se em specs. Os agentes implementam em 16 linguagens (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) em worktrees isolados. Code review automatico + revisao humana obrigatoria.

### Seguranca e Code Review Court
SAST contra OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dinamico, SBOM, compliance em 12 setores. Savia Shield: classificacao local de dados com LLM on-premise, mascaramento reversivel, assinatura criptografica de PRs. **Code Review Court**: 5 juizes especializados (correctness, architecture, security, cognitive, spec) revisam em paralelo com scoring 0-100 e gate de 400 LOC.

### Soberania de inferencia
Savia corre por default contra a API da Anthropic (qualidade maxima). Quando a cloud falha — cabo caido, outage, quota esgotada, latencia inaceitavel — ha duas opcoes de continuidade, ambas sobre Ollama local com variantes de Gemma 4 selecionadas conforme o hardware:

| Modo | Ativacao | Quando usar |
|---|---|---|
| **Emergency Mode** | Manual (`source ~/.pm-workspace-emergency.env` e reinicio do Claude Code) | Quando ja sabes que nao ha cloud e queres operar 100 % em local |
| **Savia Dual** | Automatico (proxy local em `127.0.0.1:8787`) | Por default: cloud quando funciona, fallback transparente para local quando falha |

Emergency Mode substitui o upstream inteiro via variaveis de ambiente. Savia Dual encaminha cada pedido: Anthropic primeiro, Ollama de reserva em caso de erro de rede, HTTP 5xx, HTTP 429 (quota) ou timeout. Um circuit breaker evita martelar um upstream caido.

Ambas as opcoes deixam os teus dados dentro da tua maquina em modo local. A soberania de inferencia complementa a soberania de dados: cloud quando funciona, local quando nao, sem perder continuidade nem qualidade quando a cloud esta disponivel.

Docs: [Savia Dual](docs/savia-dual.md) · [Emergency Mode](docs/EMERGENCY.md) · Instaladores: `scripts/setup-savia-dual.{sh,ps1}`

### Memoria persistente
Texto simples (JSONL). Entity recall, pesquisa semantica, continuidade entre sessoes. Extracao automatica de decisoes antes de compactar. Personal Vault cifrado AES-256.

### Acessibilidade
Trabalho guiado para pessoas com deficiencia (visual, motora, TDAH, autismo, dislexia). Micro-tarefas, detecao de bloqueios, reformulacao adaptativa.

### Inteligencia de codigo
Detecao de arquitetura (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) que reduzem a divida cognitiva.

### Modos autonomos
Sprint noturno, melhoria de codigo, investigacao tecnica. Os agentes propoem em branches `agent/*` com PRs Draft — o humano decide sempre.

### Extensoes
[Savia Mobile](projects/savia-mobile-android/README.md) (Android nativo) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + voz full-duplex)

---

## Estrutura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 532 comandos
│   ├── agents/         ← 64 agentes especializados
│   ├── skills/         ← 76 skills de dominio
│   ├── hooks/          ← 55 hooks deterministicos
│   └── rules/          ← regras de contexto e linguagem
├── docs/               ← guias por papel, cenario, setor
├── projects/           ← projetos (git-ignorados por privacidade)
├── scripts/            ← validacao, CI, utilitarios
├── zeroclaw/           ← hardware ESP32 + voz
└── CLAUDE.md           ← identidade e regras fundamentais
```

---

## Documentacao

| Secao | Descricao |
|---|---|
| [Guia de inicio](docs/getting-started.md) | De zero a produtivo |
| [Fluxo de dados](docs/data-flow-guide-es.md) | Como as partes se conectam |
| [Confidencialidade](docs/confidentiality-levels.md) | 5 niveis (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Soberania de dados |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Comandos e agentes](docs/readme/12-comandos-agentes.md) | Referencia completa |
| [Guias por cenario](docs/guides/README.md) | Azure, Jira, startup, saude... |
| [Adocao](docs/ADOPTION_GUIDE.md) | Passo a passo para consultoras |

---

## Principios

1. **Texto simples e a verdade** — .md e .jsonl. Se a IA desaparecer, os dados continuam legiveis
2. **Privacidade absoluta** — os dados do utilizador nunca saem da sua maquina
3. **O humano decide** — a IA propoe, nunca merge nem deploy autonomo
4. **Apache 2.0 / MIT** — sem vendor lock-in, sem telemetria

---

## Contribuir

Leia [CONTRIBUTING.md](CONTRIBUTING.md) e [SECURITY.md](SECURITY.md). PRs bem-vindos.

## Licenca

[MIT](LICENSE) — Criado por [la usuaria Gonzalez Paz](https://github.com/gonzalezpazmonica)
