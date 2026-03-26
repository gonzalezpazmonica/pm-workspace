<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Portugues | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Ola, eu sou a Savia

Sou a Savia, a corujinha que vive dentro do pm-workspace. O meu trabalho e fazer os teus projetos fluirem: gerencio sprints, decomponho backlog, coordeno agentes de codigo, cuido da faturacao, gero relatorios para a direcao e vigio a divida tecnica — tudo a partir do Claude Code, no idioma que voce usar.

Funciono com Azure DevOps, Jira, ou 100% Git-native com Savia Flow. Quando voce chega pela primeira vez, me apresento e te conheco. Me adapto a voce, nao o contrario.

---

## Quem e voce?

| Papel | O que faco por voce |
|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacidade, relatorios |
| **Tech Lead** | Arquitetura, divida tecnica, tech radar, PRs |
| **Developer** | Specs, implementacao, testes, meu sprint |
| **QA** | Plano de teste, cobertura, regressao, quality gates |
| **Product Owner** | KPIs, backlog, impacto de features, stakeholders |
| **CEO / CTO** | Portfolio, DORA, governanca, exposicao IA |

---

## Como funciono por dentro

Sou um workspace Claude Code com 496 comandos, 46 agentes e 82 skills. Minha arquitetura e **Command > Agent > Skills**: o usuario invoca um comando, o comando delega a um agente especializado, e o agente usa skills de conhecimento reutilizaveis.

Minha memoria persiste em texto puro (JSONL) com indexacao vetorial opcional para busca semantica. Nao envio dados a nenhum servidor — **zero telemetria**. Tudo executa localmente.

Para tirar o maximo proveito de mim:
1. **Explore antes de implementar** — `/plan` para pensar, depois implementar
2. **Me de um jeito de verificar** — testes, builds, screenshots
3. **Um objetivo por sessao** — `/clear` entre tarefas diferentes
4. **Compacte frequentemente** — `/compact` em 50% do contexto

---
Como funciona por dentro em detalhe: **[O meu Sistema de Memoria](docs/memory-architecture.md)**

## Privacidade e Telemetria

**Zero telemetria.** pm-workspace nao envia dados a nenhum servidor. Sem analytics, sem tracking, sem phone-home. Tudo executa localmente. Offline-first por design.

---


> **[Savia Shield](docs/savia-shield.pt.md)** — Sistema de soberania de dados. Classificacao local com LLM, mascaramento reversivel, auditoria completa.

## Instalacao

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia se apresenta automaticamente
```

Documentacao completa: [README.md](README.md) (espanhol) | [README.en.md](README.en.md) (ingles)

> *Savia — sua PM automatizada com IA. Compativel com Azure DevOps, Jira e Savia Flow.*
