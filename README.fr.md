<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Francais** | [Espagnol](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Catala](README.ca.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Votre equipe de developpement merite une PM qui ne dort jamais

Les sprints derapent. Le backlog grossit sans priorisation. Les rapports pour la direction se font a la main. La dette technique s'accumule sans mesure. Les agents IA generent du code sans specs ni tests.

**pm-workspace** resout cela. C'est une PM complete qui vit dans Claude Code : elle gere les sprints, decompose le backlog, coordonne les agents de code avec des specs executables, genere les rapports pour la direction et surveille la dette technique — dans votre langue, avec vos donnees protegees sur votre machine.

---

## Commencez en 3 minutes

```bash
# 1. Installez
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Ouvrez Claude Code dans le repertoire
cd pm-workspace && claude

# 3. Savia vous salue et demande votre nom. Ensuite :
/sprint-status          # ← votre premiere commande
```

Savia s'adapte a vous. Si vous etes PM, elle montre sprints et capacite. Si vous etes developpeur, votre backlog et specs. Si vous etes CEO, portfolio et metriques DORA.

**Windows :** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Quels problemes ca resout

| Probleme | Sans pm-workspace | Avec pm-workspace |
|---|---|---|
| Etat du sprint | Ouvrir Azure DevOps, filtrer, calculer | `/sprint-status` → tableau de bord complet |
| Rapport pour la direction | 2h sous Excel/PowerPoint | `/ceo-report` → genere avec des donnees reelles |
| Implementer une feature | Demander au dev d'interpreter le ticket | `/spec-generate` → spec executable → agent implemente → tests → PR |
| Dette technique | "On corrigera plus tard" | `/debt-analyze` → priorisee par impact |
| Code review | Revoir 300 lignes a la main | `/pr-review` → 3 perspectives (securite, architecture, metier) |
| Onboarding nouveau dev | 2 semaines a lire du code | `/onboard` → guide personnalise + buddy IA |

---

## Bonjour, je suis Savia 🦉

Je suis la petite chouette qui vit dans pm-workspace. Je m'adapte a votre role, votre langue et votre facon de travailler. Je fonctionne avec Azure DevOps, Jira, ou 100% Git-native avec Savia Flow.

**Quick-starts par role :**

| Role | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Ce qu'il y a dedans

**513 commandes · 56 agents · 91 skills · 55 hooks · 16 langages · 160 suites de tests**

### Gestion de projets
Sprints, burndown, capacite, dailies, retros, KPIs. Rapports en Excel et PowerPoint. Prediction par Monte Carlo. Facturation et couts.

### Developpement avec specs executables (SDD)
Les taches deviennent des specs. Les agents implementent en 16 langages (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) dans des worktrees isoles. Code review automatique + revue humaine obligatoire.

### Securite et Code Review Court
SAST contre OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dynamique, SBOM, conformite dans 12 secteurs. Savia Shield : classification locale des donnees avec LLM on-premise, masquage reversible, signature cryptographique des PRs. **Code Review Court** : 5 juges specialises (correctness, architecture, security, cognitive, spec) examinent en parallele avec un scoring 0-100 et un seuil de 400 LOC.

### Souverainete d'inference
Savia fonctionne par defaut contre l'API Anthropic (qualite maximale). Si le cloud echoue — cable coupe, outage, quota epuise, latence inacceptable — il existe deux options de continuite, toutes deux basees sur Ollama local avec des variantes de Gemma 4 selectionnees selon ton materiel :

| Mode | Activation | Quand l'utiliser |
|---|---|---|
| **Emergency Mode** | Manuel (`source ~/.pm-workspace-emergency.env` et redemarrage de Claude Code) | Quand tu sais deja qu'il n'y a pas de cloud et veux operer 100 % en local |
| **Savia Dual** | Automatique (proxy local sur `127.0.0.1:8787`) | Par defaut : cloud quand ca marche, bascule transparente en local quand non |

Emergency Mode remplace entierement l'upstream via des variables d'environnement. Savia Dual route chaque requete : Anthropic d'abord, Ollama en secours en cas d'erreur reseau, HTTP 5xx, HTTP 429 (quota) ou timeout. Un circuit breaker evite de marteler un upstream en panne.

Les deux options gardent tes donnees dans ta machine en mode local. La souverainete d'inference complete la souverainete des donnees : cloud quand ca va bien, local quand non, sans perdre continuite ni qualite lorsque le cloud est disponible.

Docs : [Savia Dual](docs/savia-dual.md) · [Emergency Mode](docs/EMERGENCY.md) · Installeurs : `scripts/setup-savia-dual.{sh,ps1}`

### Memoire persistante
Texte brut (JSONL). Entity recall, recherche semantique, continuite entre sessions. Extraction automatique des decisions avant compression. Personal Vault chiffre AES-256.

### Accessibilite
Travail guide pour les personnes en situation de handicap (visuel, moteur, TDAH, autisme, dyslexie). Micro-taches, detection de blocages, reformulation adaptative.

### Intelligence du code
Detection d'architecture (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) qui reduisent la dette cognitive.

### Modes autonomes
Sprint nocturne, amelioration du code, recherche technique. Les agents proposent sur des branches `agent/*` avec des PRs Draft — l'humain decide toujours.

### Extensions
[Savia Mobile](projects/savia-mobile-android/README.md) (Android natif) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + voix full-duplex)

---

## Structure

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 513 commandes
│   ├── agents/         ← 56 agents specialises
│   ├── skills/         ← 91 skills de domaine
│   ├── hooks/          ← 55 hooks deterministes
│   └── rules/          ← regles de contexte et de langage
├── docs/               ← guides par role, scenario, secteur
├── projects/           ← projets (git-ignores pour la confidentialite)
├── scripts/            ← validation, CI, utilitaires
├── zeroclaw/           ← materiel ESP32 + voix
└── CLAUDE.md           ← identite et regles fondamentales
```

---

## Documentation

| Section | Description |
|---|---|
| [Guide de demarrage](docs/getting-started.md) | De zero a productif |
| [Flux de donnees](docs/data-flow-guide-es.md) | Comment les parties se connectent |
| [Confidentialite](docs/confidentiality-levels.md) | 5 niveaux (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Souverainete des donnees |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Commandes et agents](docs/readme/12-comandos-agentes.md) | Reference complete |
| [Guides par scenario](docs/guides/README.md) | Azure, Jira, startup, sante... |
| [Adoption](docs/ADOPTION_GUIDE.md) | Pas a pas pour les cabinets de conseil |

---

## Principes

1. **Le texte brut est la verite** — .md et .jsonl. Si l'IA disparait, les donnees restent lisibles
2. **Confidentialite absolue** — les donnees de l'utilisateur ne quittent jamais sa machine
3. **L'humain decide** — l'IA propose, jamais de merge ni de deploy autonome
4. **Apache 2.0 / MIT** — pas de vendor lock-in, pas de telemetrie

---

## Contribuer

Lisez [CONTRIBUTING.md](CONTRIBUTING.md) et [SECURITY.md](SECURITY.md). PRs bienvenus.

## Licence

[MIT](LICENSE) — Cree par [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)
