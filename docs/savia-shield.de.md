# Savia Shield — Datensouveränitätssystem für agentische KI

> Die Daten deiner Kunden verlassen deinen Rechner nicht ohne deine Erlaubnis.

---

## Was ist Savia Shield

Savia Shield ist ein 4-Schichten-System, das vertrauliche Daten aus
Kundenprojekten schützt, wenn mit KI-Assistenten (Claude, GPT usw.)
gearbeitet wird. Es klassifiziert jeden Datensatz, bevor er den lokalen
Rechner verlassen kann, und maskiert sensible Entitäten, wenn Text für
tiefgehende Verarbeitung an Cloud-APIs gesendet werden muss.

**Das zu lösende Problem:** KI-Werkzeuge senden Prompts an externe Server.
Enthält der Prompt Kundennamen, interne IPs, Zugangsdaten oder Inhalte aus
Besprechungen, entsteht ein Datenleck, das NDAs und die DSGVO verletzt.

**Die Lösung:** 4 unabhängige Schichten, jede von Menschen überprüfbar.

---

## Architektur — Daemon + Proxy + Fallback

### Hauptablauf (Daemon aktiv)

```
Claude Code → Hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (vereinheitlichter Daemon)
  → Daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fallback-Ablauf (Daemon ausgefallen)

```
gate.sh erkennt Daemon offline → Inline-Regex + NFKC + base64 + cross-write
  → gleiche Erkennungen, ohne NER (Presidio ohne Daemon nicht verfügbar)
```

Der Fallback stellt sicher, dass Shield **immer schützt**, auch ohne Daemon.

---

## Die 4 Schichten

### Schicht 1 — Deterministische Eingangskontrolle (regex + NFKC + base64 + cross-write)

Scannt den Inhalt vor dem Schreiben einer öffentlichen Datei. Umfasst:

- Regex für Zugangsdaten, IPs, Tokens, private Schlüssel, SAS-Tokens
- Unicode-NFKC-Normalisierung (erkennt Fullwidth-Ziffern)
- base64-Dekodierung verdächtiger Blobs
- Cross-write: kombiniert vorhandenen Inhalt auf dem Datenträger + neuen Inhalt zur Erkennung von Splits
- Pfad-Normalisierung (löst `../`-Traversal auf)
- Latenz: < 2s. Abhängigkeiten: bash, grep, jq, python3

### Schicht 2 — Lokale Klassifizierung mit LLM (Ollama)

Für Inhalte, die regex nicht auswerten kann (semantischer Text, Besprechungs-
protokolle, Geschäftsbeschreibungen), klassifiziert ein lokales KI-Modell
(qwen2.5:7b) den Text als VERTRAULICH oder ÖFFENTLICH.

- Das Modell läuft auf localhost:11434 — die Daten **verlassen den Rechner nicht**
- Latenz: 2–5 Sekunden
- Widerstandsfähig gegen Prompt-Injection:
  - Trennzeichen [BEGIN/END DATA] isolieren den Text vom Prompt
  - Sandwich-Defense: Anweisung nach den Daten wiederholt
  - Strenge Validierung: Antwortet das Modell nicht genau mit
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, wird CONFIDENTIAL angenommen
- Degradation: Läuft Ollama nicht, wird nur Schicht 1 verwendet

### Schicht 3 — Nachträgliche Überprüfung

Nach jedem Schreibvorgang scannt ein asynchroner Hook die vollständige
Datei auf dem Datenträger (ohne Kürzung) und sucht nach Lecks, die
Schicht 1–2 möglicherweise übersehen haben.

- Blockiert den Arbeitsablauf nicht
- Scannt die VOLLSTÄNDIGE Datei (nicht gekürzt)
- Sofortige Warnung bei erkanntem Leck

### Schicht 4 — Reversibles Maskieren

Wenn die Leistungsfähigkeit von Claude Opus oder Sonnet für komplexe
Analysen benötigt wird, ersetzt Savia Shield alle realen Entitäten
(Personen, Unternehmen, Projekte, Systeme, IPs) durch konsistente
fiktive Namen.

**Vollständiger Ablauf (5 Schritte):**

```
SCHRITT 1 — Der Benutzer hat einen Text mit realen Daten (N4)
  "Der PM des Kunden bat darum, das Abrechnungsmodul zu priorisieren"

