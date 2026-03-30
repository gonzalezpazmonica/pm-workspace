# Guide Savia Shield — Protection des donnees au quotidien

> Usage pratique. Pour l'architecture technique : [docs/savia-shield.md](savia-shield.md)

## Qu'est-ce que Savia Shield

Savia Shield empeche les donnees confidentielles des projets clients (niveau N4/N4b) de fuiter vers les fichiers publics du depot (niveau N1). Il fonctionne avec 5 couches independantes, chacune auditable. Desactive par defaut, il s'active lorsque vous commencez a travailler avec des donnees clients.

## Les 4 profils de hooks

Les profils controlent quels hooks s'executent. Chaque profil inclut le precedent :

| Profil | Hooks actifs | Cas d'usage |
|--------|-------------|-------------|
| `minimal` | Bloqueurs de securite uniquement (identifiants, force-push, infra destructive, souverainete) | Demos, onboarding, debugging |
| `standard` | Securite + qualite (validation bash, plan gate, TDD, scope guard, compliance) | Travail quotidien (recommande) |
| `strict` | Standard + validation dispatch, quality gate a l'arret, suivi des competences | Avant les releases, code critique |
| `ci` | Comme standard mais sans interactivite | Pipelines automatiques, scripts |

```bash
bash scripts/hook-profile.sh get           # Voir le profil actif
bash scripts/hook-profile.sh set standard  # Changer (persiste entre les sessions)
export SAVIA_HOOK_PROFILE=ci               # Ou par variable d'environnement
```

Hooks de securite presents dans TOUS les profils : `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## Les 5 couches de protection

**Couche 0 — Proxy API** : Intercepte les prompts sortants vers Anthropic. Masque les entites automatiquement. Activer avec `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Couche 1 — Gate deterministe** (< 2s) : Hook PreToolUse qui scanne le contenu avant l'ecriture de fichiers publics. Regex pour identifiants, IPs, tokens. Inclut NFKC et base64.

**Couche 2 — Classification locale par LLM** : Ollama qwen2.5:7b classe le texte semantiquement comme CONFIDENTIAL ou PUBLIC. Les donnees ne quittent jamais localhost. Sans Ollama, seule la Couche 1 opere.

**Couche 3 — Audit post-ecriture** : Hook asynchrone qui re-scanne le fichier complet. Ne bloque pas. Alerte immediate en cas de fuite detectee.

**Couche 4 — Masquage reversible** : Remplace les entites reelles par des fictives avant l'envoi aux APIs cloud. Correspondances locales (N4, jamais dans git).

```bash
bash scripts/sovereignty-mask.sh mask "texte avec donnees reelles" --project mon-projet
bash scripts/sovereignty-mask.sh unmask "reponse de Claude"
```

---

## Activer et desactiver

```bash
/savia-shield enable    # Activer
/savia-shield disable   # Desactiver
/savia-shield status    # Voir etat et installation
```

Ou en editant `.claude/settings.local.json` :

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configuration par projet

Chaque projet peut definir des entites sensibles dans :

- `projects/{nom}/GLOSSARY.md` — termes de domaine
- `projects/{nom}/GLOSSARY-MASK.md` — entites pour le masquage
- `projects/{nom}/team/TEAM.md` — noms des parties prenantes

Shield charge ces fichiers automatiquement lorsqu'il opere sur le projet.

## Installation complete (optionnel)

Pour les 5 couches incluant proxy et NER :

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Prerequis : Python 3.12+, Ollama, jq, 8 Go de RAM minimum. Sans installation complete : les couches 1 et 3 (regex + audit) fonctionnent toujours.

## Les 5 niveaux de confidentialite

| Niveau | Qui voit | Exemple |
|--------|----------|---------|
| N1 Public | Internet | Code du workspace |
| N2 Entreprise | L'organisation | Config de l'org |
| N3 Utilisateur | Vous seul | Votre profil |
| N4 Projet | Equipe du projet | Donnees du client |
| N4b PM uniquement | La PM seule | Entretiens individuels |

Shield protege les frontieres **N4/N4b vers N1**. Ecrire dans des emplacements prives est toujours autorise.

> Architecture complete : [docs/savia-shield.md](savia-shield.md) | Tests : `bats tests/test-data-sovereignty.bats`
