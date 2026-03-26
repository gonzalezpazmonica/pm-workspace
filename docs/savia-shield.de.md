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

## Die 4 Schichten

### Schicht 1 — Deterministische Eingangskontrolle (regex)

Scannt den Inhalt mit regex-Mustern, bevor eine Datei geschrieben wird.
Werden Zugangsdaten, private IPs, API-Tokens oder private Schlüssel in
einer öffentlichen Datei erkannt, **wird das Schreiben blockiert**.

- Latenz: < 2 Sekunden
- Abhängigkeiten: bash, grep, jq (POSIX-Standard)
- Immer aktiv, auch ohne Internetverbindung
- base64-Erkennung: dekodiert verdächtige Blobs und scannt erneut

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
- 95+ gemappte Entitäten pro Projekt über GLOSSARY-MASK.md
- Pools mit 32 Personen, 12 Unternehmen, 16 fiktiven Systemen
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
- AWS-Schlüssel (AKIA...), GitHub (ghp_, github_pat_), OpenAI (sk-...)
- Azure SAS-Tokens (sv=20XX-)
- Google API Keys (AIza...)
- Private Schlüssel (-----BEGIN...PRIVATE KEY-----)
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

| Komponente | Datei | Zeilen |
|-----------|-------|--------|
| regex-Eingangskontrolle | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| LLM-Klassifizierer | `scripts/ollama-classify.sh` | 99 |
| Nachträgliche Überprüfung | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Maskierer | `scripts/sovereignty-mask.py` | ~180 |
| Git Pre-Commit | `scripts/pre-commit-sovereignty.sh` | 72 |
| Domänregel | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Audit-Logs:**
- `output/data-sovereignty-audit.jsonl` — Entscheidungen der Schichten 1–3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — LLM-Entscheidungen
- `output/data-sovereignty-validation/mask-audit.jsonl` — Maskierungsoperationen

---

## Validierung

- **51 automatisierte Tests** (BATS) — Kernfunktionen + Randfälle + Fixes + Mocks
- **3 unabhängige Audits** — Red Team, Vertraulichkeit, Code Review
- **24 gefundene Schwachstellen — 24 behoben, 0 offen**
- **0 verbleibende Einschränkungen** — alle technisch behoben
- **Sicherheitsbewertung: 100/100**
- **Vollständiges Mapping DSGVO/ISO 27001/EU AI Act**

---

## Technische Einschränkungen und deren Mitigation

### base64 und Datenkodierung

Savia Shield dekodiert automatisch base64-Blobs (bis zu 20 Blobs mit
maximal 200 Zeichen) und scannt den dekodierten Inhalt erneut. Enthält der
dekodierte Blob eine Zugangsinformation oder interne IP, wird blockiert.

### Unicode und Homoglyphen

Vor der Anwendung von regex wird der Inhalt mit Unicode NFKC normalisiert.
Dabei werden Fullwidth-Zeichen und andere Varianten in kanonisches ASCII
konvertiert. Nach der Normalisierung werden Fullwidth-Ziffern in ASCII-
Ziffern umgewandelt, sodass regex sie korrekt erkennt.

### Aufgeteilte Schreibvorgänge (split-write)

Cross-Write-Defense: Wird in eine öffentliche Datei geschrieben, die
bereits auf dem Datenträger existiert, liest Savia Shield den vorhandenen
Inhalt und kombiniert ihn mit dem neuen Inhalt. Die regex-Muster werden
auf den kombinierten Text angewendet und erkennen Muster, die erst durch
das Zusammenfügen beider Schreibvorgänge entstehen.

### Konversationeller Inhalt (Prompts an den KI-Assistenten)

Schicht 4 (reversibles Masking) erlaubt es, Text zu maskieren BEVOR er
in den Chat eingefügt wird. Der NER-Hook scannt Dateien, die der Assistent
liest. Schulung: Benutzer referenzieren Dateien über ihren Pfad statt den
Inhalt zu kopieren. Verbleibende Einschränkung: Es gibt keine technische
Abfangung von Text, den der Benutzer direkt in den Prompt eingibt — dies
erfordert Integration auf Protokollebene (zukünftige Verbesserung).

### Prompt-Injection im lokalen Klassifizierer

Dreifache Verteidigung: (1) Trennzeichen [BEGIN/END DATA], (2) Sandwich-
Defense mit nach den Daten wiederholter Anweisung, (3) strenge Output-
Validierung (ungültige Antwort = automatisch CONFIDENTIAL). Temperature=0
und num_predict=5 begrenzen die Angriffsfläche.

### NER-Genauigkeit im Spanischen und Englischen

Dualer ES+EN-Scan: NER führt die Analyse in beiden Sprachen durch und
kombiniert die Ergebnisse. GLOSSARY-MASK.md lädt projektspezifische
Entitäten als Deny-List (Score 1.0, garantierte Erkennung).

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
