# Estratègia AST de Savia — Comprensió i Qualitat de Codi

> Document tècnic: com Savia utilitza Arbres de Sintaxi Abstracta per entendre codi llegat
> i garantir la qualitat del codi generat pels seus agents.

---

## El problema que resol

Els agents d'IA generen codi a alta velocitat. Sense validació estructural, aquest codi pot:
- Introduir patrons async bloquejants que fallen en producció
- Crear consultes N+1 que degraden el rendiment al 10% sota càrrega real
- Silenciar excepcions en `catch {}` buits que oculten errors crítics
- Modificar un fitxer de 300 línies sense entendre les seves dependències internes

Savia resol ambdós problemes amb la mateixa tecnologia: AST.

---

## Arquitectura quàdruple: quatre propòsits, un arbre

```
Codi font
     │
     ▼
Arbre de Sintaxi Abstracta (AST)
     │
     ├──► Comprensió (ABANS d'editar)                 ← hook PreToolUse
     │         Entén el que ja existeix
     │         No modifica res
     │         Pre-edit context injection
     │
     ├──► Qualitat (DESPRÉS de generar)               ← hook PostToolUse async
     │         Valida el que s'acaba d'escriure
     │         12 Quality Gates universals
     │         Informe amb score 0-100
     │
     ├──► Mapes de codi (.acm)                        ← Context persistent entre sessions
     │         Pre-generat abans de la sessió
     │         Màxim 150 línies per fitxer .acm
     │         Càrrega progressiva amb @include
     │
     └──► Mapes humans (.hcm)                         ← Lluita activa contra el deute cognitiu
               Narrativa en llenguatge natural
               Validats per humans, no per CI
               Per què existeix el codi, no només el que fa
```

La clau del disseny: el mateix arbre serveix per a **quatre** fases del cicle de vida del codi,
amb eines diferents i en moments diferents del pipeline de hooks.

---

## Part 1 — Comprensió de codi llegat

### El principi

Abans que un agent editi un fitxer, Savia n'extreu el mapa estructural.
L'agent rep aquest mapa al seu context, com si hagués llegit el codi d'antemà.

### Pipeline d'extracció (3 capes)

```
Fitxer objectiu
      │
      ▼
Capa 1: Tree-sitter (universal, 0 dependències de runtime)
  • Tots els llenguatges del Language Pack
  • Classes, funcions, mètodes, enums
  • Import declarations
  • ~1-3s, 95% cobertura semàntica

      │ (si no disponible)
      ▼
Capa 2: Eina nativa semàntica del llenguatge
  • Python: ast.walk() (mòdul built-in, 100% precisió)
  • TypeScript: ts-morph (Compiler API completa)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100% cobertura semàntica

      │ (si no disponible)
      ▼
Capa 3: Grep-structural (0 dependències absolutes)
  • Regex universal per als 16 llenguatges
  • Extreu classes, funcions, imports per patrons
  • <500ms, ~70% cobertura semàntica
  • Sempre disponible — mai falla
```

**Regla de degradació garantida**: si totes les eines avançades fallen,
grep-structural sempre funciona. Mai es bloqueja una edició per manca d'eina.

### Trigger automàtic: PreToolUse hook

```
Usuari demana editar fitxer
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Llegeix file_path de l'input JSON del hook
  • Verifica: ¿el fitxer té ≥50 línies?
  • Si sí: executa ast-comprehend.sh --surface-only (timeout 15s)
  • Extreu: classes, funcions, complexitat ciclomàtica
  • Si complexitat > 15: emet advertència visible
         │
         ▼
Agent rep al seu context:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Fitxer: src/Services/AuthService.cs
  Línies:  248  |  Classes: 1  |  Funcions: 12
  Complexitat: 42 punts de decisió  ⚠️  Procediu amb cautela

  Mapa estructural:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
Agent edita amb context complet del fitxer
```

El hook és **non-async** perquè ha de completar-se ABANS que l'agent editi.
El hook sempre fa `exit 0` — la comprensió és advisory, mai bloqueja.

---

## Part 2 — Qualitat del codi generat

### Els 12 Quality Gates universals

| Gate | Nom | Classificació | Llenguatges |
|------|-----|---------------|-------------|
| QG-01 | Async/concurrència bloquejant | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | Consultes N+1 | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference sense guard | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Magic numbers sense constant | WARNING | Tots els llenguatges |
| QG-05 | Empty catch / catch buit | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Complexitat ciclomàtica >15 | WARNING | Tots els llenguatges |
| QG-07 | Mètodes >50 línies | INFO | Tots els llenguatges |
| QG-08 | Duplicació >15% | WARNING | Tots els llenguatges |
| QG-09 | Secrets hardcodejats | BLOCKER | Tots els llenguatges |
| QG-10 | Logging excessiu en producció | INFO | Tots els llenguatges |
| QG-11 | Codi mort / dead code | INFO | Tots els llenguatges |
| QG-12 | Lògica de negoci sense tests | BLOCKER | Tots els llenguatges |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Trigger automàtic: PostToolUse async hook

```
Agent escriu/edita fitxer
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Executa en background — no bloqueja l'agent
  • Detecta llenguatge per extensió
  • Executa ast-quality-gate.sh amb el fitxer
  • Calcula score (0-100) i grade (A-F)
  • Si score < 60 (grade D o F): emet alerta visible
  • Desa l'informe a output/ast-quality/
```

---

## Part 3 — Mapes de codi per a agents (.acm)

### El problema

Cada sessió d'agent comença de zero. Sense context pre-generat, l'agent
consumeix el 30–60 % de la seva finestra de context explorant l'arquitectura
abans d'escriure una sola línia de codi.