SCHRITT 2 — sovereignty-mask.sh mask → ersetzt Entitäten
  Reale Personen        → fiktive Namen (Alice, Bob, Carol...)
  Kundenunternehmen     → fiktives Unternehmen (Acme Corp, Zenith...)
  Reales Projekt        → fiktives Projekt (Project Aurora...)
  Interne Systeme       → fiktive Systeme (CoreSystem, DataHub...)
  Private IPs           → Test-IPs RFC 5737 (198.51.100.x)
  Die Zuordnung wird in mask-map.json gespeichert (lokal, N4)

SCHRITT 3 — Der maskierte Text wird an Claude Opus/Sonnet gesendet
  Claude verarbeitet "Alice Chen von Acme Corp bat darum, CoreSystem zu priorisieren"
  Claude sieht keine realen Daten — arbeitet mit fiktiven Entitäten
  Denkvermögen und Analyse sind gleich tief

SCHRITT 4 — Claude antwortet mit fiktiven Entitäten
  "Ich empfehle, dass Alice Chen von Acme Corp CoreSystem
   gegenüber DataHub priorisiert angesichts der Q3-Deadline..."

SCHRITT 5 — sovereignty-mask.sh unmask → stellt reale Daten wieder her
  Kehrt die Zuordnung um: Alice Chen → reale Person, Acme Corp → reales Unternehmen
  Der Benutzer erhält die Antwort mit den korrekten Namen
  Die Zuordnung wird gelöscht oder je nach Projektrichtlinie aufbewahrt
```

**Garantien:**
- Zuordnungstabelle lokal (N4, nie im git)
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
- Jede Mask/Unmask-Operation im Audit-Log erfasst
- Konsistenz: dieselbe Entität wird immer auf dieselbe fiktive abgebildet

---

## 5 Vertraulichkeitsstufen

| Stufe | Name | Sichtbar für | Beispiel |
|-------|------|--------------|---------|
| N1 | Öffentlich | Internet | Workspace-Code, Templates |
| N2 | Unternehmen | Die Organisation | Org-Konfiguration, Werkzeuge |
| N3 | Benutzer | Nur du | Dein Profil, Einstellungen |
| N4 | Projekt | Projektteam | Kundendaten, Regeln |
| N4b | Nur PM | Nur die PM | Einzelgespräche, Bewertungen |

**Savia Shield schützt die Grenzen N4/N4b → N1.**
Das Schreiben sensibler Daten an private Speicherorte (N2–N4b) ist stets erlaubt.

---

## Was erkannt wird (Schicht 1)

- Connection Strings (JDBC, MongoDB, SQL Server)
- AWS-Schlüssel (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Azure SAS-Tokens (sv=20XX-)
- Google API Keys (AIza...)
- Private Schlüssel (-----BEG​IN...PRIVATE KEY-----)
- Private IPs RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- In base64 kodierte Geheimnisse

---

## Verwendung

### Maskieren vor dem Senden an Claude

```bash
# Text maskieren, bevor er gesendet wird
bash scripts/sovereignty-mask.sh mask "Text mit Kundendaten" --project my-project

# Antwort von Claude demaskieren
bash scripts/sovereignty-mask.sh unmask "Antwort mit Acme Corp"

