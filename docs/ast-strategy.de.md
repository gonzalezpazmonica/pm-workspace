# Savia AST-Strategie — Code-Verständnis und Codequalität

> Technisches Dokument: Wie Savia abstrakte Syntaxbäume verwendet, um Legacy-Code zu verstehen
> und die Qualität des von seinen Agenten generierten Codes zu gewährleisten.

---

## Das gelöste Problem

KI-Agenten generieren Code mit hoher Geschwindigkeit. Ohne strukturelle Validierung kann dieser Code:
- Blockierende Async-Muster einführen, die in der Produktion fehlschlagen
- N+1-Abfragen erzeugen, die die Leistung unter echter Last auf 10 % degradieren
- Ausnahmen in leeren `catch {}`-Blöcken unterdrücken, die kritische Fehler verbergen
- Eine 300-zeilige Datei ändern, ohne ihre internen Abhängigkeiten zu verstehen

Savia löst beide Probleme mit derselben Technologie: AST.

---

## Vierfache Architektur: vier Zwecke, ein Baum

```
Quellcode
     │
     ▼
Abstrakter Syntaxbaum (AST)
     │
     ├──► Verständnis (VOR dem Bearbeiten)          ← PreToolUse-Hook
     │         Versteht, was bereits existiert
     │         Ändert nichts
     │         Kontext-Injektion vor der Bearbeitung
     │
     ├──► Qualität (NACH der Generierung)            ← PostToolUse-Async-Hook
     │         Validiert, was gerade geschrieben wurde
     │         12 universelle Quality Gates
     │         Bericht mit Score 0-100
     │
     ├──► Code-Karten (.acm)                         ← Persistenter Kontext zwischen Sitzungen
     │         Vor der Sitzung vorgeeneriert
     │         Maximal 150 Zeilen pro .acm-Datei
     │         Progressive Ladung mit @include
     │
     └──► Menschliche Karten (.hcm)                  ← Aktiver Kampf gegen kognitive Schulden
               Narrative in natürlicher Sprache
               Von Menschen validiert, nicht von CI
               Warum der Code existiert, nicht nur was er tut
```

Das Designprinzip: Derselbe Baum dient **vier** Phasen des Code-Lebenszyklus,
mit unterschiedlichen Werkzeugen zu unterschiedlichen Zeitpunkten der Hook-Pipeline.

---

## Teil 1 — Verständnis von Legacy-Code

### Das Prinzip

Bevor ein Agent eine Datei bearbeitet, extrahiert Savia ihre strukturelle Karte.
Der Agent erhält diese Karte in seinem Kontext, als hätte er den Code bereits gelesen.

### Extraktions-Pipeline (3 Schichten)

```
Zieldatei
      │
      ▼
Schicht 1: Tree-sitter (universell, 0 Runtime-Abhängigkeiten)
  • Alle Sprachen des Language Pack
  • Klassen, Funktionen, Methoden, Enums
  • Import-Deklarationen
  • ~1-3s, 95 % semantische Abdeckung

      │ (falls nicht verfügbar)
      ▼
Schicht 2: Natives semantisches Sprachwerkzeug
  • Python: ast.walk() (Built-in-Modul, 100 % Präzision)
  • TypeScript: ts-morph (vollständige Compiler API)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100 % semantische Abdeckung

      │ (falls nicht verfügbar)
      ▼
Schicht 3: Grep-strukturell (0 absolute Abhängigkeiten)
  • Universelle Regex für 16 Sprachen
  • Extrahiert Klassen, Funktionen, Importe nach Mustern
  • <500ms, ~70 % semantische Abdeckung
  • Immer verfügbar — schlägt nie fehl
```

**Garantierte Degradierungsregel**: Falls alle erweiterten Werkzeuge fehlschlagen,
funktioniert Grep-strukturell immer. Eine Bearbeitung wird nie wegen fehlender Werkzeuge blockiert.

### Automatischer Auslöser: PreToolUse-Hook

```
Benutzer bittet um Dateibearbeitung
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, Matcher: Edit)
  • Liest file_path aus dem Hook-JSON-Input
  • Prüft: Hat die Datei ≥50 Zeilen?
  • Falls ja: Führt ast-comprehend.sh --surface-only aus (Timeout 15s)
  • Extrahiert: Klassen, Funktionen, zyklomatische Komplexität
  • Falls Komplexität > 15: Gibt sichtbare Warnung aus
         │
         ▼
Agent erhält in seinem Kontext:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Datei: src/Services/AuthService.cs
  Zeilen: 248  |  Klassen: 1  |  Funktionen: 12
  Komplexität: 42 Entscheidungspunkte  ⚠️  Mit Vorsicht vorgehen

  Strukturkarte:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
Agent bearbeitet mit vollständigem Dateikontext
```

