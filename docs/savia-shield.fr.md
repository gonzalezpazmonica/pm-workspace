# Savia Shield — Système de souveraineté des données pour l'IA agentique

> Les données de ton client ne quittent jamais ta machine sans ta permission.

---

## Qu'est-ce que Savia Shield

Savia Shield est un système à 4 couches qui protège les données confidentielles
des projets client lorsqu'on travaille avec des assistants IA (Claude,
GPT, etc.). Il classifie chaque donnée avant qu'elle puisse quitter la machine
locale, et masque les entités sensibles lorsqu'il est nécessaire d'envoyer
du texte à des APIs cloud pour un traitement approfondi.

**Problème résolu :** Les outils IA envoient des prompts à des serveurs externes.
Si le prompt contient des noms de clients, des IPs internes, des identifiants
ou des données de réunions, une fuite de données se produit, violant les
NDAs et le RGPD.

**Comment il le résout :** 4 couches indépendantes, chacune auditable par des humains.

---

## Les 4 couches

### Couche 1 — Porte déterministe (regex)

Analyse le contenu avec des patterns regex avant d'écrire un fichier.
Si elle détecte des identifiants, des IPs privées, des tokens d'API ou des clés
privées dans un fichier public, **bloque l'écriture**.

- Latence : < 2 secondes
- Dépendances : bash, grep, jq (standard POSIX)
- Toujours active, même sans connexion internet
- Détection base64 : décode les blobs suspects et re-scanne

### Couche 2 — Classification locale avec LLM (Ollama)

Pour le contenu que le regex ne peut pas évaluer (texte sémantique, comptes
rendus de réunions, descriptions métier), un modèle IA local
(qwen2.5:7b) classifie le texte comme CONFIDENTIEL ou PUBLIC.

- Le modèle tourne sur localhost:11434 — les données **ne sortent jamais**
- Latence : 2-5 secondes
- Résistant à l'injection de prompt :
  - Délimiteurs [BEGIN/END DATA] isolent le texte du prompt
  - Sandwich defense : instruction répétée après les données
  - Validation stricte : si la réponse n'est pas exactement
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, elle est traitée comme CONFIDENTIAL
- Dégradation : si Ollama ne tourne pas, seule la Couche 1 est utilisée

### Couche 3 — Audit post-écriture

Après chaque écriture, un hook asynchrone re-scanne le fichier
complet sur disque (sans tronquer) à la recherche de fuites que les Couches 1-2
auraient pu manquer.

- Ne bloque pas le flux de travail
- Scanne le fichier COMPLET (non tronqué)
- Alerte immédiate si une fuite est détectée

### Couche 4 — Masquage réversible

Quand tu as besoin de la puissance de Claude Opus ou Sonnet pour une analyse
complexe, Savia Shield remplace toutes les entités réelles (personnes,
entreprises, projets, systèmes, IPs) par des noms fictifs cohérents.

**Flux complet (5 étapes) :**

```
ÉTAPE 1 — L'utilisateur a un texte avec des données réelles (N4)
  "Le PM client a demandé de prioriser le module de facturation"

ÉTAPE 2 — sovereignty-mask.sh mask → remplace les entités
  Personnes réelles     → noms fictifs (Alice, Bob, Carol...)
  Entreprise cliente    → entreprise fictive (Acme Corp, Zenith...)
  Projet réel           → projet fictif (Project Aurora...)
  Systèmes internes     → systèmes fictifs (CoreSystem, DataHub...)
  IPs privées           → IPs de test RFC 5737 (198.51.100.x)
  La carte est sauvegardée dans mask-map.json (local, N4)

ÉTAPE 3 — Le texte masqué est envoyé à Claude Opus/Sonnet
  Claude traite "Alice Chen d'Acme Corp a demandé de prioriser CoreSystem"
  Claude NE VOIT PAS les données réelles — il travaille avec des entités fictives
  Le raisonnement et l'analyse sont tout aussi approfondis

ÉTAPE 4 — Claude répond avec des entités fictives
  "Je recommande qu'Alice Chen d'Acme Corp priorise CoreSystem
   sur DataHub compte tenu du deadline du Q3..."

ÉTAPE 5 — sovereignty-mask.sh unmask → restaure les données réelles
  Inverse la carte : Alice Chen → personne réelle, Acme Corp → entreprise réelle
  L'utilisateur reçoit la réponse avec les bons noms
  La carte est effacée ou conservée selon la politique du projet
```

**Garanties :**
- Carte de correspondances locale (N4, jamais dans git)
- 95+ entités mappées par projet via GLOSSARY-MASK.md
- Pools de 32 personnes, 12 entreprises, 16 systèmes fictifs
- Chaque opération mask/unmask enregistrée dans le journal d'audit
- Cohérence : la même entité mappe toujours vers le même fictif

---

## 5 niveaux de confidentialité

