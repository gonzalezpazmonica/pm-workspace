# Guida Savia Shield — Protezione dati per il lavoro quotidiano

> Uso pratico. Per l'architettura tecnica: [docs/savia-shield.md](savia-shield.md)

## Cos'e Savia Shield

Savia Shield impedisce che dati riservati dei progetti cliente (livello N4/N4b) fuoriescano verso file pubblici del repository (livello N1). Opera con 5 livelli indipendenti, ciascuno verificabile. Disattivato di default, si attiva quando inizi a lavorare con dati dei clienti.

## I 4 profili hook

I profili controllano quali hook vengono eseguiti. Ogni profilo include il precedente:

| Profilo | Hook attivi | Caso d'uso |
|---------|------------|------------|
| `minimal` | Solo blocker di sicurezza (credenziali, force-push, infra distruttiva, sovranita) | Demo, onboarding, debugging |
| `standard` | Sicurezza + qualita (validazione bash, plan gate, TDD, scope guard, compliance) | Lavoro quotidiano (consigliato) |
| `strict` | Standard + validazione dispatch, quality gate all'arresto, competence tracker | Prima dei release, codice critico |
| `ci` | Come standard ma senza interattivita | Pipeline automatiche, script |

```bash
bash scripts/hook-profile.sh get           # Vedere il profilo attivo
bash scripts/hook-profile.sh set standard  # Cambiare (persiste tra le sessioni)
export SAVIA_HOOK_PROFILE=ci               # O con variabile d'ambiente
```

Hook di sicurezza presenti in TUTTI i profili: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## I 5 livelli di protezione

**Livello 0 — Proxy API**: Intercetta i prompt in uscita verso Anthropic. Maschera le entita automaticamente. Attivare con `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Livello 1 — Gate deterministico** (< 2s): Hook PreToolUse che scansiona il contenuto prima della scrittura di file pubblici. Regex per credenziali, IP, token. Include NFKC e base64.

**Livello 2 — Classificazione locale con LLM**: Ollama qwen2.5:7b classifica il testo semanticamente come CONFIDENTIAL o PUBLIC. I dati non lasciano mai localhost. Senza Ollama, opera solo il Livello 1.

**Livello 3 — Audit post-scrittura**: Hook asincrono che ri-scansiona il file completo. Non blocca. Allarme immediato se rileva una fuga.

**Livello 4 — Mascheramento reversibile**: Sostituisce entita reali con fittizie prima dell'invio alle API cloud. Mappa locale (N4, mai in git).

```bash
bash scripts/sovereignty-mask.sh mask "testo con dati reali" --project il-mio-progetto
bash scripts/sovereignty-mask.sh unmask "risposta di Claude"
```

---

## Attivare e disattivare

```bash
/savia-shield enable    # Attivare
/savia-shield disable   # Disattivare
/savia-shield status    # Vedere stato e installazione
```

Oppure modificando `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configurazione per progetto

Ogni progetto puo definire entita sensibili in:

- `projects/{nome}/GLOSSARY.md` — termini di dominio
- `projects/{nome}/GLOSSARY-MASK.md` — entita per il mascheramento
- `projects/{nome}/team/TEAM.md` — nomi degli stakeholder

Shield carica questi file automaticamente quando opera sul progetto.

## Installazione completa (opzionale)

Per tutti i 5 livelli inclusi proxy e NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requisiti: Python 3.12+, Ollama, jq, minimo 8GB RAM. Senza installazione completa: i livelli 1 e 3 (regex + audit) funzionano sempre.

## I 5 livelli di riservatezza

| Livello | Chi vede | Esempio |
|---------|----------|---------|
| N1 Pubblico | Internet | Codice del workspace |
| N2 Azienda | L'organizzazione | Config dell'org |
| N3 Utente | Solo tu | Il tuo profilo |
| N4 Progetto | Team del progetto | Dati del cliente |
| N4b Solo PM | Solo la PM | Colloqui individuali |

Shield protegge i confini **N4/N4b verso N1**. Scrivere in posizioni private e sempre consentito.

> Architettura completa: [docs/savia-shield.md](savia-shield.md) | Test: `bats tests/test-data-sovereignty.bats`
