<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Francais | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Bonjour, je suis Savia

Je suis Savia, la petite chouette qui vit dans pm-workspace. Mon travail est de faire couler vos projets : je gere les sprints, decompose le backlog, coordonne les agents de code, gere la facturation, genere les rapports pour la direction et surveille la dette technique — tout depuis Claude Code, dans la langue que vous utilisez.

Je fonctionne avec Azure DevOps, Jira, ou 100% Git-native avec Savia Flow. Quand vous arrivez pour la première fois, je me presente et j'apprends a vous connaitre. Je m'adapte a vous, pas l'inverse.

---

## Qui etes-vous ?

| Role | Ce que je fais pour vous |
|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacité, rapports |
| **Tech Lead** | Architecture, dette technique, tech radar, PRs |
| **Developer** | Specs, implementation, tests, mon sprint |
| **QA** | Plan de test, couverture, regression, quality gates |
| **Product Owner** | KPIs, backlog, impact des features, stakeholders |
| **CEO / CTO** | Portfolio, DORA, gouvernance, exposition IA |

---

## Comment je fonctionne a l'intérieur

Je suis un workspace Claude Code avec 496 commandes, 46 agents et 82 skills. Mon architecture est **Command > Agent > Skills** : l'utilisateur invoque une commande, la commande delegue a un agent specialise, et l'agent utilise des skills de connaissance reutilisables.

Ma memoire persiste en texte brut (JSONL) avec indexation vectorielle optionnelle pour la recherche semantique. Je n'envoie aucune donnee a aucun serveur — **zero télémétrie**. Tout s'execute localement.

Pour tirer le meilleur parti de moi :
1. **Explorez avant d'implementer** — `/plan` pour reflechir, puis implementer
2. **Donnez-moi un moyen de verifier** — tests, builds, captures d'ecran
3. **Un objectif par session** — `/clear` entre taches differentes
4. **Compactez regulierement** — `/compact` a 50% du contexte

---
Comment ca fonctionne en detail : **[Mon systeme de memoire](docs/memory-architecture.md)**

## Confidentialité et Télémétrie

**Zero télémétrie.** pm-workspace n'envoie aucune donnee a aucun serveur. Pas d'analytics, pas de tracking, pas de phone-home. Tout s'execute localement. Offline-first par conception.

---


> **[Savia Shield](docs/savia-shield.fr.md)** — Systeme de souverainete des donnees. Classification locale par LLM, masquage reversible, audit complet.

## Installation

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia se presente automatiquement
```

Documentation complete : [README.md](README.md) (espagnol) | [README.en.md](README.en.md) (anglais)

> *Savia — votre PM automatisee avec IA. Compatible avec Azure DevOps, Jira et Savia Flow.*
