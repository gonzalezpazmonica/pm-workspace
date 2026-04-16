# Stratégie AST de Savia — Compréhension et Qualité de Code

> Document technique : comment Savia utilise les Arbres de Syntaxe Abstraite pour comprendre
> le code legacy et garantir la qualité du code généré par ses agents.

---

## Le problème résolu

Les agents IA génèrent du code à grande vitesse. Sans validation structurelle, ce code peut :
- Introduire des patterns async bloquants qui échouent en production
- Créer des requêtes N+1 qui dégradent les performances à 10 % sous charge réelle
- Silencier des exceptions dans des blocs `catch {}` vides qui cachent des erreurs critiques
- Modifier un fichier de 300 lignes sans comprendre ses dépendances internes

Savia résout ces deux problèmes avec la même technologie : l'AST.

---

## Architecture quadruple : quatre objectifs, un arbre

```
Code source
     │
     ▼
Arbre de Syntaxe Abstraite (AST)
     │
     ├──► Compréhension (AVANT d'éditer)                  ← hook PreToolUse
     │         Comprend ce qui existe déjà
     │         Ne modifie rien
     │         Injection de contexte pré-édition
     │
     ├──► Qualité (APRÈS génération)                       ← hook PostToolUse async
     │         Valide ce qui vient d'être écrit
     │         12 Quality Gates universels
     │         Rapport avec score 0-100
     │
     ├──► Cartes de code (.acm)                            ← Contexte persistant entre sessions
     │         Pré-généré avant la session
     │         Maximum 150 lignes par fichier .acm
     │         Chargement progressif avec @include
     │
     └──► Cartes humaines (.hcm)                           ← Combat actif contre la dette cognitive
               Narrative en langage naturel
               Validées par des humains, pas par CI
               Pourquoi le code existe, pas seulement ce qu'il fait
```

La clé de conception : le même arbre sert **quatre** phases du cycle de vie du code,
avec des outils différents à des moments différents du pipeline de hooks.

---

## Partie 1 — Compréhension du code legacy

### Le principe

Avant qu'un agent édite un fichier, Savia en extrait la carte structurelle.
L'agent reçoit cette carte dans son contexte, comme s'il avait déjà lu le code.

### Pipeline d'extraction (3 couches)

```
Fichier cible
      │
      ▼
Couche 1 : Tree-sitter (universel, 0 dépendances runtime)
  • Tous les langages du Language Pack
  • Classes, fonctions, méthodes, enums
  • Déclarations d'importation
  • ~1-3s, 95 % de couverture sémantique

      │ (si non disponible)
      ▼
Couche 2 : Outil sémantique natif du langage
  • Python : ast.walk() (module built-in, 100 % de précision)
  • TypeScript : ts-morph (Compiler API complète)
  • Go : gopls symbols
  • C# : Roslyn SyntaxWalker
  • Rust : cargo check + rustfmt AST
  • Java : javap -c, semgrep
  • ~2-10s, 100 % de couverture sémantique

      │ (si non disponible)
      ▼
Couche 3 : Grep-structural (0 dépendances absolues)
  • Regex universel pour les 16 langages
  • Extrait classes, fonctions, imports par motifs
  • <500ms, ~70 % de couverture sémantique
  • Toujours disponible — ne échoue jamais
```

**Règle de dégradation garantie** : si tous les outils avancés échouent,
grep-structural fonctionne toujours. Aucune édition n'est jamais bloquée faute d'outil.

### Déclencheur automatique : hook PreToolUse

```
L'utilisateur demande à éditer un fichier
         │
         ▼
Hook : ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Lit file_path depuis le JSON d'entrée du hook
  • Vérifie : le fichier a-t-il ≥50 lignes ?
  • Si oui : exécute ast-comprehend.sh --surface-only (timeout 15s)
  • Extrait : classes, fonctions, complexité cyclomatique
  • Si complexité > 15 : émet un avertissement visible
         │
         ▼
L'agent reçoit dans son contexte :
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Fichier : src/Services/AuthService.cs
  Lignes :  248  |  Classes : 1  |  Fonctions : 12
  Complexité : 42 points de décision  ⚠️  Procéder avec prudence

  Carte structurelle :
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
L'agent édite avec le contexte complet du fichier
```

