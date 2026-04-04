<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Euskara** | [Gaztelania](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Catala](README.ca.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Zure garapen-taldeak inoiz lo egiten ez duen PM bat merezi du

Sprint-ak kontroletik irteten dira. Backlog-a lehentasunik gabe hazten da. Zuzendaritzarako txostenak eskuz egiten dira. Zor teknikoa neurtu gabe pilatzen da. IA agenteek kodea sortzen dute spec-ik eta test-ik gabe.

**pm-workspace**-k hau konpontzen du. Claude Code barruan bizi den PM oso bat da: sprint-ak kudeatzen ditu, backlog-a deskonposatzen du, kode-agenteak spec exekutagarriekin koordinatzen ditu, zuzendaritzarako txostenak sortzen ditu eta zor teknikoa zaintzen du — erabiltzen duzun hizkuntzan, datuak zure makinan babestuta.

---

## Hasi 3 minututan

```bash
# 1. Instalatu
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Ireki Claude Code direktorioan
cd pm-workspace && claude

# 3. Saviak agurtzen zaitu eta izena galdetzen dizu. Gero:
/sprint-status          # ← zure lehen komandoa
```

Savia zuri moldatzen zaizu. PM bazara, sprint-ak eta ahalmena erakusten dizkizu. Developer bazara, backlog-a eta spec-ak. CEO bazara, portfolioa eta DORA metrikak.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Zer arazo konpontzen ditu

| Arazoa | pm-workspace gabe | pm-workspace-rekin |
|---|---|---|
| Sprint-aren egoera | Azure DevOps ireki, iragazi, kalkulatu | `/sprint-status` → dashboard osoa |
| Zuzendaritzarako txostena | 2h Excel/PowerPoint-en | `/ceo-report` → datu errealekin sortua |
| Feature inplementatu | Dev-ari ticket-a interpretatzeko eskatu | `/spec-generate` → spec exekutagarria → agenteak inplementatzen du → testak → PR |
| Zor teknikoa | "Geroago konponduko dugu" | `/debt-analyze` → eraginaren arabera lehenetsia |
| Code review | 300 lerro eskuz berrikusi | `/pr-review` → 3 ikuspegi (segurtasuna, arkitektura, negozioa) |
| Dev berriaren onboarding | 2 aste kodea irakurtzen | `/onboard` → gida pertsonalizatua + IA buddy |

---

## Kaixo, Savia naiz 🦉

pm-workspace barruan bizi den hontzatxoa naiz. Zure rolera, zure hizkuntzara eta zure lan-erara moldatzen naiz. Azure DevOps-ekin, Jira-rekin edo %100 Git-native Savia Flow-ekin funtzionatzen dut.

**Quick-start-ak rolaren arabera:**

| Rola | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Zer dago barruan

**508 komando · 48 agente · 89 skill · 48 hook · 16 hizkuntza · 107 test suite**

### Proiektuen kudeaketa
Sprint-ak, burndown-a, ahalmena, dailyak, retroak, KPIak. Txostenak Excel eta PowerPoint formatuan. Monte Carlo bidezko iragarpena. Fakturazioa eta kostuak.

### Spec-Driven Development (SDD)
Zereginak spec bihurtzen dira. Agenteek 16 hizkuntzatan inplementatzen dute (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) worktree isolatuetan. Code review automatikoa + giza berrikusketa derrigorrezkoa.

### Segurtasuna
SAST OWASP Top 10-aren aurka, Red/Blue/Auditor pipeline-a, pentesting dinamikoa, SBOM, compliance 12 sektoretan. Savia Shield: datuen sailkapen lokala on-premise LLM-arekin, maskaratze itzulgarria, PR-en sinadura kriptografikoa. Emergency Watchdog: fallback automatikoa LLM lokalera (Gemma 4 / Qwen) internet erortzen bada.

### Memoria iraunkorra
Testu arrunta (JSONL). Entity recall, bilaketa semantikoa, saioen arteko jarraitutasuna. Erabakien erauzketa automatikoa trinkotu aurretik. Personal Vault AES-256-rekin zifratua.

### Irisgarritasuna
Lan gidatua desgaitasunak dituzten pertsonentzat (ikusmena, motorra, AGAH, autismoa, dislexia). Mikro-zereginak, blokeoen detekzioa, birformulatze moldagarria.

### Kode-adimena
Arkitektura-detekzioa (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) zor kognitiboa murrizten dutenak.

### Modu autonomoak
Gaueko sprint-a, kodearen hobekuntza, ikerketa teknikoa. Agenteek `agent/*` adarretan proposatzen dute Draft PR-ekin — gizakiak beti erabakitzen du.

### Luzapenak
[Savia Mobile](projects/savia-mobile-android/README.md) (Android natiboa) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboardak) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + ahots full-duplex)

---

## Egitura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 komando
│   ├── agents/         ← 48 agente espezializatu
│   ├── skills/         ← 89 domeinu skill
│   ├── hooks/          ← 48 hook deterministiko
│   └── rules/          ← testuinguru eta hizkuntza arauak
├── docs/               ← gidak rolaren, eszenarioaren, sektorearen arabera
├── projects/           ← proiektuak (git-ignoratuak pribatutasunagatik)
├── scripts/            ← balidazioa, CI, tresnak
├── zeroclaw/           ← ESP32 hardwarea + ahotsa
└── CLAUDE.md           ← identitatea eta oinarrizko arauak
```

---

## Dokumentazioa

| Atala | Deskribapena |
|---|---|
| [Hasteko gida](docs/getting-started.md) | Zerotik produktibora |
| [Datu-fluxua](docs/data-flow-guide-es.md) | Nola konektatzen diren atalak |
| [Konfidentzialtasuna](docs/confidentiality-levels.md) | 5 maila (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Datuen subiranotasuna |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Komandoak eta agenteak](docs/readme/12-comandos-agentes.md) | Erreferentzia osoa |
| [Eszenario-gidak](docs/guides/README.md) | Azure, Jira, startup, osasuna... |
| [Adopzioa](docs/ADOPTION_GUIDE.md) | Pausoz pauso aholkularitzentzat |

---

## Printzipioak

1. **Testu arrunta da egia** — .md eta .jsonl. IA desagertzen bada, datuak irakurgarriak izaten jarraitzen dute
2. **Pribatutasun absolutua** — erabiltzailearen datuak ez dira inoiz bere makinatik irteten
3. **Gizakiak erabakitzen du** — IAk proposatzen du, inoiz ez merge edo deploy autonomoa
4. **Apache 2.0 / MIT** — vendor lock-in gabe, telemetria gabe

---

## Lagundu

Irakurri [CONTRIBUTING.md](CONTRIBUTING.md) eta [SECURITY.md](SECURITY.md). PR-ak ongi etorriak.

## Lizentzia

[MIT](LICENSE) — [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)-ek sortua