Der Hook ist **nicht-asynchron**, da er sich BEVOR der Agent bearbeitet abschließen muss.
Der Hook führt immer `exit 0` aus — das Verständnis ist beratend, blockiert nie.

---

## Teil 2 — Qualität des generierten Codes

### Die 12 universellen Quality Gates

| Gate | Name | Klassifizierung | Sprachen |
|------|------|-----------------|----------|
| QG-01 | Blockierendes Async/Nebenläufigkeit | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | N+1-Abfragen | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null-Dereferenz ohne Guard | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Magische Zahlen ohne Konstante | WARNING | Alle Sprachen |
| QG-05 | Leeres Catch / verschluckte Ausnahmen | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Zyklomatische Komplexität >15 | WARNING | Alle Sprachen |
| QG-07 | Methoden >50 Zeilen | INFO | Alle Sprachen |
| QG-08 | Duplizierung >15 % | WARNING | Alle Sprachen |
| QG-09 | Hardkodierte Geheimnisse | BLOCKER | Alle Sprachen |
| QG-10 | Übermäßiges Logging in Produktion | INFO | Alle Sprachen |
| QG-11 | Toter Code / Dead Code | INFO | Alle Sprachen |
| QG-12 | Geschäftslogik ohne Tests | BLOCKER | Alle Sprachen |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Automatischer Auslöser: PostToolUse-Async-Hook

```
Agent schreibt/bearbeitet Datei
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, Matcher: Edit|Write)
  • Läuft im Hintergrund — blockiert den Agenten nicht
  • Erkennt Sprache anhand der Erweiterung
  • Führt ast-quality-gate.sh mit der Datei aus
  • Berechnet Score (0-100) und Note (A-F)
  • Falls Score < 60 (Note D oder F): Gibt sichtbare Warnung aus
  • Speichert Bericht in output/ast-quality/
```

---

## Teil 3 — Code-Karten für Agenten (.acm)

### Das Problem

Jede Agentensitzung beginnt von Grund auf. Ohne vorab generierten Kontext verbraucht der Agent
30–60 % seines Kontextfensters beim Erkunden der Architektur, bevor er eine einzige Codezeile schreibt.

Agent Code Maps (.acm) sind strukturelle Karten, die sitzungsübergreifend persistent sind,
in `.agent-maps/` gespeichert und für den direkten Agenten-Konsum optimiert.

```
.agent-maps/
├── INDEX.acm              ← Navigations-Einstiegspunkt
├── domain/
│   ├── entities.acm       ← Domänenentitäten
│   └── services.acm       ← Geschäftsservices
├── infrastructure/
│   └── repositories.acm   ← Repositories und Datenzugriff
└── api/
    └── controllers.acm    ← Controller und Endpunkte
```

**150-Zeilen-Limit pro .acm**: Wenn eine Datei wächst, wird sie automatisch in Unterverzeichnisse aufgeteilt.
**@include-System**: Progressive On-Demand-Ladung — der Agent lädt nur das, was er benötigt.

### Frischemodell

| Status | Bedingung | Agentenaktion |
|--------|-----------|---------------|
| `frisch` | .acm-Hash stimmt mit Quellcode überein | Direkt verwenden |
| `veraltet` | Interne Änderungen, Struktur intakt | Mit Warnung verwenden |
| `defekt` | Dateien gelöscht oder öffentliche Signaturen geändert | Vor Verwendung regenerieren |

### Integration in die SDD-Pipeline

.acm-Dateien werden VOR `/spec:generate` geladen. Der Agent kennt die echte Projektarchitektur
vom ersten Token an, ohne blindes Erkunden.

```
[0] LADEN — /codemap:check && /codemap:load <scope>
[1-5] SDD-Pipeline unverändert
[post-SDD] AKTUALISIEREN — /codemap:refresh --incremental
```

---

## Teil 4 — Menschliche Code-Karten (.hcm)

### Das Problem

Entwickler verbringen 58 % ihrer Zeit damit, Code zu lesen, und nur 42 % damit, ihn zu schreiben
(Addy Osmani, 2024). Dieser 58-%-Anteil multipliziert sich in Bereichen mit **kognitiver Schuld**:
Subsysteme, die jemand jedes Mal neu erlernen muss, wenn er sie berührt, weil keine narrative Karte
existiert, die den mentalen Weg vorwegnimmt.