Le hook est **non-async** car il doit se terminer AVANT que l'agent édite.
Le hook fait toujours `exit 0` — la compréhension est consultative, ne bloque jamais.

---

## Partie 2 — Qualité du code généré

### Les 12 Quality Gates universels

| Gate | Nom | Classification | Langages |
|------|-----|----------------|----------|
| QG-01 | Async/concurrence bloquant | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | Requêtes N+1 | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference sans garde | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Nombres magiques sans constante | WARNING | Tous les langages |
| QG-05 | Catch vide / exceptions avalées | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Complexité cyclomatique >15 | WARNING | Tous les langages |
| QG-07 | Méthodes >50 lignes | INFO | Tous les langages |
| QG-08 | Duplication >15 % | WARNING | Tous les langages |
| QG-09 | Secrets hardcodés | BLOCKER | Tous les langages |
| QG-10 | Logging excessif en production | INFO | Tous les langages |
| QG-11 | Code mort | INFO | Tous les langages |
| QG-12 | Logique métier sans tests | BLOCKER | Tous les langages |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Déclencheur automatique : hook PostToolUse async

```
L'agent écrit/édite le fichier
         │
         ▼
Hook : ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • S'exécute en arrière-plan — ne bloque pas l'agent
  • Détecte le langage par l'extension
  • Exécute ast-quality-gate.sh sur le fichier
  • Calcule le score (0-100) et la note (A-F)
  • Si score < 60 (note D ou F) : émet une alerte visible
  • Sauvegarde le rapport dans output/ast-quality/
```

---

## Partie 3 — Cartes de code pour les agents (.acm)

### Le problème

Chaque session d'agent repart de zéro. Sans contexte pré-généré, l'agent
consomme 30–60 % de sa fenêtre de contexte à explorer l'architecture avant
d'écrire la moindre ligne de code.

Les Agent Code Maps (.acm) sont des cartes structurelles persistantes entre sessions,
stockées dans `.agent-maps/` et optimisées pour une consommation directe par les agents.

```
.agent-maps/
├── INDEX.acm              ← Point d'entrée de navigation
├── domain/
│   ├── entities.acm       ← Entités du domaine
│   └── services.acm       ← Services métier
├── infrastructure/
│   └── repositories.acm   ← Référentiels et accès aux données
└── api/
    └── controllers.acm    ← Contrôleurs et endpoints
```

**Limite de 150 lignes par .acm** : si le fichier grossit, il est divisé automatiquement.
**Système @include** : chargement progressif à la demande — l'agent charge uniquement ce dont il a besoin.

### Modèle de fraîcheur

| État | Condition | Action de l'agent |
|------|-----------|------------------|
| `frais` | Le hash .acm correspond au code source | Utiliser directement |
| `obsolète` | Modifications internes, structure intacte | Utiliser avec avertissement |
| `cassé` | Fichiers supprimés ou signatures publiques modifiées | Régénérer avant d'utiliser |

### Intégration dans le pipeline SDD

Les fichiers .acm sont chargés AVANT `/spec:generate`. L'agent connaît la
véritable architecture du projet dès le premier token, sans exploration à l'aveugle.

```
[0] CHARGER — /codemap:check && /codemap:load <scope>
[1-5] Pipeline SDD sans changements
[post-SDD] METTRE À JOUR — /codemap:refresh --incremental
```

---

## Partie 4 — Cartes de code humaines (.hcm)

### Le problème

Les développeurs passent 58 % de leur temps à lire du code et seulement 42 % à l'écrire
(Addy Osmani, 2024). Ce 58 % se multiplie dans les zones de **dette cognitive** : des sous-systèmes
que quelqu'un doit réapprendre à chaque fois qu'il y touche, faute d'une carte narrative
qui pré-digère le chemin mental.

