# Savia Shield Anleitung — Datenschutz fuer den Alltag

> Praktische Nutzung. Fuer technische Architektur: [docs/savia-shield.md](savia-shield.md)

## Was ist Savia Shield

Savia Shield verhindert, dass vertrauliche Daten aus Kundenprojekten (Stufe N4/N4b) in oeffentliche Dateien des Repositorys (Stufe N1) gelangen. Es arbeitet mit 5 unabhaengigen Schichten, die jeweils ueberpruefbar sind. Standardmaessig deaktiviert — wird aktiviert, sobald du mit Kundendaten arbeitest.

## Die 4 Hook-Profile

Profile steuern, welche Hooks ausgefuehrt werden. Jedes Profil umfasst das vorherige:

| Profil | Aktive Hooks | Einsatzfall |
|--------|-------------|-------------|
| `minimal` | Nur Sicherheits-Blocker (Credentials, Force-Push, destruktive Infra, Souveraenitaet) | Demos, Onboarding, Debugging |
| `standard` | Sicherheit + Qualitaet (Bash-Validierung, Plan Gate, TDD, Scope Guard, Compliance) | Taegliche Arbeit (empfohlen) |
| `strict` | Standard + Dispatch-Validierung, Quality Gate beim Stoppen, Kompetenz-Tracker | Vor Releases, kritischer Code |
| `ci` | Wie standard, aber nicht interaktiv | Automatische Pipelines, Skripte |

```bash
bash scripts/hook-profile.sh get           # Aktives Profil anzeigen
bash scripts/hook-profile.sh set standard  # Wechseln (bleibt zwischen Sitzungen)
export SAVIA_HOOK_PROFILE=ci               # Oder per Umgebungsvariable
```

Sicherheits-Hooks, die in ALLEN Profilen laufen: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## Die 5 Schutzschichten

**Schicht 0 — API-Proxy**: Faengt ausgehende Prompts an Anthropic ab. Maskiert Entitaeten automatisch. Aktivieren mit `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Schicht 1 — Deterministisches Gate** (< 2s): PreToolUse-Hook, der Inhalte vor dem Schreiben oeffentlicher Dateien scannt. Regex fuer Credentials, IPs, Tokens. Einschliesslich NFKC und Base64.

**Schicht 2 — Lokale Klassifizierung mit LLM**: Ollama qwen2.5:7b klassifiziert Text semantisch als CONFIDENTIAL oder PUBLIC. Daten verlassen localhost nie. Ohne Ollama arbeitet nur Schicht 1.

**Schicht 3 — Post-Write-Audit**: Asynchroner Hook, der die komplette Datei erneut scannt. Blockiert nicht. Sofortige Warnung bei erkanntem Datenleck.

**Schicht 4 — [VERALTET] Manuelles Masking entfernt**

Das manuelle Masking (`sovereignty-mask.sh`) wurde am 2026-05-05 entfernt.  
Schicht 4 (Proxy) behalt sein eigenes internes Masking in `savia-shield-proxy.py`.  
Dieser Slot bleibt fur eine zukunftige Alternative reserviert.

---

## Aktivieren und Deaktivieren

```bash
/savia-shield enable    # Aktivieren
/savia-shield disable   # Deaktivieren
/savia-shield status    # Status und Installation anzeigen
```

Oder durch Bearbeiten von `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Konfiguration pro Projekt

Jedes Projekt kann sensible Entitaeten definieren in:

- `projects/{name}/GLOSSARY.md` — Fachbegriffe
- `projects/{name}/GLOSSARY-MASK.md` — Entitaeten fuer Masking
- `projects/{name}/team/TEAM.md` — Namen von Stakeholdern

Shield laedt diese Dateien automatisch bei der Arbeit am Projekt.

## Vollstaendige Installation (optional)

Fuer alle 5 Schichten einschliesslich Proxy und NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Anforderungen: Python 3.12+, Ollama, jq, mindestens 8GB RAM. Ohne vollstaendige Installation: Schichten 1 und 3 (Regex + Audit) arbeiten immer.

## Die 5 Vertraulichkeitsstufen

| Stufe | Wer sieht es | Beispiel |
|-------|-------------|---------|
| N1 Oeffentlich | Internet | Workspace-Code |
| N2 Unternehmen | Die Organisation | Org-Konfiguration |
| N3 Benutzer | Nur du | Dein Profil |
| N4 Projekt | Projektteam | Kundendaten |
| N4b Nur PM | Nur die PM | Einzelgespraeche |

Shield schuetzt die Grenzen **N4/N4b nach N1**. Schreiben an private Speicherorte ist immer erlaubt.

## Era 171 (SPEC-071) Verbesserungen

- **Ereignisabdeckung**: 17 von 28 Claude Code-Ereignissen abgedeckt (61%, vorher 25%)
- **`if`-Bedingungen**: 7 Hooks ueberspringen automatisch, wenn die Datei kein Code ist (spart ~40% der Spawns)
- **Neue Ereignisse**: SubagentStart/Stop, TaskCreated/Completed, FileChanged, InstructionsLoaded, ConfigChange
- **Portabilitaet**: Entfernung aller hardcodierten `/tmp/`-Pfade und inkompatiblen `sed -i`-Befehle
- **Nachvollziehbare Timeouts**: Wenn der Daemon >5s dauert, wird es als TIMEOUT_ALLOW im Audit-Log registriert

> Vollstaendige Architektur: [docs/savia-shield.md](savia-shield.md) | Tests: `bats tests/test-data-sovereignty.bats`
