# Guia de Savia Shield — Proteccio de dades per al dia a dia

> Us practic. Per a arquitectura tecnica: [docs/savia-shield.md](savia-shield.md)

## Que es Savia Shield

Savia Shield impedeix que dades confidencials de projectes de client (nivell N4/N4b) es filtrin a fitxers publics del repositori (nivell N1). Opera amb 5 capes independents, cadascuna auditable. Esta desactivat per defecte i s'activa quan comences a treballar amb dades de clients.

## Els 4 perfils de hooks

Els perfils controlen quins hooks s'executen. Cada perfil inclou l'anterior:

| Perfil | Hooks actius | Cas d'us |
|--------|-------------|----------|
| `minimal` | Nomes blockers de seguretat (credencials, force-push, infra destructiva, sobirania) | Demos, onboarding, debugging |
| `standard` | Seguretat + qualitat (validacio bash, plan gate, TDD, scope guard, compliance) | Treball diari (recomanat) |
| `strict` | Standard + dispatch validation, quality gate en aturar, competence tracker | Abans de releases, codi critic |
| `ci` | Igual que standard pero sense interactivitat | Pipelines automatics, scripts |

```bash
bash scripts/hook-profile.sh get           # Veure perfil actiu
bash scripts/hook-profile.sh set standard  # Canviar (persisteix entre sessions)
export SAVIA_HOOK_PROFILE=ci               # O amb variable d'entorn
```

Hooks de seguretat que corren en TOTS els perfils: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## Les 5 capes de proteccio

**Capa 0 — Proxy API**: Intercepta prompts sortints a Anthropic. Emmascara entitats automaticament. Activar amb `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Capa 1 — Gate determinista** (< 2s): Hook PreToolUse que escaneja contingut abans d'escriure fitxers publics. Regex per a credencials, IPs, tokens. Inclou NFKC i base64.

**Capa 2 — Classificacio local amb LLM**: Ollama qwen2.5:7b classifica text semantic com a CONFIDENTIAL o PUBLIC. Les dades mai surten de localhost. Sense Ollama, nomes opera la Capa 1.

**Capa 3 — Auditoria post-escriptura**: Hook asincron que re-escaneja el fitxer complet. No bloqueja. Alerta immediata si detecta fugida.

**Capa 4 — [DEPRECIADA] Masking manual eliminat**

El masking manual (`sovereignty-mask.sh`) va ser eliminat el 2026-05-05.  
La Capa 4 (Proxy) mantiene el seu propi masking intern a `savia-shield-proxy.py`.  
Aquest espai queda reservat per a una alternativa futura.

---

## Activar i desactivar

```bash
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Veure estat i installacio
```

O editant `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configuracio per projecte

Cada projecte pot definir entitats sensibles a:

- `projects/{nom}/GLOSSARY.md` — termes de domini
- `projects/{nom}/GLOSSARY-MASK.md` — entitats per a masking
- `projects/{nom}/team/TEAM.md` — noms de stakeholders

Shield carrega aquests fitxers automaticament en operar sobre el projecte.

## Installacio completa (opcional)

Per a les 5 capes incloent proxy i NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requisits: Python 3.12+, Ollama, jq, 8GB RAM minim. Sense installacio completa: les capes 1 i 3 (regex + auditoria) operen sempre.

## Els 5 nivells de confidencialitat

| Nivell | Qui veu | Exemple |
|--------|---------|---------|
| N1 Public | Internet | Codi del workspace |
| N2 Empresa | L'organitzacio | Config de l'org |
| N3 Usuari | Nomes tu | El teu perfil |
| N4 Projecte | Equip del projecte | Dades del client |
| N4b PM-Only | Nomes la PM | One-to-ones |

Shield protegeix les fronteres **N4/N4b cap a N1**. Escriure en ubicacions privades sempre esta permes.

## Millores Era 171 (SPEC-071)

- **Cobertura d'events**: 17 de 28 events Claude Code coberts (61%, anteriorment 25%)
- **Condicions `if`**: 7 hooks salten automaticament si l'arxiu no es codi (estalvia ~40% dels spawns)
- **Nous events**: SubagentStart/Stop, TaskCreated/Completed, FileChanged, InstructionsLoaded, ConfigChange
- **Portabilitat**: eliminacio de tots els camins `/tmp/` codificats i comandaments `sed -i` incompatibles
- **Timeouts auditable**: si el daemon tarda >5s, es registra com TIMEOUT_ALLOW al registre d'auditoria

> Arquitectura completa: [docs/savia-shield.md](savia-shield.md) | Tests: `bats tests/test-data-sovereignty.bats`