Les fichiers `.hcm` combattent activement la dette cognitive : ils sont le jumeau humain
des `.acm`. Tandis que `.acm` dit à un agent « ce qui existe et où », `.hcm` dit
à un développeur « pourquoi ça existe et comment le concevoir ».

### Format .hcm

```markdown
# {Composant} — Carte humaine (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{composant}.acm

## L'histoire (1 paragraphe)
Quel problème est résolu, en langage humain.

## Le modèle mental
Comment penser ce composant. Des analogies si elles aident.

## Points d'entrée (tâche → par où commencer)
- Pour ajouter X → commencer dans {fichier}:{section}
- Si Y échoue → le point d'entrée est {hook/script}

## Gotchas (comportements non évidents)
- Ce qui surprend les développeurs qui arrivent
- Les pièges documentés de ce sous-système

## Pourquoi c'est construit ainsi
- Décisions de conception avec leur motivation
- Compromis acceptés consciemment

## Indicateurs de dette
- Zones de confusion connues ou refactorings en attente
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Carte fraîche
4-6: À revoir bientôt
7-10: Dette active — coûte de l'argent maintenant
```

### Emplacement par projet

Chaque projet gère ses propres cartes dans son dossier :

```
projects/{projet}/
├── CLAUDE.md
├── .human-maps/               ← Cartes narratives pour les développeurs
│   ├── {projet}.hcm           ← Carte générale du projet
│   └── _archived/             ← Composants supprimés ou fusionnés
└── .agent-maps/               ← Cartes structurelles pour les agents
    ├── {projet}.acm
    └── INDEX.acm
```

### Cycle de vie

```
Création (/codemap:generate-human) → Validation humaine → Actif
         ↓ changements de code
      .acm régénéré → .hcm marqué obsolète → Actualisation (/codemap:walk)
```

**Règle immuable :** Un `.hcm` ne peut jamais avoir un `last-walk` plus récent que son `.acm`.
Si le `.acm` est obsolète, le `.hcm` l'est aussi, indépendamment de sa propre date.

### Commandes

```bash
# Générer le brouillon .hcm depuis .acm + code
/codemap:generate-human projects/mon-projet/

# Session guidée de re-lecture (actualisation)
/codemap:walk mon-module

# Afficher les debt-scores de tous les .hcm du projet
/codemap:debt-report

# Forcer l'actualisation du .hcm indiqué
/codemap:refresh-human projects/mon-projet/.human-maps/mon-module.hcm
```

---

## Garanties du système

1. **Ne bloque jamais une édition** : RN-COMP-02 — si la compréhension échoue, exit 0 toujours
2. **Ne détruit jamais le code** : RN-COMP-02 — la compréhension est en lecture seule
3. **A toujours un fallback** : RN-COMP-05 — grep-structural garantit une couverture minimale
4. **Critères agnostiques** : les 12 QG s'appliquent également à tous les langages
5. **Schéma unifié** : tous les outputs sont comparables entre langages

---

## Références

- Skill compréhension : `.claude/skills/ast-comprehension/SKILL.md`
- Skill qualité : `.claude/skills/ast-quality-gate/SKILL.md`
- Hook compréhension : `.claude/hooks/ast-comprehend-hook.sh`
- Hook qualité : `.claude/hooks/ast-quality-gate-hook.sh`
- Script compréhension : `scripts/ast-comprehend.sh`
- Script qualité : `scripts/ast-quality-gate.sh`
- Skill cartes de code : `.claude/skills/agent-code-map/SKILL.md`
- Règle cartes humaines : `docs/rules/domain/hcm-maps.md`
- Skill cartes humaines : `.claude/skills/human-code-map/SKILL.md`
- Cartes du workspace : `.human-maps/`
- Cartes de projet : `projects/*/.human-maps/*.hcm`