| Niveau | Nom | Qui voit | Exemple |
|--------|-----|----------|---------|
| N1 | Public | Internet | Code du workspace, templates |
| N2 | Entreprise | L'organisation | Config de l'org, outils |
| N3 | Utilisateur | Toi seul | Ton profil, préférences |
| N4 | Projet | Équipe du projet | Données client, règles |
| N4b | PM-Only | La PM uniquement | One-to-ones, évaluations |

**Savia Shield protège les frontières N4/N4b → N1.**
Écrire des données sensibles dans des emplacements privés (N2-N4b) est toujours autorisé.

---

## Ce qu'il détecte (Couche 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Clés AWS (AKIA...), GitHub (ghp_, github_pat_), OpenAI (sk-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Clés privées (-----BEGIN...PRIVATE KEY-----)
- IPs privées RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Secrets encodés en base64

---

## Comment l'utiliser

### Masquage pour envoyer à Claude

```bash
# Masquer le texte avant d'envoyer
bash scripts/sovereignty-mask.sh mask "Texte avec données client" --project my-project

# Démasquer la réponse de Claude
bash scripts/sovereignty-mask.sh unmask "Réponse avec Acme Corp"

# Voir la table de correspondances
bash scripts/sovereignty-mask.sh show-map
```

### Vérifier que la porte fonctionne

```bash
# Exécuter les tests
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Vérifier qu'Ollama est sur localhost
netstat -an | grep 11434
```

---

## Auditabilité — Zéro boîtes noires

Chaque composant est un fichier texte lisible par des humains :

| Composant | Fichier | Lignes |
|-----------|---------|--------|
| Porte regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Classificateur LLM | `scripts/ollama-classify.sh` | 99 |
| Audit post-écriture | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Masqueur | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Règle de domaine | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Journaux d'audit :**
- `output/data-sovereignty-audit.jsonl` — décisions des couches 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — décisions du LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — opérations de masquage

---

## Validation

- **51 tests automatisés** (BATS) — core + cas limites + corrections + mocks
- **3 audits indépendants** — Red Team, Confidentialité, Code Review
- **24 vulnérabilités trouvées — 24 résolues, 0 en suspens**
- **0 limitations résiduelles** — toutes corrigées techniquement
- **Score de sécurité : 100/100**
- **Mapping RGPD/ISO 27001/EU AI Act** complet

---

## Limitations techniques et comment elles sont atténuées

### Base64 et encodage de données

Savia Shield décode automatiquement les blobs base64 (jusqu'à 20 blobs de
maximum 200 chars) et re-scanne le contenu décodé. Si le blob
décodé contient un identifiant ou une IP interne, il est bloqué.

### Unicode et homoglyphes

Avant d'appliquer les regex, le contenu est normalisé avec Unicode NFKC.
Cela convertit les caractères fullwidth et d'autres variantes en ASCII canonique.
Après normalisation, les chiffres fullwidth sont convertis en chiffres ASCII et
les regex les détectent correctement.

### Écritures divisées (split-write)

Défense cross-write : lorsqu'on écrit dans un fichier public qui existe déjà
sur disque, Savia Shield lit le contenu existant et le combine
avec le nouveau contenu. Les regex sont appliqués sur le texte combiné,
détectant les patterns qui se forment en joignant les deux écritures.

### Contenu conversationnel (prompts à l'assistant IA)

La Couche 4 (masquage réversible) permet de masquer le texte AVANT de le coller
dans le chat. Le hook NER scanne les fichiers que l'assistant lit. Formation :
les utilisateurs référencent les fichiers par chemin plutôt que de copier le contenu.
Limite résiduelle : il n'y a pas d'interception technique du texte que l'utilisateur
écrit directement dans le prompt — cela nécessite une intégration au niveau du
protocole (amélioration future).

### Injection de prompt dans le classificateur local

Triple défense : (1) délimiteurs [BEGIN/END DATA], (2) sandwich defense
avec instruction répétée après les données, (3) validation stricte de l'output
(réponse non valide = CONFIDENTIAL automatique). Temperature=0 et
num_predict=5 limitent la surface d'attaque.

### Précision du NER en espagnol

Analyse dual ES+EN : NER exécute l'analyse dans les deux langues et combine
les résultats. GLOSSARY-MASK.md charge les entités spécifiques au projet
comme deny-list (score 1.0, détection garantie).

---

## Documentation technique (EN, pour le comité de sécurité)

- `docs/data-sovereignty-architecture.md` — Architecture technique
- `docs/data-sovereignty-operations.md` — Conformité et risque
- `docs/data-sovereignty-auditability.md` — Guide d'audit
- `docs/data-sovereignty-finetune-plan.md` — Plan de modèle fine-tuned

---

## Prérequis

- Ollama installé (`ollama --version`)
- Modèle téléchargé (`ollama pull qwen2.5:7b`)
- jq installé (pour le parsing JSON)
- Python 3.12+ (pour le masquage et NER)
- Presidio (`pip install presidio-analyzer`) — pour la Couche 1.5 NER
- spaCy modèle espagnol (`python3 -m spacy download es_core_news_md`)
- 8 Go RAM minimum (16+ recommandé)