`.hcm`-Dateien bekämpfen kognitive Schulden aktiv: Sie sind der menschliche Zwilling der `.acm`-Dateien.
Während `.acm` einem Agenten sagt „was existiert und wo", sagt `.hcm` einem Entwickler
„warum es existiert und wie man es denkt".

### .hcm-Format

```markdown
# {Komponente} — Menschliche Karte (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{komponente}.acm

## Die Geschichte (1 Absatz)
Welches Problem wird gelöst, in menschlicher Sprache.

## Das mentale Modell
Wie man diese Komponente denkt. Analogien wenn sie helfen.

## Einstiegspunkte (Aufgabe → wo anfangen)
- Um X hinzuzufügen → beginne in {Datei}:{Abschnitt}
- Wenn Y fehlschlägt → Einstiegspunkt ist {hook/script}

## Gotchas (nicht offensichtliche Verhaltensweisen)
- Was neu ankommende Entwickler überrascht
- Dokumentierte Fallen in diesem Subsystem

## Warum es so gebaut ist
- Designentscheidungen mit ihrer Motivation
- Bewusst akzeptierte Kompromisse

## Schuldenindikatoren
- Bekannte Verwirrungsbereiche oder ausstehende Refaktorierungen
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Frische Karte
4-6: Bald überprüfen
7-10: Aktive Schulden — kostet jetzt Geld
```

### Speicherort pro Projekt

Jedes Projekt verwaltet seine eigenen Karten innerhalb seines Ordners:

```
projects/{projekt}/
├── CLAUDE.md
├── .human-maps/               ← Narrative Karten für Entwickler
│   ├── {projekt}.hcm          ← Allgemeine Projektkarte
│   └── _archived/             ← Gelöschte oder zusammengeführte Komponenten
└── .agent-maps/               ← Strukturelle Karten für Agenten
    ├── {projekt}.acm
    └── INDEX.acm
```

Das Stammverzeichnis `.human-maps/` des Workspaces enthält nur die Karten
von pm-workspace selbst als Produkt (nicht der verwalteten Projekte).

### Lebenszyklus

```
Erstellung (/codemap:generate-human) → Menschliche Validierung → Aktiv
         ↓ Code-Änderungen
      .acm wird neu generiert → .hcm als veraltet markiert → Aktualisierung (/codemap:walk)
```

**Unveränderliche Regel:** Eine `.hcm` kann niemals ein `last-walk` haben, das neuer ist als ihr `.acm`.
Wenn das `.acm` veraltet ist, ist das `.hcm` es ebenfalls, unabhängig von seinem eigenen Datum.

### Befehle

```bash
# .hcm-Entwurf aus .acm + Code generieren
/codemap:generate-human projects/mein-projekt/

# Geführte Wiederlesung (Aktualisierung)
/codemap:walk mein-modul

# Debt-Scores aller .hcm im Projekt anzeigen
/codemap:debt-report

# Aktualisierung der angegebenen .hcm erzwingen
/codemap:refresh-human projects/mein-projekt/.human-maps/mein-modul.hcm
```

---

## Systemgarantien

1. **Blockiert nie eine Bearbeitung**: RN-COMP-02 — Falls Verständnis fehlschlägt, immer exit 0
2. **Zerstört nie Code**: RN-COMP-02 — Verständnis ist schreibgeschützt
3. **Hat immer einen Fallback**: RN-COMP-05 — Grep-strukturell garantiert Mindestabdeckung
4. **Sprachagnostische Kriterien**: Die 12 QG gelten gleichermaßen für alle Sprachen
5. **Einheitliches Schema**: Alle Ausgaben sind sprachübergreifend vergleichbar

---

## Referenzen

- Verständnis-Skill: `.claude/skills/ast-comprehension/SKILL.md`
- Qualitäts-Skill: `.claude/skills/ast-quality-gate/SKILL.md`
- Verständnis-Hook: `.claude/hooks/ast-comprehend-hook.sh`
- Qualitäts-Hook: `.claude/hooks/ast-quality-gate-hook.sh`
- Verständnis-Skript: `scripts/ast-comprehend.sh`
- Qualitäts-Skript: `scripts/ast-quality-gate.sh`
- Code-Karten-Skill: `.claude/skills/agent-code-map/SKILL.md`
- Regel menschliche Karten: `.claude/rules/domain/hcm-maps.md`
- Skill menschliche Karten: `.claude/skills/human-code-map/SKILL.md`
- Workspace-Karten: `.human-maps/`
- Projektkarten: `projects/*/.human-maps/*.hcm`