# Zuordnungstabelle anzeigen
bash scripts/sovereignty-mask.sh show-map
```

### Überprüfen, ob das Gate funktioniert

```bash
# Tests ausführen
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Prüfen, ob Ollama auf localhost läuft
netstat -an | grep 11434
```

---

## Überprüfbarkeit — Keine Blackboxes

Jede Komponente ist eine menschenlesbare Klartextdatei:

| Komponente | Datei | Beschreibung |
|-----------|-------|--------------|
| Vereinheitlichter Daemon | `scripts/savia-shield-daemon.py` | Scan/Mask/Unmask/Health auf localhost:8444 |
| API-Proxy | `scripts/savia-shield-proxy.py` | Fängt Claude-Prompts ab, maskiert/demaskiert |
| NER-Daemon | `scripts/shield-ner-daemon.py` | Persistentes Presidio+spaCy im RAM (~100ms) |
| Gate-Hook | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: Daemon-first, Fallback-Regex |
| Audit-Hook | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: erneuter Scan der vollständigen Datei |
| LLM-Klassifizierer | `scripts/ollama-classify.sh` | Schicht 2 Ollama (Fallback bei ausgefallem Daemon) |
| Maskierer | `scripts/sovereignty-mask.py` | Schicht 4 reversibles Mask/Unmask |
| Git Pre-Commit | `scripts/pre-commit-sovereignty.sh` | Scan gestagter Dateien vor dem Commit |
| Setup | `scripts/savia-shield-setup.sh` | Installer: Deps, Modelle, Token, Daemons |
| Force-Push-Guard | `.claude/hooks/block-force-push.sh` | Blockiert Force-Push, Push auf main, Amend |
| Domänregel | `docs/rules/domain/data-sovereignty.md` | Architektur und Richtlinien |

**Audit-Logs:**
- `output/data-sovereignty-audit.jsonl` — Entscheidungen der Schichten 1–3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — LLM-Entscheidungen
- `output/data-sovereignty-validation/mask-audit.jsonl` — Maskierungsoperationen

---

## Qualität und Tests

- Automatisierte Testsuite (BATS) mit Abdeckung von Kernfunktionen, Randfällen und Mocks
- Unabhängige Sicherheitsaudits (Red Team, Vertraulichkeit, Code Review)
- Mapping zu Compliance-Frameworks (DSGVO, ISO 27001, EU AI Act)

---

## Erweiterte Erkennungsfähigkeiten

- **Base64**: dekodiert verdächtige Blobs und scannt den dekodierten Inhalt erneut
- **Unicode NFKC**: normalisiert Fullwidth-Zeichen und Varianten vor der Regex-Anwendung
- **Cross-write**: kombiniert vorhandenen Inhalt auf dem Datenträger mit neuem Inhalt, um über Schreibvorgänge aufgeteilte Muster zu erkennen
- **API-Proxy**: fängt alle ausgehenden Prompts ab und maskiert Entitäten automatisch
- **Zweisprachiges NER**: kombinierte Analyse auf Spanisch und Englisch, mit projektspezifischer Deny-List
- **Anti-Injection**: dreifache Verteidigung im lokalen Klassifizierer (Trennzeichen, Sandwich, strenge Validierung)

---

## Technische Dokumentation (EN, für das Sicherheitskomitee)

- `docs/data-sovereignty-architecture.md` — Technische Architektur
- `docs/data-sovereignty-operations.md` — Compliance und Risiko
- `docs/data-sovereignty-auditability.md` — Audit-Leitfaden
- `docs/data-sovereignty-finetune-plan.md` — Plan für das Fine-Tuned-Modell

---

## Voraussetzungen

- Ollama installiert (`ollama --version`)
- Modell heruntergeladen (`ollama pull qwen2.5:7b`)
- jq installiert (für JSON-Parsing)
- Python 3.12+ (für Maskierung und NER)
- Presidio (`pip install presidio-analyzer`) — für Schicht 1.5 NER
- spaCy Spanisch-Modell (`python3 -m spacy download es_core_news_md`)
- Mindestens 8 GB RAM (16+ empfohlen)


---

## Schnellinstallation

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Der Installer:
1. Prüft Abhängigkeiten (python3, jq, ollama, presidio, spacy)
2. Lädt benötigte Modelle herunter (qwen2.5:7b, es_core_news_md)
3. Erzeugt Authentifizierungstoken (`~/.savia/shield-token`)
4. Startet `savia-shield-daemon.py` auf localhost:8444 (Scan/Mask/Unmask)
5. Startet `savia-shield-proxy.py` auf localhost:8443 (API-Proxy)
6. Startet `shield-ner-daemon.py` (persistenter NER im RAM)

Nach der Ausführung läuft alle Kommunikation mit der API über den Proxy,
der sensible Entitäten automatisch maskiert.

**Ohne Daemon:** Die Gate- und Audit-Hooks funktionieren weiterhin im
Fallback-Modus (Regex + NFKC + base64 + Cross-Write). Claude Code wird
nie durch einen fehlenden Daemon blockiert.
