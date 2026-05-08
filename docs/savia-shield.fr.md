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

## Architecture — Daemon + Proxy + Fallback

### Flux principal (daemon actif)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unifié)
  → daemon : regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Flux fallback (daemon en panne)

```
gate.sh détecte daemon offline → inline regex + NFKC + base64 + cross-write
  → mêmes détections, sans NER (Presidio non disponible sans daemon)
```

Le fallback garantit que Shield **protège toujours**, même sans daemon.

---

## Les 4 couches

### Couche 1 — Porte déterministe (regex + NFKC + base64 + cross-write)

Analyse le contenu avant d'écrire un fichier public. Inclut :

- Regex pour identifiants, IPs, tokens, clés privées, tokens SAS
- Normalisation Unicode NFKC (détecte les chiffres fullwidth)
- Décodage base64 des blobs suspects
- Cross-write : combine le contenu existant sur disque + le nouveau pour détecter les divisions
- Normalisation de chemin (résout les `../` traversal)
- Latence : < 2s. Dépendances : bash, grep, jq, python3

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
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
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
- Clés AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Clés privées (-----BEG​IN...PRIVATE KEY-----)
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

| Composant | Fichier | Description |
|-----------|---------|-------------|
| Daemon unifié | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health sur localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Intercepte les prompts Claude, masque/démasque |
| Daemon NER | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistant en RAM (~100ms) |
| Hook gate | `.opencode/hooks/data-sovereignty-gate.sh` | PreToolUse : daemon-first, fallback regex |
| Hook audit | `.opencode/hooks/data-sovereignty-audit.sh` | PostToolUse async : re-scan fichier complet |
| Classificateur LLM | `scripts/ollama-classify.sh` | Couche 2 Ollama (fallback si daemon en panne) |
| Masqueur | `scripts/sovereignty-mask.py` | Couche 4 mask/unmask réversible |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Scan des fichiers stagés avant commit |
| Setup | `scripts/savia-shield-setup.sh` | Installeur : deps, modèles, token, daemons |
| Force-push guard | `.opencode/hooks/block-force-push.sh` | Bloque force-push, push vers main, amend |
| Règle de domaine | `docs/rules/domain/data-sovereignty.md` | Architecture et politiques |

**Journaux d'audit :**
- `output/data-sovereignty-audit.jsonl` — décisions des couches 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — décisions du LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — opérations de masquage

---

## Qualité et tests

- Suite automatisée de tests (BATS) avec couverture du core, des cas limites et des mocks
- Audits de sécurité indépendants (Red Team, Confidentialité, Code Review)
- Mapping vers des frameworks de conformité (RGPD, ISO 27001, EU AI Act)

---

## Capacités de détection avancées

- **Base64** : décode les blobs suspects et re-scanne le contenu décodé
- **Unicode NFKC** : normalise les caractères fullwidth et les variantes avant d'appliquer les regex
- **Cross-write** : combine le contenu existant sur disque avec le nouveau pour détecter les patterns divisés entre écritures
- **Proxy API** : intercepte tous les prompts sortants et masque les entités automatiquement
- **NER bilingue** : analyse combinée en espagnol et anglais, avec deny-list par projet
- **Anti-injection** : triple défense dans le classificateur local (délimiteurs, sandwich, validation stricte)

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


---

## Installation rapide

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

L'installeur :
1. Vérifie les dépendances (python3, jq, ollama, presidio, spacy)
2. Télécharge les modèles nécessaires (qwen2.5:7b, es_core_news_md)
3. Génère un token d'authentification (`~/.savia/shield-token`)
4. Démarre `savia-shield-daemon.py` sur localhost:8444 (scan/mask/unmask)
5. Démarre `savia-shield-proxy.py` sur localhost:8443 (proxy API)
6. Démarre `shield-ner-daemon.py` (NER persistant en RAM)

Après exécution, toute communication avec l'API passe par le proxy qui
masque les entités sensibles automatiquement.

**Sans daemon :** les hooks de gate et d'audit continuent de fonctionner en
mode fallback (regex + NFKC + base64 + cross-write). Claude Code n'est
jamais bloqué par l'absence de daemon.

---

## État par défaut — Désactivé

Savia Shield est **désactivé par défaut**. Les hooks sont installés
mais ne s'exécutent pas tant que vous ne les activez pas. Cela évite
une latence inutile sur les machines sans projets privés.

Activez-le lorsque vous commencez à travailler avec des données clients.

## Activer et désactiver

```bash
# Avec la commande slash (recommandé)
/savia-shield enable    # Activer
/savia-shield disable   # Désactiver
/savia-shield status    # Vérifier l'état et l'installation
```

Ou en modifiant `.claude/settings.local.json` directement :

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Pour désactiver, changer `"true"` par `"false"`.