Els Agent Code Maps (.acm) són mapes estructurals persistents entre sessions,
emmagatzemats a `.agent-maps/` i optimitzats per al consum directe pels agents.

```
.agent-maps/
├── INDEX.acm              ← Punt d'entrada de navegació
├── domain/
│   ├── entities.acm       ← Entitats de domini
│   └── services.acm       ← Serveis de negoci
├── infrastructure/
│   └── repositories.acm   ← Repositoris i accés a dades
└── api/
    └── controllers.acm    ← Controllers i endpoints
```

**Límit de 150 línies per .acm**: si creix, es divideix automàticament.
**Sistema @include**: càrrega progressiva sota demanda — l'agent carrega només el que necessita.

### Model de frescor

| Estat | Condició | Acció de l'agent |
|-------|----------|-----------------|
| `fresc` | Hash .acm coincideix amb el codi font | Usar directament |
| `obsolet` | Canvis interns, estructura intacta | Usar amb avís |
| `trencat` | Fitxers eliminats o signatures públiques canviades | Regenerar abans d'usar |

### Integració en el pipeline SDD

Els fitxers .acm es carreguen ABANS de `/spec:generate`. L'agent coneix la
arquitectura real del projecte des del primer token, sense exploració a cegues.

```
[0] CARREGAR — /codemap:check && /codemap:load <scope>
[1-5] Pipeline SDD sense canvis
[post-SDD] ACTUALITZAR — /codemap:refresh --incremental
```

---

## Part 4 — Mapes humans (.hcm)

### El problema

Els desenvolupadors inverteixen el 58 % del temps llegint codi vs. el 42 % escrivint-lo
(Addy Osmani, 2024). Aquest 58 % es multiplica en àrees amb **deute cognitiu**: subsistemes
que algú ha de re-aprendre cada vegada que els toca perquè no existeix un mapa narratiu
que pre-digereixi el camí mental.

Els fitxers `.hcm` lluiten activament contra el deute cognitiu: són el bessó humà
dels `.acm`. Mentre `.acm` li diu a un agent "què existeix i on", `.hcm` li diu
a un desenvolupador "per què existeix i com pensar-ho".

### Format .hcm

```markdown
# {Component} — Mapa humà (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{component}.acm

## La història (1 paràgraf)
Quin problema resol, en llenguatge humà.

## El model mental
Com pensar en aquest component. Analogies si ajuden.

## Punts d'entrada (tasca → on començar)
- Per afegir X → comença a {fitxer}:{secció}
- Si Y falla → el punt d'entrada és {hook/script}

## Gotchas (comportaments no obvis)
- El que sorprèn els desenvolupadors que arriben nous
- Les trampes documentades d'aquest subsistema

## Per què està construït així
- Decisions de disseny amb la seva motivació
- Compromisos acceptats conscientment

## Indicadors de deute
- Àrees conegudes de confusió o refactor pendent
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mapa fresc
4-6: Revisar aviat
7-10: Deute actiu — costant diners ara
```

### Ubicació per projecte

Cada projecte gestiona els seus propis mapes dins la seva carpeta:

```
projects/{projecte}/
├── CLAUDE.md
├── .human-maps/               ← Mapes narratius per a desenvolupadors
│   ├── {projecte}.hcm         ← Mapa general del projecte
│   └── _archived/             ← Components eliminats o fusionats
└── .agent-maps/               ← Mapes estructurals per a agents
    ├── {projecte}.acm
    └── INDEX.acm
```

El directori `.human-maps/` arrel del workspace conté únicament els mapes
del propi pm-workspace com a producte (no dels projectes gestionats).

### Cicle de vida

```
Creació (/codemap:generate-human) → Validació humana → Actiu
         ↓ canvis de codi
      .acm es regenera → .hcm marcat com obsolet → Refresc (/codemap:walk)
```

**Regla immutable:** Un `.hcm` mai pot tenir `last-walk` més recent que el seu `.acm`.
Si el `.acm` és obsolet, el `.hcm` també ho és independentment de la seva data.

### Comandes

```bash
# Genera l'esborrany .hcm a partir de .acm + codi
/codemap:generate-human projects/el-meu-projecte/

# Sessió guiada de re-lectura (refresc)
/codemap:walk el-meu-modul

# Mostra els debt-scores de tots els .hcm del projecte
/codemap:debt-report

# Força el refresc del .hcm indicat
/codemap:refresh-human projects/el-meu-projecte/.human-maps/el-meu-modul.hcm
```

---

## Garanties del sistema

1. **Mai bloqueja un edit**: RN-COMP-02 — si la comprensió falla, exit 0 sempre
2. **Mai destrueix codi**: RN-COMP-02 — comprensió és read-only
3. **Sempre té fallback**: RN-COMP-05 — grep-structural garanteix cobertura mínima
4. **Criteris agnòstics**: els 12 QG apliquen igual a tots els llenguatges
5. **Schema unificat**: tots els outputs són comparables entre llenguatges

---

## Referències

- Skill comprensió: `.claude/skills/ast-comprehension/SKILL.md`
- Skill qualitat: `.claude/skills/ast-quality-gate/SKILL.md`
- Hook comprensió: `.claude/hooks/ast-comprehend-hook.sh`
- Hook qualitat: `.claude/hooks/ast-quality-gate-hook.sh`
- Script comprensió: `scripts/ast-comprehend.sh`
- Script qualitat: `scripts/ast-quality-gate.sh`
- Skill mapes de codi: `.claude/skills/agent-code-map/SKILL.md`
- Regla mapes humans: `docs/rules/domain/hcm-maps.md`
- Skill mapes humans: `.claude/skills/human-code-map/SKILL.md`
- Mapes del workspace: `.human-maps/`
- Mapes de projecte: `projects/*/.human-maps/*.hcm`
