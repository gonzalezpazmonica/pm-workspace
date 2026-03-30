<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Euskara | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Kaixo, Savia naiz

Savia naiz, pm-workspace barruan bizi den hontzatxoa. Nire lana zure proiektuak aurrera eramatea da: sprint-ak kudeatzen ditut, backlog-a deskonposatzen dut, kode-agenteen artean koordinatzen dut, fakturazioaz arduratzen naiz, zuzendaritzarako txostenak sortzen ditut eta zor teknikoa zaintzen dut — dena Claude Code-tik, erabiltzen duzun hizkuntzan.

Azure DevOps-ekin, Jira-rekin, edo %100 Git-native Savia Flow-ekin funtzionatzen dut. Lehenengo aldiz iristen zarenean, aurkezten naiz eta ezagutzen zaitut. Zuri moldatzen naiz, ez alderantziz.

---

## Nor zara?

| Rola | Zer egiten dut zuretzat |
|---|---|
| **PM / Scrum Master** | Sprint-ak, dailyak, ahalmena, txostenak |
| **Tech Lead** | Arkitektura, zor teknikoa, tech radar, PRak |
| **Developer** | Spec-ak, inplementazioa, testak, nire sprint-a |
| **QA** | Test-plana, estaldura, erregresioa, quality gate-ak |
| **Product Owner** | KPIak, backlog-a, feature impact-a, stakeholderrak |
| **CEO / CTO** | Portfolioa, DORA, gobernantza, IA esposizioa |

**Lehen aldia?** Irakurri [Hasteko Gida](docs/getting-started.eu.md) — zerotik produktibora 15 minututan. Bezeroen datuen babeserako: [Savia Shield Gida](docs/savia-shield-guide.eu.md).

---

## Nola funtzionatzen dut barrutik

Claude Code workspace bat naiz 505 komando, 49 agente eta 85 skill-ekin. Nire arkitektura **Command > Agent > Skills** da: erabiltzaileak komando bat deitzen du, komandoak agente espezializatu bati delegatzen dio, eta agenteak berrerabilgarriak diren ezagutza skill-ak erabiltzen ditu.

Nire memoria testu arruntean gordetzen da (JSONL) bilaketa semantikorako hautazko indexazio bektorialarekin. Ez ditut datuak inongo zerbitzarira bidaltzen — **zero telemetria**. Dena lokalki exekutatzen da.

Niri ahalik eta etekinik handiena ateratzeko:
1. **Esploratu inplementatu aurretik** — `/plan` pentsatzeko, gero inplementatu
2. **Eman egiaztatzeko modua** — testak, buildak, pantaila-kapturak
3. **Helburu bat saioko** — `/clear` zeregin desberdinen artean
4. **Trinkotu maiz** — `/compact` testuinguruaren %50ean

---

## Pribatutasuna eta Telemetria

**Zero telemetria.** pm-workspace-k ez du daturik inongo zerbitzarira bidaltzen. Ez dago analitika, ez dago jarraipen, ez dago phone-home. Dena lokalki exekutatzen da. Offline-first diseinuz.

---


> **[AST Estrategia](docs/ast-strategy.eu.md)** — Kode legatuaren ulermena + 12 Quality Gate unibertsal. AST arkitektura bikoitza: editatu aurreko ulermena eta sortutako kodearen kalitatea. **Human Code Maps (.hcm)** — azpisistemaren lehen ibilbidea aurre-digeritzen duten hizkuntza naturaleko mapa narratiboak. Proiektu bakoitzak bere mapak daramatza `.human-maps/` bere karpetaren barnean. Komandoak: `/codemap:generate-human`, `/codemap:walk`, `/codemap:debt-report`. Zor kognitiboaren aurkako borroka aktiboa: garatzaileek denbora %58 kode irakurtzen ematen dute; mapa hauek kostu hori murrizten dute saio batetik bestera.
> **[Savia Shield](docs/savia-shield.eu.md)** — Datuen subiranotasun sistema. Sailkapen lokala LLM-arekin, maskaratze itzulgarria, auditoria osoa.
> **Era 164** — Kalitate moldagarria: Responsibility Judge (hook deterministikoa, 7 patroi), trace-to-prompt optimizazioa, instintu-kolapsoa detekzioa, eskakizunen pushback-a, dev-session discard-a, arriskuan oinarritutako review-aren sakontasuna, reaction engine-a, 13 egoerako state machine-a, zereginen deskonposizio errekurtsiboa.

## Instalazioa

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia automatikoki aurkezten da
```

Dokumentazio osoa: [README.md](README.md) (gaztelania) | [README.en.md](README.en.md) (ingelesa)

> *Savia — zure PM automatizatua IArekin. Azure DevOps, Jira eta Savia Flow-ekin bateragarria.*
