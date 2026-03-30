# Guia de Savia Shield — Proteccion de datos para o dia a dia

> Uso practico. Para arquitectura tecnica: [docs/savia-shield.md](savia-shield.md)

## Que e Savia Shield

Savia Shield impide que datos confidenciais de proxectos de cliente (nivel N4/N4b) se filtren a ficheiros publicos do repositorio (nivel N1). Opera con 5 capas independentes, cada unha auditable. Esta desactivado por defecto e activase cando comezas a traballar con datos de clientes.

## Os 4 perfis de hooks

Os perfis controlan que hooks se executan. Cada perfil inclue o anterior:

| Perfil | Hooks activos | Caso de uso |
|--------|--------------|-------------|
| `minimal` | So blockers de seguridade (credenciais, force-push, infra destrutiva, soberania) | Demos, onboarding, debugging |
| `standard` | Seguridade + calidade (validacion bash, plan gate, TDD, scope guard, compliance) | Traballo diario (recomendado) |
| `strict` | Standard + dispatch validation, quality gate ao parar, competence tracker | Antes de releases, codigo critico |
| `ci` | Igual que standard pero sen interactividade | Pipelines automaticos, scripts |

```bash
bash scripts/hook-profile.sh get           # Ver perfil activo
bash scripts/hook-profile.sh set standard  # Cambiar (persiste entre sesions)
export SAVIA_HOOK_PROFILE=ci               # Ou con variable de contorno
```

Hooks de seguridade que corren en TODOS os perfis: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## As 5 capas de proteccion

**Capa 0 — Proxy API**: Intercepta prompts saintes a Anthropic. Enmascara entidades automaticamente. Activar con `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Capa 1 — Gate determinista** (< 2s): Hook PreToolUse que escanea contido antes de escribir ficheiros publicos. Regex para credenciais, IPs, tokens. Inclue NFKC e base64.

**Capa 2 — Clasificacion local con LLM**: Ollama qwen2.5:7b clasifica texto semantico como CONFIDENTIAL ou PUBLIC. Os datos nunca saen de localhost. Sen Ollama, so opera a Capa 1.

**Capa 3 — Auditoria post-escritura**: Hook asincrono que re-escanea o ficheiro completo. Non bloquea. Alerta inmediata se detecta fuga.

**Capa 4 — Masking reversibel**: Reemplaza entidades reais con ficticias antes de enviar a APIs cloud. Mapa local (N4, nunca en git).

```bash
bash scripts/sovereignty-mask.sh mask "texto con datos reais" --project o-meu-proxecto
bash scripts/sovereignty-mask.sh unmask "resposta de Claude"
```

---

## Activar e desactivar

```bash
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Ver estado e instalacion
```

Ou editando `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configuracion por proxecto

Cada proxecto pode definir entidades sensibeis en:

- `projects/{nome}/GLOSSARY.md` — termos de dominio
- `projects/{nome}/GLOSSARY-MASK.md` — entidades para masking
- `projects/{nome}/team/TEAM.md` — nomes de stakeholders

Shield carga estes ficheiros automaticamente ao operar sobre o proxecto.

## Instalacion completa (opcional)

Para as 5 capas incluindo proxy e NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requisitos: Python 3.12+, Ollama, jq, 8GB RAM minimo. Sen instalacion completa: as capas 1 e 3 (regex + auditoria) operan sempre.

## Os 5 niveis de confidencialidade

| Nivel | Quen ve | Exemplo |
|-------|---------|---------|
| N1 Publico | Internet | Codigo do workspace |
| N2 Empresa | A organizacion | Config da org |
| N3 Usuario | So ti | O teu perfil |
| N4 Proxecto | Equipo do proxecto | Datos do cliente |
| N4b PM-Only | So a PM | One-to-ones |

Shield protexe as fronteiras **N4/N4b cara a N1**. Escribir en ubicacions privadas sempre esta permitido.

> Arquitectura completa: [docs/savia-shield.md](savia-shield.md) | Tests: `bats tests/test-data-sovereignty.bats`
